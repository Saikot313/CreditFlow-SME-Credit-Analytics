# Deployment checklist (shinyapps.io + GitHub)

## A. Before deploying
1. `source("run_all.R")` finished without errors.
2. `shiny_app/data/` contains `apps.rds`, `events.rds`, `monitor.rds`.
3. `shiny::runApp("shiny_app")` works locally and both tabs load.

## B. shinyapps.io (free plan)
1. Sign up at shinyapps.io, choose an account name.
2. Dashboard -> your name (top right) -> Tokens -> Show -> Copy to clipboard.
3. In R, run the `setAccountInfo(...)` line from the token popup (once per machine).
4. `source("deploy.R")`  (or `rsconnect::deployApp("shiny_app")`).
5. First deploy takes 3-8 minutes. The console prints your URL:
   `https://YOUR_ACCOUNT.shinyapps.io/creditflow-sme/`

## C. Common errors
| Error | Fix |
|---|---|
| `cannot open file 'data/apps.rds'` | Run `run_all.R` first; deploy the `shiny_app` folder, not the project root |
| Package install fails on server | Update packages locally (`update.packages()`), redeploy |
| App loads then disconnects | Free plan has 1 GB RAM; keep the app data as .rds (do not deploy the sqlite file) |
| `Error in rsconnect...: account not found` | Re-run `setAccountInfo` with the right name/token/secret |
| Slow first load | Free apps sleep after inactivity; open the link once before interviews |

## D. GitHub
1. Create repo `creditflow-sme` (public).
2. Add 3-4 screenshots (both dashboard tabs, heatmap, KM curve) under `docs/` and embed in README.
3. Put the live link at the top of README: `**Live demo:** https://...`
4. RStudio: Tools -> Version Control -> Project Setup, or use GitHub Desktop.
5. Do NOT commit your shinyapps.io token/secret (never paste them into a file in the repo).

## E. Before sharing the link
Open it in a private window and on your phone. Check the cut-off slider and stuck-application table work.
