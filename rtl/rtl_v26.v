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
  #(
    parameter int unsigned ADDR_W    = 32,
    parameter int unsigned DATA_W    = 32,
    parameter int unsigned MEM_BYTES = 64 * 1024
  )
  (
    input  logic                       clk,
    input  logic                       rst_n,

    // ------------------------------------------------
    // Memory Write Port A
    // ------------------------------------------------
    input  logic                       a_we,
    input  logic [ADDR_W-1:0]          a_addr_base,
    input  logic [(DATA_W/8)-1:0]      a_be,
    input  logic [DATA_W-1:0]          a_wdata,

    // ------------------------------------------------
    // Memory Read Port B
    // ------------------------------------------------
    input  logic                       b_re,
    input  logic [ADDR_W-1:0]          b_addr_base,
    output logic [DATA_W-1:0]          b_rdata
  );

  // ================================================================
  // Local parameters
  // ================================================================

  localparam int unsigned STRB_W =
      DATA_W / 8;
 integer init_index;

  // ================================================================
  // Byte-addressable memory
  // ================================================================

  logic [7:0] mem [0:MEM_BYTES-1];
  
 `ifndef SYNTHESIS



  initial
  begin
    for (init_index = 0;
         init_index < MEM_BYTES;
         init_index++)
    begin
        mem[init_index] = 8'h00;
    end
 end

`endif


  // ================================================================
  // Internal memory addresses
  // ================================================================

  logic [ADDR_W-1:0] a_base;
  logic [ADDR_W-1:0] b_base;


  assign a_base =
      a_addr_base;

  assign b_base =
      b_addr_base;


 // ================================================================
// Write Port A
// ================================================================

integer i;


always @(posedge clk)
begin
    if (a_we)
    begin
        for (i = 0; i < STRB_W; i++)
        begin
            if (a_be[i])
            begin
                mem[(a_base + i) % MEM_BYTES] <=
                    a_wdata[8*i +: 8];
            end
        end
    end
end
  
  // ================================================================
  // Read Port B
  //
  // Registered read output with same-cycle write forwarding.
  //
  // Different address:
  //     Read existing memory.
  //
  // Same address and enabled write byte:
  //     Return new write data.
  //
  // Same address and disabled write byte:
  //     Return existing memory data.
  // ================================================================

  integer j;

  always_ff @(posedge clk or negedge rst_n)
  begin
      if (!rst_n)
      begin
          b_rdata <= '0;
      end
      else if (b_re)
      begin
          for (j = 0; j < STRB_W; j++)
          begin
              if (a_we &&
                  (a_base == b_base) &&
                  a_be[j])
              begin
                  /*
                   * Same-cycle read/write collision.
                   *
                   * Forward the newly written byte directly
                   * to the read output.
                   */
                  b_rdata[8*j +: 8] <=
                      a_wdata[8*j +: 8];
              end
              else
              begin
                  /*
                   * Normal registered memory read.
                   */
                  b_rdata[8*j +: 8] <=
                      mem[(b_base + j) % MEM_BYTES];
              end
          end
      end
  end


`ifndef SYNTHESIS

  // ================================================================
  // Simulation-only parameter checks
  // ================================================================

  initial
  begin
      if ((DATA_W % 8) != 0)
      begin
          $fatal(
              1,
              "[AXI_MEM] DATA_W=%0d must be divisible by 8",
              DATA_W
          );
      end

      if (MEM_BYTES < STRB_W)
      begin
          $fatal(
              1,
              "[AXI_MEM] MEM_BYTES=%0d must be at least STRB_W=%0d",
              MEM_BYTES,
              STRB_W
          );
      end
  end

`endif
  
 `ifndef SYNTHESIS

always_ff @(posedge clk)
begin
    if (rst_n)
    begin
        if (a_we && b_re)
        begin
            $display(
                "[MEM_RW] T=%0t WADDR=%08h RADDR=%08h SAME=%0b BE=%b WDATA=%08h RDATA=%08h",
                $time,
                a_base,
                b_base,
                (a_base == b_base),
                a_be,
                a_wdata,
                b_rdata
            );
        end

        if (a_we &&
            b_re &&
            (a_base == b_base))
        begin
            $display(
                "[MEM_FORWARD] T=%0t ADDR=%08h BE=%b WDATA=%08h",
                $time,
                a_base,
                a_be,
                a_wdata
            );
        end
    end
end

`endif


