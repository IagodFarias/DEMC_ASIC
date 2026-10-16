# =============================================================================
#  mmmc_postlayout.tcl - corners para a analise pos-layout (Etapa 2/3)
#
#  Corners de biblioteca (nucleo 1.2 V do sg13g2):
#    slow : 1.08 V / 125 C   -> pior caso de atraso (setup)
#    typ  : 1.20 V /  25 C   -> nominal
#    fast : 1.32 V / -40 C   -> melhor caso (hold / corridas)
#
#  RC: o PDK aberto nao traz QRC techfile nem captable. A extracao usa os
#  valores R/C da tech LEF (RPERSQ, CPERSQDIST, EDGECAPACITANCE), que nao
#  variam com o corner. Por isso ha um unico RC corner; a variacao entre
#  corners vem das bibliotecas.
# =============================================================================
set LIB_DIR /home/mateusmaia45/IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib

create_library_set -name libs_slow -timing [list $LIB_DIR/sg13g2_stdcell_slow_1p08V_125C.lib]
create_library_set -name libs_typ  -timing [list $LIB_DIR/sg13g2_stdcell_typ_1p20V_25C.lib]
create_library_set -name libs_fast -timing [list $LIB_DIR/sg13g2_stdcell_fast_1p32V_m40C.lib]

create_rc_corner -name rc_lef -T 25

create_delay_corner -name dc_slow -library_set libs_slow -rc_corner rc_lef
create_delay_corner -name dc_typ  -library_set libs_typ  -rc_corner rc_lef
create_delay_corner -name dc_fast -library_set libs_fast -rc_corner rc_lef

# SDC original do Genus, sem alteracoes (decisao do projeto)
create_constraint_mode -name cm_func -sdc_files [list ecc_design_synth.sdc]

create_analysis_view -name av_slow -delay_corner dc_slow -constraint_mode cm_func
create_analysis_view -name av_typ  -delay_corner dc_typ  -constraint_mode cm_func
create_analysis_view -name av_fast -delay_corner dc_fast -constraint_mode cm_func

set_analysis_view -setup [list av_slow av_typ av_fast] \
                  -hold  [list av_fast av_typ av_slow]
