module BatchReactorDemo

using Dates
using Printf
using SHA
using TOML

export ModelParams,
       SimulationResult,
       load_parameters,
       simulate,
       calculate_metrics,
       with_jacket_temperature,
       write_timeseries_csv,
       write_svg_chart,
       write_summary_markdown,
       write_manifest_json,
       git_revision

"""Parameters for the fictional, well-mixed batch reactor demonstration.

The reaction is A -> B with first-order, Arrhenius temperature dependence and
heat removal through a constant-temperature jacket. Every field uses SI units.
"""
Base.@kwdef struct ModelParams
    volume_m3::Float64 = 0.05
    initial_concentration_A_mol_m3::Float64 = 100.0
    initial_concentration_B_mol_m3::Float64 = 0.0
    initial_temperature_K::Float64 = 298.15
    jacket_temperature_K::Float64 = 298.15
    k_ref_per_s::Float64 = 0.001
    activation_energy_J_mol::Float64 = 45000.0
    reference_temperature_K::Float64 = 298.15
    reaction_enthalpy_J_mol::Float64 = -50000.0
    volumetric_heat_capacity_J_m3_K::Float64 = 4.0e6
    UA_W_K::Float64 = 150.0
end

struct SimulationResult
    time_s::Vector{Float64}
    concentration_A_mol_m3::Vector{Float64}
    concentration_B_mol_m3::Vector{Float64}
    temperature_K::Vector{Float64}
end

"""Load ModelParams and run settings from a TOML configuration file."""
function load_parameters(path::AbstractString)
    cfg = TOML.parsefile(path)
    params = ModelParams(
        volume_m3 = Float64(cfg["volume_m3"]),
        initial_concentration_A_mol_m3 = Float64(cfg["initial_concentration_A_mol_m3"]),
        initial_concentration_B_mol_m3 = Float64(cfg["initial_concentration_B_mol_m3"]),
        initial_temperature_K = Float64(cfg["initial_temperature_K"]),
        jacket_temperature_K = Float64(cfg["jacket_temperature_K"]),
        k_ref_per_s = Float64(cfg["k_ref_per_s"]),
        activation_energy_J_mol = Float64(cfg["activation_energy_J_mol"]),
        reference_temperature_K = Float64(cfg["reference_temperature_K"]),
        reaction_enthalpy_J_mol = Float64(cfg["reaction_enthalpy_J_mol"]),
        volumetric_heat_capacity_J_m3_K = Float64(cfg["volumetric_heat_capacity_J_m3_K"]),
        UA_W_K = Float64(cfg["UA_W_K"]),
    )
    return params, Float64(cfg["t_end_s"]), Float64(cfg["dt_s"])
end

function validate(params::ModelParams, t_end_s::Real, dt_s::Real)
    params.volume_m3 > 0 || error("volume_m3 must be positive")
    params.initial_concentration_A_mol_m3 >= 0 || error("initial concentration of A must be non-negative")
    params.initial_concentration_B_mol_m3 >= 0 || error("initial concentration of B must be non-negative")
    params.initial_temperature_K > 0 || error("initial_temperature_K must be positive")
    params.jacket_temperature_K > 0 || error("jacket_temperature_K must be positive")
    params.reference_temperature_K > 0 || error("reference_temperature_K must be positive")
    params.k_ref_per_s >= 0 || error("k_ref_per_s must be non-negative")
    params.activation_energy_J_mol >= 0 || error("activation_energy_J_mol must be non-negative")
    params.volumetric_heat_capacity_J_m3_K > 0 || error("volumetric heat capacity must be positive")
    params.UA_W_K >= 0 || error("UA_W_K must be non-negative")
    t_end_s > 0 || error("t_end_s must be positive")
    dt_s > 0 || error("dt_s must be positive")
end

"""Arrhenius rate constant at temperature T (K)."""
function rate_constant_per_s(T_K::Real, params::ModelParams)
    R_J_mol_K = 8.31446261815324
    exponent = -params.activation_energy_J_mol / R_J_mol_K *
               (1 / T_K - 1 / params.reference_temperature_K)
    return params.k_ref_per_s * exp(exponent)
