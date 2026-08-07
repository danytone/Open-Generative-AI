#!/usr/bin/env node
/**
 * Sync packages/studio/src/models.js with the live Muapi model catalog.
 *
 * Fetches https://api.muapi.ai/api/v1/models (public, no key required) plus the
 * per-model input schema for anything missing, and appends new entries to the
 * matching exported array — mirroring the hand-curated conventions already in
 * the file. Only ADDS models; it never edits or removes existing entries.
 *
 * Usage:
 *   node scripts/sync-muapi-models.mjs            # apply changes to models.js
 *   node scripts/sync-muapi-models.mjs --dry-run  # report only, no writes
 *
 * Exit codes: 0 = success (whether or not anything changed). Non-zero = error.
 * On success it prints a summary and, when $GITHUB_OUTPUT is set, writes
 * `added=<n>` and a markdown `summary` for the CI job to consume.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const API = 'https://api.muapi.ai/api/v1';
const DRY_RUN = process.argv.includes('--dry-run');

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MODELS_PATH = path.join(__dirname, '..', 'packages', 'studio', 'src', 'models.js');

// API category → target exported array in models.js.
const CATEGORY_TO_ARRAY = {
  'Text to Image': 't2iModels',
  'Image to Image': 'i2iModels',
  'Text to Video': 't2vModels',
  'Image to Video': 'i2vModels',
  'Audio to Video': 'lipsyncModels',
};
// Deliberately excluded: "Video to Video" (upscalers, watermark removal,
// face-swap, captions …) — these don't map onto the current studios. Adjust
// here if a matching studio is added later.

const DIRECTION_PHRASES = [
  'text-to-video', 'image-to-video', 'reference-to-video', 'speech-to-video',
  'video-to-video', 'text-to-image', 'image-to-image', 'first-last-frame',
];
const UPPER = new Set(['ai', 'ltx', 'vip', 'hd', 'ugc', 'gpt', '4k', '8k', 'sd', 'i2v', 't2v']);

function prettify(slug) {
  let s = slug;
  for (const p of DIRECTION_PHRASES) s = s.split(p).join('-');
  s = s.replace(/-(t2v|i2v|t2i|i2i)(-|$)/g, '$2');
  s = s.replace(/-{2,}/g, '-').replace(/^-|-$/g, '');
  return s.split('-').filter(Boolean).map((t) => {
    if (UPPER.has(t.toLowerCase())) return t.toUpperCase();
    if (/^v\d/i.test(t)) return 'v' + t.slice(1);
    if (/^\d/.test(t)) return t;
    return t.charAt(0).toUpperCase() + t.slice(1);
  }).join(' ').trim();
}

function slimProp(p) {
  if (!p || typeof p !== 'object') return p;
  const { examples, ...rest } = p;
  return rest;
}

const CONTROL_FIELDS = ['prompt', 'aspect_ratio', 'resolution', 'quality', 'duration', 'mode'];

function buildInputs(props, includePrompt) {
  const inputs = {};
  for (const f of CONTROL_FIELDS) {
    if (f === 'prompt' && !includePrompt) continue;
    if (props[f]) inputs[f] = slimProp(props[f]);
  }
  if (props.name && props.name.enum) inputs.name = slimProp(props.name);
  return inputs;
}

function detectImageField(props) {
  if (props.images_list) return 'images_list';
  if (props.image_url) return 'image_url';
  if (props.image_urls) return 'image_urls';
  return Object.keys(props).find((x) => /image/i.test(x)) || 'image_url';
}

function detectLastImageField(props) {
  return ['last_image', 'last_image_url', 'end_image_url', 'tail_image_url'].find((k) => props[k]) || null;
}

function makeEntry(slug, arr, family, description, props) {
  const hasPrompt = !!props.prompt;
  const base = { id: slug, name: prettify(slug), endpoint: slug };
  if (family) base.family = family;

  if (arr === 't2iModels' || arr === 't2vModels') {
    return { ...base, inputs: buildInputs(props, true) };
  }
  if (arr === 'i2iModels') {
    const e = { ...base, imageField: detectImageField(props), hasPrompt };
    const il = props.images_list;
    if (il && typeof il.maxItems === 'number' && il.maxItems > 1) e.maxImages = il.maxItems;
    e.inputs = buildInputs(props, hasPrompt);
    return e;
  }
  if (arr === 'i2vModels') {
    const e = { ...base, imageField: detectImageField(props) };
    const lf = detectLastImageField(props);
    if (lf) e.lastImageField = lf;
    e.inputs = buildInputs(props, hasPrompt);
    return e;
  }
  if (arr === 'lipsyncModels') {
    const e = { ...base, category: 'image', hasPrompt, description };
    e.inputs = {};
    const res = props.resolution || props.output_resolution;
    if (res && res.enum) e.inputs.resolution = { type: 'string', title: 'Resolution', name: 'resolution', enum: res.enum, default: res.default || res.enum[0] };
    return e;
  }
  return null;
}

async function getJson(url) {
  const r = await fetch(url, { headers: { accept: 'application/json' } });
  if (!r.ok) throw new Error(`${r.status} for ${url}`);
  return r.json();
}

async function fetchDetails(slugs, concurrency = 8) {
  const out = {};
  const queue = [...slugs];
  await Promise.all(Array.from({ length: concurrency }, async () => {
    while (queue.length) {
      const slug = queue.shift();
      try { out[slug] = await getJson(`${API}/models/${slug}`); }
      catch (e) { out[slug] = { __error: String(e) }; }
    }
  }));
  return out;
}

function spliceInto(code, arr, entries) {
  const body = entries
    .map((e) => '  ' + JSON.stringify(e, null, 2).split('\n').join('\n  '))
    .join(',\n');
  const declStart = code.indexOf(`export const ${arr} = [`);
  if (declStart === -1) throw new Error(`declaration not found for ${arr}`);
  const closeIdx = code.indexOf('\n];', declStart);
  if (closeIdx === -1) throw new Error(`close bracket not found for ${arr}`);
  const insertion = `,\n  // ── Auto-added by scripts/sync-muapi-models.mjs (${new Date().toISOString().slice(0, 10)}) ──\n${body}`;
  return code.slice(0, closeIdx) + insertion + code.slice(closeIdx);
}

async function main() {
  let code = fs.readFileSync(MODELS_PATH, 'utf8');
  const existing = new Set([...code.matchAll(/"(?:id|endpoint)":\s*"([^"]+)"/g)].map((m) => m[1]));

  const list = (await getJson(`${API}/models`)).models;
  const missing = list.filter((m) => CATEGORY_TO_ARRAY[m.category] && !existing.has(m.name));

  if (!missing.length) {
    console.log('Catalog is already up to date — no new models found.');
    writeCiOutput(0, 'No new Muapi models found.');
    return;
  }

  console.log(`Found ${missing.length} model(s) not yet in the catalog. Fetching schemas…`);
  const details = await fetchDetails(missing.map((m) => m.name));

  const buckets = {};
  const errors = [];
  for (const m of missing) {
    const d = details[m.name];
    if (!d || d.__error) { errors.push(`${m.name}: ${d?.__error || 'no detail'}`); continue; }
    const props = d.input_schema?.schemas?.input_data?.properties || {};
    const arr = CATEGORY_TO_ARRAY[m.category];
    const entry = makeEntry(m.name, arr, m.family, m.description, props);
    if (entry && !existing.has(entry.id) && !existing.has(entry.endpoint)) {
      (buckets[arr] ||= []).push(entry);
      existing.add(entry.id); existing.add(entry.endpoint);
    }
  }

  // Dedupe display names within each array for readability.
  for (const arr of Object.keys(buckets)) {
    const seen = new Map();
    for (const e of buckets[arr]) {
      if (seen.has(e.name)) { const n = seen.get(e.name) + 1; seen.set(e.name, n); e.name = `${e.name} (${n})`; }
      else seen.set(e.name, 1);
    }
  }

  const lines = [];
  let total = 0;
  for (const arr of ['t2iModels', 'i2iModels', 't2vModels', 'i2vModels', 'lipsyncModels']) {
    const list = buckets[arr];
    if (!list || !list.length) continue;
    total += list.length;
    lines.push(`- \`${arr}\`: +${list.length} (${list.map((e) => e.name).slice(0, 8).join(', ')}${list.length > 8 ? ', …' : ''})`);
    if (!DRY_RUN) code = spliceInto(code, arr, list);
  }

  const summary = total
    ? `Added ${total} new model(s):\n${lines.join('\n')}`
    : 'No new models added.';
  if (errors.length) console.warn(`Skipped ${errors.length} model(s) with fetch errors:\n  ${errors.slice(0, 10).join('\n  ')}`);

  if (DRY_RUN) {
    console.log('[dry-run] ' + summary);
  } else if (total) {
    fs.writeFileSync(MODELS_PATH, code);
    console.log(summary);
  } else {
    console.log(summary);
  }
  writeCiOutput(total, summary);
}

function writeCiOutput(added, summary) {
  const out = process.env.GITHUB_OUTPUT;
  if (!out) return;
  const delim = 'EOF_' + Math.random().toString(36).slice(2);
  fs.appendFileSync(out, `added=${added}\n`);
  fs.appendFileSync(out, `summary<<${delim}\n${summary}\n${delim}\n`);
}

main().catch((e) => { console.error(e); process.exit(1); });
