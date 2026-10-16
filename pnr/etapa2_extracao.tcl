# =============================================================================
#  etapa2_extracao.tcl - extracao de parasitas do layout roteado
#
#  Uso (dentro de pnr/), depois do etapa2a_pnr.tcl:
#     innovus -no_gui -files etapa2_extracao.tcl -log etapa2
#
#  Entrada: ecc_design_route.enc(.dat), gerado pelo etapa2a_pnr.tcl
#           (os corners slow/typ/fast ja vem dentro do banco)
#  Saida:   out/ecc_design.spef
# =============================================================================
set ROUTED_DB ecc_design_route.enc
set OUT       out

file mkdir $OUT
file mkdir reports_postlayout

# --- 1. Restaura o design ja roteado -----------------------------------------
if {![file exists ${ROUTED_DB}.dat]} {
  puts "ERRO: banco '${ROUTED_DB}.dat' nao encontrado. Rode antes o etapa2a_pnr.tcl."
  exit 1
}
restoreDesign ${ROUTED_DB}.dat ecc_design

# --- 2. Extracao RC (motor nativo, R/C da tech LEF) --------------------------
setDesignMode    -process 130
setExtractRCMode -engine postRoute -effortLevel low
extractRC

# --- 3. SPEF (entrada para STA e para o SDF da Etapa 4) ----------------------
rcOut -spef $OUT/ecc_design.spef -rc_corner rc_lef

# --- 4. Conferencia do design restaurado -------------------------------------
checkDesign -all -noHtml -outfile reports_postlayout/checkDesign.rpt

puts "\n>> Etapa 2 concluida: $OUT/ecc_design.spef"
exit
