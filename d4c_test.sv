`include "d4c.sv"
 `include "uvm_macros.svh"
  import uvm_pkg::*;

import d4c::*;

// Test data
  /*
{
  "en" : 0b1, #int
  "rate"  : 100_000_000.0, #real
  "l_vld" : 0xff, 
  "m_per_n" : {
    0 : [0,1,2,3], #integer indices and array literal
    1 : [4,5,6,7],
    3 : [1,2,3,4],
  }, #Nested objects
  "name": "A string value", 
  # This will get ignored
  0xff  : "The key here will be interpreted as a string",
}
*/
  class CustomClass extends d4c_base;
    d4c_int#(bit[0:0])                         en;
    d4c_real                                   rate;
   d4c_int#(bit[6:0])                         l_vld;
   d4c_int_map#(.VAL(d4c_array#(d4c_int#()))) m_per_n;
    d4c_string                                 name;

    `d4c_reg_begin
      `d4c_reg_field(en)
      `d4c_reg_field(rate)
      `d4c_reg_field(l_vld)
      `d4c_reg_field(m_per_n)
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
    fd = $fopen("example_dict_of_array.txt", "r");
    while($fgets(line, fd)) begin
      content = { content, line };
    end
    $display("%s", content);
    $fclose(fd);
    $display("Parse start");
    parsed.parse(content);
    $display("Parse done");
    $display("%s", parsed.to_string());
    
   fd = $fopen("example_cfg.txt", "r");
    while($fgets(line, fd)) begin
      file2 = { file2, line };
    end
    $display("%s", file2);
    $fclose(fd);
    cc.parse(file2);
    $display("%s", cc.to_string());

  end
endmodule
