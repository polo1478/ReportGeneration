# Process-model reporting rules

- Run Julia from the repository root with `julia --project=.`.
- Treat `data/raw/` as immutable and append-only. Do not create or alter raw data in a task.
- Use SI units internally. Define every reported symbol and display any process-unit conversion explicitly.
- Every model equation must have an ID and map to source code, a parameter source, and at least one verification test in `docs/equation_register.md`.
- Every decision-relevant artifact must record the scenario configuration, Julia version, project hash, and Git revision when available.
- Generate figures and tables from scripts. Do not copy numerical values into the report manually.
- Mark all extrapolations, uncalibrated parameters, and missing sources clearly. Never invent a reference, experimental result, batch record, or validation result.
- This repository is an educational demo. Its fictional parameters and outputs are not suitable for GMP, batch release, regulatory submission, or process-control decisions.

