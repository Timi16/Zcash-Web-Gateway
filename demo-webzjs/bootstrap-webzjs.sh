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

if ! command -v just >/dev/null 2>&1; then
  echo "just is required (install via https://github.com/casey/just)" >&2
  exit 1
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "rustup is required (install via https://rustup.rs/)" >&2
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

# Work around upstream pczt missing from ChainSafe fork by switching to the
# crates.io pczt release.
perl -0pi -e 's|pczt = \\{ git = \"https://github.com/ChainSafe/librustzcash-nu61\"[^}]*\\}|pczt = { version = \"0.5.1\", default-features = false, features = [\"orchard\", \"sapling\", \"transparent\"] }|s' Cargo.toml
# Remove any previous git patch we may have added.
perl -0pi -e 's|\\n\\[patch\\.\\"https://github.com/ChainSafe/librustzcash-nu61\\"\\][^\\[]*||s' Cargo.toml

rg -n "pczt =" Cargo.toml

# Build WebZjs packages with the official justfile recipe.
# This requires nightly and wasm32 target (per WebZjs README).
rustup toolchain install nightly-2024-08-07
rustup target add wasm32-unknown-unknown --toolchain nightly-2024-08-07

RUSTUP_TOOLCHAIN=nightly-2024-08-07 just build

# Install demo deps (points to local package via file:)
cd "$ROOT_DIR"
npm install

echo "WebZjs bootstrap complete. Run 'npm run dev' in demo-webzjs." 
