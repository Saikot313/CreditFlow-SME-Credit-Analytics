# 03_scorecard_models.R -- WOE/IV scorecard, LR vs XGBoost vs RF, KS/Gini/PSI, drift monitoring, SHAP
suppressPackageStartupMessages({library(DBI); library(RSQLite); library(dplyr); library(scorecard)
                                library(xgboost); library(ranger); library(ggplot2)})
set.seed(42)
dir.create("outputs", showWarnings = FALSE); dir.create("shiny_app/data", recursive = TRUE, showWarnings = FALSE)
snapshot <- as.POSIXct("2025-06-30 23:59:59", tz = "UTC")

# ---- Metric helpers (banking standard) ---------------------------------------
auc_f <- function(y, p) { r <- rank(p); n1 <- sum(y == 1); n0 <- sum(y == 0)
                          (sum(r[y == 1]) - n1*(n1 + 1)/2) / (n1*n0) }
ks_f  <- function(y, p) { x <- sort(unique(p)); max(abs(ecdf(p[y == 1])(x) - ecdf(p[y == 0])(x))) }
perf  <- function(y, p) c(AUC = auc_f(y, p), KS = ks_f(y, p), Gini = 2*auc_f(y, p) - 1)
psi <- function(e, a, bins = 10) {                 # numeric PSI, bins from the baseline (dev) sample
  br <- unique(quantile(e, seq(0, 1, length.out = bins + 1), na.rm = TRUE)); br[1] <- -Inf; br[length(br)] <- Inf
  pe <- pmax(as.numeric(table(cut(e, br))) / length(e), 1e-4)
  pa <- pmax(as.numeric(table(cut(a, br))) / length(a), 1e-4); sum((pa - pe) * log(pa / pe)) }
psi_cat <- function(e, a) { lv <- union(unique(e), unique(a))
  pe <- pmax(as.numeric(table(factor(e, lv))) / length(e), 1e-4)
  pa <- pmax(as.numeric(table(factor(a, lv))) / length(a), 1e-4); sum((pa - pe) * log(pa / pe)) }

# ---- Data & splits ------------------------------------------------------------
con  <- dbConnect(SQLite(), "data/sme_loans.sqlite")
apps <- dbGetQuery(con, "SELECT * FROM applications"); ev <- dbGetQuery(con, "SELECT * FROM stage_events")
dbDisconnect(con); apps$app_date <- as.Date(apps$app_date)

# Only APPLICATION-TIME features. legal_days is NOT used (it is unknown when scoring -> leakage).
# Branch is excluded on purpose (its effect works through legal delay, and it is not a fair credit factor).
xs <- c("business_type","sector","vintage_yrs","turnover_m","loan_amount_m","debt_to_turnover",
        "tenor_m","collateral_type","cib_status","owner_age","n_existing_loans")
y  <- "default_flag"
d  <- apps %>% filter(status == "Disbursed")
dev <- d %>% filter(app_date <  as.Date("2024-07-01"))
oot <- d %>% filter(app_date >= as.Date("2024-07-01"), app_date < as.Date("2025-01-01"))
mon <- d %>% filter(app_date >= as.Date("2025-01-01"))
idx <- sample(nrow(dev), floor(0.7 * nrow(dev))); train <- dev[idx, ]; test <- dev[-idx, ]
cat("Train:", nrow(train), " Test:", nrow(test), " OOT:", nrow(oot), " Monitor:", nrow(mon), "\n")

# ---- 1) WOE / IV scorecard (logistic regression) ------------------------------
bins <- woebin(as.data.frame(train[, c(xs, y)]), y = y, print_step = 0)
iv_tbl <- data.frame(variable = names(bins), IV = sapply(bins, function(b) b$total_iv[1])) %>% arrange(desc(IV))
write.csv(iv_tbl, "outputs/information_value.csv", row.names = FALSE); print(iv_tbl)
sel <- iv_tbl$variable[iv_tbl$IV >= 0.02]
woe_of <- function(df) woebin_ply(as.data.frame(df[, c(sel, y)]), bins[sel], print_step = 0)
lr <- step(glm(as.formula(paste(y, "~ .")), data = woe_of(train), family = binomial), direction = "both", trace = 0)
card <- scorecard(bins[sel], lr, points0 = 600, odds0 = 1/19, pdo = 50)   # 600 pts = 19:1 good:bad, +50 pts doubles odds
score_of <- function(df) scorecard_ply(as.data.frame(df[, sel]), card, only_total_score = TRUE, print_step = 0)$score
pred_lr  <- function(df) as.numeric(predict(lr, woe_of(df), type = "response"))
saveRDS(list(bins = bins[sel], model = lr, card = card), "outputs/scorecard_objects.rds")
write.csv(do.call(rbind, card[names(card) != "basepoints"]), "outputs/scorecard_points_table.csv", row.names = FALSE)

# ---- 2) XGBoost and Random Forest ---------------------------------------------
cat_vars <- xs[sapply(train[xs], is.character)]
lv <- lapply(train[cat_vars], function(v) sort(unique(v)))
prep <- function(df) { x <- as.data.frame(df[, xs]); for (v in cat_vars) x[[v]] <- factor(x[[v]], levels = lv[[v]]); x }
mm   <- function(df) model.matrix(~ . - 1, data = prep(df))
xgbm <- xgb.train(params = list(objective = "binary:logistic", eval_metric = "auc", max_depth = 3,
                                eta = 0.05, subsample = 0.8, colsample_bytree = 0.8),
                  data = xgb.DMatrix(mm(train), label = train[[y]]), nrounds = 250, verbose = 0)
