# RETINA - Diabetic Retinopathy Screening Research Prototype

RETINA is an offline, cross-platform research prototype for automated diabetic
retinopathy screening from color fundus photographs.

> **Research use only.** RETINA is not a medical device and does not replace
> assessment by a qualified eye-care professional.

The repository also retains the existing project website under `Website/`.

## Final visual system

- Background: `#1E293B`
- Surface / cards: `#0F172A`
- Borders: `#334155`
- Primary text: `#F1F5F9`
- Secondary text: `#94A3B8`
- Muted text: `#64748B`
- Accent: `#2DD4BF`

Windows and Android share the same Flutter UI and eye branding.

## Screening pipeline

`Fundus gate -> Modality gate -> Image-quality gate -> DR-scope gate -> P0 -> E03`

A stopped image does not receive an issued DR stage. Research-only shadow E03
output does not override an abstention.

Final ICDR classes:

1. No apparent DR
2. Mild NPDR
3. Moderate NPDR
4. Severe NPDR
5. Proliferative DR

## Frozen final classifier results

Locked final test set: **702 images**, consumed once for final evaluation.

- Accuracy: **0.890313**
- Balanced accuracy: **0.816366**
- Macro F1: **0.806383**
- Weighted F1: **0.893651**
- Quadratic weighted kappa: **0.956077**
- Macro AUROC: **0.979061**
- Macro AUPRC: **0.849790**
- Brier score: **0.167763**
- ECE: **0.024605**
- NLL: **0.297202**

See [`docs/SCIENTIFIC_RESULTS.md`](docs/SCIENTIFIC_RESULTS.md).

## Cross-platform verification

A deterministic 25-image **TRAIN-only** deployment-parity checkpoint passed
decision parity, gate-score strict tolerance `<= 1e-4`, E03/shadow class-index
parity, and P0 geometry parity. Probability outputs are not claimed to be
bit-exact across operating systems.

See [`docs/DEPLOYMENT_VALIDATION.md`](docs/DEPLOYMENT_VALIDATION.md).

## Final release identities

Windows:
- 53 files
- release tree SHA256: `D0EEF8B179AB8C0E7E6180A1E852522B3FFB1B89113C893647563D9D3AF69804`
- ZIP SHA256: `1B7450B5C91D6A1D99041970094510957AF7EA2F8C3DC23C65EED62B6045402E`

Android:
- package: `com.example.dr_package_app`
- APK SHA256: `C4DCA6AB7D7A956C6E122850FDA19A635CA8C9A3CF3647CC5AE60587B40ACCF9`

The Windows ZIP and Android APK are release assets and are not committed as
large binaries in the source tree.

## Key directories

```text
App/               Final Flutter Windows/Android application source
Website/           Existing project website (preserved)
Models/            Existing repository model history (preserved)
Scripts/           Existing repository scripts (preserved)
native/windows/    Frozen Windows native pipeline source
docs/              Scientific and deployment documentation
```