end

"""Right-hand side for [C_A, C_B, T]."""
function rhs(y::Vector{Float64}, params::ModelParams)
    C_A, C_B, T_K = y
    k_per_s = rate_constant_per_s(T_K, params)
    reaction_rate_mol_m3_s = k_per_s * max(C_A, 0.0)

    # EQ-R-01 and EQ-R-02 are defined in docs/equation_register.md.
    dC_A_dt = -reaction_rate_mol_m3_s
    dC_B_dt = reaction_rate_mol_m3_s
    reaction_heat_W_m3 = -params.reaction_enthalpy_J_mol * reaction_rate_mol_m3_s
    jacket_heat_W = params.UA_W_K * (T_K - params.jacket_temperature_K)
    dT_dt = (reaction_heat_W_m3 - jacket_heat_W / params.volume_m3) /
            params.volumetric_heat_capacity_J_m3_K
    return [dC_A_dt, dC_B_dt, dT_dt]
end

function rk4_step(y::Vector{Float64}, dt_s::Float64, params::ModelParams)
    k1 = rhs(y, params)
    k2 = rhs(y .+ 0.5 * dt_s .* k1, params)
    k3 = rhs(y .+ 0.5 * dt_s .* k2, params)
    k4 = rhs(y .+ dt_s .* k3, params)
    return y .+ (dt_s / 6.0) .* (k1 .+ 2.0 .* k2 .+ 2.0 .* k3 .+ k4)
end

"""Simulate the model with a fixed-step fourth-order Runge–Kutta integrator."""
function simulate(params::ModelParams; t_end_s::Real = 5400.0, dt_s::Real = 1.0)
    validate(params, t_end_s, dt_s)
    n_steps = round(Int, t_end_s / dt_s)
    isapprox(n_steps * dt_s, t_end_s; atol = 1e-9, rtol = 0.0) ||
        error("t_end_s must be an integer multiple of dt_s for this demo")

    time_s = collect(0.0:Float64(dt_s):Float64(t_end_s))
    C_A = Vector{Float64}(undef, n_steps + 1)
    C_B = Vector{Float64}(undef, n_steps + 1)
    T_K = Vector{Float64}(undef, n_steps + 1)
    y = [params.initial_concentration_A_mol_m3,
         params.initial_concentration_B_mol_m3,
         params.initial_temperature_K]

    C_A[1], C_B[1], T_K[1] = y
    for index in 1:n_steps
        y = rk4_step(y, Float64(dt_s), params)
        # Tiny negative values may appear from numerical round-off near completion.
        y[1] = max(y[1], 0.0)
        y[2] = max(y[2], 0.0)
        C_A[index + 1], C_B[index + 1], T_K[index + 1] = y
    end
    return SimulationResult(time_s, C_A, C_B, T_K)
end

"""Calculate reportable metrics and verification evidence."""
function calculate_metrics(result::SimulationResult, params::ModelParams)
    initial_total = params.initial_concentration_A_mol_m3 + params.initial_concentration_B_mol_m3
    total_concentration = result.concentration_A_mol_m3 .+ result.concentration_B_mol_m3
    mass_balance_max_abs_error_mol_m3 = maximum(abs.(total_concentration .- initial_total))
    max_temperature_index = argmax(result.temperature_K)
    final_conversion = 1.0 - result.concentration_A_mol_m3[end] /
                             params.initial_concentration_A_mol_m3
    return (
        final_conversion = final_conversion,
        max_temperature_K = result.temperature_K[max_temperature_index],
        time_of_max_temperature_s = result.time_s[max_temperature_index],
        mass_balance_max_abs_error_mol_m3 = mass_balance_max_abs_error_mol_m3,
        minimum_concentration_A_mol_m3 = minimum(result.concentration_A_mol_m3),
        minimum_concentration_B_mol_m3 = minimum(result.concentration_B_mol_m3),
    )
end

