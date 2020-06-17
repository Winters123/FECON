////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version:0.0.2018/4/25
//Filename: cdpaxi2fast.v
//Target Device: Xilinx
//Dscription: 
//  1) 
//  2) 
//  3) 
//Data Type:
//  
//Author : Qizhuo Yuan
//History List:
//
//
module cdpaxi2fast(
    input wire          aclk,
    input wire          aresetn,
//-------------cdp_axi-------------------
    input wire          s_axi_tvalid,
    input wire [127:0]  s_axi_tdata,
    input wire          s_axi_tlast,
    input wire [15:0]   s_axi_tkeep,
    input wire [15:0]   s_axi_tstrb,
    output wire          s_axi_tready,
//-------------cdp_fast------------------
    output reg          cdp2um_data_wr,
    output reg [133:0]  cdp2um_data,
    output reg          cdp2um_valid_wr,
    output reg          cdp2um_valid,
    input wire          cdp2um_ready
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable
//should be declare below here

//------------axi_register---------------------------

reg             s_axi_tvalid_r;

reg [15:0]      s_axi_tkeep_r;
//------------fifo-----------------------------------
reg [133:0]     dfifo_wdata;
reg             dfifo_wden;
wire             dfifo_full;
wire [133:0]     dfifo_rdata;
reg             dfifo_rden;
wire             dfifo_empty;
wire [8:0]       dfifo_cnt;

reg             sfifo_wdata;
reg             sfifo_wden;
wire             sfifo_full;
wire             sfifo_rdata;
reg             sfifo_rden;
wire             sfifo_empty;
//------------tran_state-----------------------------
reg [1:0]       tran_state;
localparam      IDLE_S = 2'b00,
                TRAN_S = 2'b01,
                WAIT_S = 2'b10;

//***************************************************
//              register
//***************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        s_axi_tvalid_r <= 1'b0;
        end
    else begin
        s_axi_tvalid_r <= s_axi_tvalid;
        end
    end
//***************************************************
//        axi4-stream transform fast
//***************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        dfifo_wdata <= 134'h0;
        dfifo_wden <= 1'b0;
        sfifo_wdata <= 1'b0;
        sfifo_wden <= 1'b0;
        end
    else begin
        if((s_axi_tvalid)&&(~s_axi_tvalid_r)&&(s_axi_tready))begin
            dfifo_wdata <= {2'b01,4'b0000,s_axi_tdata};
            dfifo_wden <= 1'b1;
            sfifo_wdata <= 1'b0;
            sfifo_wden <= 1'b0;
            end
        else if((s_axi_tvalid)&&(s_axi_tvalid_r)&&(s_axi_tready))begin
            if(~s_axi_tlast) begin
                dfifo_wdata <= {2'b11,4'b0000,s_axi_tdata};
                dfifo_wden <= 1'b1;
                sfifo_wdata <= 1'b0;
                sfifo_wden <= 1'b0;
                end
            else begin
                dfifo_wden <= 1'b1;
                sfifo_wdata <= 1'b1;
                sfifo_wden <= 1'b1;
                case(s_axi_tkeep)
                16'hffff: dfifo_wdata <= {2'b10,4'b0000,s_axi_tdata};
                16'hfffe: dfifo_wdata <= {2'b10,4'b0001,s_axi_tdata};
                16'hfffc: dfifo_wdata <= {2'b10,4'b0010,s_axi_tdata};
                16'hfff8: dfifo_wdata <= {2'b10,4'b0011,s_axi_tdata};
                16'hfff0: dfifo_wdata <= {2'b10,4'b0100,s_axi_tdata};
                16'hffe0: dfifo_wdata <= {2'b10,4'b0101,s_axi_tdata};
                16'hffc0: dfifo_wdata <= {2'b10,4'b0110,s_axi_tdata};
                16'hff80: dfifo_wdata <= {2'b10,4'b0111,s_axi_tdata};
                16'hff00: dfifo_wdata <= {2'b10,4'b1000,s_axi_tdata};
                16'hfe00: dfifo_wdata <= {2'b10,4'b1001,s_axi_tdata};
                16'hfc00: dfifo_wdata <= {2'b10,4'b1010,s_axi_tdata};
                16'hf800: dfifo_wdata <= {2'b10,4'b1011,s_axi_tdata};
                16'hf000: dfifo_wdata <= {2'b10,4'b1100,s_axi_tdata};
                16'he000: dfifo_wdata <= {2'b10,4'b1101,s_axi_tdata};
                16'hc000: dfifo_wdata <= {2'b10,4'b1110,s_axi_tdata};
                16'h8000: dfifo_wdata <= {2'b10,4'b1111,s_axi_tdata};
                default: dfifo_wdata <= 134'h0;
                endcase
                end
            end    
        else begin
            dfifo_wdata <= 134'h0;
            dfifo_wden <= 1'b0;
            sfifo_wdata <= 1'b0;
            sfifo_wden <= 1'b0;
            end
        end
    end
//*****************************************************
//          tran_state
//*****************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        cdp2um_data_wr <= 1'b0;
        cdp2um_data <= 134'h0;
        cdp2um_valid_wr <= 1'b0;
        cdp2um_valid <= 1'b0;
        dfifo_rden <= 1'b0;
        sfifo_rden <= 1'b0;
        tran_state <= IDLE_S;
        end
    else begin
        case(tran_state)
            IDLE_S: begin
                sfifo_rden <= 1'b0;
                if(sfifo_empty==1'b0) begin
                    if(cdp2um_ready==1'b1) begin
                        cdp2um_data_wr <= 1'b0;
                        cdp2um_data <= 134'h0;
                        cdp2um_valid_wr <= 1'b0;
                        cdp2um_valid <= 1'b0;
                        dfifo_rden <= 1'b1;
                        tran_state <= TRAN_S;
                        end
                    else begin
                        cdp2um_data_wr <= 1'b0;
                        cdp2um_data <= 134'h0;
                        cdp2um_valid_wr <= 1'b0;
                        cdp2um_valid <= 1'b0;
                        dfifo_rden <= 1'b0;
                        tran_state <= IDLE_S;
                        end                        
                    end
                else begin
                    cdp2um_data_wr <= 1'b0;
                    cdp2um_data <= 134'h0;
                    cdp2um_valid_wr <= 1'b0;
                    cdp2um_valid <= 1'b0;
                    dfifo_rden <= 1'b0;
                    tran_state <= IDLE_S;
                    end
                end
            
            TRAN_S: begin
                cdp2um_data_wr <= 1'b1;
                cdp2um_data <= dfifo_rdata;
                if(dfifo_rdata[133:132]==2'b10) begin
                    tran_state <= WAIT_S;
                    sfifo_rden <= 1'b1;
                    cdp2um_valid_wr <= 1'b1;
                    cdp2um_valid <= 1'b1;
                    dfifo_rden <= 1'b0;
                    end
                else begin
                    tran_state <= TRAN_S;
                    cdp2um_valid_wr <= 1'b0;
                    cdp2um_valid <= 1'b0;
                    dfifo_rden <= 1'b1;
                    end
                end
                
            WAIT_S: begin
                cdp2um_data_wr <= 1'b0;
                cdp2um_data <= 134'h0;
                cdp2um_valid_wr <= 1'b0;
                cdp2um_valid <= 1'b0;
                dfifo_rden <= 1'b0;
                sfifo_rden <= 1'b0;
                tran_state <= IDLE_S;
                end
                
            default: begin
                cdp2um_data_wr <= 1'b0;
                cdp2um_data <= 134'h0;
                cdp2um_valid_wr <= 1'b0;
                cdp2um_valid <= 1'b0;
                dfifo_rden <= 1'b0;
                sfifo_rden <= 1'b0;
                tran_state <= IDLE_S;
                end
                
            endcase
        end
    end
//***************************************************
//                    IP Instance
//***************************************************  
assign s_axi_tready = ~dfifo_cnt[7];    
    
sync_fifo_w134_d256_dfifo dfifo_cdp(  
    .clk(aclk),
    .srst(~aresetn),
    .wr_en(dfifo_wden),
    .din(dfifo_wdata),
    .rd_en(dfifo_rden),
    .dout(dfifo_rdata),
    .full(dfifo_full),
    .empty(dfifo_empty),
    .data_count(dfifo_cnt)
);

sync_fifo_w1_d64_sfifo sfifo_cdp(  
    .clk(aclk),
    .srst(~aresetn),
    .wr_en(sfifo_wden),
    .din(sfifo_wdata),
    .rd_en(sfifo_rden),
    .dout(sfifo_rdata),   
    .full(sfifo_full),
    .empty(sfifo_empty)
);

endmodule


/*
cdpaxi2fast cdpaxi2fast(
    .aclk(),
    .aresetn(),
//-------------cdp_axi-------------------
    .s_axi_tvalid(),
    .s_axi_tdata(),
    .s_axi_tlast(),
    .s_axi_tkeep(),
    .s_axi_tstrb(),
    .s_axi_tready(),
//-------------cdp_fast------------------
    .cdp2um_data_wr(),
    .cdp2um_data(),
    .cdp2um_valid_wr(),
    .cdp2um_valid(),
    .cdp2um_ready()
);
*/


   