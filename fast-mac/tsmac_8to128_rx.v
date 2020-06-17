/*
Filename: tsmac_8to128_rx.v
Dscription: 
	1)receive data from gmii interface(8bit data bus)
	2)assemble 8bit data to 128bit
    3)every 128bit is a pkt payloadline

    tsmac is tripe speed mac
Author : lxj
Revision List:
	rn1:	date: 2017/02/20	modifier: lxj
    description: modify the judge error pkt  from the |macrx_axis_terr[5:1] to  macrx_axis_terr[0]
                 as macrx_axis_terr[0] stand |macrx_axis_terr[5:1] in the mac ip's user guide
	rn2:	date:	modifier:	description:
	rn3:	date:	modifier:	description:
*/
module tsmac_8to128_rx(
    input  wire         port_rx_clk,
    input  wire         port_rx_rst_n,
                    
    input  wire         macrx_axis_tvalid,
    input  wire         macrx_axis_tlast,
    input  wire [7:0]   macrx_axis_tdata,
    input  wire         macrx_axis_tuser,
            
    input  wire [63:0]  sys_port_time,//system time(ns) sync to port clk region
    
    output reg          pkt_wr,
    output reg  [127:0] pkt_data,
    output reg          pkt_stat_wr,
    output wire [95:0]  pkt_stat,
    input  wire         pkt_rcv_ready,
    
    output wire         rx_overflow
);

wire        macrx_axis_tstart;
reg         macrx_axis_tvalid_r;

reg         pkt_valid;
reg [14:0]  pkt_len;//count every pkt length
reg [15:0]  pkt_id;

reg [1:0]   rx_state;
localparam  IDLE_S    = 2'd0,
            RCV_S     = 2'd1,
            DISCARD_S = 2'd2;
