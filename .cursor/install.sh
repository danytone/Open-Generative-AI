#!/usr/bin/env bash
# Idempotent bootstrap for the Open Generative AI Next.js web app.
# Safe to run repeatedly and against cached/partially-prepared state.
set -euo pipefail

# Resolve repo root (this script lives in .cursor/).
cd "$(dirname "${BASH_SOURCE[0]}")/.."

# 1. Initialize git submodules (workflow-builder + agents workspace packages).
#    Upstream has historically pinned submodule commits that later get
#    force-pushed away, which makes a plain `git submodule update` hard-fail on
#    a missing pinned commit. Fall back to each submodule's default branch so
#    setup stays reproducible even when a pin disappears.
git submodule sync --recursive
if ! git submodule update --init --recursive; then
  echo "Pinned submodule commit unavailable; falling back to default branch (--remote)."
  git config submodule.packages/Open-Poe-AI.branch main
  git config submodule.packages/Vibe-Workflow.branch main
  git submodule update --init --remote --recursive
fi

# Guarantee submodule working trees are populated (repopulate if a checkout was
# skipped because the recorded commit was unavailable).
git submodule foreach 'git checkout -f HEAD -- . 2>/dev/null || true'

# 2. Install workspace dependencies (root + studio/workflow-builder/agents).
npm install

# 3. Build the shared workspace packages the Next.js app consumes at runtime.
npm run build:packages
