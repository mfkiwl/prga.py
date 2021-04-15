// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
`include "prga_app_softregs.vh"
{%- macro dwidth(name) -%} `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_DATA_WIDTH {%- endmacro %}
{%- macro rstval(name) -%} `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_RSTVAL {%- endmacro %}
{%- macro addr(name) -%} `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_ADDR {%- endmacro %}

module prga_app_softregs (
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

        {%- if r.has_port_i %}
    , input wire [{{ dwidth(name) }} - 1:0] var_{{ name }}_i
        {%- endif %}

        {%- if r.has_port_o %}
    , output reg [{{ dwidth(name) }} - 1:0] var_{{ name }}_o
        {%- endif %}

        {%- if r.type_.name in ("pulse_ack", "cbl", "cbl_2stage") %}
    , input wire var_{{ name }}_ack
        {%- endif %}

        {%- if r.type_.is_cbl_2stage %}
    , input wire var_{{ name }}_done
        {%- endif %}

        {%- if r.type_.is_busywait %}
    , input wire var_{{ name }}_busy
        {%- endif %}

        {%- if r.type_.name in ("rdempty", "rdempty_la") %}
    , output reg var_{{ name }}_rd
    , input wire var_{{ name }}_empty
        {%- endif %}

        {%- if r.type_.is_wrfull %}
    , output reg var_{{ name }}_wr
    , input wire var_{{ name }}_full
        {%- endif %}
    {% endfor %}
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
    reg var_{{ name }}_trx;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= {{ rstval(name) }};
        end else if (var_{{ name }}_trx) begin
            var_{{ name }}_o <= softreg_req_data[0+:{{ dwidth(name) }}];
            {%- if r.type_.is_pulse %}
        end else begin
            var_{{ name }}_o <= {{ rstval(name) }};
            {%- endif %}
        end
    end

        {%- elif r.type_.name in ("pulse_ack", "busywait") %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_trx;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= {{ rstval(name) }};
        end else if (var_{{ name }}_trx) begin
            var_{{ name }}_o <= softreg_req_data[0+:{{ dwidth(name) }}];
        end else if ({% if r.type_.is_busywait -%} !var_{{ name }}_busy {%- else -%} var_{{ name }}_ack {%- endif %}) begin
            var_{{ name }}_o <= {{ rstval(name) }};
        end
    end

    wire var_{{ name }}_trx_blocked;
    assign var_{{ name }}_trx_blocked = var_{{ name }}_o != {{ rstval(name) }}
                                        && {% if r.type_.is_busywait -%} var_{{ name }}_busy {%- else -%} !var_{{ name }}_ack {%- endif %};

        {%- elif r.type_.is_wrfull %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_trx;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_wr <= 1'b0;
        end else if (var_{{ name }}_trx) begin
            var_{{ name }}_wr <= 1'b1;
        end else if (!var_{{ name }}_full) begin
            var_{{ name }}_wr <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (var_{{ name }}_trx) begin
            var_{{ name }}_o <= softreg_req_data[0+:{{ dwidth(name) }}];
        end
    end

    wire var_{{ name }}_trx_blocked;
    assign var_{{ name }}_trx_blocked = var_{{ name }}_wr && var_{{ name }}_full;

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

        {%- elif r.type_.is_bar %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_rd;
    reg [{{ dwidth(name) }} - 1:0] var_{{ name }}_latched;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_latched <= {{ rstval(name) }};
        end else if (var_{{ name }}_i != {{ rstval(name) }}) begin
            var_{{ name }}_latched <= var_{{ name }}_i;
        end else if (var_{{ name }}_rd) begin
            var_{{ name }}_latched <= {{ rstval(name) }};
        end
    end

        {%- elif r.type_.is_cbl %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_rd;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= {{ rstval(name) }};
        end else if (var_{{ name }}_rd) begin
            var_{{ name }}_o <= ~{{ rstval(name) }};
        end else if (var_{{ name }}_ack) begin
            var_{{ name }}_o <= {{ rstval(name) }};
        end
    end

        {%- elif r.type_.is_cbl_2stage %}
    // {{ r.type_.name }} soft register: {{ name }}
    reg var_{{ name }}_rd, var_{{ name }}_trx_blocked;
    always @(posedge clk) begin
        if (~rst_n) begin
            var_{{ name }}_o <= {{ rstval(name) }};
            var_{{ name }}_trx_blocked <= 1'b0;
        end else if (var_{{ name }}_rd) begin
            var_{{ name }}_o <= ~{{ rstval(name) }};
            var_{{ name }}_trx_blocked <= 1'b1;
        end else begin
            if (var_{{ name }}_ack) begin
                var_{{ name }}_o <= {{ rstval(name) }};
            end

            if (var_{{ name }}_done) begin
                var_{{ name }}_trx_blocked <= 1'b0;
            end
        end
    end

        {%- endif %}
    {% endfor %}

    // pipeline implementation
    always @* begin
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.name in ("rdempty", "rdempty_la", "bar", "cbl", "cbl_2stage") %}
        var_{{ name }}_rd = 1'b0;
            {%- elif r.type_.name in ("basic", "pulse", "pulse_ack", "decoupled", "busywait", "wrfull") %}
        var_{{ name }}_trx = 1'b0;
            {%- endif %}
        {%- endfor %}

        if (val_r && stall_r) begin
            softreg_req_rdy = 1'b0;
        end else begin
            softreg_req_rdy = 1'b1;

            case (softreg_req_addr)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_rdempty or r.type_.is_rdempty_la %}
                {{ addr(name) }}: begin
                    var_{{ name }}_rd = softreg_req_val && !softreg_req_wr;
                    softreg_req_rdy = softreg_req_wr || !var_{{ name }}_empty;
                end
            {%- elif r.type_.name in ("bar", "cbl", "cbl_2stage") %}
                {{ addr(name) }}: begin
                    var_{{ name }}_rd = softreg_req_val && !softreg_req_wr;
                end
            {%- elif r.type_.name in ("basic", "pulse", "pulse_ack", "decoupled", "busywait", "wrfull") %}
                {{ addr(name) }}: begin
                    var_{{ name }}_trx = softreg_req_val && softreg_req_wr;
                end
            {%- endif %}
        {%- endfor %}
            endcase
        end
    end

    reg [`PRGA_APP_SOFTREG_DATA_WIDTH-1:0] data_r_next;
    always @* begin
        data_r_next = {`PRGA_APP_SOFTREG_DATA_WIDTH {1'b0} };

        case (softreg_req_addr)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_const %}
            {{ addr(name) }}:
                data_r_next[0+:{{ dwidth(name) }}] = `PRGA_APP_SOFTREG_VAR_{{ name | upper }}_CONSTVAL;
            {%- elif r.type_.is_pulse %}
            {{ addr(name) }}:
                data_r_next[0+:{{ dwidth(name) }}] = {{ rstval(name) }};
            {%- elif r.type_.is_busywait %}
            {{ addr(name) }}:
                data_r_next[0] = var_{{ name }}_busy;
            {%- elif r.type_.is_cbl or r.type_.is_cbl_2stage %}
            {{ addr(name) }}:
                data_r_next[0] = 1'b1;
            {%- elif r.type_.is_bar %}
            {{ addr(name) }}:
                data_r_next[0+:{{ dwidth(name) }}] = var_{{ name }}_latched;
            {%- elif r.type_.name in ("kernel", "rdempty_la", "decoupled") %}
            {{ addr(name) }}:
                data_r_next[0+:{{ dwidth(name) }}] = var_{{ name }}_i;
            {%- elif r.type_.name in ("basic", "pulse_ack") %}
            {{ addr(name) }}:
                data_r_next[0+:{{ dwidth(name) }}] = var_{{ name }}_o;
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
        end else if (softreg_req_val && softreg_req_rdy) begin
            val_r <= 1'b1;
            wr_r <= softreg_req_wr;
            addr_r <= softreg_req_addr;
        end else if (softreg_resp_val && softreg_resp_rdy) begin
            val_r <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (softreg_req_val && softreg_req_rdy) begin
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
        stall_r = ~softreg_resp_rdy;
        softreg_resp_val = val_r;

        if (val_r && softreg_resp_rdy) begin
            case (addr_r)
            {%- for name, r in module.softregs.regs.items() %}
                {%- if r.type_.name in ("busywait", "pulse_ack", "wrfull") %}
                {{ addr(name) }}:
                if (var_{{ name }}_trx_blocked) begin
                    stall_r = 1'b1;
                    softreg_resp_val = 1'b0;
                end
                {%- elif r.type_.is_cbl %}
                {{ addr(name) }}:
                if (var_{{ name }}_o != {{ rstval(name) }} && !var_{{ name }}_ack) begin
                    stall_r = 1'b1;
                    softreg_resp_val = 1'b0;
                end
                {%- elif r.type_.is_cbl_2stage %}
                {{ addr(name) }}:
                if ((var_{{ name }}_o != {{ rstval(name) }} && !var_{{ name }}_ack)
                        || (var_{{ name }}_trx_blocked && !var_{{ name }}_done)) begin
                    stall_r = 1'b1;
                    softreg_resp_val = 1'b0;
                end
                {%- endif %}
            {%- endfor %}
            endcase
        end
    end

    always @* begin
        softreg_resp_data = data_r;

        case (addr_r)
        {%- for name, r in module.softregs.regs.items() %}
            {%- if r.type_.is_rdempty %}
            {{ addr(name) }}:
            if (var_{{ name }}_dval_r) begin
                softreg_resp_data = var_{{ name }}_i;
            end
            {%- endif %}
        {%- endfor %}
        endcase
    end

endmodule