pred_xgb <- function(df) as.numeric(predict(xgbm, mm(df)))
rf <- ranger(dependent.variable.name = "y", data = cbind(prep(train), y = factor(train[[y]])),
             probability = TRUE, num.trees = 300, min.node.size = 50, seed = 42)
pred_rf <- function(df) predict(rf, prep(df))$predictions[, "1"]

# ---- 3) Comparison table -------------------------------------------------------
comp <- do.call(rbind, lapply(list(LogReg_Scorecard = pred_lr, XGBoost = pred_xgb, RandomForest = pred_rf),
  function(f) round(c(setNames(perf(test[[y]], f(test)), paste0("Test_", c("AUC","KS","Gini"))),
                      setNames(perf(oot[[y]],  f(oot)),  paste0("OOT_",  c("AUC","KS","Gini")))), 3)))
comp <- data.frame(Model = rownames(comp), comp, row.names = NULL)
write.csv(comp, "outputs/model_comparison.csv", row.names = FALSE); cat("\n== Model comparison ==\n"); print(comp)

# ---- 4) Monitoring: monthly PSI + performance (OOT + 2025 = 12 months) --------
m <- bind_rows(oot, mon); m$pd <- pred_lr(m); m$score <- score_of(m); m$month <- format(m$app_date, "%Y-%m")
sc_train <- score_of(train)
monitor <- do.call(rbind, lapply(split(m, m$month), function(g) data.frame(
  month = g$month[1], n = nrow(g), actual_bad_rate = mean(g[[y]]), predicted_pd = mean(g$pd),
  AUC = auc_f(g[[y]], g$pd), KS = ks_f(g[[y]], g$pd), score_psi = psi(sc_train, g$score),
  psi_turnover = psi(train$turnover_m, g$turnover_m), psi_cib = psi_cat(train$cib_status, g$cib_status))))
write.csv(monitor, "outputs/monitoring_monthly.csv", row.names = FALSE); cat("\n== Monitoring ==\n"); print(round(monitor[, -1], 3))
saveRDS(list(monitor = monitor, comparison = comp), "shiny_app/data/monitor.rds")

# ---- 5) SHAP explainability (XGBoost) ------------------------------------------
X <- mm(test)[seq_len(min(2000, nrow(test))), ]
sh <- predict(xgbm, X, predcontrib = TRUE); sh <- sh[, colnames(sh) != "BIAS", drop = FALSE]
# Aggregate one-hot dummy SHAP values back to the ORIGINAL variable (e.g. cib_statusWatchlist -> cib_status)
grp  <- sapply(colnames(sh), function(cn) xs[which.max(startsWith(cn, xs) * nchar(xs))])
sh_v <- sapply(xs, function(v) rowSums(sh[, grp == v, drop = FALSE]))
imp <- sort(colMeans(abs(sh_v)), decreasing = TRUE)[seq_len(min(12, ncol(sh_v)))]
p <- ggplot(data.frame(f = factor(names(imp), rev(names(imp))), v = imp), aes(f, v)) +
  geom_col(fill = "#2b6cb0") + coord_flip() + theme_minimal(base_size = 12) +
  labs(title = "What drives predicted default? (mean |SHAP|)", x = NULL, y = "Mean |SHAP| (log-odds)")
ggsave("outputs/shap_importance.png", p, width = 7.5, height = 4.5, dpi = 150)
# Reason codes: top 3 risk-increasing features for the 5 riskiest applicants
top <- order(rowSums(sh_v), decreasing = TRUE)[1:5]
reasons <- do.call(rbind, lapply(top, function(i) {
  tv <- names(sort(sh_v[i, ], decreasing = TRUE))[1:3]
  vals <- sapply(tv, function(v) as.character(test[[v]][i]))
  data.frame(row = i, xgb_pd = round(pred_xgb(test[i, ]), 3),
             top_reasons = paste(sprintf("%s = %s", tv, vals), collapse = " | "))
}))
write.csv(reasons, "outputs/reason_codes_examples.csv", row.names = FALSE); print(reasons)

# ---- 6) Export data for the Shiny app -------------------------------------------
apps$score <- NA_real_; k <- apps$status == "Disbursed"; apps$score[k] <- score_of(apps[k, ])
apps$pd <- NA_real_; apps$pd[k] <- pred_lr(apps[k, ])   # scorecard PD, used for Expected Loss
cur <- ev %>% group_by(app_id) %>% slice_max(stage_order, n = 1, with_ties = FALSE) %>% ungroup() %>%
  select(app_id, current_stage = stage, cur_entered = entered_at)
apps2 <- apps %>% left_join(cur, by = "app_id") %>%
  mutate(days_in_current = ifelse(status == "In Progress",
         as.numeric(difftime(snapshot, as.POSIXct(cur_entered, tz = "UTC"), units = "days")), NA)) %>%
  select(app_id, app_date, branch, business_type, collateral_type, loan_amount_m, status, exit_stage, total_tat_days,
         current_stage, days_in_current, score, pd, default_flag)
saveRDS(apps2, "shiny_app/data/apps.rds")
saveRDS(ev %>% left_join(apps[, c("app_id","branch")], by = "app_id") %>%
          select(app_id, branch, stage, stage_order, days_in_stage, wait_days), "shiny_app/data/events.rds")
cat("\nExported Shiny data to shiny_app/data/\n")
