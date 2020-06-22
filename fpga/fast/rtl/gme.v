/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: gme.v
//Version: 2.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)receive key from previous module 
// 2)transmit key to lookup
// 3)transmit index to next module
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/08/24
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module gme #(
    parameter    PLATFORM = "Xilinx",
         LMID = 8'd3,
		 NMID = 8'd4
)(   
    input clk,
    input rst_n,
			 
//lookup gme read index
    input in_gme_index_wr,
    input [15:0] in_gme_index,
	output wire out_gme_index_alf,		 
//receive from Previous module
    input [511:0] in_gme_key,
	input  in_gme_key_wr,
	output out_gme_key_alf,

    input [255:0] in_gme_md,
	input in_gme_md_wr,
	output wire out_gme_md_alf,
	
    input [1023:0] in_gme_phv,
	input in_gme_phv_wr,   
	output wire out_gme_phv_alf,
	
//transport to next module
    output reg [255:0] out_gme_md,
	output reg  out_gme_md_wr,
	input in_gme_md_alf,

    output reg [1023:0] out_gme_phv,
	output reg  out_gme_phv_wr,   
	input in_gme_phv_alf,
	 
//transport key to lookup
    output reg out_gme_key_wr,
    output reg [511:0] out_gme_key,
    input in_gme_key_alf,
//localbus to gme
    input cfg2gme_cs_n, //low active
	output reg gme2cfg_ack_n, //low active
	input cfg2gme_rw, //0 :write, 1 :read
	input [31:0] cfg2gme_addr,
	input [31:0] cfg2gme_wdata,
	output reg [31:0] gme2cfg_rdata,
	
//input configure pkt from DMA
    input [133:0] cin_gme_data,
	input cin_gme_data_wr,
	output cout_gme_ready,
	
//output configure pkt to next module
    output reg [133:0] cout_gme_data,
	output reg cout_gme_data_wr,
	input cin_gme_ready
         
);

//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
reg [31:0] in_gme_index_count;
reg [31:0] gme_status;
reg [31:0] in_gme_key_count;
reg [31:0] in_gme_md_count;
reg [31:0] out_gme_md_count;    //gme output md count
reg [31:0] out_gme_phv_count;   //gme output phv count
reg [31:0] out_gme_key_count;   //gme output key count
reg [31:0] in_gme_phv_count;

reg [7:0] address_a;
reg [7:0] address_b;
reg [7:0] index_addr;
reg [31:0] data_a;
reg [31:0] data_b;
reg index_rw;
reg ctrl_rw;
wire [31:0] q_a;
wire [31:0] q_b;

reg MD_fifo_rd;
wire [255:0] MD_fifo_rdata; 
wire MD_fifo_empty;
wire [7:0] MD_fifo_usedw;

reg PHV_fifo_rd;
wire [1023:0] PHV_fifo_rdata;
wire PHV_fifo_empty;
wire [7:0] PHV_fifo_usedw;

reg cin_gme_rd;
wire [133:0] cin_gme_rdata;
wire [7:0] ctrl_fifo_usedw;
wire ctrl_fifo_empty;
wire ctrl_fifo_full;

reg index_fifo_rd;
wire [15:0]index_fifo_rdata;
wire [10:0] um2match_usedw;
wire index_fifo_empty;

