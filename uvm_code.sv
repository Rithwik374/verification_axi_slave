// Code your testbench here
// or browse Examples
// Code your testbench here
// or browse Examples
package pkg;
import uvm_pkg::*;
import axi_fifo_slave_pkg::*;
`include "uvm_macros.svh"
class wr_config extends uvm_object;
    `uvm_object_utils(wr_config)
	virtual axi_fifo_slave_if vif;
	function new(string name = "wr_config");
	       super.new(name);
	endfunction 
	uvm_active_passive_enum is_active;
endclass

class rd_config extends uvm_object;
    `uvm_object_utils(rd_config)
	virtual axi_fifo_slave_if vif;
	function new(string name = "rd_config");
	       super.new(name);
	endfunction 
	uvm_active_passive_enum is_active;
endclass

class env_config extends uvm_object;
    `uvm_object_utils(env_config)
	 wr_config wr_cfg[];
	 rd_config rd_cfg[];
	 int no_of_wr_agents = 0;
	 int no_of_rd_agents = 0;


	 function new(string name = "env_config");
	          super.new(name);
	 endfunction
	 
endclass

	
class seq_item extends uvm_sequence_item;
   `uvm_object_utils(seq_item)
   
    //axi_fifo_slave_pkg axi_pkg;
	
	rand axi_awar_t  wr_addr_channel;
	rand axi_wbeat_t wr_data_channel[];
	rand axi_awar_t  rd_addr_channel;
	rand axi_bresp_t wr_resp_channel;
	rand axi_rbeat_t rd_data_channel[];
	static int wr_trans_done = 0;
	static int rd_trans_done = 0;
    function new(string name = "seq_item");
            super.new(name);
    endfunction
	
    constraint wr_ids{wr_addr_channel.id inside {[0:15]};}
    constraint rd_ids{rd_addr_channel.id inside {[0:15]};}
    constraint c2{wr_data_channel.size() == wr_addr_channel.len+1;}

	constraint c3{rd_data_channel.size() == rd_addr_channel.len+1;}
    constraint c_data {
    foreach (wr_data_channel[i]) {
        wr_data_channel[i].data != '0;
    }
}
    constraint c_addr{
    wr_addr_channel.addr inside {[0:MEM_BYTES-1]};
    }
	
	constraint rd_addr{rd_addr_channel.addr == wr_addr_channel.addr;}

    constraint wr_last{foreach(wr_data_channel[i])
	                   wr_data_channel[i].last == (i == wr_data_channel.size()-1);}
    
	constraint burst{wr_addr_channel.burst != 2'b11;
	                 rd_addr_channel.burst == wr_addr_channel.burst;}
					 
	constraint len{wr_addr_channel.len inside {[1:15]};
	               rd_addr_channel.len == wr_addr_channel.len;}
	
	constraint bur_len{wr_addr_channel.burst == 2 -> wr_addr_channel.len inside {1,3,7,15};
                   	   rd_addr_channel.burst == 2 -> rd_addr_channel.len inside {1,3,7,15};
					  }
	
    constraint size{wr_addr_channel.size inside {0,1,2};
	                rd_addr_channel.size == wr_addr_channel.size;}
	
	constraint unused_wr{
	                  wr_addr_channel.lock   == 0;
	                  wr_addr_channel.cache  == 0;
					  wr_addr_channel.prot   == 0;
					  wr_addr_channel.qos    == 0;
					  wr_addr_channel.region == 0;
					  wr_addr_channel.user   == 0;
                      foreach(wr_data_channel[i])
                      wr_data_channel[i].user   == 0;
					  }
    
	constraint unused_rd{
	                  rd_addr_channel.lock   == 0;
	                  rd_addr_channel.cache  == 0;
					  rd_addr_channel.prot   == 0;
					  rd_addr_channel.qos    == 0;
					  rd_addr_channel.region == 0;
					  rd_addr_channel.user   == 0;
                      foreach(rd_data_channel[i])
                      rd_data_channel[i].user   == 0;
					  }
	int unsigned w_addr[];
	int unsigned r_addr[];
	
	
	
	function void post_randomize();

    wr_addr_calc();

    rd_addr_calc();

    strobe_calc();


   endfunction
	
	function void wr_addr_calc();


	    int unsigned wburst_len         =  wr_addr_channel.len+1;
	    int unsigned start_addr         =  wr_addr_channel.addr;
		int unsigned data_bus_bytes     =  (DATA_W/8);
		int unsigned no_of_bytes        =  1 << wr_addr_channel.size;
		int unsigned aligned_addr       =  int'(start_addr/no_of_bytes)*no_of_bytes;
	    int unsigned wrap_boundary      =  (int'(start_addr/(no_of_bytes*wburst_len)))*(no_of_bytes*wburst_len);
		int unsigned wrap_region        =  wrap_boundary + (no_of_bytes*wburst_len);
		
		
		bit wrapped;
		int unsigned temp ;
		
		
		w_addr = new[wburst_len];
		w_addr[0] = start_addr;

		case(wr_addr_channel.burst)
		    AXI_BURST_FIXED:
              begin
		        for(int i=1;i<wburst_len;i++)
                    begin
			         w_addr[i]          = start_addr;
                    // $display("Beat %0d ---> Addr = %h",i,w_addr[i]);
                    end
		     end

		    AXI_BURST_INCR: 
		     begin
			    for(int i=1;i<wburst_len;i++)
                    begin
				     w_addr[i]          = aligned_addr + ((i)*no_of_bytes);
                     // $display("Beat %0d ---> Addr = %h",i,w_addr[i]);
			 end
             end
		    AXI_BURST_WRAP:
		     begin
			    temp = aligned_addr;
			    for(int i=1 ;i<wburst_len ;i++)
				  begin
                    temp = temp + no_of_bytes;
					if(temp >= wrap_region)
					   temp   = wrap_boundary;
					   
					w_addr[i] = temp;  
                    
               //  $display("Beat %0d ---> Addr = %h",i,w_addr[i]);
             end	
			 
            end	
        endcase	
       endfunction 
		
		 function void do_copy(uvm_object rhs);

        seq_item rhs_tr;

        super.do_copy(rhs);

        if (!$cast(rhs_tr, rhs))
        begin
            `uvm_fatal("COPY_ERROR",
                       "Failed to cast object into seq_item")
        end

        wr_addr_channel = rhs_tr.wr_addr_channel;
        rd_addr_channel = rhs_tr.rd_addr_channel;
        wr_resp_channel = rhs_tr.wr_resp_channel;

        wr_data_channel =
            new[rhs_tr.wr_data_channel.size()];

        foreach (rhs_tr.wr_data_channel[i])
        begin
            wr_data_channel[i] =
                rhs_tr.wr_data_channel[i];
        end

        rd_data_channel =
            new[rhs_tr.rd_data_channel.size()];

        foreach (rhs_tr.rd_data_channel[i])
        begin
            rd_data_channel[i] =
                rhs_tr.rd_data_channel[i];
        end

        w_addr = new[rhs_tr.w_addr.size()];

        foreach (rhs_tr.w_addr[i])
        begin
            w_addr[i] = rhs_tr.w_addr[i];
        end

        r_addr = new[rhs_tr.r_addr.size()];

        foreach (rhs_tr.r_addr[i])
        begin
            r_addr[i] = rhs_tr.r_addr[i];
        end

    endfunction
   
   	


      
      
	function void rd_addr_calc();
	    int unsigned rburst_len         =  rd_addr_channel.len+1;
	    int unsigned start_addr         =  rd_addr_channel.addr;
		int unsigned data_bus_bytes     =  (DATA_W/8);
		int unsigned no_of_bytes        =  1 << rd_addr_channel.size;
		int unsigned aligned_addr       =  int'(start_addr/no_of_bytes)*no_of_bytes;
	    int unsigned wrap_boundary      =  (int'(start_addr/(no_of_bytes*rburst_len)))*(no_of_bytes*rburst_len);
		int unsigned wrap_region        =  wrap_boundary + (no_of_bytes*rburst_len);
		
		
		bit rdapped;
		int unsigned temp ;
		
		
		r_addr = new[rburst_len];
		r_addr[0] = start_addr;
		case(rd_addr_channel.burst)
		    0:
		     begin
		        for(int i=1;i<rburst_len;i++)
                  begin
			         r_addr[i]          = start_addr;
                    //$display("Beat %0d ---> Addr = %h",i,r_addr[i]);
                  end
		     end

		   1: 
		     begin
			    for(int i=1;i<rburst_len;i++)
                  begin
				     r_addr[i]          = aligned_addr + ((i)*no_of_bytes);
                    //$display("Beat %0d ---> Addr = %h",i,r_addr[i]);
                  end
			 end
		    2:
		     begin
			    temp = aligned_addr;
			    for(int i=1 ;i<rburst_len ;i++)
				  begin
                    temp = temp + no_of_bytes;
                    if(temp >= wrap_region)
					   temp   = wrap_boundary;
					   
					r_addr[i] = temp;   
             end	
			 
            end

        endcase			
    endfunction 		
		     
	function void strobe_calc();

    int unsigned start_addr;
    int unsigned data_bus_bytes;
    int unsigned no_of_bytes;
    int unsigned aligned_addr;
    int unsigned burst_len;

    int unsigned lower_byte_lane_0;
    int unsigned upper_byte_lane_0;

    int unsigned lower_byte_lane;
    int unsigned upper_byte_lane;

    start_addr     = wr_addr_channel.addr;
    data_bus_bytes = DATA_W / 8;
    no_of_bytes    = 1 << wr_addr_channel.size;
    aligned_addr   = (start_addr / no_of_bytes) * no_of_bytes;
    burst_len      = wr_addr_channel.len + 1;

    lower_byte_lane_0 = start_addr % data_bus_bytes;

    upper_byte_lane_0 =
        lower_byte_lane_0 + no_of_bytes - 1;

    if (upper_byte_lane_0 >= data_bus_bytes)
        upper_byte_lane_0 = data_bus_bytes - 1;

    foreach (wr_data_channel[i])
        wr_data_channel[i].strb = '0;

    for (int j = lower_byte_lane_0;
             j <= upper_byte_lane_0;
             j++)
    begin
        wr_data_channel[0].strb[j] = 1'b1;
    end

    for (int i = 1; i < burst_len; i++)
    begin
        lower_byte_lane =
            w_addr[i] % data_bus_bytes;

        upper_byte_lane =
            lower_byte_lane + no_of_bytes - 1;

        if (upper_byte_lane >= data_bus_bytes)
            upper_byte_lane = data_bus_bytes - 1;

        for (int j = lower_byte_lane;
                 j <= upper_byte_lane;
                 j++)
        begin
            wr_data_channel[i].strb[j] = 1'b1;
        end
    end

endfunction
		
endclass

class wr_seq extends uvm_sequence#(seq_item);
  `uvm_object_utils(wr_seq)
    seq_item req;
    function new(string name = "wr_seq");
            super.new(name);
    endfunction
	
    task body();
	  req = seq_item::type_id::create("req");
      start_item(req);
	   assert(req.randomize());
      finish_item(req);
	endtask
endclass

class fixed_seq extends wr_seq;
   `uvm_object_utils(fixed_seq)
   
    function new(string name = "fixed_seq");
	         super.new(name);
    endfunction
	task body();
	   req = seq_item::type_id::create("req");
	  start_item(req);
	   assert(req.randomize()with {wr_addr_channel.burst == 0;});
      finish_item(req);
	endtask 
endclass

class inc_align_seq extends wr_seq;
   `uvm_object_utils(inc_align_seq)
   
    function new(string name = "inc_align_seq");
	         super.new(name);
    endfunction
	task body();
	   req = seq_item::type_id::create("req");
	  start_item(req);
	   assert(req.randomize()with {wr_addr_channel.burst == 1;
	                                if(wr_addr_channel.size == 1)
	                                   wr_addr_channel.addr%2 == 0;
									if(wr_addr_channel.size == 2)
									   wr_addr_channel.addr%4 == 0;});
      finish_item(req);
	endtask 
endclass

class inc_unalign_seq extends wr_seq;
   `uvm_object_utils(inc_unalign_seq)
   
    function new(string name = "inc_unalign_seq");
	         super.new(name);
    endfunction
	task body();
	   req = seq_item::type_id::create("req");
	   start_item(req);
	   assert(req.randomize()with {wr_addr_channel.burst == 1;
	                               wr_addr_channel.size inside {2,4};
	                                if(wr_addr_channel.size == 1)
	                                   wr_addr_channel.addr%2 != 0;
									if(wr_addr_channel.size == 2)
									   wr_addr_channel.addr%4 != 0;});
      finish_item(req);
	endtask 
endclass

class wrap_align_seq extends wr_seq;
   `uvm_object_utils(wrap_align_seq)
   
    function new(string name = "wrap_align_seq");
	         super.new(name);
    endfunction
	task body();
	   req = seq_item::type_id::create("req");
	  start_item(req);
	  $display("[%0t] SEQ: before randomize", $time);

if (!req.randomize() with {
    wr_addr_channel.burst == 2;
    wr_addr_channel.len   == 7;
    wr_addr_channel.size  == 2;
    wr_addr_channel.addr  == 5943;
}) begin
    $fatal(1, "Randomization failed");
end

$display("[%0t] SEQ: after randomize", $time);

       finish_item(req);
	endtask 
endclass

class wrap_unalign_seq extends wr_seq;
  `uvm_object_utils(wrap_unalign_seq)

  function new(string name = "wrap_unalign_seq");
    super.new(name);
  endfunction

  task body();
    repeat(6)
    begin
    req = seq_item::type_id::create("req");

    start_item(req);

  /*  assert(req.randomize() with {wr_addr_channel.burst == 2;
                                 wr_addr_channel.len   == 15;
								 wr_addr_channel.size  == 2;
								// wr_addr_channel.addr  == 5943;
								});*/
      assert(req.randomize());
      
	finish_item(req);
    end
  endtask

endclass

class wr_sqr extends uvm_sequencer#(seq_item);
   `uvm_component_utils(wr_sqr)
    function new(string name = "wr_sqr",uvm_component parent);
	        super.new(name,parent);
	endfunction
endclass


class wr_state;

  seq_item wr_t;
  bit aw_done;
  bit w_done;
  bit b_done;
  bit transcation_done;
  
endclass

class rd_state;
   
   seq_item rd_t;
   bit arw_done;
   bit rw_done;
   bit transcation_done;
   int unsigned beats_received;
   int unsigned expected_beats;
   
endclass


class wr_driver extends uvm_driver#(seq_item);
  `uvm_component_utils(wr_driver)
    wr_config wr_cfg;
	seq_item req;
	seq_item queue_wr[$],queue_rd[$];
	wr_state wr_status;
	rd_state rd_status;
	wr_state wr_requests[int][$];
	wr_state aw_w_order[$];
	rd_state rd_requests[int][$];
	static int no_of_wr_trans_done;
	static int no_of_rd_trans_done;
    function new(string name = "wr_driver",uvm_component parent);
            super.new(name,parent);
    endfunction
	
	function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(wr_config)::get(this,"","wr_cfg",wr_cfg))
		   `uvm_fatal("CONFIG_ERROR","WR_DRIVER :configuration is not working properly")
	endfunction 

task run_phase(uvm_phase phase);
  
  fork
  
      capture_requests();
      wr_addr_channel();
      wr_data_channel();
      resp_channel();
      rd_addr_channel();
      rd_data_channel();	  
	  
  join

endtask

task capture_requests();

    seq_item local_wr;
    seq_item local_rd;

    forever
    begin
        seq_item_port.get_next_item(req);


        local_wr = seq_item::type_id::create("local_wr");
        local_rd = seq_item::type_id::create("local_rd");

        local_wr.copy(req);
        local_rd.copy(req);

        queue_wr.push_back(local_wr);
        queue_rd.push_back(local_rd);

        seq_item_port.item_done();
    end
	
endtask


task wr_addr_channel();
seq_item tr;
  forever 
    begin
	wr_status =  new();
	wait(queue_wr.size() > 0)
	begin
      tr = queue_wr[0];
	end
	wr_status.wr_t = tr;
	display_wr_addr_tr();
    repeat (2)
    begin
        @(wr_cfg.vif.cb_master);
    end
    wr_cfg.vif.cb_master.AWID     <= tr.wr_addr_channel.id;
    wr_cfg.vif.cb_master.AWADDR   <= tr.wr_addr_channel.addr;
    wr_cfg.vif.cb_master.AWLEN    <= tr.wr_addr_channel.len;
    wr_cfg.vif.cb_master.AWSIZE   <= tr.wr_addr_channel.size;
    wr_cfg.vif.cb_master.AWBURST  <= tr.wr_addr_channel.burst;
    wr_cfg.vif.cb_master.AWLOCK   <= tr.wr_addr_channel.lock;
    wr_cfg.vif.cb_master.AWCACHE  <= tr.wr_addr_channel.cache;
    wr_cfg.vif.cb_master.AWPROT   <= tr.wr_addr_channel.prot;
    wr_cfg.vif.cb_master.AWQOS    <= tr.wr_addr_channel.qos;
    wr_cfg.vif.cb_master.AWREGION <= tr.wr_addr_channel.region;
    wr_cfg.vif.cb_master.AWUSER   <= tr.wr_addr_channel.user;
    wr_cfg.vif.cb_master.AWVALID  <= 1'b1;
    display_wr_addr();
    wait (wr_cfg.vif.cb_master.AWREADY);
    @(wr_cfg.vif.cb_master);
    void'(queue_wr.pop_front());
	wr_status.aw_done = 1;
	aw_w_order.push_back(wr_status);
	wr_requests[wr_status.wr_t.wr_addr_channel.id].push_back(wr_status);
    wr_cfg.vif.cb_master.AWVALID <= 1'b0;
    end
endtask

task wr_data_channel();

    wr_state wr_status;

    forever
	begin
	wait(aw_w_order.size() > 0)
	begin
	wr_status = aw_w_order.pop_front();
	end
	foreach(wr_status.wr_t.wr_data_channel[beat])
	begin
    @(wr_cfg.vif.cb_master);
    wr_cfg.vif.cb_master.WDATA  <= wr_status.wr_t.wr_data_channel[beat].data;
    wr_cfg.vif.cb_master.WSTRB  <= wr_status.wr_t.wr_data_channel[beat].strb;
    wr_cfg.vif.cb_master.WLAST  <= wr_status.wr_t.wr_data_channel[beat].last;
    wr_cfg.vif.cb_master.WUSER  <= wr_status.wr_t.wr_data_channel[beat].user;
    wr_cfg.vif.cb_master.WVALID <= 1'b1;
    wait (wr_cfg.vif.cb_master.WREADY);
    @(wr_cfg.vif.cb_master);
    if (wr_cfg.vif.WVALID && wr_cfg.vif.cb_master.WREADY)
    begin
        display_wr_data(beat);
    end
    wr_cfg.vif.cb_master.WVALID <= 1'b0;
	end
    wr_status.w_done = 1;
    end
endtask



task resp_channel();
    seq_item t;
    wr_state wr_status;
    forever
	begin
	t = seq_item::type_id::create("t");
    @(wr_cfg.vif.cb_master);
    wr_cfg.vif.cb_master.BREADY <= 1'b1;
    wait (wr_cfg.vif.cb_master.BVALID);
    @(wr_cfg.vif.cb_master);
    if (wr_cfg.vif.cb_master.BVALID && wr_cfg.vif.BREADY)
    begin
        display_wr_bresp();
    end
	if(wr_requests.exists(wr_cfg.vif.cb_master.BID) && wr_requests[wr_cfg.vif.cb_master.BID].size() > 0)
      wr_status = wr_requests[wr_cfg.vif.cb_master.BID][0];
	if(wr_status.aw_done && wr_status.w_done)
	   begin
	   wr_status.b_done    = 1;
	   no_of_wr_trans_done = t.wr_trans_done++; 
       void'(wr_requests[wr_cfg.vif.cb_master.BID].pop_front());
       end   
	 if(wr_requests[wr_cfg.vif.cb_master.BID].size() == 0)
	    begin
        wr_requests.delete(wr_cfg.vif.cb_master.BID);
		end
        wr_cfg.vif.cb_master.BREADY <= 1'b0;
	
    end
endtask


task rd_addr_channel();

 seq_item tr;
  forever 
    begin
	rd_status =  new();
	wait(queue_rd.size() > 0)
	begin
      tr = queue_rd[0];
	end
    rd_status.rd_t = tr;
    @(wr_cfg.vif.cb_master);
    wr_cfg.vif.cb_master.ARID     <= tr.rd_addr_channel.id;
    wr_cfg.vif.cb_master.ARADDR   <= tr.rd_addr_channel.addr;
    wr_cfg.vif.cb_master.ARLEN    <= tr.rd_addr_channel.len;
    wr_cfg.vif.cb_master.ARSIZE   <= tr.rd_addr_channel.size;
    wr_cfg.vif.cb_master.ARBURST  <= tr.rd_addr_channel.burst;
    wr_cfg.vif.cb_master.ARLOCK   <= tr.rd_addr_channel.lock;
    wr_cfg.vif.cb_master.ARCACHE  <= tr.rd_addr_channel.cache;
    wr_cfg.vif.cb_master.ARPROT   <= tr.rd_addr_channel.prot;
    wr_cfg.vif.cb_master.ARQOS    <= tr.rd_addr_channel.qos;
    wr_cfg.vif.cb_master.ARREGION <= tr.rd_addr_channel.region;
    wr_cfg.vif.cb_master.ARUSER   <= tr.rd_addr_channel.user;
    wr_cfg.vif.cb_master.ARVALID  <= 1'b1;
	rd_status.expected_beats       = tr.rd_addr_channel.len+1;
    wait (wr_cfg.vif.cb_master.ARREADY);
    @(wr_cfg.vif.cb_master);
    if (wr_cfg.vif.ARVALID && wr_cfg.vif.cb_master.ARREADY)
    begin
        display_rd_addr();
    end
    void'(queue_rd.pop_front());
	rd_status.arw_done = 1;
    rd_requests[tr.rd_addr_channel.id].push_back(rd_status);
    wr_cfg.vif.cb_master.ARVALID <= 1'b0;
    end
endtask


task rd_data_channel();
    seq_item t;
    rd_state rd_status;
	int unsigned rid;
    int unsigned beat;
    bit expected_last;

    forever
	begin
	t = seq_item::type_id::create("t");
 
    @(wr_cfg.vif.cb_master);
    wr_cfg.vif.cb_master.RREADY <= 1'b1;
    wait (wr_cfg.vif.cb_master.RVALID);
    @(wr_cfg.vif.cb_master);
	if (wr_cfg.vif.cb_master.RVALID && wr_cfg.vif.RREADY)
    begin
	    rid = wr_cfg.vif.cb_master.RID;
     if(!(rd_requests.exists(rid) && rd_requests[rid].size() > 0))
	  begin
	   `uvm_error("UNKNOWN_RID",$sformatf("Received unknown RID=%0d", rid) )
	  end
	 else
	   begin
	   rd_status = rd_requests[wr_cfg.vif.cb_master.RID][0];
	   beat      = rd_status.beats_received;
       if(beat >= rd_status.expected_beats)
	     `uvm_error("EXTRA_RBEAT",$sformatf("RID=%0d received extra beat=%0d",rid,beat) )
	   else
	       begin
		            rd_status.rd_t.rd_data_channel[beat].id   = wr_cfg.vif.cb_master.RID;

                    rd_status.rd_t.rd_data_channel[beat].data = wr_cfg.vif.cb_master.RDATA;

                    rd_status.rd_t.rd_data_channel[beat].resp = axi_resp_e'(wr_cfg.vif.cb_master.RRESP);

                    rd_status.rd_t.rd_data_channel[beat].last = wr_cfg.vif.cb_master.RLAST;

                    rd_status.rd_t.rd_data_channel[beat].user = wr_cfg.vif.cb_master.RUSER;
					
					display_rd_data(beat);
					
					expected_last = (beat == rd_status.expected_beats-1);
					
				   if (wr_cfg.vif.cb_master.RLAST != expected_last)
                    begin
                      `uvm_error( "RLAST_ERROR", $sformatf( "RID=%0d beat=%0d expected_last=%0b actual_last=%0b",rid, beat,expected_last,wr_cfg.vif.cb_master.RLAST) )
                   end
                     rd_status.beats_received++;
				 if(wr_cfg.vif.cb_master.RLAST)
				  begin
					 if(rd_status.arw_done)
					 begin
	                       rd_status.rw_done   = 1;
	                       no_of_rd_trans_done = t.rd_trans_done++;
						   void'(rd_requests[rid].pop_front);
						   if(rd_requests[rid].size() == 0)
						     rd_requests.delete(rid);
	                 end
                           wr_cfg.vif.cb_master.RREADY <= 1'b0;
                 end
            end
	    end
    end
