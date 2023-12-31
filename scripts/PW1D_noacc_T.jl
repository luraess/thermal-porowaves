using Plots, ElasticArrays, Printf

@views avx(A) = (A[1:end-1] .+ A[2:end]) .* 0.5

@views function main()
    # independent physics
    lc      = 1.0 #sqrt(k_r / ηf_r * η_r / ϕ_bg) # m
    Δρg     = 1.0 #(ρs - ρf) * g # Pa/m
    η_ϕbg   = 1.0 #η_r / ϕ_bg # Pa*s
    # scales
    psc     = Δρg * lc
    tsc     = η_ϕbg / psc
    # non-dimensional numbers
    lx_lc   = 100.0
    w_lc    = 5.0
    ϕ_bg    = 0.01
    ϕA      = 0.1
    npow    = 3
    T_bg    = 0.0
    TA      = 1.0
    # dependent physics
    lx      = lx_lc * lc
    w       = w_lc * lc
    k_ηf0   = lc^2 / η_ϕbg
    λ       = 1.0
    dt      = 1e-3 * tsc
    # numerics
    nx      = 200
    nt      = 50
    maxiter = 100nx
    ϵtol    = [1e-5 1.0]
    ncheck  = ceil(Int, 2nx)
    # preprocessing
    dx      = lx / nx
    xc      = LinRange(-lx / 2 - dx / 2, lx / 2 + dx / 2, nx)
    dτ_T    = dx^2 / λ / 3.1
    # init
    ϕ       = ϕ_bg .+ ϕA .* exp.(.-((xc .+ lx / 3) ./ w) .^ 2)
    T       = T_bg .+ TA .* exp.(.-((xc .+ lx / 3) ./ w) .^ 2)
    ϕ_i     = copy(ϕ)
    Pe      = zeros(nx)
    qD      = zeros(nx - 1)
    η_ϕ     = zeros(nx)
    k_ηf    = zeros(nx)
    RPe     = zeros(nx - 2)
    dτ_β    = zeros(nx - 2)
    qUx     = zeros(nx - 1)
    Vs      = zeros(nx - 1)
    RT      = zeros(nx - 2)
    Uf      = ones(nx)
    Us      = ones(nx)
    Ut_o    = (Uf .* ϕ + Us .* (1 .- ϕ))
    # action
    for it = 1:nt
        @printf("it = %d\n", it)
        iter = 1
        errs = 2.0 .* ϵtol
        errs_evo = ElasticArray{Float64}(undef, 2, 0)
        iters_evo = Float64[]
        while any(errs .> ϵtol) && iter <= maxiter
            # material properties
            η_ϕ  .= η_ϕbg .* (ϕ_bg ./ ϕ)
            k_ηf .= k_ηf0 .* (ϕ ./ ϕ_bg) .^ npow
            # update of physical fields
            qD   .= avx(k_ηf) .* (diff(Pe) ./ dx .+ Δρg)
            RPe  .= .-Pe[2:end-1] ./ η_ϕ[2:end-1] .+ diff(qD) ./ dx
            dτ_β .= dx^2 ./ k_ηf[2:end-1] ./ 3.1
            Pe[2:end-1] .+= RPe .* dτ_β
            # energy / temperature
            qUx  .= (avx(Uf) .* avx(ϕ) .* qD .+ avx(Us) .* (1 .- avx(ϕ)) .* Vs .- λ .* diff(T) ./ dx)
            RT   .= .-((Uf[2:end-1] .* ϕ[2:end-1] + Us[2:end-1] .* (1 .- ϕ[2:end-1])) .- Ut_o[2:end-1]) ./ dt .- diff(qUx) ./ dx
            T[2:end-1] .+= dτ_T .* RT
            if iter % ncheck == 0
                errs[1] = maximum(abs.(RPe))
                errs[2] = maximum(abs.(RT))
                append!(errs_evo, errs)
                push!(iters_evo, iter / nx)
                @printf("  iter = %d, iter/nx = %1.3e, err = [ %1.3e %1.3e ] \n", iter, iter / nx, errs...)
            end
            iter += 1
        end
        ϕ   .-= dt * (1 .- ϕ) .* Pe ./ η_ϕ
        cumsum!(Vs, .-Pe[2:end] ./ η_ϕ[2:end]) .* dx
        Ut_o .= (Uf .* ϕ + Us .* (1 .- ϕ))
        # visualisation
        p1 = plot([ϕ_i, ϕ], xc; title="Porosity", ylabel="depth", label=["Init" "φ"])
        p2 = plot(Pe, xc; title="Effective Pressure", label="Pe")
        p3 = plot(Vs, xc[2:end]; title="Vs", label="Vs")
        p4 = plot(T, xc; title="temperature", label="T")
        # p4 = plot(iters_evo, err_evo'; title="Residual evolution", yaxis=:log10, marker=:circle, xlabel="Iter/nx", label="RPe")
        display(plot(p1, p2, p3, p4; layout=(1, 4)))
    end
end

main()

# doc
# Pe = Pe + RPe./βf_dτ # explicit update
