import Roots
import Optim
import Dierckx
import Elliptic
using QuadGK: quadgk
import DifferentialEquations as DiffEq
using DiffEqPhysics: HamiltonianProblem, DynamicalODEProblem

"A type representing a space-time Hamiltonian."
mutable struct SpacetimeHamiltonian
    π»β::Function    # free (unperturbed) Hamiltonian
    π»::Function     # full Hamiltonian, including time-dependent perturbation
    π::Function     # spatial potential
    left_tp::Tuple  # bracketing interval for the left turning point of the free motion
    right_tp::Tuple # bracketing interval for the right turning point of the free motion
    πΈ::Dierckx.Spline1D # energy at the given action, function πΈ(πΌ)
    πΈβ²::Function    # oscillation frequency at the given action, function πΈβ²(πΌ)
    πΈβ³::Function    # effective mass at the given action, function πΈβ³(πΌ)
    params::Vector{Float64} # a vector of parameters, will be shared among π»β and π»; the last element should contain external frequency
    s::Int  # resonance number
end

"""
Construct a `SpacetimeHamiltonian` object. `min_pos` and `max_pos` are the bracketing intervals for the minimum and the maximum
of the spatial potential. `turnpoint` is required if the potential is not symmetric, see [`turning_point_intervals`](@ref).
"""
function SpacetimeHamiltonian(π»β::Function, π»::Function, params::AbstractVector, s::Integer,
                              min_pos::Tuple{<:Real, <:Real}, max_pos::Tuple{<:Real, <:Real}, turnpoint::Union{Real, Nothing}=nothing)
    π = x -> π»β(0.0, x, params)
    left_tp, right_tp = turning_point_intervals(π, min_pos, max_pos, turnpoint)
    πΈ, πΈβ², πΈβ³ = make_action_functions(π, left_tp, right_tp)
    SpacetimeHamiltonian(π»β, π», π, left_tp, right_tp, πΈ, πΈβ², πΈβ³, params, s)
end

"""
Return the possible intervals of the turning points for motion in the potential π. A minimum and a maximum of the potential will be found
using the bracketing intervals `min_pos` and `max_pos`. If the heights of the "walls" of the potential are not equal, a `turnpoint` has to be provided.
For example, if the left wall is higher than the right one, the left turning point will be searched for in the interval (`turnpoint`, `x_min`).
"""
function turning_point_intervals(π::Function, min_pos::Tuple{<:Real, <:Real}, max_pos::Tuple{<:Real, <:Real}, turnpoint::Union{Real, Nothing})
    # find position of the potential minimum
    result = Optim.optimize(x -> π(first(x)), min_pos[1], min_pos[2], Optim.Brent())
    x_min = Optim.minimizer(result)
    
    # find position of the potential maximum
    result = Optim.optimize(x -> -π(first(x)), max_pos[1], max_pos[2], Optim.Brent())
    x_max = Optim.minimizer(result)
    E_max = -Optim.minimum(result)

    if x_max > x_min # if the located maximum is to the right of the minimum
        right_tp = (x_min, x_max)
        # if the `turnpoint` is not provided, calculate the left turning point assuming a symmetric well; 
        # otherwise, find the coordinate of the point giving `E_max` on the left wall
        x_max_left = turnpoint === nothing ? x_min - (x_max - x_min) :
                                             Roots.find_zero(x -> π(x) - E_max, (turnpoint, x_min), Roots.A42(), xrtol=1e-3)
        left_tp = (x_max_left, x_min)
    else # if the located maximum is to the left of the minimum
        left_tp = (x_max, x_min)
        x_max_right = turnpoint === nothing ? x_min + (x_min - x_max) :
                                              Roots.find_zero(x -> π(x) - E_max, (x_min, turnpoint), Roots.A42(), xrtol=1e-3)
        right_tp = (x_min, x_max_right)
    end
    left_tp, right_tp
end

"Construct and return the functions πΈ(πΌ), πΈβ²(πΌ), and πΈβ³(πΌ)."
function make_action_functions(π::Function, left_tp::Tuple{<:Real, <:Real}, right_tp::Tuple{<:Real, <:Real})
    n_E = 100 # number of energies (and actions) to save
    I = Vector{Float64}(undef, n_E) # for storing values of the action variable
    E = range(1.001π(right_tp[1]), 0.999π(right_tp[2]), length=n_E) # energies inside the potential "well"

    for i in eachindex(E)
        x_min, x_max = turning_points(π, E[i], left_tp, right_tp)
        # calculate β«πdπ₯ for a half-period; the second half is the same, hence no division by 2
        I[i] = quadgk(x -> π(π, E[i], x), x_min, x_max, rtol=1e-4)[1] / Ο # `[1]` contains the integral, `[2]` contains error
    end
    
    πΈ  = Dierckx.Spline1D(I, E; k=2)      
    πΈβ² = x -> Dierckx.derivative(πΈ, x; nu=1)
    πΈβ³ = x -> Dierckx.derivative(πΈ, x; nu=2)
    return πΈ, πΈβ², πΈβ³
