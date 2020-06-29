/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: gpp.v
//Version: 2.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)receive pkt from cpu or port
// 2)select & retransmit pkt to data_cache module 
// 3)parse pkt and transmit to next module
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2020/06/27
//      modifier: Yang Xiangrui
//      description: 
//             1) change the data path width from 128 to 256
//             2) use axis_tuser and axis_tkeep as the replacement.
///////////////////////////////////////////////////////////////// 


module gpp #(
    parameter  PLATFORM = "Xilinx",
	           LMID = 8'd1,
	           NMID = 8'd2
    )(
    input clk,
    input rst_n,
	
//receive pkt from cpu or port
    input pktin_data_wr,
    input [133:0] pktin_data,
    input pktin_valid_wr,
    input pktin_data_valid,
    input [1:0]  pktin_axis_tuser,
    input [31:0] pktin_axis_tkeep,
    output pktin_ready,  	
//parse MD AND PHV transmit to next module
    output reg [1023:0] out_gpp_phv,
	output reg out_gpp_phv_wr,
	input in_gpp_phv_alf,       //phv alf

    output reg [255:0] out_gpp_md,
    output reg out_gpp_md_wr,
    input in_gpp_md_alf,        //md alf	  
    
	
//transmit pkt to Data_cache
    output reg out_gpp_data_wr,
    output reg [133:0] out_gpp_data,
    output reg out_gpp_valid_wr,
    output reg out_gpp_valid,
    output reg [1:0]  out_gpp_axis_tuser,
    output reg [31:0] out_gpp_axis_tkeep,
    input in_gpp_data_alf,     //data alf
    
		
//input configure pkt from DMA
    input [133:0] cin_gpp_data,
	input cin_gpp_data_wr,
	output cout_gpp_ready,
	
//output configure pkt to next module
    output [133:0] cout_gpp_data,
	output cout_gpp_data_wr,
	input cin_gpp_ready
		
);

//***************************************************
//        Intermediate variable Declaration
//****************************************************
//all wire/reg/parameter variable
//should be declare below here
reg [31:0] gpp_status;
reg [31:0] in_gpp_data_count;  //input pkt count
reg [31:0] out_gpp_phv_count;  //output phv count
reg [31:0] out_gpp_md_count;    //output md count
reg [31:0] out_gpp_cache_count; //output data_cache_count

reg [7:0] pkt_step_count;
reg [7:0] pkt_step_count_inc;
reg [7:0] PST;
reg [1023:0] PHV;
reg [255:0] MD;
 
wire gpp2pktin_alf;
wire is_ipv4;
wire is_ipv6;
wire is_ipv4_tcp;
wire is_ipv4_udp;
wire is_vlan;
wire is_ipv6_tcp;
wire is_ipv6_udp;
wire is_ipv6_lisp;
wire is_arp;

reg [1:0] gpp_state;
reg flag;       
//***************************************************
//             Retransmit Pkt To Data_Cache
//***************************************************
assign pktin_ready = ~gpp2pktin_alf;
assign gpp2pktin_alf = in_gpp_md_alf | in_gpp_phv_alf | in_gpp_data_alf;
assign cout_gpp_data_wr = cin_gpp_data_wr;
assign cout_gpp_data = cin_gpp_data;
assign cout_gpp_ready = cin_gpp_ready;

localparam    IDLE_S = 2'd0,
              TRANS_S = 2'd1,
              DISCARD_S = 2'd2;     
              
