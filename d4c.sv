`ifndef __D4C_SV__
`define __D4C_SV__

//======================================================================
// This package is used to parse the D4C format, a format that is very 
// similar to json. I can be used to parse either complex command line
// arguments or from a config file
// The file format in question consists of three types:
//     Atom/Value: The most basic type. This can be a wrapped integer, 
//                 string or real number.
//     Array     : List of values of any types. 
//     Map       : This is the dictionary. Key can be string or integer
//                 value can be any type
//     A typical file can look like:
//       {#line comments allowed
//          a: "foo", #string key, string val
//          b: {0: [1,2,3], 2:[3,4,5] }, #nested structure; int key & array
//          c: 0x900,  #hex integer
//          d: 0b100,  #binary integer
//          e: 0o700,  #octal integer
//          f: 700,    #decimal integer
//          d: 1000000.0, #real
//       }
//     The braces, brackets and seperators are all parametrized. 
//     
//   Ex Command line arg with different seperators:
//        [a-<1:2:3>:b-<3:4:5>] (arguably ugly, but this works with uvm_set_config_string)
//
//       
//======================================================================


`define d4c_reg_begin d4c_stringer string_builder = new();                     \
        function new(string name);                                             \
          super.new(name);                                                     \
        endfunction                                                            \
        virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);       \
          d4c_syntree_map node_map;                                            \
          if(node.ty!=MAP) begin                                               \
            `uvm_fatal(get_name(), $psprintf("Expected Map at %s", node.pos))  \
          end                                                                  \
          else begin                                                           \
            $cast(node_map, node);                                             \
          end

