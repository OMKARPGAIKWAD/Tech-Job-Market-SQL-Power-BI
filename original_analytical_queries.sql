SELECT *
FROM cleaned_salaries;

-- 1. Highest-paying job title per country which job title has the highest average/max salary in each country.

WITH ranked_salaries_cte AS
(SELECT job_title_short,job_country,MAX(salary_year) AS max_salary,
ROW_NUMBER() OVER(
PARTITION BY job_country ORDER BY MAX(salary_year) DESC) AS ranked_salaries
FROM cleaned_salaries
WHERE salary_year IS NOT NULL
GROUP BY job_country,job_title_short
)
SELECT *
FROM ranked_salaries_cte
WHERE ranked_salaries=1
ORDER BY max_salary DESC;

-- WE CAN CONCLUDE THAT DATA SCIENTIST IN UNITED STATES IS PAID THE HIGHEST SALARY OF $ 960000 AND SENIOR DATA SCIENTIST IN SOUTH AFRICA IS PAID THE SECOND HIGHEST SALARY OF $ 890000

-- 2. Most-used job platform (job_via) per country which platform (LinkedIn, Indeed, ZipRecruiter, etc.) has the most postings in each country.

WITH ranked_platform_cte AS
(SELECT job_country,job_via,COUNT(job_via) AS platform_count,
ROW_NUMBER() OVER(
PARTITION BY job_country ORDER BY COUNT(job_via) DESC) AS ranked_platform
FROM cleaned_salaries
GROUP BY job_country,job_via
)
SELECT job_country,job_via,platform_count
FROM ranked_platform_cte
WHERE ranked_platform=1
ORDER BY platform_count DESC;

SELECT job_via,COUNT(job_via)
FROM cleaned_salaries
GROUP BY job_via
ORDER BY 2 DESC;

-- 3. Remote DA/BA roles — pay comparison For Data Analyst/Business Analyst roles in the US: what % are remote, and how does average remote pay compare to onsite pay for the same titles.

SELECT job_title_short,COUNT(*) AS total_jobs,
ROUND(AVG(CASE WHEN job_work_from_home=TRUE THEN 1 ELSE 0 END )*100,2) AS remote_percetage,
ROUND(AVG(CASE WHEN job_work_from_home=TRUE THEN salary_year  END ),2) AS avg_remote_salary,
ROUND(AVG(CASE WHEN job_work_from_home=FALSE THEN salary_year END ),2) AS avg_onsite_salary
FROM cleaned_salaries
WHERE job_title_short IN ('Data Analyst','Business Analyst') AND 
	  job_country='United States'
GROUP BY job_title_short;

-- 4. Monthly posting trend and volume Count of job postings by month, broken down by job title — identify peak hiring months.

WITH hiring_volume_cte AS
(
SELECT job_title_short,MONTHNAME(posted_date) AS peak_month,COUNT(*) AS total_job_postings,
ROW_NUMBER() OVER(
PARTITION BY job_title_short ORDER BY COUNT(*) DESC) AS volume_ranked
FROM cleaned_salaries
GROUP BY job_title_short,MONTHNAME(posted_date),EXTRACT(MONTH FROM posted_date)
)
SELECT job_title_short,peak_month,total_job_postings
FROM hiring_volume_cte
WHERE volume_ranked=1
ORDER BY total_job_postings DESC;

-- 5. Highest-paid roles in the US (full-time only) Top paying full-time roles in the US Top 10 by salary

SELECT job_title_short,ROUND(AVG(salary_year),2) AS salary
FROM cleaned_salaries
WHERE job_schedule_type="Full-time" AND job_country="United States"
GROUP BY job_title_short
ORDER BY salary DESC;

-- 6. Top 10 countries by average hourly salary

SELECT job_country,ROUND(AVG(salary_hour),2) AS avg_hourly_salary,COUNT(salary_hour) AS total_hourly_postings
FROM cleaned_salaries
WHERE salary_hour IS NOT NULL
GROUP BY job_country
HAVING COUNT(salary_hour)>=5
ORDER BY 2 DESC
LIMIT 10; 

-- 7. Salary ranking of job titles : Rank job titles by average/max salary

SELECT job_title_short,
ROUND(AVG(salary_year),2) AS avg_salary,
ROUND((
    SELECT AVG(salary_year) FROM (
        SELECT salary_year,
        ROW_NUMBER() OVER(ORDER BY salary_year) AS rn,
        COUNT(*) OVER() AS cnt
        FROM cleaned_salaries c2
        WHERE c2.job_title_short = c.job_title_short AND salary_year IS NOT NULL
    ) t
    WHERE rn IN (FLOOR((cnt+1)/2), CEIL((cnt+1)/2))
),2) AS median_salary
FROM cleaned_salaries c
WHERE salary_year IS NOT NULL
GROUP BY job_title_short
ORDER BY avg_salary DESC;

-- 8. Entry-accessible jobs with benefits : Jobs/companies requiring no degree, but offering health insurance, with a minimum of 3 required skills where SQL is mandatory.

