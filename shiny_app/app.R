library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
apps <- readRDS("data/apps.rds")
ev <- readRDS("data/events.rds")
mon <- readRDS("data/monitor.rds")
stages <- c("Sales", "Credit", "Risk", "Legal", "Approval", "Disbursement")
scored <- apps %>% filter(status == "Disbursed", !is.na(score))
rng <- range(scored$score)

css <- r"---(
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');
body, .main-header .logo, h1, h2, h3, h4, h5, h6, .box-title { font-family: 'Inter','Segoe UI',Roboto,sans-serif !important; }
.content-wrapper, .right-side { background: linear-gradient(135deg,#eef2ff 0%,#f5f3ff 45%,#ecfeff 100%) !important; background-attachment: fixed; }

/* Header + sidebar */
.skin-blue .main-header .logo, .skin-blue .main-header .navbar { background: linear-gradient(90deg,#4f46e5,#7c3aed) !important; box-shadow: 0 4px 20px rgba(79,70,229,.25); }
.skin-blue .main-header .logo { font-weight: 700; letter-spacing: .3px; }
.skin-blue .main-sidebar { background: linear-gradient(180deg,#1e1b4b 0%,#312e81 100%) !important; box-shadow: 4px 0 24px rgba(30,27,75,.25); }
.skin-blue .sidebar-menu > li > a { border-radius: 12px; margin: 6px 12px; padding: 12px 15px; color: #c7d2fe; border-left: none !important; transition: all .2s; }
.skin-blue .sidebar-menu > li:hover > a, .skin-blue .sidebar-menu > li.active > a { background: rgba(255,255,255,.14) !important; color: #fff; box-shadow: 0 4px 14px rgba(0,0,0,.18); }

/* Page title */
.page-title { margin: 4px 0 18px 4px; }
.page-title h2 { margin: 0; font-weight: 700; color: #1e1b4b; font-size: 26px; }
.page-title p { margin: 4px 0 0; color: #6b7280; font-size: 14px; }

/* Glass cards */
.box { border-radius: 18px !important; border: 1px solid rgba(255,255,255,.7) !important; border-top: 1px solid rgba(255,255,255,.7) !important;
       background: rgba(255,255,255,.62) !important; backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
       box-shadow: 0 10px 34px rgba(79,70,229,.10), 0 2px 8px rgba(0,0,0,.04) !important; transition: box-shadow .25s, transform .25s; }
.box:hover { box-shadow: 0 14px 40px rgba(79,70,229,.16), 0 2px 8px rgba(0,0,0,.05) !important; }
.box.box-warning { border-left: 5px solid #f59e0b !important; }
.box-header { border-radius: 18px 18px 0 0; }
.box-header.with-border { border-bottom: 1px solid rgba(99,102,241,.12) !important; }
.box-title { font-weight: 600 !important; color: #312e81; font-size: 15px !important; }

/* Value boxes */
.small-box { border-radius: 18px !important; box-shadow: 0 10px 26px rgba(0,0,0,.14) !important; transition: transform .2s, box-shadow .2s; overflow: hidden; }
.small-box:hover { transform: translateY(-4px); box-shadow: 0 16px 34px rgba(0,0,0,.20) !important; }
.small-box h3 { font-weight: 700; font-size: 30px; }
.small-box p { font-size: 13px; opacity: .92; }
.small-box.bg-blue   { background: linear-gradient(135deg,#4f46e5,#7c3aed) !important; }
.small-box.bg-green  { background: linear-gradient(135deg,#059669,#10b981) !important; }
.small-box.bg-yellow { background: linear-gradient(135deg,#f59e0b,#fbbf24) !important; }
.small-box.bg-red    { background: linear-gradient(135deg,#dc2626,#f43f5e) !important; }
.small-box.bg-aqua   { background: linear-gradient(135deg,#0891b2,#22d3ee) !important; }
.small-box.bg-orange { background: linear-gradient(135deg,#ea580c,#fb923c) !important; }
.small-box.bg-maroon { background: linear-gradient(135deg,#be185d,#ec4899) !important; }
.small-box.bg-purple { background: linear-gradient(135deg,#6d28d9,#a78bfa) !important; }

/* Inputs */
.form-control, .selectize-input { border-radius: 12px !important; border: 1px solid #e0e7ff !important; background: rgba(255,255,255,.85) !important; box-shadow: inset 0 1px 3px rgba(0,0,0,.04) !important; }
.form-control:focus, .selectize-input.focus { border-color: #6366f1 !important; box-shadow: 0 0 0 3px rgba(99,102,241,.18) !important; }
.selectize-input .item { border-radius: 8px; background: #eef2ff; color: #3730a3; }
.irs--shiny .irs-bar, .irs-bar, .irs-bar-edge { background: #6366f1 !important; border-color: #6366f1 !important; }
.irs--shiny .irs-handle, .irs-slider { background: #4f46e5 !important; border: 3px solid #fff !important; box-shadow: 0 3px 10px rgba(79,70,229,.45) !important; }
.irs--shiny .irs-single, .irs--shiny .irs-from, .irs--shiny .irs-to { background: #4f46e5 !important; border-radius: 8px; }

/* Tables */
.shiny-html-output table { width: 100%; border-collapse: separate; border-spacing: 0; font-size: 13px; }
.shiny-html-output table th { color: #6b7280; font-size: 11px; text-transform: uppercase; letter-spacing: .6px; border-bottom: 2px solid #e0e7ff !important; padding: 8px 10px; }
.shiny-html-output table td { padding: 8px 10px; border-top: 1px solid #eef2ff !important; color: #1f2937; }
.shiny-html-output table tr:hover td { background: rgba(99,102,241,.07); }
)---"

ui <- dashboardPage(
  dashboardHeader(title = "CreditFlow | SME"),
  dashboardSidebar(sidebarMenu(
    menuItem("Management View", tabName = "mgmt", icon = icon("dashboard")),
    menuItem("Risk View", tabName = "risk", icon = icon("exclamation-triangle"))
  )),
  dashboardBody(tags$head(tags$style(HTML(css))), tabItems(
    tabItem(
      "mgmt",
      div(class = "page-title", h2("Pipeline Command Center"), p("Where do SME loans get stuck, and how long do they take?")),
      fluidRow(
        box(width = 4, selectInput("branch", "Branch", sort(unique(apps$branch)),
          selected = unique(apps$branch), multiple = TRUE
        )),
        box(width = 4, dateRangeInput(
          "dates", "Application date", min(apps$app_date),
          max(apps$app_date), min(apps$app_date), max(apps$app_date)
        )),
        box(width = 4, numericInput("stuck", "Stuck if days in current stage >=", 10, 1, 60))
      ),
      fluidRow(
        valueBoxOutput("v_apps", 3), valueBoxOutput("v_disb", 3),
        valueBoxOutput("v_tat", 3), valueBoxOutput("v_stuck", 3)
      ),
      fluidRow(
        box(title = "Pipeline funnel (apps reaching each stage)", width = 6, plotOutput("funnel", height = 280)),
        box(title = "Average days per stage", width = 6, plotOutput("tat", height = 280))
      ),
      fluidRow(
        box(title = "Bottleneck heatmap: branch x stage (avg days)", width = 7, plotOutput("heat", height = 300)),
        box(title = "Branch ranking (closed applications)", width = 5, tableOutput("rank"))
      ),
      fluidRow(box(title = "Stuck applications (open pipeline)", width = 12, tableOutput("stuck_tbl")))
    ),
    tabItem(
      "risk",
      div(class = "page-title", h2("Risk & Policy Simulator"), p("Move the cut-off to see approval rate, bad rate, Expected Loss and net income change live.")),
      fluidRow(box(
        title = "Policy assumptions (illustrative, not IDLC actuals; edit freely). EAD = loan amount, EL = PD x LGD x EAD, net income = (yield - funding/opex) x exposure - EL", width = 12, status = "warning",
        column(2, numericInput("lgd_prop", "LGD Property %", 25, 0, 100)),
        column(2, numericInput("lgd_fdr", "LGD FDR/Deposit %", 5, 0, 100)),
        column(2, numericInput("lgd_mach", "LGD Machinery %", 45, 0, 100)),
        column(2, numericInput("lgd_uns", "LGD Unsecured %", 75, 0, 100)),
        column(2, numericInput("yield", "Yield on exposure % p.a.", 14, 0, 40)),
        column(2, numericInput("cost", "Funding cost + opex % p.a.", 11, 0, 40))
      )),
      fluidRow(box(width = 12, sliderInput("cut", "Score cut-off (approve if score >= cut-off)",
        floor(rng[1]), ceiling(rng[2]), round(median(scored$score)),
        step = 1, width = "100%"
      ))),
      fluidRow(
        valueBoxOutput("r_appr", 3), valueBoxOutput("r_bad", 3),
        valueBoxOutput("r_expo", 3), valueBoxOutput("r_el", 3)
      ),
      fluidRow(
        valueBoxOutput("r_elr", 3), valueBoxOutput("r_loss", 3),
        valueBoxOutput("r_net", 3), valueBoxOutput("r_opt", 3)
      ),
      fluidRow(
        box(title = "Approval rate vs bad rate", width = 6, plotOutput("curve", height = 280)),
        box(title = "Expected Loss vs Net income after funding & opex (BDT m): where is the optimum?", width = 6, plotOutput("elcurve", height = 280))
      ),
      fluidRow(
        box(title = "Score distribution", width = 6, plotOutput("dist", height = 260)),
        box(title = "Model health: PSI trend", width = 6, plotOutput("psi", height = 260))
      ),
      fluidRow(box(title = "Model health: monthly KS / AUC / bad rate (* = under 200 loans, partial month, read with caution)", width = 12, tableOutput("health")))
    )
  ))
)

server <- function(input, output) {
  fa <- reactive({
    req(input$branch)
    apps %>% filter(
      branch %in% input$branch,
      app_date >= input$dates[1], app_date <= input$dates[2]
    )
  })
  closed <- reactive(fa() %>% filter(status != "In Progress"))
  stuck <- reactive(fa() %>% filter(status == "In Progress", days_in_current >= input$stuck))

  output$v_apps <- renderValueBox(valueBox(format(nrow(fa()), big.mark = ","), "Applications", color = "blue"))
  output$v_disb <- renderValueBox(valueBox(sprintf("%.1f%%", 100 * mean(closed()$status == "Disbursed")), "Disbursement rate", color = "green"))
  output$v_tat <- renderValueBox(valueBox(sprintf("%.1f d", median(closed()$total_tat_days, na.rm = TRUE)), "Median TAT", color = "yellow"))
  output$v_stuck <- renderValueBox(valueBox(nrow(stuck()), "Stuck applications", color = "red"))

  output$funnel <- renderPlot(bg = "transparent", {
    ids <- closed()$app_id
    df <- ev %>%
      filter(app_id %in% ids) %>%
      count(stage_order, stage) %>%
      mutate(stage = factor(stage, stages))
    ggplot(df, aes(stage, n)) +
      geom_col(fill = "#4f46e5") +
      geom_text(aes(label = n), vjust = -.3) +
      labs(x = NULL, y = "Applications") +
      theme_minimal(base_size = 12)
  })
  output$tat <- renderPlot(bg = "transparent", {
    df <- ev %>%
      filter(app_id %in% fa()$app_id, !is.na(days_in_stage)) %>%
      group_by(stage) %>%
      summarise(avg = mean(days_in_stage)) %>%
      mutate(stage = factor(stage, stages))
    ggplot(df, aes(stage, avg)) +
      geom_col(fill = "#f59e0b") +
      geom_text(aes(label = round(avg, 1)), vjust = -.3) +
      labs(x = NULL, y = "Avg days") +
      theme_minimal(base_size = 12)
  })
  output$heat <- renderPlot(bg = "transparent", {
    df <- ev %>%
      filter(app_id %in% fa()$app_id, !is.na(days_in_stage)) %>%
      group_by(branch, stage) %>%
      summarise(avg = mean(days_in_stage), .groups = "drop") %>%
      mutate(stage = factor(stage, stages))
    ggplot(df, aes(stage, branch, fill = avg)) +
      geom_tile(colour = "white") +
      geom_text(aes(label = round(avg, 1))) +
      scale_fill_gradient(low = "#fff5eb", high = "#d94801") +
      labs(x = NULL, y = NULL, fill = "Days") +
      theme_minimal(base_size = 12)
  })
  output$rank <- renderTable({
    closed() %>%
      group_by(Branch = branch) %>%
      summarise(
        Applications = n(), `Disbursed %` = round(100 * mean(status == "Disbursed"), 1),
        `Median TAT (d)` = round(median(total_tat_days, na.rm = TRUE), 1)
      ) %>%
      arrange(`Median TAT (d)`)
  })
  output$stuck_tbl <- renderTable({
    stuck() %>%
      arrange(desc(days_in_current)) %>%
      head(25) %>%
      transmute(
        Application = app_id, Branch = branch, `Current stage` = current_stage,
        `Days in stage` = round(days_in_current, 1), `Loan (BDT m)` = loan_amount_m
      )
  })

  sc <- reactive({
    lg <- c(
      Property = input$lgd_prop, FDR_Deposit = input$lgd_fdr,
      Machinery = input$lgd_mach, Unsecured = input$lgd_uns
    ) / 100
    scored %>% mutate(
      lgd = unname(lg[collateral_type]), el = pd * lgd * loan_amount_m,
      loss = default_flag * lgd * loan_amount_m
    )
  })
  kpi <- function(d, cut, yld) {
    a <- d[d$score >= cut, ]
    data.frame(
      cut = cut, approval = 100 * nrow(a) / nrow(d),
      bad = ifelse(nrow(a) > 0, 100 * mean(a$default_flag), NA),
      expo = sum(a$loan_amount_m), el = sum(a$el), loss = sum(a$loss),
      net = yld / 100 * sum(a$loan_amount_m) - sum(a$el)
    )
  }
  sim <- reactive(kpi(sc(), input$cut, input$yield - input$cost))
  grid <- reactive({
    cs <- seq(floor(rng[1]), ceiling(rng[2]), length.out = 60)
    do.call(rbind, lapply(cs, function(x) kpi(sc(), x, input$yield - input$cost)))
  })
  bm <- function(v, u) sprintf("%s BDT m", format(round(v, 1), big.mark = ","))
  output$r_appr <- renderValueBox(valueBox(sprintf("%.1f%%", sim()$approval), "Approval rate", color = "blue"))
  output$r_bad <- renderValueBox(valueBox(sprintf("%.2f%%", sim()$bad), "Bad rate (approved)", color = "red"))
  output$r_expo <- renderValueBox(valueBox(bm(sim()$expo), "Approved exposure (EAD)", color = "aqua"))
  output$r_el <- renderValueBox(valueBox(bm(sim()$el), "Expected Loss (PD x LGD x EAD)", color = "orange"))
  output$r_elr <- renderValueBox(valueBox(sprintf("%.2f%%", 100 * sim()$el / max(sim()$expo, 1e-9)), "EL as % of exposure", color = "yellow"))
  output$r_loss <- renderValueBox(valueBox(bm(sim()$loss), "Simulated realised loss", color = "maroon"))
  output$r_net <- renderValueBox(valueBox(bm(sim()$net), "Net income after EL, funding & opex", color = "green"))
  output$r_opt <- renderValueBox({
    g <- grid()
    valueBox(round(g$cut[which.max(g$net)]), "Cut-off maximising net income", color = "purple")
  })
  long2 <- function(df, cols) do.call(rbind, lapply(cols, function(cn) data.frame(cut = df$cut, metric = cn, value = df[[cn]])))
  output$dist <- renderPlot(bg = "transparent", {
    ggplot(scored, aes(score, fill = factor(default_flag, labels = c("Good", "Bad")))) +
      geom_histogram(bins = 40, position = "identity", alpha = .6) +
      geom_vline(xintercept = input$cut, linetype = 2) +
      scale_fill_manual(values = c("#10b981", "#ef4444")) +
      labs(fill = NULL, x = "Score", y = "Loans") +
      theme_minimal(base_size = 12)
  })
  output$curve <- renderPlot(bg = "transparent", {
    g <- grid()
    names(g)[names(g) == "approval"] <- "Approval rate %"
    names(g)[names(g) == "bad"] <- "Bad rate %"
    ggplot(long2(g, c("Approval rate %", "Bad rate %")), aes(cut, value, colour = metric)) +
      geom_line(linewidth = 1) +
      geom_vline(xintercept = input$cut, linetype = 2) +
      labs(x = "Cut-off", y = "%", colour = NULL) +
      theme_minimal(base_size = 12)
  })
  output$elcurve <- renderPlot(bg = "transparent", {
    g <- grid()
    nn <- "Net income after EL, funding & opex"
    names(g)[names(g) == "el"] <- "Expected Loss"
    names(g)[names(g) == "net"] <- nn
    best <- g$cut[which.max(g[[nn]])]
    ggplot(long2(g, c("Expected Loss", nn)), aes(cut, value, colour = metric)) +
      geom_hline(yintercept = 0, colour = "grey60") +
      geom_line(linewidth = 1.1) +
      geom_vline(xintercept = input$cut, linetype = 2) +
      geom_vline(xintercept = best, linetype = 3, colour = "#6b46c1") +
      annotate("text",
        x = best, y = Inf, label = paste("optimum", round(best)), vjust = 1.5, hjust = -0.1,
        colour = "#6b46c1", size = 3.5
      ) +
      labs(x = "Cut-off (dashed = your slider, purple dotted = optimum)", y = "BDT million", colour = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "bottom")
  })
  output$psi <- renderPlot(bg = "transparent", {
    m <- mon$monitor
    ggplot(m, aes(month, score_psi, group = 1)) +
      geom_line(linewidth = 1, colour = "#4f46e5") +
      geom_point(aes(shape = n < 200), size = 3, colour = "#4f46e5") +
      scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 1), guide = "none") +
      geom_hline(yintercept = c(.10, .25), linetype = 2, colour = c("orange", "red")) +
      labs(x = NULL, y = "Score PSI", caption = "0.10 = watch, 0.25 = retrain. Hollow point = under 200 loans (partial month)") +
      theme_minimal(base_size = 12) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1))
  })
  output$health <- renderTable({
    m <- mon$monitor
    data.frame(
      Month = ifelse(m$n < 200, paste0(m$month, " *"), m$month), N = m$n, KS = round(100 * m$KS, 1), AUC = round(m$AUC, 3),
      `Bad %` = round(100 * m$actual_bad_rate, 2), `PSI` = round(m$score_psi, 3), check.names = FALSE
    )
  })
}
shinyApp(ui, server)
