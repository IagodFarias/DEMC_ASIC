// =============================================================================
//  tb_ecc_design.sv  -  Testbench de referencia do ecc_design
//
//  Mesmo testbench para RTL e para simulacao pos-layout (gate-level + SDF).
//
//  Estrategia:
//   1. Checagens "duras" (reprovam o teste): bypass (sel=000/001), chip_sel_out,
//      e ida-e-volta sem erro nos modos ECC1 (010) e ECC2 (011).
//   2. Caracterizacao (nao reprova): erros de 1 e 2 bits injetados em todas as
//      32 posicoes da palavra codificada; conta quantos foram corrigidos.
//   3. Dump de vetores: cada vetor aplicado e as saidas observadas vao para um
//      arquivo texto. No pos-layout, o mesmo arquivo e gerado e comparado (diff)
//      com o do RTL -> qualquer divergencia e um problema do layout/timing.
//
//  Limitacoes conhecidas do RTL (decisao do projeto, nao corrigidas):
//   - flag[0:2] vem de latches e fica "grudada" -> registrada, nao verificada.
//   - sel=100/101 usam sinais sem driver -> vetores em arquivo separado.
//
//  Defines opcionais:
//   +define+GATE               simula o netlist (inclua os modelos sg13g2)
//   +define+SDF_FILE=\"x.sdf\"   anota atrasos do arquivo SDF
//   +define+VEC_FILE=\"x.txt\"   nome do arquivo de vetores (padrao abaixo)
//   +define+T_SETTLE=20        tempo de estabilizacao por vetor, em ns
// =============================================================================
`timescale 1ns/1ps

`ifndef VEC_FILE
  `define VEC_FILE "vectors_rtl.txt"
`endif
`ifndef VEC_FILE_UNDEF
  `define VEC_FILE_UNDEF "vectors_undef_modes_rtl.txt"
`endif
`ifndef T_SETTLE
  `define T_SETTLE 10
`endif

module tb_ecc_design;

  // ---------------------------------------------------------------- DUT
  logic [0:15] data_in_left, data_in_right_up, data_in_right_down;
  logic [0:15] data_out_right_up, data_out_right_down, data_out_left;
  logic [2:0]  sel;
  logic        chip_sel;
  logic [0:2]  flag;
  logic [1:0]  chip_sel_out;

  ecc_design dut (
    .data_in_left       (data_in_left),
    .data_out_right_up  (data_out_right_up),
    .data_out_right_down(data_out_right_down),
    .data_in_right_up   (data_in_right_up),
    .data_in_right_down (data_in_right_down),
    .data_out_left      (data_out_left),
    .sel                (sel),
    .flag               (flag),
    .chip_sel_out       (chip_sel_out),
    .chip_sel           (chip_sel)
  );

`ifdef SDF_FILE
  initial $sdf_annotate(`SDF_FILE, dut, , "sdf_annotate.log", "MAXIMUM");
