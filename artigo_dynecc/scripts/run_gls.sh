#!/usr/bin/env bash
# Routed-netlist simulation with annotated SDF; outputs power-analysis VCD.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TOP="${1:?usage: scripts/run_gls.sh top scenario}"
SCENARIO="${2:?Need tbec|mrsc|mixed}"
case "$TOP" in mrsc_only|tbec_only|mux_reference|mux_isolated);;*)exit 2;;esac
case "$SCENARIO" in tbec|mrsc|mixed);;*)exit 2;;esac
if [[ "$TOP" == mrsc_only && "$SCENARIO" != mrsc ]] || [[ "$TOP" == tbec_only && "$SCENARIO" != tbec ]];then
 echo "Incompatible scenario" >&2;exit 2
fi
: "${PDK:?PDK path needed}"
command -v xrun >/dev/null || { echo "Gate-level SDF requires Cadence Xcelium (xrun)" >&2;exit 3; }
DUT="ecc_$TOP"
DIR="$ROOT/results/cadence/$DUT"
NET="$DIR/netlist_pnr.v"
SDF="$DIR/typ.sdf"
CELLS="$PDK/libs.ref/sg13g2_stdcell/verilog"
for f in "$NET" "$SDF" "$CELLS/sg13g2_udp.v" "$CELLS/sg13g2_stdcell.v";do
 [[ -s "$f" ]] || { echo "Missing or empty: $f" >&2;exit 3; }
done
mkdir -p "$ROOT/results/vcd" "$ROOT/results/logs"
VCD="$ROOT/results/vcd/${TOP}_${SCENARIO}_gls.vcd"
LOG="$ROOT/results/logs/${TOP}_${SCENARIO}_gls.log"
# The macro must expand to a quoted string literal for $sdf_annotate.
SDF_DEFINE="+define+SDF_FILE=\"${SDF}\""
xrun -64bit -sv -timescale 1ns/1ps -access +rwc -top tb_ecc_bench \
  "+define+DUT_MODULE=${DUT}" "$SDF_DEFINE" \
  "$CELLS/sg13g2_udp.v" "$CELLS/sg13g2_stdcell.v" \
  "$NET" "$ROOT/tb/tb_ecc_bench.sv" \
  "+SCENARIO=${SCENARIO}" "+VCD=${VCD}" -l "$LOG" | tee "${LOG%.log}_stdout.txt"
echo "CHECK in $LOG: SDF annotation warnings, unresolved cells, PASS, and VCD internal net toggling."
