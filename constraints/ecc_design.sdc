# =============================================================================
#  constraints/ecc_design.sdc - restricoes de tempo e de E/S do ecc_design
#
#  O ecc_design e puramente combinacional: fica entre a interface do
#  processador/FPGA (data_in_left/data_out_left) e as duas memorias
#  (data_*_right_up/down). As restricoes usam um relogio VIRTUAL (sem pino),
#  que representa o relogio do sistema que registra as entradas antes do
#  bloco e as saidas depois dele. O atraso combinacional permitido e:
#
#     orcamento = PERIODO - ATRASO_ENTRADA - ATRASO_SAIDA - INCERTEZA
#               = 10.0    - 2.5            - 2.5          - 0.2       = 4.8 ns
#
#  Referencia: o layout anterior mediu 3.88 ns no corner slow, sem modelar
#  slew de entrada nem carga de saida. Com o driver e a carga abaixo o
#  caminho fica proximo de 4.8 ns no slow, entao a restricao e real e
#  obriga a sintese/P&R a otimizar. Ajuste os valores conforme a interface
#  real (FPGA, memorias, pads) quando ela estiver definida.
#
#  Unidades: as da biblioteca sg13g2 (ns, pF).
#  Lido pelo Genus (synth/synth.tcl); o Genus grava a versao expandida em
#  pnr/ecc_design_synth.sdc, que e a usada pelo Innovus (mmmc_postlayout.tcl).
# =============================================================================

# --- Parametros da interface (edite aqui) ------------------------------------
set PERIODO          10.0   ;# ns  relogio do sistema (100 MHz)
set ATRASO_ENTRADA    2.5   ;# ns  clk->Q + fio ate a entrada do bloco
set ATRASO_SAIDA      2.5   ;# ns  fio + setup do registrador de destino
set ATRASO_MIN        0.5   ;# ns  menor atraso de entrada (checagem de hold)
set INCERTEZA         0.2   ;# ns  jitter/skew do relogio do sistema
set CELULA_DRIVER    sg13g2_buf_2   ;# quem dirige cada entrada
set PINO_DRIVER      X
set CARGA_SAIDA       0.010 ;# pF  carga em cada saida (~2 entradas de buf_4 + fio)
set MAX_FANOUT        8     ;# igual ao default_max_fanout da biblioteca
set MAX_TRANSICAO     1.0   ;# ns

# --- Relogio virtual ---------------------------------------------------------
create_clock -name vclk -period $PERIODO
set_clock_uncertainty $INCERTEZA [get_clocks vclk]

# --- Atrasos de E/S ----------------------------------------------------------
set_input_delay  -clock vclk -max $ATRASO_ENTRADA [all_inputs]
set_input_delay  -clock vclk -min $ATRASO_MIN     [all_inputs]
set_output_delay -clock vclk -max $ATRASO_SAIDA   [all_outputs]
set_output_delay -clock vclk -min 0.0             [all_outputs]

# --- Ambiente eletrico das portas --------------------------------------------
set_driving_cell -lib_cell $CELULA_DRIVER -pin $PINO_DRIVER [all_inputs]
set_load $CARGA_SAIDA [all_outputs]

# --- Regras de projeto -------------------------------------------------------
set_max_fanout     $MAX_FANOUT    [current_design]
set_max_transition $MAX_TRANSICAO [current_design]
