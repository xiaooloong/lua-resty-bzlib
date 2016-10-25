# Lua-Resty-bzlib

LuaJIT FFI Bindings for libbzip2 - A Lua Bzip2 Library

This library requires LuaJIT and libbzip2 to be installed.

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

ngx_lua/OpenResty/LuaJIT 使用的 bz2 压缩库，通过 LuaJIT 的 ffi 调用 libbz2.so 中的 c 函数。

使用须安装 libbz2.so 并在 LuaJIT 或 OpenResty 环境下运行。
```bash
yum install -y bzip2-libs
```

流式压缩/解压开坑中...