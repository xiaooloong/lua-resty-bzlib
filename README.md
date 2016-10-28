# Lua-Resty-bzlib
[中文说明](./README-zh.md)

LuaJIT FFI Bindings for bzlib(libbz2.so) - A Lua Bzip2 Library for OpenResty

## Contents
* [Status](#status)
* [Usage](#usage)
    * [Simple Interface](#simple-interface)
    * [Streaming Interface](#streaming-interface)
        * [Compress](#compress)
        * [Decompress](#decompress)
* [Prerequisites](#prerequisites)
* [See Also](#see-also)

## Status

This library is considered experimental.

[Back to Contents](#contents)

## Usage

This library implements two sorts of interfaces.

[Back to Contents](#contents)

### Simple Interface

```lua
local bzlib = require 'resty.bzlib'
--[[
    local bz = bzlib:new(
        dest_buff_size  -- Optional, default is 8192.
        -- The libbz2.so will return BZ_OUTBUFF_FULL(-8)
        -- if this buffer size is not enough to storage
        -- the output data.
    )
]]--
local bz = bzlib:new()
local bin1 = bz:compress('xiaooloong')
local bin2 = bz:compress('foobar')

local text1 = bz:decompress(bin1)
local text2 = bz:decompress(bin2)

print(text1, '\n', text2)
--[[
[root@localhost ~]# resty a.lua 
xiaooloong
foobar
]]--
```

[Back to Contents](#contents)

### Streaming Interface

#### Compress

Initialize:
```lua
local bzlib = require 'resty.bzlib.compress'
--[[
    local bz = bzlib:new(
        compresslevel,  -- Optional, default is 9.
        workfactor      -- Optional, default is 30.
        -- In fact, these two are parameters 'blockSize100k'
        -- and 'workFactor' of the function 'BZ2_bzCompressInit'
    )
]]--
local bz = bzlib:new()

local name = 'agw.log'
local fd1 = io.open(name, 'r')
local fd2 = io.open(name .. '.bz2', 'wb')
```

Append data:
```lua
while true do
    local ln = fd1:read('*line')
    if not ln then
        break
    end
    --[[
        local part, err = bz:append(text)
        -- Append part of data to this method.
        -- In case of failed to compress, it will return
        -- nil and a string contains error message.
    ]]--
    local part, err = bz:append(ln .. '\n')
    if not part then
        print(err)
        break
    end
    --[[
        The returned string may be '' because libbz2.so may buffer some data.
        In this case, there is no need to write the file.
    ]]--
    if #part > 0 then
        fd2:write(part)
    end
end
fd1:close()
```

Clean up:
```lua
--[[
    Use bz:finish() to tell libbz2.so that compress comes to an end.
    This method will return all remaining data the libbz2.so has buffered.
]]--
local part, err = bz:finish()
if not part then
    print(err)
end
fd2:write(part)
fd2:close()
```

Note:

Whatever `compress:append()` is returned, you must call `compress:finish()` after `bzlib:new()`

[Back to Contents](#contents)

#### Decompress

Initialize:
```lua
local bzlib = require 'resty.bzlib.decompress'
--[[
    local bz = bzlib:new(
        reducemem   -- Optional. Default is 0.
        -- In fact, this parameters is 'small'
        -- of the function 'BZ2_bzDecompressInit'
    )
]]--
local bz = bzlib:new()

local name = 'agw.log.bz2'
local fd1 = io.open(name, 'rb')
local fd2 = io.open(name .. '.txt', 'wb')
```

Append data:
```lua
while true do
    local bin = fd1:read(4096)
    if not bin then break end
    --[[
        local text, finish, err = bz:append(bin)
        -- Append part of data to this method.
        -- In case of success, 'finish' tells you wheather
        -- the compressed stream comes to an end. That means
        -- you can finish decompress when 'finish' is true.
        -- In case of failed, it will return
        -- nil and a string contains error message.
    ]]--
    local text, finish, err = bz:append(bin)
    if not text then
        print('append no return')
        break
    end
    --[[
        The returned string may be '' because libbz2.so may buffer some data.
        In this case, there is no need to write the file.
    ]]--
    if #text > 0 then
        fd2:write(text)
    end
    if finish then
        print('stream end')
        break
    end
end
fd1:close()
fd2:close()
```

The bzip2 stream contains header and end-of-stream itself. The `decompress:append()` will 
automaticlly do a cleanning up if decompress is failed or over.

[Back to Contents](#contents)

## Prerequisites

This library requires `LuaJIT` and `libbz2.so` to be installed.

For CentOS users, you can install `libbz2.so` by the following command:
```bash
yum install -y bzip2-libs
```

[Back to Contents](#contents)

## See Also

 * bzip2 man page: http://www.bzip.org/1.0.5/bzip2-manual-1.0.5.html

[Back to Contents](#contents)

  [1]: http://openresty.org/cn/
  [2]: http://www.bzip.org/
  [3]: http://luajit.org/ext_ffi.html