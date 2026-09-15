# Frozen scientific results

Final curated dataset: **4,629 images**

- Train: 3,225
- Validation: 702
- Locked final test: 702
- Development population: 3,927

Class totals:

| ICDR class | Count |
|---|---:|
| No apparent DR | 1,470 |
| Mild NPDR | 336 |
| Moderate NPDR | 1,895 |
| Severe NPDR | 235 |
| Proliferative DR | 693 |

The locked final test set was consumed once for final evaluation and must not be
used again for tuning, threshold selection, or model selection.

## Development OOF

- Accuracy: 0.8880
- Balanced accuracy: 0.8089
- Macro F1: 0.8054
- Quadratic weighted kappa: 0.9463
- Macro AUROC: 0.9755
- Macro AUPRC: 0.8427
- Brier score: 0.1704
- ECE: 0.0207

## Locked final test (`n = 702`)

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

Per-class recall:

| Class | Recall |
|---|---:|
| No apparent DR | 0.941964 |
| Mild NPDR | 0.745098 |
| Moderate NPDR | 0.926573 |
| Severe NPDR | 0.628571 |
| Proliferative DR | 0.839623 |

Final E03 model SHA256:

`672D1FA2E06B7B8C3CEF218A50A80886714E310FF70B0394332F058BC5910E77`

No E03 confidence-abstention rule was added after final evaluation.
