-- ============================================
-- A/B Testing - Mobile Game
-- SQL Queries for Data Analysis
-- ============================================

-- 1. Базовый обзор данных
SELECT 
    COUNT(*) as total_users, -- 90189
    COUNT(DISTINCT user_id) as unique_users, -- 90189
    COUNT(*) - COUNT(DISTINCT user_id) as duplicate_ids, -- 0
    SUM(CASE WHEN retention_1 IS NULL THEN 1 ELSE 0 END) as null_retention_1, -- 0
    SUM(CASE WHEN retention_7 IS NULL THEN 1 ELSE 0 END) as null_retention_7, -- 0
    SUM(CASE WHEN sum_gamerounds IS NULL THEN 1 ELSE 0 END) as null_gamerounds -- 0
FROM game_with_cats
WHERE sum_gamerounds <= 40000;

-- 2. Распределение по версиям
SELECT 
    version, -- 30/40
    COUNT(*) as users, -- 44700/45489
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage -- 49.56/50.44
FROM game_with_cats
WHERE sum_gamerounds <= 40000
GROUP BY version;

-- 3. Retention rates по версиям
SELECT 
    version, -- 30/40
    ROUND(AVG(retention_1::int), 4) as retention_1_rate, -- 0.4482/0.4423
    ROUND(AVG(retention_7::int), 4) as retention_7_rate, -- 0.1902/0.1820
    ROUND(AVG(retention_7::int) - AVG(retention_1::int), 4) as retention_drop -- -0.258/-0.2603
FROM game_with_cats
WHERE sum_gamerounds <= 40000
GROUP BY version;

-- 4. Статистика по игровым раундам
SELECT 
    version, -- 30/40
    COUNT(*) as users, -- 44700/45489
    ROUND(AVG(sum_gamerounds), 2) as mean_rounds, -- 52.46/51.30
    ROUND(PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY sum_gamerounds), 0) as median_rounds, -- 17/16
    MIN(sum_gamerounds) as min_rounds, -- 0/0
    MAX(sum_gamerounds) as max_rounds, -- 49854/2640
    ROUND(PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY sum_gamerounds), 0) as p99_rounds -- 493/493
FROM game_with_cats
WHERE sum_gamerounds <= 40000
GROUP BY version;

-- 5. Выбросы (экстремальные значения)
WITH stats AS (
    SELECT 
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY sum_gamerounds) as q3,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY sum_gamerounds) as q1
    FROM game_with_cats
	WHERE sum_gamerounds <= 40000
)
SELECT 
    version,
    COUNT(*) as outliers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM game_with_cats), 2) as pct
FROM game_with_cats, stats
WHERE sum_gamerounds > (q3 + 1.5 * (q3 - q1))
GROUP BY version;

-- 6. Распределение retention по раундам и sum_gamerounds по активности (сегментация)
WITH segments AS (
    SELECT 
        user_id,
        version,
        sum_gamerounds,
        retention_1,
        retention_7,
        CASE 
            WHEN sum_gamerounds <= 10 THEN '0-10'
            WHEN sum_gamerounds <= 50 THEN '11-50'
            WHEN sum_gamerounds <= 100 THEN '51-100'
            WHEN sum_gamerounds > 100 THEN '100+'
        END as rounds_segment
    FROM game_with_cats
	WHERE sum_gamerounds <= 40000
)
SELECT 
    version,
    rounds_segment,
    COUNT(*) as users,
    ROUND(AVG(retention_1::int), 4) as retention_1,
    ROUND(AVG(retention_7::int), 4) as retention_7
FROM segments
GROUP BY version, rounds_segment
ORDER BY version, rounds_segment;

-- 7. Когортный анализ (по дням активности)
SELECT 
    version, -- 30/40
    SUM(retention_1::int) as retained_day1, -- 20034/20119
    SUM(retention_7::int) as retained_day7, -- 8502/8279
    SUM(retention_1::int) - SUM(retention_7::int) as churned_between, -- 11532/11840
    ROUND(SUM(retention_7::int) * 100.0 / NULLIF(SUM(retention_1::int), 0), 2) as retention_rate_from_day1 -- 42.44/41.15
FROM game_with_cats
WHERE sum_gamerounds <= 40000
GROUP BY version;

-- 8. Проверка на SRM (Sample Ratio Mismatch)
WITH totals AS (
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN version = 'gate_30' THEN 1 ELSE 0 END) as gate_30_count,
        SUM(CASE WHEN version = 'gate_40' THEN 1 ELSE 0 END) as gate_40_count
    FROM game_with_cats
	WHERE sum_gamerounds <= 40000
)
SELECT 
    total, -- 90189
    gate_30_count, -- 44700
    gate_40_count, -- 45489
    ROUND(gate_30_count * 100.0 / total, 2) as gate_30_pct, -- 49.56
    ROUND(gate_40_count * 100.0 / total, 2) as gate_40_pct, -- 50.44
    ROUND(ABS(gate_30_count - gate_40_count) * 100.0 / total, 2) as imbalance_pct -- 0.87
FROM totals;

