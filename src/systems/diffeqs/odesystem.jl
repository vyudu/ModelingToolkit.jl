"""
$(TYPEDEF)

A system of ordinary differential equations.

# Fields
$(FIELDS)

# Example

```julia
using ModelingToolkit
using ModelingToolkit: t_nounits as t, D_nounits as D

@parameters σ ρ β
@variables x(t) y(t) z(t)

eqs = [D(x) ~ σ*(y-x),
       D(y) ~ x*(ρ-z)-y,
       D(z) ~ x*y - β*z]

@named de = ODESystem(eqs,t,[x,y,z],[σ,ρ,β],tspan=(0, 1000.0))
```
"""
struct ODESystem <: AbstractODESystem
    """
    A tag for the system. If two systems have the same tag, then they are
    structurally identical.
    """
    tag::UInt
    """The ODEs defining the system."""
    eqs::Vector{Equation}
    """Independent variable."""
    iv::BasicSymbolic{Real}
    """
    Dependent (unknown) variables. Must not contain the independent variable.

    N.B.: If `torn_matching !== nothing`, this includes all variables. Actual
    ODE unknowns are determined by the `SelectedState()` entries in `torn_matching`.
    """
    unknowns::Vector
    """Parameter variables. Must not contain the independent variable."""
    ps::Vector
    """Time span."""
    tspan::Union{NTuple{2, Any}, Nothing}
    """Array variables."""
    var_to_name::Any
    """Control parameters (some subset of `ps`)."""
    ctrls::Vector
    """Observed variables."""
    observed::Vector{Equation}
    """
    Time-derivative matrix. Note: this field will not be defined until
    [`calculate_tgrad`](@ref) is called on the system.
    """
    tgrad::RefValue{Vector{Num}}
    """
    Jacobian matrix. Note: this field will not be defined until
    [`calculate_jacobian`](@ref) is called on the system.
    """
    jac::RefValue{Any}
    """
    Control Jacobian matrix. Note: this field will not be defined until
    [`calculate_control_jacobian`](@ref) is called on the system.
    """
    ctrl_jac::RefValue{Any}
    """
    Note: this field will not be defined until
    [`generate_factorized_W`](@ref) is called on the system.
    """
    Wfact::RefValue{Matrix{Num}}
    """
    Note: this field will not be defined until
    [`generate_factorized_W`](@ref) is called on the system.
    """
    Wfact_t::RefValue{Matrix{Num}}
    """
    The name of the system.
    """
    name::Symbol
    """
    A description of the system.
    """
    description::String
    """
    The internal systems. These are required to have unique names.
    """
    systems::Vector{ODESystem}
    """
    The default values to use when initial conditions and/or
    parameters are not supplied in `ODEProblem`.
    """
    defaults::Dict
    """
    The guesses to use as the initial conditions for the
    initialization system.
    """
    guesses::Dict
    """
    Tearing result specifying how to solve the system.
    """
    torn_matching::Union{Matching, Nothing}
    """
    The system for performing the initialization.
    """
    initializesystem::Union{Nothing, NonlinearSystem}
    """
    Extra equations to be enforced during the initialization sequence.
    """
    initialization_eqs::Vector{Equation}
    """
    The schedule for the code generation process.
    """
    schedule::Any
    """
    Type of the system.
    """
    connector_type::Any
    """
    Inject assignment statements before the evaluation of the RHS function.
    """
    preface::Any
    """
    A `Vector{SymbolicContinuousCallback}` that model events.
    The integrator will use root finding to guarantee that it steps at each zero crossing.
    """
    continuous_events::Vector{SymbolicContinuousCallback}
    """
    A `Vector{SymbolicDiscreteCallback}` that models events. Symbolic
    analog to `SciMLBase.DiscreteCallback` that executes an affect when a given condition is
    true at the end of an integration step.
    """
    discrete_events::Vector{SymbolicDiscreteCallback}
    """
    Topologically sorted parameter dependency equations, where all symbols are parameters and
    the LHS is a single parameter.
    """
    parameter_dependencies::Vector{Equation}
    """
    Metadata for the system, to be used by downstream packages.
    """
    metadata::Any
    """
    Metadata for MTK GUI.
    """
    gui_metadata::Union{Nothing, GUIMetadata}
    """
    A boolean indicating if the given `ODESystem` represents a system of DDEs.
    """
    is_dde::Bool
    """
    Cache for intermediate tearing state.
    """
    tearing_state::Any
    """
    Substitutions generated by tearing.
    """
    substitutions::Any
    """
    If a model `sys` is complete, then `sys.x` no longer performs namespacing.
    """
    complete::Bool
    """
    Cached data for fast symbolic indexing.
    """
    index_cache::Union{Nothing, IndexCache}
    """
    A list of discrete subsystems.
    """
    discrete_subsystems::Any
    """
    A list of actual unknowns needed to be solved by solvers.
    """
    solved_unknowns::Union{Nothing, Vector{Any}}
    """
    A vector of vectors of indices for the split parameters.
    """
    split_idxs::Union{Nothing, Vector{Vector{Int}}}
    """
    The hierarchical parent system before simplification.
    """
    parent::Any

    function ODESystem(tag, deqs, iv, dvs, ps, tspan, var_to_name, ctrls, observed, tgrad,
            jac, ctrl_jac, Wfact, Wfact_t, name, description, systems, defaults, guesses,
            torn_matching, initializesystem, initialization_eqs, schedule,
            connector_type, preface, cevents,
            devents, parameter_dependencies,
            metadata = nothing, gui_metadata = nothing, is_dde = false,
            tearing_state = nothing,
            substitutions = nothing, complete = false, index_cache = nothing,
            discrete_subsystems = nothing, solved_unknowns = nothing,
            split_idxs = nothing, parent = nothing; checks::Union{Bool, Int} = true)
        if checks == true || (checks & CheckComponents) > 0
            check_independent_variables([iv])
            check_variables(dvs, iv)
            check_parameters(ps, iv)
            check_equations(deqs, iv)
            check_equations(equations(cevents), iv)
        end
        if checks == true || (checks & CheckUnits) > 0
            u = __get_unit_type(dvs, ps, iv)
            check_units(u, deqs)
        end
        new(tag, deqs, iv, dvs, ps, tspan, var_to_name, ctrls, observed, tgrad, jac,
            ctrl_jac, Wfact, Wfact_t, name, description, systems, defaults, guesses, torn_matching,
            initializesystem, initialization_eqs, schedule, connector_type, preface,
            cevents, devents, parameter_dependencies, metadata,
            gui_metadata, is_dde, tearing_state, substitutions, complete, index_cache,
            discrete_subsystems, solved_unknowns, split_idxs, parent)
    end
