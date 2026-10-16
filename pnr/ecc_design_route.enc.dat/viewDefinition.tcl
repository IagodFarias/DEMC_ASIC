if {![namespace exists ::IMEX]} { namespace eval ::IMEX {} }
set ::IMEX::dataVar [file dirname [file normalize [info script]]]
set ::IMEX::libVar ${::IMEX::dataVar}/libs

create_library_set -name libs_fast\
   -timing\
    [list ${::IMEX::libVar}/mmmc/sg13g2_stdcell_fast_1p32V_m40C.lib]
create_library_set -name libs_slow\
   -timing\
    [list ${::IMEX::libVar}/mmmc/sg13g2_stdcell_slow_1p08V_125C.lib]
create_library_set -name libs_typ\
   -timing\
    [list ${::IMEX::libVar}/mmmc/sg13g2_stdcell_typ_1p20V_25C.lib]
create_rc_corner -name rc_lef\
   -preRoute_res 1\
   -postRoute_res 1\
   -preRoute_cap 1\
   -postRoute_cap 1\
   -postRoute_xcap 1\
   -preRoute_clkres 0\
   -preRoute_clkcap 0\
   -T 25
create_delay_corner -name dc_fast\
   -library_set libs_fast\
   -rc_corner rc_lef
create_delay_corner -name dc_slow\
   -library_set libs_slow\
   -rc_corner rc_lef
create_delay_corner -name dc_typ\
   -library_set libs_typ\
   -rc_corner rc_lef
create_constraint_mode -name cm_func\
   -sdc_files\
    [list /dev/null]
create_analysis_view -name av_fast -constraint_mode cm_func -delay_corner dc_fast
create_analysis_view -name av_slow -constraint_mode cm_func -delay_corner dc_slow
create_analysis_view -name av_typ -constraint_mode cm_func -delay_corner dc_typ
set_analysis_view -setup [list av_slow av_typ av_fast] -hold [list av_fast av_typ av_slow]
