# =============================================================================
#  Makefile - fluxo completo do ecc_design (RTL -> GDS -> signoff)
#
#  Requer PDK_ROOT apontando para a raiz do IHP-Open-PDK:
#     export PDK_ROOT=$HOME/IHP-Open-PDK
#
#  Alvos principais:
#     make sim        simulacao RTL (testbench de referencia)
#     make synth      sintese (Genus)                       -> pnr/ecc_design_synth.*
#     make pnr        place & route (Innovus)               -> pnr/ecc_design_route.enc, GDS
#     make ext        extracao de parasitas                 -> pnr/out/ecc_design.spef
#     make sta        STA pos-layout nos 3 corners          -> pnr/reports_sta/resumo.txt
#     make export     netlist + SDF pos-layout para o GLS   -> pnr/out/
#     make gls        GLS nos 3 corners + comparacao com o RTL
#     make drc        DRC KLayout (regras principais)
#     make lvs        LVS KLayout (GDS x netlist pos-layout)
#     make backend    synth + pnr + ext + sta + export
#     make signoff    drc + lvs
#     make all        sim + backend + gls + signoff
# =============================================================================
SHELL := /bin/bash

GENUS   ?= genus
INNOVUS ?= innovus
SIM     ?= xrun

.PHONY: all backend signoff sim synth pnr ext sta export gls drc lvs check-pdk help

help:
	@sed -n '2,22p' Makefile

check-pdk:
	@test -n "$$PDK_ROOT" || { echo "ERRO: defina PDK_ROOT (raiz do IHP-Open-PDK)"; exit 1; }
	@test -d "$$PDK_ROOT/ihp-sg13g2" || { echo "ERRO: $$PDK_ROOT/ihp-sg13g2 nao existe"; exit 1; }

sim:
	SIM=$(SIM) tb/run_sim.sh rtl

synth: check-pdk
	cd synth && $(GENUS) -batch -files synth.tcl -log genus

pnr: check-pdk
	cd pnr && $(INNOVUS) -no_gui -files etapa2a_pnr.tcl -log etapa2a

ext: check-pdk
	cd pnr && $(INNOVUS) -no_gui -files etapa2_extracao.tcl -log etapa2

sta: check-pdk
	cd pnr && $(INNOVUS) -no_gui -files etapa3_sta.tcl -log etapa3
	@cat pnr/reports_sta/resumo.txt

export: check-pdk
	cd pnr && $(INNOVUS) -no_gui -files etapa4_export_gls.tcl -log etapa4

gls: check-pdk
	SIM=$(SIM) tb/run_sim.sh all

drc: check-pdk
	signoff/run_drc.sh

lvs: check-pdk
	signoff/run_lvs.sh

backend: synth pnr ext sta export
signoff: drc lvs
all: sim backend gls signoff
