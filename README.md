# NamedTrajectories.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://aarontrowbridge.github.io/NamedTrajectories.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://aarontrowbridge.github.io/NamedTrajectories.jl/dev/)
[![Build Status](https://github.com/aarontrowbridge/NamedTrajectories.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/aarontrowbridge/NamedTrajectories.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/aarontrowbridge/NamedTrajectories.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/aarontrowbridge/NamedTrajectories.jl)

**NamedTrajectories.jl** is a package for working with trajectories of named variables. It is designed to be used with [Pico.jl](https://github.com/aarontrowbridge/Pico.jl) and [IterativeLearningControl.jl](https://github.com/aarontrowbridge/IterativeLearningControl.jl).

## Notice!

This package is under active development and issues may arise -- please be patient and report any issues you find!

## Installation

NamedTrajectories.jl is now registered! Instal with

```julia
using Pkg
Pkg.add(NamedTrajectories)
```


## Usage

Users can define `NamedTrajectory` types which have lots of useful functionality. For example, you can access the data by name or index.  In the case of an index, a `TimeSlice` is returned which contains the data for that timestep.

```julia
using NamedTrajectories

# define number of timesteps and timestep
T = 10
dt = 0.1

# build named tuple of components and data matrices
components = (
    x = rand(3, T),
    u = rand(2, T),
)

# build trajectory
traj = NamedTrajectory(components; dt=dt, controls=:u)

# access data by name
traj.x # returns 3x10 matrix of x data
traj.u # returns 2x10 matrix of u data

z1 = traj[1] # returns TimeSlice with x and u data

z1.x # returns 3x1 matrix of x data
z1.u # returns 2x1 matrix of u data

traj.data # returns data as 5x10 matrix
traj.names # returns names as tuple (:x, :u)

# simple build in plotting
plot(traj)
```

This script generates the following plot as demonstrated in [demo.ipynb](examples/notebooks/demo.ipynb)
![](examples/notebooks/demo.png)


## Plotting

See plotting function in [plotting.jl](src/plotting.jl) for more details.

Documentation coming soon!
