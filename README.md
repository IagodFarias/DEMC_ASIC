# DEMC_ASIC — `ecc_design`

Bloco de correção de erros (ECC) configurável em tecnologia **IHP SG13G2 (130 nm)**. Ele fica entre o processador/FPGA e duas memórias de 16 bits. Codifica cada palavra de 16 bits em 32 bits, com dados numa memória e redundância na outra, e decodifica e corrige na leitura. O bloco é **puramente combinacional**.

O repositório guarda o fluxo completo, de RTL até GDS, com signoff por DRC e LVS no KLayout.

## Modos de operação (`sel`)

| `sel` | Modo | Escrita (`data_in_left` →) | Leitura (→ `data_out_left`) | `chip_sel_out` |
|---|---|---|---|---|
| `000` | Bypass memória 1 | `data_out_right_up` | `data_in_right_up` | `{cs, !cs}` |
| `001` | Bypass memória 2 | `data_out_right_down` | `data_in_right_down` | `{!cs, cs}` |
| `010` | ECC1 — TBEC-RSC | dados → `up`, redundância → `down` | palavra corrigida | `{cs, cs}` |
| `011` | ECC2 — MRSC | dados → `up`, redundância → `down` | palavra corrigida | `{cs, cs}` |
| `100`, `101` | Reservados (ECC3/ECC4) | sem implementação | sem implementação | `11` |
| `110`, `111` | Padrão | igual ao bypass da memória 1 | igual ao bypass da memória 1 | `11` |

`cs` é a entrada `chip_sel`. A saída `flag[0:2]` vem do decodificador TBEC-RSC e indica em que quadrante a correção atuou.

### Capacidade de correção

Os dois decodificadores são lineares: o resultado depende só do padrão de erro, não do dado. Os números abaixo vêm de uma varredura exaustiva dos padrões, feita no RTL.

| Padrão de erro na palavra de 32 bits | TBEC-RSC | MRSC |
|---|---|---|
| 1 bit, em qualquer posição | 100% | 100% |
| Rajada de 2 ou 3 bits consecutivos na memória de dados | 100% | 100% |
| 2 células vizinhas na matriz 4×4, incluindo diagonal | 81% | 100% |
| 2 bits em posições quaisquer | 56,5% | 56,5% |
| 1 bit de dado + 1 bit de redundância | 37,5% | 37,5% |

Quando o erro passa da capacidade do código, o dado sai errado sem nenhum aviso. Não existe sinal de "erro não corrigível".

## Estrutura

```
rtl/          RTL SystemVerilog (top: ecc_design.sv; codificadores/decodificadores TBEC-RSC e MRSC)
tb/           testbench único para RTL e gate-level (tb_ecc_design.sv) e script run_sim.sh
constraints/  restrições de tempo e de E/S (ecc_design.sdc)
scripts/      pdk.tcl — caminhos do PDK lidos de $PDK_ROOT (usado por Genus e Innovus)
synth/        synth.tcl (Genus) e relatórios
pnr/          scripts do Innovus (etapa2a, etapa2, etapa3, etapa4), MMMC, GDS, relatórios
  out/        netlist pós-layout, SPEF e SDF por corner
signoff/      DRC e LVS com KLayout (run_drc.sh, run_lvs.sh, v2spice.py)
Makefile      atalhos para cada etapa
```

## Requisitos

- **IHP-Open-PDK**, com a variável `PDK_ROOT` apontando para a raiz (a pasta que contém `ihp-sg13g2/`).
- **Cadence Genus 21.1** (síntese) e **Innovus 21.1** (P&R, extração, STA e exportação).
- **Cadence Xcelium** (`xrun`) para simular, ou **Icarus Verilog** para RTL e GLS sem SDF.
- **KLayout** e o módulo Python `klayout`, nas versões pedidas pelo PDK (`versions.txt` na raiz do IHP-Open-PDK). Para instalar o módulo: `pip install -r $PDK_ROOT/requirements.txt`.

```bash
export PDK_ROOT=$HOME/IHP-Open-PDK
```

Nenhum script tem caminho fixo para um diretório pessoal. Se `PDK_ROOT` estiver faltando ou errado, os scripts param com uma mensagem dizendo o que não encontraram.

## Fluxo

Rode todos os alvos a partir da raiz do repositório.

| Alvo | Ferramenta / script | Saída principal |
|---|---|---|
| `make sim` | `tb/run_sim.sh rtl` | `sim/rtl.log`, `sim/vectors_rtl.txt` |
| `make synth` | Genus, `synth/synth.tcl` | `pnr/ecc_design_synth.{v,sdc,sdf}`, `synth/reports/` |
| `make pnr` | Innovus, `pnr/etapa2a_pnr.tcl` | `pnr/ecc_design_route.enc`, `pnr/ecc_design_final_v2.gds`, `pnr/reports_pnr/` |
| `make ext` | Innovus, `pnr/etapa2_extracao.tcl` | `pnr/out/ecc_design.spef` |
| `make sta` | Innovus, `pnr/etapa3_sta.tcl` | `pnr/reports_sta/resumo.txt` (slow/typ/fast) |
| `make export` | Innovus, `pnr/etapa4_export_gls.tcl` | `pnr/out/ecc_design_pnr.v`, `pnr/out/ecc_design_{slow,typ,fast}.sdf` |
| `make gls` | `tb/run_sim.sh all` | GLS nos 3 corners e `sim/comparacao.txt` contra o RTL |
| `make drc` | `signoff/run_drc.sh` | `signoff/runs/drc_main/` |
| `make lvs` | `signoff/run_lvs.sh` | `signoff/runs/lvs/` |