end

"""
Return the turning points of motion with the given energy `E`. The initial guesses `a` and `b` should be given as
tuples representing the bracketing intervals.
"""
function turning_points(π::Function, E::Real, a::Tuple{<:Real, <:Real}, b::Tuple{<:Real, <:Real})
    x_min = Roots.find_zero(x -> π(x) - E, a, atol=1e-2, Roots.A42())
    x_max = Roots.find_zero(x -> π(x) - E, b, atol=1e-2, Roots.A42())
    return x_min, x_max
end

"Momentum π(π₯) = β[πΈ - π(π₯)] of a particle of energy `E`."
function π(π::Function, E::Real, x::Real)
    p = E - π(x)
    p < 0 ? zero(p) : sqrt(p) # a safeguard for the case when `x` is slightly outside of the accessible region of oscillations
end

"""
Return action for the given energy `E` as the integral of momentum over a period of motion.
The turning points will be determined using the bracketing intervals `H.left_tp` and `H.right_tp`.
"""
function πΌ(H::SpacetimeHamiltonian, E::Real)
    x_min, x_max = turning_points(H.π, E, H.left_tp, H.right_tp)
    # calculate β«πdπ₯ for a half-period; the second half is the same, hence no division by 2
    return quadgk(x -> π(H.π, E, x), x_min, x_max, rtol=1e-4)[1] / Ο # `[1]` contains the integral, `[2]` contains error
end

"""
Return the action and mass at the working point. Also return the πth Fourier coefficient for every function in `perturbations`,
where the integer numbers π are specified in `m`. `perturbations` are the spatial functions that couple the temporal perturbations;
Their signature is `f(p, x) = ...`.
"""
function compute_parameters(H::SpacetimeHamiltonian, perturbations::Vector{Function}, m::Vector{<:Integer})
    Ο = H.params[end]
    Ξ© = Ο / H.s # our choice of the oscillation frequency (of the unperturbed system)
    Iβ::Float64 = Roots.find_zero(x -> H.πΈβ²(x) - Ξ©, 0.8last(Dierckx.get_knots(H.πΈ)), atol=1e-5) # find which πΌβ gives the frequency Ξ©
    Eβ::Float64 = H.πΈ(Iβ)     # energy of the system oscillating at the frequency Ξ©
    M::Float64 = 1 / H.πΈβ³(Iβ) # "mass" of the system oscillating at the frequency Ξ©
    # evolve the unperturbed system for one period 
    T = 2Ο / Ξ©
    tspan = (0.0, T)
    # initial conditions; they may be chosen arbitrary as long as the total energy equals `Eβ`
    xβ = H.right_tp[1]; pβ = π(H.π, Eβ, xβ); # we choose position at the minimum and calculate the momentum
    Hβ_problem = HamiltonianProblem(H.π»β, pβ, xβ, tspan, H.params)
    dt=2e-4
    # none of RKN solvers worked (https://docs.juliahub.com/DifferentialEquations/UQdwS/6.15.0/solvers/dynamical_solve/)
    sol = DiffEq.solve(Hβ_problem, DiffEq.McAte3(); dt) # McAte3 is more accurate than the automatically chosen Tsit5() 

    # calculate the requested Fourier coefficient for every function in `perturbations`
    coeffs = Vector{ComplexF64}(undef, length(perturbations))
    V = Vector{Float64}(undef, length(sol.t)) # for storing perturbation evaluated in the solution points
    for (i, π) in enumerate(perturbations)
        V .= π.(sol[1, :], sol[2, :])
        coeffs[i] = fourier_coeff(V, m[i], dt, T)
    end
    return Iβ, M, coeffs
end

"Calculate the `n`th Fourier coefficient of `f`. Simple trapezoid rule is used."
function fourier_coeff(f::AbstractVector, n::Int, dt::AbstractFloat, T::AbstractFloat)
    (sum(f[i] * cispi(2n*(i-1)*dt/T) for i = 2:length(f)-1) + (f[1] + f[end])/2) * dt/T
end