assign out_gme_key_alf=in_gme_key_alf;
assign out_gme_md_alf= in_gme_md_alf  ||(MD_fifo_usedw>8'd250);
assign out_gme_phv_alf = in_gme_phv_alf ||(PHV_fifo_usedw>8'd250);
assign out_gme_index_alf = um2match_usedw>11'd1020;
assign cout_gme_ready = ~ ctrl_fifo_full;


//*******************************************
//         Transport key to lookup
//*******************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        out_gme_key_wr <= 1'b0;
        out_gme_key <= 512'b0;
    end
    else begin
        if((in_gme_key_wr == 1'b1) &&(in_gme_md[87:80] == LMID))begin
            out_gme_key_wr <= in_gme_key_wr;
            out_gme_key <= in_gme_key;
        end
        else begin
            out_gme_key_wr <= 1'b0;
            out_gme_key <= out_gme_key;
        end
    end
end

//***************************************
//            Transmit MD & PHV
//***************************************
reg [1:0]md_phv_state;
localparam md_phv_idle=2'd0,
	       md_phv_data=2'd1,
		   wait0      =2'd2,
		   wait1      =2'd3;
reg md_flag;
reg  [255:0]out_gme_md_reg;
always @(posedge clk or negedge rst_n) begin 
    if(rst_n == 1'b0) begin 
	    MD_fifo_rd<=1'b0;
        out_gme_md <= 256'b0;
        out_gme_md_wr <= 1'b0;
		out_gme_md_reg<=256'b0;
		PHV_fifo_rd <= 1'b0;
        out_gme_phv <= 1024'b0;	
		out_gme_phv_wr<=1'b0;
		md_phv_state <= md_phv_idle;
		index_fifo_rd<=1'b0;
		md_flag<=1'b0;
		
		address_a <= 8'b0;
		data_a <= 32'b0;
		index_rw <= 1'b0;
		
    end 
    else begin 
		case(md_phv_state)
		    md_phv_idle:begin
			 MD_fifo_rd<=1'b0;
             out_gme_md <= 256'b0;
             out_gme_md_wr <= 1'b0;
			 md_flag<=1'b0;
			 PHV_fifo_rd <= 1'b0;
             out_gme_phv <= 1024'b0;	
		     out_gme_phv_wr<=1'b0;
			 out_gme_md_reg<=256'b0;
			 
             address_a <= 8'b0;
		     data_a <= 32'b0;
		     index_rw <= 1'b0;
			 
			 index_fifo_rd<=1'b0;
			if((MD_fifo_empty == 1'b0)&&(PHV_fifo_empty == 1'b0))begin			   
                if(MD_fifo_rdata[87:80] == LMID) begin 
					if(index_fifo_empty==1'b0)begin
					    MD_fifo_rd<=1'b1;
						index_fifo_rd<=1'b1;
			            PHV_fifo_rd <= 1'b1;	
                        out_gme_md_reg <= {MD_fifo_rdata[255:88],8'd4,MD_fifo_rdata[79:0]};	
                        md_flag<=1'b1;	
						
						address_a <= index_fifo_rdata[7:0];
						index_addr <= index_fifo_rdata[7:0];
						md_phv_state<=wait0;
                    end
                    else begin
					    md_phv_state<=md_phv_idle;
					end
			    end
				else begin
					MD_fifo_rd<=1'b1;
			        PHV_fifo_rd <= 1'b1;
				    out_gme_md_reg <= 256'b0;
					md_flag<=1'b0;
					md_phv_state<=md_phv_data;					
				end
				
			end
			else begin
			   md_phv_state<=md_phv_idle;
			end
		end
		wait0:begin
		    MD_fifo_rd<=1'b0;
			PHV_fifo_rd <= 1'b0;
			index_fifo_rd<=1'b0;
		    md_phv_state <= wait1;
		end
		wait1:begin
		   md_phv_state <= md_phv_data;	
		end
		md_phv_data:begin
		    MD_fifo_rd<=1'b0;
			PHV_fifo_rd <= 1'b0;
			index_fifo_rd<=1'b0;
			
		    if(md_flag==1'b0)begin  //just trans
                out_gme_md <= MD_fifo_rdata;
                out_gme_md_wr <= 1'b1;
				out_gme_phv <= PHV_fifo_rdata;
		        out_gme_phv_wr<=1'b1; 
				md_phv_state<=md_phv_idle;
			end
			else begin			  
                    out_gme_md <= {out_gme_md_reg[255:64],index_fifo_rdata[12:0],1'b1,out_gme_md_reg[49:0]}; //use MD[63:50] to store index
                    out_gme_md_wr <= 1'b1;
					out_gme_phv <= PHV_fifo_rdata;
		            out_gme_phv_wr<=1'b1; 
					index_rw <= 1'b1;
			        data_a <= q_a[31:0] + 1'b1;
			        address_a <= index_addr;
					md_phv_state<=md_phv_idle;			
			end
		end
		default:md_phv_state<=md_phv_idle;
		endcase
	end							      
end 


//***************************************
//            read index count
//***************************************
reg [2:0] cfg_state;
localparam idle_s  = 3'd0,
           write_s = 3'd1,
		   wait0_s = 3'd2,
		   read_s  = 3'd3,
		   tran_s  = 3'd4,
		   discard_s = 3'd5;
           	   
always @ ( posedge clk or negedge rst_n ) begin
    if(rst_n == 1'b0) begin
	   cout_gme_data <= 134'b0;
	   cout_gme_data_wr <= 1'b0;
	   cin_gme_rd <= 1'b0;	   
	   address_b <= 8'b0;
       ctrl_rw <= 1'b0;
	   cfg_state <= idle_s;   
	end
	else begin
	   case(cfg_state)
	   idle_s:begin
	      cin_gme_rd <= 1'b0;
	      cout_gme_data <= 134'b0;
	      cout_gme_data_wr <= 1'b0;
          ctrl_rw <= 1'b0;
		  address_b <= 8'b0;
	      if((ctrl_fifo_empty == 1'b0)&&(cin_gme_ready == 1'b1)) begin

		     if(cin_gme_rdata[103:96] == LMID ) begin
			    if((cin_gme_rdata[126:124] == 3'b001) && (cin_gme_rdata[133:132] == 2'b01) ) begin  //read
				   address_b <= cin_gme_rdata[74:67];     //read address
				   cfg_state <= wait0_s;
				end
				else if ((cin_gme_rdata [126:124] == 3'b010) && (cin_gme_rdata[133:132] == 2'b01)) begin  //write
				   cfg_state <= write_s;
				end
			 end
			 else begin
			    cin_gme_rd <= 1'b1;
			    cfg_state <= tran_s;
			 end
		  end
		  else begin
		    cfg_state <= idle_s;
		  end	   
	   end
	   write_s: begin
	      cin_gme_rd <= 1'b1;
		  ctrl_rw <= 1'b1;
		  address_b <= cin_gme_rdata[74:67];  //write address
		  data_b <= cin_gme_rdata[31:0];     //write data
	      cfg_state <= discard_s;
	   end
	   wait0_s: begin
	      cin_gme_rd <= 1'b1;
		//  address_b <= 8'b0;
	      cfg_state <= read_s;
	   end
	   read_s :begin
	      cin_gme_rd <= 1'b1;
	      cout_gme_data_wr <= 1'b1;
		  cout_gme_data[133:128] <= cin_gme_rdata[133:128];
		  cout_gme_data[127] <= cin_gme_rdata[127];
	      cout_gme_data[126:124] <= 3'b011;//read ack
	      cout_gme_data[123:112] <= cin_gme_rdata[123:112];
          cout_gme_data[111:104] <= cin_gme_rdata[103:96];
		  cout_gme_data[103:96] <= cin_gme_rdata[111:104];
		  cout_gme_data[95:32] <= cin_gme_rdata[95:32];
		  cout_gme_data[31:0] <= q_b;  //pkt cnt  
	      cfg_state <= tran_s;
	   end
	   tran_s: begin
		  cout_gme_data <= cin_gme_rdata;
		  cout_gme_data_wr <= 1'b1;
		  if(cin_gme_rdata[133:132] == 2'b10) begin
		     cin_gme_rd <= 1'b0;	     
		     cfg_state <= idle_s;	 	  
		  end
		  else begin
		     cin_gme_rd <= 1'b1;
		     cfg_state <= tran_s;	 
		  end		  		    
	   end	
	   discard_s:begin
          cin_gme_rd <= 1'b0;
		  ctrl_rw <= 1'b0;
          cout_gme_data <= cin_gme_rdata;
	      if(cin_gme_rdata[133:132] == 2'b10) begin
	         cfg_state <= idle_s;
	      end
	      else begin
	         cfg_state <= discard_s;
			 cin_gme_rd <= 1'b1;
	      end   
	   end
       default : begin
          cfg_state <= idle_s;
       end	   
	   endcase	
	end
end


//***************************************************
//                  Other IP Instance
//***************************************************
//likely fifo/ram/async block.... 
//should be instantiated below here


ram_32_256 gme_ram_inst
(      
    .clka(clk),
    .dina(data_a),
    .wea(index_rw),
    .addra(address_a),
    .douta(q_a),
    .clkb(clk),
    .web(ctrl_rw),
    .addrb(address_b),
    .dinb(data_b),
    .doutb(q_b)   
);

fifo_134_128 ctrl_fifo(
   .srst(!rst_n),
   .clk(clk),
   .din(cin_gme_data),
   .wr_en(cin_gme_data_wr),
   .dout(cin_gme_rdata),
   .rd_en(cin_gme_rd),
   .data_count(ctrl_fifo_usedw),
   .empty(ctrl_fifo_empty),
   .full(ctrl_fifo_full)
);

fifo_16_1024  fifo_16_1024_inst(
	.srst(!rst_n),
	.clk(clk),
	.din(in_gme_index),
	.rd_en(index_fifo_rd),
	.wr_en(in_gme_index_wr),
	.dout(index_fifo_rdata),
	.data_count(um2match_usedw),
	.empty(index_fifo_empty),
	.full()

	);
fifo_256_256  MD_fifo(
	.srst(!rst_n),
	.clk(clk),
	.din(in_gme_md),
	.rd_en(MD_fifo_rd),
	.wr_en(in_gme_md_wr),
	.dout(MD_fifo_rdata),
	.data_count(MD_fifo_usedw),
	.empty(MD_fifo_empty),
	.full()

	);
fifo_1024_256  PHV_fifo(
    .srst(!rst_n),
    .clk(clk),
    .din(in_gme_phv),
    .rd_en(PHV_fifo_rd),
    .wr_en(in_gme_phv_wr),
    .dout(PHV_fifo_rdata),
    .data_count(PHV_fifo_usedw),
    .empty(PHV_fifo_empty),
    .full()
    );
		
	
//***************************************************
//                 out_gme_md_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gme_md_count <= 32'b0;	 
	 end
	 else begin
	    if(out_gme_md_wr == 1'b1 ) begin
		    out_gme_md_count <= out_gme_md_count + 32'b1 ; 
		end
		else begin
		    out_gme_md_count <= out_gme_md_count; 
		end
	     
	 end	 
end

//***************************************************
//                 out_gme_phv_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gme_phv_count <= 32'b0;	 
	 end
	 else begin
	    if(out_gme_phv_wr == 1'b1 ) begin
		   out_gme_phv_count <= out_gme_phv_count + 32'b1;
		end
		else begin
		   out_gme_phv_count <= out_gme_phv_count ;
		end
	      
	 end	 
end

//***************************************************
//                 out_gme_key_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gme_key_count <= 32'b0;	 
	 end
	 else begin
	    if(out_gme_key_wr == 1'b1 ) begin
		   out_gme_key_count <= out_gme_key_count + 32'b1; 
		end
		else begin
		   out_gme_key_count <= out_gme_key_count ; 
		end	     
	 end	 
end	

//***************************************************
//                 in_gme_md_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_gme_md_count <= 32'b0;	 
	 end
	 else begin
	    if(in_gme_md_wr == 1'b1 ) begin
		    in_gme_md_count <= in_gme_md_count + 32'b1 ; 
		end
		else begin
		    in_gme_md_count <= in_gme_md_count ; 
		end
	     
	 end	 
end

//***************************************************
//                 in_gme_phv_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_gme_phv_count <= 32'b0;	 
	 end
	 else begin
	    if(in_gme_phv_wr == 1'b1 ) begin
		   in_gme_phv_count <= in_gme_phv_count + 32'b1;
		end
		else begin
		   in_gme_phv_count <= in_gme_phv_count ;
		end
	      
	 end	 
end

//***************************************************
//                 in_gme_key_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_gme_key_count <= 32'b0;	 
	 end
	 else begin
	    if(in_gme_key_wr == 1'b1 ) begin
		   in_gme_key_count <= in_gme_key_count + 32'b1; 
		end
		else begin
		   in_gme_key_count <= in_gme_key_count ; 
		end	     
	 end	 
end

//***************************************************
//                 in_gme_index_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_gme_index_count <= 32'b0;	 
	 end
	 else begin
	    if(in_gme_index_wr == 1'b1 ) begin
		   in_gme_index_count <= in_gme_index_count + 32'b1; 
		end
		else begin
		   in_gme_index_count <= in_gme_index_count ; 
		end	     
	 end	 
end

//***************************************************
//                 status
//***************************************************
always @(posedge clk or negedge rst_n) begin
   if(rst_n == 1'b0) begin
      gme_status <= 32'b0;
   end
   else begin
      gme_status <= {md_phv_state,23'b0,out_gme_md_alf,out_gme_phv_alf,out_gme_key_alf,in_gme_md_alf,in_gme_phv_alf,in_gme_key_alf,out_gme_index_alf};
   end
end

//***************************************************
//                 cfg entry
//***************************************************
wire gme_cs_n;
reg [2:0] gme_cfg_state;
sync_sig sync_gme_inst(
    .clk(clk),
	.rst_n(rst_n),
	.in_sig(~cfg2gme_cs_n),
	.out_sig(gme_cs_n)
);

localparam IDLE_C  = 3'd1,
           WRITE_C = 3'd2,
		   READ_C  = 3'd3,
		   WAIT_C  = 3'd4,
		   ACK_C   = 3'd5;
		  
always@(posedge clk or negedge rst_n) begin
   if(rst_n == 1'b0) begin
      gme2cfg_ack_n <= 1'b1;
	  gme2cfg_rdata <= 32'b0;
	  gme_cfg_state <= IDLE_C;
   end
   else begin
      case(gme_cfg_state)
	    IDLE_C:begin
		   gme2cfg_ack_n <= 1'b1;
		   gme2cfg_rdata <= 32'b0;
		   if((gme_cs_n == 1'b1) && (gme2cfg_ack_n == 1'b1)) begin
		      if(cfg2gme_rw == 1'b0) begin    //write
			     gme_cfg_state <= WRITE_C;
			  end
			  else begin                      //read
			     gme_cfg_state <= READ_C;
			  end
		   end
		   else begin
		      gme_cfg_state <= IDLE_C;
		   end
		
		end
		WRITE_C:begin
		   gme_cfg_state <= ACK_C;
		end
		READ_C:begin
		   gme_cfg_state <= WAIT_C;
		end
		WAIT_C:begin
		   gme_cfg_state <= ACK_C;
		end
		ACK_C:begin
		   case(cfg2gme_addr[9:2])
		       8'h0:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'h1:begin
			      gme2cfg_rdata <= gme_status;
			   end
			   8'h2:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'h3:begin
			      gme2cfg_rdata <= in_gme_md_count;
			   end
			   8'h4:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'h5:begin
			      gme2cfg_rdata <= in_gme_phv_count;
			   end
			   8'h6:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'h7:begin
			      gme2cfg_rdata <= in_gme_key_count;
			   end 
			   8'h8:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'h9:begin
			      gme2cfg_rdata <= in_gme_index_count;
			   end
			   8'ha:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'hb:begin
			      gme2cfg_rdata <= out_gme_md_count;
			   end
			   8'hc:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'hd:begin
			      gme2cfg_rdata <= out_gme_phv_count;
			   end
			   8'he:begin
			      gme2cfg_rdata <= 32'b0;
			   end
			   8'hf:begin
			      gme2cfg_rdata <= out_gme_key_count;
			   end
			   default:begin
			      gme2cfg_rdata <= 32'b0;
			   end
		   endcase
		   
		   if(gme_cs_n == 1'b1) begin
		      gme2cfg_ack_n <= 1'b0;
			  gme_cfg_state <= ACK_C;
		   end
		   else begin
		      gme2cfg_ack_n <= 1'b1;
			  gme_cfg_state <= IDLE_C;
		   end		   
		
		end
		default:begin
		   gme2cfg_ack_n <= 1'b1;
		   gme2cfg_rdata <= 32'b0;
		   gme_cfg_state <= IDLE_C;
		end
	  endcase
   end

end


endmodule
   





    
