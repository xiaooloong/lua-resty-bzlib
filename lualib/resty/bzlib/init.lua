local ffi = require 'ffi'
local ffi_new = ffi.new
local ffi_string = ffi.string
local type = type
local tonumber = tonumber

ffi.cdef[[
int BZ2_bzBuffToBuffCompress (
    char*         dest,
    unsigned int* destLen,
    char*         source,
    unsigned int  sourceLen,
    int           blockSize100k,
    int           verbosity,
    int           workFactor
);
int BZ2_bzBuffToBuffDecompress (
    char*         dest,
    unsigned int* destLen,
    char*         source,
    unsigned int  sourceLen,
    int           small,
    int           verbosity
);
]]
local unit_prt_type = ffi.typeof('unsigned int[1]')

local bzlib = ffi.load('bz2')

local BZ_OK = 0

local blockSize100k = 9
local workFactor = 30
local small = 0

local max_size = 8192

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32)

_M._VERSION = '0.1.3'

local mt = { __index = _M }

function _M.new(self, dest_buff_size)
    local size = tonumber(dest_buff_size) or max_size
    if 0 >= size then
        size = max_size
    end
    local dest_buff = ffi_new('char[' .. size .. ']')
    local dest_size = ffi_new(unit_prt_type, size)
    return setmetatable({
        buff_size = size,
        dest_buff = dest_buff,
        dest_size = dest_size,
    }, mt)
end

function _M.compress(self, text, compresslevel, workfactor)
    if not self.buff_size then
        return nil, 'not initialized'
    end
    local level = tonumber(compresslevel) or blockSize100k
    if 1 > level or 9 < level then
        return nil, 'compresslevel must between 1 and 9'
    end
    local factor = tonumber(workfactor) or workFactor
    if 1 > factor or 250 < factor then
        return nil, 'workfactor must between 1 and 250'
    end
    if not text or 'string' ~= type(text) or 1 > #text then
        return nil, 'there must be at least 1 byte text'
    end
    local src_buff = ffi_new('char[' .. #text .. ']', text)
    local ok = bzlib.BZ2_bzBuffToBuffCompress(
        self.dest_buff, self.dest_size,
        src_buff, #text,
        level, 0, factor
    )
    local result
    if BZ_OK == ok then
        result = ffi_string(self.dest_buff, self.dest_size[0])
    end
    self.dest_size[0] = self.buff_size
    return result, ok
end

function _M.decompress(self, bin, reducemem)
    if not self.buff_size then
        return nil, 'not initialized'
    end
    local reduce = tonumber(reducemem) or small
    if not bin or 'string' ~= type(bin) or 1 > #bin then
        return nil, nil, 'there must be at least 1 byte binary'
    end
    local src_buff = ffi_new('char[' .. #bin .. ']', bin)
    local ok = bzlib.BZ2_bzBuffToBuffDecompress(
        self.dest_buff, self.dest_size,
        src_buff, #bin,
        reduce, 0
    )
    local result
    if BZ_OK == ok then
        result = ffi_string(self.dest_buff, self.dest_size[0])
    end
    self.dest_size[0] = self.buff_size
    return result, ok
end
return _M