end

function ODESystem(deqs::AbstractVector{<:Equation}, iv, dvs, ps;
        controls = Num[],
        observed = Equation[],
        systems = ODESystem[],
        tspan = nothing,
        name = nothing,
        description = "",
        default_u0 = Dict(),
        default_p = Dict(),
        defaults = _merge(Dict(default_u0), Dict(default_p)),
        guesses = Dict(),
        initializesystem = nothing,
        initialization_eqs = Equation[],
        schedule = nothing,
        connector_type = nothing,
        preface = nothing,
        continuous_events = nothing,
        discrete_events = nothing,
        parameter_dependencies = Equation[],
        checks = true,
        metadata = nothing,
        gui_metadata = nothing,
        is_dde = nothing)
    name === nothing &&
        throw(ArgumentError("The `name` keyword must be provided. Please consider using the `@named` macro"))
    @assert all(control -> any(isequal.(control, ps)), controls) "All controls must also be parameters."
    iv′ = value(iv)
    ps′ = value.(ps)
    ctrl′ = value.(controls)
    dvs′ = value.(dvs)
    dvs′ = filter(x -> !isdelay(x, iv), dvs′)
    parameter_dependencies, ps′ = process_parameter_dependencies(
        parameter_dependencies, ps′)
    if !(isempty(default_u0) && isempty(default_p))
        Base.depwarn(
            "`default_u0` and `default_p` are deprecated. Use `defaults` instead.",
            :ODESystem, force = true)
    end
    defaults = Dict{Any, Any}(todict(defaults))
    var_to_name = Dict()
    process_variables!(var_to_name, defaults, dvs′)
    process_variables!(var_to_name, defaults, ps′)
    process_variables!(var_to_name, defaults, [eq.lhs for eq in parameter_dependencies])
    process_variables!(var_to_name, defaults, [eq.rhs for eq in parameter_dependencies])
    defaults = Dict{Any, Any}(value(k) => value(v)
    for (k, v) in pairs(defaults) if v !== nothing)

    sysdvsguesses = [ModelingToolkit.getguess(st) for st in dvs′]
    hasaguess = findall(!isnothing, sysdvsguesses)
    var_guesses = dvs′[hasaguess] .=> sysdvsguesses[hasaguess]
    sysdvsguesses = isempty(var_guesses) ? Dict() : todict(var_guesses)
    syspsguesses = [ModelingToolkit.getguess(st) for st in ps′]
    hasaguess = findall(!isnothing, syspsguesses)
    ps_guesses = ps′[hasaguess] .=> syspsguesses[hasaguess]
    syspsguesses = isempty(ps_guesses) ? Dict() : todict(ps_guesses)
    syspdepguesses = [ModelingToolkit.getguess(eq.lhs) for eq in parameter_dependencies]
    hasaguess = findall(!isnothing, syspdepguesses)
    pdep_guesses = [eq.lhs for eq in parameter_dependencies][hasaguess] .=>
        syspdepguesses[hasaguess]
    syspdepguesses = isempty(pdep_guesses) ? Dict() : todict(pdep_guesses)

    guesses = merge(sysdvsguesses, syspsguesses, syspdepguesses, todict(guesses))
    guesses = Dict{Any, Any}(value(k) => value(v)
    for (k, v) in pairs(guesses) if v !== nothing)

    isempty(observed) || collect_var_to_name!(var_to_name, (eq.lhs for eq in observed))

    tgrad = RefValue(EMPTY_TGRAD)
    jac = RefValue{Any}(EMPTY_JAC)
    ctrl_jac = RefValue{Any}(EMPTY_JAC)
    Wfact = RefValue(EMPTY_JAC)
    Wfact_t = RefValue(EMPTY_JAC)
    sysnames = nameof.(systems)
    if length(unique(sysnames)) != length(sysnames)
        throw(ArgumentError("System names must be unique."))
    end
    cont_callbacks = SymbolicContinuousCallbacks(continuous_events)
    disc_callbacks = SymbolicDiscreteCallbacks(discrete_events)

    if is_dde === nothing
        is_dde = _check_if_dde(deqs, iv′, systems)
    end
    ODESystem(Threads.atomic_add!(SYSTEM_COUNT, UInt(1)),
        deqs, iv′, dvs′, ps′, tspan, var_to_name, ctrl′, observed, tgrad, jac,
        ctrl_jac, Wfact, Wfact_t, name, description, systems,
        defaults, guesses, nothing, initializesystem,
        initialization_eqs, schedule, connector_type, preface, cont_callbacks,
        disc_callbacks, parameter_dependencies,
        metadata, gui_metadata, is_dde, checks = checks)
