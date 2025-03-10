module TracerAdvectionDiffusion

export
  Problem,
  set_c!,
  updatevars!,
  OneDAdvectingFlow,
  TwoDAdvectingFlow, 
  ThreeDAdvectingFlow

using
  CUDA,
  DocStringExtensions,
  Reexport

@reexport using FourierFlows, GeophysicalFlows.MultiLayerQG

using GeophysicalFlows.MultiLayerQG: SingleLayerParams, TwoLayerParams, numberoflayers

import LinearAlgebra: mul!, ldiv!
import GeophysicalFlows.MultiLayerQG

# --
# AdvectingFlows
# --

"Abstract super type for an advecting flow."
abstract type AbstractAdvectingFlow end

noflow(args...) = 0.0 # used as defaults for u, v, w functions in AdvectingFlow constructors

"""
    struct OneDAdvectingFlow <: AbstractAdvectingFlow

A container for the advecting flow of a one dimensional `TracerAdvectionDiffusion.Problem`.
Includes:

$(TYPEDFIELDS)
"""
struct OneDAdvectingFlow <: AbstractAdvectingFlow
  "function for the ``x``-component of the advecting flow"
           u :: Function
  "boolean declaring whether or not the flow is steady (i.e., not time dependent)"
  steadyflow :: Bool
end

"""
    OneDAdvectingFlow(; u=noflow, steadyflow=true)

Return a `OneDAdvectingFlow`. By default, there is no advecting flow `u=noflow` hence 
`steadyflow=true`.    
"""
OneDAdvectingFlow(; u=noflow, steadyflow=true) = OneDAdvectingFlow(u, steadyflow)

"""
    struct TwoDAdvectingFlow <: AbstractAdvectingFlow

A container for the advecting flow of a two dimensional `TracerAdvectionDiffusion.Problem`.
Includes:

$(TYPEDFIELDS)
"""
struct TwoDAdvectingFlow <: AbstractAdvectingFlow
  "function for the ``x``-component of the advecting flow"
           u :: Function
  "function for the ``y``-component of the advecting flow"
           v :: Function
  "boolean declaring whether or not the flow is steady (i.e., not time dependent)"
  steadyflow :: Bool
end

"""
    TwoDAdvectingFlow(; u=noflow, v=noflow, steadyflow=true)

Return a `TwoDAdvectingFlow`. By default, there is no advecting flow `u=noflow` and `v=noflow` hence 
`steadyflow=true`.     
"""
TwoDAdvectingFlow(; u=noflow, v=noflow, steadyflow=true) = TwoDAdvectingFlow(u, v, steadyflow)

"""
    struct ThreeDAdvectingFlow <: AbstractAdvectingFlow

A container for the advecting flow of a three dimensional `TracerAdvectionDiffusion.Problem`.
Includes:

$(TYPEDFIELDS)
"""
struct ThreeDAdvectingFlow <: AbstractAdvectingFlow
  "function for the ``x``-component of the advecting flow"
           u :: Function
  "function for the ``y``-component of the advecting flow"
           v :: Function
  "function for the ``z``-component of the advecting flow"
           w :: Function
  "boolean declaring whether or not the flow is steady (i.e., not time dependent)"
  steadyflow :: Bool
end

"""
    ThreeDAdvectingFlow(; u=noflow, v=noflow, w=noflow, steadyflow=true)

Return a `ThreeDAdvectingFlow`. By default, there is no advecting flow `u=noflow`, `v=noflow`, and `w=noflow`
hence `steadyflow=true`.    
"""
ThreeDAdvectingFlow(; u=noflow, v=noflow, w=noflow, steadyflow=true) = ThreeDAdvectingFlow(u, v, w, steadyflow)

# --
# Problems
# --

