// Automatically generated by PRGA implementation wrapper generator
//
//  Programming circuitry type: 'Magic'
module implwrap (
    input wire tb_clk
    , input wire tb_rst
    , output reg tb_prog_done
    , input wire [31:0] tb_verbosity
    , input wire [31:0] tb_cycle_cnt
    {%- for name, port in app.ports.items() %}
    , {{ port.direction.case("input", "output") }} wire
        {%- if port.range_ is not none %} [{{ port.range_.stop - port.range_.step }}:{{ port.range_.start }}]{% endif %} {{ name }}
    {%- endfor %}
    );

    // FPGA instance
    {{ summary.top }} dut (
        .prog_clk(tb_clk)
        ,.prog_rst(tb_rst)
        ,.prog_done(1'b1)
        {%- for port in app.ports.values() %}
            {%- for idx, ((x, y), subtile) in port.iter_io_constraints() %}
        ,.{{- port.direction.case("ipin", "opin") }}_x{{ x }}y{{ y }}_{{ subtile }}({{ port.name }}{%- if idx is not none %}[{{ idx }}]{%- endif %})
            {%- endfor %}
        {%- endfor %}
        );

    reg [31:0] rst_cnt;

    // Force load fake bitstream
    initial begin
        `include "bitgen.out"

        rst_cnt = 32'b0;
        tb_prog_done = 1'b0;
    end

    always @(posedge tb_clk) begin
        if (tb_rst) begin
            rst_cnt <= 100;
            tb_prog_done <= 1'b0;
        end else if (rst_cnt > 0) begin
            rst_cnt <= rst_cnt - 1;

            if (rst_cnt == 1)
                tb_prog_done <= 1'b1;
        end
    end

endmodule