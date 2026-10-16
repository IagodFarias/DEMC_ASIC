# etapa3_sta.tcl - STA pos-layout nos 3 corners (slow/typ/fast)
# Cada corner e analisado sozinho (set_analysis_view), porque o Innovus
# poda as views "dominadas" quando todas estao ativas ao mesmo tempo.
set OUT reports_sta
file mkdir $OUT

restoreDesign ecc_design_route.enc.dat ecc_design

if {![file exists out/ecc_design.spef]} {
  puts "ERRO: out/ecc_design.spef nao encontrado. Rode antes a etapa2_extracao.tcl."
  exit 1
}
spefIn out/ecc_design.spef -rc_corner rc_lef

setAnalysisMode  -analysisType onChipVariation
setDelayCalMode  -SIAware true

set fd [open $OUT/resumo.txt w]
puts $fd "ecc_design - STA pos-layout (SPEF da tech LEF, SI ligado, OCV)"
puts $fd "Restricao: set_max_delay 5000 ns (entradas -> saidas)"
puts $fd ""
puts $fd [format "%-8s %18s %18s %14s" "corner" "atraso max (ns)" "atraso min (ns)" "slack (ns)"]

foreach v {av_slow av_typ av_fast} {
  set_analysis_view -setup [list $v] -hold [list $v]

  timeDesign -postRoute -outDir $OUT/timeDesign_$v -prefix $v
  report_timing -max_paths 10 -nworst 1 > $OUT/setup_$v.rpt
  catch {report_constraint -all_violators > $OUT/drv_$v.rpt}

  set dmax "?" ; set dmin "?" ; set slk "?"
  if {![catch {set p [report_timing -max_paths 1 -collection]}]} {
    catch {set dmax [format %.3f [get_property $p arrival]]}
    catch {set slk  [format %.3f [get_property $p slack]]}
  }
  if {![catch {report_timing -early -unconstrained -max_paths 5 \
                  -from [all_inputs] -to [all_outputs] > $OUT/min_$v.rpt}]} {
    if {![catch {set q [report_timing -early -unconstrained -max_paths 1 \
                          -from [all_inputs] -to [all_outputs] -collection]}]} {
      catch {set dmin [format %.3f [get_property $q arrival]]}
    }
  }
  puts $fd [format "%-8s %18s %18s %14s" $v $dmax $dmin $slk]
}

puts $fd ""
puts $fd "Violacoes de DRV por corner: drv_av_slow.rpt, drv_av_typ.rpt, drv_av_fast.rpt"
close $fd

puts "\n>> Etapa 3 concluida. Resumo:"
puts [exec cat $OUT/resumo.txt]
exit
