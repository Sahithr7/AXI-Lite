# **AXI Lite Interface Project Documentation**

## **1\. Project Overview**

This project implements a basic AXI4-Lite Slave interface in SystemVerilog, along with a Universal Verification Methodology (UVM) testbench for verification. The AXI4-Lite protocol is a simplified version of the AXI4 protocol, commonly used for memory-mapped registers and low-bandwidth communication in System-on-Chip (SoC) designs.

The AXI4-Lite Slave module (axilite\_s.sv) acts as a memory controller, allowing a master device to perform read and write operations to an internal memory array. The UVM testbench (tb.sv) is designed to generate random AXI4-Lite transactions (read and write), drive them to the Device Under Test (DUT), monitor the DUT's responses, and compare them against a reference model to ensure functional correctness.

## **2\. Design Details: AXI Lite Slave (axilite\_s.sv)**

The axilite\_s.sv module implements the AXI4-Lite Slave interface. It handles the AXI handshake signals and manages read/write access to an internal memory.

### **2.1. Module Ports**

The module defines the standard AXI4-Lite slave ports:

| Port Name | Direction | Width | Description |
| :---- | :---- | :---- | :---- |
| `s_axi_aclk`    | Input     | 1 bit   | AXI clock                                   |
| `s_axi_aresetn` | Input     | 1 bit   | AXI active-low reset                        |
| `s_axi_awvalid` | Input     | 1 bit   | Write address valid                         |
| `s_axi_awready` | Output    | 1 bit   | Write address ready                         |
| `s_axi_awaddr`  | Input     | 32 bits | Write address                               |
| `s_axi_wvalid`  | Input     | 1 bit   | Write data valid                            |
| `s_axi_wready`  | Output    | 1 bit   | Write data ready                            |
| `s_axi_wdata`   | Input     | 32 bits | Write data                                  |
| `s_axi_bvalid`  | Output    | 1 bit   | Write response valid                        |
| `s_axi_bready`  | Input     | 1 bit   | Write response ready                        |
| `s_axi_bresp`   | Output    | 2 bits  | Write response (OKAY, SLVERR, DECERR)       |
| `s_axi_arvalid` | Input     | 1 bit   | Read address valid                          |
| `s_axi_arready` | Output    | 1 bit   | Read address ready                          |
| `s_axi_araddr`  | Input     | 32 bits | Read address                                |
| `s_axi_rvalid`  | Output    | 1 bit   | Read data valid                             |
| `s_axi_rready`  | Input     | 1 bit   | Read data ready                             |
| `s_axi_rdata`   | Output    | 32 bits | Read data                                   |
| `s_axi_rresp`   | Output    | 2 bits  | Read response (OKAY, SLVERR, DECERR) 

### **2.2. Internal Memory**

The module includes an internal memory array mem of size 128 locations, each capable of storing 32-bit data: 

`reg \[31:0\] mem \[128\];`

### **2.3. State Machine**

The AXI Lite Slave operates based on a state machine to manage the read and write transactions. The defined states are:

* `idle`: Initial state, waiting for a write or read address.  
* `send\_waddr\_ack`: Acknowledging a write address.  
* `send\_raddr\_ack`: Acknowledging a read address.  
* `send\_wdata\_ack`: Acknowledging write data.  
* `update\_mem`: Writing data to the internal memory.  
* `send\_wr\_err`: Sending a write error response (e.g., for out-of-bounds address).  
* `send\_wr\_resp`: Sending a successful write response.  
* `gen\_data`: Generating read data from memory.  
* `send\_rd\_err`: Sending a read error response.  
* `send\_rdata`: Sending read data to the master.

The state transitions ensure proper AXI handshake sequences. For instance, after receiving a valid write address (s\_axi\_awvalid), the slave asserts s\_axi\_awready and transitions to send\_waddr\_ack. Similarly, for read operations, s\_axi\_arvalid triggers s\_axi\_arready and a transition to send\_raddr\_ack.

### **2.4. Write Operation Flow**

