-- Queries are split on the marker below; each block is run by 02_pipeline_analytics.R
-- name: stage_tat
SELECT stage_order, stage, COUNT(*) AS n_events,
       ROUND(AVG(days_in_stage),2) AS avg_days,
       ROUND(AVG(wait_days),2) AS avg_handoff_wait,
       ROUND(100.0*SUM(days_in_stage)/SUM(SUM(days_in_stage)) OVER (),1) AS pct_of_processing_time
FROM stage_events WHERE days_in_stage IS NOT NULL
GROUP BY stage_order, stage ORDER BY stage_order;

-- name: handoff_wait_lag
SELECT stage, ROUND(AVG(gap_days),2) AS avg_gap_days, ROUND(MAX(gap_days),1) AS max_gap_days
FROM (SELECT app_id, stage, stage_order,
             julianday(entered_at) - julianday(LAG(exited_at) OVER (PARTITION BY app_id ORDER BY stage_order)) AS gap_days
      FROM stage_events)
WHERE gap_days IS NOT NULL GROUP BY stage ORDER BY MIN(stage_order);

-- name: funnel
WITH reached AS (
  SELECT e.stage_order, e.stage, COUNT(DISTINCT e.app_id) AS n
  FROM stage_events e JOIN applications a USING(app_id)
  WHERE a.status <> 'In Progress' GROUP BY e.stage_order, e.stage)
SELECT stage, n,
       ROUND(100.0*n/FIRST_VALUE(n) OVER (ORDER BY stage_order),1) AS pct_of_applications,
       ROUND(100.0*(LAG(n) OVER (ORDER BY stage_order) - n)/LAG(n) OVER (ORDER BY stage_order),2) AS dropoff_pct_vs_prev_stage
FROM reached ORDER BY stage_order;

-- name: branch_stage_heatmap
SELECT a.branch, e.stage, e.stage_order, ROUND(AVG(e.days_in_stage),2) AS avg_days, COUNT(*) AS n
FROM stage_events e JOIN applications a USING(app_id)
WHERE e.days_in_stage IS NOT NULL GROUP BY a.branch, e.stage, e.stage_order;

-- name: monthly_volume_tat
SELECT substr(app_date,1,7) AS month, COUNT(*) AS applications,
       ROUND(AVG(total_tat_days),2) AS avg_tat_days,
       ROUND(100.0*SUM(status='Disbursed')/COUNT(*),1) AS disbursed_pct
FROM applications WHERE status <> 'In Progress' GROUP BY 1 ORDER BY 1;

-- name: legal_delay_vs_default
SELECT CASE WHEN legal_days<=5 THEN '1: <=5d' WHEN legal_days<=10 THEN '2: 6-10d'
            WHEN legal_days<=15 THEN '3: 11-15d' ELSE '4: >15d' END AS legal_band,
       COUNT(*) AS n, ROUND(100.0*AVG(default_flag),2) AS default_rate_pct
FROM applications WHERE status='Disbursed' GROUP BY 1 ORDER BY 1;

-- name: stuck_applications
WITH cur AS (SELECT app_id, stage, entered_at,
                    ROW_NUMBER() OVER (PARTITION BY app_id ORDER BY stage_order DESC) AS rn
             FROM stage_events)
SELECT a.app_id, a.branch, c.stage AS current_stage,
       ROUND(julianday('2025-06-30 23:59:59') - julianday(c.entered_at),1) AS days_in_stage
FROM cur c JOIN applications a USING(app_id)
WHERE c.rn = 1 AND a.status = 'In Progress' ORDER BY days_in_stage DESC LIMIT 50;