endmodule
// ============================================================================
// AXI4 FIFO Memory Slave - Fair Out-of-Order Engine Replacements
//
// Replace the existing axi_write_engine and axi_read_engine definitions with
// the two modules in this file. The existing package, sync_fifo, axi_addr_gen,
// axi_mem, and top-level port connections remain unchanged.
//
// Implemented scope
//   WRITE:
//     - Multiple outstanding AW acceptance through the existing AW FIFO.
//     - AXI4 W bursts remain associated with AW transactions in AW order.
//     - Memory writes remain in AW/W order.
//     - Completed B responses are stored in a selectable response table.
//     - Fair round-robin B response selection across eligible IDs.
//     - B responses may be returned out of order across different IDs.
//     - B responses remain ordered for the same ID and cannot starve.
//
//   READ:
//     - Multiple outstanding AR requests are stored in a context table.
//     - Fair round-robin burst-level read scheduling across different IDs.
//     - Same-ID read transaction order is preserved and cannot starve.
//     - A selected burst is completed before another burst is selected.
//     - R beats are buffered in an R response FIFO.
//
// Deliberately not implemented
//   - Read beat interleaving between transactions.
//   - RAW hazard detection or write-to-read forwarding.
//   - Exclusive access behavior and error-response generation.
// ============================================================================

