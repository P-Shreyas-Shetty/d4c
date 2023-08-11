`include "d4c.sv"
 `include "uvm_macros.svh"
  import uvm_pkg::*;

import d4c::*;

// Test data
  /*
{
  #supports line comment
  "e_raten" : 0b1, #binary int
  "e_rate"  : 100_000_000.0, #real
  "psc_vld" : 0xff, #hexadecimal int
  "pfe_per_oq" : {
    0 : [0,1,2,3], #integer indices and array literal
    1 : [4,5,6,7],
    3 : [1,2,3,4],
  }, #Nested objects
  "name": "A string value", 
  # Depending on the first Key, the type will be determined
  0xff  : "The key here will be interpreted as a string",
}
*/
  class CustomClass extends d4c_base;
    d4c_int#(bit[0:0])                         e_raten;
    d4c_real                                   e_rate;
    d4c_int#(bit[6:0])                         psc_vld;
    d4c_int_map#(.VAL(d4c_array#(d4c_int#()))) pfe_per_oq;
    d4c_string                                 name;

    `d4c_reg_begin
      `d4c_reg_field(e_raten)
      `d4c_reg_field(e_rate)
      `d4c_reg_field(psc_vld)
      `d4c_reg_field(pfe_per_oq)
      `d4c_reg_field(name)
    `d4c_reg_end
  endclass

module d4c_test;

  initial begin
    int fd;
    string content = "";
    string file2 = "";
    string line;
    d4c_int_map#(.KEY(int), .VAL(d4c_array#(d4c_int#(int)))) parsed = new("obj");
    CustomClass cc = new("cc");
    fd = $fopen("example_dict_of_array.cfg", "r");
    while($fgets(line, fd)) begin
      content = { content, line };
    end
    $display("%s", content);
    $fclose(fd);
    $display("Parse start");
    parsed.parse(content);
    $display("Parse done");
    $display("%s", parsed.to_string());
    
    fd = $fopen("example_cfg.d4c", "r");
    while($fgets(line, fd)) begin
      file2 = { file2, line };
    end
    $display("%s", file2);
    $fclose(fd);
    cc.parse(file2);
    $display("%s", cc.to_string());

  end
endmodule