1. **Address Phase:** The slave waits in idle until s\_axi\_awvalid is asserted. It then asserts s\_axi\_awready and captures s\_axi\_awaddr, transitioning to send\_waddr\_ack.  
2. **Data Phase:** In send\_waddr\_ack, the slave waits for s\_axi\_wvalid. Once asserted, it captures s\_axi\_wdata, asserts s\_axi\_wready, and transitions to send\_wdata\_ack.  
3. **Memory Update/Error:** In send\_wdata\_ack, if the waddr is within the valid memory range (0-127), it transitions to update\_mem and writes wdata to mem\[waddr\]. Otherwise, it transitions to send\_wr\_err and sends a DECERR (2'b11) response.  
4. **Response Phase:** From update\_mem, it moves to send\_wr\_resp and asserts s\_axi\_bvalid with an OKAY (2'b00) response. If in send\_wr\_err, it asserts s\_axi\_bvalid with DECERR. The slave waits for s\_axi\_bready to be asserted by the master before returning to idle.

### **2.5. Read Operation Flow**

1. **Address Phase:** The slave waits in idle until s\_axi\_arvalid is asserted. It then asserts s\_axi\_arready and captures s\_axi\_araddr, transitioning to send\_raddr\_ack.  
2. **Data Generation/Error:** In send\_raddr\_ack, if raddr is within the valid memory range, it transitions to gen\_data. Otherwise, it transitions to send\_rd\_err, asserts s\_axi\_rvalid with DECERR (2'b11) and s\_axi\_rdata as 0\.  
3. **Data Phase:** In gen\_data, it reads mem\[raddr\] into rdata. After a small delay (controlled by count), it asserts s\_axi\_rvalid with the rdata and an OKAY (2'b00) response.  
4. **Completion:** The slave waits for s\_axi\_rready from the master before returning to idle. If in send\_rd\_err, it waits for s\_axi\_rready to transition back to idle.

## **3\. UVM Testbench Architecture (tb.sv)**

The UVM testbench is structured into standard UVM components: transaction, generator, driver, monitor, and scoreboard.

### **3.1. axi\_if Interface**

The axi\_if interface defines all the AXI4-Lite signals, providing a clean and organized way to connect the testbench components to the DUT.

interface axi\_if;  
  logic clk,resetn;  
  logic awvalid, awready;  
  logic arvalid, arready;  
  logic wvalid, wready;  
  logic bready, bvalid;  
  logic rvalid, rready;  
  logic \[31:0\] awaddr, araddr, wdata, rdata;  
  logic \[1:0\] wresp,rresp;  
endinterface

### **3.2. transaction Class**

The transaction class encapsulates the data and control signals for a single AXI4-Lite transaction (either a write or a read).

* op: Random variable (1'b1 for write, 1'b0 for read).  
* awaddr, wdata: Random variables for write address and data.  
* araddr: Random variable for read address.  
* rdata, wresp, rresp: Non-random variables to capture response data and status.  
* **Constraints:**  
  * valid\_addr\_range: Constrains awaddr and araddr to be within \[1:4\].  
  * valid\_data\_range: Constrains wdata and rdata to be less than 12\.

class transaction;  
  randc bit         op;  
  rand bit \[31:0\] awaddr;  
  rand bit \[31:0\] wdata;  
  rand bit \[31:0\] araddr;  
        bit \[31:0\] rdata;  
        bit \[1:0\]  wresp;  
        bit \[1:0\]  rresp;

  constraint valid\_addr\_range {awaddr inside {\[1:4\]}; araddr inside {\[1:4\]};}  
  constraint valid\_data\_range {wdata \< 12; rdata \< 12;}  
endclass

### **3.3. generator Class**

The generator creates randomized transaction objects and sends them to the driver via a mailbox.

* mbxgd: Mailbox for generator to driver communication.  
* count: Number of transactions to generate.  
* run() task: Randomizes transaction objects, displays them, puts them into the mailbox, and waits for the scoreboard to complete its work (sconext event) before generating the next transaction.

class generator;  
  transaction tr;  
  mailbox \#(transaction) mbxgd;

  event done; ///gen completed sending requested no. of transaction  
  event sconext; ///scoreboard complete its work

  int count \= 0;

  function new( mailbox \#(transaction) mbxgd);  
    this.mbxgd \= mbxgd;  
    tr \=new();  
  endfunction

  task run();  
    for(int i=0; i \< count; i++)  
    begin  
      assert(tr.randomize) else $error("Randomization Failed");  
      $display("\[GEN\] : OP : %0b awaddr : %0d wdata : %0d araddr : %0d",tr.op, tr.awaddr, tr.wdata, tr.araddr);  
      mbxgd.put(tr);  
      @(sconext);  
    end  
    \-\>done;  
  endtask  
endclass

### **3.4. driver Class**

The driver takes transaction objects from the generator's mailbox and drives the corresponding AXI4-Lite signals to the DUT through the virtual interface.

* vif: Virtual interface to connect to the axi\_if.  
* mbxgd: Mailbox for generator to driver communication.  
* mbxdm: Mailbox for driver to monitor communication (sends the transaction driven to the DUT).  
* reset() task: Initializes and de-asserts the resetn signal, setting all AXI signals to default values.  
* write\_data() task: Drives the AXI write address and data signals, waits for awready, wready, and bvalid handshakes, and then de-asserts the signals. It also puts the transaction into mbxdm for the monitor.  
* read\_data() task: Drives the AXI read address signals, waits for arready, and rvalid handshakes, and then de-asserts the signals. It also puts the transaction into mbxdm for the monitor.  
* run() task: Continuously gets transactions from mbxgd and calls either write\_data() or read\_data() based on tr.op.

class driver;  
  virtual axi\_if vif;  
  transaction tr;  
  mailbox \#(transaction) mbxgd;  
  mailbox \#(transaction) mbxdm;

  function new( mailbox \#(transaction) mbxgd,  mailbox \#(transaction) mbxdm);  
    this.mbxgd \= mbxgd;  
    this.mbxdm \= mbxdm;  
  endfunction

  // Resetting System  
  task reset();  
    vif.resetn  \<= 1'b0;  
    vif.awvalid \<= 1'b0;  
    vif.awaddr  \<= 0;  
    vif.wvalid \<= 0;  
    vif.wdata \<= 0;  
    vif.bready \<= 0;  
    vif.arvalid \<= 1'b0;  
    vif.araddr \<= 0;  
    repeat(5) @(posedge vif.clk);  
    vif.resetn \<= 1'b1;  
    $display("-----------------\[DRV\] : RESET DONE-----------------------------");  
  endtask

  task write\_data(input transaction tr);  
    $display("\[DRV\] : OP : %0b awaddr : %0d wdata : %0d ",tr.op, tr.awaddr, tr.wdata);  
    mbxdm.put(tr); // Send transaction to monitor  
    vif.resetn  \<= 1'b1;  
    vif.awvalid \<= 1'b1;  
    vif.arvalid \<= 1'b0;  ////disable read  
    vif.araddr  \<= 0;  
    vif.awaddr  \<= tr.awaddr;  
    @(negedge vif.awready);  
    vif.awvalid \<= 1'b0;  
    vif.awaddr  \<= 0;  
    vif.wvalid  \<= 1'b1;  
    vif.wdata   \<= tr.wdata;  
    @(negedge vif.wready);  
    vif.wvalid  \<= 1'b0;  
    vif.wdata   \<= 0;  
    vif.bready  \<= 1'b1;  
    vif.rready  \<= 1'b0;  
    @(negedge vif.bvalid);  
    vif.bready  \<= 1'b0;  
  endtask

  task read\_data(input transaction tr);  
    $display("\[DRV\] : OP : %0b araddr : %0d ",tr.op, tr.araddr);  
    mbxdm.put(tr); // Send transaction to monitor  
    vif.resetn  \<= 1'b1;  
    vif.awvalid \<= 1'b0;  
    vif.awaddr  \<= 0;  
    vif.wvalid  \<= 1'b0;  
    vif.wdata   \<= 0;  
    vif.bready  \<= 1'b0;  
    vif.arvalid \<= 1'b1;  
    vif.araddr  \<= tr.araddr;  
    @(negedge vif.arready);  
    vif.araddr  \<= 0;  
    vif.arvalid \<= 1'b0;  
    vif.rready  \<= 1'b1;  
    @(negedge vif.rvalid);  
    vif.rready  \<= 1'b0;  
  endtask

  task run();  
    forever  
    begin  
      mbxgd.get(tr); // Get transaction from generator  
      @(posedge vif.clk);  
      // write mode check and signal generation  
      if(tr.op \== 1'b1)  
        write\_data(tr);  
      else  
        read\_data(tr);  
    end  
  endtask  
endclass

### **3.5. monitor Class**

The monitor observes the AXI4-Lite signals on the virtual interface and reconstructs transaction objects based on the DUT's behavior. These observed transactions are then sent to the scoreboard.

* vif: Virtual interface to observe AXI signals.  
* mbxms: Mailbox for monitor to scoreboard communication.  
* mbxdm: Mailbox for driver to monitor communication (receives the transaction driven by the driver).  
* run() task: Continuously samples the AXI signals.  
  * For write operations, it waits for bvalid to go high, captures wresp, and then waits for bvalid to go low.  
  * For read operations, it waits for rvalid to go high, captures rdata and rresp, and then waits for rvalid to go low.  
  * The reconstructed transaction is then put into mbxms.

class monitor;  
  virtual axi\_if vif;  
  transaction tr,trd;  
  mailbox \#(transaction) mbxms;  
  mailbox \#(transaction) mbxdm;

  function new( mailbox \#(transaction) mbxms , mailbox \#(transaction) mbxdm);  
    this.mbxms \= mbxms;  
    this.mbxdm \= mbxdm;  
  endfunction

  task run();  
    tr \= new();  
    forever  
    begin  
      @(posedge vif.clk);  
      mbxdm.get(trd); // Get transaction from driver

      if(trd.op \== 1\) // Write operation  
      begin  
        tr.op     \= trd.op;  
        tr.awaddr \= trd.awaddr;  
        tr.wdata  \= trd.wdata;  
        @(posedge vif.bvalid); // Wait for write response valid  
        tr.wresp  \= vif.wresp;  
        @(negedge vif.bvalid); // Wait for write response valid to go low  
        $display("\[MON\] : OP : %0b awaddr : %0d wdata : %0d wresp:%0d",tr.op, tr.awaddr, tr.wdata, tr.wresp);  
        mbxms.put(tr); // Send observed transaction to scoreboard  
      end  
      else // Read operation  
      begin  
        tr.op \= trd.op;  
        tr.araddr \= trd.araddr;  
        @(posedge vif.rvalid); // Wait for read data valid  
        tr.rdata \= vif.rdata;  
        tr.rresp \= vif.rresp;  
        @(negedge vif.rvalid); // Wait for read data valid to go low  
        $display("\[MON\] : OP : %0b araddr : %0d rdata : %0d rresp:%0d",tr.op, tr.araddr, tr.rdata, tr.rresp);  
        mbxms.put(tr); // Send observed transaction to scoreboard  
      end  
    end  
  endtask  
endclass

### **3.6. scoreboard Class**

The scoreboard receives observed transaction objects from the monitor and compares them against an expected reference model to determine if the DUT behaved correctly.

* mbxms: Mailbox for monitor to scoreboard communication.  
* data\[128\]: A local memory array that acts as the reference model, mirroring the expected state of the DUT's memory.  
* sconext: Event to signal the generator that the scoreboard has processed a transaction.  
* run() task:  
  * For write operations, it checks the wresp. If it's an error (3), it displays "DEC ERROR". Otherwise, it updates its internal data array with the wdata at awaddr.  
  * For read operations, it compares the observed rdata with the expected data from its internal data array at araddr. It displays "DATA MATCHED" or "DATA MISMATCHED" accordingly. It also checks for read errors (rresp \== 3).  
  * After processing, it triggers the sconext event.

class scoreboard;  
  transaction tr,trd;  
  event sconext;

  mailbox \#(transaction) mbxms;

  bit \[31:0\] temp;  
  bit \[31:0\] data\[128\] \= '{default:0}; // Reference memory model

  function new( mailbox \#(transaction) mbxms);  
    this.mbxms \= mbxms;  
  endfunction

  task run();  
    forever  
    begin  
      mbxms.get(tr); // Get observed transaction from monitor

      if(tr.op \== 1\) // Write operation  
      begin  
        $display("\[SCO\] : OP : %0b awaddr : %0d wdata : %0d wresp : %0d",tr.op, tr.awaddr, tr.wdata, tr.wresp);  
        if(tr.wresp \== 3\) // Check for write error response  
          $display("\[SCO\] : DEC ERROR");  
        else begin  
          data\[tr.awaddr\] \= tr.wdata; // Update reference model  
          $display("\[SCO\] : DATA STORED ADDR :%0d and DATA :%0d", tr.awaddr, tr.wdata);  
        end  
      end  
      else // Read operation  
      begin  
        $display("\[SCO\] : OP : %0b araddr : %0d rdata : %0d rresp : %0d",tr.op, tr.araddr, tr.rdata, tr.rresp);  
        temp \= data\[tr.araddr\]; // Get expected data from reference model  
        if(tr.rresp \== 3\) // Check for read error response  
          $display("\[SCO\] : DEC ERROR");  
        else if (tr.rresp \== 0 && tr.rdata \== temp) // Check for data match  
          $display("\[SCO\] : DATA MATCHED");  
        else  
          $display("\[SCO\] : DATA MISMATCHED");  
      end  
      $display("----------------------------------------------------");  
      \-\>sconext; // Signal generator to produce next transaction  
    end  
  endtask  
endclass

### **3.7. Top-Level Testbench Module (tb)**

The tb module instantiates the DUT, the axi\_if interface, and the UVM testbench components. It also manages the clock generation and the simulation flow.

* **DUT Instantiation:** axilite\_s dut (...) connects the DUT to the axi\_if interface.  
* **Clock Generation:** An initial block sets vif.clk to 0, and an always block toggles it every 5 time units, creating a 10ns clock period.  
* **Component Instantiation and Connection:** Mailboxes (mbxgd, mbxms, mbxdm) are created for inter-component communication. generator, driver, monitor, and scoreboard objects are instantiated and connected via these mailboxes.  
* **Virtual Interface Assignment:** The vif is assigned to the driver and monitor instances.  
* **Event Synchronization:** The sconext event is used to synchronize the generator and scoreboard, ensuring that the generator waits for the scoreboard to finish processing before generating a new transaction.  
* **Simulation Flow:**  
  1. drv.reset(): Resets the DUT.  
  2. fork...join\_any: Starts all UVM components (gen.run(), drv.run(), mon.run(), sco.run()) concurrently. join\_any ensures that the simulation continues as long as any of these tasks are running.  
  3. wait(gen.done.triggered): The simulation waits until the generator has completed all its transactions.  
  4. $finish: Terminates the simulation.  
* **VCD Dump:** An initial block sets up VCD dumping for waveform viewing.

module tb;

  monitor mon;  
  generator gen;  
  driver drv;  
  scoreboard sco;

  event nextgd;  
  event nextgm;

  mailbox \#(transaction) mbxgd, mbxms, mbxdm;

  axi\_if vif(); // Instantiate the AXI interface

  // Instantiate the Device Under Test (DUT)  
  axilite\_s dut (vif.clk, vif.resetn, vif.awvalid, vif.awready, vif.awaddr,  
                 vif.wvalid, vif.wready,  vif.wdata,  
                 vif.bvalid, vif.bready,  vif.wresp ,  
                 vif.arvalid, vif.arready, vif.araddr,  
                 vif.rvalid, vif.rready, vif.rdata, vif.rresp);

  // Clock generation  
  initial begin  
    vif.clk \<= 0;  
  end

  always \#5 vif.clk \<= \~vif.clk; // 10ns clock period

  initial begin  
    // Instantiate mailboxes  
    mbxgd \= new();  
    mbxms \= new();  
    mbxdm \= new();

    // Instantiate UVM components  
    gen \= new(mbxgd);  
    drv \= new(mbxgd,mbxdm);  
    mon \= new(mbxms,mbxdm);  
    sco \= new(mbxms);

    // Set generator transaction count  
    gen.count \= 10;

    // Connect virtual interfaces to driver and monitor  
    drv.vif \= vif;  
    mon.vif \= vif;

    // Connect events for synchronization  
    gen.sconext \= nextgm;  
    sco.sconext \= nextgm;  
  end

  initial begin  
    drv.reset(); // Perform reset sequence  
    fork // Start all components concurrently  
      gen.run();  
      drv.run();  
      mon.run();  
      sco.run();  
    join\_any // Continue as long as any task is running  
    wait(gen.done.triggered); // Wait for generator to complete all transactions  
    $finish; // End simulation  
  end

  // VCD dump setup for waveform viewing  
  initial begin  
    $dumpfile("dump.vcd");  
    $dumpvars;  
  end  
endmodule

## **4\. Simulation Results**

### **4.1. Waveform Analysis**

The provided waveform illustrates a typical AXI4-Lite write and read transaction.

* **Write Transaction Example:**  
  * awvalid goes high, indicating a valid write address.  
  * awready goes high in response, acknowledging the address.  
  * wvalid goes high, indicating valid write data.  
  * wready goes high in response, acknowledging the data.  
  * bvalid goes high, indicating a valid write response.  
  * bready goes high, acknowledging the response.  
  * bresp shows the response status (e.g., 00 for OKAY).

{PICTURE}

* **Read Transaction Example:**  
  * arvalid goes high, indicating a valid read address.  
  * arready goes high in response, acknowledging the address.  
  * rvalid goes high, indicating valid read data.  
  * rready goes high, acknowledging the data.  
  * rdata shows the read data.  
  * rresp shows the response status (e.g., 00 for OKAY).

The waveform demonstrates the correct handshake mechanisms and signal transitions as per the AXI4-Lite protocol.

### **4.2. Console Output**

The console output shows the log messages from the generator, driver, monitor, and scoreboard components, confirming the flow of transactions and the scoreboard's verification results.

{PICTURE}

Key observations from the console output:

* \[GEN\]: Shows the randomized transactions generated by the generator.  
* \[DRV\]: Shows the transactions being driven to the DUT.  
* \[MON\]: Shows the transactions observed from the DUT's outputs.  
* \[SCO\]: Shows the scoreboard's comparison results.  
  * "DATA STORED ADDR :%0d and DATA :%0d": Confirms successful write operations and the data being stored in the scoreboard's reference memory.  
  * "DATA MATCHED": Confirms that the data read from the DUT matches the expected data in the scoreboard's reference memory.  
  * "DEC ERROR": Indicates a decode error response from the DUT, typically when an invalid address is accessed.

### **4.3. Schematic Tracer**

The schematic tracer provides a visual representation of the DUT's internal signals and connections, which is useful for debugging and understanding the design's structure.

{PICTURE}

## **5\. How to Simulate**

To simulate this project, you will need a SystemVerilog simulator (e.g., Cadence Xcelium, Synopsys VCS, Mentor QuestaSim).

### **5.1. Downloading the Files**

To run this simulation, you will need to save the provided SystemVerilog code into separate files:

1. **axilite\_s.sv**: Contains the AXI Lite Slave module.  
2. **axi\_if.sv**: Contains the AXI interface definition.  
3. **tb.sv**: Contains the UVM testbench components and top-level module.

Copy the respective code blocks from this documentation and save them into these files in a chosen directory (e.g., axi\_lite\_project/).

### **5.2. Running with Cadence Xcelium**

Once you have saved the files, you can compile and run the simulation using Cadence Xcelium.

1. **Open a terminal or command prompt.**  
2. **Navigate to your project directory:**  
   cd axi\_lite\_project/

3. Compile and Run the simulation:  
   Use the xrun command to compile the SystemVerilog files and run the simulation. The \-sv flag enables SystemVerilog features, \-access \+rwc allows read/write/connect access for debugging, and \-timescale 1ns/1ps sets the simulation timescale.  
   xrun \-sv \-access \+rwc \-timescale 1ns/1ps axi\_if.sv axilite\_s.sv tb.sv

   *Note: If you prefer to use a Tcl script for running, you can create a run.tcl file with run and exit commands and then use xrun \-input run.tcl as shown in the previous version.*  
4. View Waveforms:  
   After the simulation completes, a dump.vcd file will be generated in your project directory. You can open this file with Cadence SimVision (or any compatible waveform viewer) to analyze the signal behavior.  
   simvision dump.vcd

This will generate a dump.vcd file which can be opened with a waveform viewer like SimVision.