// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

`include "prga_system.vh"
`include "pktchain_system.vh"

module pktchain_cfg #(
    parameter   DECOUPLED_INPUT = 1
) (
    input wire                                      clk,
    input wire                                      rst_n,

    // == CTRL <-> CFG ========================================================
    output reg [`PRGA_CFG_STATUS_WIDTH-1:0]         status,

    output wire                                     req_rdy,
    input wire                                      req_val,
    input wire [`PRGA_CREG_ADDR_WIDTH-1:0]          req_addr,
    input wire [`PRGA_CREG_DATA_BYTES-1:0]          req_strb,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]          req_data,

    output reg                                      resp_val,
    input wire                                      resp_rdy,
    output reg                                      resp_err,
    output reg [`PRGA_CREG_DATA_WIDTH-1:0]          resp_data,

    // == CFG <-> FABRIC ======================================================
    output reg                                      cfg_rst,
    output reg                                      cfg_e,

    // configuration output
    input wire                                      phit_o_full,
    output wire                                     phit_o_wr,
    output wire [`PRGA_PKTCHAIN_PHIT_WIDTH - 1:0]   phit_o,

    // configuration input
    output wire                                     phit_i_full,
    input wire                                      phit_i_wr,
    input wire [`PRGA_PKTCHAIN_PHIT_WIDTH - 1:0]    phit_i
    );

    // =======================================================================
    // -- Timing-decoupled Input ---------------------------------------------
    // =======================================================================
    reg req_rdy_f;
    wire req_val_f;
    wire [`PRGA_CREG_ADDR_WIDTH-1:0]        req_addr_f;
    wire [`PRGA_CREG_DATA_BYTES-1:0]        req_strb_f;
    wire [`PRGA_CREG_DATA_WIDTH-1:0]        req_data_f;

    generate if (DECOUPLED_INPUT) begin
        prga_valrdy_buf #(
            .REGISTERED             (1)
            ,.DECOUPLED             (1)
            ,.DATA_WIDTH            (
                `PRGA_CREG_ADDR_WIDTH
                + `PRGA_CREG_DATA_BYTES
                + `PRGA_CREG_DATA_WIDTH
            )
        ) req_valrdy_buf (
            .clk                (clk)
            ,.rst               (~rst_n)
            ,.rdy_o             (req_rdy)
            ,.val_i             (req_val)
            ,.data_i            ({
                req_addr
                , req_strb
                , req_data
            })
            ,.rdy_i             (req_rdy_f)
            ,.val_o             (req_val_f)
            ,.data_o            ({
                req_addr_f
                , req_strb_f
                , req_data_f
            })
            );
    end else begin
        assign req_val_f = req_val;
        assign req_addr_f = req_addr;
        assign req_strb_f = req_strb;
        assign req_data_f = req_data;
        assign req_rdy = req_rdy_f;
    end endgenerate

    // =======================================================================
    // -- Bitstream Frame Input ----------------------------------------------
    // =======================================================================

    // == raw data fifo ==
    reg rawq_wr;
    reg [`PRGA_CREG_DATA_WIDTH - 1:0] rawq_rawdata;
    reg [`PRGA_CREG_DATA_BYTES - 1:0] rawq_rawstrb;

    wire [`PRGA_CREG_DATA_WIDTH + `PRGA_CREG_DATA_BYTES - 1:0] rawq_din, rawq_dout;
    wire rawq_full, rawq_empty, rawq_rd;

    // put byte enable close to each byte (so the resizer can grab those correctly)
    genvar disasm_i;
    generate
        for (disasm_i = 0; disasm_i < `PRGA_CREG_DATA_BYTES; disasm_i = disasm_i + 1) begin: raw_disasm
            assign rawq_din[disasm_i * 9 +: 9] = {rawq_rawstrb[disasm_i], rawq_rawdata[disasm_i * 8 +: 8]};
        end
    endgenerate

    prga_fifo #(
        .DATA_WIDTH             (`PRGA_CREG_DATA_WIDTH + `PRGA_CREG_DATA_BYTES)
        ,.LOOKAHEAD             (0)
    ) i_rawq (
        .clk                    (clk)
        ,.rst                   (~rst_n)
        ,.full                  (rawq_full)
        ,.wr                    (rawq_wr)
        ,.din                   (rawq_din)
        ,.empty                 (rawq_empty)
        ,.rd                    (rawq_rd)
        ,.dout                  (rawq_dout)
        );

    // == Resizer ==
    localparam  FRAME_BYTES = 1 << (`PRGA_PKTCHAIN_FRAME_SIZE_LOG2 - 3);

    wire [`PRGA_PKTCHAIN_FRAME_SIZE + FRAME_BYTES - 1:0] resizer_dout;
    wire resizer_empty, resizer_rd;

    prga_fifo_resizer #(
        .DATA_WIDTH             (`PRGA_PKTCHAIN_FRAME_SIZE + FRAME_BYTES)
        ,.INPUT_MULTIPLIER      (`PRGA_CREG_DATA_WIDTH / `PRGA_PKTCHAIN_FRAME_SIZE)
        ,.INPUT_LOOKAHEAD       (0)
        ,.OUTPUT_LOOKAHEAD      (1)
    ) i_resizer (
        .clk                    (clk)
        ,.rst                   (~rst_n)
        ,.empty_i               (rawq_empty)
        ,.rd_i                  (rawq_rd)
        ,.dout_i                (rawq_dout)
        ,.empty                 (resizer_empty)
        ,.rd                    (resizer_rd)
        ,.dout                  (resizer_dout)
        );

    // re-assemble bitstream frame
    wire [FRAME_BYTES - 1:0] frame_tmp_mask;
    wire [`PRGA_PKTCHAIN_FRAME_SIZE - 1:0] frame_tmp;

    genvar asm_i;
    generate
        for (asm_i = 0; asm_i < FRAME_BYTES; asm_i = asm_i + 1) begin: bsframe_asm
            assign {frame_tmp_mask[asm_i], frame_tmp[asm_i * 8 +: 8]} = resizer_dout[asm_i * 9 +: 9];
        end
    endgenerate

    // == Register Frame ==
    reg [`PRGA_PKTCHAIN_FRAME_SIZE - 1:0] frame_i;
    reg frame_i_val, frame_i_stall;

    always @(posedge clk) begin
        if (~rst_n) begin
            frame_i_val <= 1'b0;
            frame_i <= 1'b0;
        end else if (~frame_i_val || ~frame_i_stall) begin
            if (~resizer_empty && (&frame_tmp_mask)) begin
                frame_i_val <= 1'b1;
                frame_i <= frame_tmp;
            end else begin
                frame_i_val <= 1'b0;
            end
        end
    end

    assign resizer_rd = ~( (&frame_tmp_mask) && frame_i_val && frame_i_stall );

    // =======================================================================
    // -- CTRL Interface -----------------------------------------------------
    // =======================================================================

    reg                             bitstream_en, xtra_eflags_clear;
    reg [`PRGA_CREG_DATA_WIDTH-1:0] xtra_eflags, xtra_eflags_f;

    always @(posedge clk) begin
        if (~rst_n) begin
            bitstream_en <= 1'b1;
            xtra_eflags_f <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
        end else begin
            if (|xtra_eflags) begin
                bitstream_en <= 1'b0;
            end

            if (xtra_eflags_clear) begin
                xtra_eflags_f <= xtra_eflags;
            end else begin
                xtra_eflags_f <= xtra_eflags_f | xtra_eflags;
            end
        end
    end

    // 2 stages:
    //
    //  Q (reQuest):    process CREG request
    //  R (Response):   send CREG response

    reg stall_ctrl_q, stall_ctrl_r;

    // == Q stage variables ==
    localparam  ST_CTRL_Q_WIDTH                 = 2;
    localparam  ST_CTRL_Q_RST                   = 2'h0,
                ST_CTRL_Q_NORMAL                = 2'h1,
                ST_CTRL_Q_ERR_SENT              = 2'h2;

    reg [ST_CTRL_Q_WIDTH-1:0]         ctrl_state_q, ctrl_state_q_next;

    reg                             resp_val_next, resp_err_next;
    reg [`PRGA_CREG_DATA_WIDTH-1:0] resp_data_next;

    // == Q stage ============================================================
    
    // == Register inputs ==
    always @(posedge clk) begin
        if (~rst_n) begin
            ctrl_state_q    <= ST_CTRL_Q_RST;
        end else begin
            ctrl_state_q    <= ctrl_state_q_next;
        end
    end

    always @* begin
        req_rdy_f = rst_n && (~req_val_f || ~stall_ctrl_q);
        rawq_rawdata = req_data_f;
        rawq_rawstrb = req_strb_f;
    end

    // == Main FSM ==
    always @* begin
        ctrl_state_q_next = ctrl_state_q;
        stall_ctrl_q = 1'b1;

        rawq_wr = 1'b0;
        xtra_eflags_clear = 1'b0;

        resp_val_next = 1'b0;
        resp_err_next = 1'b0;
        resp_data_next = {`PRGA_CREG_DATA_WIDTH {1'b0} };

        case (ctrl_state_q)
            ST_CTRL_Q_RST: begin
                ctrl_state_q_next = ST_CTRL_Q_NORMAL;
            end
            ST_CTRL_Q_NORMAL: begin
                if (|xtra_eflags_f) begin
                    resp_val_next = 1'b1;
                    resp_err_next = 1'b1;
                    resp_data_next = resp_data_next | xtra_eflags_f;
                    xtra_eflags_clear = resp_err || ~stall_ctrl_r;
                end

                if (req_val_f) begin
                    case (req_addr_f)
                        `PRGA_CREG_ADDR_PKTCHAIN_BITSTREAM_FIFO: if (~(|xtra_eflags_f || stall_ctrl_r)) begin
                            if (|req_strb_f && bitstream_en) begin
                                stall_ctrl_q = rawq_full;
                                rawq_wr = 1'b1;
                                resp_val_next = ~rawq_full;
                            end else begin
                                stall_ctrl_q = 1'b0;
                                resp_val_next = 1'b1;
                            end
                        end
                        default: begin
                            stall_ctrl_q = 1'b1;
                            resp_val_next = 1'b1;
                            resp_err_next = 1'b1;
                            resp_data_next[`PRGA_EFLAGS_CFG_REG_UNDEF] = 1'b1;

                            if (resp_err || ~stall_ctrl_r) begin
                                ctrl_state_q_next = ST_CTRL_Q_ERR_SENT;
                            end
                        end
                    endcase
                end
            end
            ST_CTRL_Q_ERR_SENT: if (|xtra_eflags_f) begin
                resp_val_next = 1'b1;
                resp_err_next = 1'b1;
                resp_data_next = resp_data_next | xtra_eflags_f;
                xtra_eflags_clear = resp_err || ~stall_ctrl_r;
            end else begin
                resp_val_next = 1'b1;

                if (~stall_ctrl_r) begin
                    stall_ctrl_q = 1'b0;
                    ctrl_state_q_next = ST_CTRL_Q_NORMAL;
                end
            end
        endcase
    end

    // == R stage ============================================================

    always @(posedge clk) begin
        if (~rst_n) begin
            resp_val    <= 1'b0;
            resp_err    <= 1'b0;
            resp_data   <= {`PRGA_CREG_DATA_WIDTH {1'b0} };
        end else if (~stall_ctrl_r) begin
            resp_val    <= resp_val_next;
            resp_err    <= resp_err_next;
            resp_data   <= resp_data_next;
        end else if (resp_err && resp_err_next) begin
            resp_data   <= resp_data | resp_data_next;
        end
    end

    always @* begin
        stall_ctrl_r = resp_val && ~resp_rdy;
    end

    // =======================================================================
    // -- Tile Status Tracker Array ------------------------------------------
    // =======================================================================

    localparam  TILE_STATUS_WIDTH           = 2;
    localparam  TILE_STATUS_RESET           = 2'h0,     // the tile is not programmed yet
                TILE_STATUS_PROGRAMMING     = 2'h1,     // init packet sent to the tile
                TILE_STATUS_PENDING         = 2'h2,     // checksum packet sent to the tile
                TILE_STATUS_DONE            = 2'h3;     // the tile is successfully programmed

    localparam  TILE_STATUS_OP_WIDTH    = 2;
    localparam  TILE_STATUS_OP_INVAL    = 2'h0,
                TILE_STATUS_OP_CLEAR    = 2'h1,
                TILE_STATUS_OP_UPDATE   = 2'h2;

    localparam  LOG2_PKTCHAIN_X_TILES = `CLOG2(`PRGA_PKTCHAIN_X_TILES),
                LOG2_PKTCHAIN_Y_TILES = `CLOG2(`PRGA_PKTCHAIN_Y_TILES);

    reg [TILE_STATUS_OP_WIDTH-1:0]      tile_status_op;
    reg [LOG2_PKTCHAIN_X_TILES - 1:0]   tile_status_rd_xpos,
                                        tile_status_rd_xpos_f;
    reg [LOG2_PKTCHAIN_Y_TILES - 1:0]   tile_status_rd_ypos,
                                        tile_status_rd_ypos_f;
    wire [`PRGA_PKTCHAIN_Y_TILES * TILE_STATUS_WIDTH - 1:0] tile_status_col_dout;
    reg [`PRGA_PKTCHAIN_Y_TILES * TILE_STATUS_WIDTH - 1:0] tile_status_col_din;
    reg [TILE_STATUS_WIDTH-1:0]         tile_status_dout, tile_status_din;

    prga_ram_1r1w #(
        .DATA_WIDTH                     (`PRGA_PKTCHAIN_Y_TILES * TILE_STATUS_WIDTH)
        ,.ADDR_WIDTH                    (LOG2_PKTCHAIN_X_TILES)
        ,.RAM_ROWS                      (`PRGA_PKTCHAIN_X_TILES)
    ) i_tile_status (
        .clk                            (clk)
        ,.raddr                         (tile_status_rd_xpos)
        ,.dout                          (tile_status_col_dout)
        ,.waddr                         (tile_status_rd_xpos_f)
        ,.din                           (tile_status_col_din)
        ,.we                            (tile_status_op == TILE_STATUS_OP_CLEAR || tile_status_op == TILE_STATUS_OP_UPDATE)
        );

    always @(posedge clk) begin
        if (~rst_n) begin
            tile_status_rd_xpos_f <= {LOG2_PKTCHAIN_X_TILES {1'b0} };
            tile_status_rd_ypos_f <= {LOG2_PKTCHAIN_Y_TILES {1'b0} };
        end else begin
            tile_status_rd_xpos_f <= tile_status_rd_xpos;
            tile_status_rd_ypos_f <= tile_status_rd_ypos;
        end
    end

    always @* begin
        tile_status_dout = tile_status_col_dout[tile_status_rd_ypos_f * TILE_STATUS_WIDTH +: TILE_STATUS_WIDTH];
        tile_status_col_din = tile_status_col_dout;

        case (tile_status_op)
            TILE_STATUS_OP_CLEAR: begin
                tile_status_col_din = {`PRGA_PKTCHAIN_Y_TILES {TILE_STATUS_RESET} };
            end
            TILE_STATUS_OP_UPDATE: begin
                tile_status_col_din[tile_status_rd_ypos_f * TILE_STATUS_WIDTH +: TILE_STATUS_WIDTH] = tile_status_din;
            end
        endcase
    end

    // =======================================================================
    // -- Bitstream Frame output ---------------------------------------------
    // =======================================================================

    wire frame_o_stall;
    reg frame_o_val;

    pktchain_frame_disassemble #(
        .DEPTH_LOG2             (1)
    ) i_frameq (
        .cfg_clk                (clk)
        ,.cfg_rst               (cfg_rst)
        ,.frame_full            (frame_o_stall)
        ,.frame_wr              (frame_o_val)
        ,.frame_i               (frame_i)
        ,.phit_wr               (phit_o_wr)
        ,.phit_full             (phit_o_full)
        ,.phit_o                (phit_o)
        );

    // =======================================================================
    // -- Bitstream Response Input -------------------------------------------
    // =======================================================================

    wire brespq_empty, bresp_val;
    reg bresp_stall;
    wire [`PRGA_PKTCHAIN_FRAME_SIZE - 1:0] bresp;

    pktchain_frame_assemble #(
        .DEPTH_LOG2             (1)
    ) i_brespq (
        .cfg_clk                (clk)
        ,.cfg_rst               (cfg_rst)
        ,.phit_full             (phit_i_full)
        ,.phit_wr               (phit_i_wr)
        ,.phit_i                (phit_i)
        ,.frame_empty           (brespq_empty)
        ,.frame_rd              (~bresp_stall)
        ,.frame_o               (bresp)
        );

    assign bresp_val = ~brespq_empty;

    // =======================================================================
    // -- Bitstream Loading --------------------------------------------------
    // =======================================================================

    // == FSM States ==
    localparam  ST_BL_WIDTH                     = 3;
    localparam  ST_BL_RST                       = 3'h0,
                ST_BL_CLR_TILE_STATUS           = 3'h1,
                ST_BL_STANDBY                   = 3'h2,
                ST_BL_PROG                      = 3'h3,
                ST_BL_STBLIZ                    = 3'h4,
                ST_BL_SUCCESS                   = 3'h5,
                ST_BL_FAIL                      = 3'h6;

    reg [ST_BL_WIDTH-1:0]                       bl_state, bl_state_next;
    reg [`PRGA_PKTCHAIN_POS_WIDTH * 2 - 1:0]    init_tiles, init_tiles_next, pending_tiles, pending_tiles_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            bl_state                <= ST_BL_RST;
            init_tiles              <= {(`PRGA_PKTCHAIN_POS_WIDTH * 2) {1'b0} };
            pending_tiles           <= {(`PRGA_PKTCHAIN_POS_WIDTH * 2) {1'b0} };
        end else begin
            bl_state                <= bl_state_next;
            init_tiles              <= init_tiles_next;
            pending_tiles           <= pending_tiles_next;
        end
    end

    // == Resource Arbitration ==
    localparam  ARB_WIDTH   = 1;
    localparam  ARB_MAIN    = 1'b0,
                ARB_PKT     = 1'b1;

    reg [ARB_WIDTH-1:0] resource_arb;

    // tile status array
    reg [TILE_STATUS_OP_WIDTH-1:0]  tile_status_op_candidate            [0:1];  // PKT or MAIN
    reg [LOG2_PKTCHAIN_X_TILES-1:0] tile_status_rd_xpos_candidate       [0:1];  // PKT or MAIN

    // init_tiles
    reg [`PRGA_PKTCHAIN_POS_WIDTH*2-1:0] init_tiles_next_candidate      [0:1];  // PKT or MAIN
    reg [`PRGA_PKTCHAIN_POS_WIDTH*2-1:0] pending_tiles_next_candidate   [0:1];  // PKT or MAIN

    always @* begin
        tile_status_op = tile_status_op_candidate[resource_arb];
        tile_status_rd_xpos = tile_status_rd_xpos_candidate[resource_arb];
        init_tiles_next = init_tiles_next_candidate[resource_arb];
        pending_tiles_next = pending_tiles_next_candidate[resource_arb];
    end

    // == Main FSM ==
    // transition triggers
    reg pkt_sob, pkt_eob;

    always @* begin
        status = `PRGA_CFG_STATUS_STANDBY;
        cfg_rst = 1'b0;
        cfg_e = 1'b0;
        bl_state_next = bl_state;
        resource_arb = ARB_PKT;
        tile_status_op_candidate[ARB_MAIN]      = TILE_STATUS_OP_INVAL;
        tile_status_rd_xpos_candidate[ARB_MAIN] = {LOG2_PKTCHAIN_X_TILES {1'b0} };
        init_tiles_next_candidate[ARB_MAIN]     = {(`PRGA_PKTCHAIN_POS_WIDTH*2) {1'b0} };
        pending_tiles_next_candidate[ARB_MAIN]  = {(`PRGA_PKTCHAIN_POS_WIDTH*2) {1'b0} };

        case (bl_state)
            ST_BL_RST: begin
                cfg_rst = 1'b1;
                bl_state_next = ST_BL_CLR_TILE_STATUS;
                resource_arb = ARB_MAIN;
            end
            ST_BL_CLR_TILE_STATUS: begin
                cfg_rst = 1'b1;
                resource_arb = ARB_MAIN;
                tile_status_op_candidate[ARB_MAIN] = TILE_STATUS_OP_CLEAR;
                tile_status_rd_xpos_candidate[ARB_MAIN] = tile_status_rd_xpos_f + 1;

                if (tile_status_rd_xpos_f + 1 == `PRGA_PKTCHAIN_X_TILES) begin
                    bl_state_next = ST_BL_STANDBY;
                end
            end
            ST_BL_STANDBY: begin
                cfg_e = 1'b1;

                // error?
                if (|xtra_eflags) begin
                    bl_state_next = ST_BL_FAIL;
                end

                // start of bitstream?
                else if (pkt_sob) begin
                    bl_state_next = ST_BL_PROG;
                end
            end
            ST_BL_PROG: begin
                status = `PRGA_CFG_STATUS_PROGRAMMING;
                cfg_e = 1'b1;

                // error?
                if (|xtra_eflags) begin
                    bl_state_next = ST_BL_FAIL;
                end

                // end of bitstream?
                else if (pkt_eob) begin
                    bl_state_next = ST_BL_STBLIZ;
                end
            end
            ST_BL_STBLIZ: begin
                status = `PRGA_CFG_STATUS_PROGRAMMING;
                cfg_e = 1'b1;

                // error?
                if (|xtra_eflags) begin
                    bl_state_next = ST_BL_FAIL;
                end 

                // finished?
                else if (pending_tiles == 0) begin
                    bl_state_next = ST_BL_SUCCESS;
                end
            end
            ST_BL_SUCCESS: begin
                status = `PRGA_CFG_STATUS_DONE;
            end
            ST_BL_FAIL: begin
                status = `PRGA_CFG_STATUS_ERR;
            end
        endcase
    end

    // == Packet Input/Output FSM ==
    localparam  ST_PKT_WIDTH                    = 2;
    localparam  ST_PKT_IDLE                     = 2'h0,
                ST_PKT_HDR                      = 2'h1,
                ST_PKT_PLD_DUMP                 = 2'h2,
                ST_PKT_PLD_FWD                  = 2'h3;

    reg [ST_PKT_WIDTH-1:0]                      pkt_o_state, pkt_o_state_next;
    reg [`PRGA_PKTCHAIN_PAYLOAD_WIDTH-1:0]      pkt_o_payload, pkt_o_payload_next;

    reg [ST_PKT_WIDTH-1:0]                      pkt_i_state, pkt_i_state_next;
    reg [`PRGA_PKTCHAIN_PAYLOAD_WIDTH-1:0]      pkt_i_payload, pkt_i_payload_next;

    always @(posedge clk) begin
        if (~rst_n) begin
            pkt_o_state             <= ST_PKT_IDLE;
            pkt_o_payload           <= {`PRGA_PKTCHAIN_PAYLOAD_WIDTH {1'b0} };
            pkt_i_state             <= ST_PKT_IDLE;
            pkt_i_payload           <= {`PRGA_PKTCHAIN_PAYLOAD_WIDTH {1'b0} };
        end else begin
            pkt_o_state             <= pkt_o_state_next;
            pkt_o_payload           <= pkt_o_payload_next;
            pkt_i_state             <= pkt_i_state_next;
            pkt_i_payload           <= pkt_i_payload_next;
        end
    end

    // temporary variable:
    reg tile_status_busy;

    always @* begin
        tile_status_busy = 1'b0;

        // Prioritize response handling
        pkt_i_state_next = pkt_i_state;
        pkt_i_payload_next = pkt_i_payload;
        bresp_stall = 1'b1;
        xtra_eflags = {`PRGA_CREG_DATA_WIDTH {1'b0} };
        tile_status_op_candidate[ARB_PKT]       = TILE_STATUS_OP_INVAL;
        tile_status_rd_xpos_candidate[ARB_PKT]  = tile_status_rd_xpos_f;
        tile_status_rd_ypos                     = tile_status_rd_ypos_f;
        tile_status_din                         = {TILE_STATUS_WIDTH {1'b0} };
        init_tiles_next_candidate[ARB_PKT]      = init_tiles;
        pending_tiles_next_candidate[ARB_PKT]   = pending_tiles;

        case (pkt_i_state)
            ST_PKT_IDLE: if ((bl_state == ST_BL_PROG || bl_state == ST_BL_STBLIZ) && bresp_val) begin
                if (bresp[`PRGA_PKTCHAIN_XPOS_INDEX] < `PRGA_PKTCHAIN_X_TILES &&
                    bresp[`PRGA_PKTCHAIN_YPOS_INDEX] < `PRGA_PKTCHAIN_Y_TILES &&
                    bresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX] == 0
                ) begin
                    case (bresp[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                        `PRGA_PKTCHAIN_MSG_TYPE_DATA_ACK: begin
                            pkt_i_state_next = ST_PKT_HDR;
                            tile_status_rd_xpos_candidate[ARB_PKT] = bresp[`PRGA_PKTCHAIN_XPOS_INDEX];
                            tile_status_rd_ypos = `PRGA_PKTCHAIN_Y_TILES - 1 - bresp[`PRGA_PKTCHAIN_YPOS_INDEX];
                            tile_status_busy = 1'b1;
                        end
                        `PRGA_PKTCHAIN_MSG_TYPE_ERROR_UNKNOWN_MSG_TYPE,
                        `PRGA_PKTCHAIN_MSG_TYPE_ERROR_ECHO_MISMATCH,
                        `PRGA_PKTCHAIN_MSG_TYPE_ERROR_CHECKSUM_MISMATCH,
                        `PRGA_PKTCHAIN_MSG_TYPE_ERROR_FEEDTHRU_PACKET: begin
                            xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                            bresp_stall = 1'b0;
                        end
                        default: begin
                            xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_RESP_INVAL] = 1'b1;
                            bresp_stall = 1'b0;
                        end
                    endcase
                end else begin
                    xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_RESP_INVAL] = 1'b1;
                    bresp_stall = 1'b0;

                    if (bresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                        pkt_i_payload_next = bresp[`PRGA_PKTCHAIN_PAYLOAD_INDEX] - 1;
                        pkt_i_state_next = ST_PKT_PLD_DUMP;
                    end
                end
            end
            ST_PKT_HDR: if (tile_status_dout == TILE_STATUS_PENDING) begin
                pkt_i_state_next = ST_PKT_IDLE;
                tile_status_op_candidate[ARB_PKT] = TILE_STATUS_OP_UPDATE;
                tile_status_din = TILE_STATUS_DONE;
                pending_tiles_next_candidate[ARB_PKT] = pending_tiles - 1;
                bresp_stall = 1'b0;
            end else begin
                pkt_i_state_next = ST_PKT_IDLE;
                xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_RESP_INVAL] = 1'b1;
                bresp_stall = 1'b0;
            end
            ST_PKT_PLD_DUMP: begin
                bresp_stall = 1'b0;

                if (bresp_val) begin

                    if (pkt_i_payload == 0) begin
                        pkt_i_state_next = ST_PKT_IDLE;
                    end else begin
                        pkt_i_payload_next = pkt_i_payload - 1;
                    end
                end
            end
        endcase

        // handle bitstream output packets
        pkt_o_state_next = pkt_o_state;
        pkt_o_payload_next = pkt_o_payload;
        frame_i_stall = 1'b1;
        frame_o_val = 1'b0;
        pkt_sob = 1'b0;
        pkt_eob = 1'b0;

        case (pkt_o_state)
            ST_PKT_IDLE: if (frame_i_val) begin
                case (bl_state)
                    ST_BL_STANDBY: if (frame_i == {
                        `PRGA_PKTCHAIN_MSG_TYPE_SOB,
                        {`PRGA_PKTCHAIN_POS_WIDTH {1'b0} },
                        {`PRGA_PKTCHAIN_POS_WIDTH {1'b0} },
                        {`PRGA_PKTCHAIN_PAYLOAD_WIDTH {1'b0} }
                    }) begin
                        pkt_sob = 1'b1;
                        frame_i_stall = 1'b0;
                    end else begin
                        xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_INCOMPLETE] = 1'b1;
                        frame_i_stall = 1'b0;

                        if (frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                            pkt_o_payload_next = frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] - 1;
                            pkt_o_state_next = ST_PKT_PLD_DUMP;
                        end
                    end
                    ST_BL_PROG: if (frame_i == {
                        `PRGA_PKTCHAIN_MSG_TYPE_EOB,
                        {`PRGA_PKTCHAIN_POS_WIDTH {1'b0} },
                        {`PRGA_PKTCHAIN_POS_WIDTH {1'b0} },
                        {`PRGA_PKTCHAIN_PAYLOAD_WIDTH {1'b0} }
                    }) begin
                        frame_i_stall = 1'b0;

                        if (init_tiles) begin
                            xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                        end else begin
                            pkt_eob = 1'b1;
                        end
                    end else if (frame_i[`PRGA_PKTCHAIN_XPOS_INDEX] < `PRGA_PKTCHAIN_X_TILES &&
                        frame_i[`PRGA_PKTCHAIN_YPOS_INDEX] < `PRGA_PKTCHAIN_Y_TILES && (
                            frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA ||
                            frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT ||
                            frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT_CHECKSUM ||
                            frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX] == `PRGA_PKTCHAIN_MSG_TYPE_DATA_CHECKSUM)
                    ) begin
                        if (~tile_status_busy) begin
                            tile_status_rd_xpos_candidate[ARB_PKT] = frame_i[`PRGA_PKTCHAIN_XPOS_INDEX];
                            tile_status_rd_ypos = frame_i[`PRGA_PKTCHAIN_YPOS_INDEX];
                            pkt_o_state_next = ST_PKT_HDR;
                        end
                    end else begin
                        xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                        frame_i_stall = 1'b0;

                        if (frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                            pkt_o_payload_next = frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] - 1;
                            pkt_o_state_next = ST_PKT_PLD_DUMP;
                        end
                    end
                    ST_BL_SUCCESS,
                    ST_BL_FAIL: begin
                        xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_REDUNDANT] = 1'b1;
                        frame_i_stall = 1'b0;

                        if (frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                            pkt_o_payload_next = frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] - 1;
                            pkt_o_state_next = ST_PKT_PLD_DUMP;
                        end
                    end
                endcase
            end
            ST_PKT_HDR: begin
                case (tile_status_dout)
                    TILE_STATUS_RESET: begin
                        case (frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                            `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT: begin
                                init_tiles_next_candidate[ARB_PKT] = init_tiles + 1;
                                tile_status_din = TILE_STATUS_PROGRAMMING;
                                tile_status_op_candidate[ARB_PKT] = TILE_STATUS_OP_UPDATE;
                                frame_o_val = 1'b1;
                            end
                            `PRGA_PKTCHAIN_MSG_TYPE_DATA_INIT_CHECKSUM: begin
                                pending_tiles_next_candidate[ARB_PKT] = pending_tiles + 1;
                                tile_status_din = TILE_STATUS_PENDING;
                                tile_status_op_candidate[ARB_PKT] = TILE_STATUS_OP_UPDATE;
                                frame_o_val = 1'b1;
                            end
                            default: begin
                                xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                            end
                        endcase
                    end
                    TILE_STATUS_PROGRAMMING: begin
                        case (frame_i[`PRGA_PKTCHAIN_MSG_TYPE_INDEX])
                            `PRGA_PKTCHAIN_MSG_TYPE_DATA: begin
                                frame_o_val = 1'b1;
                            end
                            `PRGA_PKTCHAIN_MSG_TYPE_DATA_CHECKSUM: begin
                                init_tiles_next_candidate[ARB_PKT] = init_tiles - 1;
                                pending_tiles_next_candidate[ARB_PKT] = pending_tiles + 1;
                                tile_status_din = TILE_STATUS_PENDING;
                                tile_status_op_candidate[ARB_PKT] = TILE_STATUS_OP_UPDATE;
                                frame_o_val = 1'b1;
                            end
                            default: begin
                                xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                            end
                        endcase
                    end
                    default: begin
                        xtra_eflags[`PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED] = 1'b1;
                    end
                endcase

                if (frame_o_val) begin
                    if (frame_o_stall) begin
                        pkt_o_payload_next = frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX];
                        pkt_o_state_next = ST_PKT_PLD_FWD;
                    end else begin
                        frame_i_stall = 1'b0;

                        if (frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] > 0) begin
                            pkt_o_payload_next = frame_i[`PRGA_PKTCHAIN_PAYLOAD_INDEX] - 1;
                            pkt_o_state_next = ST_PKT_PLD_FWD;
                        end else begin
                            pkt_o_state_next = ST_PKT_IDLE;
                        end
                    end
                end else begin
                    frame_i_stall = 1'b0;
                    pkt_o_state_next = ST_PKT_IDLE;
                end
            end
            ST_PKT_PLD_FWD: if (frame_i_val) begin
                frame_o_val = 1'b1;

                if (~frame_o_stall) begin
                    frame_i_stall = 1'b0;

                    if (pkt_o_payload == 0) begin
                        pkt_o_state_next = ST_PKT_IDLE;
                    end else begin
                        pkt_o_payload_next = pkt_o_payload - 1;
                    end
                end
            end
            ST_PKT_PLD_DUMP: if (frame_i_val) begin
                frame_i_stall = 1'b0;

                if (pkt_o_payload == 0) begin
                    pkt_o_state_next = ST_PKT_IDLE;
                end else begin
                    pkt_o_payload_next = pkt_o_payload - 1;
                end
            end
        endcase
    end

endmodule
