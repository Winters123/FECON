
//Version: 0.1
//Filename: tsmac_128to8_tx.v
//Target Device: xilinx
//Dscription: 
//	1)receive data from user(8bit data bus)
//	2)divide 1288bit data to 8bit slice
//    
//    tsmac is tripe speed mac
//    mactx_axis_tready,more likely ack, only MAC has been got the mactx_axis_tdata,it will be assert
//Author : lxj
//Revision List:
//	rn1:add state WAIT_BYTE_S	date: 20170621	modifier: Qizhuo Yuan 	description: the revise is used for solution the tri speed mac 1g/100m switch question ,
//                                                                                  the reason is the ready signal is discontinuous when the mac's speed is 100m. 
//
//
module tsmac_128to8_tx (
    input  wire         user_clk,//user data's clk domin
    input  wire         user_rst_n,
                    
    input  wire         port_tx_clk,
    input  wire         port_tx_rst_n,
            
    input  wire         mactx_axis_tready,
    output reg          mactx_axis_tvalid,
    output reg          mactx_axis_tlast,
    output reg  [7:0]   mactx_axis_tdata,
    output wire         mactx_axis_tuser,
    
    input  wire         pkt_wr,
    input  wire [127:0] pkt_data,
    input  wire         pkt_stat_wr,
    input  wire [15:0]  pkt_stat,//count every pkt length
    output wire         pkt_rcv_ready
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
wire         dfifo_empty;
wire         dfifo_full;
wire [7:0]   dfifo_wrusedw;
wire [7:0]   dfifo_rdusedw;
reg          dfifo_rden;
wire [127:0] dfifo_rdata; 
reg  [127:0] dfifo_rdata_r;

wire         sfifo_empty;
wire         sfifo_full;
reg          sfifo_rden;
wire [15:0]  sfifo_rdata; 

reg [14:0]   send_byte_cnt;
reg [3:0]    payload_byte_cnt;

reg [1:0]    tx_state;

localparam   FIRST_BYTE_S = 2'd0,
             MIDDLE_BYTE_S = 2'd1,
             LAST_BYTE_S = 2'd2,
             WAIT_BYTE_S = 2'd3;
                          
//***************************************************
//                 Data Transmtion
//***************************************************
assign mactx_axis_tuser = 1'b0;//user must support the pkt need be send is no err

assign pkt_rcv_ready = ~dfifo_wrusedw[7];
//if dfifo_wrusedw[7]=0,that fifo at least can store 2048byte,less than 1518,so must be ready
//exactly,we can use the condition dfifo_wrusedw<161,but use dfifo_wrusedw[7] can get more timing quality  

always @(posedge port_tx_clk or negedge port_tx_rst_n) begin
    if(port_tx_rst_n == 1'b0) begin
        dfifo_rden <= 1'b0;
        sfifo_rden <= 1'b0;
        mactx_axis_tvalid <= 1'b0;
        mactx_axis_tlast <= 1'b0;
        mactx_axis_tdata <= 8'b0;
        send_byte_cnt <= 15'b0;
        payload_byte_cnt <= 4'b0;
        tx_state <= FIRST_BYTE_S;
    end
    else begin
        case(tx_state)
            FIRST_BYTE_S: begin
                dfifo_rden <= 1'b0;
                mactx_axis_tlast <= 1'b0;
                if((sfifo_empty == 1'b0) && (sfifo_rdata[15] == 1'b1))begin//there is a complete pkt wait for sending
                //as non-blocking assign,if send data until mactx_axis_tready assert to 1
                //it will waste 1 cycle
                    sfifo_rden <= 1'b1;
                    mactx_axis_tvalid <= 1'b1;
                    mactx_axis_tdata <= dfifo_rdata[8*15+7:8*15];
                    send_byte_cnt <= sfifo_rdata[14:0] - 15'd1;
                    payload_byte_cnt <= 4'd1;//have been send 1 byte
                    tx_state <= MIDDLE_BYTE_S;
                end
                else begin
                    sfifo_rden <= 1'b0;
                    mactx_axis_tvalid <= 1'b0;
                    tx_state <= FIRST_BYTE_S;
                end
            end
            
            MIDDLE_BYTE_S: begin
                sfifo_rden <= 1'b0;
                mactx_axis_tvalid <= 1'b1;
                if(mactx_axis_tready == 1'b1) begin//the data before cycle have been got
                    send_byte_cnt <= send_byte_cnt - 15'd1;
                    payload_byte_cnt <= payload_byte_cnt + 4'd1;
                    //noneed clear after a full payloadline have been send
                    //as a full payloadline have 16byte ,but payload_byte_cnt's max value is 15,so it will be overflow to 0(just like clear)
                    case(payload_byte_cnt)//select the 8bit data's to send in current payloadline
                        4'h0: mactx_axis_tdata <= dfifo_rdata[8*15+7:8*15];
                        4'h1: mactx_axis_tdata <= dfifo_rdata[8*14+7:8*14];
                        4'h2: mactx_axis_tdata <= dfifo_rdata[8*13+7:8*13];
                        4'h3: mactx_axis_tdata <= dfifo_rdata[8*12+7:8*12];
                        4'h4: mactx_axis_tdata <= dfifo_rdata[8*11+7:8*11];
                        4'h5: mactx_axis_tdata <= dfifo_rdata[8*10+7:8*10];
                        4'h6: mactx_axis_tdata <= dfifo_rdata[8*9+7:8*9];
                        4'h7: mactx_axis_tdata <= dfifo_rdata[8*8+7:8*8];
                        4'h8: mactx_axis_tdata <= dfifo_rdata[8*7+7:8*7];
                        4'h9: mactx_axis_tdata <= dfifo_rdata[8*6+7:8*6];
                        4'ha: mactx_axis_tdata <= dfifo_rdata[8*5+7:8*5];
                        4'hb: mactx_axis_tdata <= dfifo_rdata[8*4+7:8*4];
                        4'hc: mactx_axis_tdata <= dfifo_rdata[8*3+7:8*3];
                        4'hd: mactx_axis_tdata <= dfifo_rdata[8*2+7:8*2];
                        4'he: mactx_axis_tdata <= dfifo_rdata[8*1+7:8*1];
                        4'hf: mactx_axis_tdata <= dfifo_rdata[8*0+7:8*0];
                    endcase
                    
                    if((payload_byte_cnt == 4'he) && (send_byte_cnt != 15'd1)) begin //payload_byte_cnt == 4'he;
                        dfifo_rden <= 1'b1;
                    end
                    else if(send_byte_cnt == 15'd2)begin        //send_byte_cnt == 15'd2;
                        dfifo_rden <= 1'b1;
                    end
                    else begin
                        dfifo_rden <= 1'b0;
                    end

                    if(send_byte_cnt == 15'd1) begin//whole pkt will be send over after this cycle 
                      //  dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b1;
                        tx_state <= LAST_BYTE_S;
                    end
                    else begin
                        //dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b0;
                        tx_state <= MIDDLE_BYTE_S;
                    end
                    
                end
                else begin
                    if(dfifo_rden==1'b1) begin
                        dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b0;
                        dfifo_rdata_r <= dfifo_rdata;
                        tx_state <= WAIT_BYTE_S;
                        end
                    else begin
                        dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b0;
                        tx_state <= MIDDLE_BYTE_S;
                        end
                end
            end
            
            WAIT_BYTE_S: begin
                if(mactx_axis_tready == 1'b1) begin
                    send_byte_cnt <= send_byte_cnt - 15'd1;
                    payload_byte_cnt <= payload_byte_cnt + 4'd1;
                    //noneed clear after a full payloadline have been send
                    //as a full payloadline have 16byte ,but payload_byte_cnt's max value is 15,so it will be overflow to 0(just like clear)
                    case(payload_byte_cnt)//select the 8bit data's to send in current payloadline
                        4'h0: mactx_axis_tdata <= dfifo_rdata_r[8*15+7:8*15];
                        4'h1: mactx_axis_tdata <= dfifo_rdata_r[8*14+7:8*14];
                        4'h2: mactx_axis_tdata <= dfifo_rdata_r[8*13+7:8*13];
                        4'h3: mactx_axis_tdata <= dfifo_rdata_r[8*12+7:8*12];
                        4'h4: mactx_axis_tdata <= dfifo_rdata_r[8*11+7:8*11];
                        4'h5: mactx_axis_tdata <= dfifo_rdata_r[8*10+7:8*10];
                        4'h6: mactx_axis_tdata <= dfifo_rdata_r[8*9+7:8*9];
                        4'h7: mactx_axis_tdata <= dfifo_rdata_r[8*8+7:8*8];
                        4'h8: mactx_axis_tdata <= dfifo_rdata_r[8*7+7:8*7];
                        4'h9: mactx_axis_tdata <= dfifo_rdata_r[8*6+7:8*6];
                        4'ha: mactx_axis_tdata <= dfifo_rdata_r[8*5+7:8*5];
                        4'hb: mactx_axis_tdata <= dfifo_rdata_r[8*4+7:8*4];
                        4'hc: mactx_axis_tdata <= dfifo_rdata_r[8*3+7:8*3];
                        4'hd: mactx_axis_tdata <= dfifo_rdata_r[8*2+7:8*2];
                        4'he: mactx_axis_tdata <= dfifo_rdata_r[8*1+7:8*1];
                        4'hf: mactx_axis_tdata <= dfifo_rdata_r[8*0+7:8*0];
                    endcase
                    if(send_byte_cnt == 15'd1) begin//whole pkt will be send over after this cycle 
                        //dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b1;
                        tx_state <= LAST_BYTE_S;
                        end
                    else if(send_byte_cnt == 15'd2) begin
                        dfifo_rden <= 1'b1;
                        mactx_axis_tlast <= 1'b0;
                        tx_state <= MIDDLE_BYTE_S;
                        end
                    else begin
                       // dfifo_rden <= 1'b0;
                        mactx_axis_tlast <= 1'b0;
                        tx_state <= MIDDLE_BYTE_S;
                        end
                    end
                else begin
                    tx_state <= WAIT_BYTE_S;
                    end
                end    
            
            LAST_BYTE_S: begin
                dfifo_rden <= 1'b0;
                if(mactx_axis_tready == 1'b1) begin//the last 8 bit data before cycle have been got
                    mactx_axis_tlast <= 1'b0;
                    if((sfifo_empty == 1'b0) && (sfifo_rdata[15] == 1'b1)) begin//there is a complete pkt wait for sending
                    //no need jump to FIRST_BYTE_S, if you do it, maybe will waste 1 cycle
                        sfifo_rden <= 1'b1;
                        mactx_axis_tvalid <= 1'b1;
                        mactx_axis_tdata <= dfifo_rdata[8*15+7:8*15];
                        send_byte_cnt <= sfifo_rdata[14:0] - 15'd1;
                        payload_byte_cnt <= 4'd1;//have been send 1 byte
                        tx_state <= MIDDLE_BYTE_S;
                    end
                    else begin
                        sfifo_rden <= 1'b0;
                        mactx_axis_tvalid <= 1'b0;
                        tx_state <= FIRST_BYTE_S;
                    end
                end
                else begin//hold the mac_data and so on,for mac to get it
                    sfifo_rden <= 1'b0;
                    mactx_axis_tvalid <= 1'b1;
                    mactx_axis_tlast <= 1'b1;
                    tx_state <= LAST_BYTE_S;
                end
            end
            
            default: begin
                dfifo_rden <= 1'b0;
                sfifo_rden <= 1'b0;
                mactx_axis_tvalid <= 1'b0;
                mactx_axis_tlast <= 1'b0;
                mactx_axis_tdata <= 8'b0;
                send_byte_cnt <= 15'b0;
                payload_byte_cnt <= 4'b0;
                tx_state <= FIRST_BYTE_S;
            end
        endcase
    end
end

//***************************************************
//                  Other IP Instance
//***************************************************
//likely fifo/ram/async block.... 
//should be instantiated below here 
async_mactx_dfifo_w128_d256 async_mactx_dfifo_w128_d256_inst(  
    .wr_clk(user_clk),
    .rd_clk(port_tx_clk),
    .wr_rst(~user_rst_n),
    .rd_rst(~port_tx_rst_n),

    .wr_en(pkt_wr),
    .din(pkt_data),
    .rd_en(dfifo_rden),
    .dout(dfifo_rdata),
    //--------FIFO State-----   
    .wr_data_count(dfifo_wrusedw),
    .rd_data_count(dfifo_rdusedw),
    .full(dfifo_full),
    .empty(dfifo_empty)
);

async_mactx_vfifo_w16_d64 async_mactx_vfifo_w16_d64_inst(  
    .wr_clk(user_clk),
    .rd_clk(port_tx_clk),
    .wr_rst(~user_rst_n),
    .rd_rst(~port_tx_rst_n),

    .wr_en(pkt_stat_wr),
    .din(pkt_stat),
    
    .rd_en(sfifo_rden),
    .dout(sfifo_rdata),
    //--------FIFO State-----   
    .full(sfifo_full),
    .empty(sfifo_empty)
);

endmodule
/*
tsmac_128to8_tx tsmac_128to8_tx_inst(
    .user_clk(),//user data's clk domin
    .user_rst_n(),

    .port_tx_clk(),
    .port_tx_rst_n(),

    .mactx_axis_tready(),
    .mactx_axis_tvalid(),
    .mactx_axis_tlast(),
    .mactx_axis_tdata(),
    .mactx_axis_tuser(),

    .pkt_wr(),
    .pkt_data(),
    .pkt_stat_wr(),
    .pkt_stat(),//count every pkt length
    .pkt_rcv_ready()
);
*/