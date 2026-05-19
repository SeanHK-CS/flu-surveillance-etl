-- Calculate Rolling Averages and Trend Indicators for Search Interest
-- Updates fact_search_interest_daily with calculated metrics

-- ============================================================================
-- Function: Calculate and Update Rolling Averages for Search Interest
-- ============================================================================

CREATE OR REPLACE FUNCTION transform.update_search_interest_rolling_averages(
    p_start_date_id INTEGER DEFAULT NULL,
    p_end_date_id INTEGER DEFAULT NULL
)
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_row RECORD;
    v_7day_avg DECIMAL;
    v_30day_avg DECIMAL;
    v_previous_7day_avg DECIMAL;
    v_trend VARCHAR(20);
    v_percent_change_7day DECIMAL;
    v_percent_change_30day DECIMAL;
BEGIN
    -- Update rolling averages for search interest
    FOR v_row IN
        SELECT 
            f.fact_id,
            f.date_id,
            f.location_id,
            f.source_id,
            f.search_interest,
            d.full_date
        FROM facts.fact_search_interest_daily f
        JOIN dimensions.dim_date d ON f.date_id = d.date_id
        WHERE (p_start_date_id IS NULL OR f.date_id >= p_start_date_id)
          AND (p_end_date_id IS NULL OR f.date_id <= p_end_date_id)
        ORDER BY f.location_id, f.source_id, d.full_date
    LOOP
        BEGIN
            -- Calculate 7-day rolling average
            SELECT AVG(f2.search_interest)::DECIMAL
            INTO v_7day_avg
            FROM facts.fact_search_interest_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '7 days';
            
            -- Calculate 30-day rolling average
            SELECT AVG(f2.search_interest)::DECIMAL
            INTO v_30day_avg
            FROM facts.fact_search_interest_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date
              AND d2.full_date > v_row.full_date - INTERVAL '30 days';
            
            -- Get previous period's 7-day average (2 weeks ago) for trend calculation
            SELECT AVG(f2.search_interest)::DECIMAL
            INTO v_previous_7day_avg
            FROM facts.fact_search_interest_daily f2
            JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
            WHERE f2.location_id = v_row.location_id
              AND f2.source_id = v_row.source_id
              AND d2.full_date <= v_row.full_date - INTERVAL '14 days'
              AND d2.full_date > v_row.full_date - INTERVAL '21 days';
            
            -- Calculate percent changes
            IF v_previous_7day_avg > 0 AND v_7day_avg IS NOT NULL THEN
                v_percent_change_7day := ((v_7day_avg - v_previous_7day_avg) / v_previous_7day_avg) * 100;
            ELSE
                v_percent_change_7day := NULL;
            END IF;
            
            -- Get 30-day ago value for 30-day change
            DECLARE
                v_30day_ago_value DECIMAL;
            BEGIN
                SELECT AVG(f2.search_interest)::DECIMAL
                INTO v_30day_ago_value
                FROM facts.fact_search_interest_daily f2
                JOIN dimensions.dim_date d2 ON f2.date_id = d2.date_id
                WHERE f2.location_id = v_row.location_id
                  AND f2.source_id = v_row.source_id
                  AND d2.full_date <= v_row.full_date - INTERVAL '30 days'
                  AND d2.full_date > v_row.full_date - INTERVAL '37 days';
                
                IF v_30day_ago_value > 0 AND v_30day_avg IS NOT NULL THEN
                    v_percent_change_30day := ((v_30day_avg - v_30day_ago_value) / v_30day_ago_value) * 100;
                ELSE
                    v_percent_change_30day := NULL;
                END IF;
            END;
            
            -- Calculate trend based on 2-week change
            v_trend := transform.calculate_trend(
                p_current_value := v_7day_avg,
                p_previous_value := v_previous_7day_avg,
                p_change_threshold := 0.10  -- 10% threshold
            );
            
            -- Update the fact table
            UPDATE facts.fact_search_interest_daily
            SET 
                search_interest_7day_avg = v_7day_avg,
                search_interest_30day_avg = v_30day_avg,
                trend_flag = v_trend,
                percent_change_7day = v_percent_change_7day,
                percent_change_30day = v_percent_change_30day,
                updated_timestamp = CURRENT_TIMESTAMP
            WHERE fact_id = v_row.fact_id;
            
            v_updated := v_updated + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error updating rolling averages for fact_id %: %', v_row.fact_id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_updated, v_errors;
END;
$$;

-- Quick update function
CREATE OR REPLACE FUNCTION transform.update_search_interest_rolling_averages()
RETURNS TABLE(
    rows_updated INTEGER,
    errors INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM transform.update_search_interest_rolling_averages(
        p_start_date_id := NULL,
        p_end_date_id := NULL
    );
END;
$$;
