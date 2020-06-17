/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: fast2axi.v
//Version: 1.0
//Author : FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2018/07/17
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module fast2axi(
    input wire          aclk,
    input wire          aresetn,
//-----------------um----------------------
    input wire          pktout_data_wr,
    input wire [133:0]  pktout_data,
    input wire          pktout_data_valid_wr,
    input wire          pktout_data_valid,
    output wire         pktout_ready,
	input wire          cout_data_valid,
	input wire [133:0]  cout_data,
	output wire         cout_ready,
//----------------dma----------------------
    output wire          m_axi_dma_tvalid,
    output wire [127:0]  m_axi_dma_tdata,
    output wire          m_axi_dma_tlast,
    output wire [15:0]   m_axi_dma_tkeep,
    output wire [15:0]   m_axi_dma_tstrb,
    input wire          m_axi_dma_tready,
//---------------cdp-----------------------
    output wire          m_axi_cdp_tvalid,
    output wire [127:0]  m_axi_cdp_tdata,
    output wire          m_axi_cdp_tlast,
    output wire [15:0]   m_axi_cdp_tkeep,
    output wire [15:0]   m_axi_cdp_tstrb,
    input wire          m_axi_cdp_tready
);
//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable
//should be declare below here

wire                dmain_data_wr;
wire [133:0]        dmain_data;
wire                dmain_valid_wr;
wire                dmain_valid;
wire                dmain_ready;

wire                cdpin_data_wr;
wire [133:0]        cdpin_data;
wire                cdpin_valid_wr;
wire                cdpin_valid;
wire                cdpin_ready;







//***************************************************
//                    IP Instance
//***************************************************
fast2dmaaxi fast2dmaaxi_inst(
    .aclk(aclk),
    .aresetn(aresetn),
//-------------fast_um-------------
    .dmain_data_wr(dmain_data_wr),
    .dmain_data(dmain_data),
    .dmain_valid_wr(dmain_valid_wr),
    .dmain_valid(dmain_valid),
    .dmain_ready(dmain_ready),
//-------------axi_stream----------
    .m_axi_tvalid(m_axi_dma_tvalid),
    .m_axi_tdata(m_axi_dma_tdata),
    .m_axi_tlast(m_axi_dma_tlast),
    .m_axi_tkeep(m_axi_dma_tkeep),
    .m_axi_tstrb(m_axi_dma_tstrb),
    .m_axi_tready(m_axi_dma_tready)
);

fast2cdpaxi fast2cdpaxi_inst(
    .aclk(aclk),
    .aresetn(aresetn),
//-------------fast_um-------------
    .cdpin_data_wr(cdpin_data_wr),
    .cdpin_data(cdpin_data),
    .cdpin_valid_wr(cdpin_valid_wr),
    .cdpin_valid(cdpin_valid),
    .cdpin_ready(cdpin_ready),
//-------------axi_stream----------
    .m_axi_tvalid(m_axi_cdp_tvalid),
    .m_axi_tdata(m_axi_cdp_tdata),
    .m_axi_tlast(m_axi_cdp_tlast),
    .m_axi_tkeep(m_axi_cdp_tkeep),
    .m_axi_tstrb(m_axi_cdp_tstrb),
    .m_axi_tready(m_axi_cdp_tready)
);                     

fast2dmacdp fast2dmacdp_inst(
    .clk(aclk),
    .rst_n(aresetn),
 

    .pktout_data_wr(pktout_data_wr),
    .pktout_data(pktout_data),
    .pktout_data_valid_wr(pktout_data_valid_wr),
    .pktout_data_valid(pktout_data_valid),
    .pktout_ready(pktout_ready),
	.cout_data_valid(cout_data_valid),
	.cout_data(cout_data),
	.cout_ready(cout_ready),

    .um2cpu_data_wr(dmain_data_wr),
    .um2cpu_data(dmain_data),
    .um2cpu_valid_wr(dmain_valid_wr),
    .um2cpu_valid(dmain_valid),
    .cpu2um_data_ready(dmain_ready),

    .um2port_data_wr(cdpin_data_wr),
    .um2port_data(cdpin_data),
    .um2port_valid_wr(cdpin_valid_wr),
    .um2port_valid(cdpin_valid),
    .port2um_data_ready(cdpin_ready)
);

endmodule

/*
fast2axi fast2axi(
    .aclk(),
    .aresetn(),
//-----------------um----------------------
    .pktout_data_wr(),
    .pktout_data(),
    .pktout_data_valid_wr(),
    .pktout_data_valid(),
    .pktout_ready(),
//----------------dma----------------------
    .m_axi_dma_tvalid(),
    .m_axi_dma_tdata(),
    .m_axi_dma_tlast(),
    .m_axi_dma_tkeep(),
    .m_axi_dma_tstrb(),
    .m_axi_dma_tready(),
//---------------cdp-----------------------
    .m_axi_cdp_tvalid(),
    .m_axi_cdp_tdata(),
    .m_axi_cdp_tlast(),
    .m_axi_cdp_tkeep(),
    .m_axi_cdp_tstrb(),
    .m_axi_cdp_tready()
);
*/
