if !isdefined(Main, :BatchReactorDemo)
    include(joinpath(@__DIR__, "..", "src", "BatchReactorDemo.jl"))
end
using .BatchReactorDemo

function project_root()
    return normpath(joinpath(@__DIR__, ".."))
end

"""Generate all base-case artifacts consumed by the internal report."""
function run_base_case(root::AbstractString = project_root())
    config_path = joinpath(root, "configs", "base_case.toml")
    params, t_end_s, dt_s = load_parameters(config_path)
    result = simulate(params; t_end_s, dt_s)
    metrics = calculate_metrics(result, params)

    results_dir = joinpath(root, "results")
    figures_dir = joinpath(results_dir, "figures")
    mkpath(figures_dir)
    write_timeseries_csv(joinpath(results_dir, "timeseries.csv"), result)
    write_summary_markdown(joinpath(results_dir, "summary.md"), metrics, params)
    write_manifest_json(joinpath(results_dir, "run_manifest.json"); root, config_path)

    write_svg_chart(
        joinpath(figures_dir, "concentrations.svg"),
        result.time_s,
        [
            (name = "A", y = result.concentration_A_mol_m3, color = "#2563eb"),
            (name = "B", y = result.concentration_B_mol_m3, color = "#16a34a"),
        ];
        title = "Base case: species concentrations",
        x_label = "Time (s)",
        y_label = "Concentration (mol/m³)",
    )
    write_svg_chart(
        joinpath(figures_dir, "temperature.svg"),
        result.time_s,
        [(name = "Reactor temperature", y = result.temperature_K, color = "#dc2626")];
        title = "Base case: reactor temperature",
        x_label = "Time (s)",
        y_label = "Temperature (K)",
    )
    println("Base-case artifacts written to $(relpath(results_dir, root)).")
    return result, metrics, params
end

if abspath(PROGRAM_FILE) == @__FILE__
    run_base_case()
end

