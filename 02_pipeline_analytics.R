# 02_pipeline_analytics.R -- SQL pipeline metrics + Kaplan-Meier + legal-delay/default link
suppressPackageStartupMessages({library(DBI); library(RSQLite); library(dplyr); library(ggplot2); library(survival)})
dir.create("outputs", showWarnings = FALSE)
stages <- c("Sales","Credit","Risk","Legal","Approval","Disbursement")
con <- dbConnect(SQLite(), "data/sme_loans.sqlite")

read_queries <- function(path) {
  txt <- paste(readLines(path), collapse = "\n")
  parts <- strsplit(txt, "-- name: ", fixed = TRUE)[[1]][-1]
  setNames(trimws(sub("^[^\n]*\n", "", parts)), trimws(sub("\n.*", "", parts)))
}
qs  <- read_queries("sql/pipeline_queries.sql")
res <- lapply(qs, function(q) dbGetQuery(con, sub(";\\s*$", "", q)))
for (n in names(res)) write.csv(res[[n]], file.path("outputs", paste0(n, ".csv")), row.names = FALSE)
cat("\n== Stage TAT ==\n");  print(res$stage_tat)
cat("\n== Funnel ==\n");     print(res$funnel)
cat("\n== Legal delay vs default ==\n"); print(res$legal_delay_vs_default)

# ---- Bottleneck heatmap (branch x stage) -------------------------------------
h <- res$branch_stage_heatmap; h$stage <- factor(h$stage, levels = stages)
p <- ggplot(h, aes(stage, branch, fill = avg_days)) + geom_tile(colour = "white") +
  geom_text(aes(label = round(avg_days, 1)), size = 3.5) +
  scale_fill_gradient(low = "#fff5eb", high = "#d94801") +
  labs(title = "Where do SME loans get stuck?", subtitle = "Average days per stage, by branch",
       x = NULL, y = NULL, fill = "Avg days") + theme_minimal(base_size = 12)
ggsave("outputs/bottleneck_heatmap.png", p, width = 8, height = 4.5, dpi = 150)

# ---- Kaplan-Meier: time to disbursement ---------------------------------------
# Rejected/withdrawn are treated as censored (cause-specific view); see README limitations.
apps <- dbGetQuery(con, "SELECT * FROM applications WHERE status <> 'In Progress'")
apps$event <- as.integer(apps$status == "Disbursed")
fit <- survfit(Surv(total_tat_days, event) ~ branch, data = apps)
png("outputs/km_time_to_disbursement.png", width = 1000, height = 650, res = 130)
plot(fit, fun = "event", col = seq_along(fit$strata), lwd = 2, xlim = c(0, 60),
     xlab = "Days since application", ylab = "Cumulative share disbursed",
     main = "Time to disbursement by branch (Kaplan-Meier)")
legend("bottomright", sub("branch=", "", names(fit$strata)), col = seq_along(fit$strata), lwd = 2, cex = .8)
dev.off()
lr <- survdiff(Surv(total_tat_days, event) ~ branch, data = apps)
km_tab <- data.frame(branch = sub("branch=", "", names(fit$strata)),
                     median_days_to_disbursement = summary(fit)$table[, "median"])
write.csv(km_tab, "outputs/km_median_by_branch.csv", row.names = FALSE)
cat("\n== KM median days by branch ==\n"); print(km_tab)
cat("Log-rank p-value:", format.pval(1 - pchisq(lr$chisq, length(lr$n) - 1)), "\n")

# ---- Does slow legal processing go with worse loans? ----------------------------
disb <- apps %>% filter(status == "Disbursed")
g <- glm(default_flag ~ legal_days + log(loan_amount_m) + cib_status + collateral_type,
         data = disb, family = binomial)
sink("outputs/legal_default_glm.txt"); print(summary(g)); sink()
cat("\nOdds ratio per extra legal-stage day (controlling for risk factors):",
    round(exp(coef(g)["legal_days"]), 3), "\n")
dbDisconnect(con)
