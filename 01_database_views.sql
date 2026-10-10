-- ==============================================================================
-- PROJECT: Global Tech & Data Job Market Analytics
-- TOOLS: MySQL + Microsoft Power BI
-- PURPOSE: Production-ready SQL views & schemas optimized for Power BI Direct/Import
-- ==============================================================================

-- 1. Fact Table View: Cleaned Job Postings
-- Standardizes data types, handles nulls, and pre-calculates flags for Power BI
CREATE OR REPLACE VIEW v_fact_job_postings AS
SELECT 
    id AS job_id,
    job_title_short,
    job_country,
    company_name,
    job_via AS job_platform,
    CASE 
        WHEN job_work_from_home = 1 THEN 'Remote'
        ELSE 'Onsite/Hybrid'
    END AS work_type,
    job_work_from_home AS is_remote,
    job_schedule_type,
    posted_date,
    CAST(posted_date AS DATE) AS posting_date,
    EXTRACT(YEAR FROM posted_date) AS posting_year,
    EXTRACT(MONTH FROM posted_date) AS posting_month,
    MONTHNAME(posted_date) AS posting_month_name,
    salary_year,
    salary_hour,
    CASE 
        WHEN salary_year IS NOT NULL THEN salary_year
        WHEN salary_hour IS NOT NULL THEN salary_hour * 2080 -- Standard 40 hrs/wk * 52 wks
        ELSE NULL 
    END AS normalized_annual_salary,
    degree_mentioned,
    health_insurance,
    CASE 
        WHEN degree_mentioned = 0 AND health_insurance = 1 THEN 1 
        ELSE 0 
    END AS is_accessible_with_benefits
FROM cleaned_salaries;

-- 2. Skills Bridge View: Job to Skills Mapping
-- Optimized for relational star schema join (1-to-many relationship with v_fact_job_postings)
CREATE OR REPLACE VIEW v_job_skills AS
SELECT 
    job_id,
    TRIM(LOWER(skill_name)) AS skill_key,
    TRIM(skill_name) AS skill_name
FROM job_to_skills_map
WHERE skill_name IS NOT NULL AND skill_name != '';

-- 3. Job Level Aggregation: Skill Density & Multi-Skill Flag
-- Pre-calculates whether a job is single-skill or multi-skill
CREATE OR REPLACE VIEW v_job_skill_density AS
SELECT 
    job_id,
    COUNT(DISTINCT skill_name) AS skill_count,
    CASE 
        WHEN COUNT(DISTINCT skill_name) = 1 THEN 'Single-Skill Posting'
        WHEN COUNT(DISTINCT skill_name) BETWEEN 2 AND 4 THEN 'Moderate (2-4 Skills)'
        ELSE 'Multi-Skill Heavy (5+ Skills)'
    END AS skill_density_tier,
    MAX(CASE WHEN LOWER(skill_name) = 'sql' THEN 1 ELSE 0 END) AS has_sql
FROM job_to_skills_map
GROUP BY job_id;

-- 4. Analytical Summary View: Skills Demand vs Salary Premium (Skills Gap Analysis)
CREATE OR REPLACE VIEW v_skills_market_benchmark AS
SELECT 
    j.skill_name,
    COUNT(DISTINCT c.id) AS total_job_postings,
    COUNT(DISTINCT CASE WHEN c.salary_year IS NOT NULL THEN c.id END) AS salary_sample_size,
    ROUND(AVG(c.salary_year), 2) AS avg_annual_salary,
    ROUND(MIN(c.salary_year), 2) AS min_annual_salary,
    ROUND(MAX(c.salary_year), 2) AS max_annual_salary,
    CASE 
        WHEN COUNT(DISTINCT c.id) >= 4000 THEN 'High Demand Core Tool'
        WHEN COUNT(DISTINCT c.id) BETWEEN 500 AND 3999 THEN 'Moderate Demand Tool'
        ELSE 'Niche / Specialized Tool'
    END AS market_tier
FROM job_to_skills_map j
JOIN cleaned_salaries c ON j.job_id = c.id
GROUP BY j.skill_name;

-- 5. Analytical View: Role & Country Compensation Benchmarks
CREATE OR REPLACE VIEW v_role_country_salaries AS
SELECT 
    job_title_short,
    job_country,
    COUNT(*) AS total_postings,
    COUNT(salary_year) AS salary_sample_size,
    ROUND(AVG(salary_year), 2) AS avg_annual_salary,
    ROUND(AVG(salary_hour), 2) AS avg_hourly_salary,
    ROUND(AVG(CASE WHEN job_work_from_home = 1 THEN salary_year END), 2) AS avg_remote_salary,
    ROUND(AVG(CASE WHEN job_work_from_home = 0 THEN salary_year END), 2) AS avg_onsite_salary,
    ROUND(
        (AVG(CASE WHEN job_work_from_home = 1 THEN salary_year END) - 
         AVG(CASE WHEN job_work_from_home = 0 THEN salary_year END)), 2
    ) AS remote_pay_variance
FROM cleaned_salaries
GROUP BY job_title_short, job_country;
