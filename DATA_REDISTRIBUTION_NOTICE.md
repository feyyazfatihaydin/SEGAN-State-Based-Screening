# Data Sources, Licensing, and Redistribution Notice

**Project:** SEGAN — Auditable State-Based Screening of Capacity-Withholding Effects in Nodal Electricity Markets  
**Associated article:** Feyyaz Fatih Aydin, *Sustainable Energy, Grids and Networks*, 48 (2026), article 102558. https://doi.org/10.1016/j.segan.2026.102558  
**Status:** Release preparation; not an assertion that every third-party item has been cleared for public republication.

## Scope

The project's root `LICENSE` (BSD-3-Clause) applies to the author's SEGAN MATLAB implementation, as described in `LICENSE_SCOPE.md`. **It does not relicense** third-party case files, workbooks, datasets, or MATLAB/Gurobi software. The author wishes to distribute the four canonical research inputs together with the twelve author-generated Quick Mode `.mat` checkpoints; this document identifies each input's origin and the evidence still needed before the first public push.

The source links are supplied for attribution, independent provenance checks, and optional retrieval. The validated files, if approved for redistribution, retain their exact names and SHA-256 fingerprints in `RELEASE_DATA_SHA256.tsv`.

## Canonical input files

### `data/raw/AMES_5Bus.xlsx`

- **Credit:** Leigh Tesfatsion, the AMES Wholesale Power Market Test Bed team, Iowa State University, and the contributors to the underlying five-bus benchmark. https://faculty.sites.iastate.edu/tesfatsi/archive/tesfatsi/AMESMarketHome.htm
- **File character:** Study-assembled Excel workbook with the sheets `input`, `output_benchmark`, and `output_learning`; it is not claimed to be an unmodified official AMES distribution. The SEGAN code uses benchmark parameters and economic conventions, **not the AMES agent-based simulation software**.
- **License distinction:** The AMES website describes open-source software and its GPL software release. That does not, by itself, settle the redistribution status of the exact adapted workbook or its incorporated material.
- **Release action:** Record the provenance and author-created transformations in the workbook. Retain upstream credits; obtain permission if the workbook reproduces separately protected material whose reuse terms do not already permit sharing.

### `data/raw/case57.m`

- **Credit:** University of Washington Power Systems Test Case Archive (IEEE Common Data Format), as converted to MATPOWER `case57` on 15-Oct-2014. https://labs.ece.uw.edu/pstca/ and https://matpower.org/download/
- **Evidence:** The canonical file's header identifies IEEE CDF / UW Archive lineage and conversion history. The MATLAB function is a test-case dataset, not the user's own code.
- **License distinction:** MATPOWER explicitly excludes its case files from the BSD-3-Clause license for MATPOWER **software**: https://matpower.org/license/
- **Release action:** Verify a case-specific distribution grant or retain the upstream copy as an externally sourced test-case dependency. If the public repository must be self-contained, secure a redistribution basis for the exact file before publishing it.

### `data/raw/pglib_opf_case57_ieee__sad.m`

- **Credit:** IEEE PES Power Grid Library — Optimal Power Flow, PGLib-OPF `v23.07`, Small Angle Difference case, and the case's original contributors. https://github.com/power-grid-lib/pglib-opf/tree/v23.07
- **License:** PGLib-OPF **data** are under Creative Commons Attribution 4.0 International (CC BY 4.0): https://github.com/power-grid-lib/pglib-opf/blob/v23.07/LICENSE and https://creativecommons.org/licenses/by/4.0/
- **Attribution requirements:** Preserve case-file notices and credits, identify version `v23.07`, link to CC BY 4.0, and indicate any modifications. The input is used, among other things, to inform network branch ratings in the SEGAN model.
- **Release action:** Verify the precise provenance/version of the canonical bytes and disclose any modifications. Publication is supported by this explicit license subject to its requirements.

### `data/raw/power Generation and consumption.csv`

- **Credit:** Kaggle dataset *Electrical Power Demand In Turkey*, published by `dharanikra`: https://www.kaggle.com/datasets/dharanikra/electrical-power-demand-in-turkey ; underlying Turkish electricity market data from EPİAŞ Transparency Platform: https://seffaflik.epias.com.tr/
- **File character:** Exact CSV selected for the paper's 2022 hourly Turkish demand-shape construction, with the original column schema including `Date_Time`, `Total (MWh)`, and `Consumption (MWh)`.
- **Official source finding:** EPİAŞ's published 2021 web-service terms include a clause permitting third-party sharing of obtained data when EPİAŞ is cited. This document addresses a historical web-service registration arrangement; current access methods and applicability to the exact Kaggle compilation require review: https://www.epias.com.tr/wp-content/uploads/2021/02/TR_Web_Servis_IP_Kayit_Proseduru.pdf
- **Do not infer:** The separate **Apache 2.0 license of a Kaggle notebook** is not evidence that the underlying Kaggle dataset file is licensed Apache 2.0.
- **Release action:** Document the specific Kaggle dataset file's distribution terms, permission from its publisher, or a separately prepared redistribution-compatible extraction from EPİAŞ. Do not substitute a newly downloaded dataset without revalidating the paper's exact numerical results.

## Twelve author-generated Quick Mode MAT checkpoints

The author approves publication of the outputs of their own SEGAN computational work. The exact twelve files are listed in `RELEASE_DATA_SHA256.tsv` under `outputs/cache/`. These are not identical to the input case files, and they are **not automatically covered by the source-code BSD-3-Clause license**. Declare the chosen release terms for these outputs separately while preserving the input provenance above. They are sufficient for the validated Quick Mode regeneration of Figures 2–7 and Tables 4–9.

## Software and solver are external dependencies

MATLAB, the Statistics and Machine Learning Toolbox, MATPOWER 8.1, and Gurobi 13.0.1 are **not redistributed** by this project. See `USER_GUIDE.md` for installation and licensing instructions. `SOLVER_EVIDENCE.md` documents a current in-memory test where MATPOWER `DEFAULT` resolved to GUROBI; it does **not** retrospectively certify every historic OPF solve.

## Reproduction and citation

- Original / Quick / clean Full comparisons passed **27/27 numerical CSV pairwise checks**, and the recorded-result validator passed **17/17** checks. This is numerical consistency evidence, not a claim of byte-identical `.mat`, PDF, or PNG outputs.
- Cite the author's article: https://doi.org/10.1016/j.segan.2026.102558 . Also credit original third-party data and software contributors as specified above.
- The Git release should preserve the 16 verified assets without rewriting their content and should not include Full-test clones, intermediate runs, license secrets, or credentials.

**Public-release gate:** Repository publication of any third-party item is not authorized by this notice alone. Complete the item-specific release decisions in `DATA_RELEASE_DECISIONS.md` before making the repository public.
