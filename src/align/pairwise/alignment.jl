# Pairwise Alignment
# ------------------

"""
Pairwise alignment
"""
type PairwiseAlignment{S1,S2}
    a::AlignedSequence{S1}
    b::S2
end

Base.start(aln::PairwiseAlignment) = (2, 1)
Base.done(aln::PairwiseAlignment, ij) = ij[1] > endof(aln.a.aln.anchors)
function Base.next(aln::PairwiseAlignment, ij)
    i, j = ij
    anchors = aln.a.aln.anchors
    anchor = anchors[i]
    seq = aln.a.seq
    ref = aln.b
    seqpos = anchors[i-1].seqpos
    refpos = anchors[i-1].refpos

    if ismatchop(anchor.op)
        x = seq[seqpos + j]
        y = ref[refpos + j]
    elseif isinsertop(anchor.op)
        x = seq[seqpos + j]
        y = gap(eltype(ref))
    elseif isdeleteop(anchor.op)
        x = gap(eltype(seq))
        y = ref[refpos + j]
    else
        @assert false
    end

    if ismatchop(anchor.op) || isinsertop(anchor.op)
        if j < anchor.seqpos - seqpos
            j += 1
        else
            i += 1
            j = 1
        end
    else
        if j < anchor.refpos - refpos
            j += 1
        else
            i += 1
            j = 1
        end
    end

    return (x, y), (i, j)
end

Base.length(aln::PairwiseAlignment) = count_aligned(aln)
Base.eltype{S1,S2}(::Type{PairwiseAlignment{S1,S2}}) = Tuple{eltype(S1),eltype(S2)}

"""
    count(aln::PairwiseAlignment, target::Operation)

Count the number of positions where the `target` operation is applied.
"""
function Base.count(aln::PairwiseAlignment, target::Operation)
    anchors = aln.a.aln.anchors
    n = 0
    for i in 2:endof(anchors)
        op = anchors[i].op
        if op == target
            if ismatchop(op) || isinsertop(op)
                n += anchors[i].seqpos - anchors[i-1].seqpos
            elseif isdeleteop(op)
                n += anchors[i].refpos - anchors[i-1].refpos
            end
        end
    end
    return n
end

"""
Count the number of matching positions.
"""
function count_matches(aln::PairwiseAlignment)
    return count(aln, OP_SEQ_MATCH)
end

"""
Count the number of mismatching positions.
"""
function count_mismatches(aln::PairwiseAlignment)
    return count(aln, OP_SEQ_MISMATCH)
end

"""
Count the number of inserting positions.
"""
function count_insertions(aln::PairwiseAlignment)
    return count(aln, OP_INSERT)
end

"""
Count the number of deleting positions.
"""
function count_deletions(aln::PairwiseAlignment)
    return count(aln, OP_DELETE)
end

"""
Count the number of aligned positions.
"""
function count_aligned(aln::PairwiseAlignment)
    anchors = aln.a.aln.anchors
    n = 0
    for i in 2:endof(anchors)
        op = anchors[i].op
        if ismatchop(op) || isinsertop(op)
            n += anchors[i].seqpos - anchors[i-1].seqpos
        elseif isdeleteop(op)
            n += anchors[i].refpos - anchors[i-1].refpos
        end
    end
    return n
end

function Base.show{S1,S2}(io::IO, aln::PairwiseAlignment{S1,S2})
    println(io, "PairwiseAlignment{", S1, ",", S2, "}:")
    print(io, aln)
end

function Base.print(io::IO, aln::PairwiseAlignment, width::Integer=60)
    seq = aln.a.seq
    ref = aln.b
    anchors = aln.a.aln.anchors
    # width of position numbers
    posw = ndigits(max(anchors[end].seqpos, anchors[end].refpos)) + 1

    i = 0
    seqpos = anchors[1].seqpos
    refpos = anchors[1].refpos
    seqbuf = IOBuffer()
    refbuf = IOBuffer()
    matbuf = IOBuffer()
    s = start(aln)
    while !done(aln, s)
        (x, y), s = next(aln, s)

        i += 1
        if x != gap(eltype(seq))
            seqpos += 1
        end
        if y != gap(eltype(ref))
            refpos += 1
        end

        if i % width == 1
            print(seqbuf, "  seq:", lpad(seqpos, posw), ' ')
            print(refbuf, "  ref:", lpad(refpos, posw), ' ')
            print(matbuf, " "^(posw + 7))
        end

        print(seqbuf, x)
        print(refbuf, y)
        print(matbuf, x == y ? '|' : ' ')

        if i % width == 0
            print(seqbuf, lpad(seqpos, posw))
            print(refbuf, lpad(refpos, posw))
            print(matbuf)

            println(io, takebuf_string(seqbuf))
            println(io, takebuf_string(matbuf))
            println(io, takebuf_string(refbuf))

            if !done(aln, s)
                println(io)
                seek(seqbuf, 0)
                seek(matbuf, 0)
                seek(refbuf, 0)
            end
        end
    end

    if i % width != 0
        print(seqbuf, lpad(seqpos, posw))
        print(refbuf, lpad(refpos, posw))
        print(matbuf)

        println(io, takebuf_string(seqbuf))
        println(io, takebuf_string(matbuf))
        println(io, takebuf_string(refbuf))
    end
end
