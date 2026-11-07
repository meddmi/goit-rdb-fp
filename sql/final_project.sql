-- Final project: infectious_cases (PostgreSQL)
-- All SQL from final_project.ipynb in execution order.
--
-- The raw table pandemic.infectious_cases is filled from data/infectious_cases.csv.
-- In the notebook this is done with pandas; in psql the equivalent is:
--   \copy infectious_cases FROM 'data/infectious_cases.csv' WITH (FORMAT csv, HEADER true)
-- (all raw columns are TEXT and missing values are empty strings, as in the notebook)

-- ======================================================================
-- [1] Task 1. Create the pandemic schema and set it as default
-- ======================================================================
CREATE SCHEMA IF NOT EXISTS pandemic;
SET search_path TO pandemic;

-- ======================================================================
-- [2] Task 1. Check the default schema
-- ======================================================================
SELECT current_schema() AS default_schema,
       current_setting('search_path') AS search_path,
       current_setting('server_version') AS server_version;

-- ======================================================================
-- [3] Task 1. Create the raw table (filled from the CSV, see header)
-- ======================================================================
DROP TABLE IF EXISTS infectious_cases CASCADE;

CREATE TABLE infectious_cases (
    entity               TEXT,
    code                 TEXT,
    year                 TEXT,
    number_yaws          TEXT,
    polio_cases          TEXT,
    cases_guinea_worm    TEXT,
    number_rabies        TEXT,
    number_malaria       TEXT,
    number_hiv           TEXT,
    number_tuberculosis  TEXT,
    number_smallpox      TEXT,
    number_cholera_cases TEXT
);

-- ======================================================================
-- [4] Task 1. Preview the data
-- ======================================================================
SELECT *
FROM infectious_cases
LIMIT 10;

-- ======================================================================
-- [5] Task 1. Profile the data: row counts, entities, years, empty values
-- ======================================================================
SELECT
    COUNT(*)                                           AS total_rows,
    COUNT(DISTINCT entity)                             AS total_entities,
    COUNT(DISTINCT NULLIF(code, ''))                   AS total_codes,
    MIN(year::INTEGER)                                 AS min_year,
    MAX(year::INTEGER)                                 AS max_year,
    COUNT(*) FILTER (WHERE code = '')                  AS empty_code,
    COUNT(*) FILTER (WHERE number_rabies = '')         AS empty_rabies,
    COUNT(*) FILTER (WHERE number_malaria = '')        AS empty_malaria,
    COUNT(*) FILTER (WHERE polio_cases = '')           AS empty_polio,
    COUNT(*) FILTER (WHERE number_yaws = '')           AS empty_yaws
FROM infectious_cases;

-- ======================================================================
-- [6] Task 1. Check that indicator columns contain only numbers or empty strings
-- ======================================================================
SELECT t.column_name,
       COUNT(*) FILTER (WHERE t.value = '') AS blank,
       COUNT(*) FILTER (WHERE t.value ~ '^[0-9]+(\.[0-9]+)?$') AS numeric_values,
       COUNT(*) FILTER (WHERE t.value <> '' AND t.value !~ '^[0-9]+(\.[0-9]+)?$') AS other_values
FROM infectious_cases
CROSS JOIN LATERAL (
    VALUES
        ('year', year),
        ('number_yaws', number_yaws),
        ('polio_cases', polio_cases),
        ('cases_guinea_worm', cases_guinea_worm),
        ('number_rabies', number_rabies),
        ('number_malaria', number_malaria),
        ('number_hiv', number_hiv),
        ('number_tuberculosis', number_tuberculosis),
        ('number_smallpox', number_smallpox),
        ('number_cholera_cases', number_cholera_cases)
) AS t (column_name, value)
GROUP BY t.column_name
ORDER BY t.column_name;

-- ======================================================================
-- [7] Task 2. Create the normalized tables entities and disease_cases
-- ======================================================================
DROP TABLE IF EXISTS disease_cases CASCADE;
DROP TABLE IF EXISTS entities CASCADE;

CREATE TABLE entities (
    entity_id    INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    entity_name  TEXT NOT NULL UNIQUE,
    entity_code  TEXT UNIQUE
);

CREATE TABLE disease_cases (
    entity_id            INTEGER  NOT NULL REFERENCES entities (entity_id),
    year                 SMALLINT NOT NULL,
    number_yaws          NUMERIC CHECK (number_yaws          >= 0),
    polio_cases          NUMERIC CHECK (polio_cases          >= 0),
    cases_guinea_worm    NUMERIC CHECK (cases_guinea_worm    >= 0),
    number_rabies        NUMERIC CHECK (number_rabies        >= 0),
    number_malaria       NUMERIC CHECK (number_malaria       >= 0),
    number_hiv           NUMERIC CHECK (number_hiv           >= 0),
    number_tuberculosis  NUMERIC CHECK (number_tuberculosis  >= 0),
    number_smallpox      NUMERIC CHECK (number_smallpox      >= 0),
    number_cholera_cases NUMERIC CHECK (number_cholera_cases >= 0),
    PRIMARY KEY (entity_id, year)
);

