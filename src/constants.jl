const TYPE_0 = UInt8(0) # An unsigned integer in the range 0..2^(64)-1 inclusive
const TYPE_1 = UInt8(1) << 5 # A negative integer in the range -2^(64)..-1 inclusive.
const TYPE_2 = UInt8(2) << 5 #  A byte string.
const TYPE_3 = UInt8(3) << 5 # A text string encoded as UTF-8.
const TYPE_4 = UInt8(4) << 5 # An array of data items.
const TYPE_5 = UInt8(5) << 5 # A map of pairs of data items
const TYPE_6 = UInt8(6) << 5  # A tagged data item 
const TYPE_7 = UInt8(7) << 5 # loating-point numbers and simple values, as well as the "break" stop code

const BITS_PER_BYTE = UInt8(8)
const HEX_BASE = Int(16)
const LOWEST_ORDER_BYTE_MASK = 0xFF

const TYPE_BITS_MASK = UInt8(0b1110_0000)
const ADDNTL_INFO_MASK = UInt8(0b0001_1111)

const ADDNTL_INFO_UINT8 = UInt8(24)
const ADDNTL_INFO_UINT16 = UInt8(25)
const ADDNTL_INFO_UINT32 = UInt8(26)
const ADDNTL_INFO_UINT64 = UInt8(27)

const SINGLE_BYTE_SIMPLE_PLUS_ONE = UInt8(24)
const SIMPLE_FALSE = UInt8(20)
const SIMPLE_TRUE = UInt8(21)
const SIMPLE_NULL = UInt8(22)
const SIMPLE_UNDEF = UInt8(23)

const ADDNTL_INFO_FLOAT16 = UInt8(25)
const ADDNTL_INFO_FLOAT32 = UInt8(26)
const ADDNTL_INFO_FLOAT64 = UInt8(27)

const ADDNTL_INFO_INDEF = UInt8(31)
const BREAK_INDEF = TYPE_7 | UInt8(31)

const SINGLE_BYTE_UINT_PLUS_ONE = 24
const UINT8_MAX_PLUS_ONE = 0x100
const UINT16_MAX_PLUS_ONE = 0x10000
const UINT32_MAX_PLUS_ONE = 0x100000000
const UINT64_MAX_PLUS_ONE = 0x10000000000000000

const INT8_MAX_POSITIVE = 0x7f
const INT16_MAX_POSITIVE = 0x7fff
const INT32_MAX_POSITIVE = 0x7fffffff
const INT64_MAX_POSITIVE = 0x7fffffffffffffff

const SIZE_OF_FLOAT64 = sizeof(Float64)
const SIZE_OF_FLOAT32 = sizeof(Float32)
const SIZE_OF_FLOAT16 = sizeof(Float16)

const TAG_STANDARD_DATE_STRING = UInt8(0)
const TAG_EPOCH_BASED_DATE_TIME = UInt8(1)
const TAG_POS_BIG_INT = UInt8(2)
const TAG_NEG_BIG_INT = UInt8(3)
const TAG_DECIMAL_FRACTION = UInt8(4)
const TAG_BIGFLOAT = UInt8(5)
const TAG_EXPECTED_BASE64URL = UInt8(21)
const TAG_EXPECTED_BASE64 = UInt8(22)
const TAG_EXPECTED_BASE16 = UInt8(23)
const TAG_ENCODED_CBOR_DATA_ITEM = UInt8(24)
const TAG_URI = UInt8(32)
const TAG_BASE64URL = UInt8(33)
const TAG_BASE64 = UInt8(34)
const TAG_MIME_MESSAGE = UInt8(36)
const TAG_SELF_DESCRIBED_CBOR = UInt16(55799)

const CBOR_FALSE_BYTE = UInt8(TYPE_7 | 20)
const CBOR_TRUE_BYTE = UInt8(TYPE_7 | 21)
const CBOR_NULL_BYTE = UInt8(TYPE_7 | 22)
const CBOR_UNDEF_BYTE = UInt8(TYPE_7 | 23)


const CUSTOM_LANGUAGE_TYPE = UInt8(27)

# Definition of map decoding method (enum-like)
"""
Constants to specify collection type for map decoding.
- `:Dict` - Uses standard `Dict` type (default)
- `:OrderedDict` - Uses `OrderedDict` type which preserves key order
"""
@enum MapDecoderType::UInt8 begin
    DICT = UInt8(1)
    ORDERED_DICT = UInt8(2)
end

const current_map_decoder = Ref(DICT)

function set_map_decoder(type::MapDecoderType)
    current_map_decoder[] = type
end
function set_map_decoder(symbol::Symbol)
    if symbol === :Dict
        set_map_decoder(DICT)
    elseif symbol === :OrderedDict
        set_map_decoder(ORDERED_DICT)
    else
        error(ArgumentError("Invalid map decoder type: $symbol. Use `:Dict` or `:OrderedDict`."))
    end
end

# DateTime or ZonedDateTime or NanoDates
@enum DateTimeType::UInt8 begin
    DATETIME = UInt8(1)
    ZONED_DATETIME = UInt8(2)
    NANO_DATE = UInt8(3)
end

const current_datetime_decoder = Ref(DATETIME)

function set_datetime_type(type::DateTimeType)
  current_datetime_decoder[] = type
end

"""
Set the datetime type for decoding.
- `:DateTime` - Decodes as `DateTime` type (default)
- `:ZonedDateTime` - Decodes as `ZonedDateTime` type
- `:NanoDate` - Decodes as `NanoDate` type
"""
function set_datetime_type(symbol::Symbol)
    if symbol === :DateTime
        set_datetime_type(DATETIME)
    elseif symbol === :ZonedDateTime
        set_datetime_type(ZONED_DATETIME)
    elseif symbol === :NanoDate
        set_datetime_type(NANO_DATE)
    else
        error(ArgumentError("Invalid datetime type: $symbol. Use `:DateTime`, `:ZonedDateTime`, or `:NanoDate`."))
    end
end
