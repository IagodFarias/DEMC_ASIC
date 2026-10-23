#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ACTION="${1:-}"
TOPARG="${2:-}"
: "${PDK:?Export PDK=/absolute/path/to/ihp-sg13g2}"
if [[ "$ACTION" != synth && "$ACTION" != pnr && "$ACTION" != power ]];then
 echo 'Usage: scripts/run_cadence.sh synth|pnr|power <mrsc_only|tbec_only|mux_reference|mux_isolated> [tbec|mrsc|mixed]' >&2;exit 2
fi
case "$TOPARG" in mrsc_only|tbec_only|mux_reference|mux_isolated);;*)exit 2;;esac
export ROOT PDK TOP="ecc_$TOPARG"
export OUT="$ROOT/results/cadence/$TOP"
mkdir -p "$OUT"
if [[ "$ACTION" == synth ]];then
 command -v genus >/dev/null || { echo 'genus not in PATH' >&2;exit 3; }
 genus -batch -files "$ROOT/scripts/cadence/run_synth.tcl" -log "$OUT/genus.log"
elif [[ "$ACTION" == pnr ]];then
 command -v innovus >/dev/null || { echo 'innovus not in PATH' >&2;exit 3; }
 sed -e "s|@STD@|$PDK/libs.ref/sg13g2_stdcell|g" -e "s|@OUT@|$OUT|g" \
  "$ROOT/scripts/cadence/mmmc.tcl.in" > "$OUT/mmmc.tcl"
 innovus -no_gui -files "$ROOT/scripts/cadence/run_pnr.tcl" -log "$OUT/innovus.log"
else
 SCENARIO="${3:?Need tbec|mrsc|mixed}"
 VCD="$ROOT/results/vcd/${TOPARG}_${SCENARIO}_gls.vcd"
 [[ -s "$VCD" ]] || { echo "Run scripts/run_gls.sh $TOPARG $SCENARIO first; RTL VCD is not acceptable for post-layout mapped-cell power estimation" >&2;exit 3; }
 export SCENARIO VCD
 command -v innovus >/dev/null || { echo 'innovus not in PATH' >&2;exit 3; }
 innovus -no_gui -files "$ROOT/scripts/cadence/run_power.tcl" -log "$OUT/power_${SCENARIO}.log"
fi
