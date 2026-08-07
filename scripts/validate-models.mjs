#!/usr/bin/env node
/**
 * Dependency-free sanity check for packages/studio/src/models.js.
 *
 * Loads the module (rewriting `export const` → CommonJS so no bundler/build is
 * needed) and asserts the model arrays are well-formed: present, non-empty,
 * every entry has a string id + name, and ids are unique within each array.
 * Exits non-zero on any problem so CI fails loudly.
 */
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import Module from 'node:module';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MODELS_PATH = path.join(__dirname, '..', 'packages', 'studio', 'src', 'models.js');

const src = fs.readFileSync(MODELS_PATH, 'utf8');
const cjs = src.replace(/export const ([A-Za-z0-9_]+) =/g, 'const $1 = exports.$1 =');
const tmp = path.join(os.tmpdir(), `models-validate-${process.pid}.cjs`);
fs.writeFileSync(tmp, cjs);

let ex;
try {
  const m = new Module(tmp);
  m.filename = tmp;
  m.paths = Module._nodeModulePaths(path.dirname(tmp));
  m._compile(cjs, tmp);
  ex = m.exports;
} finally {
  fs.rmSync(tmp, { force: true });
}

const ARRAYS = ['t2iModels', 'i2iModels', 't2vModels', 'i2vModels', 'v2vModels', 'lipsyncModels'];
const errors = [];

for (const name of ARRAYS) {
  const arr = ex[name];
  if (!Array.isArray(arr)) { errors.push(`${name} is not an array`); continue; }
  if (arr.length === 0) { errors.push(`${name} is empty`); continue; }
  const seen = new Set();
  for (const e of arr) {
    if (!e || typeof e.id !== 'string' || !e.id) errors.push(`${name}: entry with invalid id`);
    else if (seen.has(e.id)) errors.push(`${name}: duplicate id "${e.id}"`);
    else seen.add(e.id);
    if (!e || typeof e.name !== 'string' || !e.name) errors.push(`${name}: entry "${e?.id}" missing name`);
  }
}

for (const fn of ['getModelById', 'getI2IModelById', 'getVideoModelById', 'getI2VModelById', 'getLipSyncModelById']) {
  if (typeof ex[fn] !== 'function') errors.push(`missing helper export: ${fn}`);
}

if (errors.length) {
  console.error('models.js validation FAILED:');
  for (const e of errors) console.error('  - ' + e);
  process.exit(1);
}

const counts = ARRAYS.map((n) => `${n}=${ex[n].length}`).join('  ');
console.log('models.js validation passed:  ' + counts);
