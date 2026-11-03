# DC-OPF Solver Selection Evidence

**Repository:** SEGAN State-Based Screening reproduction source  
**Observation date:** 2026-11-03  
**Evidence type:** A new, in-memory, same-workstation probe; **not** a historical Full Mode execution trace.

## Purpose

The reproducibility configuration sets `opf.dc.solver = 'DEFAULT'`. That option does not, on its own, identify the solver used in a specific run. Stage 11O explicitly compared MATPOWER's resolved algorithm under `DEFAULT` with an explicit `GUROBI` request in two IEEE 5-bus peak-hour DC-OPF cases. The resolved algorithm was inspected from the returned solution record, rather than inferred from the presence of a Gurobi installation.

## Observed result

| Peak-hour case | Configured request | Resolved solver | Explicit request | Explicit resolved solver | Both successful | Objective difference | Maximum dispatch difference (MW) | Maximum LMP difference |
| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: |
| CW0 peak (hour 17) | `DEFAULT` | `GUROBI` | `GUROBI` | `GUROBI` | Yes | 0 | 0 | 0 |
| CCW peak (hour 17) | `DEFAULT` | `GUROBI` | `GUROBI` | `GUROBI` | Yes | 0 | 0 | 0 |

Four small DC-OPF solves were performed in memory. All four succeeded. The Stage 11O check reported `ConfiguredSolverIsGurobi = true`, `ExplicitGurobiAvailable = true`, and `InMemoryProbePassed = true`. Objective function values printed in the test were 21,752 for CW0 peak and 25,913 for CCW peak, respectively; displayed values may be rounded by MATLAB's table formatter.

## How to reproduce the observation

From the repository root in a compatible MATLAB installation with MATPOWER and Gurobi separately installed and licensed:

```matlab
addpath(fullfile(pwd, 'config'));
addpath(fullfile(pwd, 'src'));
cfg = reproduction_config();
evidence = segan.probe_dc_solver(cfg);
disp(evidence.Cases);
disp(evidence.Validation);
```

This probe needs Stage 1 prepared data in the research repository. It does not write MAT files, figures, tables, source code, or Git files. It is not a substitute for a Full Mode rerun.

## Evidence boundaries

- **Directly observed:** In the tested researcher's MATLAB environment, `DEFAULT` resolved to Gurobi for both small probe cases; explicitly choosing Gurobi gave matching objectives, dispatch and LMPs for those cases.
- **Not established by this new probe:** Which solver was chosen during the already-completed Stage 11G3 Full Mode execution. A new probe is not a timestamped solver trace of an earlier run.
- **Not established:** Identical solver choices or machine-precision equality on other installations, versions or networks. The paper reports MATLAB R2025b Update 3, MATPOWER 8.1 and Gurobi 13.0.1; the displayed Stage 11O log does not independently report the exact version of each component.
- **Publication statements:** Describe the solver setting as `DEFAULT`, with Gurobi *observed* during the Stage 11O probe. For a particular Full Mode run, retain that run's own algorithm/solver logs if solver identity matters.

## Relation to the manuscript

Associated paper: F. F. Aydin, "Auditable state-based screening of capacity-withholding effects in nodal electricity markets," *Sustainable Energy, Grids and Networks*, vol. 48, art. 102558, 2026. https://doi.org/10.1016/j.segan.2026.102558

This document records computational observations; it does not grant a software license, confer permission to redistribute third-party inputs, or change the research results. See `PROVENANCE.md`, `DATA_SOURCES.md`, and `RELEASE_CHECKLIST.md` for other release considerations.