always @(posedge clk or negedge rst_n) begin 
    if(rst_n == 1'b0) begin 
        out_gpp_data_wr <= 1'b0;
        out_gpp_data <= 134'b0;
		out_gpp_valid <= 1'b0;
        out_gpp_valid_wr <= 1'b0;
		flag <= 1'b0;
        gpp_state <= IDLE_S;
    end
    else begin
        case(gpp_state)
            IDLE_S: begin  
			    out_gpp_valid <= 1'b0;	
                out_gpp_valid_wr <= 1'b0;
                //get DMID to check if we need the change.
                if((pktin_axis_tuser == 2'b01)&&(pktin_data_wr == 1'b1)) begin
                    if((pktin_data[87:80]==8'd1)||(pktin_data[87:80]>8'd4)) begin
                        out_gpp_data_wr <= 1'b1;
                        out_gpp_data <= pktin_data;
						flag <= 1'b1;
                        gpp_state <= TRANS_S;
                    end 
                    else begin 
                        out_gpp_data_wr <= 1'b0;
                        out_gpp_data <= 256'b0;
						flag <= 1'b0;
                        gpp_state <= DISCARD_S;
                    end
                end
                else begin
                    out_gpp_data_wr <= 1'b0;
                    out_gpp_data <= 256'b0;
                    gpp_state <= IDLE_S;
                end
            end
            TRANS_S: begin				   
                out_gpp_data_wr <= 1'b1;
                out_gpp_data <= pktin_data;
			    out_gpp_valid <= pktin_data_valid;
                if(pktin_axis_tuser == 2'b10) begin
                    out_gpp_valid_wr <= 1'b1; 
                    gpp_state <= IDLE_S;
                end
                else begin
                    out_gpp_valid_wr <= 1'b0;           
                    gpp_state <= TRANS_S;
                end
            end 
            DISCARD_S: begin 
				out_gpp_data_wr <= 1'b0;
				out_gpp_valid_wr <= 1'b0;
                if(pktin_axis_tuser == 2'b10) begin
                        gpp_state <= IDLE_S;
                end 
                else begin 
                        gpp_state <= DISCARD_S;
                end
              end
        endcase
     end
end
     	 
//***************************************************
//                 Pkt Step Count
//***************************************************
//count the pkt cycle step for locate parse procotol field
//compare with pkt_step_count, pkt_step_count_inc always change advance 1 cycle

always @* begin 
    if(pktin_data_wr == 1'b1) begin 
        if(pktin_axis_tuser == 2'b01) begin 
            pkt_step_count_inc = 8'd0;
        end
		else begin
			pkt_step_count_inc = pkt_step_count + 8'd1;
		end 
    end
    else begin 
        pkt_step_count_inc = 8'd0;
    end 
end

always @(posedge clk or negedge rst_n) begin 
    if(rst_n == 1'b0) begin 
        pkt_step_count <= 8'd0;
    end
    else begin 
        pkt_step_count <= pkt_step_count_inc;
    end
end
//***************************************************
//                 MD Field Parse
//***************************************************

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        MD[255:0] = 256'b0;
    end
    else begin
        if((pktin_data_wr == 1'b1) && (pktin_axis_tuser == 2'b01)) begin
            MD <= pktin_data;
        end
        else begin
            MD <= MD;
        end
    end
end


//***************************************************
//                 UDF Field Parse
//***************************************************
//always @(posedge clk) begin
//    if((pktin_data_wr == 1'b1) && (pkt_step_count_inc == 8'd0)&&(pktin_data[119:108]>16'd1200)) begin
//		UDF <= 8'd1;
//    end
//    else begin
//        UDF <= 8'd0;
//    end
//end


//***************************************************
//             PHV Field Parse
//***************************************************

always @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
	    PHV <= 1024'b0;
		out_gpp_phv <= 1024'b0;
		out_gpp_phv_wr <= 1'b0;
	end
	else begin
	
        if(flag == 1'b1) begin 
            //out_gpp_phv_wr <= pktin_data_valid;
            if(pktin_axis_tuser == 2'b10) begin
               out_gpp_phv_wr <= 1'b1; 
            end 
            else begin
                out_gpp_phv_wr <= 1'b0;
            end
        end
        else begin
            out_gpp_phv_wr <= 1'b0;
        end 
       	 	 
		if(pktin_data_wr == 1'b1)begin
		    case(pkt_step_count_inc)
                8'd0:begin
                    PHV[1023:768] <= pktin_data[255:0];
                    out_gpp_phv <= {pktin_data[255:0], 768'b0};
                end
                8'd1:begin
                    PHV[767:512] <= pktin_data[255:0];
                    out_gpp_phv <= {PHV[1023:768], pktin_data[255:0], 521'b0};
                end
                8'd2:begin
                    PHV[511:256] <= pktin_data[255:0];
                    out_gpp_phv <= {PHV[1023:512], pktin_data[255:0], 256'b0};
                end
                8'd3:begin
                    PHV[255:0] <= pktin_data[255:0];
                    out_gpp_phv <= {PHV[1023:256], pktin_data[255:0]};
                end
                default:begin 
                    PHV <= PHV;
                    out_gpp_phv <= out_gpp_phv;
                end
			endcase		
		end		
		else begin
		    PHV <= PHV;
		end
	end
end    
//************************************************
//              PST Field Parse
//************************************************
assign is_ipv4 = (PHV[927:912] == 16'h0800)?1'b1:1'b0;
assign is_arp = (PHV[927:912] == 16'h0806)?1'b1:1'b0;
assign is_ipv4_tcp = ((PHV[927:912] == 16'h0800)&&(PHV[839:832] == 8'h6))? 1'b1:1'b0;
assign is_ipv4_udp = ((PHV[927:912] == 16'h0800)&&(PHV[839:832] == 8'h11))? 1'b1:1'b0;
//TODO here we use procl num 443 to identify QUIC packets.
assign is_quic = ((PHV[927:912] == 16'h0800)&&(PHV[839:832] == 8'h11)&&((PHV[751:736] == 16'd443)
    ||PHV[735:720] == 16'd443))? 1'b1:1'b0;
assign is_ipv6 = (PHV[927:912] == 16'h86dd)?1'b1:1'b0;
assign is_ipv6_udp = ((PHV[927:912] == 16'h86dd)&&(PHV[863:856] == 8'h11))?1'b1:1'b0;
assign is_ipv6_tcp = ((PHV[927:912] == 16'h86dd)&&(PHV[863:856] == 8'h6))? 1'b1:1'b0;

always @(posedge clk) begin 
    if(rst_n == 1'b0) begin
	     PST <= 8'b0;
	end
	else begin
	    if(is_ipv6_tcp == 1'b1) begin//PST = 8'b1000 0001           
            PST[7:0] <= 8'b10000001;
        end
        else if(is_ipv6_udp == 1'b1) begin//PST = 8'b1000 0011           
            PST[7:0] <= 8'b10000011;
        end 
        else if(is_ipv6 == 1'b1) begin //PST = 1000 0010
            PST[7:0] <= 8'b10000010;
        end
        else if(is_ipv4_tcp == 1'b1) begin//PST =8'b0000 0001
            PST[7:0] <= 8'b00000001;
        end
        else if(is_ipv4_udp == 1'b1) begin//PST =8'b0000 0111
            PST[7:0] <= 8'b00000111;
        end  
        else if(is_ipv4 == 1'b1)begin //PST = 0000 0010
            PST[7:0] <= 8'b00000010;
        end
        else if (is_arp == 1'b1) begin //PST = 8'b0000 0011
            PST[7:0] <= 8'b00000011;
        end
        //TODO here the QUIC PST is 8'b1100 0001
        else if (is_quic == 1'b1) begin
            PST[7:0] <= 8'b11000001;
        end
        else begin
            PST <= PST;
        end        	 
	end  
end  


//************************************************
//              Transmit MD
//************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin 
        out_gpp_md <= 256'b0;
		out_gpp_md_wr <= 1'b0;
    end
    else begin 	 
        //the out_md will only be changed at the tail.
	    if(flag == 1'b1) begin 
	        //out_gpp_md_wr <= pktin_data_valid;
            if(pktin_axis_tuser == 2'b10) begin
               out_gpp_md_wr <= 1'b1; 
            end 
            else begin
                out_gpp_md_wr <= 1'b0;
            end
	    end
	    else begin
	       out_gpp_md_wr <= 1'b0;
	    end         
        if(MD[87:80]== LMID) begin 
            out_gpp_md <= {MD[255:128],MD[127:88],8'd2,PST,MD[71:0]};  //NMID[87:80],PST[79:72]
        end
        else begin 
            out_gpp_md <= {MD[255:128],MD[127:0]};
        end
    end
end



//***************************************************
//                 in_gpp_data_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    in_gpp_data_count <= 32'b0;	 
	end
	else begin
	    if(pktin_valid_wr == 1'b1) begin
		   in_gpp_data_count <= in_gpp_data_count + 32'b1; 
		end
		else begin
		   in_gpp_data_count <= in_gpp_data_count; 
		end
	     
	end	 
end

//***************************************************
//                 out_gpp_md_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gpp_md_count <= 32'b0;	 
	end
	else begin
	    if(out_gpp_md_wr == 1'b1) begin
		   out_gpp_md_count <= out_gpp_md_count + 32'b1 ; 
		end
		else begin
		   out_gpp_md_count <= out_gpp_md_count ; 
		end	     
	end	 
end

//***************************************************
//                 out_gpp_pfv_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gpp_phv_count <= 32'b0;	 
	end
	else begin
	    if(out_gpp_phv_wr == 1'b1) begin
		   out_gpp_phv_count <= out_gpp_phv_count + 32'b1;
		end
		else begin
		   out_gpp_phv_count <= out_gpp_phv_count ;
		end	      
	end	 
end

//***************************************************
//                 out_gpp_cache_count
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0 ) begin
	    out_gpp_cache_count <= 32'b0;	 
	 end
	 else begin
	    if(out_gpp_valid_wr == 1'b1) begin
		   out_gpp_cache_count <= out_gpp_cache_count + 32'b1; 
		end
		else begin
		   out_gpp_cache_count <= out_gpp_cache_count ; 
		end	     
	 end	 
end

//***************************************************
//                 status
//***************************************************
always @(posedge clk or negedge rst_n) begin
   if(rst_n == 1'b0) begin
      gpp_status <= 32'b0;
   end
   else begin
      gpp_status <= {gpp_state,26'b0,pktin_ready,in_gpp_md_alf,in_gpp_phv_alf,in_gpp_data_alf};
   end
end
  
endmodule