-sv                     # turn on SystemVerilog
-timescale 1ns/1ps      # or whatever your DUT uses
-access +rwc            # allow read/write/change from the GUI or PLI

axilite_s.sv     // compile AXI rtl file
tb.sv            // compile testbench

