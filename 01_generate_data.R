# 01_generate_data.R  --  Synthetic SME loan pipeline generator (Bangladesh context)
suppressPackageStartupMessages({library(dplyr); library(lubridate); library(DBI); library(RSQLite)})
set.seed(2025)
dir.create("data", showWarnings = FALSE)

N        <- 25000
snapshot <- as.POSIXct("2025-06-30 23:59:59", tz = "UTC")   # "today" of the simulated pipeline
stages   <- c("Sales","Credit","Risk","Legal","Approval","Disbursement")

# ---- Calendar: Eid pre-rush and Ramadan slowdown ---------------------------
eid_d <- as.Date(c("2023-04-21","2023-06-29","2024-04-10","2024-06-17","2025-03-31","2025-06-07"))
ram_s <- as.Date(c("2023-03-23","2024-03-11","2025-03-01")); ram_e <- ram_s + 29
in_any <- function(d, s, e) { out <- rep(FALSE, length(d))
  for (i in seq_along(s)) out <- out | (d >= s[i] & d <= e[i]); out }

days <- seq(as.Date("2023-01-01"), as.Date("2025-06-30"), by = "day")
w <- ifelse(in_any(days, eid_d - 21, eid_d - 1), 1.7, 1)        # application spike before Eid
wk <- wday(days) %in% c(6, 7)                                    # Fri/Sat weekend in Bangladesh
w[wk] <- w[wk] * 0.15
app_date <- sample(days, N, TRUE, prob = w)
app_ts   <- as.POSIXct(app_date, tz = "UTC") + runif(N, 9*3600, 17*3600)
ids      <- sprintf("APP%06d", 1:N)
drift    <- app_date >= as.Date("2025-01-01")                    # population drift in 2025

# ---- Applicant features ------------------------------------------------------
branch <- sample(c("Motijheel","Gulshan","Chattogram","Rajshahi","Khulna","Sylhet","Bogura"),
                 N, TRUE, c(.22,.18,.20,.10,.10,.08,.12))
business_type <- sample(c("Trading","Manufacturing","Service"), N, TRUE, c(.5,.3,.2))
sector_v <- c(RMG_Textile=.1, Food_Agro=.1, Construction=.35, Retail_Wholesale=0,
              Pharma=-.3, Transport=.25, Education_Health=-.2)
sector   <- sample(names(sector_v), N, TRUE, c(.15,.15,.12,.28,.06,.14,.10))
vintage  <- pmin(rpois(N, 7) + 1, 30)
turnover <- rlnorm(N, log(30), .8) * ifelse(drift, .7, 1)        # BDT million / year
loan_m   <- rlnorm(N, log(5), .7)                                # BDT million
ratio    <- loan_m / turnover
tenor    <- sample(c(12,24,36,48,60), N, TRUE, c(.15,.30,.30,.15,.10))
owner_age <- round(pmin(pmax(rnorm(N, 42, 9), 23), 68))
n_exist  <- rpois(N, 1.2)
cib_lv   <- c("Regular","No_History","Watchlist","Classified")
cib      <- ifelse(drift, sample(cib_lv, N, TRUE, c(.58,.15,.18,.09)),
                          sample(cib_lv, N, TRUE, c(.70,.15,.11,.04)))
coll     <- sample(c("Property","FDR_Deposit","Machinery","Unsecured"), N, TRUE, c(.45,.08,.17,.30))
rm_id    <- sprintf("RM%03d", sample(1:80, N, TRUE))

# ---- Application-time risk (logit scale) -------------------------------------
lp <- -2.5 +
  unname(c(Regular=0, No_History=.3, Watchlist=.9, Classified=1.8)[cib]) +
  unname(c(Property=-.5, FDR_Deposit=-.7, Machinery=-.1, Unsecured=.5)[coll]) +
  unname(c(Trading=0, Manufacturing=-.15, Service=.1)[business_type]) +
  unname(sector_v[sector]) - 0.07*vintage + 0.9*pmin(ratio, 1.5) +
  0.12*n_exist - 0.01*(owner_age - 42)

# ---- Stage durations (days) + hand-off waits ---------------------------------
base <- c(2, 4, 3, 7, 3, 3)
br_legal <- unname(c(Motijheel=1, Gulshan=1, Chattogram=1.15, Rajshahi=1.9,
                     Khulna=1.1, Sylhet=1.25, Bogura=1.3)[branch])       # Rajshahi legal ~2x
