// Automatically generated by PRGA's RTL generator
`ifndef PRGA_PKTCHAIN_H
`define PRGA_PKTCHAIN_H

`include "prga_utils.vh"

`define PRGA_PKTCHAIN_FRAME_SIZE_LOG2 5
`define PRGA_PKTCHAIN_PHIT_WIDTH_LOG2 {{ (context.summary.pktchain.fabric.phit_width - 1).bit_length() }}
`define PRGA_PKTCHAIN_CFG_WIDTH_LOG2 {{ (context.summary.scanchain.cfg_width - 1).bit_length() }}

`define PRGA_PKTCHAIN_FRAME_SIZE (1 << `PRGA_PKTCHAIN_FRAME_SIZE_LOG2)
`define PRGA_PKTCHAIN_PHIT_WIDTH (1 << `PRGA_PKTCHAIN_PHIT_WIDTH_LOG2)
`define PRGA_PKTCHAIN_CFG_WIDTH (1 << `PRGA_PKTCHAIN_CFG_WIDTH_LOG2)

`define PRGA_PKTCHAIN_LOG2_PHITS_PER_FRAME (`PRGA_PKTCHAIN_FRAME_SIZE_LOG2 - `PRGA_PKTCHAIN_PHIT_WIDTH_LOG2)
`define PRGA_PKTCHAIN_NUM_PHITS_PER_FRAME (1 << `PRGA_PKTCHAIN_LOG2_PHITS_PER_FRAME)

`define PRGA_PKTCHAIN_LOG2_CFG_UNITS_PER_FRAME (`PRGA_PKTCHAIN_FRAME_SIZE_LOG2 - `PRGA_PKTCHAIN_CFG_WIDTH_LOG2)
`define PRGA_PKTCHAIN_NUM_CFG_UNITS_PER_FRAME (1 << `PRGA_PKTCHAIN_LOG2_CFG_UNITS_PER_FRAME)

`define PRGA_PKTCHAIN_MSG_TYPE_WIDTH 8
`define PRGA_PKTCHAIN_POS_WIDTH 8
`define PRGA_PKTCHAIN_PAYLOAD_WIDTH 8

`define PRGA_PKTCHAIN_PAYLOAD_BASE 0
`define PRGA_PKTCHAIN_YPOS_BASE (`PRGA_PKTCHAIN_PAYLOAD_BASE + `PRGA_PKTCHAIN_PAYLOAD_WIDTH)
`define PRGA_PKTCHAIN_XPOS_BASE (`PRGA_PKTCHAIN_YPOS_BASE + `PRGA_PKTCHAIN_POS_WIDTH)
`define PRGA_PKTCHAIN_MSG_TYPE_BASE (`PRGA_PKTCHAIN_XPOS_BASE + `PRGA_PKTCHAIN_POS_WIDTH)

`define PRGA_PKTCHAIN_PAYLOAD_INDEX `PRGA_PKTCHAIN_PAYLOAD_BASE+:`PRGA_PKTCHAIN_PAYLOAD_WIDTH
`define PRGA_PKTCHAIN_YPOS_INDEX `PRGA_PKTCHAIN_YPOS_BASE+:`PRGA_PKTCHAIN_POS_WIDTH
`define PRGA_PKTCHAIN_XPOS_INDEX `PRGA_PKTCHAIN_XPOS_BASE+:`PRGA_PKTCHAIN_POS_WIDTH
`define PRGA_PKTCHAIN_MSG_TYPE_INDEX `PRGA_PKTCHAIN_MSG_TYPE_BASE+:`PRGA_PKTCHAIN_MSG_TYPE_WIDTH 

// Message types
// -- BEGIN AUTO-GENERATION (see prga.cfg.pktchain.protocol for more info)
{%- for type_ in context.summary.pktchain.protocol.Programming.MSGType %}
`define PRGA_PKTCHAIN_MSG_TYPE_{{ type_.name }} `PRGA_PKTCHAIN_MSG_TYPE_WIDTH'h{{ "{:>02x}".format(type_.value) }}
{%- endfor %}
// -- DONE AUTO-GENERATION

// Fabric-specific
`define PRGA_PKTCHAIN_X_TILES                    {{ context.summary.pktchain.fabric.x_tiles }}
`define PRGA_PKTCHAIN_Y_TILES                    {{ context.summary.pktchain.fabric.y_tiles }}
`define PRGA_PKTCHAIN_ROUTER_FIFO_DEPTH_LOG2     {{ context.summary.pktchain.fabric.router_fifo_depth_log2 }}

`endif
