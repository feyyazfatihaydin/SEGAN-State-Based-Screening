# Auditable State-Based Screening of Capacity-Withholding Effects in Nodal Electricity Markets

\## Complete Installation \& Reproduction Manual



📘 \*\*\[Download the Step-by-Step User Guide (PDF)](docs/SEGAN\_Complete\_Reproduction\_Manual.pdf)\*\*



This manual provides step-by-step instructions for installing MATLAB, MATPOWER and Gurobi, configuring academic licensing, and reproducing the published results using Quick Mode and Full Mode.

Research code for reproducing the numerical experiments in:

> Feyyaz Fatih Aydın, "Auditable State-Based Screening of Capacity-Withholding Effects in Nodal Electricity Markets," \*Sustainable Energy, Grids and Networks\* (2026), article 102558. https://doi.org/10.1016/j.segan.2026.102558

**Release status (4 November 2026):** The complete 72-file repository (source code, documentation, four canonical inputs, twelve Quick Mode MAT checkpoints, and Git line-ending rules) is committed and uploaded to a **private GitHub repository**. No public GitHub release or Zenodo archive has been issued. Local verification completed: Quick reproduction generated 27/27 nonempty publication exports; an isolated Full reproduction passed 17/17 recorded-result checks; and original/Quick/Full numerical CSV comparisons passed 27/27 within stated tolerance. A fresh private GitHub clone contained all 71 files before the subsequent `.gitattributes` update; the sixteen research assets passed SHA-256 checks, allowing for Git's Windows line-ending conversion of two `.m` case files. A current-environment solver probe resolved MATPOWER `DEFAULT` to GUROBI in two cases; this is not retrospective evidence of every historical solve. Public redistribution of certain upstream inputs remains under review. See [PROVENANCE.md](PROVENANCE.md), [DATA\_RELEASE\_DECISIONS.md](DATA_RELEASE_DECISIONS.md), and [RELEASE\_CHECKLIST.md](RELEASE_CHECKLIST.md).

## Start here: bundled data and MATLAB user guide

**The current private repository includes the actual four raw research inputs and twelve Quick Mode MAT checkpoints**, alongside the original MATLAB code. No separate AMES or Turkey-data search is needed for ordinary Quick/Full setup, when the repository is publicly released. Official AMES, MATPOWER, PGLib, Kaggle and EPİAŞ links are included for **source attribution and optional independent acquisition**, not as substitutes for the supplied canonical inputs.

* [USER\_GUIDE.md](USER_GUIDE.md): end-to-end MATLAB, MATPOWER 8.1 and Gurobi setup, Quick/Full steps, verification and troubleshooting.
* [DATA\_ACQUISITION.md](DATA_ACQUISITION.md), [DATA\_SOURCES.md](DATA_SOURCES.md), [DATA\_REDISTRIBUTION\_NOTICE.md](DATA_REDISTRIBUTION_NOTICE.md), and [DATA\_RELEASE\_DECISIONS.md](DATA_RELEASE_DECISIONS.md): exact input filenames, provenance, upstream attribution, and outstanding redistribution checks.
* `RELEASE\_DATA\_SHA256.tsv`: SHA-256 hashes and byte sizes of the **16 selected** raw/MAT files. A fresh clone can verify its files using this list.
* `prepare\_full\_workspace.m`: safely creates a clean `full\_workspace/` from the bundled code and four inputs **without copying Quick MAT checkpoints**. See Section 7 in the user guide before using Full Mode.

**Do not invoke Full Mode directly in the downloaded root with bundled MAT checkpoints**; the built-in overwrite protection will reject that attempt. Use the helper to create the empty-output workspace. Neither MATPOWER nor Gurobi nor license credentials are redistributed here.

## Software license and data rights

