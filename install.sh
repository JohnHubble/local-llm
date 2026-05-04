#!/usr/bin/env bash
# install.sh — set up the venv and dependencies for local-llm.
# Idempotent: safe to re-run.

set -euo pipefail

cd "$(dirname "$0")"
ROOT="$(pwd)"

# 1. Sanity checks.
if [[ "$(uname -s)" != "Darwin" ]] || [[ "$(uname -m)" != "arm64" ]]; then
  echo "error: local-llm requires Apple Silicon macOS (M1/M2/M3/M4). Detected: $(uname -s) $(uname -m)" >&2
  exit 1
fi

# Find a Python 3.10+ — macOS system python3 is 3.9, which mlx-lm doesn't support.
# Try newest first; whichever exists wins.
PYBIN=""
for cand in python3.13 python3.12 python3.11 python3.10 python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    ver="$("$cand" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
    major="$(echo "$ver" | cut -d. -f1)"
    minor="$(echo "$ver" | cut -d. -f2)"
    if (( major == 3 )) && (( minor >= 10 )); then
      PYBIN="$(command -v "$cand")"
      PY_VER="$ver"
      break
    fi
  fi
done

if [[ -z "$PYBIN" ]]; then
  echo "error: need Python 3.10+, none found on PATH." >&2
  echo "       macOS ships with Python 3.9 which mlx-lm doesn't support." >&2
  echo "       Install with: brew install python@3.12" >&2
  exit 1
fi
echo "using $PYBIN (python $PY_VER)"

# 2. Create venv.
if [[ ! -d "$ROOT/venv" ]]; then
  echo "creating venv at $ROOT/venv..."
  "$PYBIN" -m venv "$ROOT/venv"
else
  echo "venv exists at $ROOT/venv — reusing"
fi

PIP="$ROOT/venv/bin/pip"
"$PIP" install --upgrade --quiet pip

# 3. Install deps from pinned requirements.txt.
# Versions are pinned to a known-working set; see "Known Tested On" in README.
# To intentionally upgrade, bump versions in requirements.txt and re-run.
echo "installing python deps from requirements.txt..."
"$PIP" install --quiet -r "$ROOT/requirements.txt"

# 4. Make wrapper executable.
chmod +x "$ROOT/bin/local-llm"

# 5. PATH advice.
cat <<EOF

install complete.

To use \`local-llm\` from anywhere, add the bin/ dir to your PATH:

    echo 'export PATH="$ROOT/bin:\$PATH"' >> ~/.zshrc
    source ~/.zshrc

Or symlink it into a dir already on your PATH:

    ln -s "$ROOT/bin/local-llm" /usr/local/bin/local-llm   # may need sudo
    ln -s "$ROOT/bin/local-llm" ~/.local/bin/local-llm     # if ~/.local/bin is on PATH

Quick start (downloads ~2.1 GB on first switch):

    local-llm switch daily
    local-llm prompt "Summarize this in one sentence: $(echo "this is a test")"
    local-llm stop

See README.md for the full walkthrough.
EOF
