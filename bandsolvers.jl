import BandedMatrices as BM
using SparseArrays: sparse
using KrylovKit: eigsolve

"""
Calculate `n_bands` energy bands of Hamiltonian (S32) sweeping over the adiabatic `phases` (Ïâ in (S32)).
In the returned matrix of bands, columns enumerate the adiabatic phases, while rows enumerate eigenvalues.
Rows `1:n_bands` store the eigenvalues corresponding to the centre of BZ, ð = 0.
Rows `n_bands:end` store the eigenvalues corresponding to the boundary of BZ, in our case Î»âAâcos(sÏ+Ïâ) leads to ð = s/2.
"""
function compute_secular_bands(; n_bands::Integer, phases::AbstractVector, s::Integer, M::Real, Î»âAâ::Real, Î»âAâ::Real)
    n_j = 2n_bands # number of indices ð to use for constructing the Hamiltonian (its size will be (2n_j+1)Ã(2n_j+1))
    
    # Hamiltonian matrix
    H = BM.BandedMatrix{ComplexF64}(undef, (2n_j + 1, 2n_j + 1), (2, 2))
    H[BM.band(-2)] .= Î»âAâ
    H[BM.band(2)]  .= Î»âAâ
    
    bands = Matrix{Float64}(undef, 2n_bands, length(phases))
    for k in [0, sÃ·2] # iterate over the centre of BZ and then the boundary
        H[BM.band(0)] .= [(2j + k)^2 / M for j = -n_j:n_j]
        # `a` and `b` control where to place the eigenvalues depedning on `k`; see function docstring
        a = (k > 0)*n_bands + 1 
        b = a+n_bands - 1
        for (i, Ï) in enumerate(phases)
            H[BM.band(-1)] .= Î»âAâ*cis(-Ï)
            H[BM.band(1)]  .= Î»âAâ*cis(Ï)
            vals, _, _ = eigsolve(H, n_bands, :LR; krylovdim=n_bands+10)
            bands[a:b, i] .= vals[1:n_bands]
        end
    end
    return bands / 2 # restore the omitted factor
end