end

endtask




task drive_back_pressure(seq_item tr);
  
    fork
        begin
          wr_data_channel();
        end
        begin
            repeat (20)
            begin
                @(wr_cfg.vif.cb_master);
            end
            wr_addr_channel();
        end
    join
    resp_channel();

endtask


task display_wr_addr_tr();

    $display("");
    $display("+------------------------------------------------------------------------------------------------------------------+");
    $display("| WRITE ADDRESS CHANNEL                                                                                            |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+--------+--------+------+");
    $display("| ID   | ADDRESS    | LEN  | BEATS | SIZE | BURST  | LOCK   | CACHE  | PROT   | QOS    | REGION | USER |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+--------+--------+------+");
    $display("| %-4d | 0x%08h | %-4d | %-5d | %-4d | %-6d | %-6b | 0x%-4h | 0x%-4h | 0x%-4h | 0x%-4h | 0x%-2h |", tr.AWID, tr.AWADDR, tr.AWLEN, tr.AWLEN + 1, tr.AWSIZE, tr.AWBURST, tr.AWLOCK, tr.AWCACHE, tr.AWPROT, tr.AWQOS, tr.AWREGION, tr.AWUSER);
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+--------+--------+------+");
    $display("TIME=%0t", $time);

endtask
task display_wr_addr();

    $display("");
    $display("+------------------------------------------------------------------------------------------------------------------+");
    $display("| WRITE ADDRESS CHANNEL                                                                                             |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("| ID   | ADDRESS    | LEN  | BEATS | SIZE | BURST  | LOCK   | CACHE  | PROT   | QOS  | REGION | USER |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("| %-4d | 0x%08h | %-4d | %-5d | %-4d | %-6d | %-6b | 0x%-4h | 0x%-4h | 0x%-2h | 0x%-4h | 0x%-2h |",
             wr_cfg.vif.AWID, wr_cfg.vif.AWADDR, wr_cfg.vif.AWLEN,
             wr_cfg.vif.AWLEN + 1, wr_cfg.vif.AWSIZE, wr_cfg.vif.AWBURST,
             wr_cfg.vif.AWLOCK, wr_cfg.vif.AWCACHE, wr_cfg.vif.AWPROT,
             wr_cfg.vif.AWQOS, wr_cfg.vif.AWREGION, wr_cfg.vif.AWUSER);
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("TIME=%0t  HANDSHAKE=%0b", $time, wr_cfg.vif.AWVALID && wr_cfg.vif.cb_master.AWREADY);

endtask


task display_wr_data(int beat);

    $display("+--------------------------------------------------------------------------------------------------+");
    $display("| WRITE DATA CHANNEL                                                                               |");
    $display("+------+------------+--------+------+--------+-------+-------+");
    $display("| BEAT | DATA       | STRB   | LAST | USER   | VALID | READY |");
    $display("+------+------------+--------+------+--------+-------+-------+");
    $display("| %-4d | 0x%08h | %04b   | %-4b | 0x%-4h | %-5b | %-5b |",
             beat, wr_cfg.vif.WDATA, wr_cfg.vif.WSTRB,
             wr_cfg.vif.WLAST, wr_cfg.vif.WUSER,
             wr_cfg.vif.WVALID, wr_cfg.vif.cb_master.WREADY);
    $display("+------+------------+--------+------+--------+-------+-------+");
    $display("TIME=%0t  HANDSHAKE=%0b", $time, wr_cfg.vif.WVALID && wr_cfg.vif.WREADY);

endtask


task display_wr_bresp();

    $display("+-------------------------------------------------------------------+");
    $display("| WRITE RESPONSE CHANNEL                                            |");
    $display("+------+--------+--------+-------+-------+");
  $display("| BID  | BRESP  | VALID | READY |");
    $display("+------+--------+--------+-------+-------+");
  $display("| %-4d | %02b     |  %-5b|  %-5b|",
             wr_cfg.vif.cb_master.BID, wr_cfg.vif.cb_master.BRESP,
             wr_cfg.vif.cb_master.BVALID,
             wr_cfg.vif.BREADY);
    $display("+------+--------+--------+-------+-------+");
    $display("TIME=%0t  HANDSHAKE=%0b", $time, wr_cfg.vif.cb_master.BVALID && wr_cfg.vif.BREADY);

endtask


task display_rd_addr();

    $display("");
    $display("+------------------------------------------------------------------------------------------------------------------+");
    $display("| READ ADDRESS CHANNEL                                                                                              |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("| ID   | ADDRESS    | LEN  | BEATS | SIZE | BURST  | LOCK   | CACHE  | PROT   | QOS  | REGION | USER |");
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("| %-4d | 0x%08h | %-4d | %-5d | %-4d | %-6d | %-6b | 0x%-4h | 0x%-4h | 0x%-2h | 0x%-4h | 0x%-2h |",
             wr_cfg.vif.ARID, wr_cfg.vif.ARADDR, wr_cfg.vif.ARLEN,
             wr_cfg.vif.ARLEN + 1, wr_cfg.vif.ARSIZE, wr_cfg.vif.ARBURST,
             wr_cfg.vif.ARLOCK, wr_cfg.vif.ARCACHE, wr_cfg.vif.ARPROT,
             wr_cfg.vif.ARQOS, wr_cfg.vif.ARREGION, wr_cfg.vif.ARUSER);
    $display("+------+------------+------+-------+------+--------+--------+--------+--------+------+--------+------+");
    $display("TIME=%0t  HANDSHAKE=%0b", $time, wr_cfg.vif.ARVALID && wr_cfg.vif.cb_master.ARREADY);

endtask


task display_rd_data(int beat);

    $display("+--------------------------------------------------------------------------------------------------------+");
    $display("| READ DATA CHANNEL                                                                                      |");
    $display("+------+------+------------+--------+------+--------+-------+-------+");
    $display("| BEAT | RID  | DATA       | RESP   | LAST | USER   | VALID | READY |");
    $display("+------+------+------------+--------+------+--------+-------+-------+");
    $display("| %-4d | %-4d | 0x%08h | %02b     | %-4b | 0x%-4h | %-5b | %-5b |",
             beat, wr_cfg.vif.cb_master.RID, wr_cfg.vif.cb_master.RDATA,
             wr_cfg.vif.cb_master.RRESP, wr_cfg.vif.cb_master.RLAST,
             wr_cfg.vif.cb_master.RUSER, wr_cfg.vif.cb_master.RVALID,
             wr_cfg.vif.RREADY);
    $display("+------+------+------------+--------+------+--------+-------+-------+");
    $display("TIME=%0t  HANDSHAKE=%0b", $time, wr_cfg.vif.cb_master.RVALID && wr_cfg.vif.RREADY);

endtask


endclass


class wr_monitor extends uvm_monitor;
  `uvm_component_utils(wr_monitor)
    uvm_analysis_port#(seq_item) w_mn2sb;
    wr_config wr_cfg;
	seq_item t;
    function new(string name = "wr_monitor",uvm_component parent);
            super.new(name,parent);
			w_mn2sb = new("w_mn2sb",this);
    endfunction
	
	function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(wr_config)::get(this,"","wr_cfg",wr_cfg))
		   `uvm_fatal("CONFIG_ERROR","WR_MONITOR :configuration is not working properly")
	endfunction 
	
	task run_phase(uvm_phase phase);
	forever
	begin
	  t = seq_item::type_id::create("t");
    
   	   wr_addr_mon(t);
	   wr_data_mon(t);
	   wr_resp_mon(t);
	   w_mn2sb.write(t);
    	
	end
	endtask
    
	task wr_addr_mon(seq_item tr);
    forever
	    begin
		@(wr_cfg.vif.cb_monitor);
          if(wr_cfg.vif.cb_monitor.AWVALID && wr_cfg.vif.cb_monitor.AWREADY)
		   begin  
			tr.wr_addr_channel.id     = wr_cfg.vif.cb_monitor.AWID;
			tr.wr_addr_channel.addr   = wr_cfg.vif.cb_monitor.AWADDR;
			tr.wr_addr_channel.len    = wr_cfg.vif.cb_monitor.AWLEN;
			tr.wr_addr_channel.size   = wr_cfg.vif.cb_monitor.AWSIZE;
			tr.wr_addr_channel.burst  = wr_cfg.vif.cb_monitor.AWBURST;
			tr.wr_addr_channel.lock   = wr_cfg.vif.cb_monitor.AWLOCK;
			tr.wr_addr_channel.cache  = wr_cfg.vif.cb_monitor.AWCACHE;
			tr.wr_addr_channel.prot   = wr_cfg.vif.cb_monitor.AWPROT;
			tr.wr_addr_channel.qos    = wr_cfg.vif.cb_monitor.AWQOS;
			tr.wr_addr_channel.region = wr_cfg.vif.cb_monitor.AWREGION;
			tr.wr_addr_channel.user   = wr_cfg.vif.cb_monitor.AWUSER;
            break;
		   end
	    end
	endtask
	
      task wr_data_mon(seq_item tr);
	    
		foreach(tr.wr_data_channel[i])
		begin
	    forever
	    begin
		   @(wr_cfg.vif.cb_monitor);
          if(wr_cfg.vif.cb_monitor.WVALID && wr_cfg.vif.cb_monitor.WREADY)
		   begin
             tr.wr_data_channel[i].last    = wr_cfg.vif.cb_monitor.WLAST;
             tr.wr_data_channel[i].user   = wr_cfg.vif.cb_monitor.WUSER;
             tr.wr_data_channel[i].strb    = wr_cfg.vif.cb_monitor.WSTRB;
             tr.wr_data_channel[i].data    = wr_cfg.vif.cb_monitor.WDATA;
			
            break;
		   end
	    end
	    end
	endtask
    
      task wr_resp_mon(seq_item tr);
        forever
           begin
             @(wr_cfg.vif.cb_monitor);
             if(wr_cfg.vif.cb_monitor.BVALID && wr_cfg.vif.cb_monitor.BREADY)
               begin
               tr.wr_resp_channel.id      = wr_cfg.vif.cb_monitor.BID;
                 tr.wr_resp_channel.resp  =  axi_resp_e'(wr_cfg.vif.cb_monitor.BRESP);
               tr.wr_resp_channel.user    = wr_cfg.vif.cb_monitor.BUSER;
               break;
               end
           end
       endtask
	
endclass


class wr_agent extends uvm_agent;
  `uvm_component_utils(wr_agent)
   wr_driver  wr_drv;
   wr_monitor wr_mon;
   wr_config  wr_cfg;
   wr_sqr     wr_sr;
    function new(string name = "wr_agent",uvm_component parent);
            super.new(name,parent);
    endfunction
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(wr_config)::get(this,"","wr_cfg",wr_cfg))
		   `uvm_fatal("CONFIG_ERROR","WR_AGENT :configuration is not working properly")
		else
		    begin
		    wr_mon = wr_monitor::type_id::create("wr_mon",this);
		    if(wr_cfg.is_active == UVM_ACTIVE)
			  begin
			   wr_drv = wr_driver::type_id::create("wr_drv",this);
			   wr_sr  = wr_sqr::type_id::create("wr_sr",this);
			   end
		    end
    endfunction
	
	function void connect_phase(uvm_phase phase);
	   if(wr_drv !== null && wr_sr !== null)
	    wr_drv.seq_item_port.connect(wr_sr.seq_item_export);
    endfunction
	
  endclass
  
  class wr_agt_top extends uvm_env;
   `uvm_component_utils(wr_agt_top)
    env_config env_cfg;
    wr_agent wr_agt[];
	function new(string name = "wr_agt_top",uvm_component parent);
             super.new(name,parent);
    endfunction
	
    function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(env_config)::get(this,"","env_cfg",env_cfg))
		    `uvm_fatal("CONFIG_ERROR","WR_AGT_TOP :configuration is not working properly")
		else
		   begin
		     wr_agt = new[env_cfg.no_of_wr_agents];
		     foreach(env_cfg.wr_cfg[i])
			    begin
				wr_agt[i] = wr_agent::type_id::create($sformatf("wr_agt[%0d]",i),this);
				end
			end
    endfunction
				 
   endclass
   
  
  class rd_seq extends uvm_sequence#(seq_item);
  `uvm_object_utils(rd_seq)
    function new(string name = "rd_seq");
            super.new(name);
    endfunction
endclass

class rd_sqr extends uvm_sequencer#(seq_item);
   `uvm_component_utils(rd_sqr)
    function new(string name = "rd_sqr",uvm_component parent);
	        super.new(name,parent);
	endfunction
endclass

class rd_driver extends uvm_driver#(seq_item);
  `uvm_component_utils(rd_driver)
   rd_config rd_cfg;
    function new(string name = "rd_driver",uvm_component parent);
            super.new(name,parent);
    endfunction
	
	function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(rd_config)::get(this,"","rd_cfg",rd_cfg))
		   `uvm_fatal("CONFIG_ERROR","RD_DRIVER :configuration is not working properly")
	endfunction 
endclass


class rd_monitor extends uvm_monitor;
  `uvm_component_utils(rd_monitor) 
    uvm_analysis_port#(seq_item) r_mn2sb;
	rd_config rd_cfg;
	
    function new(string name = "rd_monitor",uvm_component parent);
            super.new(name,parent);
			r_mn2sb = new("r_mn2sb",this);
    endfunction
	 
	function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(rd_config)::get(this,"","rd_cfg",rd_cfg))
		   `uvm_fatal("CONFIG_ERROR","RD_MONITOR :configuration is not working properly")
	endfunction 
          
  task run_phase(uvm_phase phase);
   seq_item tr;
   forever
   begin

      tr = seq_item::type_id::create("tr");
      collect_rd_addr(tr);
      collect_rd_data(tr);
	  r_mn2sb.write(tr);

   end
   endtask
   
  task collect_rd_addr(ref seq_item tr);

  forever 
  begin

    @(rd_cfg.vif.cb_monitor);

    if (rd_cfg.vif.cb_monitor.ARVALID && rd_cfg.vif.cb_monitor.ARREADY) 
	  begin

      tr.rd_addr_channel.id     = rd_cfg.vif.cb_monitor.ARID;
      tr.rd_addr_channel.addr   = rd_cfg.vif.cb_monitor.ARADDR;
      tr.rd_addr_channel.len    = rd_cfg.vif.cb_monitor.ARLEN;
      tr.rd_addr_channel.size   = rd_cfg.vif.cb_monitor.ARSIZE;
      tr.rd_addr_channel.burst  = rd_cfg.vif.cb_monitor.ARBURST;
      tr.rd_addr_channel.lock   = rd_cfg.vif.cb_monitor.ARLOCK;
      tr.rd_addr_channel.cache  = rd_cfg.vif.cb_monitor.ARCACHE;
      tr.rd_addr_channel.prot   = rd_cfg.vif.cb_monitor.ARPROT;
      tr.rd_addr_channel.qos    = rd_cfg.vif.cb_monitor.ARQOS;
      tr.rd_addr_channel.region = rd_cfg.vif.cb_monitor.ARREGION;
      tr.rd_addr_channel.user   = rd_cfg.vif.cb_monitor.ARUSER;

      /*$display(
        "[%0t] ARVALID=%0b ARREADY=%0b ARADDR=%h ARLEN=%0d ARSIZE=%0d ARBURST=%0d",
        $time,
        rd_cfg.vif.cb_monitor.ARVALID,
        rd_cfg.vif.cb_monitor.ARREADY,
        rd_cfg.vif.cb_monitor.ARADDR,
        rd_cfg.vif.cb_monitor.ARLEN,
        rd_cfg.vif.cb_monitor.ARSIZE,
        rd_cfg.vif.cb_monitor.ARBURST
      );*/

      break;

    end
  end

endtask
task collect_rd_data(ref seq_item tr);

  int unsigned beat;

  tr.rd_data_channel =
      new[tr.rd_addr_channel.len + 1];


  //while (beat < tr.rd_data_channel.size()) 
    foreach(tr.rd_data_channel[beat])
	begin

    @(rd_cfg.vif.cb_monitor);

    if (rd_cfg.vif.cb_monitor.RVALID && rd_cfg.vif.cb_monitor.RREADY) 
	  begin

      tr.rd_data_channel[beat].id =
          rd_cfg.vif.cb_monitor.RID;

      tr.rd_data_channel[beat].data =
          rd_cfg.vif.cb_monitor.RDATA;

      tr.rd_data_channel[beat].resp =
          axi_resp_e'(rd_cfg.vif.cb_monitor.RRESP);

      tr.rd_data_channel[beat].last =
          rd_cfg.vif.cb_monitor.RLAST;

      tr.rd_data_channel[beat].user =
          rd_cfg.vif.cb_monitor.RUSER;

     /* `uvm_info("RD_MON",
        $sformatf(
          "Beat=%0d RVALID=%0b RREADY=%0b RID=%0d DATA=%08h LAST=%0b",
          beat,
          rd_cfg.vif.cb_monitor.RVALID,
          rd_cfg.vif.cb_monitor.RREADY,
          tr.rd_data_channel[beat].id,
          tr.rd_data_channel[beat].data,
          tr.rd_data_channel[beat].last
        ),
        UVM_LOW
      )*/

      //beat++;
    end
  end

endtask
endclass
          
        


class rd_agent extends uvm_agent;
  `uvm_component_utils(rd_agent)
   rd_driver  rd_drv;
   rd_monitor rd_mon;
   rd_config  rd_cfg;
   rd_sqr     rd_sr;
    function new(string name = "rd_agent",uvm_component parent);
            super.new(name,parent);
    endfunction
    function void build_phase(uvm_phase phase);
        if(!uvm_config_db#(rd_config)::get(this,"","rd_cfg",rd_cfg))
		   `uvm_fatal("CONFIG_ERROR","rd_AGENT :configuration is not working properly")
		else
		    begin
		    rd_mon = rd_monitor::type_id::create("rd_mon",this);
		    if(rd_cfg.is_active == UVM_ACTIVE)
			  begin
			   rd_drv = rd_driver::type_id::create("rd_drv",this);
			   rd_sr  = rd_sqr::type_id::create("rd_sr",this);
			   end
		    end
    endfunction
	
	function void connect_phase(uvm_phase phase);
	   if(rd_drv !== null && rd_sr !== null)
	    rd_drv.seq_item_port.connect(rd_sr.seq_item_export);
    endfunction
	
  endclass
  
   class rd_agt_top extends uvm_env;
   `uvm_component_utils(rd_agt_top)
    env_config env_cfg;
    rd_agent rd_agt[];
	function new(string name = "rd_agt_top",uvm_component parent);
             super.new(name,parent);
    endfunction
	
    function void build_phase(uvm_phase phase);
	    if(!uvm_config_db#(env_config)::get(this,"","env_cfg",env_cfg))
		    `uvm_fatal("CONFIG_ERROR","rd_AGT_TOP :configuration is not working properly")
		else
		   begin
		     rd_agt = new[env_cfg.no_of_rd_agents];
		     foreach(env_cfg.rd_cfg[i])
			    begin
				rd_agt[i] = rd_agent::type_id::create($sformatf("rd_agt[%0d]",i),this);
				end
			end
    endfunction
				 
   endclass
  class score_board extends uvm_scoreboard;
   `uvm_component_utils(score_board)
    uvm_tlm_analysis_fifo#(seq_item) sb_wr;
	uvm_tlm_analysis_fifo#(seq_item) sb_rd;
	logic [(DATA_W/4)-1:0] mem [0:MEM_BYTES-1];
	function new(string name ="score_board",uvm_component parent);
	          super.new(name,parent);
			  sb_wr = new("sb_wr",this);
			  sb_rd = new("sb_rd",this);
	endfunction
	
	
  endclass
  
  
  class env extends uvm_env;
    `uvm_component_utils(env)
	 wr_agt_top   wr_ag_tp;
	 rd_agt_top   rd_ag_tp;
	 score_board  sb_h;
	 function new(string name = "env",uvm_component parent);
	          super.new(name,parent);
	 endfunction
	function void build_phase(uvm_phase phase);
	    wr_ag_tp    = wr_agt_top::type_id::create("wr_ag_tp",this);
        rd_ag_tp    = rd_agt_top::type_id::create("rd_ag_tp",this);
		sb_h        = score_board::type_id::create("sb_h",this); 
    endfunction
	function void connect_phase(uvm_phase phase);
	    foreach(wr_ag_tp.wr_agt[i])
          begin	
  	        if(wr_ag_tp.wr_agt[i].wr_mon!= null)
			   wr_ag_tp.wr_agt[i].wr_mon.w_mn2sb.connect(sb_h.sb_wr.analysis_export);
		  end
		foreach(rd_ag_tp.rd_agt[i])
          begin	
  	        if(rd_ag_tp.rd_agt[i].rd_mon!= null)
			   rd_ag_tp.rd_agt[i].rd_mon.r_mn2sb.connect(sb_h.sb_rd.analysis_export);
		  end
    endfunction
  endclass

   class test extends uvm_test;
    `uvm_component_utils(test)
	 env en;
	 wr_seq wr_sq;
	 rd_seq rd_sq;
	 wr_config    wr_cfg[];
	 rd_config    rd_cfg[];
	 env_config   env_cfg;
	 int          no_of_wr_agents = 1;
	 int          no_of_rd_agents = 1;
	 
     function new(string name = "test",uvm_component parent);
        super.new(name,parent);
     endfunction
	 function void build_phase(uvm_phase phase);
	    wr_cfg                   = new[no_of_wr_agents];
		rd_cfg                   = new[no_of_rd_agents];
		env_cfg                  = env_config::type_id::create("env_cfg");
		env_cfg.wr_cfg           = new[no_of_wr_agents];
		env_cfg.rd_cfg           = new[no_of_rd_agents];
		env_cfg.no_of_wr_agents  = no_of_wr_agents;
		env_cfg.no_of_rd_agents  = no_of_rd_agents;
		foreach(wr_cfg[i])
		   begin
		      wr_cfg[i] = wr_config::type_id::create($sformatf("wr_cfg[%0d]",i));
			
			if(!uvm_config_db #(virtual axi_fifo_slave_if)::get(this,"","vif",wr_cfg[i].vif))
			   `uvm_fatal("CONFIG_ERROR","WR_CONFIG at TEST:configuration is not working properly")
			else
			 begin
			  env_cfg.wr_cfg[i] = wr_cfg[i];
		     if(i<2)
			  wr_cfg[i].is_active = UVM_ACTIVE;
			 else
		      wr_cfg[i].is_active = UVM_PASSIVE;
			  
		      uvm_config_db#(wr_config)::set(this,$sformatf("en.wr_ag_tp.wr_agt[%0d]*",i),"wr_cfg",wr_cfg[i]);
			 end
		  end
		foreach(rd_cfg[i])
		   begin
		      rd_cfg[i] = rd_config::type_id::create($sformatf("rd_cfg[%0d]",i));
			  
			if(! uvm_config_db #(virtual axi_fifo_slave_if)::get(this,"","vif",rd_cfg[i].vif))
			  `uvm_fatal("CONFIG_ERROR","RD_CONFIG at TEST:configuration is not working properly")
			else
             begin			
			   env_cfg.rd_cfg[i] = rd_cfg[i];
			 if(i<2)
			   rd_cfg[i].is_active = UVM_PASSIVE;
			 else
		       rd_cfg[i].is_active = UVM_ACTIVE;
			  
			   uvm_config_db#(rd_config)::set(this,$sformatf("en.rd_ag_tp.rd_agt[%0d]*",i),"rd_cfg",rd_cfg[i]);
		    end
		   end
		  uvm_config_db#(env_config)::set(this,"*","env_cfg",env_cfg);
		  en    = env::type_id::create("en",this);
		  wr_sq = wr_seq::type_id::create("wr_sq");
		  rd_sq = rd_seq::type_id::create("rd_sq");
	 endfunction
	 
	 
	 function void end_of_elaboration_phase(uvm_phase phase);
	               //uvm_top.print_topology();
				  uvm_root::get().print_topology();
	 endfunction
	 
	 task run_phase(uvm_phase phase);
	
        phase.raise_objection(this);
		  foreach(wr_cfg[i])
		    begin
			
		    if(wr_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       wr_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
			   
            end
    	phase.drop_objection(this);	
     endtask		
	
endclass
	 
class fixed_test extends test ;
  `uvm_component_utils(fixed_test)
  fixed_seq fx_sq;
    function new(string name = "fixed_test",uvm_component parent);
	         super.new(name,parent);
	endfunction

	
    task run_phase(uvm_phase phase);
	   phase.raise_objection(this);
	      fx_sq = fixed_seq::type_id::create("fx_sq");
	      foreach(wr_cfg[i])
		    begin
		    if(fx_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       fx_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
            end
	   phase.drop_objection(this);
	endtask
 endclass
 
 class inc_align_test extends test ;
  `uvm_component_utils(inc_align_test)
  inc_align_seq in_an_sq;
    function new(string name = "inc_align_test",uvm_component parent);
	         super.new(name,parent);
	endfunction

	
    task run_phase(uvm_phase phase);
	   phase.raise_objection(this);
	      in_an_sq = inc_align_seq::type_id::create("in_an_sq");
	      foreach(wr_cfg[i])
		    begin
		    if(in_an_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       in_an_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
            end
	   phase.drop_objection(this);
	endtask
 endclass
 
 class inc_unalign_test extends test ;
  `uvm_component_utils(inc_unalign_test)
  inc_unalign_seq in_unan_sq;
    function new(string name = "inc_unalign_test",uvm_component parent);
	         super.new(name,parent);
	endfunction

	
    task run_phase(uvm_phase phase);
	   phase.raise_objection(this);
	      in_unan_sq = inc_unalign_seq::type_id::create("in_unan_sq");
	      foreach(wr_cfg[i])
		    begin
		    if(in_unan_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       in_unan_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
            end
	   phase.drop_objection(this);
	endtask
 endclass
 
 
 class wrap_unalign_test extends test ;
  `uvm_component_utils(wrap_unalign_test)
   wrap_unalign_seq wrap_unan_sq;
    function new(string name = "wrap_unalign_test",uvm_component parent);
	         super.new(name,parent);
	endfunction

	
    task run_phase(uvm_phase phase);
	   phase.raise_objection(this);
	      wrap_unan_sq = wrap_unalign_seq::type_id::create("wrap_unan_sq");
	      foreach(wr_cfg[i])
		    begin
		    if(wrap_unan_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       wrap_unan_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
              wait(en.wr_ag_tp.wr_agt[i].wr_drv.no_of_wr_trans_done == 3 && en.wr_ag_tp.wr_agt[i].wr_drv.no_of_rd_trans_done == 3);
            end
	   phase.drop_objection(this);
	endtask
 endclass
 
 class wrap_align_test extends test ;
  `uvm_component_utils(wrap_align_test)
  wrap_align_seq wrap_an_sq;
    function new(string name = "wrap_align_test",uvm_component parent);
	         super.new(name,parent);
	endfunction

	
    task run_phase(uvm_phase phase);
	   phase.raise_objection(this);
	      wrap_an_sq = wrap_align_seq::type_id::create("wrap_an_sq");
	      foreach(wr_cfg[i])
		    begin
		    if(wrap_an_sq != null && en.wr_ag_tp.wr_agt[i].wr_sr != null)
		       wrap_an_sq.start(en.wr_ag_tp.wr_agt[i].wr_sr);
            end
	   phase.drop_objection(this);
	endtask
 endclass
 
endpackage 
	
module top;
   parameter int unsigned ADDR_W = 32;
   parameter int unsigned DATA_W = 32;
   parameter int unsigned ID_W   = 4;
   parameter int unsigned USER_W = 1;
  import uvm_pkg::*;
  import pkg::*;
  bit clk = 0;
  bit rst_n ;
  always #5 clk = ~ clk;
  axi_fifo_slave_if #(
    .ADDR_W (ADDR_W),
    .DATA_W (DATA_W),
    .ID_W   (ID_W),
    .USER_W (USER_W)) 
	vif (.aclk(clk),.areset_n(rst_n));
	
  axi_fifo_slave_top #(
    .ADDR_W(ADDR_W),
    .DATA_W(DATA_W),
    .ID_W  (ID_W),
    .USER_W(USER_W)
) dut (

    .aclk      (vif.ACLK),
    .areset_n  (vif.ARESETn),

    // Write Address
    .s_awid     (vif.AWID),
    .s_awaddr   (vif.AWADDR),
    .s_awlen    (vif.AWLEN),
    .s_awsize   (vif.AWSIZE),
    .s_awburst  (vif.AWBURST),
    .s_awlock   (vif.AWLOCK),
    .s_awcache  (vif.AWCACHE),
    .s_awprot   (vif.AWPROT),
    .s_awqos    (vif.AWQOS),
    .s_awregion (vif.AWREGION),
    .s_awuser   (vif.AWUSER),
    .s_awvalid  (vif.AWVALID),
    .s_awready  (vif.AWREADY),

    // Write Data
    .s_wdata   (vif.WDATA),
    .s_wstrb   (vif.WSTRB),
    .s_wlast   (vif.WLAST),
    .s_wuser   (vif.WUSER),
    .s_wvalid  (vif.WVALID),
    .s_wready  (vif.WREADY),

    // Write Response
    .s_bid     (vif.BID),
    .s_bresp   (vif.BRESP),
    .s_buser   (vif.BUSER),
    .s_bvalid  (vif.BVALID),
    .s_bready  (vif.BREADY),

    // Read Address
    .s_arid     (vif.ARID),
    .s_araddr   (vif.ARADDR),
    .s_arlen    (vif.ARLEN),
    .s_arsize   (vif.ARSIZE),
    .s_arburst  (vif.ARBURST),
    .s_arlock   (vif.ARLOCK),
    .s_arcache  (vif.ARCACHE),
    .s_arprot   (vif.ARPROT),
    .s_arqos    (vif.ARQOS),
    .s_arregion (vif.ARREGION),
    .s_aruser   (vif.ARUSER),
    .s_arvalid  (vif.ARVALID),
    .s_arready  (vif.ARREADY),

    // Read Data
    .s_rid     (vif.RID),
    .s_rdata   (vif.RDATA),
    .s_rresp   (vif.RRESP),
    .s_rlast   (vif.RLAST),
    .s_ruser   (vif.RUSER),
    .s_rvalid  (vif.RVALID),
    .s_rready  (vif.RREADY)
);
	initial
	 begin
       uvm_config_db #(virtual axi_fifo_slave_if)::set(null,"*","vif",vif);
	  run_test("test");
     end
  initial 
    begin
     rst_n = 0;
     @(posedge clk);
     rst_n = 1;
   end
 
/*always @(posedge clk)
  begin

  if (dut.mem_we_a)
    begin

    automatic logic [ADDR_W-1:0] captured_addr;
    captured_addr = dut.mem_waddr_base_a;

    $display(
      "[MEM_WRITE_REQ] T=%0t ADDR=%08h WDATA=%08h WBE=%b",
      $time,
      captured_addr,
      dut.mem_wdata_a,
      dut.mem_wbe_a
    );

    #1;

    for (int lane = 0; lane < DATA_W/8; lane++) begin
      if (dut.mem_wbe_a[lane]) begin
        $display(
          "[MEM_STORED] ADDR=%08h VALUE=%02h",
          captured_addr + lane,
          dut.u_mem.mem[captured_addr + lane]
        );
      end
    end

  end

end

always @(posedge clk)
begin
    if (vif.WVALID && !vif.WREADY)
    begin
        $display("[W_STALL ] T=%0t DATA=0x%08h STRB=%0h LAST=%0b",
                 $time, vif.WDATA, vif.WSTRB, vif.WLAST);
    end

    if (vif.WVALID && vif.WREADY)
    begin
        $display("[W_ACCEPT] T=%0t DATA=0x%08h STRB=%0h LAST=%0b",
                 $time, vif.WDATA, vif.WSTRB, vif.WLAST);
    end
end*/
  
endmodule 