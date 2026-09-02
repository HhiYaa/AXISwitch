module axis_arbiter #(
    parameter int TDATA_WIDTH = 32,   
    parameter int TDEST_WIDTH = 1,    
    parameter int TUSER_WIDTH = 1,    
    parameter int NUM_RX      = 2,    
    parameter int NUM_TX      = 2     

    // TODO: replace TDEST -> output-port lookup table once it's defined.
) (
    input  logic                                   clk,
    input  logic                                   rst_n,

    // RX side (inputs into the arbiter)
    input  logic [NUM_RX-1:0][TDATA_WIDTH-1:0]      tdata_in,
    input  logic [NUM_RX-1:0][TDEST_WIDTH-1:0]      tdest_in,
    input  logic [NUM_RX-1:0][TUSER_WIDTH-1:0]      tuser_in,
    input  logic [NUM_RX-1:0]                       tlast_in,   
    input  logic [NUM_RX-1:0][(TDATA_WIDTH/8)-1:0]  tkeep_in,   
    input  logic [NUM_RX-1:0]                       tvalid_in,
    output logic [NUM_RX-1:0]                       tready_out, 

    // TX side (outputs from the arbiter)
    output logic [NUM_TX-1:0][TDATA_WIDTH-1:0]      tdata_out,
    output logic [NUM_TX-1:0][TUSER_WIDTH-1:0]      tuser_out,
    output logic [NUM_TX-1:0]                       tlast_out,
    output logic [NUM_TX-1:0][(TDATA_WIDTH/8)-1:0]  tkeep_out,
    output logic [NUM_TX-1:0]                       tvalid_out,
    input  logic [NUM_TX-1:0]                       tready_in   // ready coming back from each TX destination
);


    // TDEST -> output port index lookup table
    // TODO - replace tdest_table lookup table - paramametric 
    localparam int NUM_DEST_ENTRIES = (1 << TDEST_WIDTH);
    logic [$clog2(NUM_TX)-1:0] tdest_table [NUM_DEST_ENTRIES];

    initial begin
        for (int idx = 0; idx < NUM_DEST_ENTRIES; idx++) begin
            tdest_table[idx] = idx % NUM_TX; // placeholder - replace with real mapping
        end
    end


    // Per-input decode: which output port does this input want? - TODO - double check
    logic [NUM_RX-1:0][$clog2(NUM_TX)-1:0] dest_idx;

    genvar gi;
    generate
        for (gi = 0; gi < NUM_RX; gi++) begin : g_decode
            assign dest_idx[gi] = tdest_table[tdest_in[gi]];
        end
    endgenerate


    // Output muxing: only one master in the system, so at most one input
    // targets a given output at a time - no arbitration needed.
    genvar go;
    generate
        for (go = 0; go < NUM_TX; go++) begin : g_output_mux
            always_comb begin
                tvalid_out[go] = 1'b0;
                tdata_out[go]  = '0;
                tuser_out[go]  = '0;
                tlast_out[go]  = 1'b0;
                tkeep_out[go]  = '0;

                for (int ri = 0; ri < NUM_RX; ri++) begin
                    if (tvalid_in[ri] && (dest_idx[ri] == go)) begin
                        tvalid_out[go] = tvalid_in[ri];
                        tdata_out[go]  = tdata_in[ri];
                        tuser_out[go]  = tuser_in[ri];
                        tlast_out[go]  = tlast_in[ri];
                        tkeep_out[go]  = tkeep_in[ri];
                    end
                end
            end
        end
    endgenerate


    // each input's tready comes from whichever output it targets
    genvar gk;
    generate
        for (gk = 0; gk < NUM_RX; gk++) begin : g_ready_fanback
            assign tready_out[gk] = tready_in[dest_idx[gk]];
        end
    endgenerate

endmodule