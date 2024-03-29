module Types

export NamedTrajectory
export KnotPoint

"""
We define the following struct to store and organize the various components of a trajectory. (e.g. the state `x`, control `u`, and control derivative `du` and `ddu`)

```julia
mutable struct NamedTrajectory
    data::AbstractMatrix{Float64}
    datavec::AbstractVector{Float64}
    T::Int
    timestep::Float64
    dynamical_timesteps::Bool
    dim::Int
    dims::NamedTuple{dnames, <:Tuple{Vararg{Int}}} where dnames
    bounds::NamedTuple{bnames, <:Tuple{Vararg{AbstractVector{Float64}}}} where bnames
    initial::NamedTuple{inames, <:Tuple{Vararg{AbstractVector{Float64}}}} where inames
    final::NamedTuple{fnames, <:Tuple{Vararg{AbstractVector{Float64}}}} where fnames
    components::NamedTuple{names, <:Tuple{Vararg{AbstractVector{Int}}}} where names
    controls_names::Tuple{Vararg{Symbol}}
end
```
"""

const BoundType = Tuple{AbstractVector{<:Real}, AbstractVector{<:Real}}

mutable struct NamedTrajectory
    data::AbstractMatrix{Float64}
    datavec::AbstractVector{Float64}
    T::Int
    timestep::Float64
    dynamical_timesteps::Bool
    dim::Int
    dims::NamedTuple{dnames, <:Tuple{Vararg{Int}}} where dnames
    bounds::NamedTuple{bnames, <:Tuple{Vararg{BoundType}}} where bnames
    initial::NamedTuple{inames, <:Tuple{Vararg{AbstractVector{<:Real}}}} where inames
    final::NamedTuple{fnames, <:Tuple{Vararg{AbstractVector{<:Real}}}} where fnames
    goal::NamedTuple{gnames, <:Tuple{Vararg{AbstractVector{<:Real}}}} where gnames
    components::NamedTuple{cnames, <:Tuple{Vararg{AbstractVector{Int}}}} where cnames
    names::Tuple{Vararg{Symbol}}
    controls_names::Tuple{Vararg{Symbol}}
end


function NamedTrajectory(
    comp_data::NamedTuple{names, <:Tuple{Vararg{vals}}} where
        {names, vals <: AbstractVecOrMat};
    controls::Union{Symbol, Tuple{Vararg{Symbol}}}=(),
    timestep::Union{Nothing, Float64}=nothing,
    dynamical_timesteps::Bool=false,
    bounds=(;),
    initial=(;),
    final=(;),
    goal=(;),
)
    controls = (controls isa Symbol) ? (controls,) : controls

    @assert !isempty(controls)
    @assert !isnothing(timestep)

    @assert all([k ∈ keys(comp_data) for k ∈ controls])
    @assert all([k ∈ keys(comp_data) for k ∈ keys(initial)])
    @assert all([k ∈ keys(comp_data) for k ∈ keys(final)])
    @assert all([k ∈ keys(comp_data) for k ∈ keys(goal)])

    @assert all([k ∈ keys(comp_data) for k ∈ keys(bounds)])
    @assert all([
        bound isa AbstractVector{<:Real} ||
        bound isa BoundType ||
        bound isa Tuple{<:Real,<:Real}
            for bound ∈ bounds
    ])

    bounds_dict = Dict{Symbol,Any}(pairs(bounds))
    for (name, bound) ∈ bounds_dict
        if bound isa AbstractVector
            bounds_dict[name] = (-bound, bound)
        elseif bound isa Tuple{<:Real, <:Real}
            bounds_dict[name] = ([bound[1]], [bound[2]])
        end
    end
    bounds = NamedTuple(bounds_dict)

    comp_data_pairs = []
    for (key, val) ∈ pairs(comp_data)
        if val isa AbstractVector{<:Real}
            data = reshape(val, 1, :)
            push!(comp_data_pairs, key => data)
        else
            push!(comp_data_pairs, key => val)
        end
    end

    data = vcat([val for (key, val) ∈ comp_data_pairs]...)

    T = size(data, 2)

    datavec = vec(data)

    # do this to store data matrix as view of datavec
    data = reshape(view(datavec, :), :, T)

    dim = size(data, 1)

    dims_pairs = [(k => size(v, 1)) for (k, v) ∈ comp_data_pairs]

    dims_tuple = NamedTuple(dims_pairs)

    @assert all([length(bounds[k][1]) == dims_tuple[k] for k ∈ keys(bounds)])
    @assert all([length(initial[k]) == dims_tuple[k] for k ∈ keys(initial)])
    @assert all([length(final[k]) == dims_tuple[k] for k ∈ keys(final)])
    @assert all([length(goal[k]) == dims_tuple[k] for k ∈ keys(goal)])

    comp_pairs::Vector{Pair{Symbol, AbstractVector{Int}}} =
        [(dims_pairs[1][1] => 1:dims_pairs[1][2])]

    for (k, dim) in dims_pairs[2:end]
        k_range = comp_pairs[end][2][end] .+ (1:dim)
        push!(comp_pairs, k => k_range)
    end

    # add states and controls to dims

    dim_states = sum([dim for (k, dim) in dims_pairs if k ∉ controls])
    dim_controls = sum([dim for (k, dim) in dims_pairs if k ∈ controls])

    push!(dims_pairs, :states => dim_states)
    push!(dims_pairs, :controls => dim_controls)

    # add states and controls to components

    comp_tuple = NamedTuple(comp_pairs)

    states_comps = vcat([comp_tuple[k] for k ∈ keys(comp_data) if k ∉ controls]...)
    controls_comps = vcat([comp_tuple[k] for k ∈ keys(comp_data) if k ∈ controls]...)

    push!(comp_pairs, :states => states_comps)
    push!(comp_pairs, :controls => controls_comps)

    dims = NamedTuple(dims_pairs)
    comps = NamedTuple(comp_pairs)

    names = Tuple(keys(comp_data))

    return NamedTrajectory(
        data,
        datavec,
        T,
        timestep,
        dynamical_timesteps,
        dim,
        dims,
        bounds,
        initial,
        final,
        goal,
        comps,
        names,
        controls
    )