The **author-owned SEGAN MATLAB software is BSD-3-Clause licensed**:
see [LICENSE](LICENSE) and the explicit [LICENSE\_SCOPE.md](LICENSE_SCOPE.md).
This permission does **not** automatically extend to the bundled AMES/IEEE
case/PGLib/Turkey input data or the twelve derived Quick `.mat` checkpoints;
those assets retain their own provenance and applicable upstream terms.
See [DATA\_SOURCES.md](DATA_SOURCES.md) and [RELEASE\_CHECKLIST.md](RELEASE_CHECKLIST.md)
before making the repository or its data publicly available. The repository is currently uploaded privately; the BSD-3-Clause software license does not itself authorize publication of third-party data.

When using the research software or reproducing its results in a publication,
**please cite the associated peer-reviewed SEGAN article** using
[CITATION.cff](CITATION.cff) or [CITATION.bib](CITATION.bib). Citation is a
scholarly request, not an extra license condition.

## Scope

The implementation examines exogenously imposed capacity-withholding scenarios in hourly DC optimal power flow (DC-OPF). It separates *reported offers used for market clearing* from *baseline (true) costs used for ex-post accounting*. Unsupervised operating states are named only after clustering by their economic characteristics; the screening results do not establish behavioral intent or a legal finding.

* **IEEE 5-bus:** 16 scenarios x 24 hours = **384** hourly market-clearing records; strategic focus on G3.
* **IEEE 57-bus:** two strategic configurations, Single-G5 and Double-G5/G7; each has 16 scenarios x 2,160 hours = **34,560** records; **69,120** hourly records in total.
* The main scenario library thus contains **69,504** hourly records across the two test systems. Additional generator-selection screening experiments are separate from this count.
* The repository reproduces **Figures 2-7 and Tables 4-9**. **Figure 1 was drawn manually for the manuscript and is not regenerated here.** Tables 1-2 are descriptive and Table 3 documents computational settings.

The 57-bus experiments use the MATPOWER `case57` network, replacing branch `RATE\_A` values with those from the PGLib-SAD version. The three 30-day, 24-hour-per-day demand windows use 2022 Turkish load-shape data. The release design includes the four exact input files, with upstream attribution and outstanding rights notes documented in [DATA\_SOURCES.md](DATA_SOURCES.md).

## Software environment

The environment reported in the article (Table 3) is:

|Component|Published experiment setting|
|-|-|
|MATLAB|R2025b Update 3|
|MATPOWER|8.1|
|DC-OPF routine|`rundcopf`|
|Solver setting|`opf.dc.solver = 'DEFAULT'`; solver resolved to GUROBI in the publication environment|
|Gurobi|13.0.1 available in the publication environment|
|Clustering|Squared Euclidean K-means; 50 replicates; 1,000 maximum iterations|
|Random seed|`20260422`|
|Zero-variance filtering|tolerance `1e-8`|

The **Statistics and Machine Learning Toolbox** is needed for K-means, PCA, and associated analysis. Install MATLAB, MATPOWER, any applicable solver, and their respective licenses separately; they are not distributed in this repository. A different solver/tool version may produce small numerical differences. Add MATPOWER to the MATLAB path before running the examples below.

## Repository layout

```text
config/reproduction\_config.m   Portable paths and experiment settings
data/raw/                      Four validated raw inputs (specifically allowlisted)
src/+segan/                    Modular simulation, accounting and analysis
reproduce\_all.m                Protected Quick and clean-copy Full reproduction
validate\_results.m             Read-only validation of existing outputs
run\_demo.m                     Four small, in-memory IEEE 5-bus DC-OPF cases
tests/test\_reproduction.m       Automated functional and safety tests
outputs/cache/                 Twelve allowlisted Quick MAT checkpoints; other intermediates ignored
outputs/figures/               Generated Figures 2-7 (ignored by Git)
outputs/tables/                Generated Tables 4-9 (ignored by Git)
DATA\_SOURCES.md                Provenance and permission-review register
```

