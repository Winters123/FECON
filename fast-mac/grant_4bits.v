/////////////////////////////////////////////////////////////////
// Copyright (c) 2018-2025 Xperis, Inc.  All rights reserved.
//*************************************************************
//                     Basic Information
//*************************************************************
//Vendor: Hunan Xperis Network Technology Co.,Ltd.
//Xperis URL://www.xperis.com.cn
//FAST URL://www.fastswitch.org 
//Target Device: Xilinx
//Filename: grant_4bits.v
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
module grant_4bits(
    input clk,
    input rst_n,
    
    input get,
    input [3:0] req_bits,
    output reg [3:0] grant_bits
);

//***************************************************
//        Intermediate variable Declaration
//***************************************************
//all wire/reg/parameter variable 
//should be declare below here 
reg [3:0] grant_record;//record all bit have been alloc before
reg [3:0] promise_grant;
wire [3:0] grant_mask;

reg [3:0] grant_branch0 , grant_branch1;
//***************************************************
//                 Grant Process
//***************************************************
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        grant_record <= 4'b0;
    end
    else begin
        if(get == 1'b1) begin//grant have been get to use
            if((&grant_record) == 1'b1) begin//have been sweep all bits
                grant_record <= grant_bits;
            end
            else begin
                grant_record <= grant_record | grant_bits;//record last grant
            end
        end
        else begin
            grant_record <= grant_record;
        end
    end
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        promise_grant <= 4'b0;
    end
    else begin
        if(get == 1'b1) begin//grant have been get to use
            promise_grant <= {grant_bits[2:0],grant_bits[3]};
        end
        else begin
            promise_grant <= promise_grant;
        end
    end
end

assign grant_mask = ~grant_record;

always @* begin//grant branch(promise)
    if((promise_grant & req_bits) != 4'b0) begin//promise req is valid
        grant_branch0 = promise_grant;
    end
    else begin
        casez(grant_mask & req_bits)
            4'b???1: grant_branch0 = 4'b0001;
            4'b??10: grant_branch0 = 4'b0010;
            4'b?100: grant_branch0 = 4'b0100;
            4'b1000: grant_branch0 = 4'b1000;
            default: grant_branch0 = 4'b0000;
        endcase
    end
end

always @* begin//grant branch(no match promise)
    casez(req_bits)
        4'b???1: grant_branch1 = 4'b0001;
        4'b??10: grant_branch1 = 4'b0010;
        4'b?100: grant_branch1 = 4'b0100;
        4'b1000: grant_branch1 = 4'b1000;
        default: grant_branch1 = 4'b0000;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        grant_bits <= 4'b0;
    end 
    else begin
        grant_bits <= (grant_branch0 != 4'b0) ? grant_branch0 : 
                      (grant_branch1 != 4'b0) ? grant_branch1 : 4'b0;
    end
end
//assign grant_bits = (grant_branch0 != 4'b0) ? grant_branch0 : 
//                    (grant_branch1 != 4'b0) ? grant_branch1 : 4'b0;


endmodule