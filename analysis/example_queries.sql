-- Example questions (load curated CSVs into SQLite/DBeaver or use in Power BI)

-- Peak ILI week per state
SELECT state, week_ending, wili_pct
FROM flu_weekly
ORDER BY wili_pct DESC
LIMIT 10;

-- Average weighted ILI by state
SELECT state, ROUND(AVG(wili_pct), 2) AS avg_wili
FROM flu_weekly
GROUP BY state
ORDER BY avg_wili DESC;

-- Highest hospital bed utilization
SELECT state, report_date, bed_utilization_pct
FROM hospital_daily
WHERE bed_utilization_pct IS NOT NULL
ORDER BY bed_utilization_pct DESC
LIMIT 10;
