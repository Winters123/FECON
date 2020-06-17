////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2016-2020 C2comm, Inc.  All rights reserved.
////////////////////////////////////////////////////////////////////////////////
//Vendor: China Chip Communication Co.Ltd in Hunan Changsha 
//Version: 0.1
//Filename: dma&cdp2fast.v
//Target Device: xilinx
//Dscription: 
//  1)receive and restore 2 stream, select 1 stream send to UM module
//  2)
//  3)
//
//      
//
// 
//  
//Author : 
//Revision List:
//	rn1: 
//      date: 
//      modifier: 
//      description: 
module pkt_switch (
    input clk,
    input rst_n,
    input [63:0] sys_um_time,
//input pkt from cpu 
    input cpu2um_data_wr,
    input [133:0] cpu2um_data,
    input cpu2um_valid_wr,
    input cpu2um_valid,
    output um2cpu_data_ready,
//input pkt from port 
    input port2um_data_wr,
    input [133:0] port2um_data,
    input port2um_valid_wr,
    input port2um_valid,
    output um2port_data_ready,
//trans pkt to um
    output reg pktin_data_wr,
    output reg [133:0] pktin_data,
    output reg pktin_data_valid_wr,
    output pktin_data_valid,
    input  pktin_ready,
	
	output reg cin_data_valid,
    output reg [133:0] cin_data,
    input  cin_ready
);
 //***************************************************
//        Intermediate variable Declaration
//****************************************************
//all wire/reg/parameter variable
//should be declare below here
reg up_dfifo_rd;
wire [133:0] up_dfifo_rdata;
wire [8:0] up_dfifo_usedw;

reg up_vfifo_rd;
wire up_vfifo_rdata;
wire up_vfifo_empty;

reg port_dfifo_rd;
wire [133:0] port_dfifo_rdata;
wire [8:0] port_dfifo_usedw;

reg port_vfifo_rd;
wire port_vfifo_rdata;
wire port_vfifo_empty;

reg last_select;//which direction last pkt select
// 0:send up cpu's pkt   1: send port  's pkt
reg grant_bit;//current pkt direction selecct
reg has_pkt;
reg [1:0] switch_state;
//***************************************************
//                 Stream Judge
//***************************************************

always @ * begin
    case({up_vfifo_empty,port_vfifo_empty})
        2'b00: begin has_pkt = 1'b1; grant_bit = ~last_select; end//both direction have pkt,so select different with last
        2'b01: begin has_pkt = 1'b1; grant_bit = 1'b1; end//just up cpu have pkt need to sending 
        2'b10: begin has_pkt = 1'b1; grant_bit = 1'b0; end//just port have pkt need to sending
        2'b11: begin has_pkt = 1'b0; grant_bit = last_select; end//both no pkt,hold last select
    endcase
end

//*****************************************************
//                Pkt Switch
//*****************************************************
assign um2cpu_data_ready = ~up_dfifo_usedw[7];
assign um2port_data_ready = ~port_dfifo_usedw[7];

assign pktin_data_valid = pktin_data_valid_wr;

localparam  IDLE_S = 2'd0,
            SEND_EXE_S = 2'd1,
            SEND_UP_S = 2'd2, 
            SEND_UP_CMD=2'd3;
