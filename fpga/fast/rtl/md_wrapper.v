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
    output wire         tx_axis_tvalid_fast,
    input  wire         tx_axis_tready_fast,
    output wire [127:0] tx_axis_tuser_fast,
    
    //RX side write signals
    input  wire [255:0] rx_axis_tdata_fast,
    input  wire [31:0]  rx_axis_tkeep_fast,
    input  wire         rx_axis_tvalid_fast,
    output wire         rx_axis_tready_fast,
    input  wire [127:0] rx_axis_tuser_fast,

    //fast side read signals
    input  wire [255:0] pktout_data,
    input  wire         pktout_data_wr,
    input  wire         pktout_data_valid,
    input  wire [31:0]  tx_axis_tkeep_int_3,
    input  wire [1:0]   tx_axis_tuser_int_3,
    input  wire         pktout_data_valid_wr,
    output wire         pktout_ready,

    //fast side write signals
    output wire [255:0] pktin_data,
    output wire         pktin_data_wr,
    output wire         pktin_data_valid,
    output wire         pktin_data_valid_wr,
    output wire [31:0]  rx_axis_tkeep_int_3,
    output wire [1:0]   rx_axis_tuser_int_3,
    input  wire         pktin_ready
);

//TX path
assign tx_axis_tdata_fast = pktout_data_valid;
assign tx_axis_tkeep_fast = tx_axis_tkeep_int_3;
assign tx_axis_tvalid_fast = pktout_data_valid;
assign tx_axis_tuser_fast = tx_axis_tuser_int_3;
assign pktout_ready = tx_axis_tready_fast;

//RX path
assign pktin_data = rx_axis_tdata_fast;
assign pktin_data_valid = rx_axis_tvalid_fast;
assign pktin_data_valid_wr = rx_axis_tvalid_fast;
assign pktin_data_wr = rx_axis_tvalid_fast;
assign rx_axis_tready_fast = pktin_ready;
assign rx_axis_tkeep_int_3 = rx_axis_tkeep_fast;
assign rx_axis_tuser_int_3 = rx_axis_tuser_fast;

endmodule