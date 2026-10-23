// TBEC-RSC decoder, upstream syndrome/correction logic with latches removed.
// NOTE: the upstream 'flag' outputs retained stale values. This version defaults to zero.
module TBEC_RSC_decoder(input logic [0:31] data_in,
                         output logic [0:15] data_out,output logic [0:2] flag);
  logic [0:3] signal [0:3];
  logic [0:1] linsin [0:3];
  logic [0:3] SP,SDi;
  logic bit1,bit2,bit3;
  integer sumSL,sumSP,sumSDi,quad1,quad2;
  always_comb begin
    // Mandatory defaults (prevents latches in all branches).
    bit1=1'b0;bit2=1'b0;bit3=1'b0;
    sumSL=0;sumSP=0;sumSDi=0;quad1=0;quad2=0;
    for(int b=0;b<4;b++) begin
      signal[b]={data_in[b], data_in[b+4],data_in[b+8],data_in[b+12]};
    end
    linsin[0][0]=signal[0][0]^signal[0][2]^data_in[24];
    linsin[0][1]=signal[0][1]^signal[0][3]^data_in[25];
    linsin[1][0]=signal[1][0]^signal[1][2]^data_in[26];
    linsin[1][1]=signal[1][1]^signal[1][3]^data_in[27];
    linsin[2][0]=signal[2][0]^signal[2][2]^data_in[28];
    linsin[2][1]=signal[2][1]^signal[2][3]^data_in[29];
    linsin[3][0]=signal[3][0]^signal[3][2]^data_in[30];
    linsin[3][1]=signal[3][1]^signal[3][3]^data_in[31];
    SP[0]=signal[0][0]^signal[0][1]^signal[1][0]^signal[1][1]^data_in[20];
    SP[1]=signal[2][0]^signal[2][1]^signal[3][0]^signal[3][1]^data_in[22];
    SP[2]=signal[0][2]^signal[0][3]^signal[1][2]^signal[1][3]^data_in[23];
    SP[3]=signal[2][2]^signal[2][3]^signal[3][2]^signal[3][3]^data_in[21];
    SDi[0]=signal[0][0]^signal[1][1]^signal[2][0]^signal[3][1]^data_in[16];
    SDi[1]=signal[0][1]^signal[1][0]^signal[2][1]^signal[3][0]^data_in[18];
    SDi[2]=signal[0][2]^signal[1][3]^signal[2][2]^signal[3][3]^data_in[19];
    SDi[3]=signal[0][3]^signal[1][2]^signal[2][3]^signal[3][2]^data_in[17];
    for(int b=0;b<4;b++) sumSL+=int'(linsin[b][0])+int'(linsin[b][1]);
    for(int b=0;b<4;b++) begin sumSP+=int'(SP[b]);sumSDi+=int'(SDi[b]);end
    if (((((SP!=4'b0000)&&(SDi!=4'b0000)) || (sumSL>1))) &&
         !((sumSDi==0)&&(sumSP==1)&&(sumSL>=2))) begin
      quad1=int'(SP[0])+int'(SP[1])+int'(SDi[0])+int'(SDi[1]);
      quad2=int'(SP[2])+int'(SP[3])+int'(SDi[2])+int'(SDi[3]);
      if(quad1>quad2) begin
        bit1=1'b1;
        for(int b=0;b<4;b++) if(linsin[b]!=2'b00)
          signal[b][0:1]=signal[b][0:1]^linsin[b];
      end else if(quad1<quad2) begin
        bit2=1'b1;
        for(int b=0;b<4;b++) if(linsin[b]!=2'b00)
          signal[b][2:3]=signal[b][2:3]^linsin[b];
      end else if((quad1==quad2)&&({SP[0],SP[1],SDi[0],SDi[1]}!=4'b0000)) begin
        bit3=1'b1;
        for(int b=0;b<4;b++) if(linsin[b]!=2'b00)
          signal[b][1:2]=signal[b][1:2]^{linsin[b][1],linsin[b][0]};
      end
    end
  end
  assign data_out={signal[0],signal[1],signal[2],signal[3]};
  assign flag={bit1,bit2,bit3};
endmodule
