/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: fast_mux_stream.v
//Version: 2.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)receive and restore 4 stream, select 1 stream send to up moudle
// 2)use a fair and efficiently algorithm to select stream 
// 3)every stream 's status type is {1bit valid ,15bit port, 16bit len,16bit pkt id,64bit timestamp}
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/07/17
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module fast_mux_stream #(
    parameter   START_STREAM_ID = 0
)(
    input wire          user_clk,//mux module's work clk domin
    input wire          user_rst_n,
                        
    input wire          port0_rx_clk,
    input wire          port1_rx_clk,
    input wire          port2_rx_clk,
    input wire          port3_rx_clk,
                        
    input wire          port0_rst_n,
    input wire          port1_rst_n,
    input wire          port2_rst_n,
    input wire          port3_rst_n,
//--------------input stream-----------------//
    input  wire         s0_port2user_data_wr,
    input  wire [127:0] s0_port2user_data,
    input  wire         s0_port2user_stat_wr,
    input  wire [95:0]  s0_port2user_stat,
    output wire         s0_user2port_rcv_ready,
    
    input  wire         s1_port2user_data_wr,
    input  wire [127:0] s1_port2user_data,
    input  wire         s1_port2user_stat_wr,
    input  wire [95:0]  s1_port2user_stat,
    output wire         s1_user2port_rcv_ready,
    
    input  wire         s2_port2user_data_wr,
    input  wire [127:0] s2_port2user_data,
    input  wire         s2_port2user_stat_wr,
    input  wire [95:0]  s2_port2user_stat,
    output wire         s2_user2port_rcv_ready,
    
    input  wire         s3_port2user_data_wr,
    input  wire [127:0] s3_port2user_data,
    input  wire         s3_port2user_stat_wr,
    input  wire [95:0]  s3_port2user_stat,
    output wire         s3_user2port_rcv_ready,
//--------------output stream--------------//
    output reg          m_axis_tvalid,
    output reg [127:0]  m_axis_tdata,
    output reg [15:0]   m_axis_tkeep,
    output reg          m_axis_tlast,
    input  wire         m_axis_tready//high acitve
);

//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
reg  [3:0]   dfifo_rd;
wire [127:0] dfifo_rdata [3:0];
wire [7:0]   dfifo_wrusedw [3:0];
wire [7:0]   dfifo_rdusedw [3:0];
wire [3:0]   dfifo_full;
wire [3:0]   dfifo_empty;

reg  [3:0]   vfifo_rd;
wire [95:0]  vfifo_rdata [3:0];
wire [5:0]   vfifo_wrusedw [3:0];
wire [5:0]   vfifo_rdusedw [3:0];
wire [3:0]   vfifo_full;
wire [3:0]   vfifo_empty;  

reg  [127:0] tdata_reg;  
reg  [15:0]  tkeep_reg;
wire [5:0]   stream_id [3:0];
  
reg          grant_get;
wire [3:0]   grant_bits;
wire [3:0]   grant_req;
reg  [14:0]  send_pkt_len;

reg  [3:0]   grant_bits_cache;
reg  [127:0] tdata_reg_cache;

reg  [15:0]  valid_bitmap;

reg          um_head_flag;//assert it flag current transmit data is um head

reg  [3:0]   last_valid_byte;

assign s0_user2port_rcv_ready = ~dfifo_wrusedw[0][7];
assign s1_user2port_rcv_ready = ~dfifo_wrusedw[1][7];
assign s2_user2port_rcv_ready = ~dfifo_wrusedw[2][7];
assign s3_user2port_rcv_ready = ~dfifo_wrusedw[3][7];

reg [3:0]    mux_state;
localparam   IDLE_S       = 4'd0,
             HEAD_S       = 4'd1,
             TRANSMIT_S   = 4'd2,
             WAIT_READY_S = 4'd3,
             DISCARD_S    = 4'd4;
//***************************************************
//                 Mux to 1 stream
//***************************************************
assign stream_id[0] = START_STREAM_ID;  
assign stream_id[1] = START_STREAM_ID + 4'd1; 
assign stream_id[2] = START_STREAM_ID + 4'd2; 
assign stream_id[3] = START_STREAM_ID + 4'd3; 

assign grant_req = ~vfifo_empty;