"""
Calculate energy bands of the Floquet Hamiltonian (S20) sweeping over the adiabatic `phases` Ïâ. It is assumed that 2Ïâ = Ïâ.
Energy levels of the unperturbed Hamiltonian ââ from `2n_min` to `2n_max` will be used for constructing the Floquet Hamiltonian.
The values `n_min` to `n_max` thus correspond to the energy level numbers of a single well.
Return a tuple of a matrix `Ïµâ` of `4În` bands of ââ and a matrix `Eâ` of `În` bands of ð»â, where `În = n_max - n_min + 1`.
In the returned matrices, columns enumerate the adiabatic phases, while rows enumerate eigenvalues.
In `Eâ`, rows `1:În` store the eigenvalues corresponding to the centre of BZ, ð = 0.
In `Eâ`, rows `În:end` store the eigenvalues corresponding to the boundary of BZ, in our case VâcosÂ²(x+Ïâ) leads to ð = 2/2 = 1.
The structure of `Ïµâ` is the same, but with `2În` instead of `În`.
Type of pumping is controlled via `pumptype`: `:time` for temporal, `:space` for spatial, or anything else for simultaneous space-time pumping.
Note that if `pumptype==:time`, ââ is diagonalised only once (as the spatial phase is constant), hence only the first column of `Ïµâ` is populated.
"""
function compute_floquet_bands(; n_min::Integer, n_max::Integer, phases::AbstractVector, s::Integer, l::Real, gâ::Real, Vâ::Real, Î»â::Real, Î»â::Real, Ï::Real, pumptype::Symbol)
    n_j = 2n_max # number of indices ð to use for constructing ââ (its size will be (2n_j+1)Ã(2n_j+1)). `2n_max` is a safe value, but it could be less.
    În = n_max - n_min + 1

    hâ = BM.BandedMatrix(BM.Zeros{ComplexF64}(2n_j+1, 2n_j+1), (2l, 2l))
    # fill the off-diagonals with binomial numbers; the diagonal is treated in the `k` loop
    for n in 1:l
        hâ[BM.band(2n)] .= hâ[BM.band(-2n)] .= gâ / 4^l * binomial(2l, l-n)
    end
    
    # Eigenvalues of ââ (eigenenergies of the unperturbed Hamiltonian).
    # We should store `2În` of them because each of the `În` levels are almost degenerate. To account for the two values of ð, we use `4În`.
    Ïµâ = Matrix{Float64}(undef, 4În, length(phases))
    câ = [Vector{ComplexF64}(undef, 2n_j+1) for _ in 1:2În]  # eigenvectors of ââ, we will save `2În` of them (only for a single ð), and each will have `2n_j+1` components
    
    Eâ = Matrix{Float64}(undef, 2În, length(phases)) # eigenvalues of ð»â (Floquet quasi-energies) that will be saved; size is twice `În` for the two values of ð
    Hâ_dim = 2În # dimension of the constructed ð»â matrix (twice larger than the number of requested quasi-energies)
    n_Hâ_nonzeros = 9Hâ_dim - 24s # number of non-zero elements in ð»â
    Hâ_rows = Vector{Int}(undef, n_Hâ_nonzeros)
    Hâ_cols = Vector{Int}(undef, n_Hâ_nonzeros)
    Hâ_vals = Vector{ComplexF64}(undef, n_Hâ_nonzeros)
    for k in [0, 1] # iterate over the centre of BZ and then the boundary
        hâ[BM.band(0)] .= [(2j + k)^2 + Vâ/2 + gâ / 4^l * binomial(2l, l) for j = -n_j:n_j]
        # `a_*` and `b_*` control where to place the eigenvalues of ð»â and ââ depedning on `k`; see function docstring
        a_hâ = (k > 0)*2În + 1 # `(k > 0)` is zero for BZ centre (when `k == 0`) and unity otherwise
        b_hâ = a_hâ+2În - 1
        a_Hâ = (k > 0)*În + 1 # `(k > 0)` is zero for BZ centre (when `k == 0`) and unity otherwise
        b_Hâ = a_Hâ+În - 1
        for (z, Ï) in enumerate(phases)
            if pumptype != :time || z == 1 # If pupming is not time-only, ââ has to be diagonalised on each iteration. If it's time-only, then we diagonalise only once, at `z == 1`.
                hâ[BM.band(-1)] .= Vâ/4 * cis(2Ï)
                hâ[BM.band(1)]  .= Vâ/4 * cis(-2Ï)
                vals, vecs, info = eigsolve(hâ, 2n_max, :SR; krylovdim=2n_j+1)
                if info.converged < 2n_max
                    @warn "Only $(info.converged) eigenvalues out of $(2n_max) converged when diagonalising ââ. "*
                          "Results may be inaccurate." unconverged_norms=info.normres[info.converged+1:end]
                end
                # save only energies and states for levels from `2n_min` to `2n_max`
                Ïµâ[a_hâ:b_hâ, z] = vals[2n_min-1:2n_max]
                câ .= vecs[2n_min-1:2n_max]
            end

            # Construct ð»â
            p = 1 # a counter for placing elements to the vectors `Hâ_*`
            for m in 1:Hâ_dim
                # place the diagonal element (S25)
                Hâ_rows[p] = Hâ_cols[p] = m
                q = (pumptype == :time ? 1 : z) # If pumping is time-only, `Ïµâ[m, z]` is only calculated for `z == 1` (during diagonalisation of ââ)
                Hâ_vals[p] = Ïµâ[m, q] - ceil(m/2)*Ï/s
                p += 1

                # place the elements of the long lattice (S26)
                for i in 1:2
                    mâ² = 2s + 2(ceil(Int, m/2)-1) + i
                    mâ² > Hâ_dim && break
                    Hâ_rows[p] = mâ²
                    Hâ_cols[p] = m
                    if pumptype != :time || z == 1 # If pumping is time-only, this may be calculated only once
                        j_sum = sum( (câ[mâ²][j+2]/4 + câ[mâ²][j-2]/4 + câ[mâ²][j]/2)' * câ[m][j] for j = 3:2n_j-1 ) + 
                                     (câ[mâ²][3]/4 + câ[mâ²][1]/2)' * câ[m][1] +                # iteration j = 1
                                     (câ[mâ²][2n_j-1]/4 + câ[mâ²][2n_j+1]/2)' * câ[m][2n_j+1]   # iteration j = 2n_j+1
                        Hâ_vals[p] = (pumptype == :space ? Î»â/2 * j_sum : Î»â/2 * j_sum * cis(-2Ï)) # a check for space or space-time pumping
                    elseif pumptype == :time 
                        Hâ_vals[p] *= cis(-2(phases[2]-phases[1]))
                    end
                    p += 1
                    # place the conjugate element
                    Hâ_rows[p] = m
                    Hâ_cols[p] = mâ²
                    Hâ_vals[p] = Hâ_vals[p-1]'
                    p += 1
                end
                
                # place the elements of the short lattice (S29)
                for i in 1:2
                    mâ² = 4s + 2(ceil(Int, m/2)-1) + i
                    mâ² > Hâ_dim && break
                    Hâ_rows[p] = mâ²
                    Hâ_cols[p] = m
                    if pumptype != :time || z == 1 # If pumping is time-only, this may be calculated only once
                        j_sum = sum( (-câ[mâ²][j+2]/4 - câ[mâ²][j-2]/4 + câ[mâ²][j]/2)' * câ[m][j] for j = 3:2n_j-1 ) + 
                                     (-câ[mâ²][3]/4 + câ[mâ²][1]/2)' * câ[m][1] +                # iteration j = 1
                                     (-câ[mâ²][2n_j-1]/4 + câ[mâ²][2n_j+1]/2)' * câ[m][2n_j+1]   # iteration j = 2n_j+1
                        Hâ_vals[p] = Î»â/2 * j_sum
                    end
                    p += 1
                    # place the conjugate element
                    Hâ_rows[p] = m
                    Hâ_cols[p] = mâ²
                    Hâ_vals[p] = Hâ_vals[p-1]'
                    p += 1
                end
            end
            Hâ = sparse(Hâ_rows, Hâ_cols, Hâ_vals)
            vals, _, info = eigsolve(Hâ, În, :LR; krylovdim=Hâ_dim)
            if info.converged < În
                @warn "Only $(info.converged) eigenvalues out of $(În) converged when diagonalising ð»â. "*
                      "Results may be inaccurate." unconverged_norms=info.normres[info.converged+1:end]
            end
            Eâ[a_Hâ:b_Hâ, z] .= vals[1:În]
        end
    end
    return Ïµâ, Eâ
end