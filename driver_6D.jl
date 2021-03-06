# The driving script for the analysis of Hamiltonians (9) and (13) from arXiv:2012.02783

using Plots, LaTeXStrings
pyplot()
plotlyjs()
theme(:dark, size=(700, 600))

include("SpacetimeHamiltonian.jl")

function π»β(p, x, params)
    p^2 + params[1]*sin(x)^2
end

function π»(p, x, params, t)
    p^2 + params[1]*sin(x)^2 + p * params[2] * params[3] * sin(params[3]*t)
end

function π(p::Real, x::Real)
    p
end

Vβ = 4320.0; Ο = 240.0; Ξ» = 0.01;
s = 3
params = [Vβ, Ξ», Ο]
# plot(range(0, 2Ο, length=200), x -> π»β(0, x, params))
H = SpacetimeHamiltonian(π»β, π», params, s, (3.0, 3.2), (1.4, 1.6))

function plot_actions(H::SpacetimeHamiltonian)
    figs = [plot() for _ in 1:4];
    x = range(0, 2Ο, length=50);
    figs[1] = plot(x, H.π, xlabel=L"x", ylabel=L"U(x)=V_0\sin^{2}(x)", legend=false);
    # title!(L"V_0 = %$(round(Vβ, sigdigits=4))");
    I = Dierckx.get_knots(H.πΈ)
    figs[2] = plot(I, H.πΈ(I), xlabel=L"I", ylabel=L"E", legend=false);
    figs[3] = plot(I, H.πΈβ², xlabel=L"I", ylabel=L"dE/dI", xlims=(I[1], I[end]), legend=false);
    figs[4] = plot(I, H.πΈβ³, xlabel=L"I", ylabel=L"d^2E/dI^2", xlims=(I[1], I[end]), legend=false);
    lay = @layout [a{0.5w} grid(3,1)]
    plot(figs..., layout=lay)
end

plot_actions(H)
savefig("h_0-parameters.pdf")

### Make a plot of the motion in the (πΌ, Ο) phase-space in the secular approximation

Iβ, M, coeffs = compute_parameters(H, Function[π], [s])

function plot_isoenergies(; M, Ξ», Ο, pβ, Iβ, s)
    Ο = range(0, 2Ο, length=50)
    I_max = last(Dierckx.get_knots(H.πΈ))
    I = [0:2:30; range(30.5, I_max, length=20)]
    E = Matrix{Float64}(undef, length(Ο), length(I))
    for i in eachindex(I), t in eachindex(Ο)
        E[t, i] = (I[i]-Iβ)^2/2M - Ξ»*Ο*abs(pβ)*cos(s*Ο[t])
    end
    levels = [range(minimum(E), -20, length=20); range(-19, maximum(E), length=10)]
    contour(Ο, I, E', xlabel=L"\Theta"*", rad", ylabel=L"I", cbartitle="Energy \$H\$ (13)", color=:viridis; levels)
    hline!([Iβ], label=L"I_s = %$(round(Iβ, sigdigits=4))", c=:white)
    title!(L"\lambda = %$(round(Ξ», sigdigits=2))")
end

pβ = abs(coeffs[1])
plot_isoenergies(; pβ, M, Ξ», Ο, Iβ, s)
savefig("secular-isoenergies.pdf")

### Make an "exact" plot of the motion in the (πΌ, Ο) phase-space

fig = plot();
for i in [2:2:34; Iβ; 36:39]
    I, Ξ = compute_IΞ(H, i, n_T=200)
    scatter!(mod2pi.(Ξ.+pi/2), I, xlabel=L"\theta", ylabel=L"I", markerstrokewidth=0, markeralpha=0.6, label=false)
end
display(fig)
savefig("exact-isoenergies.pdf")