"""
    Problem(dev::Device=CPU(), advecting_flow; parameters...)

Construct a constant diffusivity problem with steady or time-varying `advecting_flow` on device `dev`.
The default device is the `CPU()`, to use the `GPU` pass the argument to the function
The dimensionality of the problem is inferred from the type of `advecting_flow` provided:
* `advecting_flow::OneDAdvectingFlow` for 1D advection-diffusion problem,
* `advecting_flow::TwoDAdvectingFlow` for 2D advection-diffusion problem,
* `advecting_flow::ThreeDAdvectingFlow` for 3D advection-diffusion problem.
"""
function Problem(dev::Device, advecting_flow::OneDAdvectingFlow;
                     nx = 128,
                     Lx = 2π,
                      κ = 0.1,
                     dt = 0.01,
                stepper = "RK4",
                      T = Float64
                 )

  grid = OneDGrid(dev; nx, Lx, T)
  
  params = advecting_flow.steadyflow==true ?
           ConstDiffSteadyFlowParams(κ, advecting_flow.u, grid::OneDGrid) :
           ConstDiffTimeVaryingFlowParams(κ, advecting_flow.u)

  vars = Vars(grid)

  equation = Equation(params, grid)

  return FourierFlows.Problem(equation, stepper, dt, grid, vars, params)
end

function Problem(dev::Device, advecting_flow::TwoDAdvectingFlow;
                     nx = 128,
                     Lx = 2π,
                     ny = nx,
                     Ly = Lx,
                      κ = 0.1,
                      η = κ,
                     dt = 0.01,
                stepper = "RK4",
                      T = Float64
                 )
  
  grid = TwoDGrid(dev; nx, Lx, ny, Ly, T)

  params = advecting_flow.steadyflow==true ?
           ConstDiffSteadyFlowParams(κ, η, advecting_flow.u, advecting_flow.v, grid::TwoDGrid) :
           ConstDiffTimeVaryingFlowParams(κ, η, advecting_flow.u, advecting_flow.v)

  vars = Vars(grid)

  equation = Equation(params, grid)

  return FourierFlows.Problem(equation, stepper, dt, grid, vars, params)
end

function Problem(dev::Device, advecting_flow::ThreeDAdvectingFlow;
                    nx = 128,
                    Lx = 2π,
                    ny = nx,
                    Ly = Lx,
                    nz = nx,
                    Lz = Lx,
                    κ = 0.1,
                    η = κ,
                    ι = κ,
                    dt = 0.01,
                stepper = "RK4",
                    T = Float64
                 )

  grid = ThreeDGrid(dev; nx, Lx, ny, Ly, nz, Lz, T)

  params = advecting_flow.steadyflow==true ?
           ConstDiffSteadyFlowParams(κ, η, ι, advecting_flow.u, advecting_flow.v, advecting_flow.w, grid::ThreeDGrid) :
           ConstDiffTimeVaryingFlowParams(κ, η, ι, advecting_flow.u, advecting_flow.v, advecting_flow.w)

  vars = Vars(grid)

  equation = Equation(params, grid)

  return FourierFlows.Problem(equation, stepper, dt, grid, vars, params)
end

"""
    Problem(dev::Device=CPU(), MQGprob::FourierFlows.Problem; parameters...)

Construct a constant diffusivity problem on device `dev` using the flow from a
`GeophysicalFlows.MultiLayerQG` problem as the advecting flow. The device `CPU()`
is set as the default device.
"""
function Problem(MQGprob::FourierFlows.Problem;
                     κ = 0.1,
                     η = κ,
               stepper = "FilteredRK4",
   tracer_release_time = 0
                 )

  grid = MQGprob.grid

  tracer_release_time < 0 && throw(ArgumentError("tracer_release_time must be non-negative!"))

  if tracer_release_time > 0
    @info "Stepping the flow forward until t = tracer_release_time = $tracer_release_time"
    step_until!(MQGprob, tracer_release_time)
  end

  params = ConstDiffTurbulentFlowParams(κ, η, tracer_release_time, MQGprob)

  vars = Vars(grid, MQGprob)

  equation = Equation(params, grid)

  dt = MQGprob.clock.dt

  return FourierFlows.Problem(equation, stepper, dt, grid, vars, params)
end

# --
# Params
# --

abstract type AbstractTimeVaryingFlowParams <: AbstractParams end
abstract type AbstractSteadyFlowParams <: AbstractParams end
abstract type AbstractTurbulentFlowParams <: AbstractParams end