end


function NamedTrajectory(
    datavec::AbstractVector{Float64},
    T::Int,
    components::NamedTuple{
        names,
        <:Tuple{Vararg{AbstractVector{Int}}}
    } where names;
    timestep::Union{Nothing, Float64}=nothing,
    dynamical_timesteps::Bool=false,
    controls::Union{Symbol, Tuple{Vararg{Symbol}}}=(),
    bounds=(;),
    initial=(;),
    final=(;),
    goal=(;),
)
    controls = (controls isa Symbol) ? (controls,) : controls

    @assert !isempty(controls) "must specify at least one control"
    @assert !isnothing(timestep) "must specify a time step size"

    @assert all([k ∈ keys(components) for k ∈ controls])
    @assert all([k ∈ keys(components) for k ∈ keys(initial)])
    @assert all([k ∈ keys(components) for k ∈ keys(final)])
    @assert all([k ∈ keys(components) for k ∈ keys(goal)])

    @assert all([k ∈ keys(components) for k ∈ keys(bounds)])
    @assert all([
        (bound isa AbstractVector{<:Real}) ||
        (bound isa BoundType)
        for bound ∈ bounds
    ])

    bounds_dict = Dict(pairs(bounds))
    for (name, bound) ∈ bounds_dict
        if bound isa AbstractVector
            bounds_dict[name] = (-bound, bound)
        end
    end
    bounds = NamedTuple(bounds_dict)

    data = reshape(view(datavec, :), :, T)
    dim = size(data, 1)

    @assert all([isa(components[k], AbstractVector{Int}) for k in keys(components)])
    @assert vcat([components[k] for k in keys(components)]...) == 1:dim

    dim_pairs = [(k => length(components[k])) for k in keys(components)]

    dim_states = sum([dim for (k, dim) ∈ dim_pairs if k ∉ controls])
    dim_controls = sum([dim for (k, dim) ∈ dim_pairs if k ∈ controls])

    push!(dim_pairs, :states => dim_states)
    push!(dim_pairs, :controls => dim_controls)

    dims = NamedTuple(dim_pairs)

    @assert all([length(bounds[k][1]) == dims[k] for k in keys(bounds)])
    @assert all([length(initial[k]) == dims[k] for k in keys(initial)])
    @assert all([length(final[k]) == dims[k] for k in keys(final)])
    @assert all([length(goal[k]) == dims[k] for k in keys(goal)])

    names = Tuple(keys(components))

    return NamedTrajectory(
        data,
        datavec,
        T,
        timestep,
        dynamical_timesteps,
        dim,
        dims,
        bounds,
        initial,
        final,
        goal,
        components,
        names,
        controls
    )
end

function NamedTrajectory(
    datavec::AbstractVector{Float64},
    Z::NamedTrajectory
)
    @assert length(datavec) == length(Z.datavec)

    data = reshape(view(datavec, :), :, Z.T)

    return NamedTrajectory(
        data,
        datavec,
        Z.T,
        Z.timestep,
        Z.dynamical_timesteps,
        Z.dim,
        Z.dims,
        Z.bounds,
        Z.initial,
        Z.final,
        Z.goal,
        Z.components,
        Z.names,
        Z.controls_names
    )
end

function NamedTrajectory(
    data::AbstractMatrix{Float64},
    components::NamedTuple{
        names,
        <:Tuple{Vararg{AbstractVector{Int}}}
    } where names;
    kwargs...
)
    T = size(data, 2)
    datavec = vec(data)
    return NamedTrajectory(datavec, T, components; kwargs...)
end


struct KnotPoint
    t::Int
    data::AbstractVector{Float64}
    components::NamedTuple{
        cnames, <:Tuple{Vararg{AbstractVector{Int}}}
    } where cnames
    names::Tuple{Vararg{Symbol}}
    controls_names::Tuple{Vararg{Symbol}}
end

function KnotPoint(
    Z::NamedTrajectory,
    t::Int
)
    @assert 1 ≤ t ≤ Z.T
    data = view(Z.data, :, t)
    return KnotPoint(t, data, Z.components, Z.names, Z.controls_names)
end

end
