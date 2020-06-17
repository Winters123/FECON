////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version:0.0.2018/5/5
//Filename: axi2fast.v
//Target Device: Xilinx
//Dscription: 
//  1) top files
//  2) 
//  3) 
//Data Type:
//  
//Author : Qizhuo Yuan
//History List:
//
//
module axi2fast(
    input wire          aclk,
    input wire          aresetn,
//-------------cdp_axi-------------------
    input wire          s_axi_cdp_tvalid,
    input wire [127:0]  s_axi_cdp_tdata,
    input wire          s_axi_cdp_tlast,
    input wire [15:0]   s_axi_cdp_tkeep,
    input wire [15:0]   s_axi_cdp_tstrb,
    output wire         s_axi_cdp_tready,
//-------------dma_axi--------------------
    input wire          s_axi_dma_tvalid,
    input wire [127:0]  s_axi_dma_tdata,
    input wire          s_axi_dma_tlast,
    input wire [15:0]   s_axi_dma_tkeep,
    input wire [15:0]   s_axi_dma_tstrb,
    output wire         s_axi_dma_tready,
//----------trans pkt to um---------------
    output wire          pktin_data_wr,
    output wire [133:0]  pktin_data,
    output wire          pktin_data_valid_wr,
    output wire          pktin_data_valid,
    input wire           pktin_ready,
	output wire          cin_data_valid,
    output wire [133:0]  cin_data,
    input  wire          cin_ready
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable
//should be declare below here
wire                cdp2um_data_wr;
wire [133:0]        cdp2um_data;
wire                cdp2um_valid_wr;
wire                cdp2um_valid;
wire                cdp2um_ready;

wire                dma2um_data_wr;
wire [133:0]        dma2um_data;
wire                dma2um_valid_wr;
wire                dma2um_valid;
wire                dma2um_ready;








//***************************************************
//                    IP Instance
//***************************************************
cdpaxi2fast cdpaxi2fast(
    .aclk(aclk),
    .aresetn(aresetn),
//-------------cdp_axi-------------------
    .s_axi_tvalid(s_axi_cdp_tvalid),
    .s_axi_tdata(s_axi_cdp_tdata),
    .s_axi_tlast(s_axi_cdp_tlast),
    .s_axi_tkeep(s_axi_cdp_tkeep),
    .s_axi_tstrb(s_axi_cdp_tstrb),
    .s_axi_tready(s_axi_cdp_tready),
//-------------cdp_fast------------------
    .cdp2um_data_wr(cdp2um_data_wr),
    .cdp2um_data(cdp2um_data),
    .cdp2um_valid_wr(cdp2um_valid_wr),
    .cdp2um_valid(cdp2um_valid),
    .cdp2um_ready(cdp2um_ready)
);

dmaaxi2fast dmaaxi2fast(
    .aclk(aclk),
    .aresetn(aresetn),
//-------------cdp_axi-------------------
    .s_axi_tvalid(s_axi_dma_tvalid),
    .s_axi_tdata(s_axi_dma_tdata),
    .s_axi_tlast(s_axi_dma_tlast),
    .s_axi_tkeep(s_axi_dma_tkeep),
    .s_axi_tstrb(s_axi_dma_tstrb),
    .s_axi_tready(s_axi_dma_tready),
//-------------cdp_fast------------------
    .dma2um_data_wr(dma2um_data_wr),
    .dma2um_data(dma2um_data),
    .dma2um_valid_wr(dma2um_valid_wr),
    .dma2um_valid(dma2um_valid),
    .dma2um_ready(dma2um_ready)
);

pkt_switch pkt_switch (
    .clk(aclk),
    .rst_n(aresetn),
    .sys_um_time(),
//input pkt from cpu 
    .cpu2um_data_wr(dma2um_data_wr),
    .cpu2um_data(dma2um_data),
    .cpu2um_valid_wr(dma2um_valid_wr),
    .cpu2um_valid(dma2um_valid),
    .um2cpu_data_ready(dma2um_ready),
//input pkt from port 
    .port2um_data_wr(cdp2um_data_wr),
    .port2um_data(cdp2um_data),
    .port2um_valid_wr(cdp2um_valid_wr),
    .port2um_valid(cdp2um_valid),
    .um2port_data_ready(cdp2um_ready),
//trans pkt to um
    .pktin_data_wr(pktin_data_wr),
    .pktin_data(pktin_data),
    .pktin_data_valid_wr(pktin_data_valid_wr),
    .pktin_data_valid(pktin_data_valid),
    .pktin_ready(pktin_ready),
	.cin_data_valid(cin_data_valid),
    .cin_data(cin_data),
    .cin_ready(cin_ready)
);

endmodule

/*
module axi2fast(
    .aclk(),
    .aresetn(),
//-------------cdp_axi-------------------
    .s_axi_cdp_tvalid(),
    .s_axi_cdp_tdata(),
    .s_axi_cdp_tlast(),
    .s_axi_cdp_tkeep(),
    .s_axi_cdp_tstrb(),
    .s_axi_cdp_tready(),
//-------------dma_axi--------------------
    .s_axi_dma_tvalid(),
    .s_axi_dma_tdata(),
    .s_axi_dma_tlast(),
    .s_axi_dma_tkeep(),
    .s_axi_dma_tstrb(),
    .s_axi_dma_tready(),
//----------trans pkt to um---------------
    .pktin_data_wr(),
    .pktin_data(),
    .pktin_data_valid_wr(),
    .pktin_data_valid(),
    .pktin_ready()
);
*/








