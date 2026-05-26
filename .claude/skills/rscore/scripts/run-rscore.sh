#!/usr/bin/env bash
set -euxo pipefail

BIN=".claude/skills/rscore/bin/rscore"
TESTDATA_DIR=".claude/skills/rscore/public/testdata"
RESULTS_DIR=".claude/skills/rscore/public/testresults"
game="${1:?Usage: $0 <game-name>}"

mkdir -p "$RESULTS_DIR"

pre_nodes="$TESTDATA_DIR/${game}_pre_nodes.csv"
pre_edges="$TESTDATA_DIR/${game}_pre_edges.csv"
post_nodes="$TESTDATA_DIR/${game}_post_nodes.csv"
post_edges="$TESTDATA_DIR/${game}_post_edges.csv"
output="$RESULTS_DIR/${game}_score.txt"

echo "=== ${game} PRE ===" > "$output"
"$BIN" score -n "$pre_nodes" -e "$pre_edges" >> "$output"

echo "" >> "$output"
echo "=== ${game} POST ===" >> "$output"
"$BIN" score -n "$post_nodes" -e "$post_edges" >> "$output"

echo "Scored $game -> $output"
