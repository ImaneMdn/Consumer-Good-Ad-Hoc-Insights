-- markets in which customer "Atliq Exclusive" operates its business in the APAC region.

SELECT 
  DISTINCT market 
FROM 
  dim_customer 
WHERE 
  customer = 'Atliq Exclusive' 
  and region = 'APAC';


-- What is the percentage of unique product increase in 2021 vs. 2020?

WITH total_product AS (
  SELECT 
    fiscal_year, 
    COUNT(DISTINCT product_code) AS product_count 
  FROM 
    fact_sales_monthly 
  GROUP BY 
    fiscal_year
) 
SELECT 
  A.product_count AS unique_products_2020, 
  B.product_count AS unique_products_2021, 
  ROUND(
    (B.product_count - A.product_count) / A.product_count * 100, 2
  ) AS percentage_chg 
FROM 
  total_product AS A 
  LEFT JOIN total_product AS B ON A.fiscal_year + 1 = B.fiscal_year 
LIMIT 1;

-- Provide a report with all the unique product counts for each segment and sort them in descending order of product counts.

SELECT 
  segment, 
  COUNT(DISTINCT product_code) AS product_count 
FROM 
  dim_product 
GROUP BY 
  segment 
ORDER BY 
  product_count DESC;

-- Which segment had the most increase in unique products in 2021 vs 2020?
WITH total_product AS(
  SELECT 
    segment, 
    fiscal_year, 
    COUNT(DISTINCT P.product_code) AS product_count 
  FROM 
    dim_product AS P 
    INNER JOIN fact_sales_monthly AS S ON P.product_code = S.product_code 
  GROUP BY 
    segment, 
    fiscal_year
) 
SELECT 
  A.segment, 
  A.product_count AS product_count_2020, 
  B.product_count AS product_count_2021, 
  B.product_count - A.product_count AS Difference 
FROM 
  total_product AS A 
  JOIN total_product AS B ON A.fiscal_year + 1 = B.fiscal_year 
  AND A.segment = B.segment 
ORDER BY 
  Difference DESC;


-- Get the products that have the highest and lowest manufacturing costs.

SELECT 
  M.product_code, 
  product, 
  M.manufacturing_cost 
FROM 
  fact_manufacturing_cost M 
  JOIN dim_product P ON P.product_code = M.product_code 
WHERE 
  M.manufacturing_cost IN (
    SELECT 
      MAX(manufacturing_cost) AS MAX_cost 
    FROM 
      fact_manufacturing_cost 
    UNION 
    SELECT 
      MIN(manufacturing_cost) AS MIN_cost 
    FROM 
      fact_manufacturing_cost
  ) 
ORDER BY 
  M.manufacturing_cost DESC;
-- Generate a report which contains the top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 and in the Indian market

SELECT 
  C.customer_code, 
  C.customer, 
  ROUND(AVG(pre_invoice_discount_pct), 4) AS avg_discount 
FROM 
  fact_pre_invoice_deductions F 
  JOIN dim_customer C ON F.customer_code = C.customer_code 
WHERE 
  fiscal_year = 2021 
  AND market = 'India' 
GROUP BY 
  C.customer_code, 
  C.customer 
ORDER BY 
  avg_discount DESC 
LIMIT 5;

-- Get the complete report of the Gross sales amount for the customer “Atliq Exclusive” for each month.

WITH temp_table AS (
    SELECT customer,
    monthname(date) AS months ,
    month(date) AS month_number, 
    year(date) AS year,
    (sold_quantity * gross_price)  AS gross_sales
 FROM fact_sales_monthly s JOIN
 fact_gross_price g ON s.product_code = g.product_code
 JOIN dim_customer c ON s.customer_code=c.customer_code
 WHERE customer="Atliq exclusive"
)
SELECT months,year, concat(round(sum(gross_sales)/1000000,2),"M") AS gross_sales FROM temp_table
GROUP BY year,months
ORDER BY year,months;

-- In which quarter of 2020, got the maximum total_sold_quantity?

SELECT 
  CASE WHEN MONTH(date) BETWEEN 9 AND 11 THEN 'Q1' 
  WHEN MONTH(date) IN (12, 1, 2) THEN 'Q2' 
  WHEN MONTH(date) BETWEEN 3 AND 5 THEN 'Q3' 
  WHEN MONTH(date) BETWEEN 6 AND 8 THEN 'Q4' 
  END AS Quarters, 
  CONCAT(CAST(ROUND(SUM(sold_quantity)/ 1000000, 2) AS CHAR), " M") AS total_sold_quantity 
FROM 
  fact_sales_monthly FS 
WHERE 
  fiscal_year = 2020 
GROUP BY 
  Quarters 
ORDER BY 
  total_sold_quantity DESC;


-- Which channel helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution?
WITH gross_by_channel AS (
  SELECT 
    C.channel, 
    ROUND(SUM(sold_quantity * gross_price) / 1000000, 2) AS gross_sales_mln 
  FROM 
    fact_sales_monthly FS 
    JOIN fact_gross_price FG ON FS.product_code = FG.product_code 
    JOIN dim_customer AS C ON FS.customer_code = C.customer_code 
  WHERE 
    FS.fiscal_year = 2021 
  GROUP BY 
    C.channel
) 
SELECT 
  channel, 
  CONCAT(gross_sales_mln, " M") AS gross_sales_mln, 
  ROUND(gross_sales_mln * 100 / (
      SELECT 
        SUM(gross_sales_mln) 
      FROM 
        gross_by_channel
    ), 
    2) AS percentage 
FROM 
  gross_by_channel 
ORDER BY 
  percentage DESC;

-- Get the Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021?
WITH CTE AS (
  SELECT 
    P.division, 
    FS.product_code, 
    P.product, 
    SUM(FS.sold_quantity) AS total_sold_quantity, 
    RANK() OVER (
      PARTITION BY division 
      ORDER BY 
        SUM(FS.sold_quantity) DESC
    ) AS rank_order 
  FROM 
    fact_sales_monthly FS 
    JOIN dim_product AS P ON FS.product_code = P.product_code 
  WHERE 
    FS.fiscal_year = 2021 
  GROUP BY 
    P.division, 
    FS.product_code, 
    P.product
) 
SELECT 
  * 
FROM 
  CTE 
WHERE 
  rank_order <= 3;
