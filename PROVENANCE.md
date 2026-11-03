# Reproduction Evidence and Computational Provenance

**Status:** Evidence gathered on 2026-11-03 in the researcher's MATLAB environment. The repository has not yet received public release and data-license clearance. This document records observed checks, not an assertion of byte-identical or third-party-independent verification.

## Reported software environment

The paper reports MATLAB R2025b Update 3, MATPOWER 8.1, Gurobi 13.0.1 available, and `opf.dc.solver = 'DEFAULT'` resolved as GUROBI in the publication environment. The reproduction source currently retains `DEFAULT`; availability of `gurobi` does **not**, by itself, prove that the clean-copy run resolved to Gurobi. Save the actual solver-selection diagnostics from the MATLAB run before asserting solver parity.

K-means: squared Euclidean, 50 replicates, 1,000 maximum iterations, `rng(20260422)`; zero-variance tolerance `1e-8`.

## Successful local validation events

1. The Stage 11D demonstration solved four IEEE 5-bus DC-OPF cases in memory; seven MATLAB unit/behavioral tests passed.
2. Stage 11F Quick Mode regenerated six figures (both PNG and PDF), six tables (both CSV and TeX), and three plotting-data CSVs, yielding 27/27 nonempty publication export files without OPF or K-means. It used twelve existing MAT checkpoints.
3. Stage 11G3 Full Mode completed all 23 research stages in a clean nested test clone, generated new data and exports, and reported recorded-result validation **17/17**, with the original source repository untouched. This is a clean-copy test on the same workstation.
4. Stage 11H compared the original, Quick, and Full outputs. All three sets had 27/27 expected output files. The four raw inputs and MATLAB sources were SHA-256 identical between the original and clean Full clone. Nine numerical CSV files passed pairwise semantic comparisons across Original/Full, Quick/Full and Original/Quick: **27/27 comparisons**. Numeric tolerance: `1e-6 + 1e-8*max(abs(a),abs(b))`.
5. **MAT serialization:** all twelve required MAT checkpoints exist in both original and Full; 0/12 have identical binary hashes. **Other artifacts:** only 6/18 PNG/PDF/TeX files were byte-identical in each comparison. These are informative, not an indication of failure. Array-level deep comparison of every MAT member has *not* been performed.

## Scope of conclusions

The checks establish a successful local end-to-end rerun and tolerance-based equality of publication CSV values; they do **not** establish bitwise identity of MAT/PNG/PDF/TeX files, reuse on unrelated operating systems, or automatic Gurobi equivalence. The study has not yet been independently installed by an unaffiliated researcher.

The results reproduce **Figures 2-7 and Tables 4-9**; Figure 1 is a manually constructed author figure. Some reported strategic net-earning quantities are 90-day aggregates rather than daily means. See `DATA_SOURCES.md` for input provenance and unresolved redistribution terms.

## Evidence to retain before depositing a version

- Capture full unedited MATLAB command-window log for Stage 11G3 and the Stage 11H audit log (local private release evidence).
- Record `version`, `ver`, MATPOWER version, Gurobi version/license context and **actual DC-OPF solver selection**; avoid committing machine-specific secrets or personal paths.
- Record a source revision identifier and checksums for releasable artifacts.
- Inspect the Git index (not only `.gitignore`) before a commit; ignore patterns do not remove files already tracked.
- Publish only inputs and derived MAT checkpoints whose redistribution conditions are documented.

## Prepared bundled research assets (Stage 11R)

The release design retains **four canonical source inputs** under `data/raw/` and **twelve derived Quick MAT checkpoints** under `outputs/cache/`, without changing their bytes. Their precise relative paths, byte sizes and SHA-256 values are listed in `RELEASE_DATA_SHA256.tsv`, generated from the author's original validated files. All other cached experiments, intermediate scenario files, figures and test clones are excluded by `.gitignore`. This is **not yet evidence of a public GitHub or Zenodo upload**.

For Full Mode, `prepare_full_workspace.m` creates a new, clean `full_workspace/` containing four inputs and source but **no precomputed MAT results**. The source workstation's validated Full run and independent result comparison remain the scientific evidence; this new convenience helper must still be tested in MATLAB before public-release claims.

Known publication-time caveat: software license selection and upstream case/workbook/CSV redistribution review remain outstanding. The in-memory Gurobi probe documents the current MATLAB environment only.
