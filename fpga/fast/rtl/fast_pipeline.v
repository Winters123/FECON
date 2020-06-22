/////////////////////////////////////////////////////////////////
// NUDT.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: NUDT
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: fast_pipeline.v
//Version: 1.0
//Author : (Yang Xiangrui) FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)support FAST pipeline in corundum's port module 
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2020/06/21
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module fast_pipeline #(
    parameter PLATFORM = "Xilinx",
    parameter AXIL_DATA_WIDTH = 32,
    parameter AXIL_ADDR_WIDTH = 16,
    parameter AXIL_STRB_WIDTH = (AXIL_DATA_WIDTH/8),
    parameter PTP_TS_WIDTH = 96
)(
    input  wire         clk,
    input  wire         rst_n,

    //TX side wirte signals
    input  wire [255:0] tx_axis_tdata_int,
    input  wire [31:0]  tx_axis_tkeep_int,
    input  wire         tx_axis_tvalid_int,
    output wire         tx_axis_tready_int,
    input  wire [127:0] tx_axis_tuser_int,
    //RX side read signals
    output wire [255:0] rx_axis_tdata_int,
    output wire [31:0]  rx_axis_tkeep_int,
    output wire         rx_axis_tvalid_int,
    input  wire         rx_axis_tready_int,
    output wire [127:0] rx_axis_tuser_int,
    //TX side read signals
    output wire [255:0] tx_axis_tdata_fast,
    output wire [31:0]  tx_axis_tkeep_fast,
    output wire         tx_axis_tvalid_fast,
    input  wire         tx_axis_tready_fast,
    output wire [127:0] tx_axis_tuser_fast,
    //RX side write signals
    input  wire [255:0] rx_axis_tdata_fast,
    input  wire [31:0]  rx_axis_tkeep_fast,
    input  wire         rx_axis_tvalid_fast,
    output wire         rx_axis_tready_fast,
    input  wire [127:0] rx_axis_tuser_fast,

    //receive timestamp input 
    input  wire [PTP_TS_WIDTH-1:0]              s_axis_tx_ptp_ts_96,
    input  wire                                 s_axis_tx_ptp_ts_valid,
    output wire                                 s_axis_tx_ptp_ts_ready,
    //PTP clock
    input  wire [95:0]                          ptp_ts_96,
    input  wire                                 ptp_ts_step,

    //AXI-Lite slave interface
    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_awaddr,
    input  wire [2:0]                           s_axil_awprot,
    input  wire                                 s_axil_awvalid,
    output wire                                 s_axil_awready,
    input  wire [AXIL_DATA_WIDTH-1:0]           s_axil_wdata,
    input  wire [AXIL_STRB_WIDTH-1:0]           s_axil_wstrb,
    input  wire                                 s_axil_wvalid,
    output wire                                 s_axil_wready,
    output wire [1:0]                           s_axil_bresp,
    output wire                                 s_axil_bvalid,
    input  wire                                 s_axil_bready,
    input  wire [AXIL_ADDR_WIDTH-1:0]           s_axil_araddr,
    input  wire [2:0]                           s_axil_arprot,
    input  wire                                 s_axil_arvalid,
    output wire                                 s_axil_arready,
    output wire [AXIL_DATA_WIDTH-1:0]           s_axil_rdata,
    output wire [1:0]                           s_axil_rresp,
    output wire                                 s_axil_rvalid,
    input  wire                                 s_axil_rready,

);



endmodule