always @(posedge clk or negedge rst_n) begin 
    if(rst_n == 1'b0) begin 
        last_select <= 1'b0;
        
        pktin_data_wr <= 1'b0;
        pktin_data_valid_wr <= 1'b0;
        
        up_dfifo_rd <= 1'b0;
        up_vfifo_rd <= 1'b0;
        port_dfifo_rd <= 1'b0;
        port_vfifo_rd <= 1'b0;
        cin_data_valid<=1'b0; 
        switch_state <= IDLE_S;
    end
    else begin
        case(switch_state)
            IDLE_S:begin 
                pktin_data_wr <= 1'b0;
                   pktin_data_valid_wr <= 1'b0;
                   
                   up_dfifo_rd <= 1'b0;
                   up_vfifo_rd <= 1'b0;
                   port_dfifo_rd <= 1'b0;
                   port_vfifo_rd <= 1'b0;
                   cin_data_valid<=1'b0;      
                if((pktin_ready == 1'b1) && (has_pkt == 1'b1)) begin 
                    //there is at least a pkt ,& next module can receive a pkt   
                    last_select <= grant_bit;
                    if(grant_bit == 1'b1) begin //send up cpu's pkt&&cin_ready
					    if(cin_ready==1'b1&&up_dfifo_rdata[127]==1'b1)begin
							up_dfifo_rd <= 1'b1;
                            up_vfifo_rd <= 1'b1;
						    switch_state <= SEND_UP_CMD;
						end 
						else if(up_dfifo_rdata[127]==1'b0)begin
                            up_dfifo_rd <= 1'b1;
                            up_vfifo_rd <= 1'b1;
                            port_dfifo_rd <= 1'b0;
                            port_vfifo_rd <= 1'b0;
                            switch_state <= SEND_UP_S;
						end
						else begin
						    up_dfifo_rd <= 1'b0;
                            up_vfifo_rd <= 1'b0;
                            port_dfifo_rd <= 1'b0;
                            port_vfifo_rd <= 1'b0;
                            switch_state <= IDLE_S;
						end
                    end
                    else begin 
                        up_dfifo_rd <= 1'b0;
                        up_vfifo_rd <= 1'b0;
                        port_dfifo_rd <= 1'b1;
                        port_vfifo_rd <= 1'b1;
                        switch_state <= SEND_EXE_S;
                    end
                end
                else begin
                    up_dfifo_rd <= 1'b0;
                    up_vfifo_rd <= 1'b0;
                    port_dfifo_rd <= 1'b0;
                    port_vfifo_rd <= 1'b0;
                    switch_state <= IDLE_S;
                end
            end

            SEND_UP_S:begin 
                up_vfifo_rd <= 1'b0;
                pktin_data_wr <= 1'b1;
                pktin_data <= up_dfifo_rdata;
                //pktin_data <= up_dfifo_rdata
				if(up_dfifo_rdata[133:132] == 2'b01)begin//start of pkt
				     pktin_data[127] <= up_dfifo_rdata[49];				
				end
				else if(up_dfifo_rdata[133:132] == 2'b10)begin//end of pkt
                    up_dfifo_rd <= 1'b0;
                    pktin_data_valid_wr <= 1'b1;
                    switch_state <= IDLE_S;
                end
                else begin
                    up_dfifo_rd <= 1'b1;
                    pktin_data_valid_wr <= 1'b0;
                    switch_state <= SEND_UP_S;
                end
            end
            
            SEND_EXE_S: begin
                port_vfifo_rd <= 1'b0;
                pktin_data_wr <= 1'b1;
                pktin_data <= port_dfifo_rdata;
                if(port_dfifo_rdata[133:132] == 2'b10)begin//end of pkt
                    port_dfifo_rd <= 1'b0;
                    pktin_data_valid_wr <= 1'b1;
                    switch_state <= IDLE_S;
                end
                else begin 
                    port_dfifo_rd <= 1'b1;
                    pktin_data_valid_wr <= 1'b0;
                    switch_state <= SEND_EXE_S;
                end
            end
			SEND_UP_CMD:begin
			     up_vfifo_rd <= 1'b0;
				if(up_dfifo_rdata[133:132] == 2'b01)begin//start of pkt
				    cin_data_valid<=1'b1;
                    cin_data[133:128]<=up_dfifo_rdata[133:128];
                    cin_data[127]<=1'b1;
					cin_data[126:0]<=up_dfifo_rdata[126:0];
					up_dfifo_rd <= 1'b1;
					switch_state <= SEND_UP_CMD;
				end
				else if(up_dfifo_rdata[133:132] == 2'b10)begin//end of pkt
				    cin_data_valid<=1'b1;
                    cin_data<=up_dfifo_rdata;
					up_dfifo_rd <= 1'b0;	
                    switch_state <= IDLE_S;					
				end
				else begin
				    cin_data_valid<=1'b1;
                    cin_data<=up_dfifo_rdata;
					up_dfifo_rd <= 1'b1;
					switch_state <= SEND_UP_CMD;
				end
			end
            default:begin
                last_select <= 1'b0;
                
                pktin_data_wr <= 1'b0;
                pktin_data_valid_wr <= 1'b0;
                
                up_dfifo_rd <= 1'b0;
                up_vfifo_rd <= 1'b0;
                port_dfifo_rd <= 1'b0;
                port_vfifo_rd <= 1'b0;
                
                switch_state <= IDLE_S;
            end
        endcase
    end
end    

//***************************************************
//                    IP Instance
//***************************************************
sync_fifo_w134_d256_dfifo dfifo_cdp(  
    .clk(clk),
    .srst(~rst_n),
    .wr_en(port2um_data_wr),
    .din(port2um_data),
    .rd_en(port_dfifo_rd),
    .dout(port_dfifo_rdata),
    .full(),
    .empty(),
    .data_count(port_dfifo_usedw)
);

sync_fifo_w1_d64_sfifo sfifo_cdp(  
    .clk(clk),
    .srst(~rst_n),
    .wr_en(port2um_valid_wr),
    .din(port2um_valid),
    .rd_en(port_vfifo_rd),
    .dout(port_vfifo_rdata),   
    .full(),
    .empty(port_vfifo_empty)
);

sync_fifo_w134_d256_dfifo dfifo_dma(  
    .clk(clk),
    .srst(~rst_n),
    .wr_en(cpu2um_data_wr),
    .din(cpu2um_data),
    .rd_en(up_dfifo_rd),
    .dout(up_dfifo_rdata),
    .full(),
    .empty(),
    .data_count(up_dfifo_usedw)
);

sync_fifo_w1_d64_sfifo sfifo_dma(  
    .clk(clk),
    .srst(~rst_n),
    .wr_en(cpu2um_valid_wr),
    .din(cpu2um_valid),
    .rd_en(up_vfifo_rd),
    .dout(up_vfifo_rdata),   
    .full(),
    .empty(up_vfifo_empty)
);

endmodule

/*
pkt_switch pkt_switch (
    .clk(),
    .rst_n(),
    .sys_um_time(),
//input pkt from cpu 
    .cpu2um_data_wr(),
    .cpu2um_data(),
    .cpu2um_valid_wr(),
    .cpu2um_valid(),
    .um2cpu_data_alful(),
//input pkt from port 
    .port2um_data_wr(),
    .port2um_data(),
    .port2um_valid_wr(),
    .port2um_valid(),
    .um2port_data_alful(),
//trans pkt to um
    .pktin_data_wr(),
    .pktin_data(),
    .pktin_data_valid_wr(),
    .pktin_data_valid(),
    .pktin_ready()
);
*/

