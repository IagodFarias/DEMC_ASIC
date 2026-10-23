`timescale 1ns/1ps
`ifndef DUT_MODULE
 `define DUT_MODULE ecc_mux_reference
`endif
module tb_faults;
  logic [0:15] data_in_left,data_in_right_up,data_in_right_down;
  logic [0:15] data_out_right_up,data_out_right_down,data_out_left;
  logic [2:0] sel;
  logic [0:2] flag;
  logic [1:0] chip_sel_out;
  logic chip_sel;
  logic [0:31] cw,errword;
  logic [0:15] d;
  integer n0=0,n1=0,n2=0,good0=0,good1=0,good2=0;
  `DUT_MODULE dut(.*);
  task automatic exercise(input logic[2:0] code);
    sel=code;chip_sel=0;
    for(int w=0;w<8;w++) begin
      d=(16'hBEEF ^ (16'h2417 * w));
      data_in_left=d;data_in_right_up='0;data_in_right_down='0;#5;
      cw={data_out_right_up,data_out_right_down};
      data_in_right_up=cw[0:15];data_in_right_down=cw[16:31];#5;
      n0++;if(data_out_left===d)good0++;
      for(int a=0;a<32;a++) begin
        errword=cw;errword[a]=~errword[a];
        data_in_right_up=errword[0:15];data_in_right_down=errword[16:31];#5;
        n1++;if(data_out_left===d)good1++;
        for(int b=a+1;b<32;b++) begin
          errword=cw;errword[a]=~errword[a];errword[b]=~errword[b];
          data_in_right_up=errword[0:15];data_in_right_down=errword[16:31];#5;
          n2++;if(data_out_left===d)good2++;
        end
      end
    end
    $display("FAULTS sel=%b no-error=%0d/%0d single=%0d/%0d double=%0d/%0d",code,good0,n0,good1,n1,good2,n2);
    if (good0!=n0) $fatal(1,"No-error roundtrip failed");
  endtask
  initial begin
    data_in_left=0;data_in_right_up=0;data_in_right_down=0;
`ifdef TBEC_MODE
    exercise(3'b010);
`else
    exercise(3'b011);
`endif
    $finish;
  end
endmodule
