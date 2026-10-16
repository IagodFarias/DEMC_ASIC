# =============================================================================
#  etapa4_export_gls.tcl - exporta netlist e SDF pos-layout para a simulacao
#                          gate-level (GLS)
#
#  Uso (dentro de pnr/), depois da etapa2_extracao.tcl:
#     innovus -no_gui -files etapa4_export_gls.tcl -log etapa4
#
#  Entradas: ecc_design_route.enc(.dat)  banco roteado (etapa2a_pnr.tcl)
#            out/ecc_design.spef         parasitas    (etapa2_extracao.tcl)
#
#  Saidas:   out/ecc_design_pnr.v        netlist pos-layout (sem fillers)
#            out/ecc_design_slow.sdf     atrasos pos-layout, corner slow
#            out/ecc_design_typ.sdf      atrasos pos-layout, corner typ
#            out/ecc_design_fast.sdf     atrasos pos-layout, corner fast
#
#  A netlist e os SDF saem do MESMO banco, entao os nomes de instancia batem.
#  Os SDF usam o SPEF extraido (mesmo calculo de atraso do STA da etapa 3).
# =============================================================================
set ROUTED_DB ecc_design_route.enc
set SPEF      out/ecc_design.spef
set OUT       out

foreach f [list ${ROUTED_DB}.dat $SPEF] {
  if {![file exists $f]} {
    puts "ERRO: '$f' nao encontrado. Rode antes etapa2a_pnr.tcl e etapa2_extracao.tcl."
    exit 1
  }
}
file mkdir $OUT

# --- 1. Restaura o banco e carrega os parasitas ------------------------------
restoreDesign ${ROUTED_DB}.dat ecc_design
spefIn $SPEF -rc_corner rc_lef

setAnalysisMode -analysisType onChipVariation
setDelayCalMode -SIAware true

# --- 2. Netlist pos-layout ---------------------------------------------------
# Celulas so fisicas (fill) ficam de fora por padrao; as tie (tiehi/tielo)
# sao logicas e entram, como devem.
saveNetlist $OUT/ecc_design_pnr.v -excludeLeafCell

# --- 3. Um SDF por corner ----------------------------------------------------
foreach {v nome} {av_slow slow av_typ typ av_fast fast} {
  set_analysis_view -setup [list $v] -hold [list $v]
  write_sdf -view $v -recompute_delay_calc -precision 4 \
            $OUT/ecc_design_${nome}.sdf
  puts ">> SDF gerado: $OUT/ecc_design_${nome}.sdf"
}

puts "\n>> Etapa 4 concluida: netlist e SDF pos-layout em $OUT/"
exit
