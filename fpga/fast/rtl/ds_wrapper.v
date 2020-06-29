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
    input  wire [31:0]  tx_axis_tkeep_int,
    input  wire         tx_axis_tvalid_int,
    output wire         tx_axis_tready_int,
    input  wire         tx_axis_tuser_int,


    //fast side write signals
    output wire [255:0] pktin_data,
    output wire         pktin_data_wr,
    output wire         pktin_data_valid,
    output wire [31:0]  tx_axis_tkeep_int_2,
    output wire [1:0]   tx_axis_tuser_int_2,
    output wire         pktin_data_valid_wr,

    input  wire         pktin_ready,


    //RX side read signals
    output wire [255:0] rx_axis_tdata_int,
    output wire [31:0]  rx_axis_tkeep_int,
    output wire         rx_axis_tvalid_int,
    input  wire         rx_axis_tready_int,
    output wire         rx_axis_tuser_int,

    //fast side read signals
    input  wire [255:0] pktout_data,
    input  wire         pktout_data_wr,
    input  wire         pktout_data_valid,
    input  wire         pktout_data_valid_wr,
    input  wire [31:0]  rx_axis_tkeep_int_2,
    input  wire [1:0]   rx_axis_tuser_int_2,
    output wire         pktout_ready
);

//intermidiate variables
//1st delay signals;
reg [255:0] pktin_data_reg;
reg         pktin_data_wr_reg;
reg         pktin_data_valid_reg;
reg [31:0]  tx_axis_tkeep_int_2_reg;
reg [1:0]   tx_axis_tuser_int_2_reg;
reg         pktin_data_valid_wr_reg;

//2nd delay singals;
reg [255:0] pktin_data_reg_dly;
reg         pktin_data_wr_reg_dly;
reg         pktin_data_valid_reg_dly;
reg [31:0]  tx_axis_tkeep_int_2_reg_dly;
reg [1:0]   tx_axis_tuser_int_2_reg_dly;
reg         pktin_data_valid_wr_reg_dly;

//make the delay signals work
always @(posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        pktin_data_reg <= 256'b0;
        pktin_data_wr_reg <= 1'b0;
        pktin_data_valid_reg <= 1'b0;
        tx_axis_tkeep_int_2_reg <= 32'b0;
        tx_axis_tuser_int_2_reg <= 1'b0;
        pktin_data_valid_wr_reg <= 1'b0;
    end

    else begin
        //1st round delay feeds
        pktin_data_reg <= tx_axis_tdata_int;
        pktin_data_wr_reg <= tx_axis_tvalid_int;
        pktin_data_valid_reg <= tx_axis_tvalid_int;
        tx_axis_tkeep_int_2_reg <= tx_axis_tkeep_int;
        //tx_axis_tuser_int_2_reg <= tx_axis_tuser_int;
        pktin_data_valid_wr_reg <= tx_axis_tvalid_int;

        //2nd round delay feeds
        pktin_data_reg_dly <= pktin_data_reg;
        pktin_data_wr_reg_dly <= pktin_data_wr_reg;
        pktin_data_valid_reg_dly <= pktin_data_valid_reg;
        tx_axis_tkeep_int_2_reg_dly <= tx_axis_tkeep_int_2_reg;
        //tx_axis_tuser_int_2_reg_dly <= tx_axis_tuser_int_2_reg;
        pktin_data_valid_wr_reg_dly <= pktin_data_valid_wr_reg;
    end
end

//RX path
assign rx_axis_tdata_int = pktout_data;
assign rx_axis_tkeep_int = rx_axis_tkeep_int_2;
//change the tuser back to orignal corundum design to assure DMA works correctly.
assign rx_axis_tuser_int = 1'b0;
assign rx_axis_tvalid_int = pktout_data_valid;
assign pktout_ready = rx_axis_tready_int;

//TX path
assign pktin_data = pktin_data_reg_dly;
assign pktin_data_wr = pktin_data_wr_reg_dly;
//TODO some tricks going to play on tx_axis_tuser_int;
assign tx_axis_tuser_int_2 = tx_axis_tkeep_int_2_reg_dly;
assign tx_axis_tkeep_int_2 = tx_axis_tkeep_int_2_reg_dly;
assign tx_axis_tready_int = pktin_ready;

//make sure valid and valid_wr only active at the frame tail.
always @* begin
    pktin_data_valid_wr = (tx_axis_tkeep_int_2_reg_dly == 2'b10)? 1'b1:1'b0;
    pktin_data_valid = (tx_axis_tkeep_int_2_reg_dly == 2'b10)? 1'b1:1'b0;
end

always @(posedge clk or negedge rst_n) begin
    //change the tx_axis_tuser value
    if(rst_n == 1'b0) begin
        tx_axis_tuser_int_reg <= 2'b0;
        tx_axis_tuser_int_reg_dly <= 2'b0;
    end

    //frame head
    else if(tx_axis_tvalid_int == 1'b1 && pktin_data_valid_reg == 1'b0) begin
        tx_axis_tuser_int_2_reg_dly <= 2'b01;
    end
    //frame body
    else if(tx_axis_tvalid_int == 1'b1 && pktin_data_valid_reg == 1'b1) begin
        tx_axis_tuser_int_2_reg_dly <= 2'b11;
    end
    //frame tail
    else if(tx_axis_tvalid_int == 1'b0 && pktin_data_valid_reg == 1'b1) begin
        tx_axis_tuser_int_2_reg_dly <= 2'b10;
    end
    //empty
    else begin
        tx_axis_tuser_int_2_reg_dly <= 2'b00;
    end
end


endmodule