`define d4c_reg_field(__d4c_field, __d4c_default=null)                              \
          if(!node_map.val.exists(`"__d4c_field`")) begin                           \
            __d4c_field = __d4c_default;                                            \
            if(__d4c_field == null ) begin                                          \
              `uvm_fatal(get_name(), {"Field ", `"__d4c_field`", " not passed!!!"}) \
            end                                                                     \
          end                                                                       \
          else begin                                                                \
            __d4c_field = new($psprintf("%s.%0s", get_name(), `"__d4c_field`"));    \
            __d4c_field.parse_from_syntree(node_map.val[`"__d4c_field`"].v, .syn_param(syn_param));        \
          end                                                                       \
          string_builder.params[`"__d4c_field`"] = __d4c_field; 


`define d4c_reg_end endfunction                        \
      virtual function string to_string(int indent=0); \
        return string_builder.build(indent);           \
      endfunction
            
            

package d4c;

  `include "uvm_macros.svh"
  import uvm_pkg::*;

  // defining syntax.
  // syntax is configrable, we can set any character 
  // as seperator or as brackets
  // I have chosen mostly  a json like syntax for cfg file
  // but these same syntax might not work exactly when used as
  // UVM set_config_string
  // I have defined two sets of syntax params, one for cfg file
  // and one for command line friendliness. Howver, user
  // is free to write his own set of syntax symbols
  parameter byte SEP0 = ",";
  parameter byte SEP1 = ":";
  parameter byte OPEN_ARRAY = "[";
  parameter byte CLOSE_ARRAY = "]";
  parameter byte OPEN_MAP = "{";
  parameter byte CLOSE_MAP = "}";
  
  //syntax param struct to define your own syntax
  typedef struct {
    byte sep0;
    byte sep1;
    byte open_array;
    byte close_array;
    byte open_map;
    byte close_map;
  } d4c_syn_param_t;

  //predefined syntax struct for cfg files
  //defined with this, cfg file will look like: {foo: [1,2,3], bar:[2,3,4]}
  parameter d4c_syn_param_t D4C_CFG_FILE_SYN = '{
    SEP0, 
    SEP1,
    OPEN_ARRAY,
    CLOSE_ARRAY,
    OPEN_MAP,
    CLOSE_MAP
  };

  //predefined syntax struct that is command line friendly
  //defined with this, arg will look like: [foo-<1:2:3>:bar-<2:3:4>]
  parameter d4c_syn_param_t D4C_CMD_ARG_SYN = '{
     ":", "-", "<", ">", "[", "]"
  };

  
  // this is an internal implentation detail
  // not visible outside
  typedef enum {MAP, ARRAY, VAL} node_t;

  // ptr_t: This class is used to keep track of line and pos
  //        of praser in the input string
  class ptr_t;
    int unsigned line;
    int unsigned pos;
    int unsigned p;

    function new();
      line = 1;
      pos = 1;
      p = 0;
    endfunction

    function ptr_t clone();
      ptr_t clone_ptr = new();
      clone_ptr.line    = this.line;
      clone_ptr.pos     = this.pos;
      clone_ptr.p = this.p;
      return clone_ptr;
    endfunction

    function void inc();
      p++;
      pos++;
    endfunction

    // increments the ptr to next line
    function void inc_line();
      line++;
      pos = 1;
    endfunction

    function string to_string();
      return $psprintf("{line:%0d, pos:%0d}", line, pos);
    endfunction
  endclass
  
  // This class is used for intermediate representation of the string
  // it is passed
  // General syntax of a D4C Object:
  // key := <string>
  // obj := val | array | map
  // val := "<string>" | <word>
  // array := [obj,...]
  // map   := {key: obj,...}
  class d4c_syntree_base;
    node_t ty;
    ptr_t pos;

    static function void skip_ws_cmt(ref string raw_str, ref ptr_t ptr);
      forever begin
        //Handle line comments
        if(raw_str[ptr.p] == "#") begin: comment_skip
          while(raw_str[ptr.p]!="\n") ptr.inc();
          ptr.inc_line();
          ptr.inc();
        end: comment_skip

        else if(raw_str[ptr.p]==" " || raw_str[ptr.p]=="\t") begin: skip_ws
          ptr.inc();
        end: skip_ws

        else if(raw_str[ptr.p]=="\n") begin: skip_nl
          ptr.inc();
          ptr.inc_line();
        end: skip_nl
        else break;
      end
    endfunction

    extern virtual function d4c_syntree_base parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);

    virtual function string to_string(int indent=0);
    endfunction
      
  endclass: d4c_syntree_base

  // d4c_syntree_val: This class is used to parse the atomic value
  //             In this intermediate version, values are 
  // always parsed as string so that in the next stage it can be
  // read as proper types
  class d4c_syntree_val extends d4c_syntree_base;
    string val;

    function new();
      ty  = VAL;
    endfunction

    extern function d4c_syntree_base parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN); 
    
    virtual function string to_string(int indent=0);
      return $psprintf("%sVAL{%s}", {indent{"  "}}, val); 
    endfunction
  endclass

  // D$CNodeArray: This class is used to parse an array type
  class d4c_syntree_array extends d4c_syntree_base;
    d4c_syntree_base val[$];

    function new();
      ty  = ARRAY;
    endfunction

    extern function d4c_syntree_base parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN); 

    function string to_string(int indent=0);
      string s = $psprintf("%s%s\n", {indent{"  "}}, OPEN_ARRAY);
      foreach(val[i])
        s = {s, val[i].to_string(indent+1), "\n"};
      s = {s, $psprintf("%s%s", {indent{"  "}}, CLOSE_ARRAY)};
      return s;
    endfunction

  endclass

  // D$CNodeMap: This is a dictionary type
  class d4c_syntree_map extends d4c_syntree_base;
    struct {d4c_syntree_val k; d4c_syntree_base v;} val[string];

    function new();
      ty  = MAP;
    endfunction

    extern function d4c_syntree_base parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);

    function string to_string(int indent=0);
      string s = $psprintf("%s%s\n", {indent{"  "}}, OPEN_MAP);
      foreach(val[i]) begin
        s = {s, $psprintf("%s%s:", {indent{"  "}}, val[i].k.val)};
        s = {s, val[i].v.to_string(indent+1), "\n"};
      end
      s = {s, $psprintf("%s%s", {indent{"  "}}, CLOSE_MAP)};
      return s;
    endfunction
  endclass

  function d4c_syntree_base d4c_syntree_base::parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
    d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
    if(raw_str.len() == 0) `uvm_fatal(name, "Unexpected EOF") 
    if(raw_str[ptr.p]=="\"") begin
      d4c_syntree_val v = new();
      void'(v.parse(raw_str, ptr, name, .syn_param(syn_param)));
      return v;
    end
    else if(raw_str[ptr.p]==syn_param.open_array) begin
      d4c_syntree_array a = new();
      void'(a.parse(raw_str, ptr, name, .syn_param(syn_param)));
      return a;
    end
    else if(raw_str[ptr.p]==syn_param.open_map) begin
      d4c_syntree_map m = new();
      void'(m.parse(raw_str, ptr, name, .syn_param(syn_param)));
      return m;
    end
    else begin
      d4c_syntree_val v = new();
      void'(v.parse(raw_str, ptr, name, .syn_param(syn_param)));
      return v;
    end
  endfunction:parse

  function d4c_syntree_base d4c_syntree_val::parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(raw_str[ptr.p]=="\"") begin: quote_parse
        ptr_t str_start = ptr.clone();
        ptr_t str_end;
        pos = ptr.clone();
        ptr.inc();
        while(raw_str[ptr.p]!="\"") begin
          ptr.inc();
          if(raw_str.len()==ptr.p) `uvm_fatal(name, "Unexpected EOF")
        end
        val = raw_str.substr(str_start.p+1, ptr.p-1);
        ptr.inc();
      end: quote_parse
      else begin
        ptr_t str_start = ptr.clone();
        ptr_t str_end;

        pos = ptr.clone();
        if(raw_str.len()==ptr.p+1) `uvm_fatal(name, "Unexpected EOF")
        while(raw_str[ptr.p]!=" " && 
              raw_str[ptr.p]!="\n" && 
              raw_str[ptr.p]!="\t" && 
              raw_str[ptr.p]!=syn_param.sep0 &&
              raw_str[ptr.p]!=syn_param.sep1 &&
              raw_str[ptr.p]!=syn_param.close_array &&
              raw_str[ptr.p]!=syn_param.close_map &&
              raw_str.len()!=ptr.p+1) begin
          ptr.inc();
        end
        val = raw_str.substr(str_start.p, ptr.p-1);
      end
      return this;
    endfunction

  function d4c_syntree_base d4c_syntree_array::parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      ptr_t start_ptr = ptr.clone();
      if(raw_str[ptr.p]==syn_param.open_array) begin
        pos = ptr.clone();
        ptr.inc();
        while(raw_str[ptr.p]!=syn_param.close_array) begin
          d4c_syntree_base next_item = new();
          d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
          next_item = next_item.parse(raw_str, ptr, name, .syn_param(syn_param));
          
          this.val.push_back(next_item);
          d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
          if(raw_str[ptr.p]==syn_param.sep0) ptr.inc();
          else if(raw_str[ptr.p]==syn_param.close_array);
          else `uvm_fatal(name, {"Parsing error:: Expected a `", syn_param.sep0, "` at ", ptr.to_string(), " Got `", raw_str.substr(ptr.p, ptr.p), "`"})
          d4c_syntree_base::skip_ws_cmt(raw_str, ptr);

        end
        ptr.inc();
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
      end
      d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
      return this;
    endfunction

  function d4c_syntree_base d4c_syntree_map::parse(ref string raw_str, ref ptr_t ptr, input string name, input bit is_key=0, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
    if(raw_str[ptr.p]==syn_param.open_map) begin
      pos = ptr.clone();
      ptr.inc();
      while(raw_str[ptr.p]!=syn_param.close_map) begin
        d4c_syntree_val key = new(); //The key will be parsed by a `Map` type
        d4c_syntree_base val = new(); // The `Value` will be parsed as arbitrary D4C type
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
        $cast(key, key.parse(raw_str, ptr, name, .is_key(1), .syn_param(syn_param))); //parse the key as, well key; i.e. seperator in concern is SEP1
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
        if(raw_str[ptr.p]==syn_param.sep1) ptr.inc();
        else `uvm_fatal(name, {"Parsing error:: Expected a `", syn_param.sep1, "` at ", ptr.to_string(), " Got `", raw_str.substr(ptr.p, ptr.p), "`"})
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
        val = val.parse(raw_str, ptr, name, .syn_param(syn_param)); //Get the value now
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
        if(raw_str[ptr.p]==syn_param.sep0) ptr.inc();
        else if(raw_str[ptr.p]==syn_param.close_map) ;
        else `uvm_fatal(name, {"Parsing error:: Expected a `", syn_param.sep0, "` at ", ptr.to_string(), " Got `", raw_str.substr(ptr.p, ptr.p), "`"})

        this.val[key.val] = '{key, val};
        d4c_syntree_base::skip_ws_cmt(raw_str, ptr);

      end
      ptr.inc();
      d4c_syntree_base::skip_ws_cmt(raw_str, ptr);
    end
    return this;
  endfunction: parse

  ///////////////////////////////////////////////////////////////////////

  //the classes below are the actual user code


  //Base class for all other datatype
  //This class can't be instantiated
  //this is an "abstract" class
  virtual class d4c_base extends uvm_object;
    function new(string name);
      super.new(name);
    endfunction

    virtual function void parse(ref string raw_str, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      d4c_syntree_base n = new();
      ptr_t p = new();
      n = n.parse(raw_str, p, "temp_d4c_syn_tree", .syn_param(syn_param));
      parse_from_syntree(n);
    endfunction: parse

    pure virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
    pure virtual function string to_string(int indent=0);
  endclass: d4c_base
  
  // Wrapper for Integet types. T can be any in type, signed, unsigned or bit
  class d4c_int#(type T=int) extends d4c_base;

    T val;
    function new(string name);
      super.new(name);
    endfunction

    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty != VAL) begin
        `uvm_fatal(get_name(), $psprintf("Expected an Integer value at %s", node.pos.to_string()))
      end
      else begin
        d4c_syntree_val nodev;
        $cast(nodev, node);
        if(nodev.val.len()<2)
          val = nodev.val.atoi();
        else if(nodev.val.substr(0,1) == "0b")
          val = nodev.val.substr(2, nodev.val.len()-1).atobin(); 
        else if(nodev.val.substr(0,1) == "0x")
          val = nodev.val.substr(2, nodev.val.len()-1).atohex();
        else if(nodev.val.substr(0,1) == "0o")
          val = nodev.val.substr(2, nodev.val.len()-1).atooct();
        else
          val = nodev.val.atoi();
      end
    endfunction: parse_from_syntree

    function string to_string(int indent=0);
      return $psprintf("%s%0x", {indent{"  "}}, val);
    endfunction

  endclass: d4c_int

  // Wrapper class for real/float type
  class d4c_real extends d4c_base;
    real val;
    
    function new(string name);
      super.new(name);
    endfunction

    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty != VAL) begin
        `uvm_fatal(get_name(), $psprintf("Expected an real value at %s", node.pos.to_string()))
      end
      else begin
        d4c_syntree_val nodev;
        $cast(nodev, node);

        val = nodev.val.atoreal(); 
      end
    endfunction: parse_from_syntree

    function string to_string(int indent=0);
      return $psprintf("%s%0f", {indent{"  "}}, val);
    endfunction

  endclass: d4c_real

  // wrapper for string type
  class d4c_string extends d4c_base;
    string val;

    function new(string name);
      super.new(name);
    endfunction

    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty != VAL) begin
        `uvm_fatal(get_name(), $psprintf("Expected a string value at %s", node.pos.to_string()))
      end
      else begin
        d4c_syntree_val nodev;
        $cast(nodev, node);

        val = nodev.val; 
      end
    endfunction: parse_from_syntree

    function string to_string(int indent=0);
      return $psprintf("%s\"%0s\"", {indent{"  "}}, val);
    endfunction

  endclass: d4c_string
  
  // Array type; T here can be any of d4c types that inherit d4c_base
  class d4c_array#(type T=d4c_int#(int)) extends d4c_base;
    T val[$];

    function new(string name);
      super.new(name);
    endfunction
    
    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty == ARRAY) begin
        d4c_syntree_array node_a;
        $cast(node_a, node);
        foreach(node_a.val[i]) begin
          T v = new($psprintf("%s_val_%0d", get_name(), i));
          v.parse_from_syntree(node_a.val[i], .syn_param(syn_param));
          this.val.push_back(v);
        end
      end
      else 
        `uvm_fatal(get_name(), $psprintf("Expected Array at %s", node.pos.to_string()))
    endfunction 

    function string to_string(int indent=0);
      string s = {{indent{"  "}}, "[\n"};
      foreach(val[i]) begin
        s = {s, val[i].to_string(indent+1), ",\n"};
      end
      s = {s, {indent{"  "}}, "]"};
      return s;
    endfunction

  endclass: d4c_array
  
  
  // Map with integer keys; VAL here can be any of d4c types that inherit d4c_base
  // KEY can be any integer type
  class d4c_int_map#(type KEY=int, VAL=d4c_int#(int)) extends d4c_base;
    VAL val[KEY];

    function new(string name);
      super.new(name);
    endfunction

    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty == MAP) begin
        d4c_syntree_map node_map;
        $cast(node_map, node);
        foreach(node_map.val[i]) begin
          VAL v = new($psprintf("%s[%0d]", get_name(), i));
          d4c_int#(KEY) temp_key_val = new("temp_key_val");
          temp_key_val.parse_from_syntree(node_map.val[i].k, .syn_param(syn_param));
          v.parse_from_syntree(node_map.val[i].v, .syn_param(syn_param));
          this.val[temp_key_val.val] =  v;
        end
      end
      else  begin
        `uvm_fatal(get_name(), $psprintf("Expected Map at %s", node.pos.to_string()))
      end

    endfunction 
    
    function string to_string(int indent=0);
      string s = {{indent{"  "}}, "{\n"};
      foreach(val[i]) begin
        s = {s, $psprintf("%s%0x:\n", {indent{"  "}},i), val[i].to_string(indent+1), ",\n"};
      end
      s = {s, {indent{"  "}}, "}"};
      return s;
    endfunction

  endclass: d4c_int_map
  
  // Map with string keys; VAL here can be any of d4c types that inherit d4c_base
  class d4c_str_map#(type VAL=d4c_int#(int)) extends d4c_base;
    VAL val[string];

    function new(string name);
      super.new(name);
    endfunction
    
    virtual function void parse_from_syntree(d4c_syntree_base node, input d4c_syn_param_t syn_param=D4C_CFG_FILE_SYN);
      if(node.ty == MAP) begin
        d4c_syntree_map node_map;
        $cast(node_map, node);
        foreach(node_map.val[i]) begin
          VAL v =new($psprintf("%s[%0d]", get_name(), i));
          d4c_string temp_key_val = new("temp_key_val");
          temp_key_val.parse_from_syntree(node_map.val[i].k, .syn_param(syn_param));
          v.parse_from_syntree(node_map.val[i].v, .syn_param(syn_param));
          this.val[temp_key_val.val] =  v;
        end
      end
      else begin
        `uvm_fatal(get_name(), $psprintf("Expected Map at %s", node.pos.to_string()))
      end
    endfunction 

    function string to_string(int indent=0);
      string s = {{indent{"  "}}, "{\n"};
      foreach(val[i]) begin
        s = {s, $psprintf("%s%0s:\n", {indent{"  "}},i), val[i].to_string(indent+1), ",\n"};
      end
      s = {s, {indent{"  "}}, "}"};
      return s;
    endfunction

  endclass: d4c_str_map

  // this is also not useful outside this package. It is a "string builder"
  // class, useful in our custom class generator macros
  class d4c_stringer;
    d4c_base params[string];

    function string build(int indent=0);
      string ret;
      foreach(params[p_name]) begin
        if(ret=="")
          ret = {{indent{"  "}}, "{\n", {(indent+1){"  "}}, p_name, ":", params[p_name].to_string(indent+2)} ;
        else 
          ret = {ret, ",\n", {(indent+1){"  "}}, p_name, ":", params[p_name].to_string(indent+2)};
      end
      ret = {ret, "\n", {indent{"  "}}, "}"};
      return ret;
    endfunction
  endclass

endpackage: d4c 

`endif // __D4C_SV__
