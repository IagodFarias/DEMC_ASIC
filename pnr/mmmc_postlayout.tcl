# Corners pos-layout: slow (1.08V/125C), typ (1.20V/25C), fast (1.32V/-40C)
# RC unico: o PDK nao traz QRC/captable; a extracao usa o R/C da tech LEF.
# Caminhos do PDK vindos de PDK_ROOT (scripts/pdk.tcl).
source ../scripts/pdk.tcl

create_library_set -name libs_slow -timing [list $LIB_DIR/$LIB_SLOW]
create_library_set -name libs_typ  -timing [list $LIB_DIR/$LIB_TYP]
create_library_set -name libs_fast -timing [list $LIB_DIR/$LIB_FAST]

create_rc_corner -name rc_lef -T 25

create_delay_corner -name dc_slow -library_set libs_slow -rc_corner rc_lef
create_delay_corner -name dc_typ  -library_set libs_typ  -rc_corner rc_lef
create_delay_corner -name dc_fast -library_set libs_fast -rc_corner rc_lef

# SDC gerado pelo Genus a partir de constraints/ecc_design.sdc
create_constraint_mode -name cm_func -sdc_files [list ecc_design_synth.sdc]

create_analysis_view -name av_slow -delay_corner dc_slow -constraint_mode cm_func
create_analysis_view -name av_typ  -delay_corner dc_typ  -constraint_mode cm_func
create_analysis_view -name av_fast -delay_corner dc_fast -constraint_mode cm_func

set_analysis_view -setup [list av_slow av_typ av_fast] \
                  -hold  [list av_fast av_typ av_slow]
