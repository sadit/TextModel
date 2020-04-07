# This file is a part of TextSearch.jl
# License is Apac

export search_with_intersection, intersection
"""
find_insert_position(arr::AbstractVector, value)

Finds the insert position of `value` inside `arr`.
Note: it returns `0` for lower limit.
"""
function find_insert_position(v, arr::AbstractVector, by::Function)::Int
    n = length(arr)
    sp = 1
    ep = n
    while sp != ep
        imedian = ceil(Int, (ep+sp) / 2)
        median = by(arr[imedian])
        if v < median
            ep = imedian-1
        elseif median < v
            sp = imedian
        else
            return imedian
        end
    end
    
    sp == 1 && v < by(arr[sp]) ? 0 : sp
end

"""
    baezayates(first::AbstractVector, byfirst::Function, second::AbstractVector{T}, bysecond::Function, output::AbstractVector{T}) where T

Computes the intersection between first and second ordered lists using the Baeza-Yates algorithm [cite]; elements are mapped to a comparable value using `byfirst` and `bysecond` functions, for `first` and `second` lists.
The matched objects of `second` are stored in `output`.
"""
function baezayates(first::AbstractVector, byfirst::Function, second::AbstractVector{T}, bysecond::Function, output::AbstractVector{T}) where T
    m = length(first)
    n = length(second)
    imedian = ceil(Int, m / 2)
    median = byfirst(first[imedian])
    pos = find_insert_position(median, second, bysecond)
    _first = @view first[1:imedian-1]
    _second = @view second[1:pos-1]
    length(_first) > 0 && length(_second) > 0 && baezayates(_first, byfirst, _second, bysecond, output)
    
    if pos == 0
        pos += 1
    elseif median == bysecond(second[pos])
        push!(output, second[pos])
        #callback(first[imedian], second[pos])
        pos += 1
    end
    
    _first = @view first[imedian+1:m]
    _second = @view second[pos:n]
    length(_first) > 0 && length(_second) > 0 && baezayates(_first, byfirst, _second, bysecond, output)
    
    output
end

"""
    _svs(T::Type, sets::AbstractVector, by::Function)

Computes the intersection of the ordered lists in `sets` using the by::Function
to extract a comparable for elements in each list
"""
function _svs(T::Type, sets::AbstractVector, by::Function)    
    sort!(sets, by=p->length(p), rev=true)
    res = baezayates(pop!(sets), by, pop!(sets), by, T[])
    push!(sets, res)

    while length(sets) > 1
        res = baezayates(pop!(sets), by, pop!(sets), by, T[])
        push!(sets, res)
    end

    sets[1]
end

"""
    intersection(sets::AbstractVector{S}, by::Function=identity) where {S<:AbstractVector}

Computes the intersection of sets represented by ordered arrays `lists` using the by::Function
to extract a comparable for elements in each list
"""
function intersection(sets::AbstractVector{S}, by::Function=identity) where
        {S<:AbstractVector}
    n = length(sets)
    T = eltype(eltype(sets))
    if n == 0
        T[]
    elseif n == 1
        sets[1]
    else
        _svs(T, sets, by)
    end
end

_get_id(x) = x.id

function search_with_intersection(invindex::InvIndex, dist::Function, q::SVEC, res::KnnResult; ignore_lists_larger_than::Int=100_000)
    # normalize!(q) # we expect a normalized q 
    L = PostList[]
    for (sym, weight) in q
        list = get(invindex.lists, sym, EMPTY_POSTING_LIST)
        if length(list) > 0 && length(list) < ignore_lists_larger_than
            push!(L, list)
        end
    end

    I = intersection(L, _get_id)
    D = SVEC()
    output = PostList()
    for (sym, weight) in q
        list = get(invindex.lists, sym, EMPTY_POSTING_LIST)
        if length(list) > 0 && length(list) < ignore_lists_larger_than
            empty!(output)
            for e in baezayates(I, _get_id, list, _get_id, output)
                D[e.id] = get(D, e.id, 0.0) + weight * e.weight
            end
        end
    end

    for (i, w) in D
        if dist == angle_distance
            w = max(-1.0, w)
            w = min(1.0, w)
            w = acos(w)
            push!(res, i, w)
        else
            push!(res, i, 1.0 - w)  # cosine distance
        end
    end

    res
end

function search(invindex::InvIndex, dist::Function, q::SVEC, res::KnnResult; ignore_lists_larger_than::Int=100_000)
    # normalize!(q) # we expect a normalized q 
    L = PostList[]
    for (sym, weight) in q
        list = get(invindex.lists, sym, EMPTY_POSTING_LIST)
        if length(list) > 0 && length(list) < ignore_lists_larger_than
            push!(L, list)
        end
    end

    I = intersection(L, _get_id)
    D = SVEC()
    output = PostList()
    for (sym, weight) in q
        list = get(invindex.lists, sym, EMPTY_POSTING_LIST)
        if length(list) > 0 && length(list) < ignore_lists_larger_than
            empty!(output)
            for e in baezayates(I, _get_id, list, _get_id, output)
                D[e.id] = get(D, e.id, 0.0) + weight * e.weight
            end
        end
    end

    for (i, w) in D
        if dist == angle_distance
            w = max(-1.0, w)
            w = min(1.0, w)
            w = acos(w)
            push!(res, i, w)
        else
            push!(res, i, 1.0 - w)  # cosine distance
        end
    end

    res
end