end

function ODESystem(eqs, iv; kwargs...)
    eqs = collect(eqs)
    # NOTE: this assumes that the order of algebraic equations doesn't matter
    diffvars = OrderedSet()
    allunknowns = OrderedSet()
    ps = OrderedSet()
    # reorder equations such that it is in the form of `diffeq, algeeq`
    diffeq = Equation[]
    algeeq = Equation[]
    # initial loop for finding `iv`
    if iv === nothing
        for eq in eqs
            if !(eq.lhs isa Number) # assume eq.lhs is either Differential or Number
                iv = iv_from_nested_derivative(eq.lhs)
                break
            end
        end
    end
    iv = value(iv)
    iv === nothing && throw(ArgumentError("Please pass in independent variables."))
    compressed_eqs = Equation[] # equations that need to be expanded later, like `connect(a, b)`
    for eq in eqs
        eq.lhs isa Union{Symbolic, Number} || (push!(compressed_eqs, eq); continue)
        collect_vars!(allunknowns, ps, eq, iv)
        if isdiffeq(eq)
            diffvar, _ = var_from_nested_derivative(eq.lhs)
            if check_scope_depth(getmetadata(diffvar, SymScope, LocalScope()), 0)
                isequal(iv, iv_from_nested_derivative(eq.lhs)) ||
                    throw(ArgumentError("An ODESystem can only have one independent variable."))
                diffvar in diffvars &&
                    throw(ArgumentError("The differential variable $diffvar is not unique in the system of equations."))
                push!(diffvars, diffvar)
            end
            push!(diffeq, eq)
        else
            push!(algeeq, eq)
        end
    end
    for eq in get(kwargs, :parameter_dependencies, Equation[])
        collect_vars!(allunknowns, ps, eq, iv)
    end
    for ssys in get(kwargs, :systems, ODESystem[])
        collect_scoped_vars!(allunknowns, ps, ssys, iv)
    end
    for v in allunknowns
        isdelay(v, iv) || continue
        collect_vars!(allunknowns, ps, arguments(v)[1], iv)
    end
    new_ps = OrderedSet()
    for p in ps
        if iscall(p) && operation(p) === getindex
            par = arguments(p)[begin]
            if Symbolics.shape(Symbolics.unwrap(par)) !== Symbolics.Unknown() &&
               all(par[i] in ps for i in eachindex(par))
                push!(new_ps, par)
            else
                push!(new_ps, p)
            end
        else
            push!(new_ps, p)
        end
    end
    algevars = setdiff(allunknowns, diffvars)
    # the orders here are very important!
    return ODESystem(Equation[diffeq; algeeq; compressed_eqs], iv,
        collect(Iterators.flatten((diffvars, algevars))), collect(new_ps); kwargs...)