"""
    struct ConstDiffTimeVaryingFlowParams1D{T} <: AbstractTimeVaryingFlowParams

The parameters of a constant diffusivity problem with time-varying flow in one
dimension.

$(TYPEDFIELDS)
"""
struct ConstDiffTimeVaryingFlowParams1D{T} <: AbstractTimeVaryingFlowParams
  "diffusivity coefficient"
      κ :: T
  "hyperdiffusivity coefficient"
     κh :: T
  "hyperdiffusivity order"  
    nκh :: Int
  "function returning the ``x``-component of advecting flow"
      u :: Function
end

"""
    struct ConstDiffTimeVaryingFlowParams2D{T} <: AbstractTimeVaryingFlowParams

The parameters of a constant diffusivity problem with time-varying flow in two
dimensions.

$(TYPEDFIELDS)
"""
struct ConstDiffTimeVaryingFlowParams2D{T} <: AbstractTimeVaryingFlowParams
  "``x``-diffusivity coefficient"
      κ :: T
  "``y``-diffusivity coefficient"
      η :: T
  "isotropic hyperdiffusivity coefficient"
     κh :: T
  "isotropic hyperdiffusivity order"  
    nκh :: Int
  "function returning the ``x``-component of advecting flow"
      u :: Function
  "function returning the ``y``-component of advecting flow"
      v :: Function
end

"""
    struct ConstDiffTimeVaryingFlowParams3D{T} <: AbstractTimeVaryingFlowParams

The parameters of a constant diffusivity problem with time-varying flow in three
dimensions.

$(TYPEDFIELDS)
"""
struct ConstDiffTimeVaryingFlowParams3D{T} <: AbstractTimeVaryingFlowParams
  "``x``-diffusivity coefficient"
      κ :: T
  "``y``-diffusivity coefficient"
      η :: T
  "``z``-diffusivity coefficient"
      ι :: T
  "isotropic hyperdiffusivity coefficient"
     κh :: T
  "isotropic hyperdiffusivity order"  
    nκh :: Int
  "function returning the ``x``-component of advecting flow"
      u :: Function
  "function returning the ``y``-component of advecting flow"
      v :: Function
  "function returning the ``z``-component of advecting flow"
      w :: Function
end

"""
    ConstDiffTimeVaryingFlowParams(κ, u)

Return the parameters `params` for a constant diffusivity problem with a 1D time-varying flow.
"""
ConstDiffTimeVaryingFlowParams(κ, u) = ConstDiffTimeVaryingFlowParams1D(κ, 0κ, 0, u)

"""
    ConstDiffTimeVaryingFlowParams(κ, η, u, v)

Return the parameters `params` for a constant diffusivity problem with a 2D time-varying flow.
"""
ConstDiffTimeVaryingFlowParams(κ, η, u, v) = ConstDiffTimeVaryingFlowParams2D(κ, η, 0κ, 0, u, v)

"""
    ConstDiffTimeVaryingFlowParams(κ, η, ι, u, v, w)

Return the parameters `params` for a constant diffusivity problem with a 3D time-varying flow.
"""
ConstDiffTimeVaryingFlowParams(κ, η, ι, u, v, w) = ConstDiffTimeVaryingFlowParams3D(κ, η, ι, 0κ, 0, u, v, w)

"""
    struct ConstDiffSteadyFlowParams1D{T} <: AbstractSteadyFlowParams

The parameters of a constant diffusivity problem with steady flow in one dimension.

$(TYPEDFIELDS)
"""
struct ConstDiffSteadyFlowParams1D{T, A} <: AbstractSteadyFlowParams
  "``x``-diffusivity coefficient"
     κ :: T
  "isotropic hyperdiffusivity coefficient"
    κh :: T
  "isotropic hyperdiffusivity order"  
   nκh :: Int
  "``x``-component of advecting flow"
     u :: A
end

"""
    struct ConstDiffSteadyFlowParams2D{T} <: AbstractSteadyFlowParams

The parameters for a constant diffusivity problem with steady flow in two dimensions.

$(TYPEDFIELDS)
"""
struct ConstDiffSteadyFlowParams2D{T, A} <: AbstractSteadyFlowParams
  "``x``-diffusivity coefficient"
     κ :: T
  "``y``-diffusivity coefficient"
     η :: T
  "isotropic hyperdiffusivity coefficient"
    κh :: T
  "isotropic hyperdiffusivity order"  
   nκh :: Int
   "``x``-component of advecting flow"
     u :: A
   "``y``-component of advecting flow"
     v :: A
