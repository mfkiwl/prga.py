// Automatically generated by PRGA's RTL generator
`timescale 1ns/1ps

/*
* System integration complex.
*/

`include "prga_system_axi4.vh"

module prga_syscomplex #(
    parameter   DECOUPLED = 1
) (
    // == System Control Signals =============================================
    input wire                                      clk,
    input wire                                      rst_n,

    // == Generic Register-based Interface ===================================
    output wire                                     reg_req_rdy,
    input wire                                      reg_req_val,
    input wire [`PRGA_CREG_ADDR_WIDTH-1:0]          reg_req_addr,
    input wire [`PRGA_CREG_DATA_BYTES-1:0]          reg_req_strb,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]          reg_req_data,

    input wire                                      reg_resp_rdy,
    output wire                                     reg_resp_val,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]         reg_resp_data,

    // == Generic Cache-coherent interface ===================================
    input wire                                      ccm_req_rdy,
    output wire                                     ccm_req_val,
    output wire [`PRGA_CCM_REQTYPE_WIDTH-1:0]       ccm_req_type,
    output wire [`PRGA_CCM_ADDR_WIDTH-1:0]          ccm_req_addr,
    output wire [`PRGA_CCM_DATA_WIDTH-1:0]          ccm_req_data,
    output wire [`PRGA_CCM_SIZE_WIDTH-1:0]          ccm_req_size,
    output wire [`PRGA_CCM_THREADID_WIDTH-1:0]      ccm_req_threadid,
    output wire [`PRGA_CCM_AMO_OPCODE_WIDTH-1:0]    ccm_req_amo_opcode,

    output wire                                     ccm_resp_rdy,
    input wire                                      ccm_resp_val,
    input wire [`PRGA_CCM_RESPTYPE_WIDTH-1:0]       ccm_resp_type,
    input wire [`PRGA_CCM_THREADID_WIDTH-1:0]       ccm_resp_threadid,
    input wire [`PRGA_CCM_CACHETAG_INDEX]           ccm_resp_addr,  // only used for invalidations
    input wire [`PRGA_CCM_CACHELINE_WIDTH-1:0]      ccm_resp_data,

    // == CTRL <-> PROG ======================================================
    output wire                                     prog_rst_n,
    input wire [`PRGA_PROG_STATUS_WIDTH-1:0]        prog_status,

    input wire                                      prog_req_rdy,
    output wire                                     prog_req_val,
    output wire [`PRGA_CREG_ADDR_WIDTH-1:0]         prog_req_addr,
    output wire [`PRGA_CREG_DATA_BYTES-1:0]         prog_req_strb,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]         prog_req_data,

    input wire                                      prog_resp_val,
    output wire                                     prog_resp_rdy,
    input wire                                      prog_resp_err,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]          prog_resp_data,

    // == Application Control Signals ========================================
    output wire                                     aclk,
    output wire                                     arst_n,

    // == Generic Register-based Interface ===================================
    output wire                                     urst_n,

    input wire                                      ureg_req_rdy,
    output wire                                     ureg_req_val,
    output wire [`PRGA_CREG_ADDR_WIDTH-1:0]         ureg_req_addr,
    output wire [`PRGA_CREG_DATA_BYTES-1:0]         ureg_req_strb,
    output wire [`PRGA_CREG_DATA_WIDTH-1:0]         ureg_req_data,

    output wire                                     ureg_resp_rdy,
    input wire                                      ureg_resp_val,
    input wire [`PRGA_CREG_DATA_WIDTH-1:0]          ureg_resp_data,
    input wire [`PRGA_ECC_WIDTH-1:0]                ureg_resp_ecc,

    // == AXI4 Slave Interface ===============================================
    // -- AW channel --
    output wire                                 awready,
    input wire                                  awvalid,
    input wire [`PRGA_AXI4_ID_WIDTH-1:0]        awid,
    input wire [`PRGA_AXI4_ADDR_WIDTH-1:0]      awaddr,
    input wire [`PRGA_AXI4_AXLEN_WIDTH-1:0]     awlen,
    input wire [`PRGA_AXI4_AXSIZE_WIDTH-1:0]    awsize,
    input wire [`PRGA_AXI4_AXBURST_WIDTH-1:0]   awburst,

    // non-standard use of AWCACHE: Only |AWCACHE[3:2] is checked: 1'b1: cacheable; 1'b0: non-cacheable
    input wire [`PRGA_AXI4_AXCACHE_WIDTH-1:0]   awcache,

    // ECC
    input wire [`PRGA_CCM_ECC_WIDTH-1:0]        awuser,

    // not used
    //  input wire                                  awlock,     // all atomic operations are done through AR channel
    //  input wire [2:0]                            awprot,
    //  input wire [3:0]                            awqos,
    //  input wire [3:0]                            awregion,

    // -- W channel --
    output wire                                 wready,
    input wire                                  wvalid,
    input wire [`PRGA_AXI4_DATA_WIDTH-1:0]      wdata,
    input wire [`PRGA_AXI4_DATA_BYTES-1:0]      wstrb,
    input wire                                  wlast,

    // ECC
    input wire [`PRGA_CCM_ECC_WIDTH-1:0]        wuser,

    // -- B channel --
    input wire                                  bready,
    output wire                                 bvalid,
    output wire [`PRGA_AXI4_XRESP_WIDTH-1:0]    bresp,
    output wire [`PRGA_AXI4_ID_WIDTH-1:0]       bid,

    // -- AR channel --
    output wire                                 arready,
    input wire                                  arvalid,
    input wire [`PRGA_AXI4_ID_WIDTH-1:0]        arid,
    input wire [`PRGA_AXI4_ADDR_WIDTH-1:0]      araddr,
    input wire [`PRGA_AXI4_AXLEN_WIDTH-1:0]     arlen,
    input wire [`PRGA_AXI4_AXSIZE_WIDTH-1:0]    arsize,
    input wire [`PRGA_AXI4_AXBURST_WIDTH-1:0]   arburst,

    // non-standard use of ARLOCK: indicates an atomic operation.
    // Type of the atomic operation is specified in the ARUSER field
    input wire                                  arlock,

    // non-standard use of ARCACHE: Only |ARCACHE[3:2] is checked: 1'b1: cacheable; 1'b0: non-cacheable
    input wire [`PRGA_AXI4_AXCACHE_WIDTH-1:0]   arcache,

    // ATOMIC operation type, data & ECC:
    //      aruser[`PRGA_CCM_ECC_WIDTH + `PRGA_CCM_AMO_OPCODE_WIDTH +: `PRGA_CCM_DATA_WIDTH]        amo_data
    //      aruser[`PRGA_CCM_ECC_WIDTH                              +: `PRGA_CCM_AMO_OPCODE_WIDTH]  amo_opcode
    //      aruser[0                                                +: `PRGA_CCM_ECC_WIDTH]         ecc
    input wire [`PRGA_CCM_AMO_OPCODE_WIDTH + `PRGA_CCM_ECC_WIDTH + `PRGA_CCM_DATA_WIDTH - 1:0]      aruser,

    // not used
    //  input wire [2:0]                            arprot,
    //  input wire [3:0]                            arqos,
    //  input wire [3:0]                            arregion,

    // -- R channel --
    input wire                                  rready,
    output wire                                 rvalid,
    output wire [`PRGA_AXI4_XRESP_WIDTH-1:0]    rresp,
    output wire [`PRGA_AXI4_ID_WIDTH-1:0]       rid,
    output wire [`PRGA_AXI4_DATA_WIDTH-1:0]     rdata,
    output wire                                 rlast
    );

    wire sax_ctrl_rdy, ctrl_sax_val, ctrl_asx_rdy, asx_ctrl_val;
    wire sax_transducer_rdy, transducer_sax_val, transducer_asx_rdy, asx_transducer_val;
    wire uprot_sax_rdy, sax_uprot_val, asx_uprot_rdy, uprot_asx_val;
    wire mprot_sax_rdy, sax_mprot_val, asx_mprot_rdy, mprot_asx_val;
    wire [`PRGA_SAX_DATA_WIDTH-1:0] ctrl_sax_data, transducer_sax_data, sax_uprot_data, sax_mprot_data;
    wire [`PRGA_ASX_DATA_WIDTH-1:0] asx_ctrl_data, asx_transducer_data, uprot_asx_data, mprot_asx_data;
    wire app_en, app_en_aclk;
    wire [`PRGA_CREG_DATA_WIDTH-1:0] app_features, app_features_aclk;
    wire [`PRGA_PROT_TIMER_WIDTH-1:0] timeout_limit;

    prga_ctrl #(
        .DECOUPLED                              (DECOUPLED)
    ) i_ctrl (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.creg_req_rdy                          (reg_req_rdy)
        ,.creg_req_val                          (reg_req_val)
        ,.creg_req_addr                         (reg_req_addr)
        ,.creg_req_strb                         (reg_req_strb)
        ,.creg_req_data                         (reg_req_data)
        ,.creg_resp_rdy                         (reg_resp_rdy)
        ,.creg_resp_val                         (reg_resp_val)
        ,.creg_resp_data                        (reg_resp_data)

        ,.aclk                                  (aclk)
        ,.arst_n                                (arst_n)
        ,.app_en                                (app_en)
        ,.app_en_aclk                           (app_en_aclk)
        ,.app_features                          (app_features)

        ,.prog_rst_n		                    (prog_rst_n)
        ,.prog_status		                    (prog_status)
        ,.prog_req_rdy		                    (prog_req_rdy)
        ,.prog_req_val		                    (prog_req_val)
        ,.prog_req_addr		                    (prog_req_addr)
        ,.prog_req_strb		                    (prog_req_strb)
        ,.prog_req_data		                    (prog_req_data)
        ,.prog_resp_val		                    (prog_resp_val)
        ,.prog_resp_rdy		                    (prog_resp_rdy)
        ,.prog_resp_err		                    (prog_resp_err)
        ,.prog_resp_data		                (prog_resp_data)

        ,.sax_rdy                               (sax_ctrl_rdy)
        ,.sax_val                               (ctrl_sax_val)
        ,.sax_data                              (ctrl_sax_data)
        ,.asx_rdy                               (ctrl_asx_rdy)
        ,.asx_val                               (asx_ctrl_val)
        ,.asx_data                              (asx_ctrl_data)
        );

    prga_ccm_transducer i_transducer (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.app_en                                (app_en)
        ,.app_features                          (app_features)

		,.ccm_req_rdy			                (ccm_req_rdy)
		,.ccm_req_val			                (ccm_req_val)
		,.ccm_req_type			                (ccm_req_type)
		,.ccm_req_addr			                (ccm_req_addr)
		,.ccm_req_data			                (ccm_req_data)
		,.ccm_req_size			                (ccm_req_size)
        ,.ccm_req_threadid                      (ccm_req_threadid)
        ,.ccm_req_amo_opcode                    (ccm_req_amo_opcode)

		,.ccm_resp_rdy			                (ccm_resp_rdy)
		,.ccm_resp_val			                (ccm_resp_val)
		,.ccm_resp_type			                (ccm_resp_type)
        ,.ccm_resp_threadid                     (ccm_resp_threadid)
		,.ccm_resp_addr			                (ccm_resp_addr)
        ,.ccm_resp_data                         (ccm_resp_data)

        ,.sax_rdy		                        (sax_transducer_rdy)
        ,.sax_val		                        (transducer_sax_val)
        ,.sax_data		                        (transducer_sax_data)
        ,.asx_rdy		                        (transducer_asx_rdy)
        ,.asx_val		                        (asx_transducer_val)
        ,.asx_data		                        (asx_transducer_data)
        );

    prga_sax i_sax (
        .clk                                    (clk)
        ,.rst_n                                 (rst_n)

        ,.sax_ctrl_rdy		                    (sax_ctrl_rdy)
        ,.ctrl_sax_val		                    (ctrl_sax_val)
        ,.ctrl_sax_data		                    (ctrl_sax_data)
        ,.ctrl_asx_rdy		                    (ctrl_asx_rdy)
        ,.asx_ctrl_val		                    (asx_ctrl_val)
        ,.asx_ctrl_data		                    (asx_ctrl_data)

        ,.sax_transducer_rdy		            (sax_transducer_rdy)
        ,.transducer_sax_val		            (transducer_sax_val)
        ,.transducer_sax_data		            (transducer_sax_data)
        ,.transducer_asx_rdy		            (transducer_asx_rdy)
        ,.asx_transducer_val		            (asx_transducer_val)
        ,.asx_transducer_data		            (asx_transducer_data)

        ,.aclk                                  (aclk)
        ,.arst_n                                (arst_n)

        ,.asx_uprot_rdy		                    (asx_uprot_rdy)
        ,.uprot_asx_val		                    (uprot_asx_val)
        ,.uprot_asx_data		                (uprot_asx_data)
        ,.uprot_sax_rdy		                    (uprot_sax_rdy)
        ,.sax_uprot_val		                    (sax_uprot_val)
        ,.sax_uprot_data		                (sax_uprot_data)

        ,.asx_mprot_rdy		                    (asx_mprot_rdy)
        ,.mprot_asx_val		                    (mprot_asx_val)
        ,.mprot_asx_data		                (mprot_asx_data)
        ,.mprot_sax_rdy		                    (mprot_sax_rdy)
        ,.sax_mprot_val		                    (sax_mprot_val)
        ,.sax_mprot_data		                (sax_mprot_data)
        );

    prga_uprot #(
        .DECOUPLED                              (DECOUPLED)
    ) i_uprot (
        .clk                                    (aclk)
        ,.rst_n                                 (arst_n)

        ,.sax_rdy                               (uprot_sax_rdy)
        ,.sax_val                               (sax_uprot_val)
        ,.sax_data                              (sax_uprot_data)
        ,.asx_rdy                               (asx_uprot_rdy)
        ,.asx_val                               (uprot_asx_val)
        ,.asx_data                              (uprot_asx_data)

        ,.app_en                                (app_en_aclk)
        ,.app_features                          (app_features_aclk)
        ,.timeout_limit                         (timeout_limit)
        ,.urst_n                                (urst_n)

        ,.ureg_req_rdy                          (ureg_req_rdy)
        ,.ureg_req_val                          (ureg_req_val)
        ,.ureg_req_addr                         (ureg_req_addr)
        ,.ureg_req_strb                         (ureg_req_strb)
        ,.ureg_req_data                         (ureg_req_data)
        ,.ureg_resp_rdy                         (ureg_resp_rdy)
        ,.ureg_resp_val                         (ureg_resp_val)
        ,.ureg_resp_data                        (ureg_resp_data)
        ,.ureg_resp_ecc                         (ureg_resp_ecc)
        );

    prga_mprot #(
        .DECOUPLED                              (DECOUPLED)
    ) i_mprot (
        .clk                                    (aclk)
        ,.rst_n                                 (arst_n)

        ,.sax_rdy                               (mprot_sax_rdy)
        ,.sax_val                               (sax_mprot_val)
        ,.sax_data                              (sax_mprot_data)
        ,.asx_rdy                               (asx_mprot_rdy)
        ,.asx_val                               (mprot_asx_val)
        ,.asx_data                              (mprot_asx_data)

        ,.app_en                                (app_en_aclk)
        ,.app_features                          (app_features_aclk)
        ,.timeout_limit                         (timeout_limit)
        ,.urst_n                                (urst_n)

        ,.awready                               (awready)
        ,.awvalid                               (awvalid)
        ,.awid                                  (awid)
        ,.awaddr                                (awaddr)
        ,.awlen                                 (awlen)
        ,.awsize                                (awsize)
        ,.awburst                               (awburst)
        ,.awcache                               (awcache)
        ,.awuser                                (awuser)

        ,.wready                                (wready)
        ,.wvalid                                (wvalid)
        ,.wdata                                 (wdata)
        ,.wstrb                                 (wstrb)
        ,.wlast                                 (wlast)
        ,.wuser                                 (wuser)

        ,.bready                                (bready)
        ,.bvalid                                (bvalid)
        ,.bresp                                 (bresp)
        ,.bid                                   (bid)

        ,.arready                               (arready)
        ,.arvalid                               (arvalid)
        ,.arid                                  (arid)
        ,.araddr                                (araddr)
        ,.arlen                                 (arlen)
        ,.arsize                                (arsize)
        ,.arburst                               (arburst)
        ,.arlock                                (arlock)
        ,.arcache                               (arcache)
        ,.aruser                                (aruser)

        ,.rready                                (rready)
        ,.rvalid                                (rvalid)
        ,.rresp                                 (rresp)
        ,.rid                                   (rid)
        ,.rdata                                 (rdata)
        ,.rlast                                 (rlast)
        );

endmodule