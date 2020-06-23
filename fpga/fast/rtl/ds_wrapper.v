/////////////////////////////////////////////////////////////////
// NUDT.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: NUDT
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: ds_wrapper.v
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
module ds_wrapper #(
    parameter PLATFORM = "Xilinx"
)(
    input  wire clk,
    input  wire rst_n,

    //TX side write signals
    input  wire [255:0] tx_axis_tdata_int,
    input  wire [31:0]  tx_axis_tkeep_int_in,
    input  wire         tx_axis_tvalid_int,
    output wire         tx_axis_tready_int,
    input  wire [127:0] tx_axis_tuser_int,

    //RX side read signals
    output wire [255:0] rx_axis_tdata_int,
    output wire [31:0]  rx_axis_tkeep_int_out,
    output wire         rx_axis_tvalid_int,
    input  wire         rx_axis_tready_int,
    output wire [127:0] rx_axis_tuser_int,

    //fast side write signals
    output wire [255:0] pktin_data,
    output wire         pktin_data_wr,
    output wire         pktin_data_valid,
    output wire [31:0]  tx_axis_tkeep_int_out,
    output wire         pktin_data_valid_wr,

    input  wire         pktin_ready,

    //fast side read signals
    input  wire [255:0] pktout_data,
    input  wire         pktout_data_wr,
    input  wire         pktout_data_valid,
    input  wire         pktout_data_valid_wr,
    input  wire [31:0]  rx_axis_tkeep_int_in,
    output wire         pktout_ready
);

//except tkeep, and fast_valid_wr, we can just wrap everything else.
//TX path
assign pktin_data = tx_axis_tdata_int;
assign pktin_data_wr = tx_axis_tvalid_int;
assign pktin_data_valid = tx_axis_tvalid_int;
assign tx_axis_tkeep_int_out = tx_axis_tkeep_int_in;
assign pktin_data_valid_wr = tx_axis_tvalid_int;
assign tx_axis_tready_int = pktin_ready;

//MD is a bit of tricky here


endmodule