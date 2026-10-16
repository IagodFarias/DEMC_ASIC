#!/usr/bin/env bash
# =============================================================================
#  signoff/run_drc.sh - DRC de signoff do GDS com o deck KLayout do IHP SG13G2
#
#  Uso (de qualquer pasta):
#     signoff/run_drc.sh                 regras principais (sem densidade)
#     signoff/run_drc.sh density         so as regras de densidade (informativo)
#     signoff/run_drc.sh antenna         so as regras de antena
#     signoff/run_drc.sh all             principal + densidade + antena
#
#  Variaveis de ambiente:
#     PDK_ROOT   raiz do IHP-Open-PDK (obrigatoria)
#     GDS        GDS a verificar   (padrao: pnr/ecc_design_final_v2.gds)
#     TOP        celula top        (padrao: ecc_design)
#     JOBS       processos do KLayout (padrao: numero de CPUs)
#
#  Requisitos: KLayout (binario) e o modulo Python 'klayout' nas versoes
#  pedidas pelo PDK (arquivo versions.txt na raiz do IHP-Open-PDK).
#
#  Saidas: signoff/runs/drc_<modo>/  (banco .lyrdb para abrir no KLayout:
#          Tools > Marker Browser) e o log da rodada.
#
#  Sobre densidade: as regras Mx.j/TMx.c pedem densidade minima de metal
#  no chip. Um bloco isolado sem metal fill sempre falha nelas; elas so
#  fazem sentido no top-level depois do fill. Por isso o modo padrao as
#  deixa de fora e o modo 'density' e so informativo.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODO="${1:-main}"
GDS="${GDS:-$ROOT/pnr/ecc_design_final_v2.gds}"
TOP="${TOP:-ecc_design}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 1)}"

[[ -n "${PDK_ROOT:-}" ]] || { echo "ERRO: defina PDK_ROOT (raiz do IHP-Open-PDK)"; exit 1; }
RUN_DRC="$PDK_ROOT/ihp-sg13g2/libs.tech/klayout/tech/drc/run_drc.py"
[[ -f "$RUN_DRC" ]] || { echo "ERRO: nao encontrei $RUN_DRC"; exit 1; }
[[ -f "$GDS" ]]     || { echo "ERRO: GDS nao encontrado: $GDS"; exit 1; }
command -v klayout >/dev/null || { echo "ERRO: klayout nao esta no PATH"; exit 1; }
GDS="$(cd "$(dirname "$GDS")" && pwd)/$(basename "$GDS")"

roda() {   # roda <nome> <opcoes do run_drc.py...>
  local nome="$1"; shift
  local dir="$ROOT/signoff/runs/drc_$nome"
  rm -rf "$dir"; mkdir -p "$dir"
  echo ">> DRC [$nome]: $(basename "$GDS") (top $TOP)"
  python3 "$RUN_DRC" --path="$GDS" --topcell="$TOP" --run_dir="$dir" \
          --run_mode=deep --density_thr="$JOBS" "$@" > "$dir/run_drc.log" 2>&1
  local rc=$?
  grep -E "Violated rules|Check Passed|Check Failed" "$dir/run_drc.log" | sed 's/^.*| //'
  if [[ $rc -eq 0 ]]; then
    echo "   PASSOU   (log: ${dir#$ROOT/}/run_drc.log)"
  else
    echo "   FALHOU   (log: ${dir#$ROOT/}/run_drc.log; marcadores: ${dir#$ROOT/}/*.lyrdb)"
  fi
  return $rc
}

case "$MODO" in
  main)    roda main --no_density ;;
  density) roda density --density_only ;;
  antenna) roda antenna --antenna_only ;;
  all)     st=0
           roda main --no_density || st=1
           roda antenna --antenna_only || st=1
           roda density --density_only || echo "   (densidade: informativo em bloco sem fill)"
           exit $st ;;
  *)       sed -n '2,30p' "$0"; exit 1 ;;
esac
