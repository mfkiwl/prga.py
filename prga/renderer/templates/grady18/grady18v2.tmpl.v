// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module grady18v2 (
    // user accessible ports
    input wire [0:0] clk
    , input wire [0:0] ce
    , input wire [7:0] in
    , output reg [1:0] out
    , input wire [0:0] cin
    , output reg [0:0] cout

    , input wire [0:0] prog_done
    , input wire [75:0] prog_data
        // prog_data[ 0 +: 38] BLE5A
        //          [ 0 +: 16] LUT4A
        //          [16 +: 16] LUT4B
        //          [32 +:  2] Adder CIN_MODE 
        //          [34 +:  2] Mode select: disabled, arith, LUT5, LUT6
        //          [36 +:  1] FF disable (FF enabled by default)
        //          [37 +:  1] FF ENABLE_CE
        // prog_data[38 +: 38] BLE5B
    );

    // -- Parameters ---------------------------------------------------------
    localparam LUT4_DATA_WIDTH      = 16;
    localparam ADDER_MODE_WIDTH     = 2;
    localparam BLE5_MODE_WIDTH      = 2;

    // adder carry-in modes
    localparam ADDER_MODE_CONST0    = 2'b00;
    localparam ADDER_MODE_CONST1    = 2'b01;
    localparam ADDER_MODE_CHAIN     = 2'b10;
    localparam ADDER_MODE_FABRIC    = 2'b11;

    // BLE5 modes
    localparam BLE5_MODE_DISABLED   = 2'b00;
    localparam BLE5_MODE_ARITH      = 2'b01;
    localparam BLE5_MODE_LUT5       = 2'b10;
    localparam BLE5_MODE_LUT6       = 2'b11;    // BLE5A and BLE5B behave differently in this mode

    // prog_data indexing: BLE5
    localparam LUT4A_DATA           = 0;
    localparam LUT4B_DATA           = LUT4A_DATA + LUT4_DATA_WIDTH;
    localparam ADDER_MODE           = LUT4B_DATA + LUT4_DATA_WIDTH;
    localparam BLE5_MODE            = ADDER_MODE + ADDER_MODE_WIDTH;
    localparam FF_DISABLE           = BLE5_MODE + BLE5_MODE_WIDTH;
    localparam FF_ENABLE_CE         = FF_DISABLE + 1;
    localparam BLE5_DATA_WIDTH      = FF_ENABLE_CE + 1;

    // prog_data indexing: FLE8
    localparam BLE5A_DATA           = 0;
    localparam BLE5B_DATA           = BLE5A_DATA + BLE5_DATA_WIDTH;

    // -- Internal Signals ---------------------------------------------------
    reg [1:0] internal_cin;
    reg [1:0] internal_lut4 [1:0];  // !! BLE5A.LUT4A=[0][0], BLE5A.LUT4B=[1][0], BLE5B.LUT4A=[0][1], BLE5B.LUT4B=[1][1]
    reg [1:0] internal_lut5;
    reg       internal_lut6;
    wire [1:0] internal_sum  [1:0]; // !! BLE5A.{cout, s}=[0], BLE5B.{cout, s}=[1]
    wire [1:0] internal_ce;
    reg [1:0] internal_ff;

    // decode programming data
    wire [BLE5_MODE_WIDTH-1:0]  ble5a_mode;
    wire [BLE5_MODE_WIDTH-1:0]  ble5b_mode;
    wire                        ffa_disable, ffa_ce;
    wire                        ffb_disable, ffb_ce;

    assign ble5a_mode = prog_data[BLE5A_DATA + BLE5_MODE +: BLE5_MODE_WIDTH];
    assign ble5b_mode = prog_data[BLE5B_DATA + BLE5_MODE +: BLE5_MODE_WIDTH];
    assign ffa_disable = prog_data[BLE5A_DATA + FF_DISABLE];
    assign ffa_ce = ~prog_data[BLE5A_DATA + FF_ENABLE_CE] || ce;
    assign ffb_disable = prog_data[BLE5B_DATA + FF_DISABLE];
    assign ffb_ce = ~prog_data[BLE5B_DATA + FF_ENABLE_CE] || ce;

    // -- Implementation -----------------------------------------------------
    // select carry-ins
    always @* begin
        // BLE5A
        case (prog_data[BLE5A_DATA + ADDER_MODE +: ADDER_MODE_WIDTH])
            ADDER_MODE_CONST0:  internal_cin[0] = 1'b0;
            ADDER_MODE_CONST1:  internal_cin[0] = 1'b1;
            ADDER_MODE_CHAIN:   internal_cin[0] = cin;
            ADDER_MODE_FABRIC:  internal_cin[0] = in[6];
        endcase

        // BLE5B
        case (prog_data[BLE5B_DATA + ADDER_MODE +: ADDER_MODE_WIDTH])
            ADDER_MODE_CONST0:  internal_cin[1] = 1'b0;
            ADDER_MODE_CONST1:  internal_cin[1] = 1'b1;
            ADDER_MODE_CHAIN:   internal_cin[1] = internal_sum[0][1];
            ADDER_MODE_FABRIC:  internal_cin[1] = in[6];
        endcase
    end

    // adders
    assign internal_sum[0] = internal_lut4[0][0] + internal_lut4[1][0] + internal_cin[0];
    assign internal_sum[1] = internal_lut4[0][1] + internal_lut4[1][1] + internal_cin[1];

    // LUTs
    always @* begin
        // BLE5A.LUT4A, BLE5A.LUT4B
        case (in[3:0])
            {%- for i in range(16) %}
            4'd{{ i }}: begin
                internal_lut4[0][0] = prog_data[BLE5A_DATA + LUT4A_DATA + {{ i }}];
                internal_lut4[1][0] = prog_data[BLE5A_DATA + LUT4B_DATA + {{ i }}];
            end
            {%- endfor %}
        endcase

        // BLE5B.LUT4A, BLE5B.LUT4B
        case ({in[5:4], in[1:0]})
            {%- for i in range(16) %}
            4'd{{ i }}: begin
                internal_lut4[0][1] = prog_data[BLE5B_DATA + LUT4A_DATA + {{ i }}];
                internal_lut4[1][1] = prog_data[BLE5B_DATA + LUT4B_DATA + {{ i }}];
            end
            {%- endfor %}
        endcase

        // LUT5
        case (in[6])
            1'b0: internal_lut5 = internal_lut4[0];
            1'b1: internal_lut5 = internal_lut4[1];
        endcase

        // LUT6
        case (in[7])
            1'b0: internal_lut6 = internal_lut5[0];
            1'b1: internal_lut6 = internal_lut5[1];
        endcase
    end

    // FFs
    always @(posedge clk) begin
        if (~prog_done) begin
            internal_ff <= 2'b0;
        end else begin
            // BLE5A
            case (ble5a_mode)
                BLE5_MODE_DISABLED: internal_ff[0] <= 1'b0;
                BLE5_MODE_ARITH:    if (ffa_ce) internal_ff[0] <= internal_sum[0][0];
                BLE5_MODE_LUT5:     if (ffa_ce) internal_ff[0] <= internal_lut5[0];
                BLE5_MODE_LUT6:     if (ffa_ce) internal_ff[0] <= internal_lut6;
            endcase

            // BLE5B
            case (ble5b_mode)
                BLE5_MODE_DISABLED: internal_ff[1] <= 1'b0;
                BLE5_MODE_ARITH:    if (ffb_ce) internal_ff[1] <= internal_sum[1][0];
                BLE5_MODE_LUT5:     if (ffb_ce) internal_ff[1] <= internal_lut5[1];
                BLE5_MODE_LUT6:     if (ffb_ce) internal_ff[1] <= 1'b0;
            endcase
        end
    end

    // -- Outputs ------------------------------------------------------------
    always @* begin
        if (prog_done) begin
            // out[0]
            case (ble5a_mode)
                BLE5_MODE_DISABLED: out[0] = 1'b0;
                BLE5_MODE_ARITH:    out[0] = ffa_disable ? internal_sum[0][0] : internal_ff[0];
                BLE5_MODE_LUT5:     out[0] = ffa_disable ? internal_lut5[0]   : internal_ff[0];
                BLE5_MODE_LUT6:     out[0] = ffa_disable ? internal_lut6      : internal_ff[0];
            endcase

            // out[1]
            case (ble5b_mode)
                BLE5_MODE_DISABLED: out[1] = 1'b0;
                BLE5_MODE_ARITH:    out[1] = ffb_disable ? internal_sum[1][0] : internal_ff[1];
                BLE5_MODE_LUT5:     out[1] = ffb_disable ? internal_lut5[1]   : internal_ff[1];
                BLE5_MODE_LUT6:     out[1] = 1'b0;
            endcase

            // cout
            if (ble5b_mode == BLE5_MODE_ARITH) begin
                cout = internal_sum[1][1];
            end else begin
                cout = 1'b0;
            end

        end else begin
            out = 2'b0;
            cout = 1'b0;
        end
    end

endmodule