end

"""
    struct ConstDiffSteadyFlowParams3D{T} <: AbstractSteadyFlowParams

The parameters for a constant diffusivity problem with steady flow in three dimensions.

$(TYPEDFIELDS)
"""
struct ConstDiffSteadyFlowParams3D{T, A} <: AbstractSteadyFlowParams
  "``x``-diffusivity coefficient"
     κ :: T
  "``y``-diffusivity coefficient"
     η :: T
  "``z``-diffusivity coefficient"
     ι :: T
  "isotropic hyperdiffusivity coefficient"
    κh :: T
  "isotropic hyperdiffusivity order"  
   nκh :: Int
   "``x``-component of advecting flow"
     u :: A
   "``y``-component of advecting flow"
     v :: A
   "``z``-component of advecting flow"
     w :: A
end

"""
    ConstDiffSteadyFlowParams(κ, κh, nκh, u::Function, grid::OneDGrid)
    ConstDiffSteadyFlowParams(κ, u, grid::OneDGrid)
    ConstDiffSteadyFlowParams(κ, η, κh, nκh, u::Function, v::Function, grid::TwoDGrid)
    ConstDiffSteadyFlowParams(κ, η, u, v, grid::TwoDGrid)
    ConstDiffSteadyFlowParams(κ, η, ι, κh, nκh, u::Function, v::Function, w::Function, grid::ThreeDGrid)
    ConstDiffSteadyFlowParams(κ, η, ι, u, v, w, grid::ThreeDGrid)

Return the parameters `params` for a constant diffusivity problem with a steady flow in 1D, 2D or 3D. 
"""
function ConstDiffSteadyFlowParams(κ, κh, nκh, u::Function, grid::OneDGrid)
  x = gridpoints(grid)
  ugrid = u.(x)
  
  return ConstDiffSteadyFlowParams1D(κ, κh, nκh, ugrid)
end
 
 ConstDiffSteadyFlowParams(κ, u, grid::OneDGrid) =
  ConstDiffSteadyFlowParams(κ, 0κ, 0, u, grid)

function ConstDiffSteadyFlowParams(κ, η, κh, nκh, u::Function, v::Function, grid::TwoDGrid)
  x, y = gridpoints(grid)

  return ConstDiffSteadyFlowParams2D(κ, η, κh, nκh, u.(x, y), v.(x, y))
end

ConstDiffSteadyFlowParams(κ, η, u, v, grid::TwoDGrid) =
  ConstDiffSteadyFlowParams(κ, η, 0κ, 0, u, v, grid)

function ConstDiffSteadyFlowParams(κ, η, ι, κh, nκh, u::Function, v::Function, w::Function, grid::ThreeDGrid)
  x, y, z = gridpoints(grid)
   
  return ConstDiffSteadyFlowParams3D(κ, η, ι, κh, nκh, u.(x, y, z), v.(x, y, z), w.(x, y, z))
 end
 
 ConstDiffSteadyFlowParams(κ, η, ι, u, v, w, grid::ThreeDGrid) =
  ConstDiffSteadyFlowParams(κ, η, ι, 0κ, 0, u, v, w, grid)

"""
    struct ConstDiffTurbulentFlowParams{T} <: AbstractTurbulentFlowParams

The parameters of a constant diffusivity problem with flow obtained from a
`GeophysicalFlows.MultiLayerQG` problem.

$(TYPEDFIELDS)
"""
struct ConstDiffTurbulentFlowParams{T} <: AbstractTurbulentFlowParams
  "``x``-diffusivity coefficient"
                    κ :: T
  "``y``-diffusivity coefficient"
                    η :: T
  "isotropic hyperdiffusivity coefficient"
                   κh :: T
  "isotropic hyperdiffusivity order"  
                  nκh :: Int
  "number of layers in which the tracer is advected-diffused"
              nlayers :: Int 
  "flow time prior to releasing tracer"
  tracer_release_time :: T
  "`MultiLayerQG.Problem` to generate the advecting flow"
              MQGprob :: FourierFlows.Problem            
