## Equation register

| ID | Equation and scope | Code mapping | Parameter/source status | Verification evidence |
|---|---|---|---|---|
| EQ-R-01 | \(dC_A/dt = -r_A\), \(dC_B/dt = r_A\), \(r_A = k(T)C_A\). Well-mixed batch reactor, irreversible A → B. | `src/BatchReactorDemo.jl`: `rhs` | Fictional demo values in `configs/base_case.toml`; **replace with a verified kinetic source before reuse**. | `test/runtests.jl`: mass balance and non-negative concentrations. |
| EQ-R-02 | \(dT/dt = [(-\Delta H)r_A - UA(T-T_j)/V]/(\rho C_p)\). Lumped energy balance with a constant-temperature jacket. | `src/BatchReactorDemo.jl`: `rhs` | Fictional \(\Delta H\), \(UA\), and \(\rho C_p\); **source required**. | `test/runtests.jl`: no-reaction cooling limit. |
| EQ-R-03 | \(k(T)=k_{ref}\exp[-E_a/R(1/T-1/T_{ref})]\). Arrhenius temperature dependence. | `src/BatchReactorDemo.jl`: `rate_constant_per_s` | Formula source must be an approved textbook, paper, or internal kinetic study. | Indirectly exercised by the base case and sensitivity run; add parameter-estimation tests for a real model. |

For a production model, replace “source required” with a source ID that resolves to an internal study, approved SOP, vendor document, patent, paper, or textbook. The source must support the exact claim made in the report.

