// Automatically generated by PRGA's RTL generator
module {{ module.name }} (
    input wire [0:0] cfg_clk,
    input wire [0:0] cfg_e_i,
    output reg [0:0] cfg_e
    );

    always @(posedge cfg_clk) begin
        cfg_e <= cfg_e_i;
    end
endmodule