`include "TBEC_RSC_encoder.sv"
`include "TBEC_RSC_decoder.sv"
`include "MRSC_encoder.sv"
`include "MRSC_decoder.sv"
//`include "EDACencoder.sv"
//`include "EDACdecoder.sv"

module ecc_design(input logic [0:15] data_in_left, // entrada FPGA pelo processador
                  output logic [0:15] data_out_right_up, // saída memória 1
                  output logic [0:15] data_out_right_down, // saída memória 2
                  input logic [0:15] data_in_right_up, // entrada memória 1
                  input logic [0:15] data_in_right_down, // entrada memória 2
                  output logic [0:15] data_out_left, // saida FPGA para o processador
                  input logic [2:0] sel,             // seletor ecc/bypass
                  output logic [0:2] flag,
                  output logic [1:0] chip_sel_out,
                  input logic chip_sel);
 
  logic [0:15] decoder_output1;
  logic [0:31] encoder_output1;
  logic [0:15] decoder_output2;
  logic [0:31] encoder_output2;
  
  logic [0:15] decoder_output3;
  logic [0:31] encoder_output3;
  
  logic [0:15] decoder_output4;
  logic [0:31] encoder_output4;
  

  TBEC_RSC_encoder codificador1(.data_in(data_in_left),.data_out(encoder_output1));
  TBEC_RSC_decoder decodificador1 (.data_in( {data_in_right_up,data_in_right_down}), .data_out(decoder_output1),.flag(flag));
  
  MRSC_encoder codificador2(.data_in(data_in_left),.data_out(encoder_output2));
  MRSC_decoder decodificador2 (.data_in( {data_in_right_up,data_in_right_down}), .data_out(decoder_output2));
  
  always_comb begin
    data_out_right_up    = '0;
    data_out_right_down  = '0;
    data_out_left        = '0;
    chip_sel_out         = 2'b11; 
    case (sel)
        3'b000 : begin //BYPASS memória 1
            data_out_right_up =  data_in_left;
            data_out_left = data_in_right_up;
            chip_sel_out = {chip_sel,!chip_sel};
                end
        3'b001 : begin //BYPASS memória 2
            data_out_right_down =  data_in_left;
            data_out_left  = data_in_right_down;
            chip_sel_out = {!chip_sel,chip_sel};
                end
        3'b010 : begin 
            //ECC1 TBEC_RSC
            data_out_right_up = encoder_output1[0:15];
            data_out_right_down = encoder_output1[16:31];
            data_out_left =  decoder_output1;
            chip_sel_out = {chip_sel,chip_sel};
                end
        3'b011 : begin 
            //ECC2 MRSC
            data_out_right_up = encoder_output2[0:15];
            data_out_right_down = encoder_output2[16:31];
            data_out_left =  decoder_output2;
            chip_sel_out = {chip_sel,chip_sel};
                end
        default: begin
            // error
            data_out_right_up   = data_in_left;
            data_out_left       = data_in_right_up;
            chip_sel_out        = 2'b11;
      
                end
    endcase
    
   
  end
  
  
    
  
endmodule