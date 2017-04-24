import LasIO.FixedString

@testset "FixedString" begin
    @test read(IOBuffer("asdf\0\0\0\0"), FixedString{8})::FixedString{8} == "asdf"
    @test read(IOBuffer("asdf\0\0\0\0"), FixedString{4})::FixedString{4} == "asdf"
    @test read(IOBuffer("\0\0\0\0"), FixedString{4}) == ""

    buf = IOBuffer()
    write(buf, FixedString{6}("qwer"))
    @test String(take!(buf)) == "qwer\0\0"

    @test_throws ArgumentError FixedString{4}("asdfasdf")
    @test FixedString{4}("asdfasdf", truncate=true) == "asd"
    @test FixedString{4}("asdfasdf", truncate=true, nullterm=false) == "asdf"
end

