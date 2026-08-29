using Test

include(joinpath(@__DIR__, "..", "src", "BatchReactorDemo.jl"))
using .BatchReactorDemo

@testset "Fictional batch-reactor verification" begin
    params = ModelParams()
    result = simulate(params; t_end_s = 1800.0, dt_s = 1.0)
    metrics = calculate_metrics(result, params)

    @test metrics.mass_balance_max_abs_error_mol_m3 < 1e-8
    @test metrics.minimum_concentration_A_mol_m3 >= 0.0
    @test metrics.minimum_concentration_B_mol_m3 >= 0.0
    @test 0.0 <= metrics.final_conversion <= 1.0

    no_reaction = ModelParams(
        k_ref_per_s = 0.0,
        initial_temperature_K = 330.0,
        jacket_temperature_K = 300.0,
        UA_W_K = 1000.0,
    )
    cooling_result = simulate(no_reaction; t_end_s = 2400.0, dt_s = 1.0)
    @test isapprox(cooling_result.concentration_A_mol_m3[end],
                   no_reaction.initial_concentration_A_mol_m3; atol = 1e-10)
    @test isapprox(cooling_result.temperature_K[end], no_reaction.jacket_temperature_K; atol = 0.001)
end

