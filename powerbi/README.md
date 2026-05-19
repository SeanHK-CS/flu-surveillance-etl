# Power BI setup

## Import (recommended)

1. Open **Power BI Desktop**
2. **Home → Get data → Text/CSV**
3. Select both files from `../data/curated/`:
   - `flu_weekly.csv`
   - `hospital_daily.csv`
4. Click **Load** (or Transform Data if you want Power Query tweaks)
5. Confirm types:
   - `week_ending` → Date
   - `report_date` → Date
   - Percent columns → Decimal number

**Quick demo without running the pipeline:** use `../data/samples/flu_weekly_sample.csv` and `hospital_daily_sample.csv`.

## Tables (do not merge)

| Table | Date column | Use on axis |
|-------|-------------|-------------|
| flu_weekly | `week_ending` | Weekly flu trends |
| hospital_daily | `report_date` | Daily hospital pressure |

## Suggested pages

1. **Flu trends** — Line: `week_ending` × `wili_pct`, Legend `state`
2. **Hospitals** — Line: `report_date` × `bed_utilization_pct`, Legend `state`
3. **By state** — Bar: average `wili_pct` by `state`
4. **KPIs** — Cards: max `wili_pct`, avg `bed_utilization_pct`

## Sample DAX

```dax
Latest WILI =
VAR LastWeek = MAX ( flu_weekly[week_ending] )
RETURN
    CALCULATE ( MAX ( flu_weekly[wili_pct] ), flu_weekly[week_ending] = LastWeek )

Avg Bed Utilization = AVERAGE ( hospital_daily[bed_utilization_pct] )
```

Column definitions: [`../data/DATA_DICTIONARY.md`](../data/DATA_DICTIONARY.md)
