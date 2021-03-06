using Plots, LaTeXStrings
using SpecialFunctions: gamma
using Combinatorics: factorial, binomial
pyplot()
plotlyjs()
theme(:dark, size=(700, 600))

### Calculate the spatial Hamiltonian as a function of the action, and compute the associated derivatives

include("SpacetimeHamiltonian.jl")

function π»β(p, x, params)
    p^2 + params[1]*cos(2x)^(2params[2]) + params[3]*cos(x)^2
end

function π»(p, x, params, t)
    p^2 + params[1]*cos(2x)^(2params[2]) + params[3]*cos(x)^2 +
    params[4]*sin(2x)^2*cos(2params[6]*t) + 
    params[5]*cos(2x)^2*cos(params[6]*t)
end

function πβ(p::Real, x::Real)
    sin(2x)^2
end

function πβ(p::Real, x::Real)
    cos(2x)^2
end

g = 6000; l = 1;
gβ = 2g*factorial(l) / βΟ / gamma(l + 0.5)
Vβ = 20

Ξ»β = 200; Ξ»β = 75; Ο = 391
s = 2
params = [gβ, l, Vβ, Ξ»β, Ξ»β, Ο]
H = SpacetimeHamiltonian(π»β, π», params, s, (0.8, 1.1), (1.2, 1.8), 0.001)

function plot_actions(H::SpacetimeHamiltonian)
    figs = [plot() for _ in 1:4];
    x = range(0, Ο, length=200);
    figs[1] = plot(x, H.π, xlabel=L"x", ylabel=L"U(x)=\tilde{g}_\ell\cos^{2\ell}(2x)+V_L\cos^{2}(x)", legend=false);
    title!(L"\ell = %$l, g = %$g, V_L = %$Vβ");
    I = Dierckx.get_knots(H.πΈ)
    figs[2] = plot(I, H.πΈ(I), xlabel=L"I", ylabel=L"E", legend=false);
    figs[3] = plot(I, H.πΈβ², xlabel=L"I", ylabel=L"dE/dI", legend=false);
    figs[4] = plot(I, H.πΈβ³, xlabel=L"I", ylabel=L"d^2E/dI^2", legend=false, ylims=(-30, 30));
    lay = @layout [a{0.5w} grid(3,1)]
    plot(figs..., layout=lay)
end

plot_actions(H)
savefig("h_0-parameters.pdf")

### Make a plot of the motion in the (πΌ, Ο) phase-space in the secular approximation

