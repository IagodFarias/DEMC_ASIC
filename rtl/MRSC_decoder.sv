
module MRSC_decoder(input logic [0:31] data_in,output logic [0:15] data_out);
logic [0:3] signal [0:3];
logic [0:15]red;
logic [0:1] linsin [0:3];
logic [0:3] SP;
logic [0:3] SDi;

  always_comb
begin
  
  integer b;
integer sumSL,sumSP,sumSDi;
integer quad1;
integer quad2;
  
	signal[0][0:3]={data_in[0],data_in[4],data_in[8],data_in[12]};
	signal[1][0:3]={data_in[1],data_in[5],data_in[9],data_in[13]};
	signal[2][0:3]={data_in[2],data_in[6],data_in[10],data_in[14]};
	signal[3][0:3]={data_in[3],data_in[7],data_in[11],data_in[15]};

	linsin[0][0]=signal[0][0]^signal[0][2]^data_in[24];
	linsin[0][1]=signal[0][1]^signal[0][3]^data_in[25];
	linsin[1][0]=signal[1][0]^signal[1][2]^data_in[26];
    linsin[1][1]=signal[1][1]^signal[1][3]^data_in[27];
	linsin[2][0]=signal[2][0]^signal[2][2]^data_in[28];
    linsin[2][1]=signal[2][1]^signal[2][3]^data_in[29];
	linsin[3][0]=signal[3][0]^signal[3][2]^data_in[30];
    linsin[3][1]=signal[3][1]^signal[3][3]^data_in[31];
	
		
    SP[0]=signal[0][0]^signal[1][0]^signal[2][0]^signal[3][0]^data_in[20];
    SP[1]=signal[0][1]^signal[1][1]^signal[2][1]^signal[3][1]^data_in[22];
    SP[2]=signal[0][2]^signal[1][2]^signal[2][2]^signal[3][2]^data_in[23];
    SP[3]=signal[0][3]^signal[1][3]^signal[2][3]^signal[3][3]^data_in[21];

    SDi[0]=signal[0][0]^signal[1][1]^signal[2][0]^signal[3][1]^data_in[16];
    SDi[1]=signal[0][1]^signal[1][0]^signal[2][1]^signal[3][0]^data_in[18];
    SDi[2]=signal[0][2]^signal[1][3]^signal[2][2]^signal[3][3]^data_in[19];
    SDi[3]=signal[0][3]^signal[1][2]^signal[2][3]^signal[3][2]^data_in[17];
	
	sumSL=1*linsin[1][0] + 1*linsin[1][1]+ 1*linsin[2][0]+ 1*linsin[2][1]+1*linsin[3][0] + 1*linsin[3][1]+ 1*linsin[0][0]+ 1*linsin[0][1];
	
	if((((SP[0:3] !=4'b0000) & (SDi[0:3] !=4'b0000)) |  sumSL>1)) // condi  o para erros em quadrantes
	begin	
		quad1=1*SP[0]+1*SP[1]+1*SDi[0]+1*SDi[1];
		quad2=1*SP[2]+1*SP[3]+1*SDi[2]+1*SDi[3];
		if(quad1 > quad2)// Erro no primeiro quadrante
		begin
			for(b=0;b<4;b=b+1)
			begin
				if(linsin[b][0:1]!=2'b00)
				signal[b][0:1]=signal[b][0:1]^linsin[b][0:1];
			end
		end
		
		else if(quad1 < quad2)// Erro no segundo quadrante
		begin
			for(b=0;b<4;b=b+1)
			begin
				if(linsin[b][0:1]!=2'b00)
				signal[b][2:3]=signal[b][2:3]^linsin[b][0:1];
			end
		end
		
		else if((quad1 == quad2)&({SP[0],SP[1],SDi[0],SDi[1]} !=4'b0000)) // Erro no quadrante central
		begin
				for(b=0;b<4;b=b+1)
				begin
					if(linsin[b][0:1]!=2'b00)
					signal[b][1:2]=signal[b][1:2]^{linsin[b][1],linsin[b][0]};
				end

		end
	end
end
assign data_out={signal[0][0:3],signal[1][0:3],signal[2][0:3],signal[3][0:3]};

endmodule
