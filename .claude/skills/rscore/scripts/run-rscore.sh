#!/usr/bin/env bash
set -euxo pipefail

# Resolve skill root so the binary's hardcoded relative path
# "public/templates/providers.csv" resolves correctly when we cd there.
SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$SKILL_DIR/bin/rscore"
game="${1:?Usage: $0 <game-name>}"

# Build absolute paths before cd so testdata/results still resolve.
TESTDATA_DIR="$SKILL_DIR/public/testdata"
RESULTS_DIR="$SKILL_DIR/public/testresults"
mkdir -p "$RESULTS_DIR"

pre_nodes="$TESTDATA_DIR/${game}_pre_nodes.csv"
pre_edges="$TESTDATA_DIR/${game}_pre_edges.csv"
post_nodes="$TESTDATA_DIR/${game}_post_nodes.csv"
post_edges="$TESTDATA_DIR/${game}_post_edges.csv"
output="$RESULTS_DIR/${game}_score.txt"

# Run binary from skill root so "public/templates/providers.csv" resolves.
cd "$SKILL_DIR"

echo "=== ${game} PRE ===" > "$output"
"$BIN" score -n "$pre_nodes" -e "$pre_edges" >> "$output"

echo "" >> "$output"
echo "=== ${game} POST ===" >> "$output"
"$BIN" score -n "$post_nodes" -e "$post_edges" >> "$output"

echo "Scored $game -> $output"
