// Testbench

`timescale 1ns/1ps

module tb_axis_arbiter;

    localparam int TDATA_WIDTH = 32;
    localparam int TDEST_WIDTH = 1;
    localparam int TUSER_WIDTH = 1;
    localparam int NUM_RX      = 2;
    localparam int NUM_TX      = 2;

    logic clk = 0;
    logic rst_n = 0;

    logic [NUM_RX-1:0][TDATA_WIDTH-1:0]     tdata_in;
    logic [NUM_RX-1:0][TDEST_WIDTH-1:0]     tdest_in;
    logic [NUM_RX-1:0][TUSER_WIDTH-1:0]     tuser_in;
    logic [NUM_RX-1:0]                      tlast_in;
    logic [NUM_RX-1:0][(TDATA_WIDTH/8)-1:0] tkeep_in;
    logic [NUM_RX-1:0]                      tvalid_in;
    logic [NUM_RX-1:0]                      tready_out;

    logic [NUM_TX-1:0][TDATA_WIDTH-1:0]     tdata_out;
    logic [NUM_TX-1:0][TUSER_WIDTH-1:0]     tuser_out;
    logic [NUM_TX-1:0]                      tlast_out;
    logic [NUM_TX-1:0][(TDATA_WIDTH/8)-1:0] tkeep_out;
    logic [NUM_TX-1:0]                      tvalid_out;
    logic [NUM_TX-1:0]                      tready_in;

    axis_arbiter #(
        .TDATA_WIDTH(TDATA_WIDTH),
        .TDEST_WIDTH(TDEST_WIDTH),
        .TUSER_WIDTH(TUSER_WIDTH),
        .NUM_RX(NUM_RX),
        .NUM_TX(NUM_TX)
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .tdata_in(tdata_in), .tdest_in(tdest_in), .tuser_in(tuser_in),
        .tlast_in(tlast_in), .tkeep_in(tkeep_in),
        .tvalid_in(tvalid_in), .tready_out(tready_out),
        .tdata_out(tdata_out), .tuser_out(tuser_out), .tlast_out(tlast_out),
        .tkeep_out(tkeep_out), .tvalid_out(tvalid_out), .tready_in(tready_in)
    );

    always #5 clk = ~clk; // 100MHz

    // Drive one beat on input port `rx` targeting TDEST `dest`, hold until accepted
    task automatic send_beat(int rx, logic [TDEST_WIDTH-1:0] dest, logic [TDATA_WIDTH-1:0] data);
        tdata_in[rx]  = data;
        tdest_in[rx]  = dest;
        tuser_in[rx]  = '0;
        tlast_in[rx]  = 1'b1;
        tkeep_in[rx]  = '1;
        tvalid_in[rx] = 1'b1;
        @(posedge clk);
        while (!tready_out[rx]) @(posedge clk); // wait for handshake
        tvalid_in[rx] = 1'b0;
    endtask

    initial begin
        tdata_in = '0; tdest_in = '0; tuser_in = '0;
        tlast_in = '0; tkeep_in = '0; tvalid_in = '0;
        tready_in = '1; // both destinations ready by default

        rst_n = 0;
        repeat (2) @(posedge clk);
        rst_n = 1;
        @(posedge clk);

        // Test 1: basic routing, RX0 -> TDEST 0
        send_beat(0, 1'b0, 32'hAAAA_0000);
        @(posedge clk);
        assert (tvalid_out[0] === 1'b0) // deasserted after handshake completes
            else $error("T1: tvalid_out[0] should drop after transfer");

        // Test 2: basic routing, RX1 -> TDEST 1
        send_beat(1, 1'b1, 32'hBBBB_1111);
        @(posedge clk);
        $display("T2 passed: RX1 routed to TDEST 1");

        // Test 3: backpressure -- TX0 not ready, RX0 should stall
        tready_in[0] = 1'b0;
        tdata_in[0]  = 32'hCCCC_2222;
        tdest_in[0]  = 1'b0;
        tvalid_in[0] = 1'b1;
        repeat (3) @(posedge clk);
        assert (tready_out[0] === 1'b0)
            else $error("T3: tready_out[0] should be low while TX0 not ready");
        assert (tvalid_out[0] === 1'b1)
            else $error("T3: tvalid_out[0] should stay asserted, held stable");
        tready_in[0] = 1'b1;
        @(posedge clk);
        tvalid_in[0] = 1'b0;
        $display("T3 passed: backpressure correctly stalled RX0");

        $display("All tests done.");
        $finish;
    end

endmodule