end

# NOTE: equality does not check cached Jacobian
function Base.:(==)(sys1::ODESystem, sys2::ODESystem)
    sys1 === sys2 && return true
    iv1 = get_iv(sys1)
    iv2 = get_iv(sys2)
    isequal(iv1, iv2) &&
        isequal(nameof(sys1), nameof(sys2)) &&
        _eq_unordered(get_eqs(sys1), get_eqs(sys2)) &&
        _eq_unordered(get_unknowns(sys1), get_unknowns(sys2)) &&
        _eq_unordered(get_ps(sys1), get_ps(sys2)) &&
        all(s1 == s2 for (s1, s2) in zip(get_systems(sys1), get_systems(sys2)))
end

function flatten(sys::ODESystem, noeqs = false)
    systems = get_systems(sys)
    if isempty(systems)
        return sys
    else
        return ODESystem(noeqs ? Equation[] : equations(sys),
            get_iv(sys),
            unknowns(sys),
            parameters(sys),
            parameter_dependencies = parameter_dependencies(sys),
            guesses = guesses(sys),
            observed = observed(sys),
            continuous_events = continuous_events(sys),
            discrete_events = discrete_events(sys),
            defaults = defaults(sys),
            name = nameof(sys),
            description = description(sys),
            initialization_eqs = initialization_equations(sys),
            is_dde = is_dde(sys),
            checks = false)
    end
end

