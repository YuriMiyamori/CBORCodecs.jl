#=
Copyright (c) 2025 Yuri Miyamori

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
=#

function type_from_fields(::Type{T}, fields) where T
    ccall(:jl_new_structv, Any, (Any, Ptr{Cvoid}, UInt32), T, fields, length(fields))
end

function peekbyte(io::IO)
    mark(io)
    byte = read(io, UInt8)
    reset(io)
    return byte
end

struct UndefIter{IO, F}
    f::F
    io::IO
end
Base.IteratorSize(::Type{<: UndefIter}) = Base.SizeUnknown()

function Base.iterate(x::UndefIter, state = nothing)
    peekbyte(x.io) == BREAK_INDEF && return nothing
    return x.f(x.io), nothing
end

function decode_ntimes(f, io::IO)
    first_byte = peekbyte(io)
    if (first_byte & ADDNTL_INFO_MASK) == ADDNTL_INFO_INDEF
        skip(io, 1) # skip first byte
        return UndefIter(f, io)
    else
        return (f(io) for i in 1:decode_unsigned(io))
    end
end

decode_type0(::Val{ADDNTL_INFO_UINT8}, io::IO) = bswap(read(io, UInt8)) |> Int
decode_type0(::Val{ADDNTL_INFO_UINT16}, io::IO) = bswap(read(io, UInt16)) |> Int
decode_type0(::Val{ADDNTL_INFO_UINT32}, io::IO) = bswap(read(io, UInt32)) |> Int
function decode_type0(::Val{ADDNTL_INFO_UINT64}, io::IO)::Union{Int, Int64}
    val = bswap(read(io, UInt64))
    if val > INT64_MAX_POSITIVE
        return val
    else
        return Int(val)
    end
end
decode_type0(addntl_info::UInt8, io::IO) = error("Unknown additional info for unsigned integer: $addntl_info")

# Decode unsigned integer with additional info in 0-23 range (single byte)
decode_type0_tag(::Val{ADDNTL_INFO_UINT8}, io::IO) = bswap(read(io, UInt8))
decode_type0_tag(::Val{ADDNTL_INFO_UINT16}, io::IO) = bswap(read(io, UInt16))
decode_type0_tag(::Val{ADDNTL_INFO_UINT32}, io::IO) = bswap(read(io, UInt32))
decode_type0_tag(::Val{ADDNTL_INFO_UINT64}, io::IO) = bswap(read(io, UInt64))

function decode_unsigned_tag(io::IO)
    # type is only Uint
    addntl_info = read(io, UInt8) & ADDNTL_INFO_MASK
    tag = begin
            if addntl_info < SINGLE_BYTE_UINT_PLUS_ONE 
                addntl_info
            else
                decode_type0_tag(Val(addntl_info), io)
            end
        end
    return tag
end

function decode_unsigned(io::IO)
    addntl_info = read(io, UInt8) & ADDNTL_INFO_MASK
    if addntl_info < SINGLE_BYTE_UINT_PLUS_ONE 
        return addntl_info |> Int
    end
    decode_type0(Val(addntl_info), io)
end

decode_internal(io::IO, ::Val{TYPE_0}) = decode_unsigned(io)

"""
Decode CBOR negative integer (Type 1)
"""
function decode_internal(io::IO, ::Val{TYPE_1})
    addntl_info = read(io, UInt8) & ADDNTL_INFO_MASK
    decode_type1(Val(addntl_info), io)
end

"""
Decode negative integer with additional info in 0-23 range (single byte)
"""
function decode_type1(::Val{T}, io::IO) where T
    if T < SINGLE_BYTE_UINT_PLUS_ONE
        return -Int(T + Int8(1))
    else
        error("Unknown additional info for negative integer: $T")
    end
end

"""
Decode negative integer with UInt8 payload (additional info = 24)
"""
function decode_type1(::Val{ADDNTL_INFO_UINT8}, io::IO)
    data = bswap(read(io, UInt8))
    return -Int(data + one(data))
end

"""
Decode negative integer with UInt16 payload (additional info = 25)
"""
function decode_type1(::Val{ADDNTL_INFO_UINT16}, io::IO)
    data = bswap(read(io, UInt16))
    return -Int(data + one(data))
end

"""
Decode negative integer with UInt32 payload (additional info = 26)
"""
function decode_type1(::Val{ADDNTL_INFO_UINT32}, io::IO)
    data = bswap(read(io, UInt32))
    return -Int(data + one(data))
end

"""
Decode negative integer with UInt64 payload (additional info = 27)
"""
function decode_type1(::Val{ADDNTL_INFO_UINT64}, io::IO)
    data = bswap(read(io, UInt64))
    if data > INT64_MAX_POSITIVE
        return -Int128(data + one(data))
    else
        return -Int(data + one(data))
    end
