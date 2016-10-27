# Lua-Resty-bzlib

在 [OpenResty][1] 中使用 [bz2][2] 压缩和解压。

本库使用 [FFI][3] 封装了 bzlib(libbz2.so) 库的数个函数，使得可以使用 Lua 语言，在 OpenResty 中进行 bz2 格式的压缩和解压操作。

## 目录
* [开发进度](#开发进度)
* [使用](#使用)
    * [单次操作](#单次操作)
    * [流式操作](#流式操作)
        * [压缩](#压缩)
        * [解压](#解压)
* [依赖](#依赖)
* [参见](#参见)

## 开发进度

本库是开发中的实验性库，没有进行充分的论证和测试，请勿在生产环境中使用。

[返回目录](#目录)

## 使用

本库封装了两种类型的压缩和解压操作。

[返回目录](#目录)

### 单次操作

```lua
local bzlib = require 'resty.bzlib'
--[[
    local bz = bzlib:new(dest_buff_size)
    dest_buff_size，可选，非 0 自然数，默认大小为 8192
    表示在进行压缩或者解压操作时用于存放输出字符串的缓冲区大小
    如果单次操作中，输出缓冲区耗尽，bzlib 会返回 BZ_OUTBUFF_FULL（-8）
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

[返回目录](#目录)

### 流式操作

如果你有大量的数据要进行操作，单次操作会耗费大量的内存。

你可以使用流式操作，每次读取相对较少的一部分数据进行操作，这样可以有效的降低内存的使用。

[返回目录](#目录)

#### 压缩

流式操作的压缩分为三个步骤。

初始化：
```lua
local bzlib = require 'resty.bzlib.compress'
--[[
    local bz = bzlib:new(
        compresslevel,  压缩级别，可选，1 到 9 的自然数，默认 9
                        定义了 bzlib 压缩时分块的大小，每个分块大小为
                        compresslevel x 100, 000 字节
        workfactor      可选，1 到 250 的自然数，默认 30
                        “最坏形况以及高重复度情况下的参数”
    bzlib:new() 所返回的 bz，在压缩结束时，无论是否出错，
    都要调用 bz:finish() 来结束压缩。
    )
]]--
local bz = bzlib:new()

local name = 'agw.log'
local fd1 = io.open(name, 'r')
local fd2 = io.open(name .. '.bz2', 'wb')
```

传入数据：
```lua
while true do
    local ln = fd1:read('*line')
    if not ln then
        break
    end
    --[[
        local part, err = bz:append(text)
        每次将要压缩的部分数据传入 append 函数
        如果压缩过程失败会返回 nil 和一个错误信息
    ]]--
    local part, err = bz:append(ln .. '\n')
    if not part then
        print(err)
        break
    end
    --[[
        每次成功的压缩有可能并不返回数据，
        这些数据暂时缓存在 bzlib 中。
        此时返回为 ''，也就没有写文件的必要了
    ]]--
    if #part > 0 then
        fd2:write(part)
    end
end
fd1:close()
```

结束压缩：
```lua
--[[
    使用 bz:finish() 告诉 bzlib 压缩结束，
    bzlib 会将缓存的所有数据返回。
    这些数据是压缩流的结尾。
]]--
local part, err = bz:finish()
if not part then
    print(err)
end
fd2:write(part)
fd2:close()
```

注意：

无论 `compress:append()` 是否成功，结束时都必须调用 `compress:finish()`

[返回目录](#目录)

#### 解压

流式操作的解压分为两个步骤。

初始化：
```lua
local bzlib = require 'resty.bzlib.decompress'
--[[
    local bz = bzlib:new(reducemem)
    reducemem，可选，默认为 0 表示使用默认算法。
    否则 bzlib 将使用一个外部算法来降低解压时使用的内存，
    同时减慢解压的速度。
]]--
local bz = bzlib:new()

local name = 'agw.log.bz2'
local fd1 = io.open(name, 'rb')
local fd2 = io.open(name .. '.txt', 'wb')
```

传入数据：
```lua
while true do
    local bin = fd1:read(4096)
    if not bin then break end
    --[[
        local text, finish, err = bz:append(bin)
        每次成功的解压都会返回字符串 text，
        并使用 finish 告知压缩流是否解压完成。
        如果 text 为 nil，则 err 会包含错误信息。
    ]]--
    local text, finish, err = bz:append(bin)
    if not text then
        print('append no return')
        break
    end
    fd2:write(text)
    if finish then
        print('stream end')
        break
    end
end
fd1:close()
fd2:close()
```

bzip2 的压缩流本身包含开头和结尾。因此不同于流式压缩，解压时 zlib 库本身可以知道压缩的结束。
因此在 `decompress:append()` 方法中，在出错和解压结束时会自动调用结束方法，不需要使用者手动结束。

[返回目录](#目录)

## 依赖

由于使用了 bzlib 库，需要使用者手动安装 libbz2.so。

CentOS 下可以使用 `yum` 安装

```bash
yum install -y bzip2-libs
```

[返回目录](#目录)

## 参见

 * bzip 手册：http://www.bzip.org/1.0.5/bzip2-manual-1.0.5.html

[返回目录](#目录)

  [1]: http://openresty.org/cn/
  [2]: http://www.bzip.org/
  [3]: http://luajit.org/ext_ffi.html