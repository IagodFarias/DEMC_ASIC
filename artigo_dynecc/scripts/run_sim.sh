#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TOP="${1:?usage: scripts/run_sim.sh <mrsc_only|tbec_only|mux_reference|mux_isolated> <tbec|mrsc|mixed> [bench|faults]}"
SCENARIO="${2:?missing scenario}"
TEST="${3:-bench}"
case "$TOP" in mrsc_only|tbec_only|mux_reference|mux_isolated);; *) echo "Bad TOP $TOP" >&2;exit 2;; esac
case "$SCENARIO" in tbec|mrsc|mixed);; *) echo "Bad scenario $SCENARIO" >&2;exit 2;; esac
if [[ "$TOP" == mrsc_only && "$SCENARIO" != mrsc ]] || [[ "$TOP" == tbec_only && "$SCENARIO" != tbec ]]; then
 echo "Incompatible top/scenario" >&2;exit 2
fi
if [[ "$TEST" == faults && "$SCENARIO" == mixed ]]; then echo "fault test needs single mode" >&2;exit 2;fi
case "$TEST" in bench|faults);;*) exit 2;;esac
mkdir -p "$ROOT/results/vcd" "$ROOT/results/logs"
DUT="ecc_${TOP}"
SRC=("$ROOT"/rtl/common/*.sv "$ROOT/rtl/top/${DUT}.sv")
TB="$ROOT/tb/tb_ecc_${TEST}.sv"
[[ "$TEST" == faults ]] && TB="$ROOT/tb/tb_faults.sv"
[[ "$TEST" == bench ]] && TB="$ROOT/tb/tb_ecc_bench.sv"
VCD="$ROOT/results/vcd/${TOP}_${SCENARIO}.vcd"
LOG="$ROOT/results/logs/${TOP}_${SCENARIO}_${TEST}.log"
DEFINES=("DUT_MODULE=${DUT}")
[[ "$TEST" == faults && "$SCENARIO" == tbec ]] && DEFINES+=("TBEC_MODE")
SIM="${SIM:-xrun}"
if [[ "$SIM" == xrun ]]; then
  command -v xrun >/dev/null || { echo "xrun not found; set SIM=iverilog or use student's Cadence installation" >&2; exit 3; }
  args=(-64bit -sv -timescale 1ns/1ps -top "tb_ecc_$TEST")
  [[ "$TEST" == faults ]] && args=(-64bit -sv -timescale 1ns/1ps -top tb_faults)
  for def in "${DEFINES[@]}";do args+=("+define+$def");done
  xrun "${args[@]}" "${SRC[@]}" "$TB" "+SCENARIO=$SCENARIO" "+VCD=$VCD" -l "$LOG" | tee "${LOG%.log}_stdout.txt"
elif [[ "$SIM" == iverilog ]];then
  command -v iverilog >/dev/null || { echo "iverilog not installed" >&2; exit 3; }
  OUT="$ROOT/results/logs/${TOP}_${SCENARIO}_${TEST}.vvp"
  args=(-g2012 -s tb_ecc_bench -o "$OUT")
  [[ "$TEST" == faults ]] && args=(-g2012 -s tb_faults -o "$OUT")
  for def in "${DEFINES[@]}";do args+=("-D$def");done
  iverilog "${args[@]}" "${SRC[@]}" "$TB"
  vvp "$OUT" "+SCENARIO=$SCENARIO" "+VCD=$VCD" | tee "$LOG"
else
  echo "Set SIM=xrun or SIM=iverilog" >&2;exit 3
fi
