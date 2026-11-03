# Public Release Gate (Manual Review Required)

This checklist distinguishes tested numerical computations from legal and publication decisions. None of the remaining checkboxes should be considered implicitly approved.

## Completed local technical checks

- [x] Full Mode clean-copy run completed and `validate_results()` passed 17/17.
- [x] Quick Mode created 27/27 publication files, without OPF or K-means.
- [x] Stage 11H numerical CSV triplet comparisons passed 27/27.
- [x] Original and Full raw inputs and MATLAB sources matched by SHA-256.
- [x] Add root-level ignore rules for all non-allowlisted outputs and raw inputs, Quick outputs, and nested Full test clones.

## Blocking review before publishing

- [x] Author-owned research software license selected and installed: **BSD-3-Clause** (`LICENSE` and `LICENSE_SCOPE.md`). Third-party software/data are excluded from this grant.
- [ ] Verify permissions for *each* of the four raw inputs in `DATA_SOURCES.md`. If unapproved, publish acquisition instructions, not files.
- [ ] Review rights to distribute derived MAT checkpoints; do not assume that transformation removes upstream restrictions.
- [ ] Retain the historical Full-run solver limitation and the separate current-environment GUROBI probe in `SOLVER_EVIDENCE.md`; do not conflate them.
- [x] Four unused empty scaffolds were checked and archived to local ignored backup (11L2).
- [ ] Review README, citations, software/toolbox versions, and wording of local vs independently replicated results.
- [ ] Confirm only the **four authorized raw files** and **twelve Quick MAT checkpoints** are selected; no other raw inputs, nested Full test clones, intermediate outputs, private logs, credentials or personal paths may be **tracked**. `.gitignore` alone is insufficient for already-tracked content.
- [ ] The author requests directly bundling the 12 Quick MAT checkpoints in GitHub (8.34 MiB); verify upstream derived-data rights and final byte totals before staging.
- [ ] Review GitHub release commit, tag and Zenodo snapshot metadata and archive contents before making them public.

The `CITATION.cff` preferred citation uses the published article DOI; it does not assign that DOI to the code. The software DOI and version can be added only when assigned/approved. The author-owned software license is now BSD-3-Clause, separately scoped from research data.

## Stage 11R self-contained data plan

- [x] Select the exact four input files and twelve Quick `.mat` checkpoints for Git inclusion.
- [x] Establish narrow `.gitignore` allowlist (ignore all other generated MAT files, output plots and local test clones).
- [x] Write a SHA-256 manifest generator/verifier for these exact 16 local files.
- [x] Stage 11R installer and file/ignore verification passed on the author's workstation (16/16 allowlisted).
- [x] `prepare_full_workspace()` created a clean local copy and `reproduce_all('plan')` passed without modifying the validated original outputs.
- [x] Record author-owned software license and separate data-rights scope (`LICENSE`, `LICENSE_SCOPE.md`).
- [ ] Confirm exact rights/attribution for AMES-derived workbook, MATPOWER `case57` data, and Kaggle CSV.
- [ ] Review all 16 Git candidate assets and commit only the approved release.
- [ ] Verify a fresh Git clone on a different working folder before tagging a release and depositing on Zenodo.
