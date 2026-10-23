#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for x in 'mrsc_only mrsc' 'tbec_only tbec' \
 'mux_reference tbec' 'mux_reference mrsc' 'mux_reference mixed' \
 'mux_isolated tbec' 'mux_isolated mrsc' 'mux_isolated mixed';do
  read -r top scenario <<< "$x"
  echo "##### $top $scenario #####"
  "$ROOT/scripts/run_sim.sh" "$top" "$scenario" bench
 done
for x in 'mrsc_only mrsc' 'tbec_only tbec' \
 'mux_reference tbec' 'mux_reference mrsc' \
 'mux_isolated tbec' 'mux_isolated mrsc';do
  read -r top scenario <<< "$x"
  "$ROOT/scripts/run_sim.sh" "$top" "$scenario" faults
 done
