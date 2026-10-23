module ecc_mrsc_only(
  input logic [0:15] data_in_left,
  output logic [0:15] data_out_right_up,
  output logic [0:15] data_out_right_down,
  input logic [0:15] data_in_right_up,
  input logic [0:15] data_in_right_down,
  output logic [0:15] data_out_left,
  input logic [2:0] sel,
  output logic [0:2] flag,
  output logic [1:0] chip_sel_out,
  input logic chip_sel);
  wire tbec_mode = (sel==3'b010);
  wire mrsc_mode = (sel==3'b011);
  wire ecc_mode = tbec_mode || mrsc_mode;
  logic [0:31] ec_t,ec_m;
  logic [0:15] dc_t,dc_m;
  logic [0:2] fl_t;
  MRSC_encoder u_menc(.data_in(data_in_left),.data_out(ec_m));
  MRSC_decoder u_mdec(.data_in({data_in_right_up,data_in_right_down}),.data_out(dc_m));
  always_comb begin
    data_out_right_up='0;
    data_out_right_down='0;
    data_out_left='0;
    chip_sel_out=2'b11;
    flag='0;
    case(sel)
      3'b000:begin
        data_out_right_up=data_in_left;
        data_out_left=data_in_right_up;
        chip_sel_out={chip_sel,~chip_sel};
      end
      3'b001:begin
        data_out_right_down=data_in_left;
        data_out_left=data_in_right_down;
        chip_sel_out={~chip_sel,chip_sel};
      end
      3'b011:begin
        data_out_right_up=ec_m[0:15];
        data_out_right_down=ec_m[16:31];
        data_out_left=dc_m;
        chip_sel_out={chip_sel,chip_sel};
      end
      default:begin
        // Safe inactive mode: no memory selected; no undefined ECC3/ECC4 signals.
        data_out_right_up='0;
        data_out_right_down='0;
        data_out_left='0;
        chip_sel_out=2'b11;
        flag='0;
      end
    endcase
  end
endmodule
