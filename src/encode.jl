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

cbor_tag(::UInt8) = ADDNTL_INFO_UINT8
cbor_tag(::UInt16) = ADDNTL_INFO_UINT16
cbor_tag(::UInt32) = ADDNTL_INFO_UINT32
cbor_tag(::UInt64) = ADDNTL_INFO_UINT64

cbor_tag(::Float64) = ADDNTL_INFO_FLOAT64
cbor_tag(::Float32) = ADDNTL_INFO_FLOAT32
cbor_tag(::Float16) = ADDNTL_INFO_FLOAT16

function encode_unsigned_with_type(io::IO, typ::UInt8, num::Unsigned)
    write(io, typ | cbor_tag(num))
    write(io, bswap(num))
end

function encode_length(io::IO, typ::UInt8, x::String)
    encode_smallest_int(io, typ, sizeof(x))
end

function encode_length(io::IO, typ::UInt8, x::Int)
    # encode length directly
    encode_smallest_int(io, typ, x)
end

function encode_length(io::IO, typ::UInt8, x)
    encode_smallest_int(io, typ, length(x))
end

"""
Array lengths and other integers (e.g. tags) in CBOR are encoded with smallest integer type,
which we do with this method!
"""
function encode_smallest_int(io::IO, typ::UInt8, num::Integer)
    @assert num >= 0 "array lengths must be greater 0. Found: $num"
    @assert num < UINT64_MAX_PLUS_ONE "array lengths must be smaller than 2^64. Found: $num"
    if num < SINGLE_BYTE_UINT_PLUS_ONE
        write(io, typ | UInt8(num)) # smaller 24 gets directly stored in type tag
    elseif num < UINT8_MAX_PLUS_ONE
        encode_unsigned_with_type(io, typ, UInt8(num))
    elseif num < UINT16_MAX_PLUS_ONE
        encode_unsigned_with_type(io, typ, UInt16(num))
    elseif num < UINT32_MAX_PLUS_ONE
        encode_unsigned_with_type(io, typ, UInt32(num))
    elseif num < UINT64_MAX_PLUS_ONE
        encode_unsigned_with_type(io, typ, UInt64(num))
    else
        error("128-bits ints can't be encoded in the CBOR format. found: $num")
    end
end


# ------- straightforward encoding for a few Julia types
"""
Encode a floating point value as a CBOR float (Type 7)
"""
function encode(io::IO, float::Union{Float64, Float32, Float16})
    write(io, TYPE_7 | cbor_tag(float))
    # hton only works for 32 + 64, while bswap works for all
    write(io, Base.bswap_int(float))
end

"""
Encode a boolean value as a CBOR boolean (Type 7)
"""
function encode(io::IO, bool::Bool)
    write(io, CBOR_FALSE_BYTE + bool)
end

"""
Encode a null value as a CBOR null (Type 7)
"""
function encode(io::IO, null::Nothing)
    write(io, CBOR_NULL_BYTE)
end

"""
Encode an undefined value as a CBOR undefined (Type 7)
"""
struct Undefined
end
function encode(io::IO, undef::Undefined)
    write(io, CBOR_UNDEF_BYTE)
end

"""
Encode an unsigned integer as a CBOR integer (Type 0)
"""
function encode(io::IO, num::Unsigned)
    encode_unsigned_with_type(io, TYPE_0, num)
end

"""
Encode a signed integer as a CBOR integer (Type 0 or 1)
"""
function encode(io::IO, num::T) where T <: Signed
    if num >= 0
        encode_smallest_int(io, TYPE_0, unsigned(num))
    else
        encode_smallest_int(io, TYPE_1, unsigned(-num - one(T)))
    end
end

"""
Encode a byte string as a CBOR byte string (Type 2)
"""
function encode(io::IO, byte_string::Vector{UInt8})
    encode_length(io, TYPE_2, byte_string)
    write(io, byte_string)
end

"""
Encode a text string as a CBOR text string (Type 3)
"""
function encode(io::IO, string::String)
    encode_length(io, TYPE_3, string)
    write(io, string)
end

"""
Encode an array as a CBOR array (Type 4)
"""
function encode(io::IO, arr::Union{Vector, Tuple})
    encode_length(io, TYPE_4, arr)
    foreach(x -> encode(io, x), arr)
end

"""
Encode a dictionary as a CBOR map (Type 5)
"""
function encode(io::IO, map::Union{Dict,OrderedDict})
    encode_length(io, TYPE_5, map)
    for (key, value) in map
        encode(io, key)
        encode(io, value)
    end
end

"""
Encode a pair as a CBOR  map (Type 5)
"""
function encode(io::IO, pair::Pair)
    encode_length(io, TYPE_5, 1) # length is always 1 for a pair
    encode(io, pair[1])
    encode(io, pair[2])
end

"""
Encode a Type 6 CBOR with tag
"""
function encode(io::IO, tag::Tag)
  tag.id >= 0 || error("Tag id needs to be a positive integer, found: $(tag.id)")
  encode_smallest_int(io, TYPE_6, tag.id)
  encode(io, tag.data)
end

"""
Encode a DateTime as a CBOR standard date string (Type 6 with tag 0)
"""
function encode(io::IO, dt::Union{DateTime, NanoDate})
  # Convert DateTime to ISO8601 format (RFC 3339) string and then encode
  encode(io, Tag(TAG_STANDARD_DATE_STRING, string(dt)*"Z"))
