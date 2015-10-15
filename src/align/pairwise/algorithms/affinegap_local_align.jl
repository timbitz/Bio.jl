function affinegap_local_align{T}(a, b, submat::AbstractSubstitutionMatrix{T}, gap_open_penalty::T, gap_extend_penalty::T)
    m = length(a)
    n = length(b)
    ge = gap_extend_penalty
    goe = gap_open_penalty + ge
    trace = Matrix{Trace}(m + 1, n + 1)
    H = Vector{T}(m + 1)
    E = Vector{T}(m)
    # run dynamic programming column by column
    @inbounds begin
        H[1] = T(0)
        trace[1,1] = TRACE_NONE
        for i in 1:m
            H[i+1] = T(0)
            trace[i+1,1] = TRACE_NONE
        end
        best_score = T(0)
        best_endpos = (0, 0)
        for j in 1:n
            h_diag = H[1]
            H[1] = T(0)
            trace[1,j+1] = TRACE_NONE
            # any value goes well since this will be set in the first iteration
            F = T(0)
            for i in 1:m
                # gap in the sequence A
                e = H[i+1] - goe
                if j > 1
                    e = max(e, E[i] - ge)
                end
                # gap in the sequence B
                f = H[i] - goe
                if i > 1
                    f = max(f, F - ge)
                end
                # match
                h = h_diag + submat[a[i],b[j]]
                # find the best score and its trace
                best = max(T(0), e, f, h)
                t = TRACE_NONE
                e == best && (t |= TRACE_DELETE)
                f == best && (t |= TRACE_INSERT)
                h == best && (t |= TRACE_MATCH)
                # update
                E[i] = e
                F = f
                h_diag = H[i+1]
                H[i+1] = best
                trace[i+1,j+1] = t
                if best ≥ best_score
                    best_score = best
                    best_endpos = (i, j)
                end
            end
        end
    end
    return best_score, trace, best_endpos
end

function affine_local_traceback(a, b, trace, endpos)
    anchors = Vector{AlignmentAnchor}()
    i, j = endpos
    @start_traceback
    while trace[i+1,j+1] != TRACE_NONE
        t = trace[i+1,j+1]
        if t & TRACE_MATCH > 0
            if a[i] == b[j]
                @match
            else
                @mismatch
            end
        elseif t & TRACE_DELETE > 0
            @delete
        elseif t & TRACE_INSERT > 0
            @insert
        end
        error("failed to trace back")
    end
    @finish_traceback
    return AlignedSequence(a, anchors)
end
