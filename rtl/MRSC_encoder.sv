module MRSC_encoder(input logic [0:15] data_in, output logic [0:31] data_out);
	 logic [0:3] signal [0:3];
	 logic  Di[0:3];
	 logic  P[0:3];
	 logic  [0:1] Cb[0:3];
	
  always_comb
begin
  
   integer b;
	signal[0][0:3]=data_in[0:3];
	signal[1][0:3]=data_in[4:7];
	signal[2][0:3]=data_in[8:11];
	signal[3][0:3]=data_in[12:15];
	for(b=0;b<4;b=b+1)
	begin
		Cb[b][0]=signal[b][0]^signal[b][2];
		Cb[b][1]=signal[b][1]^signal[b][3];	
	end
	
	P[0]=signal[0][0]^signal[1][0]^signal[2][0]^signal[3][0];
    P[1]=signal[0][1]^signal[1][1]^signal[2][1]^signal[3][1];
    P[2]=signal[0][2]^signal[1][2]^signal[2][2]^signal[3][2];
    P[3]=signal[0][3]^signal[1][3]^signal[2][3]^signal[3][3];
    
    Di[0]=signal[0][0]^signal[1][1]^signal[2][0]^signal[3][1];
    Di[1]=signal[0][1]^signal[1][0]^signal[2][1]^signal[3][0];
    Di[2]=signal[0][2]^signal[1][3]^signal[2][2]^signal[3][3];
    Di[3]=signal[0][3]^signal[1][2]^signal[2][3]^signal[3][2];
end
assign data_out={signal[0][0],signal[1][0],signal[2][0],signal[3][0],
		signal[0][1],signal[1][1],signal[2][1],signal[3][1],
		signal[0][2],signal[1][2],signal[2][2],signal[3][2],
		signal[0][3],signal[1][3],signal[2][3],signal[3][3],
		Di[0],Di[3],Di[1],Di[2],P[0],P[3],P[1],P[2],Cb[0][0:1],Cb[1][0:1],Cb[2][0:1],Cb[3][0:1]};

endmodule