always @* begin   
    case(last_valid_byte)   
        4'h0: valid_bitmap = 16'hffff;
        4'h1: valid_bitmap = 16'h8000;
        4'h2: valid_bitmap = 16'hc000;
        4'h3: valid_bitmap = 16'he000;
        4'h4: valid_bitmap = 16'hf000;
        4'h5: valid_bitmap = 16'hf800;
        4'h6: valid_bitmap = 16'hfc00;
        4'h7: valid_bitmap = 16'hfe00;
        4'h8: valid_bitmap = 16'hff00;
        4'h9: valid_bitmap = 16'hff80;
        4'ha: valid_bitmap = 16'hffc0;
        4'hb: valid_bitmap = 16'hffe0;
        4'hc: valid_bitmap = 16'hfff0;
        4'hd: valid_bitmap = 16'hfff8;
        4'he: valid_bitmap = 16'hfffc;
        4'hf: valid_bitmap = 16'hfffe;
    endcase
end

always @(posedge user_clk or negedge user_rst_n) begin
    if(user_rst_n == 1'b0) begin
        dfifo_rd <= 4'b0;
        vfifo_rd <= 4'b0;
        grant_get <= 1'b0;
        m_axis_tvalid <= 1'b0;
        tdata_reg <= 128'b0;
        tkeep_reg <= 16'b0;
        m_axis_tlast <= 1'b0;
        grant_bits_cache <= 4'b0;
        tdata_reg_cache <= 128'b0;
        last_valid_byte <= 4'b0;
        um_head_flag <= 1'b0;
        mux_state <= IDLE_S;
    end
    else begin
        case(mux_state)
            IDLE_S: begin
                um_head_flag <= 1'b1;
                m_axis_tlast <= 1'b0;
                grant_get <= 1'b0;
                dfifo_rd <= 4'b0;
                vfifo_rd <= 4'b0;
                last_valid_byte <= 4'b0;
                if(grant_bits == 4'b0) begin//send condition is not match
                //no pkt or up module can't receive a pkt
                    m_axis_tvalid <= 1'b0;
                    tkeep_reg <= 16'b0;
                    mux_state <= IDLE_S;
                end
                else begin
                    tkeep_reg <= 16'hffff;
                    casez(grant_bits)
                        4'b???1: begin 
                            grant_bits_cache <= 4'b0001;
                            m_axis_tvalid <= vfifo_rdata[0][95]; 
                            tdata_reg[127] <= 1'd0;//pktsrc 
							tdata_reg[126] <= 1'd0;//pktdst
                            tdata_reg[125:120] <= stream_id[0];//IngressPort
							tdata_reg[119:118] <=2'b00;//outtype
							tdata_reg[117:112] <=6'b0;//outport
							tdata_reg[111:109] <=3'b0;//priority
							tdata_reg[108] <= 1'b0;//discard
                            tdata_reg[107:96] <= vfifo_rdata[0][94:80] + 12'd32;//pkt_length
                            tdata_reg[95:88] <= 8'b0;//SrcModuleID
                            tdata_reg[87:80] <= 8'd1;//DstModuleID
							tdata_reg[79:72] <= 8'b0;//pst
                            tdata_reg[71:64] <= vfifo_rdata[0][79:64];//pkt id(Seq_num)      							
                            tdata_reg[63:50] <= 15'b0;//flowid
                            tdata_reg[49:32] <= 18'b0;//reserve
                            tdata_reg[31:0] <= vfifo_rdata[0][31:0];//timestamp 
                            send_pkt_len <= vfifo_rdata[0][94:80];
                        end
                        4'b??10: begin 
                            grant_bits_cache <= 4'b0010;
                             m_axis_tvalid <= vfifo_rdata[1][95]; 
                            tdata_reg[127] <= 1'd0;//pktsrc 
							tdata_reg[126] <= 1'd0;//pktdst
                            tdata_reg[125:120] <= stream_id[1];//IngressPort
							tdata_reg[119:118] <=2'b00;//outtype
							tdata_reg[117:112] <=6'b0;//outport
							tdata_reg[111:109] <=3'b0;//priority
							tdata_reg[108] <= 1'b0;//discard
                            tdata_reg[107:96] <= vfifo_rdata[1][94:80] + 12'd32;//pkt_length
                            tdata_reg[95:88] <= 8'b0;//SrcModuleID
                            tdata_reg[87:80] <= 8'd1;//DstModuleID
							tdata_reg[79:72] <= 8'b0;//pst
                            tdata_reg[71:64] <= vfifo_rdata[1][79:64];//pkt id(Seq_num)      							
                            tdata_reg[63:50] <= 15'b0;//flowid
                            tdata_reg[49:32] <= 18'b0;//reserve
                            tdata_reg[31:0] <= vfifo_rdata[1][31:0];//timestamp 
                            send_pkt_len <= vfifo_rdata[1][94:80];
                        end
                        4'b?100: begin 
                            grant_bits_cache <= 4'b0100;
                            m_axis_tvalid <= vfifo_rdata[2][95]; 
                            tdata_reg[127] <= 1'd0;//pktsrc 
							tdata_reg[126] <= 1'd0;//pktdst
                            tdata_reg[125:120] <= stream_id[2];//IngressPort
							tdata_reg[119:118] <=2'b00;//outtype
							tdata_reg[117:112] <=6'b0;//outport
							tdata_reg[111:109] <=3'b0;//priority
							tdata_reg[108] <= 1'b0;//discard
                            tdata_reg[107:96] <= vfifo_rdata[2][94:80] + 12'd32;//pkt_length
                            tdata_reg[95:88] <= 8'b0;//SrcModuleID
                            tdata_reg[87:80] <= 8'd1;//DstModuleID
							tdata_reg[79:72] <= 8'b0;//pst
                            tdata_reg[71:64] <= vfifo_rdata[2][79:64];//pkt id(Seq_num)      							
                            tdata_reg[63:50] <= 15'b0;//flowid
                            tdata_reg[49:32] <= 18'b0;//reserve
                            tdata_reg[31:0] <= vfifo_rdata[2][31:0];//timestamp 
                            send_pkt_len <= vfifo_rdata[2][94:80];
                        end
                        4'b1000: begin 
                            grant_bits_cache <= 4'b1000;
                             m_axis_tvalid <= vfifo_rdata[3][95]; 
                            tdata_reg[127] <= 1'd0;//pktsrc 
							tdata_reg[126] <= 1'd0;//pktdst
                            tdata_reg[125:120] <= stream_id[3];//IngressPort
							tdata_reg[119:118] <=2'b00;//outtype
							tdata_reg[117:112] <=6'b0;//outport
							tdata_reg[111:109] <=3'b0;//priority
							tdata_reg[108] <= 1'b0;//discard
                            tdata_reg[107:96] <= vfifo_rdata[3][94:80] + 12'd32;//pkt_length
                            tdata_reg[95:88] <= 8'b0;//SrcModuleID
                            tdata_reg[87:80] <= 8'd1;//DstModuleID
							tdata_reg[79:72] <= 8'b0;//pst
                            tdata_reg[71:64] <= vfifo_rdata[3][79:64];//pkt id(Seq_num)      							
                            tdata_reg[63:50] <= 15'b0;//flowid
                            tdata_reg[49:32] <= 18'b0;//reserve
                            tdata_reg[31:0] <= vfifo_rdata[3][31:0];//timestamp 
                            send_pkt_len <= vfifo_rdata[3][94:80];
                        end
                        default: begin 
                            grant_bits_cache <= 4'b0;
                            m_axis_tvalid <= 1'b0;   
                            tdata_reg <= tdata_reg;
                            send_pkt_len <= 15'b0;               
                        end
                        //this condition never be triger,as grant_real == 4'b0 is it's front layer's condition
                    endcase
                //    tdata_reg[43:0] <= 44'h123456789ab;//modify timestamp field to a fixed number for test/20180418
                    mux_state <= HEAD_S;
                end
            end
            
            HEAD_S: begin
                um_head_flag <= 1'b1;
                if(m_axis_tvalid == 1'b0) begin//discard
                    grant_get <= 1'b1;
                    dfifo_rd <= grant_bits_cache;
                    vfifo_rd <= grant_bits_cache;
                    send_pkt_len <= send_pkt_len - 15'd16;
                    mux_state <= DISCARD_S;
                end
                else begin
                    if(m_axis_tready == 1'b1) begin
                        grant_get <= 1'b1;
                        dfifo_rd <= grant_bits_cache;
                        vfifo_rd <= grant_bits_cache;
                        tdata_reg <= 128'b0;
                        send_pkt_len <= send_pkt_len - 15'd16;
                        mux_state <= TRANSMIT_S;
                    end
                    else begin
                        grant_get <= 1'b0;
                        dfifo_rd <= 4'b0;
                        vfifo_rd <= 4'b0;
                        tdata_reg <= tdata_reg;
                        mux_state <= HEAD_S;
                    end
                end
            end

            TRANSMIT_S: begin
                vfifo_rd <= 4'b0;
                grant_get <= 1'b0;
                if(m_axis_tready == 1'b1) begin
                    um_head_flag <= 1'b0;
                    casez(grant_bits_cache)
                        4'b0001: tdata_reg <= dfifo_rdata[0];
                        4'b0010: tdata_reg <= dfifo_rdata[1];
                        4'b0100: tdata_reg <= dfifo_rdata[2];
                        4'b1000: tdata_reg <= dfifo_rdata[3];
                        default: tdata_reg <= tdata_reg;
                    endcase                   
                    if(send_pkt_len == 15'd0) begin//the last of pkt
                        dfifo_rd <= 4'b0;
                        m_axis_tlast <= 1'b1;
                        tkeep_reg <= valid_bitmap;
                        mux_state <= WAIT_READY_S;
                    end
                    else if(send_pkt_len > 15'd16) begin//just the body of pkt
                        dfifo_rd <= grant_bits_cache;
                        m_axis_tlast <= 1'b0;
                        send_pkt_len <= send_pkt_len - 15'd16; 
                        mux_state <= TRANSMIT_S;
                    end
                    else begin//the last of pkt in the fifo
                        dfifo_rd <= grant_bits_cache;
                        m_axis_tlast <= 1'b0;
                        send_pkt_len <= 15'b0;
                        last_valid_byte <= send_pkt_len[3:0];//cache the last valid byte for tkeep
                        mux_state <= TRANSMIT_S;
                    end
                        
                end
                else begin
                    um_head_flag <= um_head_flag;
                    dfifo_rd <= 4'b0;
                    tdata_reg <= tdata_reg;
                    casez(grant_bits_cache)
                        4'b0001: tdata_reg_cache <= dfifo_rdata[0];
                        4'b0010: tdata_reg_cache <= dfifo_rdata[1];
                        4'b0100: tdata_reg_cache <= dfifo_rdata[2];
                        4'b1000: tdata_reg_cache <= dfifo_rdata[3];
                        default: tdata_reg_cache <= tdata_reg_cache;
                    endcase
                    m_axis_tlast <= m_axis_tlast;
                    mux_state <= WAIT_READY_S;
                end
            end
            
            WAIT_READY_S: begin
                if(m_axis_tready == 1'b1) begin
                    um_head_flag <= 1'b0;
                    if(m_axis_tlast == 1'b1) begin//the last of pkt in the tdata_reg
                        tdata_reg <= tdata_reg;
                        dfifo_rd <= 4'b0;
                        m_axis_tlast <= 1'b0;
                        m_axis_tvalid <= 1'b0;
                        mux_state <= IDLE_S;
                    end
                    else begin
                        tdata_reg <= tdata_reg_cache;
                        if(send_pkt_len == 15'd0) begin//the last of pkt in the tdata_reg_cache
                            dfifo_rd <= 4'b0;
                            m_axis_tlast <= 1'b1;
                            tkeep_reg <= valid_bitmap;
                            mux_state <= WAIT_READY_S;
                        end
                        else if(send_pkt_len > 15'd16) begin//just the body of pkt
                            dfifo_rd <= grant_bits_cache;
                            m_axis_tlast <= 1'b0;
                            send_pkt_len <= send_pkt_len - 15'd16; 
                            mux_state <= TRANSMIT_S;
                        end
                        else begin//the last of pkt in the fifo
                            dfifo_rd <= grant_bits_cache;
                            m_axis_tlast <= 1'b0;
                            send_pkt_len <= 15'b0;
                            last_valid_byte <= send_pkt_len[3:0];//cache the last valid byte for tkeep
                            mux_state <= TRANSMIT_S;
                        end
                    end
                end
                else begin
                    um_head_flag <= um_head_flag;
                    tdata_reg <= tdata_reg;
                    dfifo_rd <= 4'b0;
                    m_axis_tlast <= m_axis_tlast;
                    send_pkt_len <= send_pkt_len;
                    mux_state <= WAIT_READY_S;
                end
            end
            
            DISCARD_S: begin
                um_head_flag <= 1'b0;
                vfifo_rd <= 4'b0;
                grant_get <= 1'b0;
                send_pkt_len <= send_pkt_len - 15'd16;
                if(send_pkt_len > 15'd16) begin//not the end of pkt
                    mux_state <= DISCARD_S;
                end
                else begin//end
                    mux_state <= IDLE_S;
                end
            end
            
            default: begin
                dfifo_rd <= 4'b0;
                vfifo_rd <= 4'b0;
                grant_get <= 1'b0;
                m_axis_tvalid <= 1'b0;
                tdata_reg <= 128'b0;
                tkeep_reg <= 16'b0;
                m_axis_tlast <= 1'b0;
                grant_bits_cache <= 4'b0;
                tdata_reg_cache <= 128'b0;
                um_head_flag <= 1'b0;
                mux_state <= IDLE_S;
            end
            
        endcase
    end
end

//***************************************************
//                  Other IP Instance
//***************************************************
//likely fifo/ram/async block.... 
//should be instantiated below here 
always @* begin
    if(um_head_flag == 1'b1) begin
        m_axis_tdata[127:0]   = tdata_reg[127:0];
    end
    else begin
        m_axis_tdata = tdata_reg;
       /* m_axis_tdata[119:112] = tdata_reg[15:8];
        m_axis_tdata[111:104] = tdata_reg[23:16];
        m_axis_tdata[103:96]  = tdata_reg[31:24];
        m_axis_tdata[95:88]   = tdata_reg[39:32];
        m_axis_tdata[87:80]   = tdata_reg[47:40];
        m_axis_tdata[79:72]   = tdata_reg[55:48];
        m_axis_tdata[71:64]   = tdata_reg[63:56];
        m_axis_tdata[63:56]   = tdata_reg[71:64];
        m_axis_tdata[55:48]   = tdata_reg[79:72];
        m_axis_tdata[47:40]   = tdata_reg[87:80];
        m_axis_tdata[39:32]   = tdata_reg[95:88];
        m_axis_tdata[31:24]   = tdata_reg[103:96];
        m_axis_tdata[23:16]   = tdata_reg[111:104];
        m_axis_tdata[15:8]    = tdata_reg[119:112];
        m_axis_tdata[7:0]     = tdata_reg[127:120];*/
    end
end

always @* begin
    m_axis_tkeep =  tkeep_reg;
  /*  m_axis_tkeep[1] =  tkeep_reg[14];
    m_axis_tkeep[2] =  tkeep_reg[13];
    m_axis_tkeep[3] =  tkeep_reg[12];
    m_axis_tkeep[4] =  tkeep_reg[11];
    m_axis_tkeep[5] =  tkeep_reg[10];
    m_axis_tkeep[6] =  tkeep_reg[9];
    m_axis_tkeep[7] =  tkeep_reg[8];
    m_axis_tkeep[8] =  tkeep_reg[7];
    m_axis_tkeep[9] =  tkeep_reg[6];
    m_axis_tkeep[10] = tkeep_reg[5];
    m_axis_tkeep[11] = tkeep_reg[4];
    m_axis_tkeep[12] = tkeep_reg[3];
    m_axis_tkeep[13] = tkeep_reg[2];
    m_axis_tkeep[14] = tkeep_reg[1];
    m_axis_tkeep[15] = tkeep_reg[0]; */
end

grant_4bits grant_4bits(
    .clk(user_clk),
    .rst_n(user_rst_n),
    
    .get(grant_get),
    .req_bits(grant_req),
    .grant_bits(grant_bits)
);
//------port0 Stream Cache--------
muxfifo_w128_d256 port0_dfifo(
    .wr_clk(port0_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port0_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s0_port2user_data_wr),
    .din(s0_port2user_data),
    
    .rd_en(dfifo_rd[0]),
    .dout(dfifo_rdata[0]),
    
    .rd_data_count(dfifo_rdusedw[0]),
    .wr_data_count(dfifo_wrusedw[0]),
    .empty(dfifo_empty[0]),
    .full(dfifo_full[0])
);

muxfifo_w96_d64 port0_vfifo(
    .wr_clk(port0_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port0_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s0_port2user_stat_wr),
    .din(s0_port2user_stat),
    
    .rd_en(vfifo_rd[0]),
    .dout(vfifo_rdata[0]),
    
    .rd_data_count(vfifo_rdusedw[0]),
    .wr_data_count(vfifo_wrusedw[0]),
    .empty(vfifo_empty[0]),
    .full(vfifo_full[0])
);
//------port1 Stream Cache--------
muxfifo_w128_d256 port1_dfifo(
    .wr_clk(port1_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port1_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s1_port2user_data_wr),
    .din(s1_port2user_data),
    
    .rd_en(dfifo_rd[1]),
    .dout(dfifo_rdata[1]),
    
    .rd_data_count(dfifo_rdusedw[1]),
    .wr_data_count(dfifo_wrusedw[1]),
    .empty(dfifo_empty[1]),
    .full(dfifo_full[1])
);

muxfifo_w96_d64 port1_vfifo(
    .wr_clk(port1_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port1_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s1_port2user_stat_wr),
    .din(s1_port2user_stat),
    
    .rd_en(vfifo_rd[1]),
    .dout(vfifo_rdata[1]),
    
    .rd_data_count(vfifo_rdusedw[1]),
    .wr_data_count(vfifo_wrusedw[1]),
    .empty(vfifo_empty[1]),
    .full(vfifo_full[1])
);
//------port2 Stream Cache--------
muxfifo_w128_d256 port2_dfifo(
    .wr_clk(port2_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port2_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s2_port2user_data_wr),
    .din(s2_port2user_data),
    
    .rd_en(dfifo_rd[2]),
    .dout(dfifo_rdata[2]),
    
    .rd_data_count(dfifo_rdusedw[2]),
    .wr_data_count(dfifo_wrusedw[2]),
    .empty(dfifo_empty[2]),
    .full(dfifo_full[2])
);

muxfifo_w96_d64 port2_vfifo(
    .wr_clk(port2_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port2_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s2_port2user_stat_wr),
    .din(s2_port2user_stat),
    
    .rd_en(vfifo_rd[2]),
    .dout(vfifo_rdata[2]),
    
    .rd_data_count(vfifo_rdusedw[2]),
    .wr_data_count(vfifo_wrusedw[2]),
    .empty(vfifo_empty[2]),
    .full(vfifo_full[2])
);
//------port3 Stream Cache--------
muxfifo_w128_d256 port3_dfifo(
    .wr_clk(port3_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port3_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s3_port2user_data_wr),
    .din(s3_port2user_data),
    
    .rd_en(dfifo_rd[3]),
    .dout(dfifo_rdata[3]),
    
    .rd_data_count(dfifo_rdusedw[3]),
    .wr_data_count(dfifo_wrusedw[3]),
    .empty(dfifo_empty[3]),
    .full(dfifo_full[3])
);

muxfifo_w96_d64 port3_vfifo(
    .wr_clk(port3_rx_clk),
    .rd_clk(user_clk),
    .wr_rst(~port3_rst_n),
    .rd_rst(~user_rst_n),
    
    .wr_en(s3_port2user_stat_wr),
    .din(s3_port2user_stat),
    
    .rd_en(vfifo_rd[3]),
    .dout(vfifo_rdata[3]),
    
    .rd_data_count(vfifo_rdusedw[3]),
    .wr_data_count(vfifo_wrusedw[3]),
    .empty(vfifo_empty[3]),
    .full(vfifo_full[3])
);
endmodule

/**********************************
            Initial Inst
  
fast_mux_stream fast_mux_stream #(
    .START_STREAM_ID(0)
)(
    .user_clk(),//mux module's work clk domin
    .user_rst_n(),
                        
    .port0_rx_clk(),
    .port1_rx_clk(),
    .port2_rx_clk(),
    .port3_rx_clk(),
                        
    .port0_rst_n(),
    .port1_rst_n(),
    .port2_rst_n(),
    .port3_rst_n(),
//--------------input stream-----------------//
    .s0_port2user_data_wr(),
    .s0_port2user_data(),
    .s0_port2user_stat_wr(),
    .s0_port2user_stat(),
    .s0_user2port_rcv_ready(),
    
    .s1_port2user_data_wr(),
    .s1_port2user_data(),
    .s1_port2user_stat_wr(),
    .s1_port2user_stat(),
    .s1_user2port_rcv_ready(),
    
    .s2_port2user_data_wr(),
    .s2_port2user_data(),
    .s2_port2user_stat_wr(),
    .s2_port2user_stat(),
    .s2_user2port_rcv_ready(),
    
    .s3_port2user_data_wr(),
    .s3_port2user_data(),
    .s3_port2user_stat_wr(),
    .s3_port2user_stat(),
    .s3_user2port_rcv_ready(),
//--------------output stream--------------//
    .m_axis_tvalid(),
    .m_axis_tdata(),
    .m_axis_tkeep(),
    .m_axis_tlast(),
    .m_axis_tready//high acitve
);
**********************************/