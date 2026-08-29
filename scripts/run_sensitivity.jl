if !isdefined(Main, :BatchReactorDemo)
    include(joinpath(@__DIR__, "..", "src", "BatchReactorDemo.jl"))
end
using .BatchReactorDemo
using TOML
using Printf

project_root_sensitivity() = normpath(joinpath(@__DIR__, ".."))

"""Sweep jacket-temperature offsets and save a small, auditable sensitivity study."""
function run_sensitivity(root::AbstractString = project_root_sensitivity())
    base_params, t_end_s, dt_s = load_parameters(joinpath(root, "configs", "base_case.toml"))
    sensitivity_cfg = TOML.parsefile(joinpath(root, "configs", "sensitivity.toml"))
    offsets_K = Float64.(sensitivity_cfg["jacket_temperature_offsets_K"])
    conversion = Float64[]
    maximum_temperature_K = Float64[]

    for offset_K in offsets_K
        params = with_jacket_temperature(base_params, base_params.jacket_temperature_K + offset_K)
        result = simulate(params; t_end_s, dt_s)
        metrics = calculate_metrics(result, params)
        push!(conversion, metrics.final_conversion)
        push!(maximum_temperature_K, metrics.max_temperature_K)
    end

    results_dir = joinpath(root, "results")
    figures_dir = joinpath(results_dir, "figures")
    mkpath(figures_dir)
    open(joinpath(results_dir, "jacket_temperature_sensitivity.csv"), "w") do io
        println(io, "jacket_temperature_offset_K,final_conversion_fraction,maximum_temperature_K")
        for i in eachindex(offsets_K)
            @printf(io, "%.6f,%.9f,%.9f\n", offsets_K[i], conversion[i], maximum_temperature_K[i])
        end
    end
    open(joinpath(results_dir, "sensitivity_summary.md"), "w") do io
        println(io, "- 扫描夹套温度偏移：$(@sprintf("%.1f", minimum(offsets_K))) 至 $(@sprintf("%.1f", maximum(offsets_K))) K。")
        println(io, "- 本 Demo 的目标是展示参数追踪和敏感性工件；结论不可外推至真实设备。")
    end
    write_svg_chart(
        joinpath(figures_dir, "jacket_temperature_sensitivity.svg"),
        offsets_K,
        [(name = "Maximum reactor temperature", y = maximum_temperature_K, color = "#7c3aed")];
        title = "Sensitivity to jacket-temperature offset",
        x_label = "Jacket-temperature offset (K)",
        y_label = "Maximum reactor temperature (K)",
    )
    println("Sensitivity artifacts written to $(relpath(results_dir, root)).")
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_sensitivity()
end