"""
Compute evolutions (using the perturbed Hamiltonian) of π(π‘) and π₯(π‘) for the energy corresponding to `I_target`, and the
initial phase `Οβ`. The latter should be specified in the units of 2Ο: 0 (the default) corresponds to π₯(0) in the potential minimum,
0.25 corresponds to the right turnin point, and 0.75 corresponds to the left turning point.
The pairs (π(π‘), π₯(π‘)) are registered stroboscopically at the intervals of the period of external driving; `n_T` pairs are registered.

Then, transform the obtained (π, π₯) pairs to (πΌ, Ο) and return the results as a tuple of two vectors.
Transformation is performed as follows: for each pair (πα΅’, π₯α΅’), the energy of the unperturbed motion is calculated as
πΈα΅’ = π»β(πα΅’, π₯α΅’), and the energy is then converted to action using the function πΌ(πΈ).
To find the phase Οα΅’, a period πα΅’ of unperturbed motion with energy πΈα΅’ is calculated, and the time moment π‘ corresponding to 
the pair (πα΅’, π₯α΅’) is found. The phase is then given by Οα΅’ = 2Οπ‘/πα΅’.
Note that some energy πΈβ±Ό may be such large (due to the perturbation) that the system is no longer confined to a single potential well. In that case,
no corresponding action πΌ(πΈβ±Ό) exists. This will happen if `I_target` is too large. In that case, an info message will be printed,
and energies starting with πΈβ±Ό will be ignored.
"""
function compute_IΞ(H::SpacetimeHamiltonian, I_target::Real; Οβ::AbstractFloat=0.0, n_T::Integer=100)
    Ο = H.params[end]
    T_external = 2Ο / Ο # period of the external driving
    tspan = (0.0, n_T * T_external)
    if Οβ == 0
        xβ = H.right_tp[1] # set iniital coordinate to the potential minimum (this position with positive momenutm defines the zero phase)
        pβ = π(H.π, H.πΈ(I_target), xβ)
    elseif Οβ == 0.25
        pβ = 0.0
        xβ = Roots.find_zero(x -> H.π»β(0, x, params) - H.πΈ(I_target), H.right_tp[2]) # set iniital coordinate to the right turning point
    else # if Οβ == 0.75
        pβ = 0.0
        xβ = Roots.find_zero(x -> H.π»β(0, x, params) - H.πΈ(I_target), H.left_tp[1]) # set iniital coordinate to the left turning point
    end
    H_problem = HamiltonianProblem(H.π», pβ, xβ, tspan, params)
    sol = DiffEq.solve(H_problem, DiffEq.KahanLi8(); dt=2e-4, saveat=T_external)
    p = sol[1, :]
    x = sol[2, :]
    
    # Calculate the energies that the free system would possess if it was at `x` with momenta `p`
    E = Float64[]
    sizehint!(E, length(sol.t))
    for (pα΅’, xα΅’) in zip(p, x)
        Eα΅’ = H.π»β(pα΅’, xα΅’, H.params)
        if Eα΅’ < H.π(H.left_tp[1])
            push!(E, Eα΅’)
        else # Interrupt if energy `Eα΅’` exceeds that of the barrier. All subsequent energies are of no interest then.
            @info "Perturbation deconfines the particle if it starts at action πΌ = $I_target."
            break
        end
    end

    I = map(x -> πΌ(H, x), E)

    # for all the equations below, the initial position is chosen to be the potential minimum
    xβ = H.right_tp[1]

    # find phases from the coordinates
    Ξ = similar(I)
    for i in eachindex(Ξ)
        T_free = 2Ο / H.πΈβ²(I[i]) # period of the unperturbed motion at action `I[i]`
        tspan = (0.0, T_free)
        pβ = π(H.π, E[i], xβ)
        Hβ_problem = HamiltonianProblem(H.π»β, pβ, xβ, tspan, H.params)
        sol = DiffEq.solve(Hβ_problem, DiffEq.McAte5(); dt=2e-4)

        # Find the time point when the equilibrium point xβ (i.e. the potential minimum) is reached.
        # The coordinate will be greater than xβ at times in (0; t_eq) and less than xβ at times in (t_eq; T_free).
        t_eq = Roots.find_zero(t -> sol(t)[2] - xβ, T_free/2)

        # If the coordinate `x[i]` is very close to potential minimum `xβ`, the momentum `p[i]` may lie just outside of the bracketing interval,
        # causing the root finding to fail. However, in that case `p[i]` is either very close to its maximum, meaning `t = 0`,
        # or is very close to the minimum, meaning `t = t_eq`. The two cases can be discerned by the sign of the momentum.
        if isapprox(x[i], xβ, atol=5e-3)
            t = p[i] > 0 ? 0.0 : t_eq
        else
            # use the sign of the coordinate to determine which part of the period the point (x[i]; p[i]) is in
            bracket = x[i] > xβ ? (0.0, t_eq) : (t_eq, T_free)
            # Find the time corresponding to momentum `p[i]`:
            f = t -> sol(t)[1] - p[i] # construct the to-be-minimised function
            # Check that `bracket` is indeed a bracketing interval. This might not be the case due to various inaccuracies.
            if prod(f.(bracket)) < 0
                t = Roots.find_zero(f, bracket, Roots.A42(), xrtol=1e-3)
            else # otherwise, use the midpoint of the `bracket` as a starting point.
                t = Roots.find_zero(f, (bracket[1]+bracket[2])/2) # Note that in this case the algorithm may occasionally converge to the zero in the wrong half of the period
            end
        end
        Ξ[i] = 2Ο * t / T_free # `-2Ο*(i-1)/H.s` is the -Οπ‘/π  term that transforms to the moving frame. We have π‘β = ππ, and Οπ‘β = 2Οπ
    end
    return I, Ξ
end