Também existem alvos que agrupam etapas: `make backend` (synth → export), `make signoff` (drc + lvs) e `make all`.

Para usar outro simulador ou outro executável das ferramentas, passe a variável no comando, por exemplo `make sim SIM=iverilog` ou `make synth GENUS=/caminho/genus`.

### Restrições de tempo (`constraints/ecc_design.sdc`)

O bloco não tem relógio próprio. As restrições usam um **relógio virtual** `vclk`, que representa o relógio do sistema que registra as entradas antes do bloco e as saídas depois dele. Valores padrão:

| Parâmetro | Valor |
|---|---|
| Período | 10 ns (100 MHz) |
| Atraso de entrada / saída | 2,5 ns / 2,5 ns |
| Incerteza | 0,2 ns |
| Orçamento combinacional | **4,8 ns** |
| Driver das entradas | `sg13g2_buf_2` |
| Carga das saídas | 10 fF |
| Fanout máximo / transição máxima | 8 / 1,0 ns |

Todos os valores estão no topo do arquivo, para ajustar quando a interface real (FPGA, memórias, pads) estiver definida. O Genus lê esse arquivo e grava a versão expandida em `pnr/ecc_design_synth.sdc`, que é a que o Innovus usa. A síntese otimiza no corner **slow**, e o P&R confere os três corners.

### DRC e LVS (KLayout)

- `signoff/run_drc.sh` roda o deck oficial do IHP (`run_drc.py`) no GDS.
  - O modo padrão roda as regras principais, sem as de densidade.
  - `signoff/run_drc.sh antenna` roda só as regras de antena.
  - `signoff/run_drc.sh density` roda só as regras de densidade.
  - `signoff/run_drc.sh all` roda tudo.
  - As regras de densidade mínima de metal (`M2.j`–`M5.j`, `TM1.c`, `TM2.c`) **sempre falham num bloco isolado sem metal fill**. Elas só se resolvem no top-level do chip, depois do fill. Por isso ficam fora do modo padrão.
- `signoff/run_lvs.sh` compara o GDS com a netlist pós-layout. O GDS e a netlist precisam sair do **mesmo** banco do Innovus.
  - Primeiro, `signoff/v2spice.py` converte a netlist Verilog em SPICE, usando o CDL das standard cells.
  - Depois, o `run_lvs.py` do PDK extrai o layout e compara as duas netlists, inclusive os rótulos dos 105 pinos de topo.
- Os dois scripts retornam 0 só quando o resultado é limpo. Os resultados ficam em `signoff/runs/`, que não vai para o git. Para ver os erros, abra o `.lyrdb` ou o `.lvsdb` no KLayout (Marker Browser / Netlist Browser).

## Estado atual

| Item | Resultado |
|---|---|
| Simulação RTL | 8804 vetores, 0 falhas nas checagens obrigatórias |
| GLS zero-delay (netlist pós-layout) | idêntico ao RTL, exceto a coluna `flag` e os modos `100`–`111` (ver limitações) |
| Layout | die 95,04 × 91,98 µm, core 74,88 × 71,82 µm, 3776 µm² de lógica, densidade de 70% |
| Verificações do Innovus | DRC, antena, conectividade e placement sem violações |
| DRC KLayout, regras principais (`ecc_design_final_v2.gds`) | **0 violações** |
| DRC KLayout, densidade | falha em `M2.j`–`M5.j`, `TM1.c`, `TM2.c` (esperado em bloco sem fill) |
| LVS KLayout (`ecc_design_final_v2.gds` × `pnr/out/ecc_design_pnr.v`) | **netlists batem** |

> **Atenção.** A netlist sintetizada, o layout e os relatórios de STA que estão versionados ainda vêm da execução feita com a restrição antiga (`set_max_delay 5000`, sem E/S). Nessa execução, o pior atraso combinacional foi 3,88 ns no corner slow, sem modelar o driver das entradas nem a carga das saídas. Com as restrições novas, rode `make backend` e depois `make signoff` para regenerar tudo. Se mudar o layout, o LVS e o DRC precisam ser refeitos.

## Limitações conhecidas do RTL

- **`flag` vem de latches.** No `TBEC_RSC_decoder`, `bit1`, `bit2` e `bit3` não recebem valor em todos os ramos do `always_comb`. A síntese gera três latches sem reset, e a flag fica "grudada": no gate-level ela fica sempre `x`. O `synth/synth.tcl` avisa quando encontra latches na netlist.
- **Os modos `100`/`101` usam sinais sem driver** (`encoder_output3/4`, `decoder_output3/4`). No RTL esses modos dão `x`. No netlist sintetizado eles viraram bypass da memória 1, ou seja, o comportamento no RTL e no silício é diferente.
- **Não existe indicação de erro não corrigível.** Veja a tabela de capacidade de correção acima.
