`timescale 1ns/1ps
`ifndef DUT_MODULE
  `define DUT_MODULE ecc_mux_reference
`endif
// Same deterministic transaction sequence for every selected design.
// The testbench acts as memory controller + two 16-bit SRAM arrays (32-bit encoded word).
// Scenario: tbec, mrsc, mixed. For mixed, each address retains its ECC tag.
module tb_ecc_bench;
  localparam int NWORDS=64;
  localparam int NOPS=1500;
  logic [0:15] data_in_left,data_in_right_up,data_in_right_down;
  logic [0:15] data_out_right_up,data_out_right_down,data_out_left;
  logic [2:0] sel;
  logic [0:2] flag;
  logic [1:0] chip_sel_out;
  logic chip_sel;
  logic [0:31] mem [0:NWORDS-1];
  logic [0:15] expected [0:NWORDS-1];
  logic [2:0] code_tag [0:NWORDS-1];
  logic [31:0] rnd_state;
  string scenario,vcd_path;
  integer errors=0, n_reads=0,n_writes=0;
  `DUT_MODULE dut(.*);
`ifdef SDF_FILE
  initial $sdf_annotate(`SDF_FILE, dut, , "sdf_annotate.log", "MAXIMUM");
`endif
  task automatic nextrand(output logic [31:0] r);
    rnd_state=rnd_state^(rnd_state<<13);
    rnd_state=rnd_state^(rnd_state>>17);
    rnd_state=rnd_state^(rnd_state<<5);
    r=rnd_state;
  endtask
  task automatic store(input integer addr,input logic [2:0] mode,input logic [0:15] data);
    sel=mode;
    chip_sel=1'b0;
    data_in_left=data;
    data_in_right_up='0;
    data_in_right_down='0;
    #5;
    if (chip_sel_out!==2'b00) begin
      $display("FAIL chip_sel store addr=%0d",addr);errors++;
    end
    mem[addr]={data_out_right_up,data_out_right_down};
    expected[addr]=data;
    code_tag[addr]=mode;
    n_writes++;
  endtask
  task automatic load(input integer addr,input logic [0:15] noise_on_write_bus);
    // IMPORTANT: select the code that was used when THIS address was encoded.
    sel=code_tag[addr];
    chip_sel=1'b0;
    data_in_left=noise_on_write_bus; // toggles unselected encoder inputs
    data_in_right_up=mem[addr][0:15];
    data_in_right_down=mem[addr][16:31];
    #5;
    if (data_out_left!==expected[addr]) begin
      errors++;
      if (errors<12) $display("FAIL roundtrip addr=%0d sel=%b got=%h expected=%h",addr,sel,data_out_left,expected[addr]);
    end
    n_reads++;
  endtask
  function automatic logic[2:0] choose_mode(input integer addr,input logic[31:0] randval);
    if(scenario=="tbec") return 3'b010;
    if(scenario=="mrsc") return 3'b011;
    // mixed: deterministic alternating code selection with changing streak lengths
    return ( (addr+randval[3:2])%4 < 2 ) ? 3'b010:3'b011;
  endfunction
  logic [31:0] r,s;
  integer addr;
  initial begin
    if(!$value$plusargs("SCENARIO=%s",scenario)) scenario="tbec";
    if(!$value$plusargs("VCD=%s",vcd_path)) vcd_path="bench.vcd";
    if(scenario!="tbec" && scenario!="mrsc" && scenario!="mixed") begin
      $fatal(1,"SCENARIO must be tbec|mrsc|mixed");
    end
    rnd_state=32'h5EEDC0DE;
    sel=3'b111;chip_sel=1'b1;
    data_in_left='0;data_in_right_up='0;data_in_right_down='0;
    // VCD is off during initialization, and on for the measured traffic window.
    $dumpfile(vcd_path);$dumpvars(0,dut);$dumpoff;
    #5;
    // Test bypass paths, independent of selected scenario.
    sel=3'b000;chip_sel=1'b0;data_in_left=16'hACDC;
    data_in_right_up=16'h5321;data_in_right_down=16'h0AA0;
    #5;
    if(data_out_right_up!==16'hACDC || data_out_left!==16'h5321) errors++;
    sel=3'b001;#5;
    if(data_out_right_down!==16'hACDC || data_out_left!==16'h0AA0) errors++;
    for(int i=0;i<NWORDS;i++) begin
      nextrand(r);nextrand(s);
      store(i,choose_mode(i,s),r[0:15]);
    end
    n_reads=0;n_writes=0;
    // Re-seed so all tests start a reproducible traffic sequence.
    rnd_state=32'h1234ABCD;
    $dumpon; $display("VCD_START %0.1f ns", $realtime);
    for(int i=0;i<NOPS;i++) begin
      nextrand(r);nextrand(s);
      addr=int'(r%NWORDS);
      if ((i%4)==0) begin
        // mixed mode may change an address's encoding on a complete overwrite.
        // This is safe; changing only the read-mode without rewriting is NOT safe.
        store(addr,choose_mode(addr,s),s[0:15]);
      end else begin
        load(addr,s[0:15]);
      end
    end
    $display("VCD_END %0.1f ns", $realtime); $dumpoff;
    $display("RESULT scenario=%s reads=%0d writes=%0d errors=%0d",scenario,n_reads,n_writes,errors);
    if(errors) $fatal(1,"Functional validation FAILED");
    else $display("PASS: all decoded data match written words");
    $finish;
  end
endmodule
