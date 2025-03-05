using Test
using CBORCodecs
using DataStructures
using Dates
using Decimals
using TimeZones
using NanoDates
using Aqua
using JET
import CBORCodecs: Tag, decode, encode, UndefLength

# Helper functions
cbor_equal(a, b) = a == b
cbor_equal(a::Vector{String}, b::String) = join(a, "") == b
cbor_equal(a::Vector{Vector{UInt8}}, b::Vector{UInt8}) = vcat(a...) == b

# Type-specific tests
@testset "Integers (Type 0, 1)" begin
    @testset "Unsigned Integers (Type 0)" begin
        test_vectors = [
            0 => hex2bytes("00"),
            1 => hex2bytes("01"),
            10 => hex2bytes("0a"),
            23 => hex2bytes("17"),
            24 => hex2bytes("1818"),
            25 => hex2bytes("1819"),
            UInt8(100) => hex2bytes("1864"),
            UInt16(1000) => hex2bytes("1903e8"),
            UInt32(1000000) => hex2bytes("1a000f4240"),
            UInt64(1000000000000) => hex2bytes("1b000000e8d4a51000"),
            "dummy" => hex2bytes("6564756d6d79"), # To avoid implicit Float64 type conversion
        ]
        
        for (data, bytes) in test_vectors
            @test cbor_equal(data, decode(encode(data)))
            @test isequal(bytes, encode(data))
            @test cbor_equal(data, decode(bytes))
        end
    end

    @testset "Signed Integers (Type 1)" begin
        test_vectors = [
            -1 => hex2bytes("20"),
            -10 => hex2bytes("29"),
            Int8(-100) => hex2bytes("3863"),
            Int16(-1000) => hex2bytes("3903e7"),
        ]
        
        for (data, bytes) in test_vectors
            @test cbor_equal(data, decode(encode(data)))
            @test isequal(bytes, encode(data))
            @test cbor_equal(data, decode(bytes))
        end
    end
end

@testset "Floating Point Numbers (Type 7)" begin
    @testset "Two-way Tests" begin
        test_vectors = [
            0.f0 => hex2bytes("fa00000000"),
            -0.f0 => hex2bytes("fa80000000"),
            1.0f0 => hex2bytes("fa3f800000"),

            1.5f0 => hex2bytes("fa3fc00000"),
            1.1 => hex2bytes("fb3ff199999999999a"),
            65504f0 => hex2bytes("fa477fe000"),
            100000f0 => hex2bytes("fa47c35000"),
            Float32(3.4028234663852886e+38) => hex2bytes("fa7f7fffff"),
            1.0e+300 => hex2bytes("fb7e37e43c8800759c"),
            Float32(5.960464477539063e-8) => hex2bytes("fa33800000"),
            Float32(0.00006103515625) => hex2bytes("fa38800000"),
            -4f0 => hex2bytes("fac0800000"),
            -4.1 => hex2bytes("fbc010666666666666"),
            "dummy" => hex2bytes("6564756d6d79"), # To avoid implicit Float64 type conversion
        ]
        
        for (data, bytes) in test_vectors
            @test cbor_equal(data, decode(encode(data)))
            @test isequal(bytes, encode(data))
            @test cbor_equal(data, decode(bytes))
        end
    end
    
    @testset "One-way Tests" begin
        test_vectors = [
            hex2bytes("fa7fc00000") => NaN32,
            hex2bytes("fa7f800000") => Inf32,
            hex2bytes("faff800000") => -Inf32,
            hex2bytes("fb7ff8000000000000") => NaN,
            hex2bytes("fb7ff0000000000000") => Inf,
            hex2bytes("fbfff0000000000000") => -Inf,
        ]
        
        for (bytes, data) in test_vectors
            @test isequal(data, decode(bytes))
        end
    end
end

