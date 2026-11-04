# SEGAN — Data Release Decisions Before GitHub Publication

**State as of 4 November 2026:** The private GitHub repository contains 69 committed files, including four canonical raw inputs and twelve author-generated Quictwelve Quick Mode MAT checkpoints remain outside Git history. The final public target is a reproducible repository containing all sixteen assets, if their respective distribution conditions permit it.

## Status by item

| Asset | Current evidence | Release condition / required action |
| --- | --- | --- |
| `pglib_opf_case57_ieee__sad.m` | **Explicit CC BY 4.0 data license** from PGLib-OPF | Preserve original credits, v23.07 identification, license link, and any modification note; verify exact file lineage. |
| `AMES_5Bus.xlsx` | AMES source and public five-bus benchmark documented; Excel is author-assembled | Record which worksheet values were transcribed or transformed and whether third-party expressive content is copied; apply any applicable AMES/benchmark notices or obtain permission where necessary. |
| `case57.m` | IEEE CDF / UW Archive source; MATPOWER converts this test case | MATPOWER excludes case data from its code BSD grant. Establish case-specific redistribution terms or document an upstream-install fallback, keeping the numeric case unchanged. |
| `power Generation and consumption.csv` | Kaggle dataset source found; EPİAŞ public data and historical attributed-sharing clause identified | Obtain the **dataset-specific Kaggle** license / publisher permission, or document a lawful equivalent EPİAŞ-derived distribution path. Notebook license is not dataset license. |
| Twelve `outputs/cache/*.mat` files | New author-generated computational checkpoints | Author authorizes public sharing of own results; choose an appropriate **separate data rights notice** and check upstream material contained within them. Do not apply software BSD to raw third-party content. |

## Evidence links

1. PGLib-OPF data license: https://github.com/power-grid-lib/pglib-opf/blob/v23.07/LICENSE
2. PGLib v23.07 release: https://github.com/power-grid-lib/pglib-opf/releases/tag/v23.07
3. AMES project and versions: https://faculty.sites.iastate.edu/tesfatsi/archive/tesfatsi/AMESMarketHome.htm
4. MATPOWER's explicit test-case exclusion: https://matpower.org/license/
5. Kaggle dataset landing page: https://www.kaggle.com/datasets/dharanikra/electrical-power-demand-in-turkey
6. EPİAŞ platform: https://seffaflik.epias.com.tr/
7. EPİAŞ 2021 web-service terms, historical context: https://www.epias.com.tr/wp-content/uploads/2021/02/TR_Web_Servis_IP_Kayit_Proseduru.pdf

## Planned publication sequence

1. Preserve first code-only commit and original **16 SHA-256-verified assets** unchanged.
2. Confirm the outstanding original-workbook, case57 and Kaggle/EPİAŞ release rights and finalize source acknowledgements; complete a separate derived-MAT rights statement.
3. The 16 data assets have been committed and pushed to the private GitHub repository. Complete the outstanding rights review befohor-code commit and do not push until reviewed.
4. Verify that a fresh clone has all 16 intended assets, that Quick Mode regenerates the 27 publication files, and that a clean `prepare_full_workspace('plan')` reports ready.
5. Publish a GitHub release only after explicit final approval; archive the release with Zenodo and add its own software DOI separately from the research-article DOI.

## Boundaries

- The author-approved software license is **BSD-3-Clause**, applying to the user's original MATLAB implementation, not to all inputs or all derived data automatically.
- Public access and an academic use case do not by themselves establish a legal right to republish a specific third-party download.
- This status document is not legal advice, is not a sublicense, and does not claim that third parties authorized distribution.
- No new OPF, K-means, figure, or table generation is required to complete these release notices.
