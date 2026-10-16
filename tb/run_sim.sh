#!/usr/bin/env bash
# =============================================================================
#  run_sim.sh - simulacao RTL e gate-level (GLS) do ecc_design + comparacao
#
#  Uso (de qualquer pasta):
#     tb/run_sim.sh rtl              simulacao RTL (gera o arquivo de referencia)
#     tb/run_sim.sh gls0             netlist pos-layout, sem atrasos
#     tb/run_sim.sh gls slow         netlist pos-layout + SDF do corner slow
#     tb/run_sim.sh gls typ|fast     idem, outros corners
#     tb/run_sim.sh all              rtl + gls0 + gls nos 3 corners + comparacao
#     tb/run_sim.sh compare          so compara os vetores ja gerados
#
#  Variaveis de ambiente opcionais:
#     SIM=xrun|iverilog   simulador (padrao xrun; iverilog nao anota SDF)
#     PDK=<caminho>       raiz do ihp-sg13g2
#     T_SETTLE=<ns>       espera por vetor (padrao 10; o pior atraso medido
#                         no STA e 3.9 ns no slow, entao 5 ainda deve passar)
#
#  Saidas em sim/:  <run>.log, vectors_<run>.txt, vectors_undef_<run>.txt,
#                   comparacao.txt
#
#  Pre-requisito do GLS: pnr/out/ecc_design_pnr.v e pnr/out/ecc_design_*.sdf,
#  gerados por pnr/etapa4_export_gls.tcl.
# =============================================================================
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SIMDIR="$ROOT/sim"
SIM="${SIM:-xrun}"
PDK="${PDK:-/home/mateusmaia45/IHP-Open-PDK/ihp-sg13g2}"
T_SETTLE="${T_SETTLE:-10}"

CELLS=("$PDK/libs.ref/sg13g2_stdcell/verilog/sg13g2_udp.v"
       "$PDK/libs.ref/sg13g2_stdcell/verilog/sg13g2_stdcell.v")
RTL=("$ROOT/rtl/TBEC_RSC_encoder.sv" "$ROOT/rtl/TBEC_RSC_decoder.sv"
     "$ROOT/rtl/MRSC_encoder.sv"     "$ROOT/rtl/MRSC_decoder.sv"
     "$ROOT/rtl/ecc_design.sv")
NET="$ROOT/pnr/out/ecc_design_pnr.v"
TB="$ROOT/tb/tb_ecc_design.sv"

mkdir -p "$SIMDIR"
cd "$SIMDIR" || exit 1

need() { for f in "$@"; do [[ -f "$f" ]] || { echo "ERRO: falta $f"; exit 1; }; done; }

# roda <nome> <defines...> -- <fontes...>
roda() {
  local nome="$1"; shift
  local defs=() srcs=()
  while [[ "$1" != "--" ]]; do defs+=("$1"); shift; done; shift
  srcs=("$@")
  defs+=("VEC_FILE=\"vectors_${nome}.txt\""
         "VEC_FILE_UNDEF=\"vectors_undef_${nome}.txt\""
         "T_SETTLE=${T_SETTLE}")

  echo ">> [$nome] simulando com $SIM ..."
  if [[ "$SIM" == "xrun" ]]; then
    local args=(-sv -access +r -timescale 1ns/1ps -xmlibdirname "xcelium.d_$nome"
                -l "$nome.log" -nocopyright)
    for d in "${defs[@]}"; do args+=("+define+$d"); done
    [[ " ${defs[*]} " != *SDF_FILE* && "$nome" != rtl ]] && args+=(-nospecify -notimingchecks)
    xrun "${args[@]}" "${srcs[@]}" > /dev/null
  else
    [[ " ${defs[*]} " == *SDF_FILE* ]] && { echo "   iverilog nao anota SDF; use SIM=xrun"; return 1; }
    local args=(-g2012 -o "$nome.vvp")
    for d in "${defs[@]}"; do args+=("-D$d"); done
    iverilog "${args[@]}" "${srcs[@]}" > "$nome.comp.log" 2>&1 || { tail "$nome.comp.log"; return 1; }
    vvp -n "$nome.vvp" > "$nome.log" 2>&1
  fi
  sed -n '/RESUMO/,/RESULTADO/p' "$nome.log"
  grep -q "RESULTADO: PASSOU" "$nome.log"
}

run_rtl()  { need "${RTL[@]}" "$TB"; roda rtl -- "${RTL[@]}" "$TB"; }
run_gls0() { need "${CELLS[@]}" "$NET" "$TB"; roda gls0 GATE -- "${CELLS[@]}" "$NET" "$TB"; }
run_gls()  {
  local c="$1" sdf="$ROOT/pnr/out/ecc_design_$1.sdf"
  need "${CELLS[@]}" "$NET" "$TB" "$sdf"
  roda "gls_$c" GATE "SDF_FILE=\"$sdf\"" -- "${CELLS[@]}" "$NET" "$TB"
}

# Compara cada run com o RTL. A coluna flag fica de fora: vem de latches sem
# reset e e "limitacao conhecida" no testbench. Os modos 100-111 (sinais sem
# driver) so sao reportados, nao reprovam.
compare() {
  local ref=vectors_rtl.txt ok=0
  [[ -f "$ref" ]] || { echo "ERRO: rode antes 'rtl'"; return 1; }
  local tira='s/ flag=.*//'
  {
    echo "Comparacao de vetores contra o RTL ($(date '+%d/%m/%Y %H:%M'))"
    echo "Coluna flag ignorada (latches sem reset); T_SETTLE=${T_SETTLE} ns"
    echo
    for f in vectors_gls*.txt; do
      [[ -f "$f" ]] || continue
      local n; n=$(diff <(sed "$tira" "$ref") <(sed "$tira" "$f") | grep -c '^<')
      local u; u=$(diff <(sed "$tira" vectors_undef_rtl.txt) \
                        <(sed "$tira" "vectors_undef_${f#vectors_}") 2>/dev/null | grep -c '^<')
      printf "%-22s %6d vetores divergentes   (modos 100-111: %d, so informativo)\n" "$f" "$n" "$u"
      [[ "$n" -eq 0 ]] || ok=1
    done
    echo
    [[ $ok -eq 0 ]] && echo "RESULTADO: pos-layout IDENTICO ao RTL" \
                    || echo "RESULTADO: HA DIVERGENCIAS (veja: diff vectors_rtl.txt vectors_gls_<corner>.txt)"
  } | tee comparacao.txt
  return $ok
}

case "${1:-}" in
  rtl)     run_rtl ;;
  gls0)    run_gls0 ;;
  gls)     run_gls "${2:?informe o corner: slow, typ ou fast}" ;;
  compare) compare ;;
  all)     run_rtl && run_gls0
           for c in slow typ fast; do run_gls "$c"; done
           compare ;;
  *)       sed -n '2,24p' "$0"; exit 1 ;;
esac
