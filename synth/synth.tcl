# =============================================================================
#  synth/synth.tcl - sintese logica do ecc_design (Cadence Genus)
#
#  Uso (dentro de synth/):
#     export PDK_ROOT=$HOME/IHP-Open-PDK
#     genus -batch -files synth.tcl -log genus
#  ou, da raiz do repositorio:  make synth
#
#  Entradas: ../rtl/*.sv, ../constraints/ecc_design.sdc, PDK em $PDK_ROOT
#  Saidas (entrada do Innovus, mesmos nomes que pnr/etapa2a_pnr.tcl espera):
#     ../pnr/ecc_design_synth.v     netlist mapeada
#     ../pnr/ecc_design_synth.sdc   restricoes expandidas pelo Genus
#     ../pnr/ecc_design_synth.sdf   atrasos pre-layout (GLS pre-layout)
#  Relatorios: reports/
#
#  A sintese usa a biblioteca do corner SLOW (1.08 V / 125 C): e o corner
#  que limita o setup, entao o Genus ja otimiza para o pior caso. O P&R
#  confere depois os tres corners (mmmc_postlayout.tcl).
# =============================================================================
source ../scripts/pdk.tcl

set DESIGN  ecc_design
set RTL_DIR ../rtl
set RTL     {MRSC_encoder.sv MRSC_decoder.sv TBEC_RSC_encoder.sv TBEC_RSC_decoder.sv ecc_design.sv}
set SDC     ../constraints/ecc_design.sdc
set OUT     ../pnr
set RPT     reports

file mkdir $RPT

# --- 1. Bibliotecas ----------------------------------------------------------
set_db init_lib_search_path $LIB_DIR
set_db library              $LIB_SLOW
set_db lef_library          [list $LEF_TECH $LEF_CELL]

# --- 2. RTL e elaboracao -----------------------------------------------------
set_db init_hdl_search_path $RTL_DIR
read_hdl -sv $RTL
elaborate $DESIGN
check_design -unresolved > $RPT/check_design_elab.rpt

# --- 3. Restricoes (antes de qualquer otimizacao) ----------------------------
read_sdc $SDC
catch {check_timing_intent > $RPT/check_timing_intent.rpt}

# --- 4. Sintese (uma unica passada) ------------------------------------------
syn_generic   ;# otimizacao independente de tecnologia
syn_map       ;# mapeamento para as standard cells sg13g2
syn_opt       ;# otimizacao de timing/area/DRV na tecnologia

# --- 5. Relatorios -----------------------------------------------------------
report_timing -max_paths 10 > $RPT/timing.rpt
report_area                 > $RPT/area.rpt
report_gates                > $RPT/gates.rpt
report_power                > $RPT/power.rpt
report_qor                  > $RPT/qor.rpt
check_design -all           > $RPT/check_design.rpt

# --- 6. Exportacao para o Innovus --------------------------------------------
write_hdl > $OUT/${DESIGN}_synth.v
write_sdc > $OUT/${DESIGN}_synth.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge \
          > $OUT/${DESIGN}_synth.sdf

# --- 7. Conferencias rapidas -------------------------------------------------
# Latches nao sao esperados num bloco combinacional: avisa se aparecerem.
set fd [open $OUT/${DESIGN}_synth.v r]; set net [read $fd]; close $fd
set n_latch [regexp -all {\msg13g2_dl[a-z0-9_]*\M} $net]
if {$n_latch > 0} {
  puts "\nAVISO: $n_latch latch(es) na netlist sintetizada (sg13g2_dl*)."
  puts "       Confira atribuicoes incompletas em always_comb."
}

if {[catch {set wns [get_db designs .slack]}]} { set wns "?" }
puts "\n>> Sintese concluida: $OUT/${DESIGN}_synth.v"
puts ">> Pior slack (corner slow, pre-layout, unidade interna do Genus): $wns"
puts ">> Relatorios em synth/$RPT/"
exit