//use macrx_axis_tvalid generate the macrx_axis_tstart flag
//as Xilinx's MAC IP don't have the rstart flag
always @(posedge port_rx_clk or negedge port_rx_rst_n) begin
    if(port_rx_rst_n == 1'b0) begin
        macrx_axis_tvalid_r <= 1'b0;
    end
    else begin
        macrx_axis_tvalid_r <= macrx_axis_tvalid;
    end
end

assign macrx_axis_tstart = macrx_axis_tvalid & (~macrx_axis_tvalid_r);


assign pkt_stat = {pkt_valid,pkt_len,pkt_id,sys_port_time};

always @(posedge port_rx_clk or negedge port_rx_rst_n) begin
    if(port_rx_rst_n == 1'b0) begin
        pkt_wr <= 1'b0;
        pkt_stat_wr <= 1'b0;
        pkt_valid <= 1'b0;
        rx_state <= IDLE_S;
    end
    else begin
        case(rx_state)
            IDLE_S: begin
                pkt_wr <= 1'b0;
                pkt_stat_wr <= 1'b0;
                pkt_valid <= 1'b0;
                if(macrx_axis_tvalid == 1'b1) begin
                    if((pkt_rcv_ready == 1'b1) && (macrx_axis_tstart == 1'b1)) begin
                    //next module can receive this pkt && current data is the head of pkt
                        pkt_data[8*15+7:8*15] <= macrx_axis_tdata;
                        pkt_len <= 15'd1;//rcv the first byte of pkt
                        rx_state <= RCV_S;
                    end
                    else begin
                        rx_state <= DISCARD_S;
                    end
                end
                else begin
                    rx_state <= IDLE_S;
                end
            end


            RCV_S: begin
                if(macrx_axis_tvalid == 1'b1) begin//there is a 8bit data coming
                    //no need clear it to 0 after a payloadline is full
                    //as pkt_len[3:0]'s  max value is 15,but a full payloadline is 16
                    //so when payload line is full,pkt_len[3:0] will be overflow to 0
                    //but the tail of pkt maybe not a full payloadline ,so need clear pkt_len[3:0]
                    case(pkt_len[3:0])//select the 8bit data's bytesite in current payloadline
                        4'h0: pkt_data[8*15+7:8*15] <= macrx_axis_tdata;
                        4'h1: pkt_data[8*14+7:8*14] <= macrx_axis_tdata;
                        4'h2: pkt_data[8*13+7:8*13] <= macrx_axis_tdata;
                        4'h3: pkt_data[8*12+7:8*12] <= macrx_axis_tdata;
                        4'h4: pkt_data[8*11+7:8*11] <= macrx_axis_tdata;
                        4'h5: pkt_data[8*10+7:8*10] <= macrx_axis_tdata;
                        4'h6: pkt_data[8*9+7:8*9] <= macrx_axis_tdata;
                        4'h7: pkt_data[8*8+7:8*8] <= macrx_axis_tdata;
                        4'h8: pkt_data[8*7+7:8*7] <= macrx_axis_tdata;
                        4'h9: pkt_data[8*6+7:8*6] <= macrx_axis_tdata;
                        4'ha: pkt_data[8*5+7:8*5] <= macrx_axis_tdata;
                        4'hb: pkt_data[8*4+7:8*4] <= macrx_axis_tdata;
                        4'hc: pkt_data[8*3+7:8*3] <= macrx_axis_tdata;
                        4'hd: pkt_data[8*2+7:8*2] <= macrx_axis_tdata;
                        4'he: pkt_data[8*1+7:8*1] <= macrx_axis_tdata;
                        4'hf: pkt_data[8*0+7:8*0] <= macrx_axis_tdata;
                    endcase
                    //send a pkt_wr high active pulse 
                    //when pkt is complete or a payloadline have bben received 16ybte
                    pkt_wr <= ((macrx_axis_tlast == 1'b1) || (pkt_len[3:0] == 4'd15));
                    pkt_len <= pkt_len + 15'd1;
                    if(macrx_axis_tlast == 1'b1) begin
                        pkt_stat_wr <= 1'b1;
                        pkt_valid <= ~macrx_axis_tuser;
                        //pkt_len is count over,so send it to next module with pkt
                        rx_state <= IDLE_S;
                    end
                    else begin
                        pkt_stat_wr <= 1'b0;
                        pkt_valid <= 1'b0;
                        rx_state <= RCV_S;
                    end
                end
                else begin
                    pkt_wr <= 1'b0;
                    pkt_stat_wr <= 1'b0;
                    pkt_valid <= 1'b0;
                    rx_state <= RCV_S;
                end
            end
            
            DISCARD_S: begin
                if((macrx_axis_tlast == 1'b1) && (macrx_axis_tvalid == 1'b1)) begin
                    rx_state <= IDLE_S;
                end
                else begin
                    rx_state <= DISCARD_S;
                end
            end
            
            default: begin
                pkt_wr <= 1'b0;
                pkt_stat_wr <= 1'b0;
                rx_state <= IDLE_S;
            end
        endcase
   end
end

always @(posedge port_rx_clk or negedge port_rx_rst_n) begin
    if(port_rx_rst_n == 1'b0) begin
        pkt_id <= 16'b0;
    end
    else begin
        pkt_id <= pkt_id + pkt_stat_wr;
        //delay 1cycle for pkt_stat_wr,so the pkt id count from 0
    end
end

//assert rx_overflow when a pkt is discard complete
assign rx_overflow = (rx_state == DISCARD_S) && (macrx_axis_tvalid == 1'b1) && (macrx_axis_tlast == 1'b1);



endmodule
/*
tsmac_8to128_rx tsmac_8to128_rx_inst(
    .port_rx_clk(),
    .port_rx_rst_n(),
    
    .macrx_axis_tvalid(),
    .macrx_axis_tlast(),
    .macrx_axis_tdata(),
    .macrx_axis_tuser(),
    
    .sys_port_time(),//system time(ns) sync to port clk region
    
    .pkt_wr(),
    .pkt_data(),
    .pkt_stat_wr(),
    .pkt_stat(),
    .pkt_rcv_ready(),
    
    .rx_overflow()
);
*/