SELECT c.job_title_short,c.company_name,COUNT(*) AS total_eligible_postings
FROM cleaned_salaries AS c
WHERE c.degree_mentioned=FALSE AND c.health_insurance=TRUE 
AND c.id IN(SELECT job_id
			FROM job_to_skills_map
            GROUP BY job_id
            HAVING COUNT(skill_name)>=3
            AND SUM(CASE WHEN LOWER(skill_name)='sql' THEN 1 ELSE 0 END )>0
			)
GROUP BY c.job_title_short,c.company_name
ORDER BY total_eligible_postings DESC;

-- 9. Data Engineer pay — India vs top-paying countries:  Compare average Data Engineer salary in India against the 5 highest-paying countries for the same title.

SELECT job_country AS country,AVG(salary_year) AS top_avg_salary,
	(SELECT AVG(salary_year) 
	FROM cleaned_salaries
	WHERE job_country='India'  
    AND job_title_short='Data Engineer') AS india_avg_salary
FROM cleaned_salaries
WHERE job_country!='India' 
AND job_title_short='Data Engineer' AND salary_year IS NOT NULL
GROUP BY job_country
HAVING COUNT(*)>=5
ORDER BY top_avg_salary DESC
LIMIT 5;

-- 10. Top 10 most in-demand skills overall

SELECT skill_name,COUNT(*) AS skill_count
FROM job_to_skills_map
GROUP BY skill_name
ORDER BY skill_count DESC
LIMIT 10;

-- 11. TOP 10 SKILLS FOR DATA ANALYST AND BUSINESS ANALYST 
WITH DA_skills AS 
(
SELECT job_title_short,skill_name,skill_count,skill_rank
FROM
(
SELECT c.job_title_short,j.skill_name,COUNT(*) AS skill_count,
ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) AS skill_rank
FROM job_to_skills_map AS j
JOIN cleaned_salaries AS c
	ON c.id=j.job_id
WHERE c.job_title_short='Data Analyst'
GROUP BY j.skill_name,c.job_title_short) AS x
WHERE skill_rank<=10),
BA_skills AS
(
SELECT job_title_short,skill_name,skill_count,skill_rank
FROM
(
SELECT c.job_title_short,j.skill_name,COUNT(*) AS skill_count,
ROW_NUMBER() OVER(ORDER BY COUNT(*) DESC) AS skill_rank
FROM job_to_skills_map AS j
JOIN cleaned_salaries AS c
	ON c.id=j.job_id
WHERE c.job_title_short='Business Analyst'
GROUP BY j.skill_name,c.job_title_short) AS y
WHERE skill_rank<=10)
SELECT DA.skill_rank AS 'Rank',
	   DA.skill_name AS 'Data Analayst Skill',
       DA.skill_count AS 'DA Count',
	   BA.skill_name AS 'Business Analayst Skill',
       BA.skill_count AS 'BA Count'
FROM DA_skills AS da
JOIN BA_skills AS ba
	ON da.skill_rank=ba.skill_rank
ORDER BY DA.skill_rank;

SELECT job_title_short,COUNT(*) AS total_job_postings
FROM cleaned_salaries
GROUP BY job_title_short
ORDER BY total_job_postings DESC;

-- 12. Skill combinations vs salary : Which skill combinations (e.g., SQL+Python+AWS) correlate with the highest average salaries, vs single-skill postings.

WITH skill_combinations AS
(SELECT job_id,
	COUNT(skill_name) AS total_skill_count
    FROM job_to_skills_map
    GROUP BY job_id
)
SELECT c.job_title_short,
CASE 
	WHEN s.total_skill_count=1 THEN 'Single-Skill-Posting' ELSE 'Multi-Skill-Posting' 
END AS job_posting_type,
ROUND(AVG(salary_year),2) AS avg_salary,
COUNT(*) AS total_job_postings
FROM cleaned_salaries AS c
JOIN skill_combinations AS s
	ON c.id=s.job_id
WHERE c.salary_year IS NOT NULL
GROUP BY c.job_title_short,job_posting_type
ORDER BY avg_salary DESC 
LIMIT 10;

-- 13. Skills gap analysis : Skills that are high in demand but relatively underpaid, vs skills that are rare but command a salary premium.

(SELECT DISTINCT j.skill_name,COUNT(*) AS skill_count,ROUND(AVG(c.salary_year),2) AS avg_sal
FROM cleaned_salaries AS c
JOIN job_to_skills_map AS j
	ON c.id=j.job_id
WHERE c.salary_year  IS NOT NULL
GROUP BY j.skill_name
HAVING skill_count>4000
ORDER BY avg_sal DESC
LIMIT 5)
UNION
(SELECT DISTINCT j.skill_name,COUNT(*) AS skill_count,ROUND(AVG(c.salary_year),2) AS avg_sal
FROM cleaned_salaries AS c
JOIN job_to_skills_map AS j
	ON c.id=j.job_id
WHERE c.salary_year  IS NOT NULL
GROUP BY j.skill_name
HAVING skill_count BETWEEN 10 AND 50
ORDER BY avg_sal DESC
LIMIT 5);
