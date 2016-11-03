local ffi = require 'ffi'
local ffi_new = ffi.new
local ffi_string = ffi.string
local type = type
local tonumber = tonumber

ffi.cdef[[
typedef struct {
    char *next_in;
    unsigned int avail_in;
    unsigned int total_in_lo32;
    unsigned int total_in_hi32;

    char *next_out;
    unsigned int avail_out;
    unsigned int total_out_lo32;
    unsigned int total_out_hi32;

    void *state;

    void *(*bzalloc)(void *,int,int);
    void (*bzfree)(void *,void *);
    void *opaque;
} bz_stream;
int BZ2_bzDecompressInit (bz_stream *strm, int verbosity, int small);
int BZ2_bzDecompress (bz_stream* strm);
int BZ2_bzDecompressEnd (bz_stream *strm);
]]

local bzlib = ffi.load('bz2')
local action = {
    run    = 0,
    flush  = 1,
    finish = 2,
}
local ret = {
    [0]  = 'ok',
    [1]  = 'run_ok',
    [2]  = 'flush_ok',
    [3]  = 'finish_ok',
    [4]  = 'stream_end',
    [-1] = 'sequence_error',
    [-2] = 'param_error',
    [-3] = 'mem_error',
    [-4] = 'data_error',
    [-5] = 'data_error_magic',
    [-6] = 'io_error',
    [-7] = 'unexpected_eof',
    [-8] = 'outbuff_full',
    [-9] = 'config_error',
}

local BZ_MAX_UNUSED = 5000
local small = 0

local bz_stream_struct_type = ffi.typeof('bz_stream')
local dest_buff_prt_type = ffi.typeof('char[' .. BZ_MAX_UNUSED .. ']')

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32)

local mt = { __index = _M }

function _M.new(self, reducemem)
    local reduce = 0 == reducemem and 0 or 1
    local strm = ffi_new(bz_stream_struct_type)
    local buff_out = ffi_new(dest_buff_prt_type)
    local ok = bzlib.BZ2_bzDecompressInit(strm, 0, reduce)
    if 'ok' == ret[ok] then
        return setmetatable({
            strm = strm,
            buff_out = buff_out,
        }, mt)
    else
        return nil, ret[ok]
    end
end

function _M.append(self, bin)
    local strm = self.strm
    if not strm then
        return nil, nil, 'not initialized'
    end
    if not bin or 'string' ~= type(bin) or 1 > #bin then
        return nil, nil, 'there must be at least 1 byte binary'
    end
    local buff_out = self.buff_out
    local buff_in = ffi_new('char[' .. #bin .. ']', bin)
    strm.next_in = buff_in
    strm.avail_in = #bin
    local text = ''
    while true do
        strm.avail_out = BZ_MAX_UNUSED
        strm.next_out = buff_out
        local ok = bzlib.BZ2_bzDecompress(strm)
        if 'ok' ~= ret[ok] and 'stream_end' ~= ret[ok] then
            bzlib.BZ2_bzDecompressEnd(strm)
            return nil, false, ret[ok]
        end
        if 'stream_end' == ret[ok] then
            local len = BZ_MAX_UNUSED - strm.avail_out
            text = text .. ffi_string(buff_out, len)
            bzlib.BZ2_bzDecompressEnd(strm)
            return text, true
        end
        if strm.avail_out < BZ_MAX_UNUSED then
            local len = BZ_MAX_UNUSED - strm.avail_out
            text = text .. ffi_string(buff_out, len)
        end
        if 0 == strm.avail_in then
            return text, false
        end
    end
end

function _M.finish(self)
    local strm = self.strm
    if not strm then
        return nil, nil, 'not initialized'
    end
    local ok = bzlib.BZ2_bzDecompressEnd(strm)
    return ret[ok]
end

return _M