module axi_write_engine
  #(
    parameter int unsigned ADDR_W                 = 32,
    parameter int unsigned DATA_W                 = 32,
    parameter int unsigned ID_W                   = 4,
    parameter int unsigned USER_W                 = 1,
    parameter int unsigned AW_FIFO_DEPTH          = 4,
    parameter int unsigned W_FIFO_DEPTH           = 8,
    parameter int unsigned B_REORDER_WAIT_CYCLES  = 16
  )
  (
    input  logic                      clk,
    input  logic                      rst_n,

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

    input  logic [DATA_W-1:0]         s_wdata,
    input  logic [(DATA_W/8)-1:0]     s_wstrb,
    input  logic                      s_wlast,
    input  logic [USER_W-1:0]         s_wuser,
    input  logic                      s_wvalid,
    output logic                      s_wready,

    output logic [ID_W-1:0]           s_bid,
    output logic [1:0]                s_bresp,
    output logic [USER_W-1:0]         s_buser,
    output logic                      s_bvalid,
    input  logic                      s_bready,

    output logic                      mem_we,
    output logic [ADDR_W-1:0]         mem_waddr_base,
    output logic [(DATA_W/8)-1:0]     mem_wbe,
    output logic [DATA_W-1:0]         mem_wdata
  );

  import axi_fifo_slave_pkg::*;

  localparam int unsigned STRB_W = DATA_W / 8;
  localparam int unsigned WENTRY_W = DATA_W + STRB_W + 1 + USER_W;
  localparam int unsigned AWENTRY_W = $bits(axi_awar_t);
  localparam int unsigned WR_OUT_CNT_W = (AW_FIFO_DEPTH <= 1) ? 1 : $clog2(AW_FIFO_DEPTH + 1);
  localparam int unsigned B_INDEX_W = (AW_FIFO_DEPTH <= 1) ? 1 : $clog2(AW_FIFO_DEPTH);
  localparam int unsigned B_COUNT_W = (AW_FIFO_DEPTH <= 1) ? 1 : $clog2(AW_FIFO_DEPTH + 1);
  localparam int unsigned B_WAIT_W = (B_REORDER_WAIT_CYCLES <= 1) ? 1 : $clog2(B_REORDER_WAIT_CYCLES + 1);

  typedef struct packed
  {
    logic [DATA_W-1:0]  data;
    logic [STRB_W-1:0]  strb;
    logic               last;
    logic [USER_W-1:0]  user;
  } wentry_t;

  typedef struct packed
  {
    logic                valid;
    logic [ID_W-1:0]     id;
    logic [1:0]          resp;
    logic [USER_W-1:0]   user;
    logic [31:0]         seq_no;
  } b_entry_t;

  typedef enum logic [2:0]
  {
    WR_IDLE,
    WR_POP_AW,
    WR_CAPTURE_AW,
    WR_WAIT_FIFO,
    WR_POP_FIFO,
    WR_CAPTURE_FIFO,
    WR_COMMIT
  } wr_state_e;

  wr_state_e state;

  axi_awar_t aw_reg;
  logic aw_active;
  logic [7:0] w_beats_total;
  logic [7:0] w_accepted_count;
  logic [7:0] w_beat_idx;

  logic aw_fifo_push;
  logic aw_fifo_pop;
  logic aw_fifo_full;
  logic aw_fifo_empty;
  logic [AWENTRY_W-1:0] aw_fifo_din;
  logic [AWENTRY_W-1:0] aw_fifo_dout;
  axi_awar_t aw_fifo_input;
  axi_awar_t aw_fifo_head;

  logic w_fifo_push;
  logic w_fifo_pop;
  logic w_fifo_full;
  logic w_fifo_empty;
  logic [WENTRY_W-1:0] w_fifo_din;
  logic [WENTRY_W-1:0] w_fifo_dout;
  wentry_t wcur_reg;

  logic [WR_OUT_CNT_W-1:0] wr_outstanding_count;
  logic aw_fire;
  logic b_fire;

  logic [ADDR_W-1:0] addr_n;
  logic [ADDR_W-1:0] base_n;
  logic [$clog2(STRB_W)-1:0] lower_lane;

  b_entry_t b_table [0:AW_FIFO_DEPTH-1];
  logic [AW_FIFO_DEPTH-1:0] b_eligible;
  logic b_free_exists;
  logic [B_INDEX_W-1:0] b_free_idx;
  logic b_sel_valid;
  logic [B_INDEX_W-1:0] b_sel_idx;
  logic [B_INDEX_W-1:0] b_active_idx;
  logic [B_INDEX_W-1:0] b_rr_ptr;
  logic [B_COUNT_W-1:0] b_pending_count;
  logic [31:0] b_seq_counter;
  logic [B_WAIT_W-1:0] b_wait_count;
  logic b_launch_allowed;

  logic final_commit;
  logic write_complete_fire;

  always_comb
  begin
    aw_fifo_input        = '0;
    aw_fifo_input.id     = s_awid;
    aw_fifo_input.addr   = s_awaddr;
    aw_fifo_input.len    = s_awlen;
    aw_fifo_input.size   = s_awsize;
    aw_fifo_input.burst  = s_awburst;
    aw_fifo_input.lock   = s_awlock;
    aw_fifo_input.cache  = s_awcache;
    aw_fifo_input.prot   = s_awprot;
    aw_fifo_input.qos    = s_awqos;
    aw_fifo_input.region = s_awregion;
    aw_fifo_input.user   = s_awuser;
  end

  assign aw_fifo_din  = aw_fifo_input;
  assign aw_fifo_head = axi_awar_t'(aw_fifo_dout);

  assign w_fifo_din = {s_wdata, s_wstrb, s_wlast, s_wuser};

  assign aw_fire = s_awvalid && s_awready;
  assign b_fire  = s_bvalid && s_bready;

  assign aw_fifo_push = aw_fire;
  assign aw_fifo_pop  = (state == WR_POP_AW);
  assign w_fifo_push  = s_wvalid && s_wready;
  assign w_fifo_pop   = (state == WR_POP_FIFO);

  assign s_awready = rst_n && !aw_fifo_full && (wr_outstanding_count < AW_FIFO_DEPTH);
  assign s_wready = rst_n && aw_active && !w_fifo_full && (w_accepted_count < w_beats_total);

  sync_fifo #(
    .WIDTH (AWENTRY_W),
    .DEPTH (AW_FIFO_DEPTH)
  ) u_awfifo (
    .clk   (clk),
    .rst_n (rst_n),
    .push  (aw_fifo_push),
    .din   (aw_fifo_din),
    .full  (aw_fifo_full),
    .pop   (aw_fifo_pop),
    .dout  (aw_fifo_dout),
    .empty (aw_fifo_empty),
    .level ()
  );

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

  assign final_commit = (w_beat_idx == (w_beats_total - 8'd1));
  assign write_complete_fire = (state == WR_COMMIT) && final_commit && b_free_exists;

  always_comb
  begin
    b_free_exists = 1'b0;
    b_free_idx    = '0;

    for (int i = 0; i < AW_FIFO_DEPTH; i++)
    begin
      if (!b_table[i].valid && !b_free_exists)
      begin
        b_free_exists = 1'b1;
        b_free_idx    = B_INDEX_W'(i);
      end
    end
  end

  always_comb
  begin
    b_pending_count = '0;

    for (int i = 0; i < AW_FIFO_DEPTH; i++)
    begin
      if (b_table[i].valid)
      begin
        b_pending_count = b_pending_count + 1'b1;
      end
    end
  end

  always_comb
  begin
    b_eligible = '0;

    for (int i = 0; i < AW_FIFO_DEPTH; i++)
    begin
      if (b_table[i].valid)
      begin
        b_eligible[i] = 1'b1;

        for (int j = 0; j < AW_FIFO_DEPTH; j++)
        begin
          if (b_table[j].valid && (b_table[j].id == b_table[i].id) && (b_table[j].seq_no < b_table[i].seq_no))
          begin
            b_eligible[i] = 1'b0;
          end
        end
      end
    end
  end

  always_comb
  begin
    int unsigned scan_idx;

    b_sel_valid = 1'b0;
    b_sel_idx   = '0;

    for (int offset = 0; offset < AW_FIFO_DEPTH; offset++)
    begin
      scan_idx = b_rr_ptr + offset;

      if (scan_idx >= AW_FIFO_DEPTH)
      begin
        scan_idx = scan_idx - AW_FIFO_DEPTH;
      end

      if (b_eligible[scan_idx] && !b_sel_valid)
      begin
        b_sel_valid = 1'b1;
        b_sel_idx   = B_INDEX_W'(scan_idx);
      end
    end
  end

  always_comb
  begin
    b_launch_allowed = 1'b0;

    if (b_pending_count >= 2)
    begin
      b_launch_allowed = 1'b1;
    end
    else if ((b_pending_count != 0) && (b_pending_count == wr_outstanding_count))
    begin
      b_launch_allowed = 1'b1;
    end
    else if ((b_pending_count != 0) && (b_wait_count >= B_REORDER_WAIT_CYCLES - 1))
    begin
      b_launch_allowed = 1'b1;
    end
  end

  always_comb
  begin
    mem_we         = 1'b0;
    mem_waddr_base = base_n;
    mem_wbe        = wcur_reg.strb;
    mem_wdata      = wcur_reg.data;

    if (state == WR_COMMIT)
    begin
      if (!final_commit || b_free_exists)
      begin
        mem_we = 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state              <= WR_IDLE;
      aw_reg             <= '0;
      aw_active          <= 1'b0;
      w_beats_total      <= '0;
      w_accepted_count   <= '0;
      w_beat_idx         <= '0;
      wcur_reg           <= '0;
    end
    else
    begin
      if (w_fifo_push)
      begin
        w_accepted_count <= w_accepted_count + 8'd1;
      end

      case (state)
        WR_IDLE:
        begin
          aw_active        <= 1'b0;
          w_beats_total    <= '0;
          w_accepted_count <= '0;
          w_beat_idx       <= '0;
          wcur_reg         <= '0;

          if (!aw_fifo_empty)
          begin
            state <= WR_POP_AW;
          end
        end

        WR_POP_AW:
        begin
          state <= WR_CAPTURE_AW;
        end

        WR_CAPTURE_AW:
        begin
          aw_reg             <= aw_fifo_head;
          aw_active          <= 1'b1;
          w_beats_total      <= aw_fifo_head.len + 8'd1;
          w_accepted_count   <= '0;
          w_beat_idx         <= '0;
          wcur_reg           <= '0;
          state              <= WR_WAIT_FIFO;
        end

        WR_WAIT_FIFO:
        begin
          if (!w_fifo_empty)
          begin
            state <= WR_POP_FIFO;
          end
        end

        WR_POP_FIFO:
        begin
          state <= WR_CAPTURE_FIFO;
        end

        WR_CAPTURE_FIFO:
        begin
          wcur_reg <= wentry_t'(w_fifo_dout);
          state    <= WR_COMMIT;
        end

        WR_COMMIT:
        begin
          if (!final_commit)
          begin
            w_beat_idx <= w_beat_idx + 8'd1;
            state      <= WR_WAIT_FIFO;
          end
          else if (b_free_exists)
          begin
            aw_active          <= 1'b0;
            w_beats_total      <= '0;
            w_accepted_count   <= '0;
            w_beat_idx         <= '0;
            wcur_reg           <= '0;
            state              <= WR_IDLE;
          end
        end

        default:
        begin
          state              <= WR_IDLE;
          aw_reg             <= '0;
          aw_active          <= 1'b0;
          w_beats_total      <= '0;
          w_accepted_count   <= '0;
          w_beat_idx         <= '0;
          wcur_reg           <= '0;
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      for (int i = 0; i < AW_FIFO_DEPTH; i++)
      begin
        b_table[i] <= '0;
      end

      b_seq_counter <= '0;
    end
    else
    begin
      if (b_fire)
      begin
        b_table[b_active_idx].valid <= 1'b0;
      end

      if (write_complete_fire)
      begin
        b_table[b_free_idx].valid  <= 1'b1;
        b_table[b_free_idx].id     <= aw_reg.id;
        b_table[b_free_idx].resp   <= AXI_RESP_OKAY;
        b_table[b_free_idx].user   <= '0;
        b_table[b_free_idx].seq_no <= b_seq_counter;
        b_seq_counter              <= b_seq_counter + 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      s_bid        <= '0;
      s_bresp      <= AXI_RESP_OKAY;
      s_buser      <= '0;
      s_bvalid     <= 1'b0;
      b_active_idx <= '0;
      b_rr_ptr     <= (AW_FIFO_DEPTH > 1) ? B_INDEX_W'(1) : '0;
      b_wait_count <= '0;
    end
    else
    begin
      if (s_bvalid)
      begin
        if (s_bready)
        begin
          s_bvalid <= 1'b0;

          if (b_active_idx == AW_FIFO_DEPTH - 1)
          begin
            b_rr_ptr <= '0;
          end
          else
          begin
            b_rr_ptr <= b_active_idx + 1'b1;
          end
        end
      end
      else if (b_sel_valid && b_launch_allowed)
      begin
        s_bid        <= b_table[b_sel_idx].id;
        s_bresp      <= b_table[b_sel_idx].resp;
        s_buser      <= b_table[b_sel_idx].user;
        s_bvalid     <= 1'b1;
        b_active_idx <= b_sel_idx;
      end

      if ((b_pending_count == 0) || (b_sel_valid && b_launch_allowed) || b_fire)
      begin
        b_wait_count <= '0;
      end
      else if (b_wait_count < B_REORDER_WAIT_CYCLES)
      begin
        b_wait_count <= b_wait_count + 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      wr_outstanding_count <= '0;
    end
    else
    begin
      case ({aw_fire, b_fire})
        2'b10:
        begin
          wr_outstanding_count <= wr_outstanding_count + 1'b1;
        end

        2'b01:
        begin
          wr_outstanding_count <= wr_outstanding_count - 1'b1;
        end

        default:
        begin
          wr_outstanding_count <= wr_outstanding_count;
        end
      endcase
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk)
  begin
    if (rst_n)
    begin
      if ((state == WR_COMMIT) && mem_we)
      begin
        if (wcur_reg.last !== final_commit)
        begin
          $error("[AXI_WRITE_ENGINE] WLAST mismatch: BID=%0d beat=%0d total=%0d WLAST=%0b", aw_reg.id, w_beat_idx, w_beats_total, wcur_reg.last);
        end
      end

      if (write_complete_fire && !b_free_exists)
      begin
        $error("[AXI_WRITE_ENGINE] B response table overflow");
      end

      if (b_fire && (wr_outstanding_count == 0))
      begin
        $error("[AXI_WRITE_ENGINE] Outstanding counter underflow");
      end
    end
  end
`endif

endmodule


module axi_read_engine
  #(
    parameter int unsigned ADDR_W        = 32,
    parameter int unsigned DATA_W        = 32,
    parameter int unsigned ID_W          = 4,
    parameter int unsigned USER_W                 = 1,
    parameter int unsigned AR_FIFO_DEPTH          = 4,
    parameter int unsigned R_FIFO_DEPTH           = 8,
    parameter int unsigned RD_REORDER_WAIT_CYCLES = 4
  )
  (
    input  logic                      clk,
    input  logic                      rst_n,

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

    output logic [ID_W-1:0]           s_rid,
    output logic [DATA_W-1:0]         s_rdata,
    output logic [1:0]                s_rresp,
    output logic                      s_rlast,
    output logic [USER_W-1:0]         s_ruser,
    output logic                      s_rvalid,
    input  logic                      s_rready,

    output logic                      mem_re,
    output logic [ADDR_W-1:0]         mem_raddr_base,
    input  logic [DATA_W-1:0]         mem_rdata
  );

  import axi_fifo_slave_pkg::*;

  localparam int unsigned STRB_W = DATA_W / 8;
  localparam int unsigned RD_INDEX_W = (AR_FIFO_DEPTH <= 1) ? 1 : $clog2(AR_FIFO_DEPTH);
  localparam int unsigned RD_COUNT_W = (AR_FIFO_DEPTH <= 1) ? 1 : $clog2(AR_FIFO_DEPTH + 1);
  localparam int unsigned RD_WAIT_W = (RD_REORDER_WAIT_CYCLES <= 1) ? 1 : $clog2(RD_REORDER_WAIT_CYCLES + 1);

  typedef struct packed
  {
    logic                  valid;
    logic [ID_W-1:0]       id;
    logic [ADDR_W-1:0]     addr;
    logic [7:0]            len;
    logic [2:0]            size;
    logic [1:0]            burst;
    logic                  lock;
    logic [3:0]            cache;
    logic [2:0]            prot;
    logic [3:0]            qos;
    logic [3:0]            region;
    logic [USER_W-1:0]     user;
    logic [31:0]           seq_no;
  } rd_ctx_t;

  typedef struct packed
  {
    logic [ID_W-1:0]       id;
    logic [DATA_W-1:0]     data;
    logic [1:0]            resp;
    logic                  last;
    logic [USER_W-1:0]     user;
  } r_entry_t;

  localparam int unsigned RENTRY_W = $bits(r_entry_t);

  typedef enum logic [1:0]
  {
    RD_IDLE,
    RD_ISSUE,
    RD_CAPTURE_MEMORY
  } rd_gen_state_e;

  typedef enum logic [1:0]
  {
    R_OUT_IDLE,
    R_OUT_POP,
    R_OUT_CAPTURE,
    R_OUT_HOLD
  } r_out_state_e;

  rd_ctx_t rd_ctx [0:AR_FIFO_DEPTH-1];
  logic [AR_FIFO_DEPTH-1:0] rd_eligible;
  logic rd_free_exists;
  logic [RD_INDEX_W-1:0] rd_free_idx;
  logic rd_sel_valid;
  logic [RD_INDEX_W-1:0] rd_sel_idx;
  logic [RD_INDEX_W-1:0] rd_rr_ptr;
  logic [RD_COUNT_W-1:0] rd_pending_count;
  logic [RD_WAIT_W-1:0] rd_wait_count;
  logic rd_launch_allowed;
  logic [31:0] rd_seq_counter;

  rd_gen_state_e rd_gen_state;
  rd_ctx_t active_read;
  logic [RD_INDEX_W-1:0] active_slot;
  logic [7:0] active_beat_idx;
  logic rd_context_complete;

  logic [ADDR_W-1:0] addr_n;
  logic [ADDR_W-1:0] base_n;
  logic [$clog2(STRB_W)-1:0] lower_lane;
  logic [DATA_W-1:0] packed_memory_data;

  r_entry_t r_fifo_input;
  r_entry_t r_fifo_head;
  logic [RENTRY_W-1:0] r_fifo_din;
  logic [RENTRY_W-1:0] r_fifo_dout;
  logic r_fifo_push;
  logic r_fifo_pop;
  logic r_fifo_full;
  logic r_fifo_empty;

  r_out_state_e r_out_state;

  logic ar_fire;
  logic r_done_fire;
  logic [RD_COUNT_W-1:0] rd_outstanding_count;

  assign ar_fire     = s_arvalid && s_arready;
  assign r_done_fire = s_rvalid && s_rready && s_rlast;

  always_comb
  begin
    rd_free_exists = 1'b0;
    rd_free_idx    = '0;

    for (int i = 0; i < AR_FIFO_DEPTH; i++)
    begin
      if (!rd_ctx[i].valid && !rd_free_exists)
      begin
        rd_free_exists = 1'b1;
        rd_free_idx    = RD_INDEX_W'(i);
      end
    end
  end

  assign s_arready = rst_n && rd_free_exists && (rd_outstanding_count < AR_FIFO_DEPTH);

  always_comb
  begin
    rd_pending_count = '0;

    for (int i = 0; i < AR_FIFO_DEPTH; i++)
    begin
      if (rd_ctx[i].valid)
      begin
        rd_pending_count = rd_pending_count + 1'b1;
      end
    end
  end

  always_comb
  begin
    rd_eligible = '0;

    for (int i = 0; i < AR_FIFO_DEPTH; i++)
    begin
      if (rd_ctx[i].valid)
      begin
        rd_eligible[i] = 1'b1;

        for (int j = 0; j < AR_FIFO_DEPTH; j++)
        begin
          if (rd_ctx[j].valid && (rd_ctx[j].id == rd_ctx[i].id) && (rd_ctx[j].seq_no < rd_ctx[i].seq_no))
          begin
            rd_eligible[i] = 1'b0;
          end
        end
      end
    end
  end

  always_comb
  begin
    int unsigned scan_idx;

    rd_sel_valid = 1'b0;
    rd_sel_idx   = '0;

    for (int offset = 0; offset < AR_FIFO_DEPTH; offset++)
    begin
      scan_idx = rd_rr_ptr + offset;

      if (scan_idx >= AR_FIFO_DEPTH)
      begin
        scan_idx = scan_idx - AR_FIFO_DEPTH;
      end

      if (rd_eligible[scan_idx] && !rd_sel_valid)
      begin
        rd_sel_valid = 1'b1;
        rd_sel_idx   = RD_INDEX_W'(scan_idx);
      end
    end
  end

  always_comb
  begin
    rd_launch_allowed = 1'b0;

    if (rd_pending_count >= 2)
    begin
      rd_launch_allowed = 1'b1;
    end
    else if ((rd_pending_count != 0) && (rd_wait_count >= RD_REORDER_WAIT_CYCLES - 1))
    begin
      rd_launch_allowed = 1'b1;
    end
  end

  axi_addr_gen #(
    .ADDR_W (ADDR_W),
    .DATA_W (DATA_W)
  ) u_addr_gen_r (
    .start_addr      (active_read.addr),
    .size            (active_read.size),
    .burst           (active_read.burst),
    .len             (active_read.len),
    .beat_idx        (active_beat_idx),
    .addr_n          (addr_n),
    .bus_base_addr   (base_n),
    .lower_byte_lane (lower_lane)
  );

  assign mem_raddr_base = base_n;

  always_comb
  begin
    packed_memory_data = '0;

    for (int lane = 0; lane < STRB_W; lane++)
    begin
      if ((lane >= lower_lane) && (lane < lower_lane + (1 << active_read.size)))
      begin
        packed_memory_data[8*lane +: 8] = mem_rdata[8*lane +: 8];
      end
    end
  end

  always_comb
  begin
    r_fifo_input      = '0;
    r_fifo_input.id   = active_read.id;
    r_fifo_input.data = packed_memory_data;
    r_fifo_input.resp = AXI_RESP_OKAY;
    r_fifo_input.last = (active_beat_idx == active_read.len);
    r_fifo_input.user = '0;
  end

  assign r_fifo_din  = r_fifo_input;
  assign r_fifo_head = r_entry_t'(r_fifo_dout);
  assign r_fifo_push = (rd_gen_state == RD_CAPTURE_MEMORY);
  assign r_fifo_pop  = (r_out_state == R_OUT_POP);

  sync_fifo #(
    .WIDTH (RENTRY_W),
    .DEPTH (R_FIFO_DEPTH)
  ) u_rfifo (
    .clk   (clk),
    .rst_n (rst_n),
    .push  (r_fifo_push),
    .din   (r_fifo_din),
    .full  (r_fifo_full),
    .pop   (r_fifo_pop),
    .dout  (r_fifo_dout),
    .empty (r_fifo_empty),
    .level ()
  );

  always_comb
  begin
    mem_re = 1'b0;

    if ((rd_gen_state == RD_ISSUE) && !r_fifo_full)
    begin
      mem_re = 1'b1;
    end
  end

  assign rd_context_complete = (rd_gen_state == RD_CAPTURE_MEMORY) && (active_beat_idx == active_read.len);

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      for (int i = 0; i < AR_FIFO_DEPTH; i++)
      begin
        rd_ctx[i] <= '0;
      end

      rd_seq_counter <= '0;
    end
    else
    begin
      if (rd_context_complete)
      begin
        rd_ctx[active_slot].valid <= 1'b0;
      end

      if (ar_fire)
      begin
        rd_ctx[rd_free_idx].valid  <= 1'b1;
        rd_ctx[rd_free_idx].id     <= s_arid;
        rd_ctx[rd_free_idx].addr   <= s_araddr;
        rd_ctx[rd_free_idx].len    <= s_arlen;
        rd_ctx[rd_free_idx].size   <= s_arsize;
        rd_ctx[rd_free_idx].burst  <= s_arburst;
        rd_ctx[rd_free_idx].lock   <= s_arlock;
        rd_ctx[rd_free_idx].cache  <= s_arcache;
        rd_ctx[rd_free_idx].prot   <= s_arprot;
        rd_ctx[rd_free_idx].qos    <= s_arqos;
        rd_ctx[rd_free_idx].region <= s_arregion;
        rd_ctx[rd_free_idx].user   <= s_aruser;
        rd_ctx[rd_free_idx].seq_no <= rd_seq_counter;
        rd_seq_counter             <= rd_seq_counter + 1'b1;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      rd_gen_state    <= RD_IDLE;
      active_read     <= '0;
      active_slot     <= '0;
      active_beat_idx <= '0;
      rd_rr_ptr        <= (AR_FIFO_DEPTH > 1) ? RD_INDEX_W'(1) : '0;
      rd_wait_count    <= '0;
    end
    else
    begin
      case (rd_gen_state)
        RD_IDLE:
        begin
          active_beat_idx <= '0;

          if (rd_sel_valid && rd_launch_allowed)
          begin
            active_read     <= rd_ctx[rd_sel_idx];
            active_slot     <= rd_sel_idx;
            active_beat_idx <= '0;
            rd_gen_state    <= RD_ISSUE;
            rd_wait_count   <= '0;

            if (rd_sel_idx == AR_FIFO_DEPTH - 1)
            begin
              rd_rr_ptr <= '0;
            end
            else
            begin
              rd_rr_ptr <= rd_sel_idx + 1'b1;
            end
          end
          else if (rd_pending_count == 0)
          begin
            rd_wait_count <= '0;
          end
          else if (rd_wait_count < RD_REORDER_WAIT_CYCLES)
          begin
            rd_wait_count <= rd_wait_count + 1'b1;
          end
        end

        RD_ISSUE:
        begin
          if (!r_fifo_full)
          begin
            rd_gen_state <= RD_CAPTURE_MEMORY;
          end
        end

        RD_CAPTURE_MEMORY:
        begin
          if (active_beat_idx == active_read.len)
          begin
            active_beat_idx <= '0;
            rd_gen_state    <= RD_IDLE;
          end
          else
          begin
            active_beat_idx <= active_beat_idx + 8'd1;
            rd_gen_state    <= RD_ISSUE;
          end
        end

        default:
        begin
          rd_gen_state    <= RD_IDLE;
          active_read     <= '0;
          active_slot     <= '0;
          active_beat_idx <= '0;
          rd_wait_count    <= '0;
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      r_out_state <= R_OUT_IDLE;
      s_rid       <= '0;
      s_rdata     <= '0;
      s_rresp     <= AXI_RESP_OKAY;
      s_rlast     <= 1'b0;
      s_ruser     <= '0;
      s_rvalid    <= 1'b0;
    end
    else
    begin
      case (r_out_state)
        R_OUT_IDLE:
        begin
          s_rvalid <= 1'b0;

          if (!r_fifo_empty)
          begin
            r_out_state <= R_OUT_POP;
          end
        end

        R_OUT_POP:
        begin
          r_out_state <= R_OUT_CAPTURE;
        end

        R_OUT_CAPTURE:
        begin
          s_rid       <= r_fifo_head.id;
          s_rdata     <= r_fifo_head.data;
          s_rresp     <= r_fifo_head.resp;
          s_rlast     <= r_fifo_head.last;
          s_ruser     <= r_fifo_head.user;
          s_rvalid    <= 1'b1;
          r_out_state <= R_OUT_HOLD;
        end

        R_OUT_HOLD:
        begin
          if (s_rvalid && s_rready)
          begin
            s_rvalid <= 1'b0;

            if (!r_fifo_empty)
            begin
              r_out_state <= R_OUT_POP;
            end
            else
            begin
              r_out_state <= R_OUT_IDLE;
            end
          end
        end

        default:
        begin
          r_out_state <= R_OUT_IDLE;
          s_rvalid    <= 1'b0;
          s_rlast     <= 1'b0;
        end
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      rd_outstanding_count <= '0;
    end
    else
    begin
      case ({ar_fire, r_done_fire})
        2'b10:
        begin
          rd_outstanding_count <= rd_outstanding_count + 1'b1;
        end

        2'b01:
        begin
          rd_outstanding_count <= rd_outstanding_count - 1'b1;
        end

        default:
        begin
          rd_outstanding_count <= rd_outstanding_count;
        end
      endcase
    end
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk)
  begin
    if (rst_n)
    begin
      if (r_fifo_push && r_fifo_full)
      begin
        $error("[AXI_READ_ENGINE] Push attempted while R FIFO full");
      end

      if (ar_fire && !rd_free_exists)
      begin
        $error("[AXI_READ_ENGINE] Read context table overflow");
      end

      if (r_done_fire && (rd_outstanding_count == 0))
      begin
        $error("[AXI_READ_ENGINE] Outstanding counter underflow");
      end
    end
  end
`endif

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
	parameter int unsigned AW_FIFO_DEPTH = 4,
    parameter int unsigned W_FIFO_DEPTH = 8,
    parameter int unsigned AR_FIFO_DEPTH = 4,
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
    .AW_FIFO_DEPTH (AW_FIFO_DEPTH),
    .W_FIFO_DEPTH  (W_FIFO_DEPTH)) 
    u_wr (
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
    .AR_FIFO_DEPTH (AR_FIFO_DEPTH),
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