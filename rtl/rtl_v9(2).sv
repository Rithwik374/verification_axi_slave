// Code your design here
// Code your design here
// ============================================================================
// File       : axi_fifo_slave_pkg.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: AXI4 FIFO-backed slave - Package
// Technology : 28nm, 1.0V
// Notes      :
//   - Primary parameters, typedefs, and enums for the AXI4 FIFO slave design.
//   - Default data width is 32-bit per requirements.
//   - All signal names follow AXI4 spec naming.
//   - This package is imported by all modules.
// ============================================================================

package axi_fifo_slave_pkg;

  // ------------------------------------------------------------
  // Global parameters
  // ------------------------------------------------------------
  parameter int unsigned ADDR_W   = 32;        // AXI address width
  parameter int unsigned DATA_W   = 32;        // AXI data width (default 32)
  parameter int unsigned ID_W     = 4;         // AXI ID width
  parameter int unsigned USER_W   = 1;         // AXI user width (optional)
  parameter int unsigned LEN_W    = 8;         // AXI length field width (AXI4: 8)
  parameter int unsigned SIZE_W   = 3;         // AXI size field width
  parameter int unsigned BURST_W  = 2;         // AXI burst field width
  parameter int unsigned STRB_W   = (DATA_W/8);// WSTRB width

  // Memory size in bytes (parameterizable). Must be >= 4KB to avoid burst-cross issues.
  parameter int unsigned MEM_BYTES = 64*1024;  // 64KB default

  // FIFO depths (power-of-two recommended)
  parameter int unsigned AW_FIFO_DEPTH = 4;
  parameter int unsigned W_FIFO_DEPTH  = 8;
  parameter int unsigned AR_FIFO_DEPTH = 4;
  parameter int unsigned R_FIFO_DEPTH  = 8;

  // ------------------------------------------------------------
  // AXI enums and constants (from ARM IHI 0022D)
  // ------------------------------------------------------------
  typedef enum logic [1:0] {
    AXI_BURST_FIXED = 2'b00,
    AXI_BURST_INCR  = 2'b01,
    AXI_BURST_WRAP  = 2'b10
  } axi_burst_e;

  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;
  
 typedef enum int
{
    NO_CHANNEL,
    WR_ADDR,
    WR_DATA,
    WR_BRESP,
    RD_ADDR,
    RD_DATA
} axi_display_channel_e;

  // ------------------------------------------------------------
  // AXI address/control structs
  // ------------------------------------------------------------
  typedef struct packed {
    logic [ID_W-1:0]      id;
    logic [ADDR_W-1:0]    addr;
    logic [LEN_W-1:0]     len;
    logic [SIZE_W-1:0]    size;
    logic [BURST_W-1:0]   burst;
    logic                 lock;           // ARLOCK/AWLOCK[0] AXI4 single-bit
    logic [3:0]           cache;          // AxCACHE
    logic [2:0]           prot;           // AxPROT
    logic [3:0]           qos;            // AxQOS
    logic [3:0]           region;         // AxREGION
    logic [USER_W-1:0]    user;           // AxUSER
  } axi_awar_t;

  typedef struct packed {
    logic [DATA_W-1:0]    data;
    logic [STRB_W-1:0]    strb;
    logic                 last;
    logic [USER_W-1:0]    user;
  } axi_wbeat_t;

  typedef struct packed {
    logic [ID_W-1:0]      id;
    axi_resp_e            resp;
    logic [USER_W-1:0]    user;
  } axi_bresp_t;

  typedef struct packed {
    logic [ID_W-1:0]      id;
    logic [DATA_W-1:0]    data;
    axi_resp_e            resp;
    logic                 last;
    logic [USER_W-1:0]    user;
  } axi_rbeat_t;

  // Utility function: clog2
  function automatic int unsigned ctz_ceil(input int unsigned x);
    int unsigned y;
    begin
      y = 0;
      while ((1<<y) < x) y++;
      return y;
    end
  endfunction

endpackage

// ============================================================================
// File       : axi_fifo_slave_if.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: AXI4 interface with modports (Slave/Master/Monitor)
// Notes      :
//   - Provided for completeness; top-level in this design exposes flat AXI ports.
//   - This interface definition aligns with ARM IHI 0022D.
// ============================================================================

