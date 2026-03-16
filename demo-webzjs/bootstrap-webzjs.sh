#!/bin/sh
set -e
set -x

ROOT_DIR=$(cd "$(dirname "$0")" && pwd)
VENDOR_DIR="$ROOT_DIR/../vendor"
WEBZJS_DIR="$VENDOR_DIR/webzjs"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v wasm-pack >/dev/null 2>&1; then
  echo "wasm-pack is required (install via https://rustwasm.github.io/wasm-pack/)" >&2
  exit 1
fi

mkdir -p "$VENDOR_DIR"

if [ ! -d "$WEBZJS_DIR/.git" ]; then
  git clone https://github.com/ChainSafe/WebZjs.git "$WEBZJS_DIR"
else
  (cd "$WEBZJS_DIR" && git pull)
fi

cd "$WEBZJS_DIR"
pwd
ls -la crates/webzjs-wallet

# Build the wallet package used by the demo.
wasm-pack build ./crates/webzjs-wallet --target web

# Install demo deps (points to local package via file:)
cd "$ROOT_DIR"
npm install

echo "WebZjs bootstrap complete. Run 'npm run dev' in demo-webzjs." 
