
export dbow
import SparseArrays: sparsevec

function dbow(model::Model, x::AbstractSparseVector)
    DBOW{Symbol,Float64}(model.id2token[x.nzind[i]] => x.nzval[i] for i in eachindex(x))
end

function sparsevec(model::VectorModel, bow::DBOW)
    I = Int[]
    F = Float64[]

    for (sym, weight) in bow
        idfreq = get(model.tokens, sym, nothing)
        if idfreq === nothing
            continue
        end

        push!(I, idfreq.id)
        push!(F, weight)
    end

    sparsevec(I, F, model.m)
end

function sparsevec(model::EntModel, bow::DBOW)
    I = Int[]
    F = Float64[]

    for (sym, weight) in bow
        idweight = get(model.tokens, sym, nothing)
        if idweight === nothing
            continue
        end

        push!(I, idweight.id)
        push!(F, weight)
    end

    sparsevec(I, F, model.m)
end