"""Return a copy of params with a different jacket temperature."""
function with_jacket_temperature(params::ModelParams, jacket_temperature_K::Real)
    return ModelParams(
        volume_m3 = params.volume_m3,
        initial_concentration_A_mol_m3 = params.initial_concentration_A_mol_m3,
        initial_concentration_B_mol_m3 = params.initial_concentration_B_mol_m3,
        initial_temperature_K = params.initial_temperature_K,
        jacket_temperature_K = Float64(jacket_temperature_K),
        k_ref_per_s = params.k_ref_per_s,
        activation_energy_J_mol = params.activation_energy_J_mol,
        reference_temperature_K = params.reference_temperature_K,
        reaction_enthalpy_J_mol = params.reaction_enthalpy_J_mol,
        volumetric_heat_capacity_J_m3_K = params.volumetric_heat_capacity_J_m3_K,
        UA_W_K = params.UA_W_K,
    )
end

function write_timeseries_csv(path::AbstractString, result::SimulationResult)
    open(path, "w") do io
        println(io, "time_s,concentration_A_mol_m3,concentration_B_mol_m3,temperature_K")
        for i in eachindex(result.time_s)
            @printf(io, "%.6f,%.9f,%.9f,%.9f\n", result.time_s[i],
                    result.concentration_A_mol_m3[i], result.concentration_B_mol_m3[i],
                    result.temperature_K[i])
        end
    end
end

function sampled_indices(length::Int; maximum_points::Int = 900)
    length <= maximum_points && return collect(1:length)
    stride = ceil(Int, length / maximum_points)
    indices = collect(1:stride:length)
    indices[end] == length || push!(indices, length)
    return indices
end

"""Write a dependency-free SVG line chart suitable for the demo report."""
function write_svg_chart(path::AbstractString, x::Vector{Float64}, series::AbstractVector{<:NamedTuple};
                         title::AbstractString, x_label::AbstractString, y_label::AbstractString)
    width, height = 960, 560
    left, right, top, bottom = 100, 40, 70, 100
    chart_width, chart_height = width - left - right, height - top - bottom
    y_values = reduce(vcat, [line.y for line in series])
    x_min, x_max = extrema(x)
    y_min, y_max = extrema(y_values)
    x_span = max(x_max - x_min, eps())
    y_span = max(y_max - y_min, eps())
    y_padding = 0.08 * y_span
    y_min -= y_padding
    y_max += y_padding
    y_span = max(y_max - y_min, eps())
    x_pixel(value) = left + (value - x_min) / x_span * chart_width
    y_pixel(value) = top + chart_height - (value - y_min) / y_span * chart_height
    indices = sampled_indices(length(x))

    open(path, "w") do io
        println(io, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$width\" height=\"$height\" viewBox=\"0 0 $width $height\">")
        println(io, "<rect width=\"100%\" height=\"100%\" fill=\"white\"/>")
        println(io, "<text x=\"$(width / 2)\" y=\"34\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"22\" font-weight=\"bold\">$title</text>")
        println(io, "<line x1=\"$left\" y1=\"$(top + chart_height)\" x2=\"$(left + chart_width)\" y2=\"$(top + chart_height)\" stroke=\"#222\"/>")
        println(io, "<line x1=\"$left\" y1=\"$top\" x2=\"$left\" y2=\"$(top + chart_height)\" stroke=\"#222\"/>")
        for fraction in 0.0:0.25:1.0
            x_value = x_min + fraction * x_span
            y_value = y_min + fraction * y_span
            xp, yp = x_pixel(x_value), y_pixel(y_value)
            println(io, "<line x1=\"$(round(xp; digits = 2))\" y1=\"$top\" x2=\"$(round(xp; digits = 2))\" y2=\"$(top + chart_height)\" stroke=\"#e5e7eb\"/>")
            println(io, "<line x1=\"$left\" y1=\"$(round(yp; digits = 2))\" x2=\"$(left + chart_width)\" y2=\"$(round(yp; digits = 2))\" stroke=\"#e5e7eb\"/>")
            @printf(io, "<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"13\">%.0f</text>\n", xp, top + chart_height + 24, x_value)
            @printf(io, "<text x=\"%.1f\" y=\"%.1f\" text-anchor=\"end\" font-family=\"Arial\" font-size=\"13\">%.3g</text>\n", left - 10, yp + 4, y_value)
        end
        for line in series
            points = join([@sprintf("%.2f,%.2f", x_pixel(x[i]), y_pixel(line.y[i])) for i in indices], " ")
            println(io, "<polyline fill=\"none\" stroke=\"$(line.color)\" stroke-width=\"2.8\" points=\"$points\"/>")
        end
        legend_x = left + 8
        for (index, line) in enumerate(series)
            legend_y = top + 24 * index
            println(io, "<line x1=\"$legend_x\" y1=\"$legend_y\" x2=\"$(legend_x + 24)\" y2=\"$legend_y\" stroke=\"$(line.color)\" stroke-width=\"3\"/>")
            println(io, "<text x=\"$(legend_x + 30)\" y=\"$(legend_y + 5)\" font-family=\"Arial\" font-size=\"14\">$(line.name)</text>")
        end
        println(io, "<text x=\"$(width / 2)\" y=\"$(height - 25)\" text-anchor=\"middle\" font-family=\"Arial\" font-size=\"16\">$x_label</text>")
        println(io, "<text x=\"25\" y=\"$(height / 2)\" text-anchor=\"middle\" transform=\"rotate(-90 25 $(height / 2))\" font-family=\"Arial\" font-size=\"16\">$y_label</text>")
        println(io, "</svg>")
    end
