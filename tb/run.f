-sv                     # turn on SystemVerilog
-timescale 1ns/1ps      # or whatever your DUT uses
-access +rwc            # allow read/write/change from the GUI or PLI

-incdir ../rtl

// compile files

../rtl/axilite_s.sv // compile YAPP package
tb.sv            // compile top level module


