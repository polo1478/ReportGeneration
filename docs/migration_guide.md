# Migrating the workflow to a real Julia process model

1. Keep `Project.toml`, `Manifest.toml`, `configs/`, `results/`, `docs/`, `report/`, and the build script.
2. Replace `src/BatchReactorDemo.jl` with your reactor, mixing, separation, or integrated flowsheet package. Do not force an existing model into this demo's API; instead, make one scenario script write the standard artifacts described below.
3. Keep configuration outside source code. A specific report should identify the exact configuration file and the run manifest.
4. Make the scenario script write: time series or tables, figures, `summary.md`, `run_manifest.json`, and any validation artifacts. The Quarto report then remains independent from the numerical implementation.
5. Replace the model card, equation register, and source register before writing results prose.
6. Add real verification and validation evidence: conservation laws, limiting cases, solver convergence, calibration residuals, independent experimental comparison, sensitivity, and uncertainty as appropriate.
7. Update `report/internal_report.qmd` to describe the intended decision and the actual unit operation. Retain the limitations and evidence sections even when the report is short.

For mixing, document the selected representation (for example, perfectly mixed, compartment, residence-time distribution, CFD surrogate) and the mixing metric. For separation, document the mechanism and conditions: filtration/cake resistance, centrifugation, crystallization, chromatography, membrane transport, or distillation require different state variables and validation evidence.

