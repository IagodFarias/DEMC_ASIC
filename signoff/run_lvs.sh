#!/usr/bin/env bash
# =============================================================================
#  signoff/run_lvs.sh - LVS do GDS contra a netlist pos-layout (KLayout, IHP)
#
#  Uso (de qualquer pasta):
#     signoff/run_lvs.sh
#
#  Variaveis de ambiente:
#     PDK_ROOT   raiz do IHP-Open-PDK (obrigatoria)
#     GDS        layout       (padrao: pnr/ecc_design_final_v2.gds)
#     NETLIST    netlist .v   (padrao: pnr/out/ecc_design_pnr.v)
#     TOP        celula top   (padrao: ecc_design)
#
#  O GDS e a netlist precisam sair do MESMO banco do Innovus
#  (etapa2a_pnr.tcl gera o GDS; etapa4_export_gls.tcl, a netlist).
#
#  Passos:
#   1. signoff/v2spice.py converte a netlist Verilog em SPICE, usando a
#      ordem de pinos do CDL das standard cells (sg13g2_stdcell.cdl).
#   2. run_lvs.py do PDK extrai o layout e compara com essa netlist,
#      inclusive os rotulos dos pinos de topo (modo estrito do PDK).
#
#  Saidas: signoff/runs/lvs/ (netlist SPICE, netlist extraida, .lvsdb para
#          abrir no KLayout: Tools > Netlist Browser, e o log).
#  Retorna 0 so se as netlists baterem (o run_lvs.py do PDK retorna 0
#  mesmo quando a comparacao falha, entao o resultado e lido do log).
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GDS="${GDS:-$ROOT/pnr/ecc_design_final_v2.gds}"
NETLIST="${NETLIST:-$ROOT/pnr/out/ecc_design_pnr.v}"
TOP="${TOP:-ecc_design}"
DIR="$ROOT/signoff/runs/lvs"

[[ -n "${PDK_ROOT:-}" ]] || { echo "ERRO: defina PDK_ROOT (raiz do IHP-Open-PDK)"; exit 1; }
P="$PDK_ROOT/ihp-sg13g2"
RUN_LVS="$P/libs.tech/klayout/tech/lvs/run_lvs.py"
CDL="$P/libs.ref/sg13g2_stdcell/cdl/sg13g2_stdcell.cdl"
for f in "$RUN_LVS" "$CDL" "$GDS" "$NETLIST"; do
  [[ -f "$f" ]] || { echo "ERRO: arquivo nao encontrado: $f"; exit 1; }
done
command -v klayout >/dev/null || { echo "ERRO: klayout nao esta no PATH"; exit 1; }

rm -rf "$DIR"; mkdir -p "$DIR"
abs() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }

echo ">> LVS: $(basename "$GDS") x $(basename "$NETLIST") (top $TOP)"
python3 "$ROOT/signoff/v2spice.py" "$NETLIST" "$CDL" "$DIR/${TOP}.cir" --top "$TOP" || exit 1

python3 "$RUN_LVS" --layout="$(abs "$GDS")" --netlist="$DIR/${TOP}.cir" \
        --topcell="$TOP" --run_dir="$DIR" --run_mode=deep > "$DIR/run_lvs.log" 2>&1

grep -E "\| (Status|Outcome|Errors) " "$DIR/run_lvs.log" | sed 's/^.*INFO *| //'
if grep -q "Comparison mode: PASS" "$DIR/run_lvs.log"; then
  echo "   PASSOU   (log: ${DIR#$ROOT/}/run_lvs.log)"
  exit 0
fi
echo "   FALHOU   (veja ${DIR#$ROOT/}/run_lvs.log e abra o .lvsdb no KLayout)"
grep -E "ERROR" "$DIR/run_lvs.log" | head -5
exit 1
