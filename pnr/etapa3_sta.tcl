# etapa3_sta.tcl - STA pos-layout nos 3 corners (slow/typ/fast)
# Cada corner e analisado sozinho (set_analysis_view), porque o Innovus
# poda as views "dominadas" quando todas estao ativas ao mesmo tempo.
#
# Restricoes: relogio virtual + atrasos/carga de E/S de
# constraints/ecc_design.sdc (via ecc_design_synth.sdc). A "chegada" de um
# caminho ja inclui o atraso de entrada; o slack e o numero que importa.
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
puts $fd "Restricoes: constraints/ecc_design.sdc (relogio virtual vclk, E/S com driver e carga)"
puts $fd ""
puts $fd [format "%-8s %20s %18s %18s" "corner" "chegada max (ns)" "slack setup (ns)" "slack hold (ns)"]

foreach v {av_slow av_typ av_fast} {
  set_analysis_view -setup [list $v] -hold [list $v]

  timeDesign -postRoute -outDir $OUT/timeDesign_$v -prefix $v
  report_timing -max_paths 10 -nworst 1 > $OUT/setup_$v.rpt
  catch {report_constraint -all_violators > $OUT/drv_$v.rpt}

  catch {report_timing -early -max_paths 10 -nworst 1 > $OUT/hold_$v.rpt}

  set dmax "?" ; set slk "?" ; set hslk "?"
  if {![catch {set p [report_timing -max_paths 1 -collection]}]} {
    catch {set dmax [format %.3f [get_property $p arrival]]}
    catch {set slk  [format %.3f [get_property $p slack]]}
  }
  if {![catch {set q [report_timing -early -max_paths 1 -collection]}]} {
    catch {set hslk [format %.3f [get_property $q slack]]}
  }
  puts $fd [format "%-8s %20s %18s %18s" $v $dmax $slk $hslk]
}

puts $fd ""
puts $fd "Violacoes de DRV por corner: drv_av_slow.rpt, drv_av_typ.rpt, drv_av_fast.rpt"
close $fd

puts "\n>> Etapa 3 concluida. Resumo:"
puts [exec cat $OUT/resumo.txt]
exit