end

"""
    ConstDiffTurbulentFlowParams(κ, η, tracer_release_time, MQGprob)

Return the parameters `params` for a constant diffusivity problem with flow obtained
from a `GeophysicalFlows.MultiLayerQG` problem.
"""
function ConstDiffTurbulentFlowParams(κ, η, tracer_release_time, MQGprob)
  nlayers = numberoflayers(MQGprob.params)
  
  MultiLayerQG.updatevars!(MQGprob)

  return ConstDiffTurbulentFlowParams(κ, η, 0κ, 0, nlayers, tracer_release_time, MQGprob)
end

# --
# Equations
# --

"""
    Equation(dev, params, grid)

Return the equation for constant diffusivity problem with `params` and `grid` on device `dev`.
"""
function Equation(params::ConstDiffTimeVaryingFlowParams1D, grid::OneDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr))
  @. L = - params.κ * grid.kr^2 - params.κh * (grid.kr^2)^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffTimeVaryingFlowParams2D, grid::TwoDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr, grid.nl))
  @. L = - params.κ * grid.kr^2 - params.η * grid.l^2 - params.κh * grid.Krsq^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffTimeVaryingFlowParams3D, grid::ThreeDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr, grid.nl, grid.nm))
  @. L = - params.κ * grid.kr^2 - params.η * grid.l^2 - params.ι * grid.m^2 - params.κh * grid.Krsq^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffSteadyFlowParams1D, grid::OneDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr))
  @. L = - params.κ * grid.kr^2 - params.κh * (grid.kr^2)^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffSteadyFlowParams2D, grid::TwoDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr, grid.nl))
  @. L = - params.κ * grid.kr^2 - params.η * grid.l^2 - params.κh * grid.Krsq^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffSteadyFlowParams3D, grid::ThreeDGrid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr, grid.nl, grid.nm))
  @. L = - params.κ * grid.kr^2 - params.η * grid.l^2 - params.ι * grid.m^2 - params.κh * grid.Krsq^params.nκh

  return FourierFlows.Equation(L, calcN!, grid)
end

function Equation(params::ConstDiffTurbulentFlowParams, grid)
  dev = grid.device

  L = zeros(dev, eltype(grid), (grid.nkr, grid.nl, params.nlayers))

  for j in 1:params.nlayers
      @. L[:, :, j] = - params.κ * grid.kr^2 - params.η * grid.l^2 - params.κh * grid.Krsq^params.nκh
  end

  return FourierFlows.Equation(L, calcN!, grid)
end

# --
# Vars
# --

"""
    struct Vars1D{Aphys, Atrans} <: AbstractVars

The variables of a 1D `TracerAdvectionDiffussion` problem.

$(FIELDS)
"""
struct Vars1D{Aphys, Atrans} <: AbstractVars
  "tracer concentration"
      c :: Aphys
  "tracer concentration ``x``-derivative, ``∂c/∂x``"
     cx :: Aphys
  "Fourier transform of tracer concentration"
     ch :: Atrans
  "Fourier transform of tracer concentration ``x``-derivative, ``∂c/∂x``"
    cxh :: Atrans
end

"""
    struct Vars2D{Aphys, Atrans} <: AbstractVars

The variables of a 2D `TracerAdvectionDiffussion` problem.

$(FIELDS)
"""
struct Vars2D{Aphys, Atrans} <: AbstractVars
  "tracer concentration"
      c :: Aphys
  "tracer concentration ``x``-derivative, ``∂c/∂x``"
     cx :: Aphys
  "tracer concentration ``y``-derivative, ``∂c/∂y``"
     cy :: Aphys
  "Fourier transform of tracer concentration"
     ch :: Atrans
  "Fourier transform of tracer concentration ``x``-derivative, ``∂c/∂x``"
    cxh :: Atrans
  "Fourier transform of tracer concentration ``y``-derivative, ``∂c/∂y``"
    cyh :: Atrans
end

