#!/usr/bin/env bash
set -euo pipefail

echo "==> Running Rust verification"

echo "--- Cargo check ---"
cargo check

echo "--- Clippy ---"
cargo clippy -- -D warnings

echo "--- Tests ---"
cargo test

echo ""
echo "All checks passed."