interface axi_fifo_slave_if
  #(parameter int unsigned ADDR_W = 32,
    parameter int unsigned DATA_W = 32,
    parameter int unsigned ID_W   = 4,
    parameter int unsigned USER_W = 1)
  (input logic aclk, input logic areset_n);

  localparam int unsigned STRB_W = DATA_W/8;

  // Global
  logic                 ACLK;
  logic                 ARESETn;

  // Write Address Channel
  logic [ID_W-1:0]      AWID;
  logic [ADDR_W-1:0]    AWADDR;
  logic [7:0]           AWLEN;     // AXI4
  logic [2:0]           AWSIZE;
  logic [1:0]           AWBURST;
  logic                 AWLOCK;    // AXI4 single-bit
  logic [3:0]           AWCACHE;
  logic [2:0]           AWPROT;
  logic [3:0]           AWQOS;
  logic [3:0]           AWREGION;
  logic [USER_W-1:0]    AWUSER;
  logic                 AWVALID;
  logic                 AWREADY;

  // Write Data Channel
  logic [DATA_W-1:0]    WDATA;
  logic [STRB_W-1:0]    WSTRB;
  logic                 WLAST;
  logic [USER_W-1:0]    WUSER;
  logic                 WVALID;
  logic                 WREADY;

  // Write Response Channel
  logic [ID_W-1:0]      BID;
  logic [1:0]           BRESP;
  logic [USER_W-1:0]    BUSER;
  logic                 BVALID;
  logic                 BREADY;

  logic                 trans_done;
  // Read Address Channel
  logic [ID_W-1:0]      ARID;
  logic [ADDR_W-1:0]    ARADDR;
  logic [7:0]           ARLEN;     // AXI4
  logic [2:0]           ARSIZE;
  logic [1:0]           ARBURST;
  logic                 ARLOCK;    // AXI4 single-bit
  logic [3:0]           ARCACHE;
  logic [2:0]           ARPROT;
  logic [3:0]           ARQOS;
  logic [3:0]           ARREGION;
  logic [USER_W-1:0]    ARUSER;
  logic                 ARVALID;
  logic                 ARREADY;

  // Read Data Channel
  logic [ID_W-1:0]      RID;
  logic [DATA_W-1:0]    RDATA;
  logic [1:0]           RRESP;
  logic                 RLAST;
  logic [USER_W-1:0]    RUSER;
  logic                 RVALID;
  logic                 RREADY;

  // Connect clock/reset internally
  assign ACLK   = aclk;
  assign ARESETn = areset_n;

  // Modports
 /* clocking  cb_slave@(posedge aclk);
    default input #1 output #1;
    input  ACLK, ARESETn;
    input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWUSER, AWVALID;
    output AWREADY;
    input  WDATA, WSTRB, WLAST, WUSER, WVALID;
    output WREADY;
    output BID, BRESP, BUSER, BVALID;
    input  BREADY;
    input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARUSER, ARVALID;
    output ARREADY;
    output RID, RDATA, RRESP, RLAST, RUSER, RVALID;
    input  RREADY;
    endclocking*/

   clocking cb_master@(posedge aclk);
    default input #1 output #1;
    input  ACLK, ARESETn;
    output AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWUSER, AWVALID;
    input  AWREADY;
    output WDATA, WSTRB, WLAST, WUSER, WVALID;
    input  WREADY;
    input  BID, BRESP, BUSER, BVALID;
    output BREADY,trans_done;
    output ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARUSER, ARVALID;
    input  ARREADY;
    input  RID, RDATA, RRESP, RLAST, RUSER, RVALID;
    output RREADY;
   endclocking

  clocking cb_monitor@(posedge aclk);
    default input #1 output #1;
    input  ACLK, ARESETn;
    input  AWID, AWADDR, AWLEN, AWSIZE, AWBURST, AWLOCK, AWCACHE, AWPROT, AWQOS, AWREGION, AWUSER, AWVALID, AWREADY;
    input  WDATA, WSTRB, WLAST, WUSER, WVALID, WREADY;
    input  BID, BRESP, BUSER, BVALID, BREADY;
    input  ARID, ARADDR, ARLEN, ARSIZE, ARBURST, ARLOCK, ARCACHE, ARPROT, ARQOS, ARREGION, ARUSER, ARVALID, ARREADY;
    input  RID, RDATA, RRESP, RLAST, RUSER, RVALID, RREADY;
  endclocking
  
  
    property p_wdata_stable_during_backpressure;

        @(posedge ACLK)
        disable iff (!ARESETn)

        WVALID && !WREADY
        |=>
        WVALID &&
        $stable({
            WDATA,
            WSTRB,
            WLAST,
            WUSER
        });

    endproperty
	
	a_wdata_stable_during_backpressure:
    assert property (p_wdata_stable_during_backpressure)
    else
    begin
        $error(
            "[AXI_W_STABILITY] T=%0t Write payload changed while WREADY was low",
            $time
        );
    end

endinterface

// ============================================================================
// File       : sync_fifo.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: Parameterizable synchronous FIFO with ready/valid style
// Notes      :
//   - Single-clock FIFO
//   - No latches; registered outputs
//   - Depth must be >= 2
// ============================================================================

