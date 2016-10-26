local ffi = require 'ffi'
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
int BZ2_bzCompressInit (bz_stream* strm, int blockSize100k, int verbosity, int workFactor);
int BZ2_bzCompress (bz_stream* strm, int action);
int BZ2_bzCompressEnd (bz_stream* strm);
]]
local bzlib = ffi.load('bz2')
local action = {
    run    = 0,
    flush  = 1,
    finish = 2,
}
local ret = {
     [0] = 'ok',
     [1] = 'run_ok',
     [2] = 'flush_ok',
     [3] = 'finish_ok',
     [4] = 'stream_end',
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
local blockSize100k = 9
local workFactor = 30

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 32)

local mt = { __index = _M }

function _M.new(self, compresslevel, workfactor)
    local level = tonumber(compresslevel) or blockSize100k
    if 1 > level or 9 < level then
        return nil, 'compresslevel must between 1 and 9'
    end
    local factor = tonumber(workfactor) or workFactor
    if 1 > factor or 250 < factor then
        return nil, 'workfactor must between 1 and 250'
    end
    local strm = ffi.new('bz_stream')
    local buff_out = ffi.new('char[?]', BZ_MAX_UNUSED)
    local ok = bzlib.BZ2_bzCompressInit(strm, level, 0, factor)
    if 'ok' == ret[ok] then
        return setmetatable({
            strm = strm,
            buff_out = buff_out,
        }, mt)
    else
        return nil, ret[ok]
    end
end

function _M.apply(self, text)
    local strm = self.strm
    if not strm then
        return nil, 'not initialized'
    end
    if not text or 'string' ~= type(text) or 1 > #text then
        return nil, 'there must be at least 1 byte text'
    end
    local buff_out = self.buff_out
    local buff_in = ffi.new('char[?]', #text, text)
    strm.next_in = buff_in
    strm.avail_in = #text
    local bin = ''
    while true do
        strm.avail_out = BZ_MAX_UNUSED
        strm.next_out = buff_out
        local ok = bzlib.BZ2_bzCompress(strm, action.run)
        if 'run_ok' ~= ret[ok] then
            return nil, ret[ok]
        end
        if strm.avail_out < BZ_MAX_UNUSED then
            local len = BZ_MAX_UNUSED - strm.avail_out
            bin = bin .. ffi.string(buff_out, len)
        end
        if 0 == strm.avail_in then
            return bin
        end
    end
end

function _M.finish(self)
    local strm = self.strm
    if not strm then
        return nil, 'not initialized'
    end
    local buff_out = self.buff_out
    local bin = ''
    while true do
        strm.avail_out = BZ_MAX_UNUSED
        strm.next_out = buff_out
        local ok = bzlib.BZ2_bzCompress(strm, action.finish)
        if 'finish_ok' ~= ret[ok] and 'stream_end' ~= ret[ok] then
            return nil, ret[ok]
        end
        if strm.avail_out < BZ_MAX_UNUSED then
            local len = BZ_MAX_UNUSED - strm.avail_out
            bin = bin .. ffi.string(buff_out, len)
        end
        if 'stream_end' == ret[ok] then
            break
        end
    end
    local ok = bzlib.BZ2_bzCompressEnd(strm)
    if 'ok' ~= ret[ok] then
        return nil, ret[ok]
    end
    return bin
end

return _M