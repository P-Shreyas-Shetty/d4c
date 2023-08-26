# d4c
Command line and config file parser for SystemVerilog


## What is this for?

D4C parses a data format consisitng of numbers or string, array and map. This data format is somewhat similar to JSON.

Ex: 
```
{
  #Comment
  a: [1,2,3],
  b: "A quoted string", 
  c: {
    a: 0, b:1, c:2
  }, #trailing commas are OK
}
```
The syntax itself is somewhat configurable so as to be command line friendly. 

Ex: 
```
+uvm_set_config_string=\*,cmd_arg,[a-<0:1:2>:b-<3:2:1>]
```

## Basic building blocks
All the buildng block classes have a field `val`, whose type depends on the classes. They also come with method `to_string()` and `parse(string raw_str)`. They all satisfy a virtual class `d4c_base`.
### 1. Atomic types
D4C provides wrapper for basic datatypes of integer, real and string. All the atom types have the field `val`, whose type will be same as the type they are wrapping.
#### a. d4c_int#(T)
Wrapper for integer types. `T` can be any integer type like `int`, `bit[N-1:0]`, `unsigned`, etc.

#### b. d4c_real
Wrapper for `real` type on SV.

#### c. d4c_string
Wrapper for `string` type on SV.

### 2. Array type
D4C defines `d4c_array#(T)` type that represents array of values. The `val` field of this class is a queue of `T`. `T` can be any D4C type (i.e. Atomic type, `d4c_array` or `d4c_map`)

### 3. Map/dictionary type
D4C provides two map types, one for string keys and the other for int keys. `val` field of these types will be a SV associative array.

#### a. d4c_string_map#(VAL)
`val` field is defined as `VAL val[string]`, where `VAL` can be any D4C type (so nested maps are a possibility).

#### b. d4c_int_map#(KEY, VAL)
  `val` field is defined as `VAL val[KEY]`, where `VAL` can be any D4C type (so nested maps are a possibility);   `KEY` can be any SV integer type (Ex: `int`, `byte`, `bit[N-1:0]`, etc).

These basic types can be nested to form more complex regular types.
Ex:
```sv
d4c_string_map#(
    .VAL(
        d4c_int_map#(.KEY(bit[3:0]), 
                     .VAL(d4c_array#(bit[3:0]))
                    )
    )
) cfg = new("cfg_parser");
```

The above type can parse data like below:
```
{
    a: {
        0: [0,1], 1:[2,3]
    },
    b: {
        0: [1,0], 2:[1,3]
    }
}
```

D4C also provides a way to define custom classes for heterogenius data. That will be discussed in usage section next.


## Usage
Include the D4C package

```sv
`include "d4c.sv"

import d4c::*;
```

### 1. Regular data
If the data you are parsing is regular, define a variable of the type you require using building block types. As an example, consider the data that looks like the one in the example in the last section.

```sv
d4c_string_map#(
    .VAL(
        d4c_int_map#(.KEY(bit[3:0]), 
                     .VAL(d4c_array#(bit[3:0]))
                    )
    )
) cfg = new("cfg_parser");
```

Then use the `parse` method to parse a string.
```sv
// If you are parsing it using default syntax of cfg string, the one shown in example
cfg.parse(cfg_string);

//If you are parsing with custom syntax
cfg.parse(cfg_string, .syn_param(D4C_CMD_ARG_SYN))
```

Now we can use the `val` field to get the values

```sv
$display("cfg %s", cfg.to_string()); //to print the read value
foreach(cfg.val[i]) begin
    string key_i = i;
    foreach(cfg.val[i].val[j]) begin
        bit[3:0] key_j = j;
        d4c_array#(bit[3:0]) array_val = cfg.val[i].val[j];
        foreach(arrayval[k]) begin
            bit [3:0] v = array_val[k].val;
            //do ur thing with `v` now
        end
    end
end
```

### 2. Custom class
If you are parsing a custom class data with fields of different data types, you can define custom parser class that inherits from `d4c_base` and D4C param registration macros.

As an example, consider you need to parse below config:

```
{
  "en" : 0b1, #binary int
  "rate"  : 100_000_000.0, #real
  "l_vld" : 0xff, #hexadecimal int
  "foo_per_bar" : {
    0 : [0,1,2,3], #integer indices and array literal
    1 : [4,5,6,7],
    3 : [1,2,3,4],
  }, #Nested objects
  "name": "A string value", 
}

```

You can define a custom D4C class as below:
```sv
class CustomClass extends d4c_base;
    d4c_int#(bit[0:0])                         en;
    d4c_real                                   rate;
    d4c_int#(bit[6:0])                         l_vld;
    d4c_int_map#(.VAL(d4c_array#(d4c_int#()))) foo_per_bar;
    d4c_string                                 name;

    `d4c_reg_begin
      `d4c_reg_field(en)
      `d4c_reg_field(rate)
      `d4c_reg_field(l_vld)
      `d4c_reg_field(foo_per_bar)
      `d4c_reg_field(name)
    `d4c_reg_end
  endclass

```

The `d4c_reg_*` macros autogenerate the `parse` and `to_string` methods. Now we can use `CustomClass` normally.

```sv
CustomClass cc = new("cc");
cc.parse(cfg_string);

//Now use the parsed values
bit[0:0] en   = cc.en.val;
real     rate = cc.rate.val;
string   name = cc.name.val;
```

## Customizing syntax

The `parse` method takes an additional optional argument called `syn_param` of the `type d4c_syn_param_t`, which is defined as below:

```sv
typedef struct {
    byte sep0;
    byte sep1;
    byte open_array;
    byte close_array;
    byte open_map;
    byte close_map;
  } d4c_syn_param_t;

```

In this param struct, one can use their own custom set of characters for syntax. By default, this argument is `'{",", ":", "[", "]", "{", "}"}`, which is defined as parameter `D4C_CFG_FILE_SYN` in the D4C package. The package also provides another syntax config called `D4C_CMD_ARG_SYN`, which is defined as `'{":", "-", "<", ">", "[", "]"}`. The latter is useful because the default syntax is not friendly for UVM command line arguments.

Example usage:
```sv
string ex_cmd_arg = "[foo-<1:2:3>:bar-<2:3:4>]";
d4c_str_map# (.VAL(d4c_array# (d4c_int# ()))) cmd_parser = new("cmd_parser");

cmd_parser.parse(ex_cmd_arg, .syn_param(D4C_CMD_ARG_SYN));

```

Ofcourse the user can define their own syntax.
