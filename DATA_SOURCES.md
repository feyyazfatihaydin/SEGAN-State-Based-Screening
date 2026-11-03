# SEGAN — Data Sources, Attribution, and Reproduction Assets

## Publication design

The author requests a **self-contained research-data release**: four validated raw inputs and twelve validated `.mat` results are included in the GitHub release alongside the computational code. Official upstream links below serve **provenance, credit, optional downloads and rights verification**, not prerequisites for running the exact released results. The validated source files are not altered by Stage 11R.

This document records an author's publication intent. It does **not** assign a new license to third-party material or override conditions imposed by the original data providers. Before the first public push, review case-specific, workbook-specific and dataset-specific redistribution rights. The author-owned SEGAN code is now distributed under **BSD-3-Clause** (see `LICENSE` and `LICENSE_SCOPE.md`); this software license does not change the rights in third-party input files or derived MAT checkpoints.

## Four canonical raw inputs

| Repository file | Upstream attribution / optional source | Practical note |
| --- | --- | --- |
| `data/raw/AMES_5Bus.xlsx` | [AMES Wholesale Power Market Test Bed, Iowa State](https://faculty.sites.iastate.edu/tesfatsi/archive/tesfatsi/AMESMarketHome.htm) | The supplied workbook is the exact author-prepared spreadsheet used in this paper. The AMES landing page need not host that identical workbook; verify third-party parts and workbook provenance before redistributing. |
| `data/raw/case57.m` | [MATPOWER 8.1 / IEEE 57-bus benchmark](https://matpower.org/download/) | Validate source/attribution for the exact case file. MATPOWER's BSD software license **explicitly excludes case-data files**; do not apply it automatically. |
| `data/raw/pglib_opf_case57_ieee__sad.m` | [PGLib-OPF source](https://github.com/power-grid-lib/pglib-opf) / [data license](https://github.com/power-grid-lib/pglib-opf/blob/master/LICENSE) | Preserve case-specific attribution and version. PGLib lists data files under CC BY 4.0; cite the original case author and PGLib. |
| `data/raw/power Generation and consumption.csv` | [Kaggle: Electrical Power Demand in Turkey](https://www.kaggle.com/datasets/dharanikra/electrical-power-demand-in-turkey) / [EPİAŞ Transparency Platform](https://seffaflik.epias.com.tr/) | Use the exact bundled canonical CSV for reproduction. Public access to underlying EPİAŞ data is not, alone, a legal grant to redistribute a third-party Kaggle download; document the dataset-specific terms. |

The SEGAN implementation uses these files for **reported-offer DC-OPF**, not to run the AMES Java/Python simulator. It uses the MATPOWER 57-bus case with PGLib-SAD branch-rating data and 2022 Turkey hourly demand-shape profiles.

## Twelve Quick Mode MAT checkpoints

The release preserves the exact twelve files under `outputs/cache/` listed in `RELEASE_DATA_SHA256.tsv`. They supply the feature, cluster, library, screening and robustness summaries required for the seven existing publication exporters. Remaining intermediate `.mat` files are **not** required by the verified Quick export calls and remain Git-ignored. Full Mode recomputes new MAT files from the four raw inputs in a separate clean workspace.

## Integrity and safe setup

- Verify files against `RELEASE_DATA_SHA256.tsv`, which records their relative paths, sizes in bytes and SHA-256 fingerprints.
- Do not rename or hand-edit the supplied Excel, `.m`, CSV or MAT files; edits can invalidate reproduction.
- For Full Mode, **do not run in the downloaded repository root that contains Quick checkpoints**. Use `prepare_full_workspace()` per [USER_GUIDE.md](USER_GUIDE.md).
- MATPOWER and Gurobi are **not** redistributed. Their current official download instructions and licensing requirements are in the User Guide.
- Retain provider notices and cite both the scientific paper and original data/software providers when appropriate.

## Unresolved public-release checks

1. Confirm and document original workbook components and any upstream AMES redistribution conditions.
2. Confirm exact `case57.m` data provenance/permission. MATPOWER's *code* BSD license is not enough.
3. Preserve PGLib data CC BY 4.0 attribution/version and check any case-specific credits.
4. Confirm the Kaggle dataset's posted reuse terms (or replace with an independently licensed EPİAŞ-based normalized export).
5. The author-owned code license has been chosen (BSD-3-Clause); inspect the Git index and the rights of the data files before any public push.
