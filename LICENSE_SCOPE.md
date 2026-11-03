# SEGAN: License Scope and Third-Party Notices

## Author-owned research software

Copyright (c) 2026 Feyyaz Fatih Aydın.

The author elects the **BSD 3-Clause License** (`BSD-3-Clause`) for the
**author-owned research software** in this repository. See [LICENSE](LICENSE)
for the complete terms. The intended software scope includes:

- `src/+segan/` algorithms, exporters, feature engineering, analysis utilities,
  and repository-specific MATLAB functions created by the author;
- `config/`, `reproduce_all.m`, `validate_results.m`, `run_demo.m`,
  `prepare_full_workspace.m`, and the author-owned test and setup code;
- author-created build, setup, validation and documentation helpers distributed
  as part of this repository, to the extent the author holds the relevant rights.

The copyright notice does **not** assert ownership of any third-party code,
source data, benchmark network, library, solver, or software dependencies.
Third-party notices, where supplied, continue to apply. For unidentified
portions with uncertain ownership, the original rights must be verified before
public distribution.

## Research input and derived data: separate rights

The root software license **does not relicense the four `data/raw/` files**:

| File | Rights and attribution treatment |
| --- | --- |
| `AMES_5Bus.xlsx` | Canonical author-prepared study workbook; evaluate the source of its original AMES-based material and any reused components before a public release. Cite the AMES project. |
| `case57.m` | IEEE/MATPOWER benchmark data. MATPOWER explicitly excludes case data from its software BSD license. Retain source attribution and resolve the relevant case-file redistribution permission. |
| `pglib_opf_case57_ieee__sad.m` | PGLib-OPF data under CC BY 4.0; preserve its attribution, version information and applicable upstream notices. |
| `power Generation and consumption.csv` | Turkey electricity-demand dataset obtained through Kaggle / EPİAŞ-derived sources. Document exact dataset terms and original producer attribution before public redistribution. |

The twelve **derived** `outputs/cache/*.mat` checkpoints are likewise **not
licensed automatically by the software BSD license**. Assess the effects of
upstream input rights on their distribution. All sixteen selected files are
listed with exact SHA-256 fingerprints in `RELEASE_DATA_SHA256.tsv`.

MATPOWER 8.1, Gurobi 13.0.1, MATLAB and third-party toolboxes are not included;
users must obtain them and the appropriate licenses from their providers.

## Scholarly citation

If you use the algorithms, framework or reproduced results in scholarly work,
please cite the associated peer-reviewed article via [CITATION.cff](CITATION.cff)
or [CITATION.bib](CITATION.bib):

Aydın, F. F. (2026). Auditable state-based screening of capacity-withholding
effects in nodal electricity markets. *Sustainable Energy, Grids and Networks*,
**48**, Article 102558. https://doi.org/10.1016/j.segan.2026.102558

This scholarly citation request is **not an additional condition** of the
BSD 3-Clause software license, and it does not replace third-party attribution
requirements.

## Release gate

This license-scope document records the author's choice for code. It does not
mean that upstream-data permission reviews or GitHub/Zenodo publication have
been completed. See [DATA_SOURCES.md](DATA_SOURCES.md) and
[RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) for the remaining release work.
