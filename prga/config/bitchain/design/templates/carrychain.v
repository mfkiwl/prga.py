// Automatically generated by PRGA's RTL generator
module carrychain (
    input wire [0:0] p,     // has to be a ^ b instead of a + b
    input wire [0:0] g,
    input wire [0:0] ci,
    output wire [0:0] s,
    output wire [0:0] co
    );

    assign co = g | (p & ci);
    assign s = p ^ ci;

endmodule