-- ======================================================================
-- [8] Task 2. Fill the normalized tables
-- ======================================================================
INSERT INTO entities (entity_name, entity_code)
SELECT DISTINCT entity, NULLIF(code, '')
FROM infectious_cases
ORDER BY entity;

INSERT INTO disease_cases (
    entity_id,
    year,
    number_yaws, 
    polio_cases,
    cases_guinea_worm,
    number_rabies,
    number_malaria,
    number_hiv,
    number_tuberculosis,
    number_smallpox,
    number_cholera_cases
)
SELECT
    e.entity_id,
    ic.year::SMALLINT,
    NULLIF(ic.number_yaws, '')::NUMERIC,
    NULLIF(ic.polio_cases, '')::NUMERIC,
    NULLIF(ic.cases_guinea_worm, '')::NUMERIC,
    NULLIF(ic.number_rabies, '')::NUMERIC,
    NULLIF(ic.number_malaria, '')::NUMERIC,
    NULLIF(ic.number_hiv, '')::NUMERIC,
    NULLIF(ic.number_tuberculosis, '')::NUMERIC,
    NULLIF(ic.number_smallpox, '')::NUMERIC,
    NULLIF(ic.number_cholera_cases, '')::NUMERIC
FROM infectious_cases AS ic
JOIN entities AS e
    ON e.entity_name = ic.entity;

-- ======================================================================
-- [9] Task 2. Compare row counts of raw and normalized tables
-- ======================================================================
SELECT 'infectious_cases (raw)' AS table_name, COUNT(*) AS n_rows 
FROM infectious_cases
UNION ALL
SELECT 'entities', COUNT(*) 
FROM entities
UNION ALL
SELECT 'disease_cases', COUNT(*) 
FROM disease_cases;

-- ======================================================================
-- [10] Task 2. Preview entities
-- ======================================================================
SELECT *
FROM entities
ORDER BY entity_id
LIMIT 10;

-- ======================================================================
-- [11] Task 2. Preview disease_cases
-- ======================================================================
SELECT *
FROM disease_cases
WHERE number_rabies IS NOT NULL
ORDER BY entity_id, year
LIMIT 10;

-- ======================================================================
-- [12] Task 2. Lossless check: both numbers must be 0
-- ======================================================================
WITH restored AS (
    SELECT e.entity_name AS entity,
           e.entity_code AS code,
           dc.year,
           dc.number_yaws, dc.polio_cases, dc.cases_guinea_worm, dc.number_rabies,
           dc.number_malaria, dc.number_hiv, dc.number_tuberculosis,
           dc.number_smallpox, dc.number_cholera_cases
    FROM disease_cases AS dc
    JOIN entities AS e USING (entity_id)
),
original AS (
    SELECT entity,
           NULLIF(code, '') AS code,
           year::SMALLINT AS year,
           NULLIF(number_yaws, '')::NUMERIC AS number_yaws,
           NULLIF(polio_cases, '')::NUMERIC AS polio_cases,
           NULLIF(cases_guinea_worm, '')::NUMERIC AS cases_guinea_worm,
           NULLIF(number_rabies, '')::NUMERIC AS number_rabies,
           NULLIF(number_malaria, '')::NUMERIC AS number_malaria,
           NULLIF(number_hiv, '')::NUMERIC AS number_hiv,
           NULLIF(number_tuberculosis, '')::NUMERIC AS number_tuberculosis,
           NULLIF(number_smallpox, '')::NUMERIC AS number_smallpox,
           NULLIF(number_cholera_cases, '')::NUMERIC AS number_cholera_cases
    FROM infectious_cases
)
SELECT
    (SELECT COUNT(*) FROM (SELECT * FROM original EXCEPT SELECT * FROM restored) AS t) AS missing_in_normalized,
    (SELECT COUNT(*) FROM (SELECT * FROM restored EXCEPT SELECT * FROM original) AS t) AS extra_in_normalized;

-- ======================================================================
-- [13] Task 3. Rabies avg / min / max / sum per entity, top 10 by average
-- ======================================================================
SELECT
    e.entity_id,
    e.entity_name,
    e.entity_code,
    ROUND(AVG(dc.number_rabies), 2) AS avg_rabies,
    ROUND(MIN(dc.number_rabies), 2) AS min_rabies,
    ROUND(MAX(dc.number_rabies), 2) AS max_rabies,
    ROUND(SUM(dc.number_rabies), 2) AS sum_rabies,
    COUNT(dc.number_rabies)         AS n_years
