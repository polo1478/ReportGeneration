## Model card

| Field | Demo definition |
|---|---|
| Intended use | Demonstrate a Julia-to-report workflow for a process-modeling team. |
| Process scope | Fictional, well-mixed, jacketed batch reactor containing one irreversible reaction A → B. |
| Inputs | Initial concentrations, temperatures, kinetic constants, heat capacity, UA, and simulation settings. |
| Outputs | Concentration profiles, temperature profile, conversion, mass-balance residual, and a jacket-temperature sensitivity sweep. |
| Model form | First-order Arrhenius kinetics; lumped material and energy balances; fixed-step RK4 integration. |
| Calibration status | None. All numbers are fictional. |
| Validation status | Educational numerical verification only; not qualified against experimental data. |
| Excluded physics | Mixing non-uniformity, mass transfer, phase equilibria, impurities, pressure dynamics, control logic, measurement uncertainty, and equipment faults. |
| Decision status | Not for GMP, process-control, scale-up, batch release, or regulatory use. |

When migrating this workflow, replace this card before creating a report. A real model card should state the intended decision, operating range, data lineage, calibration method, independent validation data, uncertainty treatment, owner, reviewer, and approval status.

