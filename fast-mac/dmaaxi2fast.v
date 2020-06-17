////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version:0.0.2018/5/4
//Filename: dmaaxi2fast.v
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
module dmaaxi2fast(
    input wire          aclk,
    input wire          aresetn,
//-------------dma_axi--------------------
    input wire          s_axi_tvalid,
    input wire [127:0]  s_axi_tdata,
    input wire          s_axi_tlast,
    input wire [15:0]   s_axi_tkeep,
    input wire [15:0]   s_axi_tstrb,
    output wire          s_axi_tready,
//-------------dma_fast-------------------
    output reg          dma2um_data_wr,
    output reg [133:0]  dma2um_data,
    output reg          dma2um_valid_wr,
    output reg          dma2um_valid,
    input wire          dma2um_ready
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable
//should be declare below here
/*
//------------axi_register---------------------------
reg [127:0]     s_axi_tdata_r;
reg             s_axi_tvalid_r;
reg             s_axi_tlast_r;
reg [15:0]      s_axi_tkeep_r;*/
wire [127:0]     dfifo_rdata_n;   
reg [7:0]       count;
//------------fifo-----------------------------------
reg [127:0]      dfifo_wdata;
reg              dfifo_wden;      
wire             dfifo_full;
wire [127:0]     dfifo_rdata;
reg             dfifo_rden;
wire             dfifo_empty;
wire [8:0]       dfifo_cnt;

reg [15:0]       sfifo_wdata;
reg              sfifo_wden;              
wire             sfifo_full;
wire [15:0]      sfifo_rdata;
reg             sfifo_rden;
wire             sfifo_empty;

reg             lsfifo_wdata;
reg             lsfifo_wden;
wire            lsfifo_full;
wire            lsfifo_rdata;
reg             lsfifo_rden;
wire            lsfifo_empty;
reg [15:0]sfifo_valid;
//------------tran_state-----------------------------
reg [2:0]       tran_state;
localparam      IDLE_S = 3'd0,
                METADATA_S = 3'd1,
                TRAN_S = 3'd2,
                WAIT_S = 3'd3,
				CMD_S=3'd4,
                TRAN_CMD_S=3'd5;

//***************************************************
//          
//***************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        lsfifo_wdata <= 1'b0;
        lsfifo_wden <= 1'b0;
        sfifo_wdata <= 1'b0;
        sfifo_wden <= 1'b0;
        dfifo_wdata <= 1'b0;
        dfifo_wden <= 1'b0;
        end
    else begin
        if((s_axi_tvalid==1'b1)&&(s_axi_tready==1'b1)) begin
            if(s_axi_tlast==1'b1) begin
                lsfifo_wdata <= 1'b1;
                lsfifo_wden <= 1'b1;
                dfifo_wdata <= s_axi_tdata;
                dfifo_wden <= 1'b1;
                sfifo_wdata <= s_axi_tkeep;
                sfifo_wden <= 1'b1;
                end
            else begin
                lsfifo_wdata <= 1'b0;
                lsfifo_wden <= 1'b1;
                dfifo_wdata <= s_axi_tdata;
                dfifo_wden <= 1'b1;
                sfifo_wdata <= 16'hffff;
                sfifo_wden <= 1'b0;
                end
            end
        else begin
            lsfifo_wdata <= 1'b0;
            lsfifo_wden <= 1'b0;
            sfifo_wdata <= 1'b0;
            sfifo_wden <= 1'b0;
            dfifo_wdata <= 1'b0;
            dfifo_wden <= 1'b0;
            end
        end
    end            
                
                
assign dfifo_rdata_n = {dfifo_rdata[7:0],dfifo_rdata[15:8],dfifo_rdata[23:16],dfifo_rdata[31:24],dfifo_rdata[39:32],dfifo_rdata[47:40],
    dfifo_rdata[55:48],dfifo_rdata[63:56],dfifo_rdata[71:64],dfifo_rdata[79:72],dfifo_rdata[87:80],dfifo_rdata[95:88],
    dfifo_rdata[103:96],dfifo_rdata[111:104],dfifo_rdata[119:112],dfifo_rdata[127:120]};
/*
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

//**************************************************
//          axi4-stream transform fast
//**************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        dfifo_wdata <= 134'h0;
        dfifo_wden <= 1'b0;
        sfifo_wdata <= 1'b0;
        sfifo_wden <= 1'b0;
        count <= 8'd1;
        end
    else begin
        if((s_axi_tvalid)&&(~s_axi_tvalid_r)) begin
            dfifo_wdata <= {2'b01,4'b0000,s_axi_tdata};
            dfifo_wden <= 1'b1;
            sfifo_wdata <= 1'b0;
            sfifo_wden <= 1'b0;
            count <= count+1'd1;
            end
        else if((s_axi_tvalid)&&(s_axi_tvalid_r)) begin
            if(~s_axi_tlast) begin
                if(count<=8'd2) begin
                    dfifo_wdata <= {2'b11,4'b0000,s_axi_tdata};
                    dfifo_wden <= 1'b1;
                    sfifo_wdata <= 1'b0;
                    sfifo_wden <= 1'b0;
                    count <= count+1'd1;
                    end
                else begin
                    dfifo_wdata <= {2'b11,4'b0000,s_axi_tdata_n};
                    dfifo_wden <= 1'b1;
                    sfifo_wdata <= 1'b0;
                    sfifo_wden <= 1'b0;
                    count <= count+1'd1;
                    end
                end   
            else begin
            dfifo_wden <= 1'b1;
            sfifo_wdata <= 1'b1;
            sfifo_wden <= 1'b1;
            count <= 8'd1;
            case(s_axi_tkeep)
                16'hffff: dfifo_wdata <= {2'b10,4'b0000,s_axi_tdata_n};
                16'h7fff: dfifo_wdata <= {2'b10,4'b0001,s_axi_tdata_n};
                16'h3fff: dfifo_wdata <= {2'b10,4'b0010,s_axi_tdata_n};
                16'h1fff: dfifo_wdata <= {2'b10,4'b0011,s_axi_tdata_n};
                16'h0fff: dfifo_wdata <= {2'b10,4'b0100,s_axi_tdata_n};
                16'h07ff: dfifo_wdata <= {2'b10,4'b0101,s_axi_tdata_n};
                16'h03ff: dfifo_wdata <= {2'b10,4'b0110,s_axi_tdata_n};
                16'h01ff: dfifo_wdata <= {2'b10,4'b0111,s_axi_tdata_n};
                16'h00ff: dfifo_wdata <= {2'b10,4'b1000,s_axi_tdata_n};
                16'h007f: dfifo_wdata <= {2'b10,4'b1001,s_axi_tdata_n};
                16'h003f: dfifo_wdata <= {2'b10,4'b1010,s_axi_tdata_n};
                16'h001f: dfifo_wdata <= {2'b10,4'b1011,s_axi_tdata_n};
                16'h000f: dfifo_wdata <= {2'b10,4'b1100,s_axi_tdata_n};
                16'h0007: dfifo_wdata <= {2'b10,4'b1101,s_axi_tdata_n};
                16'h0003: dfifo_wdata <= {2'b10,4'b1110,s_axi_tdata_n};
                16'h0001: dfifo_wdata <= {2'b10,4'b1111,s_axi_tdata_n};
                default: dfifo_wdata <= 134'h0;
                endcase
            end
        end    
        else begin
            dfifo_wdata <= 134'h0;
            dfifo_wden <= 1'b0;
            sfifo_wdata <= 1'b0;
            sfifo_wden <= 1'b0;
            count <= count;
            end
        end
    end*/
//********************************************************
//              tran_state
//********************************************************
always @(posedge aclk or negedge aresetn) begin
    if(~aresetn) begin
        dma2um_data_wr <= 1'b0;
        dma2um_data <= 134'h0;
        dma2um_valid_wr <= 1'b0;
        dma2um_valid <= 1'b0;
        dfifo_rden <= 1'b0;
        sfifo_rden <= 1'b0;
        lsfifo_rden <= 1'b0;
        count <= 8'd0;
		sfifo_valid<=16'b0;
        tran_state <= IDLE_S;
        end
    else begin
        case(tran_state)
            IDLE_S: begin
			     dma2um_data_wr <= 1'b0;
                 dma2um_data <= 134'h0;
                 dma2um_valid_wr <= 1'b0;
                 dma2um_valid <= 1'b0;
                 dfifo_rden <= 1'b0;
                 sfifo_rden <= 1'b0;
                 lsfifo_rden <= 1'b0;
                 count <= 8'd0;
			    sfifo_valid<=16'b0;
                if(sfifo_empty==1'b0) begin
                    if(dma2um_ready==1'b1) begin
                        dma2um_data_wr <= 1'b0;
                        dma2um_data <= 134'h0;
                        dma2um_valid_wr <= 1'b0;
                        dma2um_valid <= 1'b0;
                        dfifo_rden <= 1'b1;
                        lsfifo_rden <= 1'b1;
                        sfifo_rden <= 1'b1;
						sfifo_valid<=sfifo_rdata;
						if(dfifo_rdata[127]==1'b1)begin//pkttype
						tran_state <= CMD_S;
						end
						else begin
                        count <= 8'd1;
                        tran_state <= METADATA_S;						
                        end
					end
                    else begin
                        dma2um_data_wr <= 1'b0;
                        dma2um_data <= 134'h0;
                        dma2um_valid_wr <= 1'b0;
                        dma2um_valid <= 1'b0;
                        dfifo_rden <= 1'b0;
                        lsfifo_rden <= 1'b0;
                        count <= 8'd0;
                        tran_state <= IDLE_S;
                        end
                    end
                else begin
                    dma2um_data_wr <= 1'b0;
                    dma2um_data <= 134'h0;
                    dma2um_valid_wr <= 1'b0;
                    dma2um_valid <= 1'b0;
                    dfifo_rden <= 1'b0;
                    lsfifo_rden <= 1'b0;
                    count <= 8'd0;
                    tran_state <= IDLE_S;
                    end
                end
            METADATA_S : begin
                sfifo_rden <= 1'b0;
                if(count == 8'd1) begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_data <= {2'b01,4'b0000,dfifo_rdata};
                    dma2um_valid <= 1'b0;
                    dma2um_valid_wr <= 1'b0;
                    count = count + 1'd1;
                    dfifo_rden <= 1'b1;
                    lsfifo_rden <= 1'b1;
                    tran_state <= METADATA_S;
                    end
                else if(count == 8'd2) begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_data <= {2'b11,4'b0000,dfifo_rdata};
                    dma2um_valid <= 1'b0;
                    dma2um_valid_wr <= 1'b0;
                    count = count + 1'd1;
                    dfifo_rden <= 1'b1;
                    lsfifo_rden <= 1'b1;
                    tran_state <= TRAN_S;
                    end
                else begin
                    dma2um_data_wr <= 1'b0;
                    dma2um_data <= 134'h0;
                    dma2um_valid <= 1'b0;
                    dma2um_valid_wr <= 1'b0;
                    count = 1'd0;
                    dfifo_rden <= 1'b0;
                    lsfifo_rden <= 1'b0;
                    tran_state <= METADATA_S;
                    end
                end    
              
            TRAN_S: begin
                if(lsfifo_rdata==1'b1) begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_valid <= 1'b1;
                    dma2um_valid_wr <= 1'b1;
                    dfifo_rden <= 1'b0;
                    lsfifo_rden <= 1'b0;
                    tran_state <= IDLE_S;
                    case(sfifo_valid)
                        16'hffff: dma2um_data <= {2'b10,4'b0000,dfifo_rdata_n};
                        16'h7fff: dma2um_data <= {2'b10,4'b0001,dfifo_rdata_n};
                        16'h3fff: dma2um_data <= {2'b10,4'b0010,dfifo_rdata_n};
                        16'h1fff: dma2um_data <= {2'b10,4'b0011,dfifo_rdata_n};
                        16'h0fff: dma2um_data <= {2'b10,4'b0100,dfifo_rdata_n};
                        16'h07ff: dma2um_data <= {2'b10,4'b0101,dfifo_rdata_n};
                        16'h03ff: dma2um_data <= {2'b10,4'b0110,dfifo_rdata_n};
                        16'h01ff: dma2um_data <= {2'b10,4'b0111,dfifo_rdata_n};
                        16'h00ff: dma2um_data <= {2'b10,4'b1000,dfifo_rdata_n};
                        16'h007f: dma2um_data <= {2'b10,4'b1001,dfifo_rdata_n};
                        16'h003f: dma2um_data <= {2'b10,4'b1010,dfifo_rdata_n};
                        16'h001f: dma2um_data <= {2'b10,4'b1011,dfifo_rdata_n};
                        16'h000f: dma2um_data <= {2'b10,4'b1100,dfifo_rdata_n};
                        16'h0007: dma2um_data <= {2'b10,4'b1101,dfifo_rdata_n};
                        16'h0003: dma2um_data <= {2'b10,4'b1110,dfifo_rdata_n};
                        16'h0001: dma2um_data <= {2'b10,4'b1111,dfifo_rdata_n};
                        default: dma2um_data <= 134'h0;
                        endcase
                    end
                else begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_valid <= 1'b0;
                    dma2um_valid_wr <= 1'b0;
                    dfifo_rden <= 1'b1;
                    lsfifo_rden <= 1'b1;
                    tran_state <= TRAN_S;
                    dma2um_data <= {2'b11,4'b0000,dfifo_rdata_n};
                    end
                end
            
            WAIT_S: begin
                dma2um_data_wr <= 1'b0;
                dma2um_data <= 134'h0;
                dma2um_valid_wr <= 1'b0;
                dma2um_valid <= 1'b0;
                dfifo_rden <= 1'b0;
                lsfifo_rden <= 1'b0;
                count <= 8'd0;
                tran_state <= IDLE_S;
                end
			CMD_S:begin
			     sfifo_rden <= 1'b0;
			     dma2um_data_wr <= 1'b1;
                 dma2um_valid <= 1'b0;
                 dma2um_valid_wr <= 1'b0;
                 dfifo_rden <= 1'b1;
                 lsfifo_rden <= 1'b1;
                 tran_state <= TRAN_CMD_S;
                 dma2um_data <= {2'b01,4'b0000,dfifo_rdata};
			end
			
			TRAN_CMD_S: begin
                if(lsfifo_rdata==1'b1) begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_valid <= 1'b1;
                    dma2um_valid_wr <= 1'b1;
                    dfifo_rden <= 1'b0;
                    lsfifo_rden <= 1'b0;
                    tran_state <= IDLE_S;
                    case(sfifo_valid)
                        16'hffff: dma2um_data <= {2'b10,4'b0000,dfifo_rdata};
                        16'h7fff: dma2um_data <= {2'b10,4'b0001,dfifo_rdata};
                        16'h3fff: dma2um_data <= {2'b10,4'b0010,dfifo_rdata};
                        16'h1fff: dma2um_data <= {2'b10,4'b0011,dfifo_rdata};
                        16'h0fff: dma2um_data <= {2'b10,4'b0100,dfifo_rdata};
                        16'h07ff: dma2um_data <= {2'b10,4'b0101,dfifo_rdata};
                        16'h03ff: dma2um_data <= {2'b10,4'b0110,dfifo_rdata};
                        16'h01ff: dma2um_data <= {2'b10,4'b0111,dfifo_rdata};
                        16'h00ff: dma2um_data <= {2'b10,4'b1000,dfifo_rdata};
                        16'h007f: dma2um_data <= {2'b10,4'b1001,dfifo_rdata};
                        16'h003f: dma2um_data <= {2'b10,4'b1010,dfifo_rdata};
                        16'h001f: dma2um_data <= {2'b10,4'b1011,dfifo_rdata};
                        16'h000f: dma2um_data <= {2'b10,4'b1100,dfifo_rdata};
                        16'h0007: dma2um_data <= {2'b10,4'b1101,dfifo_rdata};
                        16'h0003: dma2um_data <= {2'b10,4'b1110,dfifo_rdata};
                        16'h0001: dma2um_data <= {2'b10,4'b1111,dfifo_rdata};
                        default: dma2um_data <= 134'h0;
                        endcase
                    end
                else begin
                    dma2um_data_wr <= 1'b1;
                    dma2um_valid <= 1'b0;
                    dma2um_valid_wr <= 1'b0;
                    dfifo_rden <= 1'b1;
                    lsfifo_rden <= 1'b1;
                    tran_state <= TRAN_CMD_S;
                    dma2um_data <= {2'b11,4'b0000,dfifo_rdata};
                    end
                end
            endcase   
        end
    end        
//***************************************************
//                    IP Instance
//***************************************************
assign s_axi_tready = ~dfifo_cnt[7];    
    
sync_fifo_w128_d256_dfifo dfifo_dma(  
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

sync_fifo_w16_d64_sfifo sfifo_dma(  
    .clk(aclk),
    .srst(~aresetn),
    .wr_en(sfifo_wden),
    .din(sfifo_wdata),
    .rd_en(sfifo_rden),
    .dout(sfifo_rdata),   
    .full(sfifo_full),
    .empty(sfifo_empty)
);

sync_fifo_w1_d256_sfifo lsfifo_dma(  
    .clk(aclk),
    .srst(~aresetn),
    .wr_en(lsfifo_wden),
    .din(lsfifo_wdata),
    .rd_en(lsfifo_rden),
    .dout(lsfifo_rdata),   
    .full(lsfifo_full),
    .empty(lsfifo_empty)
);


endmodule

/*
dmaaxi2fast dmaaxi2fast(
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
    .dma2um_data_wr(),
    .dma2um_data(),
    .dma2um_valid_wr(),
    .dma2um_valid(),
    .dma2um_ready()
);
*/

                