`endif

  // ---------------------------------------------------------------- estado
  integer fd, fd_undef;
  integer n_vec   = 0;
  integer n_err   = 0;       // falhas nas checagens duras
  integer seed    = 32'hEC0DE;
  integer tot1[2], cor1[2];  // erros de 1 bit: total / corrigidos, por modo
  integer tot2[2], cor2[2];  // erros de 2 bits

  // Aplica entradas, espera estabilizar e registra o vetor
  task automatic apply(input [2:0] s, input cs,
                       input [0:15] dl, input [0:15] du, input [0:15] dd,
                       input integer f);
    sel = s; chip_sel = cs;
    data_in_left = dl; data_in_right_up = du; data_in_right_down = dd;
    #(`T_SETTLE);
    n_vec++;
    $fdisplay(f, "%0d sel=%b cs=%b dl=%h du=%h dd=%h | ou=%h od=%h ol=%h csel=%b flag=%b",
              n_vec, s, cs, dl, du, dd,
              data_out_right_up, data_out_right_down, data_out_left,
              chip_sel_out, flag);
  endtask

  task automatic check(input string what, input [0:15] got, input [0:15] exp);
    if (got !== exp) begin
      n_err++;
      $display("ERRO  vetor %0d  %s: obtido=%h esperado=%h", n_vec, what, got, exp);
    end
  endtask

  task automatic check_cs(input [1:0] got, input [1:0] exp);
    if (got !== exp) begin
      n_err++;
      $display("ERRO  vetor %0d  chip_sel_out: obtido=%b esperado=%b", n_vec, got, exp);
    end
  endtask

  // Codifica 'd' no modo 'm' (0 = ECC1/TBEC, 1 = ECC2/MRSC) pelo proprio DUT
  task automatic encode(input integer m, input [0:15] d, output [0:31] cw);
    apply(m ? 3'b011 : 3'b010, 1'b0, d, 16'h0, 16'h0, fd);
    cw = {data_out_right_up, data_out_right_down};
  endtask

  // Decodifica 'cw' no modo 'm' e devolve o dado corrigido
  task automatic decode(input integer m, input [0:31] cw, output [0:15] d);
    apply(m ? 3'b011 : 3'b010, 1'b0, 16'h0, cw[0:15], cw[16:31], fd);
    d = data_out_left;
  endtask

  // ---------------------------------------------------------------- testes
  logic [0:15] d, q, r1, r2;
  logic [0:31] cw, cw_e;
  integer i, j, k, m;
  localparam int N_RAND = 64;   // palavras aleatorias no ida-e-volta
  localparam int N_ERRW = 8;    // palavras usadas na injecao de erros

  initial begin
    fd       = $fopen(`VEC_FILE, "w");
    fd_undef = $fopen(`VEC_FILE_UNDEF, "w");
    $dumpfile("tb_ecc_design.vcd");
    $dumpvars(0, tb_ecc_design);
    for (m = 0; m < 2; m++) begin tot1[m]=0; cor1[m]=0; tot2[m]=0; cor2[m]=0; end

    // --- 1. Bypass -------------------------------------------------------
    for (i = 0; i < 32; i++) begin
      r1 = $random(seed); r2 = $random(seed); d = $random(seed);
      k  = i % 2;                               // alterna chip_sel
      apply(3'b000, k, d, r1, r2, fd);          // bypass memoria 1
      check("bypass0 out_up",   data_out_right_up,   d);
      check("bypass0 out_down", data_out_right_down, 16'h0);
      check("bypass0 out_left", data_out_left,       r1);
      check_cs(chip_sel_out, {k[0], ~k[0]});
      apply(3'b001, k, d, r1, r2, fd);          // bypass memoria 2
      check("bypass1 out_up",   data_out_right_up,   16'h0);
      check("bypass1 out_down", data_out_right_down, d);
      check("bypass1 out_left", data_out_left,       r2);
      check_cs(chip_sel_out, {~k[0], k[0]});
    end

    // --- 2. Ida e volta sem erro (ECC1 e ECC2) --------------------------
    for (m = 0; m < 2; m++) begin
      for (i = 0; i < N_RAND + 4; i++) begin
        case (i)                                 // cantos + aleatorios
          0: d = 16'h0000;  1: d = 16'hFFFF;
          2: d = 16'hAAAA;  3: d = 16'h5555;
          default: d = $random(seed);
        endcase
        encode(m, d, cw);
        check_cs(chip_sel_out, 2'b00);           // cs=0 -> {cs,cs}
        decode(m, cw, q);
        check(m ? "ECC2 sem erro" : "ECC1 sem erro", q, d);
      end
    end

    // --- 3. Caracterizacao: erros de 1 e 2 bits -------------------------
    for (m = 0; m < 2; m++) begin
      for (k = 0; k < N_ERRW; k++) begin
        d = $random(seed);
        encode(m, d, cw);
        for (i = 0; i < 32; i++) begin
          cw_e = cw; cw_e[i] = ~cw_e[i];
          decode(m, cw_e, q);
          tot1[m]++; if (q === d) cor1[m]++;
          for (j = i + 1; j < 32; j++) begin
            cw_e = cw; cw_e[i] = ~cw_e[i]; cw_e[j] = ~cw_e[j];
            decode(m, cw_e, q);
            tot2[m]++; if (q === d) cor2[m]++;
          end
        end
      end
    end

    // --- 4. Modos sem implementacao (100, 101, 110, 111): so registro ---
    for (i = 4; i < 8; i++) begin
      d = $random(seed); r1 = $random(seed); r2 = $random(seed);
      apply(i[2:0], 1'b1, d, r1, r2, fd_undef);
    end

    // --- Resumo ----------------------------------------------------------
    $display("");
    $display("==================== RESUMO tb_ecc_design ====================");
    $display(" Vetores aplicados            : %0d", n_vec);
    $display(" Falhas nas checagens duras   : %0d", n_err);
    $display(" ECC1 (TBEC-RSC) 1 bit        : %0d / %0d corrigidos", cor1[0], tot1[0]);
    $display(" ECC1 (TBEC-RSC) 2 bits       : %0d / %0d corrigidos", cor2[0], tot2[0]);
    $display(" ECC2 (MRSC)     1 bit        : %0d / %0d corrigidos", cor1[1], tot1[1]);
    $display(" ECC2 (MRSC)     2 bits       : %0d / %0d corrigidos", cor2[1], tot2[1]);
    $display(" Vetores gravados em          : %s", `VEC_FILE);
    $display(" RESULTADO: %s", (n_err == 0) ? "PASSOU" : "FALHOU");
    $display("===============================================================");
    $fclose(fd); $fclose(fd_undef);
    $finish;
  end

endmodule
