#!/usr/bin/env bash
# Equivalencia do RTL do pacote DYNECC com o RTL original do repositorio (modos 000..011).
# Uso (dentro de artigo_dynecc):
#   SIM=xrun scripts/run_equiv.sh [pasta_do_rtl_original]      (padrao: ../rtl)
#   PLUSARGS="+NWORDS=2048 +NRAND=500000" SIM=xrun scripts/run_equiv.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ORIG="$(cd "${1:-$ROOT/../rtl}" && pwd)"
OUT="$ROOT/results/equiv"
mkdir -p "$OUT/orig" "$ROOT/results/logs"
# Os modulos originais tem os mesmos nomes dos novos: copia com sufixo _orig.
MODS='ecc_design|TBEC_RSC_encoder|TBEC_RSC_decoder|MRSC_encoder|MRSC_decoder'
for f in ecc_design TBEC_RSC_encoder TBEC_RSC_decoder MRSC_encoder MRSC_decoder; do
  [[ -s "$ORIG/$f.sv" ]] || { echo "Falta $ORIG/$f.sv" >&2; exit 3; }
  sed -E "s/\b($MODS)\b/\1_orig/g" "$ORIG/$f.sv" > "$OUT/orig/${f}_orig.sv"
done
SRC=("$OUT"/orig/*_orig.sv "$ROOT"/rtl/common/*.sv "$ROOT"/rtl/top/*.sv "$ROOT/tb/tb_equiv.sv")
LOG="$ROOT/results/logs/equiv.log"
read -r -a PA <<< "${PLUSARGS:-}"
SIM="${SIM:-xrun}"
if [[ "$SIM" == xrun ]]; then
  command -v xrun >/dev/null || { echo "xrun nao encontrado" >&2; exit 3; }
  if ! xrun -64bit -sv -timescale 1ns/1ps -xmlibdirname "$ROOT/xcelium.d_equiv" -top tb_equiv \
       "${SRC[@]}" ${PA[@]+"${PA[@]}"} -l "$LOG" > "$OUT/xrun_stdout.txt" 2>&1; then
    echo "xrun falhou; ultimas linhas:" >&2; tail -30 "$OUT/xrun_stdout.txt" >&2; exit 4
  fi
elif [[ "$SIM" == iverilog ]]; then
  # o Icarus emite "sorry: constant selects in always_*" (limitacao de sensibilidade, inofensiva)
  iverilog -g2012 -s tb_equiv -o "$OUT/equiv.vvp" "${SRC[@]}" 2>&1 | { grep -v "sorry: constant selects" || true; }
  [[ ${PIPESTATUS[0]} -eq 0 ]] || { echo "iverilog falhou" >&2; exit 4; }
  vvp "$OUT/equiv.vvp" ${PA[@]+"${PA[@]}"} > "$LOG"
else
  echo "SIM=xrun ou SIM=iverilog" >&2; exit 3
fi
sed -n '/^DIVERGE/p;/^EQUIVALENCIA/,/^EQUIV_/p' "$LOG" || true
grep -q EQUIV_PASS "$LOG"