"""
    struct Vars3D{Aphys, Atrans} <: AbstractVars

The variables of a 3D `TracerAdvectionDiffussion` problem.

$(FIELDS)
"""
struct Vars3D{Aphys, Atrans} <: AbstractVars
  "tracer concentration"
      c :: Aphys
  "tracer concentration ``x``-derivative, ``∂c/∂x``"
     cx :: Aphys
  "tracer concentration ``y``-derivative, ``∂c/∂y``"
     cy :: Aphys
  "tracer concentration ``z``-derivative, ``∂c/∂z``"
     cz :: Aphys
  "Fourier transform of tracer concentration"
     ch :: Atrans
  "Fourier transform of tracer concentration ``x``-derivative, ``∂c/∂x``"
    cxh :: Atrans
  "Fourier transform of tracer concentration ``y``-derivative, ``∂c/∂y``"
    cyh :: Atrans
    "Fourier transform of tracer concentration ``z``-derivative, ``∂c/∂z``"
    czh :: Atrans
end

"""
    Vars(dev, grid; T=Float64) 

Return the variables `vars` for a constant diffusivity problem on `grid` and device `dev`.
"""
function Vars(grid::OneDGrid{T}) where T
  Dev = typeof(grid.device)

  @devzeros Dev T (grid.nx) c cx
  @devzeros Dev Complex{T} (grid.nkr) ch cxh
    
  return Vars1D(c, cx, ch, cxh)
end

function Vars(grid::TwoDGrid{T}) where T
  Dev = typeof(grid.device)

  @devzeros Dev T (grid.nx, grid.ny) c cx cy
  @devzeros Dev Complex{T} (grid.nkr, grid.nl) ch cxh cyh
  
  return Vars2D(c, cx, cy, ch, cxh, cyh)
end

function Vars(grid::ThreeDGrid{T}) where T
  Dev = typeof(grid.device)

  @devzeros Dev T (grid.nx, grid.ny, grid.nz) c cx cy cz
  @devzeros Dev Complex{T} (grid.nkr, grid.nl, grid.nm) ch cxh cyh czh
    
  return Vars3D(c, cx, cy, cz, ch, cxh, cyh, czh)
end

function Vars(grid::AbstractGrid{T}, MQGprob::FourierFlows.Problem) where T
  nlayers = numberoflayers(MQGprob.params)

  if nlayers == 1
    return Vars(grid)
  else
    Dev = typeof(grid.device)

    @devzeros Dev T (grid.nx, grid.ny, nlayers) c cx cy
    @devzeros Dev Complex{T} (grid.nkr, grid.nl, nlayers) ch cxh cyh

    return Vars2D(c, cx, cy, ch, cxh, cyh)
  end
end



# --
# Solvers
# --
"""
    calcN!(N, sol, t, clock, vars, params, grid)

Calculate the advective terms for a constant diffusivity `problem` with `params` and on `grid`.
"""
function calcN!(N, sol, t, clock, vars, params::AbstractTimeVaryingFlowParams, grid::OneDGrid)
  @. vars.cxh = im * grid.kr * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u(grid.x, clock.t) * vars.cx

  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractTimeVaryingFlowParams, grid::TwoDGrid)
  @. vars.cxh = im * grid.kr * sol
  @. vars.cyh = im * grid.l  * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw
  ldiv!(vars.cy, grid.rfftplan, vars.cyh) # destroys vars.cyh when using fftw

  x, y = gridpoints(grid)

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u(x, y, clock.t) * vars.cx - params.v(x, y, clock.t) * vars.cy

  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractTimeVaryingFlowParams, grid::ThreeDGrid)
  @. vars.cxh = im * grid.kr * sol
  @. vars.cyh = im * grid.l  * sol
  @. vars.czh = im * grid.m  * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw
  ldiv!(vars.cy, grid.rfftplan, vars.cyh) # destroys vars.cyh when using fftw
  ldiv!(vars.cz, grid.rfftplan, vars.czh) # destroys vars.czh when using fftw

  x, y, z = gridpoints(grid)

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u(x, y, z, clock.t) * vars.cx - params.v(x, y, z, clock.t) * vars.cy - params.w(x, y, z, clock.t) * vars.cz

  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractSteadyFlowParams, grid::OneDGrid)
  @. vars.cxh = im * grid.kr * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u * vars.cx
  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractSteadyFlowParams, grid::TwoDGrid)
  @. vars.cxh = im * grid.kr * sol
  @. vars.cyh = im * grid.l  * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw
  ldiv!(vars.cy, grid.rfftplan, vars.cyh) # destroys vars.cyh when using fftw

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u * vars.cx - params.v * vars.cy

  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractSteadyFlowParams, grid::ThreeDGrid)
  @. vars.cxh = im * grid.kr * sol
  @. vars.cyh = im * grid.l  * sol
  @. vars.czh = im * grid.m  * sol

  ldiv!(vars.cx, grid.rfftplan, vars.cxh) # destroys vars.cxh when using fftw
  ldiv!(vars.cy, grid.rfftplan, vars.cyh) # destroys vars.cyh when using fftw
  ldiv!(vars.cz, grid.rfftplan, vars.czh) # destroys vars.cyh when using fftw

  # store N (in physical space) into vars.cx
  @. vars.cx = - params.u * vars.cx - params.v * vars.cy - params.w * vars.cz

  mul!(N, grid.rfftplan, vars.cx)
  
  return nothing
