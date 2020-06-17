/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: fast_dmux_stream.v
//Version: 1.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
//   1)receive and restore 4 stream, select 1 stream send to um moudle
//   2)use a fair and efficiently algorithm to select stream 
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/07/17
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 

module fast_dmux_stream #(
    parameter   START_STREAM_ID = 0
)(
    input wire          user_clk,//mux module's work clk domin
    input wire          user_rst_n,
//--------------input stream-----------------//
    input wire          s_axis_tvalid,
    input wire [127:0]  s_axis_tdata,
    input wire [15:0]   s_axis_tkeep,
    input wire          s_axis_tlast,
    output wire          s_axis_tready,//high acitve
//--------------output stream-----------------//
    output reg          m0_user2port_data_wr,
    output reg  [127:0] m0_user2port_data,
    output reg          m0_user2port_stat_wr,
    output reg  [15:0]  m0_user2port_stat,
    input  wire         m0_port2user_rcv_ready,
                        
    output reg          m1_user2port_data_wr,
    output reg  [127:0] m1_user2port_data,
    output reg          m1_user2port_stat_wr,
    output reg  [15:0]  m1_user2port_stat,
    input  wire         m1_port2user_rcv_ready,
                        
    output reg          m2_user2port_data_wr,
    output reg  [127:0] m2_user2port_data,
    output reg          m2_user2port_stat_wr,
    output reg  [15:0]  m2_user2port_stat,
    input  wire         m2_port2user_rcv_ready,
                        
    output reg          m3_user2port_data_wr,
    output reg  [127:0] m3_user2port_data,
    output reg          m3_user2port_stat_wr,
    output reg  [15:0]  m3_user2port_stat,
    input  wire         m3_port2user_rcv_ready
);



