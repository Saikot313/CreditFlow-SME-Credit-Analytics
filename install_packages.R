pk <- c("dplyr","lubridate","DBI","RSQLite","ggplot2","survival","scorecard",
        "xgboost","ranger","shiny","shinydashboard","rsconnect")
install.packages(setdiff(pk, rownames(installed.packages())))
