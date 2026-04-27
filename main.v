(* top *)
module radio_correlator (
(* iopad_external_pin,clkbuf_inhibit *) input clk_in,
(* iopad_external_pin *) input ant_a,
(* iopad_external_pin *) input ant_b,
(* iopad_external_pin *) output osc_en,
(* iopad_external_pin *) output corr_0,
(* iopad_external_pin *) output corr_1,
(* iopad_external_pin *) output corr_2,
(* iopad_external_pin *) output corr_3,
(* iopad_external_pin *) output corr_4,
(* iopad_external_pin *) output corr_5,
(* iopad_external_pin *) output corr_0_oe,
(* iopad_external_pin *) output corr_1_oe,
(* iopad_external_pin *) output corr_2_oe,
(* iopad_external_pin *) output corr_3_oe,
(* iopad_external_pin *) output corr_4_oe,
(* iopad_external_pin *) output corr_5_oe,
(* iopad_external_pin *) output latch_out,
(* iopad_external_pin *) output latch_oe,
(* iopad_external_pin *) output led,
(* iopad_external_pin *) output led_en
);

localparam integer WINDOW_BITS = 16;   
localparam integer ACC_BITS    = 17;   

// ── LED blink ─────────────────────────────────────────────────────────────
reg [24:0] blink_counter = 0;
always @(posedge clk_in)
    blink_counter <= blink_counter + 1;
assign led    = blink_counter[24];
assign led_en = 1'b1;

// ── Input DFFs ────────────────────────────────────────────────────────────
reg dff_a, dff_b;
always @(posedge clk_in) begin
    dff_a <= ant_a;
    dff_b <= ant_b;
end

wire xnor_out;
assign xnor_out = ~(dff_a ^ dff_b);

reg [ACC_BITS-1:0]    accumulator  = 0;
reg [WINDOW_BITS-1:0] sample_count = 0;
reg [5:0]             corr_latch   = 0;
reg                   latch_flag   = 0;

always @(posedge clk_in) begin
    if (sample_count == {WINDOW_BITS{1'b1}}) begin
        corr_latch   <= accumulator[WINDOW_BITS-1 : WINDOW_BITS-6];
        latch_flag   <= ~latch_flag;
        accumulator  <= {{(ACC_BITS-1){1'b0}}, xnor_out};
        sample_count <= 0;
    end else begin
        accumulator  <= accumulator + {{(ACC_BITS-1){1'b0}}, xnor_out};
        sample_count <= sample_count + 1;
    end
end

assign {corr_5, corr_4, corr_3, corr_2, corr_1, corr_0} = corr_latch;
assign latch_out = latch_flag;
assign osc_en    = 1'b1;
assign corr_0_oe = 1'b1;
assign corr_1_oe = 1'b1;
assign corr_2_oe = 1'b1;
assign corr_3_oe = 1'b1;
assign corr_4_oe = 1'b1;
assign corr_5_oe = 1'b1;
assign latch_oe  = 1'b1;

endmodule
