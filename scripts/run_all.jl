include(joinpath(@__DIR__, "run_demo.jl"))
include(joinpath(@__DIR__, "run_sensitivity.jl"))

root = normpath(joinpath(@__DIR__, ".."))
run_base_case(root)
run_sensitivity(root)