end

"""
Encode a DateTime as a CBOR standard date string (Type 6 with tag 0)
"""
function encode(io::IO, dt::ZonedDateTime)
  # Convert DateTime to ISO8601 format (RFC 3339) string and then encode
  encode(io, Tag(TAG_STANDARD_DATE_STRING, string(dt)))
end

hex(n::Integer) = string(n, base = 16)
"""
Encode a BigInt as a CBOR big integer (Type 6 with tag 2 or 3)
"""
function encode(io::IO, big_int::BigInt)
    if (typemin(Int64) <= big_int <= typemax(Int64))
        encode(io, Int(big_int))
        return 
    end 
    if 0 <= big_int < UINT64_MAX_PLUS_ONE
        encode(io, UInt64(big_int))
        return
    end
    tag = if big_int < 0
        big_int = -big_int - 1
        TAG_NEG_BIG_INT
    else
        TAG_POS_BIG_INT
    end
    hex_str = hex(big_int)
    if isodd(length(hex_str))
        hex_str = "0" * hex_str
    end
    encode(io, Tag(tag, hex2bytes(hex_str)))
end

"""
Encode a Decimal as a CBOR decimal fraction (Type 6 with tag 4)
"""
function encode(io::IO, dec::Decimal)
    M = begin
        if dec.s
            - dec.c
        else
            dec.c
        end
    end
    q = dec.q
    encode(io, Tag(TAG_DECIMAL_FRACTION, [M, q]))
end

"""
Encode a BigFloat as a CBOR big float (Type 6 with tag 5)
"""
function encode(io::IO, big_float::BigFloat)
    # 内部形式から正確な指数と仮数を取得
    p = precision(big_float)  # BigFloatの精度（ビット数）
    e_adj = Base.exponent(big_float)
    s = Base.significand(big_float)
    
    # 仮数を整数に変換（2^p倍して整数化）
    m_int = round(BigInt, s * 2.0^p)
    e_int = e_adj - p  # 精度分だけ指数を調整
    
    encode(io, Tag(TAG_BIG_FLOAT, (e_int, m_int)))
end



"""
Wrapper for collections with undefined length, that will then get encoded
in the cbor format. Underlying is just
"""
struct UndefLength{ET, A}
    iter::A
end

function UndefLength(iter::T) where T
    UndefLength{eltype(iter), T}(iter)
end

function UndefLength{T}(iter::A) where {T, A}
    UndefLength{T, A}(iter)
end

Base.iterate(x::UndefLength) = iterate(x.iter)
Base.iterate(x::UndefLength, state) = iterate(x.iter, state)

# ------- encoding for indefinite length collections
function encode(io::IO, iter::UndefLength{ET, A}) where {ET, A}
    typ = begin
        # 文字列や byte string の配列の場合は Type 4 (array) としてエンコード
        if (A <: AbstractVector || A <: Tuple) && (ET == String || ET == Vector{UInt8})
            TYPE_4 # array - 配列構造を保持
        elseif ET == Vector{UInt8}
            TYPE_2 # byte string
        elseif ET == String
            TYPE_3 # text string
        elseif ET <: Pair
            TYPE_5 # map
        else
            TYPE_4 # array
        end
    end
    write(io, typ | ADDNTL_INFO_INDEF)
    foreach(x-> encode(io, x), iter)
    write(io, BREAK_INDEF)
end


function fields2array(typ::T) where T
    fnames = fieldnames(T)
    getfield.((typ,), [fnames...])
end

"""
Any Julia type get's serialized as Tag 27
Tag             27
Data Item       array [typename, constructargs...]
Semantics       Serialised language-independent object with type name and constructor arguments
Reference       http://cbor.schmorp.de/generic-object
Contact         Marc A. Lehmann <cbor@schmorp.de>
"""
function encode(io::IO, struct_type::T) where T
    # TODO don't use Serialization for the whole struct!
    # It almost works to deserialize from just the fields and type,
    # but that ends up being problematic for
    # anonymous functions (the type changes between serialization & deserialization)
    tio = IOBuffer(); serialize(tio, struct_type)
    encode(
        io,
        Tag(
            CUSTOM_LANGUAGE_TYPE,
            [string("Julia/", T), take!(tio), fields2array(struct_type)]
        )
    )
end

"""
    encode(data)

Convert any Julia data structure into CBOR encoded byte array.

# Arguments
- `data`: Any Julia value or structure to be encoded in CBOR format.

# Returns
- `Vector{UInt8}`: A byte array containing the CBOR encoded data.

# Examples
```julia
# Encode simple values
bytes = encode(42)                  # Integer
bytes = encode("Hello, world!")     # String
bytes = encode([1, 2, 3])           # Array
bytes = encode(Dict("a" => 1))      # Dictionary

# Encode a custom struct
struct Person
    name::String
    age::Int
end
bytes = encode(Person("John", 30))
```

# Supported Types
- Basic types: Integers, Floats, Strings, Bool, Nothing
- Collections: Arrays, Tuples, Dictionaries, OrderedDictionaries, Pairs
- Date/Time: DateTime, ZonedDateTime, NanoDate
- Specialized numbers: BigInt, Decimal, BigFloat
- Tagged items: using the Tag constructor
- Custom Julia structs via serialization tag 27
"""
function encode(data)
  io = IOBuffer()
  encode(io, data)
  return take!(io)
end