ram <- in_any(app_date, ram_s, ram_e); pre_eid <- in_any(app_date, eid_d - 21, eid_d - 1)
season <- ifelse(ram, 1.3, 1) * ifelse(pre_eid, 1.1, 1)
dur <- sapply(1:6, function(j) {
  m <- base[j] * season * (if (j %in% c(2,3,5)) ifelse(loan_m > 15, 1.25, 1) else 1) *
       (if (j == 4) br_legal else 1)
  rgamma(N, shape = 2.5, rate = 2.5 / m)
})
wait <- cbind(0, sapply(2:6, function(j) rgamma(N, shape = 1.5, rate = 1.5 / (0.6 * season))))
cum_end <- t(apply(dur + wait, 1, cumsum))

# ---- Drop-off: rejection (risk-driven) and withdrawal (delay-driven) ---------
z <- lp + 2.6
p_rej <- list(rep(.02, N), plogis(-3 + .9*z), plogis(-3.1 + .9*z), rep(.03, N),
              plogis(-3.4 + .5*z), rep(0, N))
alive <- rep(TRUE, N); exit_idx <- rep(6L, N); status <- rep("Disbursed", N)
for (j in 1:6) {
  p_wd <- pmin(0.0015 * cum_end[, j], 0.15)
  rej <- alive & runif(N) < p_rej[[j]]
  wd  <- alive & !rej & runif(N) < p_wd
  status[rej] <- "Rejected"; status[wd] <- "Withdrawn"
  exit_idx[rej | wd] <- j
  alive <- alive & !rej & !wd
}
final_end <- app_ts + cum_end[cbind(seq_len(N), exit_idx)] * 86400
open <- final_end > snapshot
status[open] <- "In Progress"

# ---- Outcome: HIDDEN link -> longer Legal stage = higher default probability -
p_def <- plogis(lp + 0.06 * (pmin(dur[, 4], 40) - 7))
default_flag <- ifelse(status == "Disbursed", rbinom(N, 1, p_def), NA_integer_)

# ---- Assemble tables -----------------------------------------------------------
tf <- function(x) format(x, "%Y-%m-%d %H:%M:%S")
closed <- status != "In Progress"
applications <- data.frame(
  app_id = ids, app_date = format(app_date), branch, rm_id, business_type, sector,
  vintage_yrs = vintage, turnover_m = round(turnover, 2), loan_amount_m = round(loan_m, 2),
  debt_to_turnover = round(ratio, 4), tenor_m = tenor, collateral_type = coll,
  cib_status = cib, owner_age, n_existing_loans = n_exist, status,
  exit_stage = ifelse(closed & status != "Disbursed", stages[exit_idx], NA),
  total_tat_days = ifelse(closed, round(cum_end[cbind(seq_len(N), exit_idx)], 2), NA),
  legal_days = ifelse(closed & exit_idx >= 4, round(dur[, 4], 2), NA),
  default_flag, stringsAsFactors = FALSE)

ev <- do.call(rbind, lapply(1:6, function(j) {
  d <- data.frame(app_id = ids, stage_order = j, stage = stages[j],
    entered_at = app_ts + (cum_end[, j] - dur[, j]) * 86400,
    exited_at  = app_ts + cum_end[, j] * 86400,
    days_in_stage = dur[, j], wait_days = wait[, j], stringsAsFactors = FALSE)
  d[j <= exit_idx & d$entered_at <= snapshot, ]
}))
op <- ev$exited_at > snapshot
ev$exited_at[op] <- NA; ev$days_in_stage[op] <- NA
ev$entered_at <- tf(ev$entered_at); ev$exited_at <- tf(ev$exited_at)
ev$days_in_stage <- round(ev$days_in_stage, 2); ev$wait_days <- round(ev$wait_days, 2)
ev <- ev[order(ev$app_id, ev$stage_order), ]

con <- dbConnect(SQLite(), "data/sme_loans.sqlite")
dbWriteTable(con, "applications", applications, overwrite = TRUE)
dbWriteTable(con, "stage_events", ev, overwrite = TRUE)
dbExecute(con, "CREATE INDEX IF NOT EXISTS ix_ev ON stage_events(app_id, stage_order)")
dbDisconnect(con)
write.csv(applications, "data/applications.csv", row.names = FALSE)
write.csv(ev, "data/stage_events.csv", row.names = FALSE)
cat("Generated", N, "applications.\n"); print(table(applications$status))
cat("Default rate (disbursed):", round(mean(default_flag, na.rm = TRUE) * 100, 2), "%\n")