FROM disease_cases AS dc
JOIN entities AS e USING (entity_id)
WHERE dc.number_rabies IS NOT NULL
GROUP BY e.entity_id, e.entity_name, e.entity_code
ORDER BY AVG(dc.number_rabies) DESC
LIMIT 10;

-- ======================================================================
-- [14] Task 3. Same query for countries only (reference)
-- ======================================================================
SELECT
    e.entity_id,
    e.entity_name,
    e.entity_code,
    ROUND(AVG(dc.number_rabies), 2) AS avg_rabies,
    ROUND(MIN(dc.number_rabies), 2) AS min_rabies,
    ROUND(MAX(dc.number_rabies), 2) AS max_rabies,
    ROUND(SUM(dc.number_rabies), 2) AS sum_rabies,
    COUNT(dc.number_rabies)         AS n_years
FROM disease_cases AS dc
JOIN entities AS e USING (entity_id)
WHERE dc.number_rabies IS NOT NULL
  AND e.entity_code IS NOT NULL
  AND e.entity_code NOT LIKE 'OWID\_%'
GROUP BY e.entity_id, e.entity_name, e.entity_code
ORDER BY AVG(dc.number_rabies) DESC
LIMIT 10;

-- ======================================================================
-- [15] Task 4. Year difference column with built-in functions
-- ======================================================================
SELECT
    e.entity_name,
    dc.year,
    MAKE_DATE(dc.year, 1, 1) AS year_start_date,
    CURRENT_DATE AS today,
    EXTRACT(YEAR FROM AGE(CURRENT_DATE, MAKE_DATE(dc.year, 1, 1)))::INTEGER AS years_diff
FROM disease_cases AS dc
JOIN entities AS e USING (entity_id)
ORDER BY e.entity_name, dc.year
LIMIT 10;

-- ======================================================================
-- [16] Task 5. Create fn_years_since(year)
-- ======================================================================
CREATE OR REPLACE FUNCTION fn_years_since(p_year INTEGER)
RETURNS INTEGER
LANGUAGE sql
STABLE
STRICT
AS $$
    SELECT EXTRACT(YEAR FROM AGE(CURRENT_DATE, MAKE_DATE(p_year, 1, 1)))::INTEGER;
$$;

-- ======================================================================
-- [17] Task 5. Test fn_years_since on 1996
-- ======================================================================
SELECT 
    1996 AS year_value,
    make_date(1996, 1, 1) AS year_start,
    CURRENT_DATE AS today,
    fn_years_since(1996) AS years_diff;

-- ======================================================================
-- [18] Task 5. Use fn_years_since on the table
-- ======================================================================
SELECT 
    e.entity_name,
    dc.year,
    fn_years_since(dc.year) AS years_diff
FROM disease_cases AS dc
JOIN entities AS e USING (entity_id)
ORDER BY e.entity_name, dc.year
LIMIT 10;

-- ======================================================================
-- [19] Task 5. Create fn_avg_cases_per_period(cases_per_year, divisor)
-- ======================================================================
CREATE OR REPLACE FUNCTION fn_avg_cases_per_period(p_cases_per_year NUMERIC, p_divisor NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_cases_per_year / NULLIF(p_divisor, 0);
$$;

-- ======================================================================
-- [20] Task 5. Test divisors 12 (month), 4 (quarter), 2 (half-year)
-- ======================================================================
SELECT 
    ROUND(fn_avg_cases_per_period(1200, 12), 2) AS per_month,
    ROUND(fn_avg_cases_per_period(1200, 4), 2) AS per_quarter,
    ROUND(fn_avg_cases_per_period(1200, 2), 2) AS per_half_year,
    fn_avg_cases_per_period(NULL, 12) AS null_cases,
    fn_avg_cases_per_period(1200, 0) AS zero_divisor;

-- ======================================================================
-- [21] Task 5. Use both functions on numeric rabies records
-- ======================================================================
SELECT e.entity_name,
       dc.year,
       fn_years_since(dc.year) AS years_diff,
       ROUND(dc.number_rabies, 4) AS cases_per_year,
       ROUND(fn_avg_cases_per_period(dc.number_rabies, 12), 4) AS avg_per_month,
       ROUND(fn_avg_cases_per_period(dc.number_rabies, 4), 4) AS avg_per_quarter,
       ROUND(fn_avg_cases_per_period(dc.number_rabies, 2), 4) AS avg_per_half_year
FROM disease_cases AS dc
JOIN entities AS e USING (entity_id)
WHERE dc.number_rabies IS NOT NULL  -- numeric records only
ORDER BY e.entity_name, dc.year
LIMIT 10;