function plot_isoenergies(; Ο, M, Ξ»β, Aβ, Οβ, Ξ»β, Aβ, Οβ, Iβ, s, I_min)
    Ο = range(0, 2Ο, length=50)
    I_max = last(Dierckx.get_knots(H.πΈ))
    I = range(I_min, I_max, length=50)
    E = Matrix{Float64}(undef, length(Ο), length(I))
    hβ = H.πΈ(Iβ) - Ο/s*Iβ
    for i in eachindex(I), t in eachindex(Ο)
        E[t, i] = hβ + (I[i]-Iβ)^2/2M + Ξ»β*Aβ*cos(2s*Ο[t] + Οβ) + Ξ»β*Aβ*cos(s*Ο[t] + Οβ)
    end
    contour(Ο, I, E', xlabel=L"\Theta"*", rad", ylabel=L"I", cbartitle="Energy \$H\$ (S17)", color=:viridis, minorgrid=true, minorticks=5)
    hline!([Iβ], label=L"I_s = %$(round(Iβ, sigdigits=4))", c=:white)
    title!(L"\omega = %$Ο, s = %$s, M = %$(round(M, sigdigits=2))"*"\n"*
           L"\lambda_L = %$Ξ»β, A_L = %$(round(Aβ, sigdigits=2)), \chi_L = %$(round(Οβ, sigdigits=2)),"*"\n"*
           L"\lambda_S = %$Ξ»β, A_S = %$(round(Aβ, sigdigits=2)), \chi_S = %$(round(Οβ, sigdigits=2))")
end

Iβ, M, coeffs = compute_parameters(H, Function[πβ, πβ], [-2s, -s])

Aβ = abs(coeffs[1]); Οβ = angle(coeffs[1])
Οβ = 0.0
eQ = cis(Οβ)*coeffs[2]
Aβ = abs(eQ); Οβ = angle(eQ)

I_min = 22
plot_isoenergies(; Ο, M, Ξ»β=Ξ»β, Aβ, Οβ, Ξ»β=Ξ»β, Aβ, Οβ, Iβ, s, I_min)
savefig("secular-isoenergies.pdf")

### Make an "exact" plot of the motion in the (πΌ, Ο) phase-space

fig = plot();
for i in 22:0.5:28
    I, Ξ = compute_IΞ(H, i, n_T=150, Οβ=0.0)
    scatter!(Ξ, I, xlabel=L"\theta, rad", ylabel=L"I", markerstrokewidth=0, markeralpha=0.6, label=false, minorgrid=true, minorticks=5)
end
for i in 22:0.5:28
    I, Ξ = compute_IΞ(H, i, n_T=150, Οβ=0.75)
    scatter!(Ξ, I, xlabel=L"\theta, rad", ylabel=L"I", markerstrokewidth=0, markeralpha=0.6, label=false, minorgrid=true, minorticks=5)
end
ylims!((I_min, last(Dierckx.get_knots(H.πΈ))))
title!(L"\ell = %$l, g = %$g, V_L = %$Vβ, \lambda_S = %$Ξ»β, \lambda_L = %$Ξ»β, \omega = %$Ο")
savefig(fig, "exact-isoenergies.pdf")

### Calculate secular bands

include("bandsolvers.jl")

phases = range(0, Ο, length=51) # values of the adiabatic phase in (S32)
n_bands = 2
bands = compute_secular_bands(; n_bands, phases, s, M, Ξ»βAβ=Ξ»β*Aβ, Ξ»βAβ=Ξ»β*Aβ) .+ H.πΈ(Iβ) .- Ο/s*Iβ

fig2 = plot();
for i in 1:n_bands
    plot!(phases, bands[i, :], fillrange=bands[n_bands+i, :], fillalpha=0.35, label="band $i");
end
xlabel!(L"\varphi_t"*", rad"); ylabel!("Energy of quantised secular "*L"H"*" (S17)")
title!(L"\omega = %$Ο, \lambda_L = %$Ξ»β, \lambda_S = %$Ξ»β")
savefig("semiclassical-bands.pdf")

### Extract tight-binding parameters

function tb_parameters(E_0_0, E_0_pi)
    Jβ = E_0_pi / 2
    Ξ = β(E_0_0^2 - 4Jβ^2)
    return Jβ, Ξ
end

gap = bands[1, 1] - bands[2, 1]
w = bands[1, 1] - gap/2

Jβ, Ξ = tb_parameters(gap/2, bands[1, endΓ·2]-w)
E0 = @. sqrt(Ξ^2*cos(phases)^2 + 4Jβ^2)
title!("Fit patameters: "*L"\Delta = %$(round(Ξ, sigdigits=3)), J_0 = %$(round(Jβ, sigdigits=3)), w = %$(round(w, sigdigits=3))")
plot!(phases, E0 .+ w, c=:white, label=L"\pm\sqrt{\Delta^{2}\cos^{2}\varphi_t+4J_{0}^{2}}+w", legend=:bottomright, lw=0.5)
plot!(phases, -E0 .+ w, c=:white, label=false, lw=0.5)

### Calculate Floquet bands

phases = range(0, Ο, length=51) # values of the adiabatic phase in (S32)
n_min = 15
n_max = 30
n_bands = n_max-n_min+1
eβ, Eβ = compute_floquet_bands(;n_min, n_max, phases, s, l, gβ, Vβ=Vβ, Ξ»β=Ξ»β, Ξ»β=Ξ»β, Ο=Ο, pumptype=:spacetime)

fig1 = plot();
for i in 1:n_bands
    plot!(phases, Eβ[i, :], fillrange=Eβ[n_bands+i, :], fillalpha=0.3, label=false)
end
xlabel!(L"2\varphi_t=\varphi_x"*", rad"); ylabel!("Floquet quasi-energy "*L"\varepsilon_{k,m}")
title!("2D pumping. "*L"\ell = %$l, g = %$g, V_L = %$Vβ, \lambda_S = %$Ξ»β, \lambda_L = %$Ξ»β, \omega = %$Ο")
savefig("pumping-both.pdf")
ylims!((4895, 4945))

b = 1
# spatial fit
gap = Eβ[b, 1] - Eβ[b+2, 1] |> abs
w = Eβ[b, 1] - gap/2 |> abs
Jβ, Ξ = tb_parameters(Eβ[b, endΓ·4]-w, gap/2)
E0 = @. sqrt(Ξ^2*sin(2phases)^2 + 4Jβ^2)
plot!(phases, E0 .+ w, c=:white, label=L"\pm\sqrt{\Delta^{2}\sin^{2}2\varphi_x+4J_{0}^{2}}+w", legend=:bottomright, lw=0.5)
# temporal fit
gap = Eβ[b, 1] - Eβ[b+5, 1] |> abs
w = Eβ[b, 1] - gap/2 |> abs
Jβ, Ξ = tb_parameters(gap/2, Eβ[b, endΓ·4]-w)
E0 = @. sqrt(Ξ^2*cos(2phases)^2 + 4Jβ^2)
plot!(phases, E0 .+ w, c=:white, label=L"\pm\sqrt{\Delta^{2}\cos^{2}\varphi_t+4J_{0}^{2}}+w", legend=:bottomright, lw=0.5)

plot!(phases, -E0 .+ w, c=:white, label=false, lw=0.5)
title!("Space pumping. Parameters: "*L"\Delta = %$(round(Ξ, sigdigits=3)), J_0 = %$(round(Jβ, sigdigits=3)), w = %$(round(-w, sigdigits=3))")
savefig("pumping-space.pdf")

fig2 = plot();
x = range(0, Ο, length=200)
plot!(x, x -> π»β(0, x, params), lw=2, c=:white, label=false) # Spatial potential
for i in 1:2n_bands
    plot!(phases, eβ[i, :], fillrange=eβ[2n_bands+i, :], fillalpha=0.3, label="band $i")
end
title!("Energy spectrum of "*L"h_k"*" (S21)")
ylims!((7750, 8500))
xlabel!(L"\varphi_x"*", rad"); ylabel!("Eigenenergy "*L"\epsilon_{k,m}"*" of "*L"h_k"*" (S21)")
savefig("h_k-spectrum.pdf")

b = 3
shift = abs(Eβ[b, 1] - bands[1, 1])
plot!(phases, bands[1, :].-shift, fillrange=bands[2+1, :].-shift, fillalpha=0.3, label="semiclassical bands 1 and 2", c=:white)
plot!(phases, bands[2, :].-shift, fillrange=bands[2+2, :].-shift, fillalpha=0.3, label=false, c=:white)
title!("Pumping in time, comparison with semiclassical result")
savefig("floquet-vs-semiclassical-2.pdf")
findfirst(<(-1390), Eβ[1:end, 1])
plot(phases, Eβ[19, :])

### Plot band Minkowski sums

function make_silhouettes(energies, bandnumbers, n_sils)
    simple_bands = Matrix{Float64}(undef, 2n_sils, size(energies, 2))
    n = size(energies, 1) Γ· 2
    for i in 1:n_sils
        simple_bands[i, :] .= max.(energies[bandnumbers[i], :], energies[n+bandnumbers[i], :])
        simple_bands[n_sils+i, :] .= min.(energies[bandnumbers[n_sils+i], :], energies[n+bandnumbers[n_sils+i], :])
    end
    return simple_bands
end

relevant_bands = 1 .+ [0, 2, 1, 5]
relevant_bands = 1 .+ [2, 6, 5, 7]
n_sils = length(relevant_bands) Γ· 2
spacebands = make_silhouettes(Eβ, relevant_bands, n_sils)

fig1 = plot();
for i in 1:n_sils
    plot!(phases, spacebands[i, :], fillrange=spacebands[n_sils+i, :], fillalpha=0.3, label=false)
end
xlabel!(L"2\varphi_t=\varphi_x"*", rad"); ylabel!("Floquet quasi-energy "*L"\varepsilon_{k,m}")
title!("2D spacetime bands")
savefig("2D-bands.pdf")

function sum_bands(bands)
    n = size(bands, 1)Γ·2        # number of input bands
    N = round(Int, (n+1)*nΓ·2)   # number of output bands
    summed = Matrix{Float64}(undef, 2N, size(bands, 2))
    i = 1
    for b1 in 1:n
        for b2 in b1:n
            summed[i, :] = bands[b1, :].+bands[b2, :]
            summed[i+N, :] = bands[b1+n, :].+bands[b2+n, :]
            i += 1 
        end
    end
    summed
end

function plot_summed_bands(bands)
    n = size(bands, 1) Γ· 2
    fig = plot()
    for i in 1:n
        plot!(phases, bands[i, :], fillrange=bands[i+n, :], fillalpha=0.3, label=false)
        hline!([maximum(bands[i, :]), minimum(bands[i+n, :])], c=:white, label=false)
    end
    return fig
end

su = sum_bands(spacebands)
sr = sum_bands(su)
fig = plot_summed_bands(sr)
xlabel!(L"2\varphi_t=\varphi_x"*", rad"); ylabel!("Floquet quasi-energy "*L"\varepsilon_{k,m}")
title!("6D spacetime bands")
ylims!((19720, 19753))
savefig("6D-bands.pdf")