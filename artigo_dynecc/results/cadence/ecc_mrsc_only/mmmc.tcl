create_library_set -name libs_typ -timing [list /home/mateusmaia45/IHP-Open-PDK/ihp-sg13g2/libs.ref/sg13g2_stdcell/lib/sg13g2_stdcell_typ_1p20V_25C.lib]
create_rc_corner -name rc_typ
create_delay_corner -name dc_typ -library_set libs_typ -rc_corner rc_typ
create_constraint_mode -name cm -sdc_files [list /home/mateusmaia45/Documentos/DEMC_ASIC/artigo_dynecc/results/cadence/ecc_mrsc_only/synth.sdc]
create_analysis_view -name av_typ -constraint_mode cm -delay_corner dc_typ
set_analysis_view -setup {av_typ} -hold {av_typ}
