# Pacote experimental TCAS-II — TBEC-RSC / MRSC / NASCERR

**Objetivo:** gerar dados de implementação e potência **comparáveis** para a contribuição científica sobre a multiplexação de dois ECCs em tecnologia IHP SG13G2 (130 nm). Data: 21/10/2026.

**IMPORTANTE:** este pacote é material de engenharia **preliminar e não validado em Cadence**. Foi montado com base nos módulos publicados em [IagodFarias/DEMC_ASIC](https://github.com/IagodFarias/DEMC_ASIC), consultados em 21/10/2026, e nos relatórios enviados pelo grupo. **Não afirmar ganhos energéticos nem resultados de correção até executar, verificar e documentar as simulações e sínteses.**

## 1. Os quatro circuitos

| `TOP` em scripts | Arquitetura | ECC efetivo no benchmark |
| --- | --- | --- |
| `mrsc_only` | Apenas MRSC + bypass (referência mínima) | `mrsc` / `sel=011` |
| `tbec_only` | Apenas TBEC-RSC + bypass (referência mínima) | `tbec` / `sel=010` |
| `mux_reference` | TBEC + MRSC calculados paralelamente; multiplexação só nas saídas | `tbec`, `mrsc`, `mixed` |
| `mux_isolated` | TBEC + MRSC com isolamento **de operandos de entrada** antes dos codecs | `tbec`, `mrsc`, `mixed` |

Todos usam a mesma interface externa. Esta versão da referência já remove o latch de `flag`, corrige sinais sem driver nos modos `100/101` e zera saídas dos modos não usados. **Não é bit-a-bit idêntica ao RTL original em sinais `flag` e modos não implementados**; o teste de equivalência recomendado deve comparar saída de dados somente em modos funcionais (`000..011`).

### Diferenças intencionais em relação ao original

- TBEC-RSC: bits `flag` têm atribuição default zero em todo `always_comb`; evita os latches detectados no repositório.
- Modos `100..111`: entradas não implementadas agora usam saída segura, sem sinais sem driver. Não confundir isso com uma função de `bypass` ativo.
- TBEC-RSC/MRSC: correção e equações de paridade são mantidas do projeto de origem; os arquivos foram reorganizados para legibilidade e **precisam de checagem de equivalência formal/simulação**.
- Modo otimizado: máscara entradas não selecionadas; **não implementa power gating físico**. Overhead de máscaras pode superar economia; é objeto da medição.

## 2. Checagem rápida

```bash
python3 scripts/python_sanity.py  # apenas coerência algébrica dos encoders
SIM=xrun scripts/run_matrix.sh  # simulador Cadence Xcelium, se disponível
# ou:
SIM=iverilog scripts/run_matrix.sh
```

O testbench `tb_ecc_bench.sv` escreve e lê dados através de duas memórias abstratas (16+16 bits), checa ida-e-volta de dados e gera VCD **somente durante a janela medida**, após inicialização. Usa sequência determinística e 1.500 operações por caso. `tb_faults.sv` caracteriza falhas injetadas em 1 ou 2 dos 32 bits, para 8 palavras; os totais são estatísticas, não critérios de aprovação de 100% de correção. As verificações completas usam `===` e detectam X/Z.

**Compatibilidade de formato:** cada endereço guarda uma *tag* do código utilizado. Ao ler, deve ser usado o mesmo código. Mudar o ECC de leitura sobre dados antigos sem reescrita **não é correto**. O armazenamento, custo energético, área e confiabilidade da tag **não estão incluídos** nas quatro arquiteturas. Comparações do subsistema completo devem considerá-lo.

## 3. Requisitos no computador do aluno

- Linux, Cadence Genus 21.x e Innovus 21.x com licenças.
- Cadence Xcelium (`xrun`) ou Icarus Verilog (`iverilog`) para simulação.
- PDK IHP SG13G2 no mesmo formato `libs.ref/sg13g2_stdcell/...` dos scripts do repositório.
- Bash e Python 3.

Definir caminho completo do PDK:

```bash
export PDK=/CAMINHO/IHP-Open-PDK/ihp-sg13g2
```

## 4. Execução ASIC

Primeiro validar simulação (falha funcional = interromper):

```bash
SIM=xrun scripts/run_matrix.sh
```

Em seguida, para **cada** arquitetura:

```bash
scripts/run_cadence.sh synth mrsc_only
scripts/run_cadence.sh pnr mrsc_only
# repetir para tbec_only, mux_reference, mux_isolated
```

Os scripts TCL de Genus/Innovus **são templates de automação para revisão local**, não foram executados nesta sessão por ausência das ferramentas/licenças. O aluno deverá ajustar comandos que variem conforme instalação, checar as mensagens de warning e garantir a mesma versão de PDK, canto TT, tensão de 1,20 V, temperatura de 25°C e restrição de atraso de **5 ns** para todas as alternativas. O *constraint* de 5 ns não deve ser reportado como atraso real.

**Power pós-layout:** gerar primeiro as simulações pós-layout (gate-level + SDF) para os oito casos, para evitar importação de VCD RTL com redes internas incompatíveis:

```bash
scripts/run_gls.sh mrsc_only mrsc
scripts/run_gls.sh tbec_only tbec
for top in mux_reference mux_isolated; do
 for scenario in tbec mrsc mixed; do scripts/run_gls.sh "$top" "$scenario"; done
done
```

Verificar primeiro importação da atividade de cada VCD em Innovus (escopo `tb_ecc_bench/dut`), proporção de redes anotadas, cobertura e política de *glitch power*. O script `run_power.tcl` é um ponto inicial que **falha** se o VCD não for importado. Adaptar sintaxe `read_activity_file` à versão do ambiente, e confirmar os resultados no log. Medir **separadamente** os cenários:

```bash
scripts/run_cadence.sh power mrsc_only mrsc
scripts/run_cadence.sh power tbec_only tbec
scripts/run_cadence.sh power mux_reference tbec
scripts/run_cadence.sh power mux_reference mrsc
scripts/run_cadence.sh power mux_reference mixed
scripts/run_cadence.sh power mux_isolated tbec
scripts/run_cadence.sh power mux_isolated mrsc
scripts/run_cadence.sh power mux_isolated mixed
```

O script de potência **exige VCD de GLS + SDF** (`*_gls.vcd`), não aceita o VCD RTL. Conferir anotação completa SDF, incluindo cobertura de células e *glitches*. Mesmo GLS não é signoff: revisar escopo VCD, mapeamento das redes, bibliotecas e condições elétricas. Em caso de ausência de simulação GLS válida, manter métricas energéticas em branco.

## 5. O que devolver (OBRIGATÓRIO)

1. Os oito VCDs RTL e oito VCDs GLS+SDF, logs dos testes e confirmação **PASS**, juntamente com os logs de anotação SDF.
2. As quatro pastas `results/cadence/ecc_*/` com `genus.log`, `area.rpt`, `timing.rpt`, `summary.rpt`, `timing_pnr.rpt`, `drc.rpt`, `antenna.rpt`, `connectivity.rpt` e, se disponíveis, arquivos de netlist e SDF.
3. Os oito `power_*.rpt` (**quatro casos físicos / oito cenários**), com *internal*, *switching* e *leakage*, método de anotação e relatório de cobertura do VCD.
4. `results/measurements_template.csv` preenchido com valores rastreáveis, **sem misturar dados Genus, Innovus e LibreLane**.
5. Versões exatas dos programas, parâmetros de PDK, library corner, tensão e temperatura, relatório das restrições, falhas/warnings e arquivo de log completo.

Calcular economia frente à multiplexação **não isolada**, mesmo estímulo:

\[\mathrm{Savings}(s)=100\frac{P_{\mathrm{mux-reference},s}-P_{\mathrm{mux-isolated},s}}{P_{\mathrm{mux-reference},s}}\]\

```bash
python3 scripts/summarize.py results/measurements_template.csv
```

`P` é potência média de cada cenário no mesmo intervalo de tempo. Para energia por acesso, obter `E = P × T / número_de_acessos` utilizando **mesmos períodos e contagem de operações**, documentando possíveis overheads de mudança de modo. Tráfego de memória real e potência das SRAMs não estão modelados aqui.

## 6. Critérios antes de usar no TCAS-II

- Simulação de todos os casos PASS; comparação funcional com versão original nos modos `000..011` para dados e chip-select; flags corrigidas com semântica revisada.
- Sintetizar sem latches; investigar lógicas combinacionais mal inferidas.
- Corrigir `max_fanout`, `max_transition`, `max_capacitance`, falhas de DRC e conectividade; realizar LVS/signoff externo quando pertinente.
- Comparar área **lógica**, área do core, área do die; não confundir fillers com lógica.
- Confirmar que dados codificados TBEC-RSC e MRSC são distinguíveis e não trocar decoder inadvertidamente.
- Demonstrar economia medindo isoladamente condições com mesmo tráfego e cenários de radiação; não extrapolar para energia total do CubeSat sem medir SRAM/controlador e overhead das tags.
- O modo `mixed` ainda não é uma política de adaptação baseada em radiação: é carga mista determinística para caracterização. Integrar controlador real depois.

## Proveniência

Arquivos adaptados/reescritos manualmente a partir de `rtl/MRSC_encoder.sv`, `rtl/MRSC_decoder.sv`, `rtl/TBEC_RSC_encoder.sv` e `rtl/TBEC_RSC_decoder.sv` do [DEMC_ASIC](https://github.com/IagodFarias/DEMC_ASIC) consultado em 21/10/2026. **Os arquivos neste ZIP não devem ser confundidos com cópias certificadas da versão GitHub**. Referência do repositório continua autoritativa e deve ser usada para comparação de equivalência. Os TCL acompanham a organização e a tecnologia do repositório, mas foram elaborados para esta comparação.
