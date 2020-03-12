module TracerAdvDiff

export
   Problem,
   set_c!,
   updatevars!

using
  FFTW,
  Reexport

@reexport using FourierFlows

import LinearAlgebra: mul!, ldiv!

# --
# Problems
# --

"""
    Problem(; parameters...)

Construct a constant diffusivity problem with steady or time-varying flow.
"""
noflow(args...) = 0.0 # used as defaults for u, v functions in Problem()

function Problem(;
          nx = 128,
          Lx = 2π,
          ny = nx,
          Ly = Lx,
         kap = 0.1,
         eta = kap,
           u = noflow,
           v = noflow,
          dt = 0.01,
     stepper = "RK4",
  steadyflow = false,
           T = Float64,
         dev = CPU()
  )
  
  gr = TwoDGrid(dev, nx, Lx, ny, Ly; T=T)
  pr = steadyflow==true ? ConstDiffSteadyFlowParams(eta, kap, u, v, gr) : ConstDiffParams(eta, kap, u, v)
  vs = Vars(dev, gr)
  eq = Equation(pr, gr)

  FourierFlows.Problem(eq, stepper, dt, gr, vs, pr, dev)
end


# --
# Params
# --

abstract type AbstractTracerParams <: AbstractParams end
abstract type AbstractConstDiffParams <: AbstractParams end
abstract type AbstractSteadyFlowParams <: AbstractParams end

"""
    ConstDiffParams(eta, kap, kaph, nkaph, u, v)
    ConstDiffParams(eta, kap, u, v)

Returns the params for constant diffusivity problem with time-varying flow.
"""
struct ConstDiffParams{T} <: AbstractConstDiffParams
  eta :: T           # Constant isotropic horizontal diffusivity
  kap :: T           # Constant isotropic vertical diffusivity
 kaph :: T           # Constant isotropic hyperdiffusivity
nkaph :: Int         # Constant isotropic hyperdiffusivity order
    u :: Function    # Advecting x-velocity
    v :: Function    # Advecting y-velocity
end
ConstDiffParams(eta, kap, u, v) = ConstDiffParams(eta, kap, 0eta, 0, u, v)

"""
    ConstDiffSteadyFlowParams(eta, kap, kaph, nkaph, u, v, g)
    ConstDiffSteadyFlowParams(eta, kap, u, v, g)

Returns the params for constant diffusivity problem with time-steady flow.
"""
struct ConstDiffSteadyFlowParams{T,A} <: AbstractSteadyFlowParams
  eta :: T           # Constant horizontal diffusivity
  kap :: T           # Constant vertical diffusivity
 kaph :: T           # Constant isotropic hyperdiffusivity
nkaph :: Int         # Constant isotropic hyperdiffusivity order
    u :: A           # Advecting x-velocity
    v :: A           # Advecting y-velocity
end

function ConstDiffSteadyFlowParams(eta, kap, kaph, nkaph, u::Function, v::Function, g)
   x, y = gridpoints(g)
  ugrid = u.(x, y)
  vgrid = v.(x, y)
  ConstDiffSteadyFlowParams(eta, kap, kaph, nkaph, ugrid, vgrid)
end

ConstDiffSteadyFlowParams(eta, kap, u, v, g) = ConstDiffSteadyFlowParams(eta, kap, 0eta, 0, u, v, g)


# --
# Equations
# --

"""
    Equation(p, g)

Returns the equation for constant diffusivity problem with params p and grid g.
"""
function Equation(p::ConstDiffParams, g::AbstractGrid{T}) where T
  L = @. -p.eta*g.kr^2 - p.kap*g.l^2 - p.kaph*g.Krsq^p.nkaph
  FourierFlows.Equation(L, calcN!, g)
end

function Equation(p::ConstDiffSteadyFlowParams, g::AbstractGrid{T}) where T
  L = @. -p.eta*g.kr^2 - p.kap*g.l^2 - p.kaph*g.Krsq^p.nkaph
  FourierFlows.Equation(L, calcN_steadyflow!, g)
end


# --
# Vars
# --

struct Vars{Aphys, Atrans} <: AbstractVars
    c :: Aphys
   cx :: Aphys
   cy :: Aphys
   ch :: Atrans
  cxh :: Atrans
  cyh :: Atrans
end

"""
    Vars(g)

Returns the vars for constant diffusivity problem on grid g.
"""
function Vars(::Dev, g::AbstractGrid{T}) where {Dev, T}
  @devzeros Dev T (g.nx, g.ny) c cx cy
  @devzeros Dev Complex{T} (g.nkr, g.nl) ch cxh cyh
  Vars(c, cx, cy, ch, cxh, cyh)
end



# --
# Solvers
# --

"""
    calcN!(N, sol, t, cl, v, p, g)

Calculate the advective terms for a tracer equation with constant diffusivity and time-varying flow.
"""
function calcN!(N, sol, t, cl, v, p::AbstractConstDiffParams, g)
  @. v.cxh = im*g.kr*sol
  @. v.cyh = im*g.l*sol

  ldiv!(v.cx, g.rfftplan, v.cxh) # destroys v.cxh when using fftw
  ldiv!(v.cy, g.rfftplan, v.cyh) # destroys v.cyh when using fftw

  x, y = gridpoints(g)
  @. v.cx = -p.u(x, y, cl.t)*v.cx - p.v(x, y, cl.t)*v.cy # copies over v.cx so v.cx = N in physical space
  mul!(N, g.rfftplan, v.cx)
  nothing
end


"""
    calcN_steadyflow!(N, sol, t, cl, v, p, g)

Calculate the advective terms for a tracer equation with constant diffusivity and time-constant flow.
"""
function calcN_steadyflow!(N, sol, t, cl, v, p::AbstractSteadyFlowParams, g)
  @. v.cxh = im*g.kr*sol
  @. v.cyh = im*g.l*sol

  ldiv!(v.cx, g.rfftplan, v.cxh) # destroys v.cxh when using fftw
  ldiv!(v.cy, g.rfftplan, v.cyh) # destroys v.cyh when using fftw

  @. v.cx = -p.u*v.cx - p.v*v.cy # copies over v.cx so v.cx = N in physical space
  mul!(N, g.rfftplan, v.cx)
  nothing
end


# --
# Helper functions
# --

"""
    updatevars!(prob)

Update the vars in v on the grid g with the solution in sol.
"""
function updatevars!(prob)
  v, g, sol = prob.vars, prob.grid, prob.sol
  v.ch .= sol
  ldiv!(v.c, g.rfftplan, deepcopy(v.ch))
  nothing
end

"""
    set_c!(prob, c)

Set the solution sol as the transform of c and update variables v
on the grid g.
"""
function set_c!(prob, c)
  sol, v, g = prob.sol, prob.vars, prob.grid

  mul!(sol, g.rfftplan, c)
  updatevars!(prob)
  nothing
end

end # module
