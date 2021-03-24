// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
`include "prga_app_softregs.vh"

module prga_app_softregs #(
    parameter   DECOUPLED_INPUT = 1
    , parameter DECOUPLED_OUTPUT = 1
) (
    input wire                                      clk
    , input wire                                    rst_n

    // == Val/Rdy Interface ===================================================
    , output reg                                    softreg_req_rdy
    , input wire                                    softreg_req_val
    , input wire [`PRGA_APP_SOFTREG_ADDR_WIDTH-1:0] softreg_req_addr
    , input wire                                    softreg_req_wr
    , input wire [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0] softreg_req_data

    , input wire                                    softreg_resp_rdy
    , output reg                                    softreg_resp_val
    , output reg [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0] softreg_resp_data

    // == Soft Register Ports =================================================
    {%- for name, r in module.softregs.regs.items() %}
    // {{ r.type_.name }} soft register: {{ name }}

        {%- if r.type_.name in ("kernel", "rdempty", "rdempty_la", "decoupled") %}
    , input wire [`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH - 1:0] var_{{ name }}_i
        {%- endif %}

        {%- if r.type_.is_const or r.type_.is_wrfull %}
    , output wire [`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH - 1:0] var_{{ name }}_o
        {%- elif r.type_.name in ("basic", "pulse", "pulse_ack", "decoupled") %}
    , output reg [`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH - 1:0] var_{{ name }}_o
        {%- endif %}

        {%- if r.type_.is_pulse_ack %}
    , input wire var_{{ name }}_ack
        {%- endif %}

        {%- if r.type_.is_rdempty or r.type_.is_rdempty_la %}
    , output reg var_{{ name }}_rd
    , input wire var_{{ name }}_empty
        {%- endif %}

        {%- if r.type_.is_wrfull %}
    , output reg var_{{ name }}_wr
    , input wire var_{{ name }}_full
        {%- endif %}
    {% endfor %}
    );

    // == Input Request Buffering ==
    reg                                     softreg_req_rdy_p;
    wire                                    softreg_req_val_f;
    wire [`PRGA_APP_SOFTREG_ADDR_WIDTH-1:0] softreg_req_addr_f;
    wire                                    softreg_req_wr_f;
    wire [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0] softreg_req_data_f;

    prga_valrdy_buf #(
        .REGISTERED     (1)
        ,.DECOUPLED     (DECOUPLED_INPUT)
        ,.DATA_WIDTH    (
            `PRGA_APP_SOFTREG_ADDR_WIDTH
            + 1
            + `PRGA_APP_SOFTREG_DATA_WIDTH
        )
    ) req_valrdy_buf (
        .clk            (clk)
        ,.rst           (~rst_n)
        ,.rdy_o         (softreg_req_rdy)
        ,.val_i         (softreg_req_val)
        ,.data_i        ({
            softreg_req_addr
            , softreg_req_wr
            , softreg_req_data
        })
        ,.rdy_i         (softreg_req_rdy_p)
        ,.val_o         (softreg_req_val_f)
        ,.data_o        ({
            softreg_req_addr_f
            , softreg_req_wr_f
            , softreg_req_data_f
        })
        );

    // == Output Response Buffering ==
    wire                                    softreg_resp_rdy_f;
    reg                                     softreg_resp_val_p;
    reg [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0]  softreg_resp_data_p;

    prga_valrdy_buf #(
        .REGISTERED     (1)
        ,.DECOUPLED     (DECOUPLED_OUTPUT)
        ,.DATA_WIDTH    (`PRGA_APP_SOFTREG_DATA_WIDTH)
    ) resp_valrdy_buf (
        .clk            (clk)
        ,.rst           (~rst_n)
        ,.rdy_o         (softreg_resp_rdy_f)
        ,.val_i         (softreg_resp_val_p)
        ,.data_i        (softreg_resp_data_p)
        ,.rdy_i         (softreg_resp_rdy)
        ,.val_o         (softreg_resp_val)
        ,.data_o        (softreg_resp_data)
        );

    // == 2-stage pipeline ===================================================
    //  Q (request):    request processing stage
    //  R (response):   response sending stage

    // forward declaration of R-stage variables
    reg stall_r, val_r;

    // == Q-stage ==
    // register implementation (write)

    {% for name, r in module.softregs.regs.items() %}
        {%- if r.type_.is_const %}
    // {{ r.type_.name }} soft register: {{ name }}
    assign var_{{ name }}_o = `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_CONSTVAL;

        {%- elif r.type_.name in ("basic", "pulse", "decoupled") %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_wr;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL;
        end else if (var_{{ name }}_wr) begin
            var_{{ name }}_o <= softreg_req_data_f[0+:`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH];
            {%- if r.type_.is_pulse %}
        end else begin
            var_{{ name }}_o <= `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL;
            {%- endif %}
        end
    end

        {%- elif r.type_.is_pulse_ack %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_wr;
    reg var_{{ name }}_ack_pending_r;

    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL;
            var_{{ name }}_ack_pending_r <= 1'b0;
        end else if (var_{{ name }}_wr) begin
            var_{{ name }}_o <= softreg_req_data_f[0+:`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH];
            var_{{ name }}_ack_pending_r <= softreg_req_data_f[0+:`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH] != var_{{ name }}_o;
        end else if (var_{{ name }}_ack) begin
            var_{{ name }}_o <= `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL;
            var_{{ name }}_ack_pending_r <= 1'b0;
        end
    end

        {%- elif r.type_.is_wrfull %}
    // {{ r.type_.name }} soft register: {{ name }}
    assign var_{{ name }}_o = softreg_req_data_f[0+:`PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH];

        {%- elif r.type_.is_rdempty %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_dval_r;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_dval_r <= 1'b0;
        end else begin
            var_{{ name }}_dval_r <= var_{{ name }}_rd && !var_{{ name }}_empty;
        end
    end

        {%- endif %}
    {% endfor %}

    // pipeline implementation
    always @* begin
        softreg_req_rdy_p = ~(val_r && stall_r);
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_rdempty or r.type_.is_rdempty_la %}
        var_{{ name }}_rd = 1'b0;
            {%- elif r.type_.name in ("basic", "pulse", "pulse_ack", "decoupled", "wrfull") %}
        var_{{ name }}_wr = 1'b0;
            {%- endif %}
        {%- endfor %}

        if (softreg_req_val_f && !(val_r && stall_r)) begin
            case (softreg_req_addr_f)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_rdempty or r.type_.is_rdempty_la %}
                `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                if (!softreg_req_wr_f) begin
                    var_{{ name }}_rd = 1'b1;
                    softreg_req_rdy_p = !var_{{ name }}_empty;
                end
            {%- elif r.type_.name in ("basic", "pulse", "pulse_ack", "decoupled", "wrfull") %}
                `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                if (softreg_req_wr_f) begin
                    var_{{ name }}_wr = 1'b1;
                {%- if r.type_.is_wrfull %}
                    softreg_req_rdy_p = !var_{{ name }}_full;
                {%- endif %}
                end
            {%- endif %}
        {%- endfor %}
            endcase
        end
    end

    reg [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0] data_r_next;
    always @* begin
        data_r_next = {`PRGA_APP_SOFTREG_DATA_WIDTH {1'b0} };

        case (softreg_req_addr_f)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_const %}
            `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                data_r_next = `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_CONSTVAL;
            {%- elif r.type_.name in ("pulse", "pulse_ack") %}
            `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                data_r_next = `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL;
            {%- elif r.type_.name in ("kernel", "rdempty_la", "decoupled") %}
            `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                data_r_next = var_{{ name }}_i;
            {%- elif r.type_.is_basic %}
            `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                data_r_next = var_{{ name }}_o;
            {%- endif %}
        {%- endfor %}
        endcase
    end

    // == R-stage ==
    reg                                     wr_r;
    reg [`PRGA_APP_SOFTREG_ADDR_WIDTH-1:0]  addr_r;
    reg [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0]  data_r;

    always @(posedge clk) begin
        if (~rst_n) begin
            val_r <= 1'b0;
            wr_r <= 1'b0;
            addr_r <= {`PRGA_APP_SOFTREG_ADDR_WIDTH {1'b0} };
        end else if (softreg_req_val_f && softreg_req_rdy_p) begin
            val_r <= 1'b1;
            wr_r <= softreg_req_wr_f;
            addr_r <= softreg_req_addr_f;
        end else if (softreg_resp_val_p && softreg_resp_rdy_f) begin
            val_r <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (softreg_req_val_f && softreg_req_rdy_p) begin
            data_r <= data_r_next;
            {%- for name, r in module.softregs.regs.items() %}
                {%- if r.type_.is_rdempty %}
        end else if (var_{{ name }}_dval_r) begin
            data_r <= var_{{ name }}_i;
                {%- endif %}
            {%- endfor %}
        end
    end

    always @* begin
        stall_r = ~softreg_resp_rdy_f;
        softreg_resp_val_p = val_r;

        if (val_r && softreg_resp_rdy_f) begin
            case (addr_r)
            {%- for name, r in module.softregs.regs.items() %}
                {%- if r.type_.is_pulse_ack %}
                `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
                if (var_{{ name }}_ack_pending_r && ~var_{{ name }}_ack) begin
                    stall_r = 1'b1;
                    softreg_resp_val_p = 1'b0;
                end
                {%- endif %}
            {%- endfor %}
            endcase
        end
    end

    always @* begin
        softreg_resp_data_p = data_r;

        case (addr_r)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_rdempty %}
            `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR:
            if (var_{{ name }}_dval_r) begin
                softreg_resp_data_p = var_{{ name }}_i;
            end
            {%- endif %}
        {%- endfor %}
        endcase
    end

endmodule