All paths in MATLAB code are resolved relative to the repository root. No user-specific absolute path is required. The Git ignore rules allow **exactly four source inputs** and **twelve selected Quick MAT checkpoints**, while excluding all other generated outputs, local Full test copies and temporary files.

## Four bundled inputs

The private repository contains the **four exact validated inputs** in `data/raw/`, named:

```text
AMES\_5Bus.xlsx
case57.m
pglib\_opf\_case57\_ieee\_\_sad.m
power Generation and consumption.csv
```

These are the input files the author wishes to distribute directly; upstream provider credit and any third-party reuse limitations remain separately applicable. Review [DATA\_SOURCES.md](DATA_SOURCES.md) before publishing or sharing any copies.

## Safe inspection of an existing working repository

From the repository root in MATLAB, with MATPOWER already on the path:

```matlab
addpath(fullfile(pwd, 'config'));
addpath(fullfile(pwd, 'src'));

plan = reproduce\_all('plan');
disp(plan.SafeToStartFreshRun);

results = validate\_results();
disp(results.Validation);

tests = runtests(fullfile(pwd, 'tests', 'test\_reproduction.m'));
disp(tests);
```

`reproduce\_all('plan')` is read-only. It reports `SafeToStartFreshRun = false` when the `outputs/` tree already contains generated files: **that is the correct protection for an occupied research repository**. `validate\_results()` checks stored numerical evidence and publication comparisons without solving OPF or fitting clusters. The tests exercise planning, demonstration, and validation behaviors; they are not a substitute for a clean-copy full rerun.

## Small demonstration

The demonstration requires **Stage 1 prepared inputs** at `outputs/cache/segan\_inputs.mat`. If they are not present, prepare them first:

```matlab
cfg = reproduction\_config();
inputs = segan.prepare\_inputs(cfg);  % Creates the Stage 1 MAT cache.
demo = run\_demo();                  % Four in-memory DC-OPF solves; no file output.
disp(demo.Validation);
```

`run\_demo()` illustrates CW0 versus CCW 0.30/0.05 for a peak and a nonpeak hour in the IEEE 5-bus case. It does **not** reproduce all publication results.

## Quick reproduction (existing validated MAT checkpoints)

Quick mode uses the twelve bundled MAT checkpoints already under `outputs/cache/` and does not rerun OPF or K-means. It creates a **separate** `quick\_reproduction/outputs/` tree, leaving `outputs/` unchanged. First inspect the plan, then run once into an empty Quick destination:

```matlab
quickPlan = reproduce\_all('quick\_plan');
assert(quickPlan.SafeToStartQuickRun);
quickReport = reproduce\_all('quick');
assert(quickReport.Validation.AllPassed);
```

Quick mode regenerates Figures 2-7 and Tables 4-9 (27 publication output files counting image formats and plotting-data CSV). The original Figure 1 remains out of scope. A repeated run to an occupied Quick destination is intentionally blocked; **do not delete validated data to bypass this protection**. The author has approved sharing the twelve generated MAT checkpoints; any embedded third-party material must still be treated according to its applicable terms.

## Full reproduction (new, empty-output copy only)

**Never run Full Mode in the downloaded root:** it contains the twelve Quick Mode MAT files. In MATLAB, open the downloaded SEGAN root and let the new helper create an isolated, clean working copy:

```matlab
addpath(fullfile(pwd,'config'),'-begin');
addpath(fullfile(pwd,'src'),'-begin');
workspacePlan = prepare\_full\_workspace('plan');
assert(workspacePlan.SafeToCreate);
workspace = prepare\_full\_workspace();
cd(workspace.WorkspacePath);
addpath(fullfile(pwd,'config'),'-begin');
addpath(fullfile(pwd,'src'),'-begin');
clear functions;
rehash;
plan = reproduce\_all('plan');
assert(plan.SafeToStartFreshRun);
report = reproduce\_all('full');
disp(report.Validation);
```

