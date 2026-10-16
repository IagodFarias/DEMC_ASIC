# =============================================================================
#  scripts/pdk.tcl - caminhos do PDK IHP SG13G2, lidos da variavel PDK_ROOT
#
#  Fonte unica dos caminhos para a sintese (Genus) e o backend (Innovus).
#  Os scripts rodam de dentro de synth/ ou pnr/ e fazem:
#     source ../scripts/pdk.tcl
#
#  PDK_ROOT aponta para a raiz do repositorio IHP-Open-PDK (a pasta que
#  contem ihp-sg13g2/), por exemplo:
#     export PDK_ROOT=$HOME/IHP-Open-PDK
# =============================================================================
if {![info exists ::env(PDK_ROOT)] || $::env(PDK_ROOT) eq ""} {
  puts "\nERRO: variavel de ambiente PDK_ROOT nao definida."
  puts "      Ex.: export PDK_ROOT=\$HOME/IHP-Open-PDK  (pasta que contem ihp-sg13g2/)"
  exit 1
}

set PDK      [file normalize [file join $::env(PDK_ROOT) ihp-sg13g2]]
set STD      $PDK/libs.ref/sg13g2_stdcell
set LIB_DIR  $STD/lib
set LEF_TECH $STD/lef/sg13g2_tech.lef
set LEF_CELL $STD/lef/sg13g2_stdcell.lef
set STD_GDS  $STD/gds/sg13g2_stdcell.gds
set GDS_MAP  $PDK/libs.tech/klayout/tech/sg13g2.map

# Bibliotecas Liberty por corner (1.2 V nominal)
set LIB_SLOW sg13g2_stdcell_slow_1p08V_125C.lib
set LIB_TYP  sg13g2_stdcell_typ_1p20V_25C.lib
set LIB_FAST sg13g2_stdcell_fast_1p32V_m40C.lib

set faltando {}
foreach f [list $LIB_DIR/$LIB_SLOW $LIB_DIR/$LIB_TYP $LIB_DIR/$LIB_FAST $LEF_TECH $LEF_CELL] {
  if {![file exists $f]} { lappend faltando $f }
}
if {[llength $faltando]} {
  puts "\nERRO: arquivos do PDK nao encontrados (confira PDK_ROOT=$::env(PDK_ROOT)):"
  foreach f $faltando { puts "   - $f" }
  exit 1
}