end

function write_summary_markdown(path::AbstractString, metrics, params::ModelParams)
    open(path, "w") do io
        println(io, "> **演示状态：** 本报告采用虚构的动力学和设备参数，仅用于展示可复现报告工作流；不能用于工艺开发、GMP、批次放行或监管申报。")
        println(io)
        println(io, "- 最终 A 转化率：**$(@sprintf("%.2f", 100 * metrics.final_conversion))%**")
        println(io, "- 最高温度：**$(@sprintf("%.3f", metrics.max_temperature_K)) K**，发生在 **$(@sprintf("%.0f", metrics.time_of_max_temperature_s)) s**")
        println(io, "- 最大物料衡算绝对误差：**$(@sprintf("%.3e", metrics.mass_balance_max_abs_error_mol_m3)) mol/m³**")
        println(io, "- 工况：夹套温度 $(@sprintf("%.2f", params.jacket_temperature_K)) K；初始 A 浓度 $(@sprintf("%.2f", params.initial_concentration_A_mol_m3)) mol/m³。")
    end
end

json_escape(value::AbstractString) = replace(value, "\\" => "\\\\", "\"" => "\\\"")

function git_revision(root::AbstractString)
    try
        command = pipeline(`git -C $root rev-parse --short HEAD`; stderr = devnull)
        revision = readchomp(command)
        return isempty(revision) ? "unavailable" : revision
    catch
        return "unavailable"
    end
end

function write_manifest_json(path::AbstractString; root::AbstractString, config_path::AbstractString)
    project_toml = joinpath(root, "Project.toml")
    project_sha1 = isfile(project_toml) ? bytes2hex(sha1(read(project_toml))) : "unavailable"
    timestamp = Dates.format(now(UTC), dateformat"yyyy-mm-ddTHH:MM:SS") * "Z"
    open(path, "w") do io
        println(io, "{")
        println(io, "  \"generated_at_utc\": \"$(json_escape(timestamp))\",")
        println(io, "  \"julia_version\": \"$(json_escape(string(VERSION)))\",")
        println(io, "  \"git_revision\": \"$(json_escape(git_revision(root)))\",")
        println(io, "  \"project_toml_sha1\": \"$(json_escape(project_sha1))\",")
        println(io, "  \"base_case_config\": \"$(json_escape(relpath(config_path, root)))\",")
        println(io, "  \"model\": \"fictional well-mixed batch reactor demo\"")
        println(io, "}")
    end
end

end # module