end

"""
Decode indefinite length array
"""
function decode_indefinite(io::IO, converter = identity)
    skip(io, 1)
    result = IOBuffer()
    while peekbyte(io) !== BREAK_INDEF
        write(result, decode_internal(io))
    end
    skip(io, 1) # BREAK_INDEF をスキップ
    return converter(take!(result))
end

"""
Decode Byte Array
"""
function decode_internal(io::IO, ::Val{TYPE_2})
    if (peekbyte(io) & ADDNTL_INFO_MASK) == ADDNTL_INFO_INDEF
        return decode_indefinite(io)
    else
        return read(io, decode_unsigned(io))
    end
end

"""
Decode String
"""
function decode_internal(io::IO, ::Val{TYPE_3})
    if (peekbyte(io) & ADDNTL_INFO_MASK) == ADDNTL_INFO_INDEF
        return decode_indefinite(io, String)
    else
        return String(read(io, decode_unsigned(io)))
    end
end

"""
Decode Vector of arbitrary elements
"""
function decode_internal(io::IO, ::Val{TYPE_4})
    return map(identity, decode_ntimes(decode_internal, io))
end

function decode_internal(io::IO, ::Val{TYPE_5}, ::Val{ORDERED_DICT})
    return OrderedDict(decode_ntimes(io) do io
        decode_internal(io) => decode_internal(io)
    end)
end

function decode_internal(io::IO, ::Val{TYPE_5}, ::Val{DICT})
    return Dict(decode_ntimes(io) do io
        decode_internal(io) => decode_internal(io)
    end)
end

"""
Decode Map to Dict or OrderedDict
"""
function decode_internal(io::IO, ::Val{TYPE_5})
    return decode_internal(io, Val(TYPE_5), Val(current_map_decoder[]))
end


"""
Decode Tagged type
"""
function decode_internal(io::IO, ::Val{TYPE_6})
    tag = decode_unsigned_tag(io)
    data = decode_internal(io)
    return decode_tag(Val(tag), data)
end


function normalize_datetime_string(datetime_str::String)
    # ミリ秒部分を抽出する正規表現パターン
    pattern = r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})\.(\d+)(.*)$"
    
    if occursin(pattern, datetime_str)
        m = match(pattern, datetime_str)
        date_part = m[1]
        ms_part = m[2]
        timezone_part = m[3]
        
        # ミリ秒部分を3桁に制限（3桁より多い場合のみ切り捨て）
        if length(ms_part) > 3
            ms_part = ms_part[1:3]
        end
        
        return date_part * "." * ms_part * timezone_part
    else
        # ミリ秒がない場合はそのまま返す
        return datetime_str
    end
end

"""
Decode CBOR tag 0 to DateTime
"""
function decode_tag(::Val{TAG_STANDARD_DATE_STRING}, ::Val{DATETIME}, data::String)
    return NanoDate(data) |> DateTime
end

function decode_tag(::Val{TAG_STANDARD_DATE_STRING}, ::Val{ZONED_DATETIME}, data::String)
    return ZonedDateTime(normalize_datetime_string(data))
end

function decode_tag(::Val{TAG_STANDARD_DATE_STRING}, ::Val{NANO_DATE}, data::String)
    return NanoDate(data)
end

function decode_tag(::Val{TAG_STANDARD_DATE_STRING}, data::String)
    return decode_tag(Val(TAG_STANDARD_DATE_STRING), Val(current_datetime_decoder[]), data)
end

"""
Decode CBOR tag 1 to DateTime
"""
function decode_tag(::Val{TAG_EPOCH_BASED_DATE_TIME}, ::Val{DATETIME}, data::Number)
    return unix2datetime(data) |> DateTime
end

function decode_tag(::Val{TAG_EPOCH_BASED_DATE_TIME}, ::Val{ZONED_DATETIME}, data::Number)
    return unix2datetime(data) |> x -> ZonedDateTime(x, tz"UTC")
end

function decode_tag(::Val{TAG_EPOCH_BASED_DATE_TIME}, ::Val{NANO_DATE}, data::Number)
    # fix this method only have millisecond precision
    return unix2datetime(data) |> NanoDate
end

function decode_tag(::Val{TAG_EPOCH_BASED_DATE_TIME}, data::Number)
    return decode_tag(Val(TAG_EPOCH_BASED_DATE_TIME), Val(current_datetime_decoder[]), data)
end


"""
Decode CBOR tag 2 to BigInt
"""
function decode_tag(::Val{TAG_POS_BIG_INT}, data::Vector{UInt8})
    return parse(BigInt, bytes2hex(data), base = HEX_BASE)
end

