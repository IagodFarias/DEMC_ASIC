#1. onfiguração de caminhos do PDK IHP

set PDK_DIR "/home/mateusmaia45/IHP-Open-PDK/ihp-sg13g2"
set LIB_PATH "$PDK_DIR/libs.ref/sg13g2_stdcell/lib"
set LEF_TECH "$PDK_DIR/libs.ref/sg13g2_stdcell/lef/sg13g2_tech.lef"
set LEF_CELL "$PDK_DIR/libs.ref/sg13g2_stdcell/lef/sg13g2_stdcell.lef"

#2. Carregamento das Bibliotecas de 130nm

set_db init_lib_search_path $LIB_PATH
set_db library {sg13g2_stdcell_typ_1p20V_25C.lib}
set_db lef_library "$LEF_TECH $LEF_CELL"


#3. Importação do Código RTL

set_db init_hdl_search_path  ../rtl

read_hdl -sv MRSC_encoder.sv MRSC_decoder.sv TBEC_RSC_encoder.sv TBEC_RSC_decoder.sv 

read_hdl -sv ecc_design.sv

#4. Elaboração e Mapeamento Tecnológico

elaborate ecc_design
syn_generic
syn_map
syn_opt

set_max_delay 5000 -from [all_inputs] -to [all_outputs]

syn_generic ;#Otimização  independente de teclogia
syn_map;    #Mapemento para as standard cells do IHP sg13g2
syn_opt;    #Otimização em consertar timing e área na teclogia

file mkdir reports
report_timing > reports/timing_report.rpt
report_area   > reports/area_report.rpt
report_power  > reports/power_report.rpt


#5. Exportação dos Arquivos para o Innovus (Placa & Rooute)

write_hdl > ../pnr/ecc_desing_synth.v
write_sdc > ../pnr/ecc_desing_synth.sdc
write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge > ../pnr/ecc_desing_synth.sdf