ODESystem(eq::Equation, args...; kwargs...) = ODESystem([eq], args...; kwargs...)

"""
$(SIGNATURES)

Build the observed function assuming the observed equations are all explicit,
i.e. there are no cycles.
"""
function build_explicit_observed_function(sys, ts;
        inputs = nothing,
        expression = false,
        eval_expression = false,
        eval_module = @__MODULE__,
        output_type = Array,
        checkbounds = true,
        drop_expr = drop_expr,
        ps = parameters(sys),
        return_inplace = false,
        param_only = false,
        op = Operator,
        throw = true)
    if (isscalar = symbolic_type(ts) !== NotSymbolic())
        ts = [ts]
    end
    ts = unwrap.(ts)
    issplit = has_index_cache(sys) && get_index_cache(sys) !== nothing
    if is_dde(sys)
        if issplit
            ts = map(
                x -> delay_to_function(
                    sys, x; history_arg = issplit ? MTKPARAMETERS_ARG : DEFAULT_PARAMS_ARG),
                ts)
        else
            ts = map(x -> delay_to_function(sys, x), ts)
        end
    end

    vars = Set()
    foreach(v -> vars!(vars, v; op), ts)
    ivs = independent_variables(sys)
    dep_vars = scalarize(setdiff(vars, ivs))

    obs = param_only ? Equation[] : observed(sys)

    cs = collect_constants(obs)
    if !isempty(cs) > 0
        cmap = map(x -> x => getdefault(x), cs)
        obs = map(x -> x.lhs ~ substitute(x.rhs, cmap), obs)
    end

    sts = param_only ? Set() : Set(unknowns(sys))
    sts = param_only ? Set() :
          union(sts,
        Set(arguments(st)[1] for st in sts if iscall(st) && operation(st) === getindex))

    observed_idx = Dict(x.lhs => i for (i, x) in enumerate(obs))
    param_set = Set(full_parameters(sys))
    param_set = union(param_set,
        Set(arguments(p)[1] for p in param_set if iscall(p) && operation(p) === getindex))
    param_set_ns = Set(unknowns(sys, p) for p in full_parameters(sys))
    param_set_ns = union(param_set_ns,
        Set(arguments(p)[1]
        for p in param_set_ns if iscall(p) && operation(p) === getindex))
    namespaced_to_obs = Dict(unknowns(sys, x.lhs) => x.lhs for x in obs)
    namespaced_to_sts = param_only ? Dict() :
                        Dict(unknowns(sys, x) => x for x in unknowns(sys))

    # FIXME: This is a rather rough estimate of dependencies. We assume
    # the expression depends on everything before the `maxidx`.
    subs = Dict()
    maxidx = 0
    for s in dep_vars
        if s in param_set || s in param_set_ns ||
           iscall(s) &&
           operation(s) === getindex &&
           (arguments(s)[1] in param_set || arguments(s)[1] in param_set_ns)
            continue
        end
        idx = get(observed_idx, s, nothing)
        if idx !== nothing
            idx > maxidx && (maxidx = idx)
        else
            s′ = get(namespaced_to_obs, s, nothing)
            if s′ !== nothing
                subs[s] = s′
                s = s′
                idx = get(observed_idx, s, nothing)
            end
            if idx !== nothing
                idx > maxidx && (maxidx = idx)
            elseif !(s in sts)
                s′ = get(namespaced_to_sts, s, nothing)
                if s′ !== nothing
                    subs[s] = s′
                    continue
                end
                if throw
                    Base.throw(ArgumentError("$s is neither an observed nor an unknown variable."))
                else
                    # TODO: return variables that don't exist in the system.
                    return nothing
                end
            end
            continue
        end
    end
    ts = map(t -> substitute(t, subs), ts)
    obsexprs = []

    for i in 1:maxidx
        eq = obs[i]
        if is_dde(sys)
            eq = delay_to_function(
                sys, eq; history_arg = issplit ? MTKPARAMETERS_ARG : DEFAULT_PARAMS_ARG)
        end
        lhs = eq.lhs
        rhs = eq.rhs
        push!(obsexprs, lhs ← rhs)
    end

    if inputs !== nothing
        ps = setdiff(ps, inputs) # Inputs have been converted to parameters by io_preprocessing, remove those from the parameter list
    end
    _ps = ps
    if ps isa Tuple
        ps = DestructuredArgs.(unwrap.(ps), inbounds = !checkbounds)
    elseif has_index_cache(sys) && get_index_cache(sys) !== nothing
        ps = DestructuredArgs.(reorder_parameters(get_index_cache(sys), unwrap.(ps)))
        if isempty(ps) && inputs !== nothing
            ps = (:EMPTY,)
        end
    else
        ps = (DestructuredArgs(unwrap.(ps), inbounds = !checkbounds),)
    end
    dvs = DestructuredArgs(unknowns(sys), inbounds = !checkbounds)
    if is_dde(sys)
        dvs = (dvs, DDE_HISTORY_FUN)
    else
        dvs = (dvs,)
    end
    p_start = param_only ? 1 : (length(dvs) + 1)
    if inputs === nothing
        args = param_only ? [ps..., ivs...] : [dvs..., ps..., ivs...]
    else
        inputs = unwrap.(inputs)
        ipts = DestructuredArgs(inputs, inbounds = !checkbounds)
        args = param_only ? [ipts, ps..., ivs...] : [dvs..., ipts, ps..., ivs...]
        p_start += 1
    end
    pre = get_postprocess_fbody(sys)

    array_wrapper = if param_only
        wrap_array_vars(sys, ts; ps = _ps, dvs = nothing, inputs, history = is_dde(sys)) .∘
        wrap_parameter_dependencies(sys, isscalar)
    else
        wrap_array_vars(sys, ts; ps = _ps, inputs, history = is_dde(sys)) .∘
        wrap_parameter_dependencies(sys, isscalar)
    end
    mtkparams_wrapper = wrap_mtkparameters(sys, isscalar, p_start)
    if mtkparams_wrapper isa Tuple
        oop_mtkp_wrapper = mtkparams_wrapper[1]
    else
        oop_mtkp_wrapper = mtkparams_wrapper
    end

    # Need to keep old method of building the function since it uses `output_type`,
    # which can't be provided to `build_function`
    oop_fn = Func(args, [],
                 pre(Let(obsexprs,
                     isscalar ? ts[1] : MakeArray(ts, output_type),
                     false))) |> array_wrapper[1] |> oop_mtkp_wrapper |> toexpr
    oop_fn = expression ? oop_fn : eval_or_rgf(oop_fn; eval_expression, eval_module)

    if !isscalar
        iip_fn = build_function(ts,
            args...;
            postprocess_fbody = pre,
            wrap_code = mtkparams_wrapper .∘ array_wrapper .∘
                        wrap_assignments(isscalar, obsexprs),
            expression = Val{true})[2]
        if !expression
            iip_fn = eval_or_rgf(iip_fn; eval_expression, eval_module)
        end
    end
    if isscalar || !return_inplace
        return oop_fn
    else
        return oop_fn, iip_fn
    end
