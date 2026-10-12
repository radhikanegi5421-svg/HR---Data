
---   HR Workforce Analytics - SQL analysis (PostgreSQL)
---   Table : hr_employees  


-- 0. TABLE SETUP (PostgreSQL) 


-- Q1. Headline KPIs ------------------------------------------------------
SELECT COUNT(*) AS total_employees,
       SUM(is_active) AS active_employees,
       SUM(is_attrited) AS attrited_employees,
       ROUND(100.0 * SUM(is_attrited) / COUNT(*), 2) AS attrition_rate_pct,
       ROUND(AVG(salary), 0) AS avg_salary,
       ROUND(AVG(CASE WHEN is_active = 1 THEN tenure_years END), 1) AS avg_tenure_active
FROM hr_employees;

-- Q2. Headcount, attrition and pay by department ---------------------------
SELECT department,
       COUNT(*) AS employees,
       SUM(is_active) AS active,
       ROUND(100.0 * SUM(is_attrited) / COUNT(*), 2) AS attrition_rate_pct,
       ROUND(AVG(salary), 0) AS avg_salary,
       ROUND(100.0 * SUM(salary) / SUM(SUM(salary)) OVER (), 2) AS pct_of_total_payroll
FROM hr_employees
GROUP BY department
ORDER BY attrition_rate_pct DESC;

-- Q3. Where is attrition concentrated? Level x Performance --------------------
SELECT job_level, performance_rating,
       COUNT(*) AS employees,
       ROUND(100.0 * SUM(is_attrited) / COUNT(*), 2) AS attrition_rate_pct
FROM hr_employees
WHERE performance_rating <> 'Not Rated'
GROUP BY job_level, performance_rating
ORDER BY attrition_rate_pct DESC;

-- Q4. Exit type split (resigned vs terminated vs retired) by level ------------
SELECT job_level,
       SUM(CASE WHEN status = 'Resigned'   THEN 1 ELSE 0 END) AS resigned,
       SUM(CASE WHEN status = 'Terminated' THEN 1 ELSE 0 END) AS terminated,
       SUM(CASE WHEN status = 'Retired'    THEN 1 ELSE 0 END) AS retired
FROM hr_employees
GROUP BY job_level
ORDER BY resigned DESC;

-- Q5. Hiring trend with YoY growth and cumulative hires (LAG + running SUM) ----
WITH yearly AS (
    SELECT hire_year, COUNT(*) AS hires
    FROM hr_employees GROUP BY hire_year
)
SELECT hire_year, hires,
       ROUND(100.0 * (hires - LAG(hires) OVER (ORDER BY hire_year))
             / NULLIF(LAG(hires) OVER (ORDER BY hire_year), 0), 1) AS yoy_growth_pct,
       SUM(hires) OVER (ORDER BY hire_year) AS cumulative_hires
FROM yearly
ORDER BY hire_year;

-- Q6. Hire-cohort attrition (join year groups) ---------------------------------
SELECT CASE WHEN hire_year <= 2015 THEN '2008-2015'
            WHEN hire_year <= 2020 THEN '2016-2020'
            ELSE '2021-2026' END AS hire_cohort,
       COUNT(*) AS employees,
       ROUND(100.0 * SUM(is_attrited) / COUNT(*), 2) AS attrition_rate_pct,
       ROUND(AVG(salary), 0) AS avg_salary
FROM hr_employees
GROUP BY 1
ORDER BY 1;

-- Q7. Pay by performance rating (is pay linked to performance?) ----------------
SELECT performance_rating,
       COUNT(*) AS employees,
       ROUND(AVG(salary), 0) AS avg_salary,
       ROUND(AVG(salary) / (SELECT AVG(salary) FROM hr_employees) * 100, 1) AS index_vs_company_avg
FROM hr_employees
WHERE performance_rating <> 'Not Rated'
GROUP BY performance_rating
ORDER BY avg_salary DESC;

-- Q8. Top 3 best-paid job titles inside every department (RANK window) ---------
WITH t AS (
    SELECT department, job_title, COUNT(*) AS employees, ROUND(AVG(salary), 0) AS avg_salary,
           RANK() OVER (PARTITION BY department ORDER BY AVG(salary) DESC) AS pay_rank
    FROM hr_employees
    GROUP BY department, job_title
)
SELECT * FROM t WHERE pay_rank <= 3 ORDER BY department, pay_rank;

-- Q9. Active employees paid above their department + level average (CTE + join)
WITH avg_pay AS (
    SELECT department, job_level, AVG(salary) AS avg_sal
    FROM hr_employees WHERE is_active = 1
    GROUP BY department, job_level
)
SELECT e.department,
       COUNT(*) AS active_employees,
       SUM(CASE WHEN e.salary > a.avg_sal THEN 1 ELSE 0 END) AS above_avg,
       ROUND(100.0 * SUM(CASE WHEN e.salary > a.avg_sal THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_above_avg
FROM hr_employees e
JOIN avg_pay a ON a.department = e.department AND a.job_level = e.job_level
WHERE e.is_active = 1
GROUP BY e.department
ORDER BY e.department;

-- Q10. Work-mode mix by country (active employees) -----------------------------
SELECT country,
       ROUND(100.0 * SUM(CASE WHEN work_mode = 'On-site' THEN 1 ELSE 0 END) / COUNT(*), 1) AS onsite_pct,
       ROUND(100.0 * SUM(CASE WHEN work_mode = 'Hybrid'  THEN 1 ELSE 0 END) / COUNT(*), 1) AS hybrid_pct,
       ROUND(100.0 * SUM(CASE WHEN work_mode = 'Remote'  THEN 1 ELSE 0 END) / COUNT(*), 1) AS remote_pct
FROM hr_employees
WHERE is_active = 1
GROUP BY country
ORDER BY country;

-- Q11. High-risk segment: Junior + 'Needs Improvement' vs rest -------------------
SELECT CASE WHEN job_level = 'Junior' AND performance_rating = 'Needs Improvement'
            THEN 'Junior + Needs Improvement' ELSE 'All others' END AS segment,
       COUNT(*) AS employees,
       ROUND(100.0 * SUM(is_attrited) / COUNT(*), 2) AS attrition_rate_pct
FROM hr_employees
GROUP BY 1;

-- Q12. Salary-band distribution of active workforce ----------------------------
SELECT salary_band, COUNT(*) AS employees,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM hr_employees
WHERE is_active = 1
GROUP BY salary_band
ORDER BY MIN(salary);