module sync_fifo
  #(parameter int unsigned WIDTH = 64,
    parameter int unsigned DEPTH = 8)
  (input  logic                 clk,
   input  logic                 rst_n,
   // Push
   input  logic                 push,
   input  logic [WIDTH-1:0]     din,
   output logic                 full,
   // Pop
   input  logic                 pop,
   output logic [WIDTH-1:0]     dout,
   output logic                 empty,
   // Occupancy (optional)
   output logic [$clog2(DEPTH+1)-1:0] level
  );

  // Storage
  logic [WIDTH-1:0] mem [0:DEPTH-1];

  // Pointers and count
  logic [$clog2(DEPTH)-1:0] wptr, rptr;
  logic [$clog2(DEPTH+1)-1:0] count;

  // Write
  always_ff @(posedge clk or negedge rst_n) 
    begin
    if (!rst_n)
	begin
      wptr  <= '0;
    end
	else
	begin
      if (push && !full) 
	  begin
        mem[wptr] <= din;
        wptr      <= wptr + 'd1;
      end
    end
  end

  // Read
  logic [WIDTH-1:0] dout_r;
  assign dout = dout_r;
  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
	begin
      rptr   <= '0;
      dout_r <= '0;
    end
	else
	begin
      if (pop && !empty)
	  begin
        dout_r <= mem[rptr];
        rptr   <= rptr + 'd1;
      end
    end
  end

  // Count
  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
	begin
      count <= '0;
    end
	else
	begin
      case ({(push && !full), (pop && !empty)})
        2'b10: count <= count + 1'b1;
        2'b01: count <= count - 1'b1;
        default: count <= count;
      endcase
    end
  end
 

  assign level = count;
  assign empty = (count == '0);
  assign full  = (count == DEPTH[$clog2(DEPTH+1)-1:0]);

endmodule

// ============================================================================
// File       : axi_addr_gen.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: AXI4 burst address generator (FIXED/INCR/WRAP) with lane calc
// Notes      :
//   - Follows ARM IHI 0022D A3.4 Address structure
//   - Computes Address_N, lower byte lane, and bus-base address
// ============================================================================

module axi_addr_gen
  #(parameter int unsigned ADDR_W  = 32,
    parameter int unsigned DATA_W  = 32)
  (input  logic [ADDR_W-1:0]    start_addr,    // AxADDR
   input  logic [2:0]           size,          // AxSIZE
   input  logic [1:0]           burst,         // AxBURST
   input  logic [7:0]           len,           // AxLEN
   input  logic [7:0]           beat_idx,      // 0-based
   output logic [ADDR_W-1:0]    addr_n,        // Address of current beat
   output logic [ADDR_W-1:0]    bus_base_addr, // floor(addr_n / Data_Bus_Bytes) * Data_Bus_Bytes
   output logic [$clog2(DATA_W/8)-1:0] lower_byte_lane // addr_n % Data_Bus_Bytes
  );

  localparam int unsigned DBYTES = (DATA_W/8);

  // Derived
  logic [ADDR_W-1:0] aligned_addr;
  logic [ADDR_W-1:0] wrap_boundary;
  logic [ADDR_W-1:0] wrap_size;
  logic [ADDR_W-1:0] nbytes;
  logic [ADDR_W-1:0] mask_nbytes;
  logic [ADDR_W-1:0] mask_wrap;

  // Compute nbytes = 1 << size
  always_comb 
    begin
    nbytes      = (ADDR_W)'(1) << size;
    mask_nbytes = nbytes - 1;
  end

  // Aligned address: INT(Start_Address / Number_Bytes) * Number_Bytes
  always_comb
    begin
    aligned_addr = start_addr & ~mask_nbytes;
  end

  // Wrap size = Number_Bytes * (len+1)
  // Wrap boundary = INT(Start_Address / wrap_size) * wrap_size
  always_comb
    begin
    wrap_size   = nbytes * (ADDR_W)'(len + 8'd1);
    mask_wrap   = wrap_size - 1;
    wrap_boundary = start_addr & ~mask_wrap;
  end

  // Address_N per spec
  always_comb
    begin
    unique case (burst)
      2'b00: begin // FIXED
        addr_n = start_addr;
      end
      2'b01: begin // INCR
        if (beat_idx == 8'd0) addr_n = start_addr;
        else                  addr_n = aligned_addr + (ADDR_W)'(beat_idx) * nbytes;
      end
      2'b10: begin // WRAP
        if (beat_idx == 8'd0) 
		addr_n = start_addr;
        else
   		begin
          logic [ADDR_W-1:0] tmp;
          tmp = aligned_addr + (ADDR_W)'(beat_idx) * nbytes;
          if (tmp >= (wrap_boundary + wrap_size)) addr_n = wrap_boundary + (tmp - (wrap_boundary + wrap_size));
          else                                    addr_n = tmp;
        end
      end
      default:
	  begin
        // Reserved burst type; hold at start_addr
        addr_n = start_addr; // TODO: Specification does not define handling of reserved burst types - requires clarification
      end
    endcase
  end

  // Lane and base computations
  always_comb
  begin
    lower_byte_lane = addr_n[$clog2(DBYTES)-1:0];     // modulo DBYTES
    bus_base_addr   = addr_n & ~(ADDR_W)'(DBYTES-1);  // base aligned to bus bytes
  end

endmodule

// ============================================================================
// File       : axi_mem.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: True dual-port byte-addressable memory with per-byte write-en
// Notes      :
//   - Port A: Write (byte enables)
//   - Port B: Read
//   - DATA_W must be multiple of 8
//   - Byte-invariant mapping per AXI spec A3.4.3
// ============================================================================

module axi_mem
  #(parameter int unsigned ADDR_W   = 32,
    parameter int unsigned DATA_W   = 32,
    parameter int unsigned MEM_BYTES= 64*1024
	)
   (input  logic                 clk,
    input  logic                 rst_n,

   // Write port A
    input  logic                 a_we,                 // write enable (any byte)
    input  logic [ADDR_W-1:0]    a_addr_base,         // bus base byte address (aligned to DATA_W/8)
    input  logic [(DATA_W/8)-1:0] a_be,               // byte enables
    input  logic [DATA_W-1:0]    a_wdata,

   // Read port B
    input  logic                 b_re,                 // read enable
    input  logic [ADDR_W-1:0]    b_addr_base,         // bus base byte address (aligned to DATA_W/8)
    output logic [DATA_W-1:0]    b_rdata
  );

  localparam int unsigned STRB_W = (DATA_W/8);

  // Storage as bytes
  logic [7:0] mem [0:MEM_BYTES-1];

  // Mask addresses to memory range (wrap-around)
  wire [ADDR_W-1:0] a_base = a_addr_base;
  wire [ADDR_W-1:0] b_base = b_addr_base;

  // Write operation
  integer i;
  always_ff @(posedge clk or negedge rst_n)
    begin
    if (!rst_n) 
	begin
      // no init required
    end
	else if (a_we) 
	begin
      for (i = 0; i < STRB_W; i++) 
	  begin
        if (a_be[i]) 
		   begin
          // TODO: If a_base+i exceeds MEM_BYTES-1, define wrap or error handling - requires clarification
          mem[(a_base + i) % MEM_BYTES] <= a_wdata[8*i +: 8];
        
        end
        
      end
    end
  end

  // Read operation (registered)
  integer j;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      b_rdata <= '0;
    end else if (b_re)
	begin
      for (j = 0; j < STRB_W; j++) begin
        // TODO: If b_base+j exceeds MEM_BYTES-1, define wrap or error handling - requires clarification
        b_rdata[8*j +: 8] <= mem[(b_base + j) % MEM_BYTES];
      end
    end
  end

endmodule

// ============================================================================
// File       : axi_write_engine.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: AXI4 write channel engine with FIFO buffering and burst support
// Notes      :
//   - Compliant with AXI4 handshake & write response dependency (A3-42)
//   - Supports FIXED/INCR/WRAP, aligned/unaligned using WSTRB and addr_gen
//   - Single outstanding write transaction to simplify ordering
// ============================================================================
module axi_write_engine
  #(
    parameter int unsigned ADDR_W       = 32,
    parameter int unsigned DATA_W       = 32,
    parameter int unsigned ID_W         = 4,
    parameter int unsigned USER_W       = 1,
    parameter int unsigned W_FIFO_DEPTH = 8
  )
  (
    input  logic                      clk,
    input  logic                      rst_n,

    // ------------------------------------------------
    // AXI Write Address Channel
    // ------------------------------------------------
    input  logic [ID_W-1:0]           s_awid,
    input  logic [ADDR_W-1:0]         s_awaddr,
    input  logic [7:0]                s_awlen,
    input  logic [2:0]                s_awsize,
    input  logic [1:0]                s_awburst,
    input  logic                      s_awlock,
    input  logic [3:0]                s_awcache,
    input  logic [2:0]                s_awprot,
    input  logic [3:0]                s_awqos,
    input  logic [3:0]                s_awregion,
    input  logic [USER_W-1:0]         s_awuser,
    input  logic                      s_awvalid,
    output logic                      s_awready,

    // ------------------------------------------------
    // AXI Write Data Channel
    // ------------------------------------------------
    input  logic [DATA_W-1:0]         s_wdata,
    input  logic [(DATA_W/8)-1:0]     s_wstrb,
    input  logic                      s_wlast,
    input  logic [USER_W-1:0]         s_wuser,
    input  logic                      s_wvalid,
    output logic                      s_wready,

    // ------------------------------------------------
    // AXI Write Response Channel
    // ------------------------------------------------
    output logic [ID_W-1:0]           s_bid,
    output logic [1:0]                s_bresp,
    output logic [USER_W-1:0]         s_buser,
    output logic                      s_bvalid,
    input  logic                      s_bready,

    // ------------------------------------------------
    // Memory Write Port
    // ------------------------------------------------
    output logic                      mem_we,
    output logic [ADDR_W-1:0]         mem_waddr_base,
    output logic [(DATA_W/8)-1:0]     mem_wbe,
    output logic [DATA_W-1:0]         mem_wdata
  );

  import axi_fifo_slave_pkg::*;

  localparam int unsigned STRB_W   = DATA_W / 8;
  localparam int unsigned WENTRY_W =
      DATA_W + STRB_W + 1 + USER_W;

  // ================================================================
  // Write-data FIFO entry
  // ================================================================

  typedef struct packed {
    logic [DATA_W-1:0]      data;
    logic [STRB_W-1:0]      strb;
    logic                   last;
    logic [USER_W-1:0]      user;
  } wentry_t;

  // ================================================================
  // Write-engine state machine
  // ================================================================

  typedef enum logic [2:0] {
    WR_IDLE,
    WR_WAIT_FIFO,
    WR_POP_FIFO,
    WR_CAPTURE_FIFO,
    WR_COMMIT,
    WR_RESPONSE
  } wr_state_e;

  wr_state_e state;

  // ================================================================
  // Address transaction registers
  // ================================================================

  axi_awar_t aw_reg;

  logic       aw_active;
  logic [7:0] w_beats_total;
  logic [7:0] w_accepted_count;
  logic [7:0] w_beat_idx;

  // ================================================================
  // Write FIFO signals
  // ================================================================

  logic                    w_fifo_push;
  logic                    w_fifo_pop;
  logic                    w_fifo_full;
  logic                    w_fifo_empty;

  logic [WENTRY_W-1:0]     w_fifo_din;
  logic [WENTRY_W-1:0]     w_fifo_dout;

  wentry_t                 wcur_reg;

  assign w_fifo_din = {
    s_wdata,
    s_wstrb,
    s_wlast,
    s_wuser
  };

  assign w_fifo_push =
      s_wvalid && s_wready;

  sync_fifo #(
    .WIDTH (WENTRY_W),
    .DEPTH (W_FIFO_DEPTH)
  ) u_wfifo (
    .clk   (clk),
    .rst_n (rst_n),
    .push  (w_fifo_push),
    .din   (w_fifo_din),
    .full  (w_fifo_full),
    .pop   (w_fifo_pop),
    .dout  (w_fifo_dout),
    .empty (w_fifo_empty),
    .level ()
  );

  // ================================================================
  // AXI channel ready signals
  // ================================================================

  /*
   * Only one write address transaction is supported at a time.
   *
   * AWREADY is allowed to be high before AWVALID.
   */
  assign s_awready =
      (state == WR_IDLE) &&
      !aw_active &&
      !s_bvalid;

  /*
   * Accept W beats only after AW has been accepted.
   * Stop accepting once AWLEN+1 beats are received.
   */
  assign s_wready =
      aw_active &&
      !w_fifo_full &&
      (w_accepted_count < w_beats_total);

  // ================================================================
  // Address generation
  // ================================================================

  logic [ADDR_W-1:0] addr_n;
  logic [ADDR_W-1:0] base_n;
  logic [$clog2(STRB_W)-1:0] lower_lane;

  axi_addr_gen #(
    .ADDR_W (ADDR_W),
    .DATA_W (DATA_W)
  ) u_addr_gen_w (
    .start_addr      (aw_reg.addr),
    .size            (aw_reg.size),
    .burst           (aw_reg.burst),
    .len             (aw_reg.len),
    .beat_idx        (w_beat_idx),
    .addr_n          (addr_n),
    .bus_base_addr   (base_n),
    .lower_byte_lane (lower_lane)
  );

  // ================================================================
  // FIFO pop and memory-port control
  // ================================================================

  always_comb begin

    w_fifo_pop = 1'b0;

    mem_we         = 1'b0;
    mem_waddr_base = base_n;
    mem_wbe        = wcur_reg.strb;
    mem_wdata      = wcur_reg.data;

    case (state)

      WR_POP_FIFO: begin
        /*
         * Pop the FIFO only.
         * Do not write memory in this cycle.
         */
        w_fifo_pop = 1'b1;
      end

      WR_COMMIT: begin
        /*
         * FIFO data was captured into wcur_reg.
         * It is now safe to write memory.
         */
        mem_we = 1'b1;
      end

      default: begin
        w_fifo_pop = 1'b0;
        mem_we     = 1'b0;
      end

    endcase

  end

  // ================================================================
  // Main sequential logic
  // ================================================================

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state              <= WR_IDLE;

      aw_reg             <= '0;
      aw_active          <= 1'b0;

      w_beats_total      <= '0;
      w_accepted_count   <= '0;
      w_beat_idx         <= '0;

      wcur_reg           <= '0;

      s_bvalid           <= 1'b0;
      s_bid              <= '0;
      s_bresp            <= AXI_RESP_OKAY;
      s_buser            <= '0;

    end
    else begin

      // ------------------------------------------------------------
      // Count accepted AXI W-channel beats
      // ------------------------------------------------------------

      if (w_fifo_push) begin
        w_accepted_count <= w_accepted_count + 8'd1;
      end

      // ------------------------------------------------------------
      // Write-engine state machine
      // ------------------------------------------------------------

      case (state)

        // ==========================================================
        // Wait for a new AW transaction
        // ==========================================================

        WR_IDLE: begin

          aw_active        <= 1'b0;
          w_beats_total    <= '0;
          w_accepted_count <= '0;
          w_beat_idx       <= '0;
          wcur_reg         <= '0;

          if (s_awvalid && s_awready) begin

            aw_reg.id      <= s_awid;
            aw_reg.addr    <= s_awaddr;
            aw_reg.len     <= s_awlen;
            aw_reg.size    <= s_awsize;
            aw_reg.burst   <= s_awburst;
            aw_reg.lock    <= s_awlock;
            aw_reg.cache   <= s_awcache;
            aw_reg.prot    <= s_awprot;
            aw_reg.qos     <= s_awqos;
            aw_reg.region  <= s_awregion;
            aw_reg.user    <= s_awuser;

            aw_active      <= 1'b1;
            w_beats_total  <= s_awlen + 8'd1;
            w_beat_idx     <= '0;

            state          <= WR_WAIT_FIFO;

          end

        end

        // ==========================================================
        // Wait until at least one W beat exists in the FIFO
        // ==========================================================

        WR_WAIT_FIFO: begin

          if (!w_fifo_empty) begin
            state <= WR_POP_FIFO;
          end

        end

        // ==========================================================
        // Generate one FIFO pop
        // ==========================================================

        WR_POP_FIFO: begin

          /*
           * w_fifo_pop is asserted combinationally in this state.
           *
           * For a synchronous FIFO, dout changes after this clock.
           */
          state <= WR_CAPTURE_FIFO;

        end

        // ==========================================================
        // Capture the FIFO output one cycle after pop
        // ==========================================================

        WR_CAPTURE_FIFO: begin

          wcur_reg <= wentry_t'(w_fifo_dout);

          state <= WR_COMMIT;

        end

        // ==========================================================
        // Commit the captured beat to memory
        // ==========================================================

        WR_COMMIT: begin

          /*
           * mem_we is asserted combinationally during this state.
           * The memory consumes:
           *
           *   mem_waddr_base = base_n
           *   mem_wdata      = wcur_reg.data
           *   mem_wbe        = wcur_reg.strb
           */

          if (w_beat_idx == (w_beats_total - 8'd1)) begin

            /*
             * Final expected beat has been committed.
             */
            s_bvalid <= 1'b1;
            s_bid    <= aw_reg.id;
            s_bresp  <= AXI_RESP_OKAY;
            s_buser  <= '0;

            state    <= WR_RESPONSE;

          end
          else begin

            w_beat_idx <= w_beat_idx + 8'd1;

            state <= WR_WAIT_FIFO;

          end

        end

        // ==========================================================
        // Hold BVALID until BREADY
        // ==========================================================

        WR_RESPONSE: begin

          if (s_bvalid && s_bready) begin

            s_bvalid         <= 1'b0;

            aw_active        <= 1'b0;
            w_beats_total    <= '0;
            w_accepted_count <= '0;
            w_beat_idx       <= '0;
            wcur_reg         <= '0;

            state            <= WR_IDLE;

          end

        end

        default: begin

          state              <= WR_IDLE;
          aw_active          <= 1'b0;
          w_beats_total      <= '0;
          w_accepted_count   <= '0;
          w_beat_idx         <= '0;
          wcur_reg           <= '0;
          s_bvalid           <= 1'b0;

        end

      endcase

    end

  end

  // ================================================================
  // Simulation-only protocol checks
  // ================================================================

/*`ifndef SYNTHESIS

  always_ff @(posedge clk) begin

    if (rst_n && state == WR_COMMIT) begin

      if (wcur_reg.last !==
          (w_beat_idx == (w_beats_total - 8'd1))) begin

        $error(
          "[AXI_WRITE_ENGINE] WLAST mismatch: beat=%0d total=%0d WLAST=%b",
          w_beat_idx,
          w_beats_total,
          wcur_reg.last
        );

      end

      $display(
        {"[WR_COMMIT] T=%0t beat=%0d/%0d ",
         "addr=%08h data=%08h be=%b last=%b"},
        $time,
        w_beat_idx,
        w_beats_total - 8'd1,
        base_n,
        wcur_reg.data,
        wcur_reg.strb,
        wcur_reg.last
      );

    end

  end

`endif*/
  
 /*
  `ifndef SYNTHESIS

   always @(posedge clk)
    begin
    if (rst_n)
    begin
        if (w_fifo_push || w_fifo_pop || w_fifo_full)
        begin
          $display("[W_FIFO] T=%0t PUSH=%0b POP=%0b FULL=%0b EMPTY=%0b WVALID=%0b WREADY=%0b",
                     $time, w_fifo_push, w_fifo_pop, w_fifo_full, w_fifo_empty,
                      s_wvalid, s_wready);
        end
    end
end

`endif*/
  

endmodule
  
// ============================================================================
// File       : axi_read_engine.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: AXI4 read channel engine with FIFO buffering and burst support
// Notes      :
//   - Compliant with AXI4 handshake
//   - Supports FIXED/INCR/WRAP, aligned/unaligned with byte-invariant packing
//   - Single outstanding read transaction to simplify ordering
// ============================================================================

module axi_read_engine
  #(
    parameter int unsigned ADDR_W       = 32,
    parameter int unsigned DATA_W       = 32,
    parameter int unsigned ID_W         = 4,
    parameter int unsigned USER_W       = 1,
    parameter int unsigned R_FIFO_DEPTH = 8
  )
  (
    input  logic                      clk,
    input  logic                      rst_n,

    // AXI Read Address Channel
    input  logic [ID_W-1:0]           s_arid,
    input  logic [ADDR_W-1:0]         s_araddr,
    input  logic [7:0]                s_arlen,
    input  logic [2:0]                s_arsize,
    input  logic [1:0]                s_arburst,
    input  logic                      s_arlock,
    input  logic [3:0]                s_arcache,
    input  logic [2:0]                s_arprot,
    input  logic [3:0]                s_arqos,
    input  logic [3:0]                s_arregion,
    input  logic [USER_W-1:0]         s_aruser,
    input  logic                      s_arvalid,
    output logic                      s_arready,

    // AXI Read Data Channel
    output logic [ID_W-1:0]           s_rid,
    output logic [DATA_W-1:0]         s_rdata,
    output logic [1:0]                s_rresp,
    output logic                      s_rlast,
    output logic [USER_W-1:0]         s_ruser,
    output logic                      s_rvalid,
    input  logic                      s_rready,

    // Memory read port
    output logic                      mem_re,
    output logic [ADDR_W-1:0]         mem_raddr_base,
    input  logic [DATA_W-1:0]         mem_rdata
  );

  import axi_fifo_slave_pkg::*;

  localparam int unsigned STRB_W = DATA_W / 8;

  typedef enum logic [2:0] {
    RD_IDLE,
    RD_ISSUE,
    RD_WAIT_MEMORY,
    RD_CAPTURE,
    RD_SEND
  } rd_state_e;

  rd_state_e state;

  axi_awar_t ar_reg;

  logic [7:0] r_beats_total;
  logic [7:0] r_beat_idx;

  logic [ADDR_W-1:0] addr_n;
  logic [ADDR_W-1:0] base_n;
  logic [$clog2(STRB_W)-1:0] lower_lane;

  logic [DATA_W-1:0] memory_data_reg;
  logic [DATA_W-1:0] packed_data;

  axi_addr_gen #(
    .ADDR_W (ADDR_W),
    .DATA_W (DATA_W)
  ) u_addr_gen_r (
    .start_addr      (ar_reg.addr),
    .size            (ar_reg.size),
    .burst           (ar_reg.burst),
    .len             (ar_reg.len),
    .beat_idx        (r_beat_idx),
    .addr_n          (addr_n),
    .bus_base_addr   (base_n),
    .lower_byte_lane (lower_lane)
  );

  assign s_arready =
      (state == RD_IDLE);

  assign mem_raddr_base = base_n;

  always_comb begin
    mem_re = 1'b0;

    if (state == RD_ISSUE)
      mem_re = 1'b1;
  end

  always_comb begin
    packed_data = '0;

    for (int lane = 0; lane < STRB_W; lane++) begin
      if ((lane >= lower_lane) &&
          (lane < lower_lane + (1 << ar_reg.size))) begin

        packed_data[8*lane +: 8] =
            memory_data_reg[8*lane +: 8];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin

    if (!rst_n) begin

      state           <= RD_IDLE;
      ar_reg          <= '0;
      r_beats_total   <= '0;
      r_beat_idx      <= '0;
      memory_data_reg <= '0;

      s_rid           <= '0;
      s_rdata         <= '0;
      s_rresp         <= AXI_RESP_OKAY;
      s_rlast         <= 1'b0;
      s_ruser         <= '0;
      s_rvalid        <= 1'b0;

    end
    else begin

      case (state)

        RD_IDLE: 
		begin

          s_rvalid   <= 1'b0;
          s_rlast    <= 1'b0;
          r_beat_idx <= 8'd0;

          if (s_arvalid && s_arready) 
		  begin

            ar_reg.id     <= s_arid;
            ar_reg.addr   <= s_araddr;
            ar_reg.len    <= s_arlen;
            ar_reg.size   <= s_arsize;
            ar_reg.burst  <= s_arburst;
            ar_reg.lock   <= s_arlock;
            ar_reg.cache  <= s_arcache;
            ar_reg.prot   <= s_arprot;
            ar_reg.qos    <= s_arqos;
            ar_reg.region <= s_arregion;
            ar_reg.user   <= s_aruser;

            r_beats_total <= s_arlen + 8'd1;
            r_beat_idx    <= 8'd0;

            state         <= RD_ISSUE;

          end
        end

        RD_ISSUE: begin
          // mem_re is asserted in this state
          state <= RD_WAIT_MEMORY;
        end

        RD_WAIT_MEMORY: begin
          // Wait one cycle for registered memory output
          state <= RD_CAPTURE;
        end

        RD_CAPTURE: begin

          memory_data_reg <= mem_rdata;

          state <= RD_SEND;

        end

        RD_SEND: begin

          if (!s_rvalid) begin

            s_rid    <= ar_reg.id;
            s_rdata  <= packed_data;
            s_rresp  <= AXI_RESP_OKAY;
            s_ruser  <= '0;
            s_rlast  <=
                (r_beat_idx == r_beats_total - 8'd1);

            s_rvalid <= 1'b1;

          end
          else if (s_rvalid && s_rready) begin

            s_rvalid <= 1'b0;

            if (s_rlast) begin

              s_rlast    <= 1'b0;
              r_beat_idx <= 8'd0;
              state      <= RD_IDLE;

            end
            else begin

              r_beat_idx <= r_beat_idx + 8'd1;
              state      <= RD_ISSUE;

            end

          end
        end

        default: begin

          state      <= RD_IDLE;
          s_rvalid   <= 1'b0;
          s_rlast    <= 1'b0;
          r_beat_idx <= 8'd0;

        end

      endcase

    end
  end

 /*`ifndef SYNTHESIS

 always @(posedge clk) begin

    if (state != RD_IDLE) begin
      $display(
        "[RD_ENGINE] T=%0t state=%0d beat=%0d/%0d mem_re=%b mem_addr=%08h mem_data=%08h RVALID=%b RREADY=%b RDATA=%08h RLAST=%b",
        $time,
        state,
        r_beat_idx,
        r_beats_total - 1,
        mem_re,
        mem_raddr_base,
        mem_rdata,
        s_rvalid,
        s_rready,
        s_rdata,
        s_rlast
      );
    end

  end

`endif*/

endmodule
// ============================================================================
// File       : axi_fifo_slave_top.sv
// Author     : <Your Name / Company>
// Date       : 2026-03-13
// Revision   : 1.0
// Description: Top-level AXI4 FIFO-backed slave
// Notes      :
//   - Instantiates write engine, read engine, and dual-port memory
//   - Exposes flat AXI4 slave ports (no SV interface on top-level as per user)
//   - Target >=100MHz; all outputs registered; no latches
//   - Supports FIXED/INCR/WRAP bursts, aligned and unaligned via WSTRB
// ============================================================================

module axi_fifo_slave_top
  #(parameter int unsigned ADDR_W     = 32,
    parameter int unsigned DATA_W     = 32,
    parameter int unsigned ID_W       = 4,
    parameter int unsigned USER_W     = 1,
    parameter int unsigned MEM_BYTES  = 64*1024,
    parameter int unsigned W_FIFO_DEPTH = 8,
    parameter int unsigned R_FIFO_DEPTH = 8)
  (
   input  logic                 aclk,
   input  logic                 areset_n,

   // AXI4 Slave Write Address Channel
   input  logic [ID_W-1:0]      s_awid,
   input  logic [ADDR_W-1:0]    s_awaddr,
   input  logic [7:0]           s_awlen,
   input  logic [2:0]           s_awsize,
   input  logic [1:0]           s_awburst,
   input  logic                 s_awlock,
   input  logic [3:0]           s_awcache,
   input  logic [2:0]           s_awprot,
   input  logic [3:0]           s_awqos,
   input  logic [3:0]           s_awregion,
   input  logic [USER_W-1:0]    s_awuser,
   input  logic                 s_awvalid,
   output logic                 s_awready,

   // AXI4 Slave Write Data Channel
   input  logic [DATA_W-1:0]    s_wdata,
   input  logic [(DATA_W/8)-1:0] s_wstrb,
   input  logic                 s_wlast,
   input  logic [USER_W-1:0]    s_wuser,
   input  logic                 s_wvalid,
   output logic                 s_wready,

   // AXI4 Slave Write Response Channel
   output logic [ID_W-1:0]      s_bid,
   output logic [1:0]           s_bresp,
   output logic [USER_W-1:0]    s_buser,
   output logic                 s_bvalid,
   input  logic                 s_bready,

   // AXI4 Slave Read Address Channel
   input  logic [ID_W-1:0]      s_arid,
   input  logic [ADDR_W-1:0]    s_araddr,
   input  logic [7:0]           s_arlen,
   input  logic [2:0]           s_arsize,
   input  logic [1:0]           s_arburst,
   input  logic                 s_arlock,
   input  logic [3:0]           s_arcache,
   input  logic [2:0]           s_arprot,
   input  logic [3:0]           s_arqos,
   input  logic [3:0]           s_arregion,
   input  logic [USER_W-1:0]    s_aruser,
   input  logic                 s_arvalid,
   output logic                 s_arready,

   // AXI4 Slave Read Data Channel
   output logic [ID_W-1:0]      s_rid,
   output logic [DATA_W-1:0]    s_rdata,
   output logic [1:0]           s_rresp,
   output logic                 s_rlast,
   output logic [USER_W-1:0]    s_ruser,
   output logic                 s_rvalid,
   input  logic                 s_rready
  );

  import axi_fifo_slave_pkg::*;

  // -----------------------------
  // Memory instance (dual-port)
  // -----------------------------
  // Write port A signals from write engine
  logic                 mem_we_a;
  logic [ADDR_W-1:0]    mem_waddr_base_a;
  logic [(DATA_W/8)-1:0] mem_wbe_a;
  logic [DATA_W-1:0]    mem_wdata_a;

  // Read port B signals from read engine
  logic                 mem_re_b;
  logic [ADDR_W-1:0]    mem_raddr_base_b;
  logic [DATA_W-1:0]    mem_rdata_b;
  
  //assign mem_wbe_a = s_wstrb;

  axi_mem #(
    .ADDR_W    (ADDR_W),
    .DATA_W    (DATA_W),
    .MEM_BYTES (MEM_BYTES)
  ) u_mem (
    .clk           (aclk),
    .rst_n         (areset_n),
    .a_we          (mem_we_a),
    .a_addr_base   (mem_waddr_base_a),
    .a_be          (mem_wbe_a),
    .a_wdata       (mem_wdata_a),
    .b_re          (mem_re_b),
    .b_addr_base   (mem_raddr_base_b),
    .b_rdata       (mem_rdata_b)
  );

  // -----------------------------
  // Write engine
  // -----------------------------
  axi_write_engine #(
    .ADDR_W        (ADDR_W),
    .DATA_W        (DATA_W),
    .ID_W          (ID_W),
    .USER_W        (USER_W),
    .W_FIFO_DEPTH  (W_FIFO_DEPTH)
  ) u_wr (
    .clk           (aclk),
    .rst_n         (areset_n),

    .s_awid        (s_awid),
    .s_awaddr      (s_awaddr),
    .s_awlen       (s_awlen),
    .s_awsize      (s_awsize),
    .s_awburst     (s_awburst),
    .s_awlock      (s_awlock),
    .s_awcache     (s_awcache),
    .s_awprot      (s_awprot),
    .s_awqos       (s_awqos),
    .s_awregion    (s_awregion),
    .s_awuser      (s_awuser),
    .s_awvalid     (s_awvalid),
    .s_awready     (s_awready),

    .s_wdata       (s_wdata),
    .s_wstrb       (s_wstrb),
    .s_wlast       (s_wlast),
    .s_wuser       (s_wuser),
    .s_wvalid      (s_wvalid),
    .s_wready      (s_wready),

    .s_bid         (s_bid),
    .s_bresp       (s_bresp),
    .s_buser       (s_buser),
    .s_bvalid      (s_bvalid),
    .s_bready      (s_bready),

    .mem_we        (mem_we_a),
    .mem_waddr_base(mem_waddr_base_a),
    .mem_wbe       (mem_wbe_a),
    .mem_wdata     (mem_wdata_a)
  );

  // -----------------------------
  // Read engine
  // -----------------------------
  axi_read_engine #(
    .ADDR_W        (ADDR_W),
    .DATA_W        (DATA_W),
    .ID_W          (ID_W),
    .USER_W        (USER_W),
    .R_FIFO_DEPTH  (R_FIFO_DEPTH)
  ) u_rd (
    .clk           (aclk),
    .rst_n         (areset_n),

    .s_arid        (s_arid),
    .s_araddr      (s_araddr),
    .s_arlen       (s_arlen),
    .s_arsize      (s_arsize),
    .s_arburst     (s_arburst),
    .s_arlock      (s_arlock),
    .s_arcache     (s_arcache),
    .s_arprot      (s_arprot),
    .s_arqos       (s_arqos),
    .s_arregion    (s_arregion),
    .s_aruser      (s_aruser),
    .s_arvalid     (s_arvalid),
    .s_arready     (s_arready),

    .s_rid         (s_rid),
    .s_rdata       (s_rdata),
    .s_rresp       (s_rresp),
    .s_rlast       (s_rlast),
    .s_ruser       (s_ruser),
    .s_rvalid      (s_rvalid),
    .s_rready      (s_rready),

    .mem_re        (mem_re_b),
    .mem_raddr_base(mem_raddr_base_b),
    .mem_rdata     (mem_rdata_b)
  );

endmodule