"""
Decode CBOR tag 3 to BigInt
"""
function decode_tag(::Val{TAG_NEG_BIG_INT}, data::Vector{UInt8})
    big_int =  parse(BigInt, bytes2hex(data), base = HEX_BASE)
    return -(big_int + 1)
end

"""
Decode CBOR tag 4 to Decimal
"""
function decode_tag(::Val{TAG_DECIMAL_FRACTION}, data::Vector{T}) where T <:Signed
    M, q = data
    s = signbit(M)
    return Decimal(s, abs(M), q)
end

"""
Decode CBOR tag 24 (Encoded CBOR Data Item)
"""
function decode_tag(::Val{TAG_ENCODED_CBOR_DATA_ITEM}, data::Vector{UInt8})
    # バイト文字列をIOBufferに変換
    io = IOBuffer(data)
    # 埋め込まれたCBORデータをデコード
    return decode_internal(io)
end

"""
Decode CBOR tag 27 to julia struct
"""
function decode_tag(::Val{CUSTOM_LANGUAGE_TYPE}, data::Vector)
    name = data[1]
    object_serialized = data[2]
    if startswith(name, "Julia/") # Julia Type
        return deserialize(IOBuffer(object_serialized))
    else
        return Tag(name, object_serialized)
    end
end
"""
Decode CBOR tag 32 to String(URI)
"""
decode_tag(::Val{TAG_URI}, data::String) = string(data)

"""
Decode CBOR tag not defined to Tag
"""
function decode_tag(::Val{N}, data::Any) where N
    println("decode Unknown tag")
    @debug "Encountered undefined CBOR tag: $N"
    return Tag(convert(Int, N), data)
end

"""
Decode CBOR type 7 float16
"""
decode_type7(::Val{ADDNTL_INFO_FLOAT16}, io::IO) = reinterpret(Float16, ntoh(read(io, UInt16)))

"""
Decode CBOR type 7 float32
"""
decode_type7(::Val{ADDNTL_INFO_FLOAT32}, io::IO) = reinterpret(Float32, ntoh(read(io, UInt32)))

"""
Decode CBOR type 7 float64
"""
decode_type7(::Val{ADDNTL_INFO_FLOAT64}, io::IO) = reinterpret(Float64, ntoh(read(io, UInt64)))

decode_type7(::Val{SIMPLE_FALSE}, io::IO) = false
decode_type7(::Val{SIMPLE_TRUE}, io::IO) = true
decode_type7(::Val{SIMPLE_NULL}, io::IO) = nothing
decode_type7(::Val{SIMPLE_UNDEF}, io::IO) = Undefined()


function decode_internal(io::IO, ::Val{TYPE_7})
    first_byte = read(io, UInt8)
    addntl_info = first_byte & ADDNTL_INFO_MASK
    if addntl_info == SINGLE_BYTE_SIMPLE_PLUS_ONE # Simple value (value 32..255 in following byte) 
        addntl_info = read(io, UInt8)
    end
    return decode_type7(Val(addntl_info), io)
end

function decode_internal(io::IO)
    # leave startbyte in io
    first_byte = peekbyte(io)
    typ = first_byte & TYPE_BITS_MASK
    return decode_internal(io, Val(typ))
end

"""
    decode(data)

Convert CBOR encoded data back into Julia data structures.

# Arguments
- `data`: Either a byte array (`Vector{UInt8}`) containing CBOR encoded data, 
  or an `IO` object from which to read the CBOR data.

# Returns
- The decoded Julia data structure, with appropriate type based on the CBOR content.

# Examples
```julia
# Decode from byte array
bytes = hex2bytes("83010203")  # CBOR encoding for [1, 2, 3]
array = decode(bytes)  # Returns [1, 2, 3]

# Decode from file
open("data.cbor", "r") do io
    data = decode(io)
    # work with decoded data
end
```
# Supported Types
The decode function can convert CBOR data to the following Julia types:

- Basic types: Integers, Floats, Strings, Bool, Nothing
- Collections: Arrays, Dictionaries, OrderedDictionaries
- Date/Time: DateTime, ZonedDateTime, or NanoDate (configurable via set_datetime_type)
- Specialized numbers: BigInt, Decimal, BigFloat
- Tagged items: Using the Tag constructor
- Custom Julia structs (when encoded with tag 27)
- Configuration Options
    - Use set_map_decoder(:Dict) or set_map_decoder(:OrderedDict) to control how maps are decoded
    - Use set_datetime_type(:DateTime), set_datetime_type(:ZonedDateTime), or set_datetime_type(:NanoDate) to control date/time decoding 
"""
function decode(data::Vector{UInt8})
    return decode_internal(IOBuffer(data))
end

function decode(data::IO)
    return decode(read(data))
end