`prepare\_full\_workspace()` copies the four provided raw inputs and source/configuration into `full\_workspace/` but **does not copy any MAT checkpoints, plots or logs**. It refuses to overwrite an existing workspace. The isolated copy then runs all 23 computational and export stages. The original root and ready-made Quick checkpoints remain unchanged. Refer to [USER\_GUIDE.md](USER_GUIDE.md) for solver setup and detailed steps.

A previous clean-copy Full run completed locally on 2026-11-03 and passed all 17 recorded-result checks; the cross-run comparison found all 27 numerical CSV comparisons matched within tolerance. The helper and fresh-copy Full workflow are documented above. A separate fresh-clone Quick/Full readiness check is still recommended before the first public release; do not equate a file-count check with a runtime test.

## Interpretation and units

Reported-offer DC-OPF market clearing and baseline true-cost ex-post net earnings are deliberately different computations. The output columns named `CCWDelta90Day`, `StrategicNE90Days`, or similar refer to **90-day sums**, not daily averages. Related `...MeanDaily` fields give averages per day. The manuscript's units in selected economic table headings are not a reason to relabel 90-day sums as daily values in the released code.

K-means cluster IDs are arbitrary; compare clusters using economic meaning, label-independent metrics, and, when relevant, sorted cluster shares rather than raw label number. Silhouette approximations in the primary clustering and K-sensitivity routines use documented sampling conventions and need not be identical.

## Reproducibility and release checklist

* \[x] Recorded results passed the local numerical verification pipeline.
* \[x] Demo completed four in-memory OPF solves; seven MATLAB tests passed locally.
* \[x] Source portability scan reported no flagged personal paths or non-ASCII MATLAB source characters.
* \[x] An isolated **fresh-copy Full reproduction** completed and passed recorded-result validation on 2026-11-03; a cross-run audit matched the nine numerical CSV files in each of the three comparisons. Preserve the full run log for the release record.
* \[x] Apply the **BSD-3-Clause** license to author-owned software, with scope explained in [LICENSE\_SCOPE.md](LICENSE_SCOPE.md).
* \[ ] Finish upstream copyright/provenance review for the four allowlisted input files; author permission does not supersede third-party terms.
* \[x] Four empty, unused MATLAB starter scaffolds were safely archived locally outside Git in Stage 11L2.
* \[x] Ignore Full test clones and all generated outputs **except** the 12 specifically allowlisted Quick MAT checkpoints; all sixteen approved-for-private-staging assets were committed to the private repository.
* \[x] Capture current-environment Gurobi selection evidence in [SOLVER\_EVIDENCE.md](SOLVER_EVIDENCE.md); historical solver selection is not retrospectively proven.
* \[x] Upload the complete source-and-data package to a **private** GitHub repository.
* \[ ] Verify a fresh clone against the final `.gitattributes` configuration and complete release-rights review.
* \[ ] Prepare a **public** GitHub release and a versioned Zenodo snapshot only after clearance.

## How to cite this research

**If you use this repository, its MATLAB implementations, simulated results, state-based screening framework, or reproduced figures/tables in a publication, please cite the associated peer-reviewed research article:**

> Aydın, F. F. (2026). Auditable state-based screening of capacity-withholding effects in nodal electricity markets. \*Sustainable Energy, Grids and Networks\*, \*\*48\*\*, Article 102558. https://doi.org/10.1016/j.segan.2026.102558

Use the repository's **Cite this repository** menu on GitHub, which reads [`CITATION.cff`](CITATION.cff), or copy the provided [BibTeX entry](CITATION.bib). The preferred citation is the **published article**, not a yet-to-be-issued software DOI. If a separate versioned software or dataset DOI is assigned later, readers may cite that release **in addition to** the paper when relevant.

Citation is a scholarly request, not a substitute for the code license. This citation does not replace attribution or licensing required for MATPOWER, PGLib, AMES-style inputs, or the Turkish electricity-demand dataset. This repository supports controlled screening and does not establish behavioral intent or a legal finding of market manipulation.

