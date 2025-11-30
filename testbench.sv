//===============
// verification
//===============

//===============
// Import Package
//===============
import uvm_pkg::*;
`include "uvm_macros.svh"

//===============
//Interface
//===============
interface uart_if (input clk);
  logic rst_n;
  logic [7:0] tx_data;
  logic tx_start;
  logic tx;
  logic busy;
endinterface


//====================
//Class item_sequence
// Transaction
//====================
class uart_item extends uvm_sequence_item;
  `uvm_object_utils(uart_item)
//  randomize data
  rand bit [7:0] data;
  
  function new(string name = "uart_item");
    super.new(name);
  endfunction
  
  virtual function string convert2string();
    return $sformatf("Data = 8'h%0h (%0b)", data,data);
  endfunction
  
endclass

//===================
//Class uvm_sequence
//===================
class uart_sequence extends uvm_sequence #(uart_item);
  `uvm_object_utils(uart_sequence)
  
  function new(string name = "uart_sequence");
    super.new(name);
  endfunction
  
  task body();
  	uart_item req;
    
    repeat(10) begin
      req = uart_item::type_id::create("req");
      start_item(req);
      
      if(!req.randomize())
        `uvm_error(get_type_name(), "Randomize Fail!")
        finish_item(req);
    end
    
  endtask
  
endclass

//===================
//Class uvm_sequencer
//===================
class uart_sequencer extends uvm_sequencer #(uart_item);
  `uvm_component_utils(uart_sequencer)
  
  function new(string name = "uart_sequencer", uvm_component parent);
    super.new(name,parent);
  endfunction
endclass


//================
//Class uvm_driver
//================
class uart_driver extends uvm_driver #(uart_item);
  `uvm_component_utils(uart_driver)
  
  virtual uart_if vif;
  
  function new(string name = "uart_driver", uvm_component parent);
    super.new(name,parent);  	
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual uart_if)::get(this,"","vif", vif))
      `uvm_fatal(get_type_name(),"Error to get vif from DB")    
  endfunction
      
    task run_phase(uvm_phase phase);
    	
//     Reset
    vif.rst_n    <= 0;
    vif.tx_start <= 0;
    vif.tx_data  <= 0;
    @(posedge vif.clk) 
    	vif.rst_n <= 1;
    @(posedge vif.clk) 
    
    forever begin
      seq_item_port.get_next_item(req);
      @(posedge vif.clk);
    	vif.tx_data <= req.data;
      	vif.tx_start <= 1;
      
    @(posedge vif.clk) 
    	vif.tx_start <=0;
    
    wait(vif.busy == 1);
    wait(vif.busy == 0);
    
    `uvm_info(get_type_name(), $sformatf("Sent: %s", req.convert2string()), UVM_LOW);
    
    seq_item_port.item_done();
    end
    endtask
  
endclass



//=================
//Class uvm_monitor
//=================
class uart_monitor extends uvm_monitor;
  `uvm_component_utils(uart_monitor)
  
  virtual uart_if vif;
  uart_item trans_collected;
  uvm_analysis_port #(uart_item) item_collected_port;
  
  function new(string name = "uart_monitor", uvm_component parent);
    super.new(name,parent);
    item_collected_port = new("item_collected_port", this);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    if(!uvm_config_db #(virtual uart_if)::get(this,"","vif",vif))
      `uvm_info(get_type_name(), $sformatf("Fail get vif from db"), UVM_LOW)
  endfunction
      
    task run_phase(uvm_phase phase);
    	forever begin
          trans_collected = uart_item::type_id::create("trans_collected");
          
          wait(vif.tx == 0);
          
          repeat(6) @(posedge vif.clk);
          
          for(int i=0; i<8;i++) begin
            trans_collected.data[i] = vif.tx;
            repeat(4) @(posedge vif.clk);
          end
          
          `uvm_info(get_type_name(), $sformatf("Monitor Captured: 8'h%0h", trans_collected.data), UVM_LOW)
          item_collected_port.write(trans_collected);
          wait(vif.tx == 1);
          
        end
    endtask
  
endclass




//===============
//Class uvm_agent
//===============
class uart_agent extends uvm_agent;
  `uvm_component_utils(uart_agent)
  
  uart_driver    driver;
  uart_monitor   monitor;
  uart_sequencer sequencer;
  
  function new(string name = "uart_agent", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    monitor = uart_monitor::type_id::create("monitor", this);
    
    if(get_is_active() == UVM_ACTIVE) begin
      driver    = uart_driver::type_id::create("driver",this);
      sequencer = uart_sequencer::type_id::create("sequencer",this);
    end
  endfunction
  
  function void connect_phase(uvm_phase phase);
    if(get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction
endclass



//====================
//Class uvm_scoreboard
//====================
class uart_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(uart_scoreboard)
  
  uvm_analysis_imp #(uart_item, uart_scoreboard) item_collected_export;
  
  function new(string name = "uart_scoreboard", uvm_component parent);
    super.new(name,parent);
    item_collected_export = new("item_collected_export", this);
  endfunction
  
  virtual function void write (uart_item trans);
    $display("==================================================================");
    `uvm_info("Scoreboard", $sformatf("PASS! UART Captured: 8'h%0h (binary: %0b)" , trans.data, trans.data), UVM_LOW)
    $display("==================================================================");
  endfunction
  
endclass


//===============
//Class uvm_env
//===============
class uart_env extends uvm_env;
  `uvm_component_utils(uart_env)
  
  uart_agent agent;
  uart_scoreboard scb;
  
  function new(string name = "uart_env", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
    agent = uart_agent::type_id::create("agent",this);
    scb   = uart_scoreboard::type_id::create("scb",this);
    
  endfunction
  
  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    
    agent.monitor.item_collected_port.connect(scb.item_collected_export);
    
  endfunction
  
endclass




//===============
//Class base test
//===============
class uart_test extends uvm_test;
  `uvm_component_utils(uart_test)
  
  uart_env env;
  uart_sequence seq;
  
  function new(string name = "uart_test", uvm_component parent);
    super.new(name,parent);
  endfunction
  
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    env = uart_env::type_id::create("env", this);
  endfunction
  
  task run_phase(uvm_phase phase);
    
    phase.raise_objection(this);
    
    
    seq = uart_sequence::type_id::create("seq");
    `uvm_info("TEST", "Strarting UART Sequence ...", UVM_LOW)
    seq.start(env.agent.sequencer);
    `uvm_info("TEST", "Sequence Finished, Waiting for last bit...", UVM_LOW)
    #2000ns;
    
    phase.drop_objection(this);
    
  endtask
  
endclass




//====================
//    TOP MODULE
//==================== 
module testbench;
	bit clk;
  initial begin
  	clk = 0;
    forever #5 clk = ~clk;
  end
  
  uart_if vif(clk);
  
  uart_tx u_dut (
    .clk(vif.clk),
    .rst_n(vif.rst_n),
    .tx_data(vif.tx_data),
    .tx_start(vif.tx_start),
    .tx(vif.tx),
    .busy(vif.busy)
  );
  
  initial begin
    uvm_config_db #(virtual uart_if)::set(null,"*","vif",vif);
    
    $dumpfile("dump.vcd");
    $dumpvars;
    
    run_test("uart_test");
  end
  
endmodule
    

