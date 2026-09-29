# MEMO
**To:** Head of Credit-SME  |  **From:** [Your name], Data Science  |  **Date:** [date]
**Subject:** SME pipeline bottlenecks and scorecard cut-off options

## 1. Bottom line (3 lines)
[One sentence on the biggest bottleneck. One on the risk link. One on the recommended action.]

## 2. What we found
1. **Bottleneck:** [Stage] accounts for [X]% of processing time (`outputs/stage_tat.csv`). [Branch] is [X]x the average (`outputs/bottleneck_heatmap.png`).
2. **Delay and risk:** Default rate is [X]% when Legal takes <=5 days vs [Y]% above 15 days (`outputs/legal_delay_vs_default.csv`). Each extra day: odds ratio [OR] (`outputs/legal_default_glm.txt`).
3. **Seasonality:** Median TAT rises from [a] to [b] days in Ramadan (`outputs/monthly_volume_tat.csv`).
4. **Drop-off:** [X]% of applications are lost before Legal; largest single drop is at [stage] (`outputs/funnel.csv`).

## 3. Scorecard status
Test KS [ ] / AUC [ ] / Gini [ ]; out-of-time KS [ ]. XGBoost gain over scorecard: [ ] AUC points, so we keep the scorecard for explainability.
Score PSI reached [ ] in [month] -> [stable / watch / recalibrate].

## 4. Recommendations
| Option | Approval rate | Bad rate | Trade-off |
|---|---|---|---|
| Current (no cut-off) | [ ]% | [ ]% | baseline |
| Cut-off [ ] | [ ]% | [ ]% | [ ] |
| Cut-off [ ] | [ ]% | [ ]% | [ ] |
(read values from the Risk View slider)

**Proposed actions:** (1) [parallel legal/valuation processing at branch X]; (2) [cut-off decision]; (3) [monthly PSI review].

## 5. Caveats
Synthetic data; trained on disbursed loans only; figures are directional.
