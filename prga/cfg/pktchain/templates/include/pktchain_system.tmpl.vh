// Automatically generated by PRGA's RTL generator
`ifndef PRGA_PKTCHAIN_SYSTEM_H
`define PRGA_PKTCHAIN_SYSTEM_H

`include "prga_system.vh"
`include "pktchain.vh"

`define PRGA_CREG_ADDR_PKTCHAIN_BITSTREAM_FIFO      `PRGA_CREG_ADDR_WIDTH'h900  //  64b

`define PRGA_EFLAGS_PKTCHAIN_RESP_INVAL             1 << 8
`define PRGA_EFLAGS_PKTCHAIN_BITSTREAM_CORRUPTED    1 << 9
`define PRGA_EFLAGS_PKTCHAIN_BITSTREAM_INCOMPLETE   1 << 10
`define PRGA_EFLAGS_PKTCHAIN_BITSTREAM_REDUNDANT    1 << 11

`endif /* PRGA_PKTCHAIN_SYSTEM_H */
