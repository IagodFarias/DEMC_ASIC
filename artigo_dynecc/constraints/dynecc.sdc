# Restricao comum as 4 variantes (README: 5 ns entradas -> saidas).
# Unidades da biblioteca sg13g2: ns e pF.
set_max_delay 5.0 -from [all_inputs] -to [all_outputs]

# Ambiente eletrico das portas e regras de projeto: os mesmos valores
# da branch fluxo-sintese-signoff, aplicados igualmente as 4 variantes.
set_driving_cell -lib_cell sg13g2_buf_2 -pin X [all_inputs]
set_load 0.010 [all_outputs]
set_max_fanout 8 [current_design]
set_max_transition 1.0 [current_design]
