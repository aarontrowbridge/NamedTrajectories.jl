module Utils

export save
export load_traj
export derivative
export integral

using JLD2
using ..Types

function JLD2.save(filename::String, traj::NamedTrajectory)
    @assert split(filename, ".")[end] == "jld2"
    save(filename, "traj", traj)
end

function load_traj(filename::String)
    @assert split(filename, ".")[end] == "jld2"
    return load(filename, "traj")
end

function derivative(X::AbstractMatrix, Δt::AbstractVector)
    dX = similar(X)
    dxs[:, 1] = zeros(size(X, 1))
    for t = axes(X, 2)
        Δx = X[:, t] - X[:, t - 1]
        Δt = Δt[t]
        dX[:, t] .= Δx / Δt
    end
    return dX
end

function integral(X::AbstractMatrix, Δt::AbstractVector)
    ∫X = similar(X)
    ∫X[:, 1] = X[:, 1] * Δt[1]
    for t = axes(X, 2)
        Δt = Δt[t]
        ∫X[:, t] = ∫X[:, t - 1] + X[:, t] * Δt
    end
    return ∫X
end


end
