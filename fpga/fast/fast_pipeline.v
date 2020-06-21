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
)(
    input  wire         clk,
    input  wire         rst_n,

    //TX side wirte signals
    input  wire [255:0] tx_axis_tdata_int,
    input  wire [31:0]  tx_axis_tkeep_int,
    input  wire         tx_axis_tvalid_int,
    output wire         tx_tready_int,
    input  wire [127:0] tx_axis_tuser_int,
    //RX side read signals
    input  wire [255:0] rx_axis_tdata_int,
    input  wire [31:0]  rx_axis_tkeep_int,
    input  wire         rx_axis_tvalid_int,
    output wire         rx_tready_int,
    input  wire [127:0] rx_axis_tuser_int,
    //TX side read signals
    

);
endmodule
