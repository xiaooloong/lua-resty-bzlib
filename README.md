# Lua-Resty-bzlib

LuaJIT FFI Bindings for bzlib(libbz2.so) - A Lua Bzip2 Library

This library requires LuaJIT and `libbz2.so` to be installed.

You can use `yum install -y bzip2-libs` to install `libbz2.so` on CentOS.

```lua
local bzlib = require 'resty.bzlib'
local bz = bzlib:new()
bin1 = bz:compress('xiaooloong')
bin2 = bz:compress('foobar')

raw1 = bz:decompress(bin1)
raw2 = bz:decompress(bin2)

print(raw1)
print(raw2)
```

[中文说明](./README-zh.md)