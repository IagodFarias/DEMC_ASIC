# =============================================================================
#  etapa2a_pnr.tcl - refaz o Place & Route do ecc_design por script
#
#  O banco roteado original nao foi salvo; este script reproduz o layout
#  existente (parametros medidos no ecc_design_final.gds) e termina salvando
#  o banco usado nas etapas seguintes.
#
#  Uso (dentro de pnr/):
#     innovus -no_gui -files etapa2a_pnr.tcl -log etapa2a
#
#  Saidas:
#     ecc_design_route.enc(.dat)   banco roteado  -> entrada da etapa2_extracao.tcl
#     ecc_design_final_v2.gds      novo GDS (o antigo nao e sobrescrito)
#     reports_pnr/                 verificacoes do P&R
#
#  Parametros medidos no GDS original:
#     die 95.04 x 91.98 um, core 74.88 x 71.82 um (19 linhas), margem 10.08 um
#     aneis VDD/VSS: 2 um de largura, 2 um de espacamento, 2 um do core,
#                    Metal4 (verticais) e Metal5 (horizontais), sem stripes
#
#  Diferencas em relacao ao layout original (boas praticas, nao alteram a
#  logica):
#     - pinos de E/S nas camadas da direcao preferencial (Metal3 nas laterais,
#       Metal4 em cima/embaixo); no original todos estavam em Metal4
#     - celulas tie (sg13g2_tiehi/tielo) no RESET_B dos latches, em vez de
#       ligar a porta direto no VDD
#     - celulas de preenchimento (fill) nos espacos vazios das linhas, que
#       o original nao tinha e que o DRC de signoff (Etapa 6) exige
# =============================================================================
set PDK      /home/mateusmaia45/IHP-Open-PDK/ihp-sg13g2
set STD      $PDK/libs.ref/sg13g2_stdcell
set GDS_MAP  $PDK/libs.tech/klayout/tech/sg13g2.map
set STD_GDS  $STD/gds/sg13g2_stdcell.gds

# --- 0. Confere os arquivos de entrada antes de comecar ----------------------
set faltando {}
foreach f [list mmmc_postlayout.tcl ecc_design_synth.v ecc_design_synth.sdc \
                $STD/lef/sg13g2_tech.lef $STD/lef/sg13g2_stdcell.lef \
                $GDS_MAP $STD_GDS] {
  if {![file exists $f]} { lappend faltando $f }
}
if {[llength $faltando]} {
  puts "\nERRO: arquivos nao encontrados (rode o script de dentro de pnr/):"
  foreach f $faltando { puts "   - $f" }
  exit 1
}

file mkdir reports_pnr

setMultiCpuUsage -localCpu 4

# --- 1. Importacao -----------------------------------------------------------
set init_verilog           ecc_design_synth.v
set init_top_cell          ecc_design
set init_design_netlisttype Verilog
set init_design_settop     1
set init_lef_file          [list $STD/lef/sg13g2_tech.lef $STD/lef/sg13g2_stdcell.lef]
set init_mmmc_file         mmmc_postlayout.tcl   ;# corners slow/typ/fast
set init_pwr_net           VDD
set init_gnd_net           VSS
init_design

setDesignMode -process 130

globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override

checkDesign -netlist -noHtml -outfile reports_pnr/checkDesign_netlist.rpt

# --- 2. Floorplan (mesmas dimensoes do original) -----------------------------
floorPlan -site CoreSite -s 74.88 71.82 10.08 10.08 10.08 10.08

# --- 3. Pinos de E/S (mesmos lados do original) ------------------------------
proc bus {name n} {
  set l {}
  for {set i 0} {$i < $n} {incr i} { lappend l "${name}\[$i\]" }
  return $l
}
setPinAssignMode -pinEditInBatch true
editPin -side Left   -layer Metal3 -spreadType side -fixedPin 1 \
        -pin [concat [bus data_in_left 16] [bus data_out_left 16]]
editPin -side Top    -layer Metal4 -spreadType side -fixedPin 1 \
        -pin [concat [bus data_in_right_up 16] [bus data_out_right_up 16]]
editPin -side Bottom -layer Metal4 -spreadType side -fixedPin 1 \
        -pin [concat [bus data_in_right_down 16] [bus data_out_right_down 16]]
editPin -side Right  -layer Metal3 -spreadType side -fixedPin 1 \
        -pin [concat [bus sel 3] [bus flag 3] chip_sel [bus chip_sel_out 2]]
setPinAssignMode -pinEditInBatch false

# --- 4. Rede de alimentacao --------------------------------------------------
addRing -nets {VDD VSS} -type core_rings -follow core \
        -layer   {top Metal5 bottom Metal5 left Metal4 right Metal4} \
        -width   {top 2 bottom 2 left 2 right 2} \
        -spacing {top 2 bottom 2 left 2 right 2} \
        -offset  {top 2 bottom 2 left 2 right 2}

sroute -connect {corePin} -nets {VDD VSS} -corePinTarget {ring} \
       -layerChangeRange {Metal1 Metal5} -targetViaLayerRange {Metal1 Metal5} \
       -allowJogging 1 -allowLayerChange 1

# --- 5. Placement ------------------------------------------------------------
setPlaceMode -place_global_place_io_pins false
placeDesign

setTieHiLoMode -cell {sg13g2_tiehi sg13g2_tielo} -maxFanout 8
addTieHiLo     -cell {sg13g2_tiehi sg13g2_tielo}

optDesign -preCTS -outDir reports_pnr/timing_preCTS
checkPlace reports_pnr/checkPlace.rpt

# (sem CTS: o design e puramente combinacional)

# --- 6. Roteamento -----------------------------------------------------------
setDesignMode -topRoutingLayer Metal5
routeDesign
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute -outDir reports_pnr/timing_postRoute

# --- 7. Preenchimento das linhas ---------------------------------------------
addFiller -cell {sg13g2_fill_8 sg13g2_fill_4 sg13g2_fill_2 sg13g2_fill_1} -prefix FILLER

# --- 8. Verificacoes ---------------------------------------------------------
verifyConnectivity -type all -error 1000 -warning 50 -report reports_pnr/conn.rpt
verify_drc -limit 1000 -report reports_pnr/drc.rpt
verifyProcessAntenna -report reports_pnr/antenna.rpt
summaryReport -noHtml -outfile reports_pnr/summary.rpt

# --- 9. Salvamento -----------------------------------------------------------
saveDesign ecc_design_route.enc

streamOut ecc_design_final_v2.gds -mapFile $GDS_MAP -merge $STD_GDS \
          -libName ECC_DESIGN_LIB -units 1000 -mode ALL

puts "\n>> Etapa 2a concluida: ecc_design_route.enc salvo"
exit