end

function populate_delays(delays::Set, obsexprs, histfn, sys, sym)
    _vars_util = vars(sym)
    for v in _vars_util
        v in delays && continue
        iscall(v) && issym(operation(v)) && (args = arguments(v); length(args) == 1) &&
            iscall(only(args)) || continue

        idx = variable_index(sys, operation(v)(get_iv(sys)))
        idx === nothing && error("Delay term $v is not an unknown in the system")
        push!(delays, v)
        push!(obsexprs, v ← histfn(only(args))[idx])
    end
end

function _eq_unordered(a, b)
    length(a) === length(b) || return false
    n = length(a)
    idxs = Set(1:n)
    for x in a
        idx = findfirst(isequal(x), b)
        idx === nothing && return false
        idx ∈ idxs || return false
        delete!(idxs, idx)
    end
    return true
end

# We have a stand-alone function to convert a `NonlinearSystem` or `ODESystem`
# to an `ODESystem` to connect systems, and we later can reply on
# `structural_simplify` to convert `ODESystem`s to `NonlinearSystem`s.
"""
$(TYPEDSIGNATURES)

Convert a `NonlinearSystem` to an `ODESystem` or converts an `ODESystem` to a
new `ODESystem` with a different independent variable.
"""
function convert_system(::Type{<:ODESystem}, sys, t; name = nameof(sys))
    isempty(observed(sys)) ||
        throw(ArgumentError("`convert_system` cannot handle reduced model (i.e. observed(sys) is non-empty)."))
    t = value(t)
    varmap = Dict()
    sts = unknowns(sys)
    newsts = similar(sts, Any)
    for (i, s) in enumerate(sts)
        if iscall(s)
            args = arguments(s)
            length(args) == 1 ||
                throw(InvalidSystemException("Illegal unknown: $s. The unknown can have at most one argument like `x(t)`."))
            arg = args[1]
            if isequal(arg, t)
                newsts[i] = s
                continue
            end
            ns = maketerm(typeof(s), operation(s), Any[t],
                SymbolicUtils.metadata(s))
            newsts[i] = ns
            varmap[s] = ns
        else
            ns = variable(getname(s); T = FnType)(t)
            newsts[i] = ns
            varmap[s] = ns
        end
    end
    sub = Base.Fix2(substitute, varmap)
    if sys isa AbstractODESystem
        iv = only(independent_variables(sys))
        sub.x[iv] = t # otherwise the Differentials aren't fixed
    end
    neweqs = map(sub, equations(sys))
    defs = Dict(sub(k) => sub(v) for (k, v) in defaults(sys))
    return ODESystem(neweqs, t, newsts, parameters(sys); defaults = defs, name = name,
        checks = false)
