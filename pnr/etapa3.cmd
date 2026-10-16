#######################################################
#                                                     
#  Innovus Command Logging File                     
#  Created on Tue Sep 29 22:24:17 2026                
#                                                     
#######################################################

#@(#)CDS: Innovus v21.15-s110_1 (64bit) 09/23/2022 13:08 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: NanoRoute 21.15-s110_1 NR220912-2004/21_15-UB (database version 18.20.592) {superthreading v2.17}
#@(#)CDS: AAE 21.15-s039 (64bit) 09/23/2022 (Linux 3.10.0-693.el7.x86_64)
#@(#)CDS: CTE 21.15-s038_1 () Sep 20 2022 11:42:13 ( )
#@(#)CDS: SYNTECH 21.15-s012_1 () Sep  5 2022 10:25:51 ( )
#@(#)CDS: CPE v21.15-s076
#@(#)CDS: IQuantus/TQuantus 21.1.1-s867 (64bit) Sun Jun 26 22:12:54 PDT 2022 (Linux 3.10.0-693.el7.x86_64)

set_global _enable_mmmc_by_default_flow      $CTE::mmmc_default
suppressMessage ENCEXT-2799
getVersion
restoreDesign ecc_design_route.enc.dat ecc_design
spefIn out/ecc_design.spef -rc_corner rc_lef
setAnalysisMode -analysisType onChipVariation
setDelayCalMode -SIAware true
timeDesign -postRoute -outDir reports_sta/timeDesign -prefix postlayout
report_timing -view $v -max_paths 10 -nworst 1 > $OUT/setup_$v.rpt
report_timing -view $v -max_paths 1 -collection
report_timing -view $v -early -unconstrained -max_paths 5  -from [all_inputs] -to [all_outputs] > $OUT/min_$v.rpt
report_timing -view $v -early -unconstrained -max_paths 1  -from [all_inputs] -to [all_outputs] -collection
report_timing -view $v -max_paths 10 -nworst 1 > $OUT/setup_$v.rpt
report_timing -view $v -max_paths 1 -collection
report_timing -view $v -early -unconstrained -max_paths 5  -from [all_inputs] -to [all_outputs] > $OUT/min_$v.rpt
report_timing -view $v -early -unconstrained -max_paths 1  -from [all_inputs] -to [all_outputs] -collection
report_timing -view $v -max_paths 10 -nworst 1 > $OUT/setup_$v.rpt
report_timing -view $v -max_paths 1 -collection
report_timing -view $v -early -unconstrained -max_paths 5  -from [all_inputs] -to [all_outputs] > $OUT/min_$v.rpt
report_timing -view $v -early -unconstrained -max_paths 1  -from [all_inputs] -to [all_outputs] -collection
report_constraint -all_violators > reports_sta/drv_violacoes.rpt
report_constraint -all_violators -view av_slow > reports_sta/drv_av_slow.rpt
report_constraint -all_violators -view av_typ > reports_sta/drv_av_typ.rpt
report_constraint -all_violators -view av_fast > reports_sta/drv_av_fast.rpt
