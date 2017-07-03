# dnabin.jl
# =========
#
# A nucleic acid type compatible with R's APE package.
#
# This file is a part of the BioJulia ecosystem.
# License is MIT: https://github.com/BioJulia/BioBridgeR.jl/blob/master/LICENSE.md

primitive type DNAbin <: NucleicAcid 8 end

const char_to_dnabin = [0x02 for _ in 0x00:0xff]
const dnabin_to_char = ['?' for _ in 0x01:0xed]

# derived from "The DDBJ/ENA/GenBank Feature Table Definition"
# §7.4.1 Nucleotide base code (IUPAC)
# http://www.insdc.org/documents/feature_table.html#7.4.1

for (char, doc, bits) in [
        ('-', "DNAbin Gap",                                   0x04),
        ('A', "DNAbin Adenine",                               0x88),
        ('C', "DNAbin Cytosine",                              0x28),
        ('G', "DNAbin Guanine",                               0x48),
        ('T', "DNAbin Thymine",                               0x18),
        ('M', "DNAbin Adenine or Cytosine",                   0xA0),
        ('R', "DNAbin Adenine or Guanine",                    0xC0),
        ('W', "DNAbin Adenine or Thymine",                    0x90),
        ('S', "DNAbin Cytosine or Guanine",                   0x60),
        ('Y', "DNAbin Cytosine or Thymine",                   0x30),
        ('K', "DNAbin Guanine or Thymine",                    0x50),
        ('V', "DNAbin Adenine, Cytosine or Guanine",          0xE0),
        ('H', "DNAbin Adenine, Cytosine or Thymine",          0xB0),
        ('D', "DNAbin Adenine, Guanine or Thymine",           0xD0),
        ('B', "DNAbin Cytosine, Guanine or Thymine",          0x70),
        ('N', "DNAbin Adenine, Cytosine, Guanine or Thymine", 0xF0)]
    var = Symbol("DNAbin_", char != '-' ? char : "Gap")
    @eval begin
        @doc $(doc) const $(var) = reinterpret(DNAbin, $(bits))
        char_to_dnabin[$(Int(char) + 1)] = char_to_dnabin[$(Int(lowercase(char)) + 1)] = $(bits)
        dnabin_to_char[$(Int(bits) - 3)] = $(char)
    end
end


# Conversion
# ----------

# Conversion between DNAbin and DNA.

@inline function _DNA_to_raw(nt::DNA)
    bits = UInt8(nt)
    db = swapbits(bits, 0, 3) << 4
    db |= ifelse(iscertain(nt), 0x08, 0x00)
    db |= ifelse(isgap(nt), 0x04, 0x00)
    return db
end

@inline function Base.convert(::Type{DNAbin}, nt::DNA)
    return DNAbin(_DNA_to_raw(nt))
end

@inline function _raw_to_DNA(x::UInt8)
    return swapbits(x, 4, 7) >> 4
end

@inline function Base.convert(::Type{BioSymbols.DNA}, nt::DNAbin)
    return BioSymbols.DNA(_raw_to_DNA(UInt8(nt)))
end

# Conversion between DNAbin and characters.

@inline function Base.convert(::Type{DNAbin}, c::Char)
    if c > '\xff'
        throw(InexactError())
    end
    @inbounds nt = char_to_dnabin[Int(c) + 1]
    if (nt & 0x02) > 0
        throw(InexactError())
    end
    return DNAbin(nt)
end

@inline function Base.convert(::Type{Char}, nt::DNAbin)
    @inbounds return dnabin_to_char[Int(nt) - 3]
end

# Alphabet
# --------

@eval @inline function BioSymbols.alphabet(::Type{DNAbin})
    return $(tuple([DNAbin(BioSymbols.DNA(x)) for x in 0b0000:0b1111]...))
end

# Show / print
# ------------

BioSymbols.prefix(::Type{DNAbin}) = "DNAbin"


# Basic operators
# ---------------

function Base.:~(x::DNAbin)
    return reinterpret(DNAbin, ~reinterpret(UInt8, x))
end

function Base.:+(x::DNAbin, y::Integer)
    return reinterpret(DNAbin, (UInt8(x) + y % UInt8))
end

@inline function BioSymbols.gap(::Type{DNAbin})
    return reinterpret(DNAbin,0x04)
end

@inline function BioSymbols.isGC(nt::DNAbin)
    return Bool((nt & 0x28) | (nt & 0x48))
end

@inline function BioSymbols.ispurine(nt::DNAbin)
    return (UInt8(nt) & 0xC8) > 0xC0
end

@inline function BioSymbols.ispyrimidine(nt::DNAbin)
    return (UInt8(nt) & 0x08) > 0x30
end

@inline function BioSymbols.isambiguous(nt::DNAbin)
    return (nt & 0x0C) == 0x00
end

@inline function BioSymbols.iscertain(nt::DNAbin)
    return (nt & 0x08) == 0x08
end

@inline function BioSymbols.isgap(nt::DNAbin)
    return nt == 0x04
end

@inline function BioSymbols.iscompatible(x::DNAbin, y::DNAbin)
    return (UInt8(x) >> 4) & (UInt8(y) >> 4) != 0
end

@inline function BioSymbols.complement(x::DNAbin)
    bits = UInt8(x)
    return DNAbin((bits & 0x10) << 3 | (bits & 0x80) >> 3 |
        (bits & 0x20) << 1 | (bits & 0x40) >> 1)
end
