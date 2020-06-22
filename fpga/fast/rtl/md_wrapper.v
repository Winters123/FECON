/////////////////////////////////////////////////////////////////
// NUDT.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: NUDT
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: md_wrapper.v
//Version: 1.0
//Author : (Yang Xiangrui) FAST Group
//*************************************************************
//                     Module Description
//*************************************************************
// 1)support wrapper between AXIS and FAST UM
//*************************************************************
//                     Revision List
//*************************************************************
//	rn1: 
//      date:  2020/06/22
//      modifier: 
//      description: 
///////////////////////////////////////////////////////////////// 
module md_wrapper #(
    parameter PLATFORM = "Xilinx"
)(
    input  wire clk,
    input  wire rst_n,

    //TX side read signals
    output wire [255:0] tx_axis_tdata_fast,
    output wire [31:0]  tx_axis_tkeep_fast,
    output wire         tx_axis_tvalid_fast_out,
    input  wire         tx_axis_tready_fast,
    output wire [127:0] tx_axis_tuser_fast,
    
    //RX side write signals
    input  wire [255:0] rx_axis_tdata_int,
    input  wire [31:0]  rx_axis_tkeep_int,
    input  wire         rx_axis_tvalid_int,
    output wire         rx_axis_tready_int,
    input  wire [127:0] rx_axis_tuser_int,

    //fast side read signals
    input  wire [255:0] pktout_data,
    input  wire         pktout_data_wr,
    input  wire         pktout_data_valid,
    input  wire [31:0]  tx_axis_tkeep_fast_in,
    input  wire         pktout_data_valid_wr,
    output wire         pktin_ready,

    //fast side write signals
    output wire [255:0] pktin_data,
    output wire         pktin_data_wr,
    output wire         pktin_data_valid,
    output wire         pktin_data_valid_wr,
    output wire [31:0]  rx_axis_tkeep_fast_out,
    input  wire         pktin_ready
    
);

endmodule