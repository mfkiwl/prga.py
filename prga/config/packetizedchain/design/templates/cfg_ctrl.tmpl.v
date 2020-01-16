// Automatically generated by PRGA's RTL generator
{%- set width = module.all_ports.cfg_pkt_data_i|length %}
module {{ module.name }} (
    input wire [0:0] cfg_clk,
    input wire [0:0] cfg_e,

    input wire [0:0] cfg_pkt_val_i,
    input wire [{{ width - 1 }}:0] cfg_pkt_data_i,

    output reg [0:0] cfg_pkt_val_o,
    output reg [{{ width - 1 }}:0] cfg_pkt_data_o,

    output reg [0:0] cfg_we, 
    output reg [{{ width - 1 }}:0] cfg_dout,
    input wire [{{ width - 1 }}:0] cfg_din
    );

    // Packet format:
    //  Header: 16 bits + [optional] 16 bits + [optional] 16 bits
    //       8b: MAGIC NUMBER FOR START OF PACKET
    //       8b: MESSAGE TYPE
    //      16b: [optional] HOP COUNT (minus 1 per controller, consumed where it reaches zero)
    //                  - for DATA, DATA_CHECK_HOC messages only
    //      16b: [optional] PAYLOAD SIZE (#bits - 1 excluding header)
    //                  - for DATA, DATA_CHECK_HOC messages only
    //  Payload: PAYLOAD bits for DATA message types

    localparam  CFG_WIDTH = {{ width }};        // configuration chain width
    localparam  MAGIC_SOP = 8'd{{ module.magic_sop }};      // magic number for start of packet

    localparam  MSG_TYPE_CFG_DATA = 8'h00,
                MSG_TYPE_CFG_DATA_CHECK_HOC = 8'h01,        // check Head Of Config (32 bit magic number)
                MSG_TYPE_EOP = 8'hFF,                       // end of programming
                MSG_TYPE_ERROR_HOC_MISMATCH = 8'h80,        // HOC mismatch
                MSG_TYPE_ERROR_SOP_MISMATCH = 8'h81,        // SOP mismatch when waiting for the next packet
                MSG_TYPE_ERROR_UNKNOWN_STATE = 8'h82;       // FSM trapped in an unknown state

    localparam  ST_IDLE                         = 4'h0,     // waiting for SOP MAGIC NUMBER
                ST_DATA_CHECK_HOC_HEADER        = 4'h1,     // reading the header of a DATA_CHECK_HOC message
                ST_DATA_HEADER                  = 4'h2,     // reading the header of a DATA message
                ST_DATA_CHECK_HOC               = 4'h3,     // processing payload of a DATA_CHECK_HOC message
                ST_DATA                         = 4'h4,     // processing payload of a DATA message
                ST_CHECK_HOC                    = 4'h5,     // checking HOC
                ST_PASSTHRU                     = 4'h6,     // processing a message passing through
                ST_PASSTHRU_WITH_PAYLOAD_HEADER = 4'h7,     // reading the header of a pass-thru message
                ST_FLUSH                        = 4'h8,     // flush buffer
                ST_SEND_ERROR_MSG               = 4'h9,     // sending error message
                ST_TRAP                         = 4'hA,     // trapped after sending an error message
                ST_PASSTHRU_ERROR               = 4'hB;     // got an error message, transition to trap state

    // registers
    reg [31:0] buffer;                          // phits buffer
    reg [16:0] bit_count;                       // multi-purpose bit count
    reg [31:0] hoc;                             // head of config
    reg [3:0] state;

    // wires
    reg en_output, reset_bit_count, dec_hop_count;
    reg [31:0] buffer_next;
    reg [16:0] bit_count_reset_value;
    reg [3:0] state_next;

    always @(posedge cfg_clk) begin
        if (~cfg_e) begin
            buffer <= 32'b0;
            bit_count <= 16'b0;
            cfg_pkt_data_o <= {{ '{' -}} CFG_WIDTH {{- '{' -}} 1'b0 {{- '}}' -}};
            cfg_pkt_val_o <= 1'b0;
            state <= ST_IDLE;
        end else if (cfg_pkt_val_i) begin
            if (reset_bit_count) begin
                bit_count <= bit_count_reset_value - CFG_WIDTH; // the first phit passes thru when this gets updated
            end else begin
                bit_count <= bit_count - CFG_WIDTH;
            end

            {{ '{' -}} cfg_pkt_data_o, buffer {{- '}' }} <= {{ '{' -}} buffer_next, cfg_pkt_data_i {{- '}' }};
            cfg_pkt_val_o <= en_output;
            state <= state_next;
        end else begin
            cfg_pkt_val_o <= 1'b0;
        end
    end

    always @(posedge cfg_clk) begin
        if (cfg_we) begin
            hoc <= {{ '{' -}} hoc, cfg_din {{- '}' }};
        end
    end

    always @* begin
        cfg_dout = buffer[0 +: CFG_WIDTH];
    end

    always @* begin
        state_next = state;
        en_output = 1'b0;
        reset_bit_count = 1'b0;
        bit_count_reset_value = 17'b0;
        cfg_we = 1'b0;
        buffer_next = buffer;

        case (state)
            ST_IDLE: begin
                if (buffer[24 +: 8] == MAGIC_SOP) begin     // matches SOP, this is the beginning of a packet
                    reset_bit_count = 1'b1;                 // start counting bits

                    case (buffer[16 +: 8])
                        MSG_TYPE_CFG_DATA,
                        MSG_TYPE_CFG_DATA_CHECK_HOC: begin
                            if (buffer[15:0] == 0) begin    // this packet is destined here
                                bit_count_reset_value = 17'd16;     // wait until we know payload size

                                if (buffer[16 +: 8] == MSG_TYPE_CFG_DATA_CHECK_HOC) begin
                                    state_next = ST_DATA_CHECK_HOC_HEADER;
                                end else begin
                                    state_next = ST_DATA_HEADER;
                                end
                            end else begin                  // this packet is for someone after me
                                en_output = 1'b1;
                                buffer_next = {{ '{' -}} buffer[31:16], buffer[15:0] - 1 {{- '}' }};
                                bit_count_reset_value = 17'd16;     // wait until we know payload size
                                state_next = ST_PASSTHRU_WITH_PAYLOAD_HEADER;
                            end
                        end
                        MSG_TYPE_EOP: begin
                            en_output = 1'b1;
                            bit_count_reset_value = 17'd16;         // wait until the message passes thru
                            state_next = ST_PASSTHRU;
                        end
                        MSG_TYPE_ERROR_HOC_MISMATCH,
                        MSG_TYPE_ERROR_SOP_MISMATCH: begin
                            en_output = 1'b1;
                            bit_count_reset_value = 17'd16;         // wait until the message passes thru
                            state_next = ST_PASSTHRU_ERROR;
                        end
                    endcase
                end else if (buffer[24 +: 8] != 8'h0) begin // unexpected value received, something is wrong
                    buffer_next = {{ '{' -}} MAGIC_SOP, MSG_TYPE_ERROR_SOP_MISMATCH, buffer[15:0] {{- '}' }};
                    reset_bit_count = 1'b1;
                    bit_count_reset_value = 17'd16;
                    state_next = ST_SEND_ERROR_MSG;
                end
            end
            ST_PASSTHRU: begin
                en_output = 1'b1;
                if (bit_count == CFG_WIDTH) begin           // jump back to IDLE before the last phit leaves the buffer
                    state_next = ST_IDLE;
                end
            end
            ST_PASSTHRU_ERROR: begin
                en_output = 1'b1;
                if (bit_count == CFG_WIDTH) begin
                    state_next = ST_TRAP;
                end
            end
            ST_PASSTHRU_WITH_PAYLOAD_HEADER: begin
                en_output = 1'b1;
                if (bit_count == 0) begin                   // PAYLOAD should be in buffer[15:0] now
                    reset_bit_count = 1'b1;
                    bit_count_reset_value = buffer[15:0] + 33;      // wait until the message passes thru
                    state_next = ST_PASSTHRU;
                end
            end
            ST_DATA_CHECK_HOC_HEADER: begin
                if (bit_count == 0) begin                   // PAYLOAD should be in buffer[15:0] now
                    reset_bit_count = 1'b1;
                    bit_count_reset_value = buffer[15:0] + 33;
                    state_next = ST_DATA_CHECK_HOC;
                end
            end
            ST_DATA_HEADER: begin
                if (bit_count == 0) begin                   // PAYLOAD should be in buffer[15:0] now
                    reset_bit_count = 1'b1;
                    bit_count_reset_value = buffer[15:0] + 33;
                    state_next = ST_DATA;
                end
            end
            ST_DATA_CHECK_HOC: begin
                cfg_we = 1'b1;
                if (bit_count == 64) begin                  // stop before reading HOC
                    state_next = ST_CHECK_HOC;
                end
            end
            ST_CHECK_HOC: begin
                if (bit_count == 32) begin                  // HOC should be in buffer now
                    if (hoc == buffer) begin                // config successful!
                        state_next = ST_FLUSH;
                    end else begin
                        buffer_next = {{ '{' -}} MAGIC_SOP, MSG_TYPE_ERROR_HOC_MISMATCH, buffer[15:0] {{- '}' }};
                        reset_bit_count = 1'b1;
                        bit_count_reset_value = 17'd16;
                        state_next = ST_SEND_ERROR_MSG;
                    end
                end
            end
            ST_DATA: begin
                cfg_we = 1'b1;
                if (bit_count == 32) begin
                    state_next = ST_FLUSH;
                end
            end
            ST_FLUSH: begin
                if (bit_count == CFG_WIDTH) begin           // jump back to IDLE before the last phit leaves the buffer
                    state_next = ST_IDLE;
                end
            end
            ST_SEND_ERROR_MSG: begin
                en_output = 1'b1;
                if (bit_count == 0) begin
                    state_next = ST_TRAP;
                end
            end
            ST_TRAP: begin  // trapped after receiving an error message, must be reset before performing any useful actions
                state_next = ST_TRAP;
            end
            default: begin
                buffer_next = {{ '{' -}} MAGIC_SOP, MSG_TYPE_ERROR_UNKNOWN_STATE, buffer[15:0] {{- '}' }};
                reset_bit_count = 1'b1;
                bit_count_reset_value = 17'd16;
                state_next = ST_SEND_ERROR_MSG;
            end
        endcase
    end

endmodule
