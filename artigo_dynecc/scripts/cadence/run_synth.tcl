# Cadence Genus 21.x template. Requires env TOP, ROOT, OUT, PDK.
# NOTE: this synthesizes one candidate at a time under identical constraints.
set top $::env(TOP)
set root $::env(ROOT)
set out $::env(OUT)
set pdk $::env(PDK)
file mkdir $out
set std "$pdk/libs.ref/sg13g2_stdcell"
set lib "$std/lib/sg13g2_stdcell_typ_1p20V_25C.lib"
set techlef "$std/lef/sg13g2_tech.lef"
set celllef "$std/lef/sg13g2_stdcell.lef"
foreach f [list $lib $techlef $celllef] {
  if {![file exists $f]} {error "Missing PDK file: $f"}
}
set_db init_lib_search_path "$std/lib"
set_db library [list $lib]
set_db lef_library [list $techlef $celllef]
read_hdl -sv [glob "$root/rtl/common/*.sv"]
read_hdl -sv "$root/rtl/top/$top.sv"
elaborate $top
# Use documented reference timing target; do not confuse it with measured delay.
read_sdc "$root/constraints/dynecc.sdc"
syn_generic
syn_map
syn_opt
report_area > "$out/area.rpt"
report_timing > "$out/timing.rpt"
# This estimate uses default activity, NOT the scenario-specific power measurement.
report_power > "$out/power_default_activity_NON_COMPARATIVE.rpt"
write_hdl > "$out/synth.v"
write_sdc > "$out/synth.sdc"
puts "SYNTH_OK $top $out"
