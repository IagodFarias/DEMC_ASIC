// =============================================================================
//  tb_equiv.sv - equivalencia do RTL reescrito (pacote DYNECC) com o RTL original
//
//  Referencia: rtl/*.sv do repositorio DEMC_ASIC, com os modulos renomeados com
//  sufixo _orig (scripts/run_equiv.sh faz isso). Os 4 tops novos rodam lado a
//  lado com o ecc_design original e recebem exatamente as mesmas entradas.
//
//  Comparado (reprova): data_out_right_up, data_out_right_down, data_out_left,
//  chip_sel_out, nos modos funcionais de cada top:
//     mux_reference / mux_isolated : 000 001 010 011
//     tbec_only                    : 000 001 010
//     mrsc_only                    : 000 001 011
//  Informativo (nao reprova): flag no modo 010. No original o flag vem de latches
//  e "gruda"; no pacote ele foi zerado por default (diferenca intencional).
//  Modos 100..111 nao sao comparados: no original usam sinais sem driver.
//
//  Estimulos, por modo:
//   A) as 65536 palavras de data_in_left (encoder exaustivo), lado direito aleatorio
//   B) palavras-codigo validas do codigo do modo (geradas pelo encoder ORIGINAL)
//      com 0 erro, todos os 32 erros simples, todos os 496 duplos, todas as
//      rajadas de 3 e 4 bits adjacentes e NTRIPLE triplos aleatorios
//   C) NRAND vetores totalmente aleatorios
//  Plusargs: +NWORDS=<n> (palavras na fase B, padrao 512), +NRAND=<n> (padrao 100000)
// =============================================================================
`timescale 1ns/1ps
module tb_equiv;
  logic [0:15] din_l, din_ru, din_rd;
  logic [2:0]  sel;
  logic        cs;

  // ---------------- original
  wire [0:15] o_ru, o_rd, o_l; wire [0:2] o_fl; wire [1:0] o_cs;
  ecc_design_orig u_orig(.data_in_left(din_l), .data_out_right_up(o_ru), .data_out_right_down(o_rd),
    .data_in_right_up(din_ru), .data_in_right_down(din_rd), .data_out_left(o_l),
    .sel(sel), .flag(o_fl), .chip_sel_out(o_cs), .chip_sel(cs));

  // ---------------- tops do pacote
  wire [0:15] r_ru, r_rd, r_l; wire [0:2] r_fl; wire [1:0] r_cs;
  ecc_mux_reference u_ref(.data_in_left(din_l), .data_out_right_up(r_ru), .data_out_right_down(r_rd),
    .data_in_right_up(din_ru), .data_in_right_down(din_rd), .data_out_left(r_l),
    .sel(sel), .flag(r_fl), .chip_sel_out(r_cs), .chip_sel(cs));
  wire [0:15] i_ru, i_rd, i_l; wire [0:2] i_fl; wire [1:0] i_cs;
  ecc_mux_isolated u_iso(.data_in_left(din_l), .data_out_right_up(i_ru), .data_out_right_down(i_rd),
    .data_in_right_up(din_ru), .data_in_right_down(din_rd), .data_out_left(i_l),
    .sel(sel), .flag(i_fl), .chip_sel_out(i_cs), .chip_sel(cs));
  wire [0:15] t_ru, t_rd, t_l; wire [0:2] t_fl; wire [1:0] t_cs;
  ecc_tbec_only u_tbec(.data_in_left(din_l), .data_out_right_up(t_ru), .data_out_right_down(t_rd),
    .data_in_right_up(din_ru), .data_in_right_down(din_rd), .data_out_left(t_l),
    .sel(sel), .flag(t_fl), .chip_sel_out(t_cs), .chip_sel(cs));
  wire [0:15] m_ru, m_rd, m_l; wire [0:2] m_fl; wire [1:0] m_cs;
  ecc_mrsc_only u_mrsc(.data_in_left(din_l), .data_out_right_up(m_ru), .data_out_right_down(m_rd),
    .data_in_right_up(din_ru), .data_in_right_down(din_rd), .data_out_left(m_l),
    .sel(sel), .flag(m_fl), .chip_sel_out(m_cs), .chip_sel(cs));

  // ---------------- contadores: [top][modo]
  // top: 0=mux_reference 1=mux_isolated 2=tbec_only 3=mrsc_only
  integer nvec [0:3][0:3];
  integer nerr [0:3][0:3];
  integer nflag[0:3];          // divergencias de flag no modo 010 (informativo)
  integer nflagvec;
  integer shown;
  string  topname [0:3];
  string  phase;

  function automatic bit applies(input int t, input logic [2:0] m);
    case (t)
      0, 1: return (m <= 3'b011);
      2:    return (m == 3'b000 || m == 3'b001 || m == 3'b010);
      3:    return (m == 3'b000 || m == 3'b001 || m == 3'b011);
    endcase
    return 0;
  endfunction

  task automatic cmp1(input int t, input logic [0:15] ru, rd, l, input logic [1:0] c,
                      input logic [0:2] fl);
    if (applies(t, sel)) begin
      nvec[t][sel]++;
      if (ru !== o_ru || rd !== o_rd || l !== o_l || c !== o_cs) begin
        nerr[t][sel]++;
        if (shown < 20) begin
          shown++;
          $display("DIVERGE %-13s sel=%b fase=%s din_l=%h din_r=%h_%h | orig: ru=%h rd=%h l=%h cs=%b | novo: ru=%h rd=%h l=%h cs=%b",
                   topname[t], sel, phase, din_l, din_ru, din_rd, o_ru, o_rd, o_l, o_cs, ru, rd, l, c);
        end
      end
      if (sel == 3'b010 && t != 3 && fl !== o_fl) nflag[t]++;
    end
  endtask

  task automatic apply_and_check();
    #1;
    cmp1(0, r_ru, r_rd, r_l, r_cs, r_fl);
    cmp1(1, i_ru, i_rd, i_l, i_cs, i_fl);
    cmp1(2, t_ru, t_rd, t_l, t_cs, t_fl);
    cmp1(3, m_ru, m_rd, m_l, m_cs, m_fl);
    if (sel == 3'b010) nflagvec++;
  endtask

  task automatic apply_cw(input logic [0:31] w);
    din_ru = w[0:15]; din_rd = w[16:31];
    apply_and_check();
  endtask

  integer nwords, nrand, ntriple;
  logic [0:31] cw, e;
  logic [31:0] r;
  int a, b, c, k, total_err;
  integer seed;

  initial begin
    topname[0] = "mux_reference"; topname[1] = "mux_isolated";
    topname[2] = "tbec_only";     topname[3] = "mrsc_only";
    for (int t = 0; t < 4; t++) begin
      nflag[t] = 0;
      for (int m = 0; m < 4; m++) begin nvec[t][m] = 0; nerr[t][m] = 0; end
    end
    nflagvec = 0; shown = 0;
    if (!$value$plusargs("NWORDS=%d", nwords)) nwords = 512;
    if (!$value$plusargs("NRAND=%d",  nrand))  nrand  = 100000;
    ntriple = 200;
    seed = 32'h00EC0DE5;
    r = $urandom(seed);            // semente fixa: mesma sequencia em toda rodada

    for (int m = 0; m < 4; m++) begin
      sel = m[2:0];

      // A) encoder exaustivo
      phase = "A";
      for (int d = 0; d < 65536; d++) begin
        din_l = d[15:0]; din_ru = $urandom; din_rd = $urandom; cs = $urandom;
        apply_and_check();
      end

      // B) palavras-codigo + erros (so faz sentido nos modos ECC)
      if (sel == 3'b010 || sel == 3'b011) begin
        phase = "B";
        for (int w = 0; w < nwords; w++) begin
          cs = $urandom;
          din_l = (w == 0) ? 16'h0000 : (w == 1) ? 16'hFFFF : 16'($urandom);
          din_ru = '0; din_rd = '0;
          #1; cw = {o_ru, o_rd};               // codifica com o encoder ORIGINAL
          din_l = $urandom;                     // lado do encoder segue aleatorio
          apply_cw(cw);                                                  // 0 erro
          for (a = 0; a < 32; a++) begin e = cw; e[a] = ~e[a]; apply_cw(e); end   // 32 simples
          for (a = 0; a < 32; a++) for (b = a+1; b < 32; b++) begin                // 496 duplos
            e = cw; e[a] = ~e[a]; e[b] = ~e[b]; apply_cw(e);
          end
          for (k = 3; k <= 4; k++) for (a = 0; a + k <= 32; a++) begin           // rajadas
            e = cw; for (c = a; c < a + k; c++) e[c] = ~e[c]; apply_cw(e);
          end
          for (k = 0; k < ntriple; k++) begin                                    // triplos
            a = $urandom_range(31); b = $urandom_range(31); c = $urandom_range(31);
            e = cw; e[a] = ~e[a]; e[b] = ~e[b]; e[c] = ~e[c]; apply_cw(e);
          end
        end
      end

      // C) aleatorio puro
      phase = "C";
      for (int v = 0; v < nrand; v++) begin
        din_l = $urandom; din_ru = $urandom; din_rd = $urandom; cs = $urandom;
        apply_and_check();
      end
    end

    // ---------------- relatorio
    total_err = 0;
    $display("");
    $display("EQUIVALENCIA com o RTL original (dados + chip_sel_out)");
    $display("  %-13s %-5s %10s %10s", "top", "sel", "vetores", "diverg.");
    for (int t = 0; t < 4; t++)
      for (int m = 0; m < 4; m++)
        if (nvec[t][m] > 0) begin
          $display("  %-13s %3b   %10d %10d", topname[t], m[2:0], nvec[t][m], nerr[t][m]);
          total_err += nerr[t][m];
        end
    $display("INFO flag no modo 010 (diferenca intencional, nao reprova): de %0d vetores, divergem mux_reference=%0d mux_isolated=%0d tbec_only=%0d",
             nflagvec, nflag[0], nflag[1], nflag[2]);
    if (total_err == 0) $display("EQUIV_PASS: os 4 tops do pacote sao identicos ao original nos modos funcionais");
    else                $display("EQUIV_FAIL: %0d divergencias", total_err);
    $finish;
  end
endmodule