end

"""
$(SIGNATURES)

Add accumulation variables for `vars`.
"""
function add_accumulations(sys::ODESystem, vars = unknowns(sys))
    avars = [rename(v, Symbol(:accumulation_, getname(v))) for v in vars]
    add_accumulations(sys, avars .=> vars)
end

"""
$(SIGNATURES)

Add accumulation variables for `vars`. `vars` is a vector of pairs in the form
of

```julia
[cumulative_var1 => x + y, cumulative_var2 => x^2]
```
Then, cumulative variables `cumulative_var1` and `cumulative_var2` that computes
the cumulative `x + y` and `x^2` would be added to `sys`.
"""
function add_accumulations(sys::ODESystem, vars::Vector{<:Pair})
    eqs = get_eqs(sys)
    avars = map(first, vars)
    if (ints = intersect(avars, unknowns(sys)); !isempty(ints))
        error("$ints already exist in the system!")
    end
    D = Differential(get_iv(sys))
    @set! sys.eqs = [eqs; Equation[D(a) ~ v[2] for (a, v) in zip(avars, vars)]]
    @set! sys.unknowns = [get_unknowns(sys); avars]
    @set! sys.defaults = merge(get_defaults(sys), Dict(a => 0.0 for a in avars))
end

function Base.show(io::IO, mime::MIME"text/plain", sys::ODESystem; hint = true, bold = true)
    # Print general AbstractSystem information
    invoke(Base.show, Tuple{typeof(io), typeof(mime), AbstractSystem},
        io, mime, sys; hint, bold)

    # Print initialization equations (unique to ODESystems)
    nini = length(initialization_equations(sys))
    nini > 0 && printstyled(io, "\nInitialization equations ($nini):"; bold)
    nini > 0 && hint && print(io, " see initialization_equations(sys)")

    return nothing
end
