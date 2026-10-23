# Cadence Innovus 21.x example: place and route of each variant.
# Requires env TOP, OUT, PDK. Must be reviewed against lab's PDK and license.
set top $::env(TOP)
set out $::env(OUT)
set pdk $::env(PDK)
set std "$pdk/libs.ref/sg13g2_stdcell"
set init_verilog "$out/synth.v"
set init_top_cell $top
set init_design_netlisttype Verilog
set init_lef_file [list "$std/lef/sg13g2_tech.lef" "$std/lef/sg13g2_stdcell.lef"]
set init_mmmc_file "$out/mmmc.tcl"
set init_pwr_net VDD
set init_gnd_net VSS
init_design
setDesignMode -process 130
globalNetConnect VDD -type pgpin -pin VDD -inst * -override
globalNetConnect VSS -type pgpin -pin VSS -inst * -override
# Same floorplan policy across variants, rather than forcing identical die size.
floorPlan -site CoreSite -r 1.0 0.60 10.0 10.0 10.0 10.0
proc pins {name n} {
  set p {}
  for {set k 0} {$k<$n} {incr k} {lappend p "${name}\[$k\]"}
  return $p
}
setPinAssignMode -pinEditInBatch true
editPin -side Left -layer Metal3 -spreadType side -fixedPin 1 \
  -pin [concat [pins data_in_left 16] [pins data_out_left 16]]
editPin -side Top -layer Metal4 -spreadType side -fixedPin 1 \
  -pin [concat [pins data_in_right_up 16] [pins data_out_right_up 16]]
editPin -side Bottom -layer Metal4 -spreadType side -fixedPin 1 \
  -pin [concat [pins data_in_right_down 16] [pins data_out_right_down 16]]
editPin -side Right -layer Metal3 -spreadType side -fixedPin 1 \
  -pin [concat [pins sel 3] [pins flag 3] chip_sel [pins chip_sel_out 2]]
setPinAssignMode -pinEditInBatch false
addRing -nets {VDD VSS} -type core_rings -follow core \
 -layer {top Metal5 bottom Metal5 left Metal4 right Metal4} \
 -width {top 2 bottom 2 left 2 right 2} \
 -spacing {top 2 bottom 2 left 2 right 2} \
 -offset {top 2 bottom 2 left 2 right 2}
sroute -connect {corePin} -nets {VDD VSS} -corePinTarget {ring} \
 -layerChangeRange {Metal1 Metal5} -targetViaLayerRange {Metal1 Metal5} \
 -allowJogging 1 -allowLayerChange 1
setPlaceMode -place_global_place_io_pins false
placeDesign
setTieHiLoMode -cell {sg13g2_tiehi sg13g2_tielo} -maxFanout 8
addTieHiLo -cell {sg13g2_tiehi sg13g2_tielo}
optDesign -preCTS
# combinational block: no clock tree synthesis.
setDesignMode -topRoutingLayer Metal5
routeDesign
setAnalysisMode -analysisType onChipVariation
optDesign -postRoute
addFiller -cell {sg13g2_fill_8 sg13g2_fill_4 sg13g2_fill_2 sg13g2_fill_1} -prefix FILLER
verifyConnectivity -type all -report "$out/connectivity.rpt"
verify_drc -report "$out/drc.rpt"
verifyProcessAntenna -report "$out/antenna.rpt"
summaryReport -noHtml -outfile "$out/summary.rpt"
report_timing -max_paths 20 > "$out/timing_pnr.rpt"
report_constraint -all_violators > "$out/drv.rpt"
# Export matched gate-level netlist and SDF (derived from this same routed database).
# The exact extraction command can vary by Innovus release; check logs.
extractRC
rcOut -spef "$out/extracted.spef"
saveNetlist "$out/netlist_pnr.v" -excludeLeafCell
write_sdf -view av_typ -recompute_delay_calc -precision 4 "$out/typ.sdf"
saveDesign "$out/routed.enc"
# SPEF + GDS + signoff LVS optional; do not equate tool DRC with full signoff.
puts "PNR_OK $top $out"

exit