@testset "Simple Values (Type 7)" begin
    test_vectors = [
        false => hex2bytes("f4"),
        true => hex2bytes("f5"),
        nothing => hex2bytes("f6"),
        CBORCodecs.Undefined() => hex2bytes("f7"),
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
    end
end

@testset "Byte Strings (Type 2)" begin
    test_vectors = [
        UInt8[] => hex2bytes("40"), 
        hex2bytes("01020304") => hex2bytes("4401020304"),
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
    end
    
    @testset "Indefinite Length Byte Strings" begin
        @test decode(hex2bytes("5f44aabbccdd43eeff99FF")) == hex2bytes("aabbccddeeff99")
    end
end

@testset "Text Strings (Type 3)" begin
    test_vectors = [
        "" => hex2bytes("60"),
        "a" => hex2bytes("6161"),
        "IETF" => hex2bytes("6449455446"),
        "\"\\" => hex2bytes("62225c"),
        "\u00fc" => hex2bytes("62c3bc"),
        "\u6c34" => hex2bytes("63e6b0b4"),
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
    end
    
    @testset "Indefinite Length Text Strings" begin
        function producer(ch::Channel)
            for c in ["F", "ire", " ", "and", " ", "Blo", "od"]
                put!(ch, c)
            end
        end
        
        bytes = encode(UndefLength{String}(Channel(producer)))
        @test decode(bytes) == "Fire and Blood"
    end
end

@testset "Arrays (Type 4)" begin
    test_vectors = [
        [] => hex2bytes("80"),
        [1, 2, 3] => hex2bytes("83010203"),
        [1, [2, 3], [4, 5]] => hex2bytes("8301820203820405"),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25] =>
         hex2bytes("98190102030405060708090a0b0c0d0e0f101112131415161718181819"),
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
    end
    
    @testset "Indefinite Length Arrays" begin
        function producer(ch::Channel)
            for i in 1:10
                put!(ch,i*i)
            end
        end
        
        iter = Channel(producer)
        @test ((1:10) .* (1:10)) == decode(encode(UndefLength(iter)))
    end
end

@testset "Map (Type 5) to Dict" begin
    CBORCodecs.set_map_decoder(:Dict)
    test_vectors = [
        Dict() => hex2bytes("a0"),
    ]
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
        @test decode(bytes) isa Dict  # 厳密な型ではなくDictかどうかをチェック
    end
end

@testset "Map (Type 5) to OrderedDict" begin
    CBORCodecs.set_map_decoder(:OrderedDict)
    test_vectors = [
        OrderedDict(1=>2, 3=>4) => hex2bytes("a201020304"),
        OrderedDict("a"=>1, "b"=>[2, 3]) => hex2bytes("a26161016162820203"),
        OrderedDict("a"=>"A", "b"=>"B", "c"=>"C", "d"=>"D", "e"=>"E") => 
            hex2bytes("a56161614161626142616361436164614461656145"),
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
        @test decode(bytes) isa OrderedDict  # 厳密な型ではなくDictかどうかをチェック
    end
end
    
@testset "Indefinite Length Maps" begin
    function cubes(ch::Channel)
        for i in 1:10
            put!(ch, i)       # key
            put!(ch, i*i*i)   # value
        end
    end
        
    bytes = encode(UndefLength{Pair}(Channel(cubes)))
    @test Dict(zip(1:10, (1:10) .^ 3)) == decode(bytes)
end

@testset "Tagged Values (Type 6)" begin
    @testset "DateTime (Tag 0, 1)" begin
        test_vectors = [
            DateTime(2013, 3, 21, 20, 4, 0) => 
                hex2bytes("c074323031332d30332d32315432303a30343a30305a"),
        ]
        
        for (data, bytes) in test_vectors
            print(typeof(data))
            @test cbor_equal(data, decode(encode(data)))
            @test isequal(bytes, encode(data))
        end
        
        @testset "One-way Tests" begin
            # CBOR.set_datetime_type(:DateTime)  # Default is DateTime, so optional
            test_vectors_datetime = [
                hex2bytes("c11a514b67b0") => DateTime(2013, 3, 21, 20, 4, 0),
                hex2bytes("c1fb41d452d9ec200000") => DateTime(2013, 3, 21, 20, 4, 0, 500),
            ]
            
            for (bytes, data) in test_vectors_datetime
                @test isequal(data, decode(bytes))
            end
            
            # One-way tests for ZonedDateTime
            CBORCodecs.set_datetime_type(:ZonedDateTime)
            test_vectors_zdt = [
                hex2bytes("c11a514b67b0") => ZonedDateTime(DateTime(2013, 3, 21, 20, 4, 0), tz"UTC"),
                hex2bytes("c1fb41d452d9ec200000") => ZonedDateTime(DateTime(2013, 3, 21, 20, 4, 0, 500), tz"UTC"),
            ]
            
            for (bytes, data) in test_vectors_zdt
                @test isequal(data, decode(bytes))
            end
            
            # One-way tests for NanoDate
            CBORCodecs.set_datetime_type(:NanoDate)
            test_vectors_nano = [
                hex2bytes("c074323031332d30332d32315432303a30343a30305a") => 
                    NanoDate("2013-03-21T20:04:00Z"),
                hex2bytes("c0781e323031332d30332d32315432303a30343a30302e3132333435363738395a") => 
                    NanoDate("2013-03-21T20:04:00.123456789Z"),
            ]
            
            for (bytes, data) in test_vectors_nano
                @test isequal(data, decode(bytes))
            end
            
            # Reset to default after tests
            CBORCodecs.set_datetime_type(:DateTime)
        end
    end
    
    @testset "BigInt (Tag 2, 3)" begin
        test_vectors = [
            BigInt(18446744073709551616) => hex2bytes("c249010000000000000000"),
            BigInt(-18446744073709551617) => hex2bytes("c349010000000000000000")
        ]
        
        for (data, bytes) in test_vectors
            @test isequal(bytes, encode(data))
            @test isequal(data, decode(bytes))
        end
    end
    
    @testset "Decimal (Tag 4)" begin
        test_vectors = [
            parse(Decimal, "1.123456789012345678912345678") => 
                hex2bytes("c482c24c03a14d3a912972e51548d64e381a"),
        ]
        
        for (data, bytes) in test_vectors
            @test cbor_equal(data, decode(encode(data)))
            @test isequal(bytes, encode(data))
        end
    end

    @testset "Other Tags" begin
        test_vectors = [
            hex2bytes("d82076687474703a2f2f7777772e6578616d706c652e636f6d") => "http://www.example.com",
            hex2bytes("d8184c6b68656c6c6f20776f726c64") => "hello world",
        ]
        
        for (bytes, data) in test_vectors
            @test isequal(data, decode(bytes))
        end
    end
end

@testset "Complex Types" begin
    test_vectors = [
        ["a", Dict("b"=>"c")] => hex2bytes("826161a161626163")
    ]
    
    for (data, bytes) in test_vectors
        @test cbor_equal(data, decode(encode(data)))
        @test isequal(bytes, encode(data))
        @test cbor_equal(data, decode(bytes))
    end
    
    @testset "Indefinite Length Complex Types" begin
        test_vectors = [
            ["Hello", " ", "world"] =>
                hex2bytes("7f6548656c6c6f612065776f726c64ff"),
            Vector{UInt8}.(["Hello", " ", "world"]) =>
                hex2bytes("5f4548656c6c6f412045776f726c64ff"),
            [1, 2.3, "Twiddle"] =>
                hex2bytes("9f01fb40026666666666666754776964646c65ff"),
        ]
        
        for (data, bytes) in test_vectors
            @test isequal(bytes, encode(UndefLength(data)))
            @test cbor_equal(data, decode(bytes))
        end
    end
end

@testset "Aqua.jl" begin
    Aqua.test_all(
        CBORCodecs;
        # ambiguities=(exclude=[SomePackage.some_function], broken=true),
        # stale_deps=(ignore=[:Aqua],),
        deps_compat=(ignore=[:Base64, :Serialization, :JET],),
        piracies=false,
    )
end

report_package("CBORCodecs")