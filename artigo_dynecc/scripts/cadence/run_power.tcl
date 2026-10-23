# IMPORTANT: Cadence power-analysis command variants differ by installed version.
# This script is a suggested starting point and MUST be validated at the lab.
# It aborts on failed VCD import, rather than silently using default activity.
set top $::env(TOP)
set out $::env(OUT)
set scenario $::env(SCENARIO)
set vcd $::env(VCD)
if {![file exists $vcd] || [file size $vcd]<100} {error "VCD missing/empty: $vcd"}
restoreDesign "$out/routed.enc.dat" $top
set_power_analysis_mode -method static -handle_glitch false
# Observe path inside VCD: tb_ecc_bench.dut. Adjust this scope if needed.
if {[catch {read_activity_file -format VCD -scope tb_ecc_bench/dut -start 335ns -end 7835ns $vcd} detail]} {
  error "Could not import $vcd: $detail. Check scope and Innovus read_activity_file syntax."
}
report_power -outfile "$out/power_${scenario}.rpt"
puts "POWER_IMPORTED top=$top scenario=$scenario source=$vcd"
# Check log for VCD annotation coverage; non-annotated nets invalidate comparisons.

exit
