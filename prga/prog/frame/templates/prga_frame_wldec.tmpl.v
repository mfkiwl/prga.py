// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps
module {{ module.name }} #(
    parameter   ADDR_WIDTH = {{ module.ports.addr_i|length }}
    , parameter DATA_WIDTH = {{ module.ports.ce_o|length }}
) (
    input wire                      ce_i
    , input wire                    we_i
    , input wire [ADDR_WIDTH-1:0]   addr_i

    , output wire [DATA_WIDTH-1:0]  ce_o
    , output wire [DATA_WIDTH-1:0]  we_o
    );

    genvar i;
    generate for (i = 0; i < DATA_WIDTH; i++) begin
        assign ce_o[i] = ce_i && addr_i == i;
        assign we_o[i] = we_o && addr_i == o;
    end endgenerate

endmodule
