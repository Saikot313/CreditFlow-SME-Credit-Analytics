# One-time: paste YOUR values from shinyapps.io -> Account -> Tokens -> Show Secret
# rsconnect::setAccountInfo(name = "YOUR_ACCOUNT", token = "YOUR_TOKEN", secret = "YOUR_SECRET")

stopifnot(file.exists("shiny_app/data/apps.rds"))   # run source("run_all.R") first
shiny::runApp("shiny_app", launch.browser = TRUE)    # test locally BEFORE deploying (close it, then continue)
rsconnect::deployApp("shiny_app", appName = "creditflow-sme", forceUpdate = TRUE)
