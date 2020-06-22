/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: goe.v
//Version: 2.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)Transmit pkt to port or cpu
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/08/24
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module goe #(
    parameter   PLATFORM = "Xilinx",
	            LMID = 8'd5
    )(
    input clk,
    input rst_n,
	
//uda pkt waiting for transmit
    input in_goe_data_wr,
    input [133:0] in_goe_data,
    input in_goe_valid_wr,
    input in_goe_valid,
	(*MARK_DEBUG="TRUE"*)output out_goe_alf,
	
    input [1023:0] in_goe_phv,
	input in_goe_phv_wr,
	(*MARK_DEBUG="TRUE"*)output  out_goe_phv_alf,
//pkt waiting for transmit
    output reg pktout_data_wr,
    output reg [133:0] pktout_data,
    output reg pktout_data_valid_wr,
    output reg pktout_data_valid,
    (*MARK_DEBUG="TRUE"*)input pktout_ready,
	
//localbus to goe
    input cfg2goe_cs_n, //low active
	output reg goe2cfg_ack_n, //low active
	input cfg2goe_rw, //0 :write, 1 :read
	input [31:0] cfg2goe_addr,
	input [31:0] cfg2goe_wdata,
	output reg [31:0] goe2cfg_rdata,
	
//input configure pkt from DMA
    input [133:0] cin_goe_data,
	input cin_goe_data_wr,
	output cout_goe_ready,
	
//output configure pkt to next module
    output [133:0] cout_goe_data,
	output cout_goe_data_wr,
	input cin_goe_ready
);

//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
reg [31:0] goe_status;
reg [31:0] in_goe_data_count;
reg [31:0] in_goe_phv_count;
reg [31:0] out_goe_data_count;

//stream fifo
reg in_stream_data_wr;
reg [133:0] in_stream_data;
reg in_stream_valid_wr;
reg in_stream_valid;

reg	[7:0]  address_a;
reg	[7:0]  address_b;
reg	[127:0] data_a;
reg	[127:0] data_b;
reg	 stream_rw;
reg	 cnt_rw;
wire[127:0]  q_a;
wire[127:0]  q_b; 
reg [11:0] pkt_length;

reg  [7:0]stream_addr;
reg stream_data_rd;
wire [133:0]stream_data_q;
wire [7:0]stream_data_usedw;
reg stream_valid_rd;
wire stream_valid_q;
wire stream_valid_emtpy;
//state
reg [1:0]del_state;
reg [2:0]cnt_state;

assign out_goe_phv_alf=1'b0;
assign out_goe_alf = stream_data_usedw > 8'd128;
assign cout_goe_data_wr = cin_goe_data_wr;
assign cout_goe_data = cin_goe_data;
assign cout_goe_ready = cin_goe_ready;

//***********************************
//       discard pkt
//***********************************
localparam del_idle=2'b00,
           del_trans=2'b01;
reg write_en;

