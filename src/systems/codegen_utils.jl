function generated_argument_name(i::Int)
    return Symbol(:__mtk_arg_, i)
end

function array_variable_assignments(args...)
    var_to_arridxs = Dict{BasicSymbolic, Array{Tuple{Int, Int}}}()
    for (i, arg) in enumerate(args)
        symbolic_type(arg) == NotSymbolic() || continue
        arg isa AbstractArray || continue

        for (j, var) in enumerate(arg)
            var = unwrap(var)
            iscall(var) || continue
            operation(var) == getindex || continue
            arrvar = arguments(var)[1]
            idxbuffer = get!(() -> map(Returns((0, 0)), eachindex(arrvar)), var_to_arridxs, arrvar)
            idxbuffer[arguments(var)[2:end]...] = (i, j)
        end
    end

    assignments = Assignment[]
    for (arrvar, idxs) in var_to_arridxs
        any(iszero ∘ first, idxs) && continue

        if allequal(Iterators.map(first, idxs))
            buffer_idx = first(first(idxs))
            idxs = map(last, idxs)
            if first(idxs) < last(idxs) && vec(idxs) == first(idxs):last(idxs)
                idxs = first(idxs):last(idxs)
            elseif vec(idxs) == last(idxs):-1:first(idxs)
                idxs = last(idxs):-1:first(idxs)
            else
                idxs = SArray{Tuple{size(idxs)...}}(idxs)
            end
            push!(assignments, arrvar ← term(reshape, term(view, generated_argument_name(buffer_idx), idxs), size(arrvar)))
        else
            elems = map(idxs) do idx
                i, j = idx
                term(getindex, generated_argument_name(i), j)
            end
            push!(assignments, arrvar ← MakeArray(elems, SArray))
        end
    end

    return assignments
end

function build_function_wrapper(sys::AbstractSystem, expr, args...; p_start = 2, p_end = is_time_dependent(sys) ? length(args) - 1 : length(args), wrap_delays = is_dde(sys), wrap_code = identity, add_observed = true, filter_observed = Returns(true), create_bindings = true, output_type = nothing, mkarray = nothing, wrap_mtkparameters = true, kwargs...)
    isscalar = !(expr isa AbstractArray || symbolic_type(expr) == ArraySymbolic())

    obs = filter(filter_observed, observed(sys))
    if wrap_delays
        history_arg = is_split(sys) ? MTKPARAMETERS_ARG : generated_argument_name(p_start)
        obs = map(obs) do eq
            delay_to_function(sys, eq; history_arg)
        end
        expr = delay_to_function(sys, expr; history_arg)
        args = (args[1:p_start-1]..., DDE_HISTORY_FUN, args[p_start:end]...)
        p_start += 1
        p_end += 1
    end
    pdeps = parameter_dependencies(sys)

    cmap, _ = get_cmap(sys)
    extra_constants = collect_constants(expr)
    filter!(extra_constants) do c
        !any(x -> isequal(c, x.lhs), cmap)
    end
    for c in extra_constants
        push!(cmap, c ~ getdefault(c))
    end
    if add_observed
        obsidxs = observed_equations_used_by(sys, expr)
    else
        obsidxs = Int[]
    end
    pdepidxs = observed_equations_used_by(sys, expr; obs = pdeps)

    assignments = array_variable_assignments(args...)

    for eq in Iterators.flatten((cmap, pdeps[pdepidxs], obs[obsidxs]))
        push!(assignments, eq.lhs ← eq.rhs)
    end

    args = ntuple(Val(length(args))) do i
        arg = args[i]
        if is_time_dependent(sys)
            arg = if symbolic_type(arg) == NotSymbolic()
                arg isa AbstractArray ?
                map(x -> time_varying_as_func(unwrap(x), sys), arg) : arg
            else
                time_varying_as_func(unwrap(arg), sys)
            end
        end
        if symbolic_type(arg) == NotSymbolic() && arg isa AbstractArray
            DestructuredArgs(arg, generated_argument_name(i); create_bindings)
        else
            arg
        end
    end

    if is_split(sys) && wrap_mtkparameters
        if p_start > p_end
            args = (args[1:p_start-1]..., MTKPARAMETERS_ARG, args[p_end+1:end]...)
        else
            # cannot apply `create_bindings` here since it doesn't nest
            args = (args[1:(p_start - 1)]...,
                DestructuredArgs(collect(args[p_start:p_end]), MTKPARAMETERS_ARG),
                args[(p_end + 1):end]...)
        end
    end

    if has_preface(sys) && (pref = preface(sys)) !== nothing
        append!(assignments, pref)
    end

    wrap_code = wrap_code .∘ wrap_assignments(isscalar, assignments)

    similarto = nothing
    if output_type === Tuple
        expr = MakeTuple(Tuple(expr))
        wrap_code = wrap_code[1]
    elseif mkarray === nothing
        similarto = output_type
    else
        expr = mkarray(expr, output_type)
        wrap_code = wrap_code[2]
    end

    if wrap_code isa Tuple && symbolic_type(expr) == ScalarSymbolic()
        wrap_code = wrap_code[1]
    end
    return build_function(expr, args...; wrap_code, similarto, kwargs...)
end
