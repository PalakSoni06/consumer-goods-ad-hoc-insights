-- ============================================
-- AtliQ Consumer Goods - Ad Hoc SQL Insights
-- ============================================


-- 1. Markets where "Atliq Exclusive" operates in APAC region
SELECT DISTINCT market 
FROM dim_customer
WHERE region = 'APAC' 
  AND customer = 'Atliq Exclusive';



-- 2. Percentage of unique product increase (2021 vs 2020)
SELECT 
    X.a AS unique_product_2020,
    Y.b AS unique_product_2021,
    ROUND((Y.b - X.a) * 100.0 / X.a, 2) AS percentage_change
FROM 
    (SELECT COUNT(DISTINCT product_code) AS a 
     FROM fact_sales_monthly 
     WHERE fiscal_year = 2020) X,
     
    (SELECT COUNT(DISTINCT product_code) AS b 
     FROM fact_sales_monthly 
     WHERE fiscal_year = 2021) Y;



-- 3. Unique product count for each segment
SELECT 
    segment, 
    COUNT(DISTINCT product_code) AS product_count 
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC;



-- 4. Segment-wise increase in unique products (2021 vs 2020)
WITH CTE1 AS (
    SELECT 
        P.segment,
        COUNT(DISTINCT FS.product_code) AS product_count_2020
    FROM dim_product P
    JOIN fact_sales_monthly FS 
        ON P.product_code = FS.product_code
    WHERE FS.fiscal_year = 2020
    GROUP BY P.segment
),

CTE2 AS (
    SELECT 
        P.segment,
        COUNT(DISTINCT FS.product_code) AS product_count_2021
    FROM dim_product P
    JOIN fact_sales_monthly FS 
        ON P.product_code = FS.product_code
    WHERE FS.fiscal_year = 2021
    GROUP BY P.segment
)

SELECT 
    CTE1.segment,
    CTE1.product_count_2020,
    CTE2.product_count_2021,
    (CTE2.product_count_2021 - CTE1.product_count_2020) AS difference
FROM CTE1
JOIN CTE2 
    ON CTE1.segment = CTE2.segment
ORDER BY difference DESC;



-- 5. Products with highest and lowest manufacturing cost
WITH cost_data AS (
    SELECT 
        f.product_code,
        p.product,
        f.manufacturing_cost
    FROM fact_manufacturing_cost f
    JOIN dim_product p 
        ON f.product_code = p.product_code
)

SELECT *
FROM cost_data
WHERE manufacturing_cost = (SELECT MAX(manufacturing_cost) FROM cost_data)

UNION

SELECT *
FROM cost_data
WHERE manufacturing_cost = (SELECT MIN(manufacturing_cost) FROM cost_data);



-- 6. Top 5 customers with highest average discount (India, FY 2021)
SELECT 
    c.customer_code, 
    c.customer, 
    ROUND(AVG(pre_invoice_discount_pct), 4) AS average_discount_percentage
FROM fact_pre_invoice_deductions f
JOIN dim_customer c 
    ON f.customer_code = c.customer_code
WHERE c.market = 'India' 
  AND fiscal_year = 2021
GROUP BY c.customer_code, c.customer
ORDER BY average_discount_percentage DESC
LIMIT 5;



-- 7. Monthly gross sales for "Atliq Exclusive"
SELECT 
    MONTHNAME(s.date) AS month,
    YEAR(s.date) AS year,
    ROUND(SUM(s.sold_quantity * g.gross_price), 2) AS gross_sales_amount
FROM fact_sales_monthly s
JOIN fact_gross_price g 
    ON s.product_code = g.product_code
JOIN dim_customer c 
    ON s.customer_code = c.customer_code
WHERE c.customer = 'Atliq Exclusive'
GROUP BY YEAR(s.date), MONTH(s.date)
ORDER BY YEAR(s.date), MONTH(s.date);



-- 8. Quarter with maximum sold quantity in 2020 (custom mapping)
SELECT 
    CASE 
        WHEN MONTH(date) IN (9,10,11) THEN 'Q1'
        WHEN MONTH(date) IN (12,1,2) THEN 'Q2'
        WHEN MONTH(date) IN (3,4,5) THEN 'Q3'
        WHEN MONTH(date) IN (6,7,8) THEN 'Q4'
    END AS Quarter,
    SUM(sold_quantity) AS total_sold_quantity
FROM fact_sales_monthly
WHERE YEAR(date) = 2020
GROUP BY Quarter
ORDER BY total_sold_quantity DESC;



-- 9. Channel contribution to gross sales (FY 2021)
WITH temp_table AS (
    SELECT 
        c.channel,
        SUM(s.sold_quantity * g.gross_price) AS total_sales
    FROM fact_sales_monthly s 
    JOIN fact_gross_price g 
        ON s.product_code = g.product_code
    JOIN dim_customer c 
        ON s.customer_code = c.customer_code
    WHERE s.fiscal_year = 2021
    GROUP BY c.channel
)

SELECT 
    channel,
    ROUND(total_sales / 1000000, 2) AS gross_sales_mln,
    ROUND(total_sales / SUM(total_sales) OVER() * 100, 2) AS percentage
FROM temp_table
ORDER BY gross_sales_mln DESC;



-- 10. Top 3 products in each division (FY 2021)
WITH product_sales AS (
    SELECT 
        p.division,
        p.product_code,
        p.product,
        SUM(s.sold_quantity) AS total_sold_quantity
    FROM fact_sales_monthly s
    JOIN dim_product p 
        ON s.product_code = p.product_code
    WHERE s.fiscal_year = 2021
    GROUP BY p.division, p.product_code, p.product
),

ranked_products AS (
    SELECT *,
        RANK() OVER (
            PARTITION BY division 
            ORDER BY total_sold_quantity DESC
        ) AS rank_order
    FROM product_sales
)

SELECT 
    division,
    product_code,
    product,
    total_sold_quantity,
    rank_order
FROM ranked_products
WHERE rank_order <= 3;