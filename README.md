# CBORCodecs.jl

[![Build Status](https://github.com/JuliaData/CBOR.jl/workflows/CI/badge.svg)](https://github.com/JuliaData/CBOR.jl/actions/workflows/CI.yml)
[![Coverage Status](https://codecov.io/gh/JuliaData/CBOR.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/JuliaData/CBOR.jl)
[![](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/JuliaData/CBOR.jl/blob/master/LICENSE.md)
[![Aqua QA](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)


**CBORCodecs.jl** is a high-performance Julia package for the **CBOR** data format - a binary alternative to JSON that's smaller, faster, and more feature-rich. This package provides an intuitive API for seamless conversion between Julia types and CBOR.

## About CBOR

The **Concise Binary Object Representation (CBOR)** is designed to be:

- **Compact**: 20-80% smaller than equivalent JSON
- **Fast**: Binary format enables efficient parsing
- **Self-describing**: Data includes type information
- **Feature-rich**: Native support for binary data, timestamps, and more
- **Standardized**: Defined in [RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)

CBOR is ideal for IoT applications, WebAuthn, database storage, and anywhere that requires efficient data interchange.

## Installation

```julia
using Pkg
Pkg.add("CBORCodecs")
```

and add the module

```julia
using CBORCodecs
```

### Encoding and Decoding

Encoding and decoding follow the simple pattern

```julia
bytes = encode(data)

data = decode(bytes)
```
## Supported Types

CBORCodecs.jl supports a variety of Julia types for seamless encoding and decoding:

CBOR Major Types
### CBOR Major Types

| CBOR Type | First 3 bits | Description | Julia Representation |
|-----------|--------------|-------------|----------------------|
| Type 0 | 000 | Unsigned integer (0 to 2^64-1) | UInt8 to UInt64 |
| Type 1 | 001 | Negative integer (-2^64 to -1) | Int8 to Int64 |
| Type 2 | 010 | Byte string | Vector{UInt8} |
| Type 3 | 011 | Text string (UTF-8 encoded) | String |
| Type 4 | 100 | Array | Vector, Tuple |
| Type 5 | 101 | Map (key-value pairs) | Dict, OrderedDict |
| Type 6 | 110 | Tagged data item | Tag{T} |
| Type 7 | 111 | Floating-point or special values | Float16/32/64, Bool, Nothing |

### CBOR Tags (Used with Type 6)

| Tag Number | Description | Julia Representation | Example |
|------------|-------------|----------------------|---------|
| 0 | Standard date/time string (RFC 3339) | DateTime, ZonedDateTime | encode(DateTime(2023,1,1)) |
| 1 | UNIX timestamp (number) | DateTime | Epoch time in seconds or milliseconds |
| 2 | Positive BigInt | BigInt (positive) | encode(BigInt(10)^100) |
| 3 | Negative BigInt | BigInt (negative) | encode(-BigInt(10)^100) |
| 4 | Decimal fraction | Decimal | Decimal numbers |
| 5 | BigFloat | BigFloat | High-precision floating point |
| 24 | Encoded CBOR data item | Nested CBOR within byte string | CBOR-in-CBOR |
| 27 | Language-specific serialization | Julia custom types | `struct Point`, etc. |
| 32 | URI | String (URI format) | "https://example.com" |

### Type 7 Special Values

| Value | Description | Julia Representation |
|-------|-------------|----------------------|
| 20 | False | false |
| 21 | True | true |
| 22 | Null | nothing |
| 23 | Undefined | Undefined() |
| 24 | Simple value (8-bit) | - |
| 25 | IEEE 754 Half-precision (16-bit) | Float16 |
| 26 | IEEE 754 Single-precision (32-bit) | Float32 |
| 27 | IEEE 754 Double-precision (64-bit) | Float64 |
| 31 | Break stop code (for indefinite items) | - |

where `bytes` is of type `Array{UInt8, 1}`, and `data` returned from `decode()`
is *usually* of the same type that was passed into `encode()` but always
contains the original data.

#### Primitive Integers

All `Signed` and `Unsigned` types, *except* `Int128` and `UInt128`, are encoded
as CBOR `Type 0` or `Type 1`

```julia
julia> encode(21)
1-element Vector{UInt8}: 0x15

julia> encode(-135713)
5-element Vector{UInt8}: 0x3a 0x00 0x02 0x12 0x20

julia> bytes = encode(typemax(UInt32))
9-element Vector{UInt8}: 0x1a 0xff 0xff 0xff 0xff 

julia> decode(bytes)
4294967295
```

### Date and Time Types
CBORCodecs.jl supports date/time formats with RFC 3339 strings (tag 0) or UNIX timestamps (tag 1):

```julia
# Encode a DateTime (automatically tagged as standard date string)
bytes = encode(DateTime(2023, 10, 15, 12, 30, 45))
# Encode a ZonedDateTime
bytes = encode(ZonedDateTime(DateTime(2023, 10, 15, 12, 30, 45), tz"UTC"))
# Encode a NanoDate with nanosecond precision
bytes = encode(NanoDate("2023-10-15T12:30:45.123456789"))

# Configure datetime decoding format
CBOR.set_datetime_type(:DateTime)       # Default
CBOR.set_datetime_type(:ZonedDateTime)  # For timezone-aware dates
CBOR.set_datetime_type(:NanoDate)       # For nanosecond precision
```

### Map Decoding Options
Control how CBOR maps are decoded:

```julia
# Standard Dict (unordered)
CBOR.set_map_decoder(:Dict)  # Default

# OrderedDict (preserves key order)
CBOR.set_map_decoder(:OrderedDict)
```

#### Byte Strings

An `AbstractVector{UInt8}` is encoded as CBOR `Type 2`

```julia
> encode(UInt8[x*x for x in 1:10])
11-element Array{UInt8, 1}: 0x4a 0x01 0x04 0x09 0x10 0x19 0x24 0x31 0x40 0x51 0x64
```

#### Strings

`String` are encoded as CBOR `Type 3`

```julia
> encode("Valar morghulis")
16-element Array{UInt8,1}: 0x4f 0x56 0x61 0x6c 0x61 ... 0x68 0x75 0x6c 0x69 0x73

> bytes = encode("案ずるより産むが易し")
32-element Array{UInt8,1}: 0x78 0x75 0xd7 0x90 0xd7 ... 0x99 0xd7 0xaa 0xd7 0x99

> decode(bytes)
"案ずるより産むが易し"
```

#### Floats

`Float64`, `Float32` and `Float16` are encoded as CBOR `Type 7`

```julia
> encode(1.23456789e-300)
9-element Array{UInt8, 1}: 0xfb 0x01 0xaa 0x74 0xfe 0x1c 0x13 0x2c 0x0e

> bytes = encode(Float32(pi))
5-element Array{UInt8, 1}: 0xfa 0x40 0x49 0x0f 0xdb

> decode(bytes)
3.1415927f0
```

#### Arrays

`AbstractVector` and `Tuple` types, except of course `AbstractVector{UInt8}`,
are encoded as CBOR `Type 4`

```julia
> bytes = encode((-7, -8, -9))
4-element Array{UInt8, 1}: 0x83 0x26 0x27 0x28

> decode(bytes)
3-element Array{Any, 1}: -7 -8 -9

> bytes = encode(["Open", 1, 4, 9.0, "the pod bay doors hal"])
39-element Array{UInt8, 1}: 0x85 0x44 0x4f 0x70 0x65 ... 0x73 0x20 0x68 0x61 0x6c

> decode(bytes)
5-element Array{Any, 1}: "Open" 1 4 9.0 "the pod bay doors hal"

> bytes = encode([log2(x) for x in 1:10])
91-element Array{UInt8, 1}: 0x8a 0xfb 0x00 0x00 0x00 ... 0x4f 0x09 0x79 0xa3 0x71

> decode(bytes)
10-element Array{Any, 1}: 0.0 1.0 1.58496 2.0 2.32193 2.58496 2.80735 3.0 3.16993 3.32193
```

#### Maps

An `AbstractDict` type is encoded as CBOR `Type 5`

```julia
> d = Dict()
> d["GNU's"] = "not UNIX"
> d[Float64(e)] = [2, "+", 0.718281828459045]

> bytes = encode(d)
38-element Array{UInt8, 1}: 0xa2 0x65 0x47 0x4e 0x55 ... 0x28 0x6f 0x8a 0xd2 0x56

> decode(bytes)
Dict{Any,Any} with 2 entries:
  "GNU's"           => "not UNIX"
  2.718281828459045 => Any[0x02, "+", 0.718281828459045]
```

#### Tagging

To *tag* one of the above types, encode a `Tag` with `first` being an
**non-negative** integer, and `second` being the data you want to tag.

```julia
> bytes = encode(Tag(80, "web servers"))

> data = decode(bytes)
CBORCodecs.Tag{String}(80, "web servers")
```

There exists an [IANA registery](http://www.iana.org/assignments/cbor-tags/cbor-tags.xhtml)
which assigns certain meanings to tags; for example, a string tagged
with a value of `32` is to be interpreted as a
[Uniform Resource Locater](https://tools.ietf.org/html/rfc3986). To decode a
tagged CBOR data item, and then to automatically interpret the meaning of the
tag, use `decode_with_iana`.

For example, a Julia `BigInt` type is encoded as an `Array{UInt8, 1}` containing
the bytes of it's hexadecimal representation, and tagged with a value of `2` or
`3`

```julia
> b = BigInt(factorial(20))
2432902008176640000

> bytes = encode(b * b * -b)
34-element Vector{UInt8}: 0xc3 0x58 0x1f 0x13 0xd4 ... 0xff 0xff 0xff 0xff

> decode(bytes)  # Raw tag without interpretation
Tag(3, [0x13, 0xd4, 0x96, 0x58, ...])
```

To decode `bytes` *without* interpreting the meaning of the tag, use `decode`

```julia
> decode(bytes)
0x03 => UInt8[0x96, 0x58, 0xd1, 0x85, 0xdb .. 0xff 0xff 0xff 0xff 0xff]
```
To decode `bytes` and to interpret the meaning of the tag, use
`decode_with_iana`

```julia
> decode_with_iana(bytes)
-14400376622525549608547603031202889616850944000000000000
```

Currently, only `BigInt` is supported for automatically tagged encoding and
decoding; more Julia types will be added in the future.

#### Composite Types

A generic `DataType` that isn't one of the above types is encoded through
`encode` using reflection. This is supported only if all of the fields of the
type belong to one of the above types.

For example, say you have a user-defined type `Point`

```julia
mutable struct Point
    x::Int64
    y::Float64
    space::String
end

point = Point(1, 3.4, "Euclidean")
```

When `point` is passed into `encode`, it is first converted to a `Dict`
containing the symbolic names of it's fields as keys associated to their
respective values and a `"type"` key associated to the type's
symbolic name, like so

```julia
Dict{Any, Any} with 3 entries:
  "x"     => 0x01
  "type"  => "Point"
  "y"     => 3.4
  "space" => "Euclidean"
```

The `Dict` is then encoded as CBOR `Type 5`.

#### Indefinite length collections

To encode collections of *indefinite* length, you can just wrap any iterator
in the `CBOR.UndefLength` type. Make sure that your Iterator knows their eltype
to e.g. create a bytestring / string / Dict *indefinite* length encoding.
The eltype mapping is:

```julia
Vector{UInt8} -> bytestring
String -> bytestring
Pair -> Dict
Any -> List
```
If the eltype is unknown, but you still want to enforce it, use this constructor:
```Julia
CBOR.UndefLength{String}(iter)
```
First create some julia iterator with unknown length
```julia
function producer(ch::Channel)
    for i in 1:10
        put!(ch,i*i)
    end
end
iter = Channel(producer)
```

encode it with UndefLength
```julia
> encode(UndefLength(iter))
18-element Array{UInt8, 1}: 0x9f 0x01 0x04 0x09 0x10 ... 0x18 0x51 0x18 0x64 0xff

> decode(bytes)
[1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
```

While encoding an indefinite length `Map`, produce first the key and then the
value for each key-value pair, or produce pairs!

```julia
function cubes(ch::Channel)
    for i in 1:10
        put!(ch, i)       # key
        put!(ch, i*i*i)   # value
    end
end

> bytes = encode(UndefLength{Pair}(Channel(cubes)))
34-element Array{UInt8, 1}: 0xbf 0x01 0x01 0x02 0x08 ... 0x0a 0x19 0x03 0xe8 0xff

> decode(bytes)
Dict(7=>343,4=>64,9=>729,10=>1000,2=>8,3=>27,5=>125,8=>512,6=>216,1=>1)
```

Note that when an indefinite length CBOR `Type 2` or `Type 3` is decoded,
the result is a *concatenation* of the individual elements.

```julia
function producer(ch::Channel)
    for c in ["F", "ire", " ", "and", " ", "Blo", "od"]
        put!(ch,c)
    end
end

> bytes = encode(UndefLength{String}(Channel(producer)))
23-element Array{UInt8, 1}: 0x7f 0x61 0x46 0x63 0x69 ... 0x6f 0x62 0x6f 0x64 0xff

> decode(bytes)
"Fire and Blood"
```

### Caveats


Encoding a `UInt128` and an `Int128` isn't supported; use a `BigInt` instead.

Decoding CBOR data that isn't well-formed is unpredictable.