end

function calcN!(N, sol, t, clock, vars, params::AbstractTurbulentFlowParams, grid)
  @. vars.cxh = im * grid.kr * sol
  @. vars.cyh = im * grid.l  * sol

  invtransform!(vars.cx, vars.cxh, params.MQGprob.params)
  invtransform!(vars.cy, vars.cyh, params.MQGprob.params)

  u = @. params.MQGprob.vars.u + params.MQGprob.params.U
  v = params.MQGprob.vars.v

  # store N (in physical space) into vars.cx
  @. vars.cx = - u * vars.cx - v * vars.cy
  
  fwdtransform!(N, vars.cx, params.MQGprob.params)

  return nothing
end

# --
# Helper functions
# --

"""
    updatevars!(prob)

Update the `prob.vars` in problem `prob` using the solution `prob.sol`.
"""
function updatevars!(params, vars, grid, sol)
  @. vars.ch = sol
  
  ldiv!(vars.c, grid.rfftplan, deepcopy(vars.ch))
  
  return nothing
end

"""
    updatevars!(params::AbstractTurbulentFlowParams, vars, grid, sol)

Update the `vars` on the `grid` with the solution in `sol` for a problem `prob`
that is being advected by a turbulent flow.     
"""
function updatevars!(params::AbstractTurbulentFlowParams, vars, grid, sol)  
  @. vars.ch = sol
  
  invtransform!(vars.c, deepcopy(vars.ch), params.MQGprob.params)

  return nothing
end

updatevars!(prob) = updatevars!(prob.params, prob.vars, prob.grid, prob.sol)

"""
    set_c!(sol, params::Union{AbstractTimeVaryingFlowParams, AbstractSteadyFlowParams}, grid, c)

Set the solution `sol` as the transform of `c` and update variables `vars`.
"""
function set_c!(sol, params::Union{AbstractTimeVaryingFlowParams, AbstractSteadyFlowParams}, vars, grid, c)
  dev = grid.device

  mul!(sol, grid.rfftplan, device_array(dev)(c))

  updatevars!(params, vars, grid, sol)
  
  return nothing
end

"""
    set_c!(sol, params::AbstractTurbulentFlowParams, grid, c)

Set the initial condition for tracer concentration in all layers of a
`TracerAdvectionDiffusion.Problem` that uses a `MultiLayerQG` flow to 
advect the tracer.
"""
function set_c!(sol, params::AbstractTurbulentFlowParams, vars, grid, c)
  nlayers = numberoflayers(params.MQGprob.params)
  dev = grid.device
  
  C = @CUDA.allowscalar repeat(device_array(dev)(c), 1, 1, nlayers)
  fwdtransform!(sol, C, params.MQGprob.params)
  updatevars!(params, vars, grid, sol)

  return nothing
end

set_c!(prob, c) = set_c!(prob.sol, prob.params, prob.vars, prob.grid, c)

end # module
