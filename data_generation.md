# Synthetic data methodology
- **Volume/time:** 25,000 applications, Jan 2023 - Jun 2025. Daily volume is 1.7x in the 21 days before each Eid; Fri/Sat are low-volume (Bangladesh weekend).
- **Stages:** Sales -> Credit -> Risk -> Legal -> Approval -> Disbursement. Stage time ~ Gamma(shape 2.5); hand-off waits ~ Gamma(1.5, mean 0.6 d).
- **Seasonality:** Ramadan multiplies stage times by 1.3; pre-Eid rush by 1.1. Loans above BDT 15m take 1.25x in Credit/Risk/Approval.
- **Branch effect:** Legal stage multiplier: Rajshahi 1.9, Bogura 1.3, Sylhet 1.25, Chattogram 1.15, Khulna 1.1, Dhaka 1.0.
- **Drop-off:** rejection probability rises with applicant risk (Credit, Risk, Approval); withdrawal probability rises with elapsed days.
- **Default:** logit = application-time risk + 0.06 x (legal days - 7). This is the *hidden relationship* the analysis should recover.
- **Drift:** from Jan 2025, turnover is 30% lower and CIB-watchlist/classified share is higher.
- **Open pipeline:** snapshot date 30 Jun 2025; applications not finished by then are "In Progress".