//***************************************************
//                 count
//***************************************************
reg [15:0]test_count;
reg valid_r;
always @(posedge user_clk or negedge user_rst_n) begin
    if(user_rst_n == 1'b0 ) begin
	    test_count <= 16'b0;	
        valid_r<=1'b0;		
	 end
	 else begin
	 valid_r<=s_axis_tvalid;
	    if((s_axis_tvalid==1'b0)&&(valid_r==1'b1) && (s_axis_tready==1'b1)) begin
		 
		   test_count <= test_count + 32'b1;
		   end
		
		else begin
		   test_count <= test_count;
		end		
	 end	 
end

reg [15:0]test_count_last;
always @(posedge user_clk or negedge user_rst_n) begin
    if(user_rst_n == 1'b0 ) begin
	    test_count_last <= 16'b0;			
	 end
	 else begin
	    if((s_axis_tlast == 1'b1) && (s_axis_tready==1'b1)) begin
		   test_count_last <= test_count_last + 32'b1;
		end
		else begin
		   test_count_last <= test_count_last;
		end		
	 end	 
end

reg [15:0]count_last;
always @(posedge user_clk or negedge user_rst_n) begin
    if(user_rst_n == 1'b0 ) begin
	    count_last <= 16'b0;			
	 end
	 else begin
	    count_last<=test_count-test_count_last;
	 end
end
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 



reg          dfifo_rd;
wire [127:0] dfifo_rdata;
wire [7:0]   dfifo_usedw;
wire         dfifo_full;
wire         dfifo_empty;

reg          sfifo_rd;
wire         sfifo_rdata;
wire [5:0]   sfifo_usedw;
wire         sfifo_full;
wire         sfifo_empty; 

reg [127:0] dfifo_rdata_byteinv; 

wire [5:0]   stream_id [3:0];

reg [11:0]   send_pkt_len;

reg [3:0]    stream_sel_cache;

reg [3:0]    dumx_state;

localparam   IDLE_S      = 4'd0,
             DEL_META0_S = 4'd1,
             DEL_META1_S = 4'd2,
             TRANSMIT_S = 4'd3;
//***************************************************
//                 DMux to 4 stream
//***************************************************
//always @(posedge user_clk or negedge user_rst_n) begin
//    if(user_rst_n == 1'b0) begin
//        s_axis_tready <= 1'b0;
//    end
//    else begin
//        s_axis_tready <= ~dfifo_usedw[7];
//    end
//end
assign  s_axis_tready = ~dfifo_usedw[7];


assign stream_id[0] = START_STREAM_ID;  
assign stream_id[1] = START_STREAM_ID + 4'd1; 
assign stream_id[2] = START_STREAM_ID + 4'd2; 
assign stream_id[3] = START_STREAM_ID + 4'd3; 
//as the transmition will delay 1 cycle for delete metadata1
//so must cache cdpout2stream_data_wr for recover transmition

always @(posedge user_clk or negedge user_rst_n) begin
    if(user_rst_n == 1'b0) begin
        dfifo_rd <= 1'b0;
        sfifo_rd <= 1'b0;
        m0_user2port_data_wr <= 1'b0;
        m1_user2port_data_wr <= 1'b0;
        m2_user2port_data_wr <= 1'b0;
        m3_user2port_data_wr <= 1'b0;
        
        m0_user2port_stat_wr <= 1'b0;
        m1_user2port_stat_wr <= 1'b0;
        m2_user2port_stat_wr <= 1'b0;
        m3_user2port_stat_wr <= 1'b0;
        
        m0_user2port_data <= 128'b0;
        m1_user2port_data <= 128'b0;
        m2_user2port_data <= 128'b0;
        m3_user2port_data <= 128'b0;
        
        m0_user2port_stat <= 16'b0;
        m1_user2port_stat <= 16'b0;
        m2_user2port_stat <= 16'b0;
        m3_user2port_stat <= 16'b0;

        stream_sel_cache <= 4'b0;
        send_pkt_len <= 12'b0;
        
        dumx_state <= IDLE_S;
    end
    else begin
        case(dumx_state)
            IDLE_S: begin
                m0_user2port_data_wr <= 1'b0;
                m1_user2port_data_wr <= 1'b0;
                m2_user2port_data_wr <= 1'b0;
                m3_user2port_data_wr <= 1'b0;
                
                m0_user2port_stat_wr <= 1'b0;
                m1_user2port_stat_wr <= 1'b0;
                m2_user2port_stat_wr <= 1'b0;
                m3_user2port_stat_wr <= 1'b0;
                if(sfifo_empty == 1'b0) begin
                    if(dfifo_rdata[117:112] == stream_id[0]) begin
                        stream_sel_cache <= 4'b0001;
                        if(m0_port2user_rcv_ready == 1'b1) begin
                            dfifo_rd <= 1'b1;
                            sfifo_rd <= 1'b1;
                            dumx_state <= DEL_META0_S;
                        end
                        else begin
                            dfifo_rd <= 1'b0;
                            sfifo_rd <= 1'b0;
                            dumx_state <= IDLE_S;
                        end
                    end
                    else if(dfifo_rdata[117:112] == stream_id[1]) begin
                        stream_sel_cache <= 4'b0010;
                        if(m1_port2user_rcv_ready == 1'b1) begin
                            dfifo_rd <= 1'b1;
                            sfifo_rd <= 1'b1;
                            dumx_state <= DEL_META0_S;
                        end
                        else begin
                            dfifo_rd <= 1'b0;
                            sfifo_rd <= 1'b0;
                            dumx_state <= IDLE_S;
                        end
                    end
                    else if(dfifo_rdata[117:112] == stream_id[2]) begin
                        stream_sel_cache <= 4'b0100;
                        if(m2_port2user_rcv_ready == 1'b1) begin
                            dfifo_rd <= 1'b1;
                            sfifo_rd <= 1'b1;
                            dumx_state <= DEL_META0_S;
                        end
                        else begin
                            dfifo_rd <= 1'b0;
                            sfifo_rd <= 1'b0;
                            dumx_state <= IDLE_S;
                        end
                    end
                    else if(dfifo_rdata[117:112] == stream_id[3]) begin
                        stream_sel_cache <= 4'b1000;
                        if(m3_port2user_rcv_ready == 1'b1) begin
                            dfifo_rd <= 1'b1;
                            sfifo_rd <= 1'b1;
                            dumx_state <= DEL_META0_S;
                        end
                        else begin
                            dfifo_rd <= 1'b0;
                            sfifo_rd <= 1'b0;
                            dumx_state <= IDLE_S;
                        end
                    end
                    else begin
                        stream_sel_cache <= 4'b0000;
                        dfifo_rd <= 1'b1;
                        sfifo_rd <= 1'b1;
                        dumx_state <= DEL_META0_S;
                    end
                    
                end
                else begin
                    dfifo_rd <= 1'b0;
                    sfifo_rd <= 1'b0;
                    stream_sel_cache <= stream_sel_cache;
                    dumx_state <= IDLE_S;
                end
            end
            
            DEL_META0_S: begin
                dfifo_rd <= 1'b1;
                sfifo_rd <= 1'b0;
                
                send_pkt_len <= dfifo_rdata[107:96] - 12'd32;
                m0_user2port_stat <= (stream_sel_cache[0] == 1'b1) ? {1'b1,3'b0,dfifo_rdata[107:96]-12'd32} : m0_user2port_stat;
                m1_user2port_stat <= (stream_sel_cache[1] == 1'b1) ? {1'b1,3'b0,dfifo_rdata[107:96]-12'd32} : m1_user2port_stat;
                m2_user2port_stat <= (stream_sel_cache[2] == 1'b1) ? {1'b1,3'b0,dfifo_rdata[107:96]-12'd32} : m2_user2port_stat;
                m3_user2port_stat <= (stream_sel_cache[3] == 1'b1) ? {1'b1,3'b0,dfifo_rdata[107:96]-12'd32} : m3_user2port_stat;
                dumx_state <= DEL_META1_S;
            end
            
            DEL_META1_S: begin
                dfifo_rd <= 1'b1;
                dumx_state <= TRANSMIT_S;
            end
  
            TRANSMIT_S: begin
                m0_user2port_data_wr <= stream_sel_cache[0];
                m1_user2port_data_wr <= stream_sel_cache[1];
                m2_user2port_data_wr <= stream_sel_cache[2];
                m3_user2port_data_wr <= stream_sel_cache[3];
                
                m0_user2port_data <= (stream_sel_cache[0] == 1'b1) ? dfifo_rdata_byteinv : m0_user2port_data;
                m1_user2port_data <= (stream_sel_cache[1] == 1'b1) ? dfifo_rdata_byteinv : m1_user2port_data;
                m2_user2port_data <= (stream_sel_cache[2] == 1'b1) ? dfifo_rdata_byteinv : m2_user2port_data;
                m3_user2port_data <= (stream_sel_cache[3] == 1'b1) ? dfifo_rdata_byteinv : m3_user2port_data;
                send_pkt_len <= send_pkt_len - 12'd16;
                if(send_pkt_len > 15'd16) begin//not the end of pkt
                    dfifo_rd <= 1'b1;
                    m0_user2port_stat_wr <= 1'b0;
                    m1_user2port_stat_wr <= 1'b0;
                    m2_user2port_stat_wr <= 1'b0;
                    m3_user2port_stat_wr <= 1'b0;
                    dumx_state <= TRANSMIT_S;
                end
                else begin//end
                    dfifo_rd <= 1'b0;
                    m0_user2port_stat_wr <= m0_user2port_data_wr;
                    m1_user2port_stat_wr <= m1_user2port_data_wr;
                    m2_user2port_stat_wr <= m2_user2port_data_wr;
                    m3_user2port_stat_wr <= m3_user2port_data_wr;
                    dumx_state <= IDLE_S;
                end
            end
            
            default: begin
                dfifo_rd <= 1'b0;
                sfifo_rd <= 1'b0;
                m0_user2port_data_wr <= 1'b0;
                m1_user2port_data_wr <= 1'b0;
                m2_user2port_data_wr <= 1'b0;
                m3_user2port_data_wr <= 1'b0;
                
                m0_user2port_stat_wr <= 1'b0;
                m1_user2port_stat_wr <= 1'b0;
                m2_user2port_stat_wr <= 1'b0;
                m3_user2port_stat_wr <= 1'b0;
                
                m0_user2port_data <= 128'b0;
                m1_user2port_data <= 128'b0;
                m2_user2port_data <= 128'b0;
                m3_user2port_data <= 128'b0;
                
                m0_user2port_stat <= 16'b0;
                m1_user2port_stat <= 16'b0;
                m2_user2port_stat <= 16'b0;
                m3_user2port_stat <= 16'b0;
                stream_sel_cache <= 4'b0;
                send_pkt_len <= 12'b0;
                
                dumx_state <= IDLE_S;
            end
        endcase
    end
end

always @* begin
    dfifo_rdata_byteinv = dfifo_rdata;
    /*dfifo_rdata_byteinv[119:112] = dfifo_rdata[15:8];
    dfifo_rdata_byteinv[111:104] = dfifo_rdata[23:16];
    dfifo_rdata_byteinv[103:96]  = dfifo_rdata[31:24];
    dfifo_rdata_byteinv[95:88]   = dfifo_rdata[39:32];
    dfifo_rdata_byteinv[87:80]   = dfifo_rdata[47:40];
    dfifo_rdata_byteinv[79:72]   = dfifo_rdata[55:48];
    dfifo_rdata_byteinv[71:64]   = dfifo_rdata[63:56];
    dfifo_rdata_byteinv[63:56]   = dfifo_rdata[71:64];
    dfifo_rdata_byteinv[55:48]   = dfifo_rdata[79:72];
    dfifo_rdata_byteinv[47:40]   = dfifo_rdata[87:80];
    dfifo_rdata_byteinv[39:32]   = dfifo_rdata[95:88];
    dfifo_rdata_byteinv[31:24]   = dfifo_rdata[103:96];
    dfifo_rdata_byteinv[23:16]   = dfifo_rdata[111:104];
    dfifo_rdata_byteinv[15:8]    = dfifo_rdata[119:112];
    dfifo_rdata_byteinv[7:0]     = dfifo_rdata[127:120];*/
end


//***************************************************
//                  Other IP Instance
//***************************************************
//likely fifo/ram/async block.... 
//should be instantiated below here 
reg [127:0]     tdfifo_wdata;
reg             tdfifo_wden;

reg             lsfifo_wdata;
reg             lsfifo_wden;


always @(posedge user_clk or negedge user_rst_n)begin
	if(user_rst_n==1'b0)begin
	    tdfifo_wdata<=128'b0;
        tdfifo_wden<=1'b0;
        
        lsfifo_wden<=1'b0;
	end
	else begin
		if((s_axis_tready==1'b1)&& (s_axis_tvalid==1'b1))begin
            tdfifo_wden<=1'b1;
			tdfifo_wdata<=s_axis_tdata;
		    lsfifo_wden<=s_axis_tlast;
		end
		else begin
		    tdfifo_wden<=1'b0;
			tdfifo_wdata<=s_axis_tdata;
		    lsfifo_wden<=1'b0;
		end
	end

end

dmuxfifo_w128_d256 dmux_dfifo(
   .clk(user_clk),
   .srst(~user_rst_n),
   
   .wr_en(tdfifo_wden),
   .din(tdfifo_wdata),
   .rd_en(dfifo_rd),
   .dout(dfifo_rdata),
   .data_count(dfifo_usedw),
   .full(dfifo_full),
   .empty(dfifo_empty)
);


dmuxfifo_w1_d64 dmux_vfifo(
   .clk(user_clk),
   .srst(~user_rst_n),
   
   .wr_en(lsfifo_wden),
   .din(1'b1),
   .rd_en(sfifo_rd),
   .dout(sfifo_rdata),
   .data_count(sfifo_usedw),
   .full(sfifo_full),
   .empty(sfifo_empty)
);
endmodule
/*
fast_dmux_stream  #(
    .START_STREAM_ID(0)
)fast_dmux_stream(
    .user_clk(),//mux module's work clk domin
    .user_rst_n(),
//--------------input stream-----------------//
    .s_axis_tvalid(),
    .s_axis_tdata(),
    .s_axis_tkeep(),
    .s_axis_tlast(),
    .s_axis_tready(),//high acitve
//--------------output stream-----------------//
    .m0_user2port_data_wr(),
    .m0_user2port_data(),
    .m0_user2port_stat_wr(),
    .m0_user2port_stat(),
    .m0_port2user_rcv_ready(),
                        
    .m1_user2port_data_wr(),
    .m1_user2port_data(),
    .m1_user2port_stat_wr(),
    .m1_user2port_stat(),
    .m1_port2user_rcv_ready(),
                        
    .m2_user2port_data_wr(),
    .m2_user2port_data(),
    .m2_user2port_stat_wr(),
    .m2_user2port_stat(),
    .m2_port2user_rcv_ready(),
                        
    .m3_user2port_data_wr(),
    .m3_user2port_data(),
    .m3_user2port_stat_wr(),
    .m3_user2port_stat(),
    .m3_port2user_rcv_ready()

);
 */