always @(posedge clk or negedge rst_n) begin 
    if(rst_n == 1'b0) begin 
        in_stream_data_wr <= 1'b0;
        in_stream_valid_wr <= 1'b0;
        in_stream_data <= 134'b0;
		in_stream_valid<=1'b0;
		write_en<=1'b0;
		del_state<=del_idle;
    end
    else begin
		case(del_state)
		del_idle:begin
		    in_stream_data_wr <= 1'b0;
            in_stream_valid_wr <= 1'b0;
            in_stream_data <= 134'b0;
		    in_stream_valid<=1'b0;
		    write_en<=1'b0;
		    if(in_goe_data_wr==1'b1 && in_goe_data[133:132]==2'b01)begin
		        write_en<=in_goe_data[108];
                in_stream_data_wr <= ~in_goe_data[108]; 
                in_stream_data <= in_goe_data; 
                del_state<=del_trans;			
            end
		    else begin
		        del_state<=del_idle;		
		    end
        end
	    del_trans:begin
	        in_stream_data_wr <= 1'b0;
            in_stream_valid_wr <= 1'b0;
            in_stream_data <= 134'b0;
	    	in_stream_valid<=1'b0;
	        if(in_goe_data_wr==1'b1 && in_goe_data[133:132]==2'b10)begin
	    	    in_stream_data_wr <= ~write_en; 
                in_stream_data <= in_goe_data;
	    		in_stream_valid <= ~write_en;
                in_stream_valid_wr <= ~write_en;
	    		del_state<=del_idle;
	    	end
	    	else if(in_goe_data_wr)begin
	    	    in_stream_data_wr <= ~write_en; 
                in_stream_data <= in_goe_data;
	    		del_state<=del_trans;	
	    	end
	    	else begin
	    	    del_state<=del_trans;			
	    	end
	    end
	    default:begin del_state<=del_idle;end
	    endcase
	end
end

//***********************************
//       stream_cnt
//***********************************
localparam cnt_idle =3'd0,
		   cnt_wait0=3'd1,
		   cnt_wait1=3'd2,
		   cnt_write=3'd3,
		   cnt_trans=3'd4;
always @(posedge clk or negedge rst_n)begin
    if(!rst_n)begin
		address_b<=8'b0;
		data_b<=128'b0;
		stream_rw<=1'b0;
        pktout_data_wr<=1'b0;
        pktout_data<=134'b0;
        pktout_data_valid_wr<=1'b0;
        pktout_data_valid<=1'b0;
		stream_valid_rd<=1'b0;
		stream_data_rd<=1'b0;
		pkt_length <= 12'b0;
		stream_addr<=8'b0;
		cnt_state<=cnt_idle;
	end
	else begin
	case(cnt_state)
	cnt_idle:begin
	    address_b<=8'b0;
		data_b<=128'b0;
		stream_rw<=1'b0;
        pktout_data_wr<=1'b0;
        pktout_data<=134'b0;
        pktout_data_valid_wr<=1'b0;
        pktout_data_valid<=1'b0;
		stream_valid_rd<=1'b0;
		stream_data_rd<=1'b0;
		stream_addr<=8'b0;
	    if(pktout_ready==1'b1 && stream_valid_emtpy==1'b0 )begin
			stream_valid_rd<=1'b1;
		    stream_data_rd<=1'b1;
			stream_rw<=1'b0;
			pkt_length <= stream_data_q[107:96];
			if(stream_data_q[57:50] == 8'b0)begin
			     address_b <= 8'h7f;
                 stream_addr <= 8'h7f;
			end
			else begin
			    address_b <= stream_data_q[57:50];
			    stream_addr <= stream_data_q[57:50];
			end
			cnt_state<=cnt_wait0;
		end
		else begin
		    cnt_state<=cnt_idle;
		end
	end
	cnt_wait0:begin
	    stream_rw<=1'b0;
	    stream_valid_rd<=1'b0;
		stream_data_rd<=1'b1;
	    pktout_data_wr<=1'b1;
        pktout_data<=stream_data_q;
		cnt_state<=cnt_wait1;
	end
	cnt_wait1:begin
	    stream_valid_rd<=1'b0;
		stream_data_rd<=1'b1;
	    pktout_data_wr<=1'b1;
        pktout_data<=stream_data_q;
		cnt_state<=cnt_write;
	end
	cnt_write:begin
	    stream_rw<=1'b1;
		address_b<=stream_addr;
		data_b<={(q_b[127:64]+1'b1),(q_b[63:0]+pkt_length-12'd32)};
		stream_valid_rd<=1'b0;
		stream_data_rd<=1'b1;
	    pktout_data_wr<=1'b1;
        pktout_data<=stream_data_q;
	    cnt_state<=cnt_trans;
	end
	cnt_trans:begin
	    stream_rw<=1'b0;
	    pktout_data_wr<=1'b1;
        pktout_data<=stream_data_q;
		if(stream_data_q[133:132]==2'b10)begin//tail
		    stream_data_rd<=1'b0;
			pktout_data_valid_wr<=1'b1;
            pktout_data_valid<=1'b1;
			cnt_state<=cnt_idle;
		end
		else begin
		    stream_data_rd<=1'b1;
			cnt_state<=cnt_trans;
	    end
	end
	default:cnt_state<=cnt_idle;
	endcase
	end
end	


//***************************************************
//                 cfg entry
//***************************************************
wire goe_cs_n;
reg [2:0] goe_cfg_state;
reg addr_flag;
reg index_flag;
reg high_flag;
sync_sig sync_goe_inst(
    .clk(clk),
	.rst_n(rst_n),
	.in_sig(~cfg2goe_cs_n),
	.out_sig(goe_cs_n)
);

localparam IDLE_C  = 3'd0,
           WRITE_C = 3'd1,
		   READ_C  = 3'd2,
		   WAIT_C  = 3'd3,
		   WAIT0_C = 3'd4,
		   WAIT1_C = 3'd5,
		   ACK_W   = 3'd6,
		   ACK_R   = 3'd7;

		  
always@(posedge clk or negedge rst_n) begin
   if(rst_n == 1'b0) begin
      goe2cfg_ack_n <= 1'b1;
	  goe2cfg_rdata <= 32'b0;
	  address_a <= 8'b0;
	  data_a <= 128'b0;
	  cnt_rw <= 1'b0;
	  addr_flag <= 1'b0;
	  index_flag <= 1'b0;
	  high_flag <= 1'b0;
	  goe_cfg_state <= IDLE_C;
   end
   else begin
      case(goe_cfg_state)
	    IDLE_C:begin
		   goe2cfg_ack_n <= 1'b1;
		   goe2cfg_rdata <= 32'b0;
		   address_a <= 8'b0;
	       data_a <= 128'b0;
	       cnt_rw <= 1'b0;
		   addr_flag <= 1'b0;
		   index_flag <= 1'b0;
		   high_flag <= 1'b0;
		   if((goe_cs_n == 1'b1) && (goe2cfg_ack_n == 1'b1)) begin
		      if(cfg2goe_rw == 1'b0) begin    //write
		         address_a <= {cfg2goe_addr[9:3],1'b1}; //read old data before write
			     goe_cfg_state <= WAIT0_C;
			  end
			  else begin                      //read
			     goe_cfg_state <= READ_C;
				 if(cfg2goe_addr[12] == 1'b0) begin  //module count
				    addr_flag <= 1'b0;
				 end
				 else begin                           //index table count
				    address_a <= {cfg2goe_addr[9:3],1'b1};
				    addr_flag <= 1'b1;
				    if(cfg2goe_addr[2] == 1'b0) begin //low address
                       high_flag <= 1'b1;
                    end
                    else begin                         //high address          
                       high_flag <= 1'b0;
                    end
				    if(cfg2goe_addr[11] == 1'b0) begin  //read count
				       index_flag <= 1'b1;
				    end
				    else begin                         //read length
				       index_flag <= 1'b0;
				    end
				 end
			  end
		   end
		   else begin
		      goe_cfg_state <= IDLE_C;
		   end
		
		end
		WAIT0_C :begin
		   goe_cfg_state <= WAIT1_C;
		end
	    WAIT1_C :begin
           goe_cfg_state <= WRITE_C;
        end
		WRITE_C:begin
		   if(cfg2goe_addr[11] == 1'b0) begin  //write count
		      data_a <= {q_a[127:96],cfg2goe_wdata,q_a[63:0]};	      
		   end
		   else begin                         //write length
              data_a <= {q_a[127:32],cfg2goe_wdata};
		   end
		   address_a <= {cfg2goe_addr[9:3],1'b1};		   
		   cnt_rw <= 1'b1;
		   goe_cfg_state <= ACK_W;
		end
		READ_C:begin
		   goe_cfg_state <= WAIT_C;
		end
		WAIT_C:begin
		   goe_cfg_state <= ACK_R;
		end
		ACK_R:begin		   
		   if(addr_flag) begin  //read index count
		      if(index_flag) begin	
		         if(high_flag) begin
		            goe2cfg_rdata <= q_a[127:96];
		         end
		         else begin
		            goe2cfg_rdata <= q_a[95:64];
		         end	      		         
		      end
		      else begin
		         if(high_flag) begin
                    goe2cfg_rdata <= q_a[63:32];
                 end
                 else begin
                    goe2cfg_rdata <= q_a[31:0];
                 end
		      end 
		   end
		   else begin   //read data count
		      case(cfg2goe_addr[9:2])
		       8'h0:begin
			      goe2cfg_rdata <= 32'b0;
			   end
			   8'h1:begin
			      goe2cfg_rdata <= goe_status;
			   end
			   8'h2:begin
			      goe2cfg_rdata <= 32'b0;
			   end
			   8'h3:begin
			      goe2cfg_rdata <= in_goe_data_count;
			   end
			   8'h4:begin
			      goe2cfg_rdata <= 32'b0;
			   end
			   8'h5:begin
			      goe2cfg_rdata <= in_goe_phv_count;
			   end
			   8'h6:begin
			      goe2cfg_rdata <= 32'b0;
			   end
			   8'h7:begin
			      goe2cfg_rdata <= out_goe_data_count;
			   end
			   default:begin
			      goe2cfg_rdata <= 32'b0;
			   end
		   endcase
		   end
		   
		   
		   if(goe_cs_n == 1'b1) begin
		      goe2cfg_ack_n <= 1'b0;
			  goe_cfg_state <= ACK_R;
		   end
		   else begin
		      goe2cfg_ack_n <= 1'b1;
			  goe_cfg_state <= IDLE_C;
		   end		   
		
		end
		ACK_W:begin
		   cnt_rw <= 1'b0;
		   if(goe_cs_n == 1'b1) begin
              goe2cfg_ack_n <= 1'b0;
              goe_cfg_state <= ACK_W;
           end
           else begin
              goe2cfg_ack_n <= 1'b1;
              goe_cfg_state <= IDLE_C;
           end    
		end
		default:begin
		   goe2cfg_ack_n <= 1'b1;
		   goe2cfg_rdata <= 32'b0;
		   goe_cfg_state <= IDLE_C;
		end
	  endcase
   end

end
   
//***************************************************
//                 out_goe_data_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_goe_data_count <= 32'b0;	 
	 end
	 else begin
	    if(pktout_data_valid_wr == 1'b1 ) begin
		    out_goe_data_count <= out_goe_data_count + 32'b1;
		end
		else begin
		    out_goe_data_count <= out_goe_data_count ;
		end
	      
	 end	 
end

//***************************************************
//                 in_goe_data_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_goe_data_count <= 32'b0;	 
	 end
	 else begin
	    if(in_goe_valid_wr == 1'b1 ) begin
		    in_goe_data_count <= in_goe_data_count + 32'b1 ; 
		end
		else begin
		    in_goe_data_count <= in_goe_data_count ; 	
		end
 
	 end	 
end

//***************************************************
//                 in_goe_pfv_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_goe_phv_count <= 32'b0;	 
	 end
	 else begin
	    if(in_goe_phv_wr == 1'b1 ) begin
		    in_goe_phv_count <= in_goe_phv_count + 32'b1 ; 
		end
		else begin
		    in_goe_phv_count <= in_goe_phv_count ; 
		end
	     
	 end	 
end	   

//***************************************************
//                 status
//***************************************************
always @(posedge clk or negedge rst_n) begin
   if(rst_n == 1'b0) begin
      goe_status <= 32'b0;
   end
   else begin
      goe_status <= {cnt_state,27'b0,pktout_ready,out_goe_alf,out_goe_phv_alf};
   end
end	   

	
ram_128_256 goe_ram_inst
(      
    .clka(clk),
    .dina(data_a),
    .wea(cnt_rw),
    .addra(address_a),
    .douta(q_a),
    .clkb(clk),
    .web(stream_rw),
    .addrb(address_b),
    .dinb(data_b),
    .doutb(q_b)   
);

fifo_134_256  stream_data(
	.srst(!rst_n),
	.clk(clk),
	.din(in_stream_data),
	.rd_en(stream_data_rd),
	.wr_en(in_stream_data_wr),
	.dout(stream_data_q),
	.data_count(stream_data_usedw),
	.empty(),
	.full()
	);
fifo_1_128  stream_valid(
	.srst(!rst_n),
	.clk(clk),
	.din(in_stream_valid),
	.rd_en(stream_valid_rd),
	.wr_en(in_stream_valid_wr),
	.dout(stream_valid_q),
	.empty(stream_valid_emtpy),
	.full()
	);	  	   
endmodule                
                   









    
    