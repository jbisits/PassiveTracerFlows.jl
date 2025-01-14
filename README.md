# PassiveTracerFlows.jl

<!-- Badges -->
<p align="left">
    <a href="https://buildkite.com/julialang/passivetracerflows-dot-jl">
        <img alt="Buildkite CPU+GPU build status" src="https://img.shields.io/buildkite/4d921fc17b95341ea5477fb62df0e6d9364b61b154e050a123/main?logo=buildkite&label=Buildkite%20CPU%2BGPU">
    </a>
    <a href="https://ci.appveyor.com/project/navidcy/passivetracerflows-jl">
        <img alt="Build Status for Window" src="https://img.shields.io/appveyor/ci/navidcy/passivetracerflows-jl/main?label=Window&logo=appveyor&logoColor=white&style=flat-square">
    </a>
    <a href="https://FourierFlows.github.io/PassiveTracerFlowsDocumentation/stable">
        <img alt="stable docs" src="https://img.shields.io/badge/documentation-stable%20release-blue">
    </a>
    <a href="https://FourierFlows.github.io/PassiveTracerFlowsDocumentation/dev">
        <img alt="latest docs" src="https://img.shields.io/badge/documentation-in%20development-orange">
    </a>
    <a href="https://codecov.io/gh/FourierFlows/PassiveTracerFlows.jl">
        <img src="https://codecov.io/gh/FourierFlows/PassiveTracerFlows.jl/branch/main/graph/badge.svg" title="codecov">
    </a>
    <a href="https://doi.org/10.5281/zenodo.2535983">
        <img src="https://zenodo.org/badge/DOI/10.5281/zenodo.2535983.svg" alt="DOI">
    </a>
    <a href="https://github.com/SciML/ColPrac">
      <img alt="ColPrac: Contributor's Guide on Collaborative Practices for Community Packages" src="https://img.shields.io/badge/ColPrac-Contributor's%20Guide-blueviolet">
    </a>
 </p>

This package leverages the [FourierFlows.jl]() framework to provide modules for solving passive tracer advection-diffusion problems on periodic domains using Fourier-based pseudospectral methods.

## Installation

To install, use Julia's  built-in package manager (accessed by pressing `]` in the Julia REPL command prompt) to add the package and also to instantiate/build all the required dependencies

```julia
julia>]
(v1.6) pkg> add PassiveTracerFlows
(v1.6) pkg> instantiate
```

The most recent version of PassiveTracerFlows.jl requires Julia v1.6 or later.

## Examples

See `examples/` for example scripts.

## Modules

* [`TracerAdvectionDiffusion`](https://fourierflows.github.io/PassiveTracerFlowsDocumentation/stable/modules/traceradvectiondiffusion/): advection-diffusion of a passive tracer in 1D, 2D, or 3D domains.


## Cite

The code is citable via [zenodo](https://zenodo.org). Please cite as:

> Navid C. Constantinou, Josef I. Bisits, and Gregory L. Wagner (2022). FourierFlows/PassiveTracerFlows.jl: PassiveTracerFlows v0.9.1 (Version v0.9.1). Zenodo. [https://doi.org/10.5281/zenodo.2535983](https://doi.org/10.5281/zenodo.2535983)

## Contributing

We are always excited to have more members in the contributors team of PassiveTracerFlows.jl! Any
contribution is welcome, no matter how big or small!

Let us know by [open an issue](https://github.com/FourierFlows/PassiveTracerFlows.jl/issues/new) 
or [start a discussion](https://github.com/FourierFlows/PassiveTracerFlows.jl/discussions/new) 
if you'd like to work on a new feature or implement a new module, if you're new to open-source 
and want to find a cool little project or issue to work on that fits your interests! We're more 
than happy to help along the way.


[FourierFlows.jl]: https://github.com/FourierFlows/FourierFlows.jl
