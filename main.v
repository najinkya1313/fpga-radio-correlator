(* top *)
module radio_correlator (
    (* iopad_external_pin,clkbuf_inhibit *) input clk_in,
    (* iopad_external_pin *) input  ant_a,
    (* iopad_external_pin *) input  ant_b,
    (* iopad_external_pin *) output osc_en,
    (* iopad_external_pin *) output xnor_out,
    (* iopad_external_pin *) output xnor_oe,
    (* iopad_external_pin *) output led,
    (* iopad_external_pin *) output led_en
);

assign xnor_oe  = 1'b1;
assign osc_en   = 1'b1;
assign led_en   = 1'b1;

// ── LED blink: once every ~5 seconds ─────────────────────────────────────
reg [27:0] blink_counter = 0;
always @(posedge clk_in)
    blink_counter <= blink_counter + 1;
assign led = blink_counter[27];

// ── Clock divider: 50MHz → 16.7MHz ───────────────────────────────────────
reg [1:0] clk_div   = 0;
reg       sample_en = 0;
always @(posedge clk_in) begin
    if (clk_div == 2) begin
        clk_div   <= 0;
        sample_en <= 1;
    end else begin
        clk_div   <= clk_div + 1;
        sample_en <= 0;
    end
end

// ── Input DFFs ────────────────────────────────────────────────────────────
reg dff_a, dff_b;
always @(posedge clk_in) begin
    if (sample_en) begin
        dff_a <= ant_a;
        dff_b <= ant_b;
    end
end

// ── XNOR registered output ───────────────────────────────────────────────
reg xnor_reg = 0;
always @(posedge clk_in) begin
    if (sample_en)
        xnor_reg <= ~(dff_a ^ dff_b);
end

assign xnor_out = xnor_reg;

endmodule
