-- In this project we are going to create Fact and Dimensions tables from raw source data,
-- following the Medallian Architecture (Bronze, Silver,Gold).

-- Using public Schema as Bronze Layer
/*
CREATING RAW SOURCE TABLE FROM CSV 
Right-click on Table -> Import/Export Data -> Choose file. options -> Header ON, file-type->CSV
*/
-- This Table is created for Loading the Data from CSV File
CREATE TABLE PUBLIC.sales_raw(
OrderID INT ,				-- Keep VARCHAR datatype for all columns to avoid data loading failure
OrderDate  VARCHAR(50),		-- Date is giving error due to excel datatype mismatch.
CustomerID  INT,	
CustomerName  VARCHAR(100),
CustomerEmail VARCHAR(100),
Country  VARCHAR(100),
ProductID   INT,
ProductCategory  VARCHAR(100),
ProductName  VARCHAR(100),
Quantity  INT ,
UnitPrice  VARCHAR(100),
TotalPrice  VARCHAR(100),
SalesRegion  VARCHAR(20)
);

-- copy public.sales_raw(orderid, orderdate, customerid, customername, customeremail, country, productid, productcategory, productname, quantity, unitprice, totalprice, salesregion) 
-- FROM 'C:/Users/91989/Desktop/sales.csv' WITH(FORMAT csv, DELIMITER ',', HEADER, QUOTE '\', ESCAPE '''');

SELECT * FROM sales_raw ;

SELECT DISTINCT customerid FROM sales_raw;

-- This will also work in IMPORT/EXPORT Method
-- Data has been loaded into this table using Pentaho ETL tool.
CREATE TABLE PUBLIC.sales(
OrderID INT ,
OrderDate  DATE,
CustomerID  INT,	
CustomerName  VARCHAR(100),
CustomerEmail VARCHAR(100),
Country  VARCHAR(100),
ProductID   INT,
ProductCategory  VARCHAR(100),
ProductName  VARCHAR(100),
Quantity  INT ,
UnitPrice  NUMERIC(6,2),
TotalPrice  NUMERIC(8,2),
SalesRegion  VARCHAR(20)
);

SELECT * FROM PUBLIC.sales;

SELECT country FROM PUBLIC.sales WHERE LENGTH(country) > 50;

SELECT COUNT(DISTINCT orderid) FROM public.sales;

SELECT COUNT(DISTINCT customerid) FROM public.sales;

SELECT COUNT(DISTINCT productid) FROM public.sales;

SELECT COUNT(DISTINCT productcategory) FROM PUBLIC.sales;
SELECT MAX(quantity) FROM public.sales;

-- Checking NULLs and Duplicates
SELECT * FROM sales WHERE NULL IN (orderid,customerid,productid,productcategory,productname,customername,customeremail,country,unitprice,totalprice,salesregion);

SELECT  orderid,customerid,productid,customername,customeremail,country,salesregion FROM SALES
GROUP BY orderid,customerid,productid,customername,customeremail,country,salesregion
HAVING COUNT(*)>1;

SELECT DISTINCT PRODUCTNAME FROM PUBLIC.SALES;
SELECT DISTINCT PRODUCTCATEGORY FROM PUBLIC.SALES;

-- Creating Silver Layer Schema, To clean Bronze Layer Raw Table, datatype, Constraint, Names
CREATE SCHEMA silver;
-- Creating Clean Table with Primary Keys and correct Datatype
CREATE TABLE silver.sales(
order_id INT PRIMARY KEY ,
order_date  DATE,
customer_id  INT,	
customer_name  VARCHAR(100),
customer_email VARCHAR(100),
country  VARCHAR(100),
product_id   INT,
product_category  VARCHAR(30),
product_name  VARCHAR(30),
quantity   SMALLINT ,
price_per_quantity  NUMERIC(6,2),
total_price  NUMERIC(8,2),
sales_region  VARCHAR(20)
);

-- Loading Data from Bronze.sales to Silver.sales TABLE
INSERT INTO silver.sales
SELECT * FROM public.sales;

SELECT * FROM silver.sales order by 1;
-- Get Distinct product name and category
SELECT DISTINCT product_name from silver.sales order by 1;
SELECT DISTINCT product_category FROM silver.sales; -- Same queries run by modified column name.

-- Cleaning / Updating Product Category according to Product name, Original table mismatches these categories
UPDATE silver.sales
SET product_category =
CASE
	WHEN LOWER(product_name) IN ('table','sofa') THEN 'Furniture'
	WHEN LOWER(product_name) IN ('laptop','phone') THEN 'Electronics'
	WHEN LOWER(product_name) IN ('tennis racket', 'bicycle') THEN 'Sports'
	WHEN LOWER(product_name) IN ('t-shirt','shoes') THEN 'Clothing'
	WHEN LOWER(product_name) IN ('perfume') THEN 'Beauty'
	ELSE 'Miscellaneous'
END;

SELECT * FROM public.sales ORDER BY customerid;
SELECT DISTINCT product_id FROM silver.sales order by 1;

UPDATE silver.sales
SET product_id = 
CASE
	WHEN product_name = 'Bicycle' THEN 101
	WHEN product_name = 'Laptop' THEN 102
	WHEN product_name = 'Perfume' THEN 103
	WHEN product_name = 'Phone' THEN 104
	WHEN product_name = 'Shoes' THEN 105
	WHEN product_name = 'Sofa' THEN 106
	WHEN product_name = 'T-Shirt' THEN 107
	WHEN product_name = 'Table' THEN 108
	WHEN product_name = 'Tennis Racket' THEN 109
	ELSE 110
END;

SELECT DISTINCT customer_id FROM silver.sales order by 1;
SELECT * FROM silver.sales ORDER BY CUSTOMER_ID;

-- SELECT customer_name FROM silver.sales WHERE customer_id = 1003 LIMIT 1;

-- SELECT * FROM public.sales WHERE customerid IN (1880,1170)

UPDATE silver.sales s1
SET customer_name = 
( SELECT customer_name FROM silver.sales AS s2 WHERE s1.customer_id = s2.customer_id LIMIT 1)
;

SELECT COUNT(DISTINCT customer_id) FROM silver.sales;
SELECT COUNT(DISTINCT customer_name) FROM silver.sales;

-- SELECT * FROM silver.salES WHERE customer_name IN ('Michelle Taylor','Melissa Lee','Richard Williams')

-- FIND same customer name with different customer IDs.
SELECT customer_name, COUNT(DISTINCT customer_id)
FROM silver.sales
GROUP BY customer_name
HAVING COUNT(DISTINCT customer_id) > 1;

-- DELETE FROM silver.sales
-- WHERE customer_id IN (1170,1210,1714);

SELECT DISTINCT sales_region FROM silver.sales;

UPDATE silver.sales s1
SET customer_email =
(SELECT LOWER(SUBSTRING(customer_name FROM 1 FOR (POSITION(' ' in customer_name) - 1)))  || '.' ||
LOWER(SUBSTRING(customer_name FROM (POSITION(' ' in customer_name) + 1))) || '@email.com' AS email
FROM silver.sales s2 WHERE s1.customer_name = s2.customer_name LIMIT 1 );

SELECT * FROM silver.sales ORDER BY 1;

-- Extracting First Name and Last Name
SELECT customer_name ,LOWER(SUBSTRING(customer_name FROM 1 FOR (POSITION(' ' in customer_name) - 1))) AS first_name,
LOWER(SUBSTRING(customer_name FROM (POSITION(' ' in customer_name) + 1))) AS last_name
FROM silver.sales;

-- Constructing Email from Name
SELECT customer_name,  LOWER(SUBSTRING(customer_name FROM 1 FOR (POSITION(' ' in customer_name) - 1)))  || '.' ||
LOWER(SUBSTRING(customer_name FROM (POSITION(' ' in customer_name) + 1))) || '@email.com' AS email
FROM silver.sales

-- Getting and Updating Correction of Country for each customer.
SELECT customer_name, country FROM silver.sales WHERE customer_name = 'Melissa Lee';

-- Updation of Country in silver.sales table
UPDATE silver.sales s1
SET country = 
(SELECT country FROM silver.sales s2 WHERE s1.customer_name = s2.customer_name LIMIT 1);

SELECT * FROM silver.sales WHERE country = 'India' ORDER BY customer_name;


-- Creating Gold Schema (For Fact and Dimension Tables)
CREATE SCHEMA gold;

-- Creating CUSTOMER Dimension
CREATE TABLE gold.dim_customer(
	customer_key SERIAL PRIMARY KEY, 	-- Using Surrogate Key
	customer_id INT ,	-- Natural Key or Bussiness Keys
	customer_name VARCHAR(100),
	customer_email VARCHAR(100),
	country VARCHAR(100)
);

INSERT INTO gold.dim_customer (customer_id, customer_name, customer_email, country)
SELECT 
    customer_id,
    customer_name,
    customer_email,
    country
FROM silver.sales
GROUP BY customer_id, customer_name, customer_email, country
ORDER BY 1;

SELECT * FROM gold.dim_customer where country = 'India';

-- Creating PRODUCT Dimension
CREATE TABLE gold.dim_product(
	product_key SERIAL PRIMARY KEY,
	product_id SMALLINT,
	product_name VARCHAR(30),
	product_category VARCHAR(30)
);

INSERT INTO gold.dim_product(product_id,product_name,product_category)
SELECT DISTINCT product_id, product_name,product_category FROM silver.sales ORDER BY 1;

SELECT * FROM gold.dim_product;

-- Creating REGION Dimension
CREATE TABLE gold.dim_region(
	region_key SERIAL PRIMARY KEY,
	sales_region VARCHAR(10) UNIQUE
);

INSERT INTO gold.dim_region(sales_region)
SELECT DISTINCT sales_region FROM silver.sales ORDER BY 1;

SELECT * FROM gold.dim_region;

-- Creating DATE Dimension
CREATE TABLE gold.dim_date(
	date_id INT PRIMARY KEY ,	--Surrogate Key
	order_date DATE,
	day SMALLINT,
	month SMALLINT,
	year SMALLINT,
	quarter SMALLINT
);

-- Extracting Date as String 
SELECT DISTINCT order_date, SUBSTRING(order_date::VARCHAR FROM 1 FOR 4)::INT, -- AS YEAR
SUBSTRING(order_date::VARCHAR FROM 6 FOR 2)::INT,	-- AS MONTH
SUBSTRING(order_date::VARCHAR FROM 9 FOR 2)::INT	-- AS DAY
FROM silver.sales 
ORDER BY 2,3,4;

SELECT DISTINCT (SUBSTRING(order_date::VARCHAR FROM 1 FOR 4) || -- AS YEAR
SUBSTRING(order_date::VARCHAR FROM 6 FOR 2)||	-- AS MONTH
SUBSTRING(order_date::VARCHAR FROM 9 FOR 2))::INT	-- AS DAY
FROM silver.sales 
ORDER BY 1;

-- Inserting Date into dimension table
INSERT INTO gold.dim_date (date_id,order_date, day, month, year, quarter)
SELECT DISTINCT
	(SUBSTRING(order_date::VARCHAR FROM 1 FOR 4) || -- AS YEAR
	SUBSTRING(order_date::VARCHAR FROM 6 FOR 2)||	-- AS MONTH
	SUBSTRING(order_date::VARCHAR FROM 9 FOR 2))::INT,	-- AS DAY
	
    order_date,
    EXTRACT(DAY FROM order_date)::INT,
    EXTRACT(MONTH FROM order_date)::INT,
    EXTRACT(YEAR FROM order_date)::INT,
    CASE
		WHEN EXTRACT(MONTH FROM order_date) BETWEEN 1 AND 3 THEN 1
		WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 2
		WHEN EXTRACT(MONTH FROM order_date) BETWEEN 7 AND 9 THEN 3
		WHEN EXTRACT(MONTH FROM order_date) BETWEEN 10 AND 12 THEN 4
	END
FROM silver.sales ORDER BY 1 ;

SELECT * FROM gold.dim_date;

-- Creating Fact Table 
CREATE TABLE gold.fact_sales (
    fact_id SERIAL PRIMARY KEY,
    customer_key INT,
    product_key INT,
    date_key INT,
    region_key INT,
    quantity SMALLINT,
    price_per_quantity NUMERIC(6,2),
    total_price NUMERIC(8,2),

    FOREIGN KEY (customer_key) REFERENCES gold.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES gold.dim_product(product_key),
    FOREIGN KEY (date_key) REFERENCES gold.dim_date(date_id),
    FOREIGN KEY (region_key) REFERENCES gold.dim_region(region_key)
);

-- Adding Data into Fact Table from silver.sales table and dimension tables
INSERT INTO gold.fact_sales
(customer_key, product_key, date_key, region_key , quantity, price_per_quantity, total_price)
SELECT 
	dc.customer_key,
	dp.product_key,
	dd.date_id,
	dr.region_key,
	s.quantity,
	s.price_per_quantity,
	s.total_price
FROM silver.sales s
JOIN gold.dim_customer dc
ON s.customer_id = dc.customer_id
JOIN gold.dim_product dp
ON s.product_id = dp.product_id
JOIN gold.dim_date dd
ON s.order_date = dd.order_date
JOIN gold.dim_region dr
ON s.sales_region = dr.sales_region;

SELECT * FROM gold.fact_sales;

-- Row Count Validation
SELECT COUNT(*) FROM silver.sales;
SELECT COUNT(*) FROM gold.fact_sales;

-- Now we can perform Business Intelligence on these gold schema fact and dimension tables.

-- Which sales region have most sales
SELECT dr.sales_region , COUNT(*) AS sales_count
FROM gold.fact_sales f
JOIN gold.dim_region dr
ON f.region_key = dr.region_key
GROUP BY dr.sales_region
ORDER BY 2 DESC;		-- Query time on gold table 240 ms.

SELECT sales_region , COUNT(*) AS sales
FROM silver.sales
GROUP BY sales_region
ORDER BY 2 DESC;

-- Which Customer ordered most
SELECT customer_name , customer_email , country 
FROM gold.dim_customer 
WHERE customer_name = (SELECT dc.customer_name
FROM gold.fact_sales f
JOIN gold.dim_customer dc
ON f.customer_key = dc.customer_key
GROUP BY dc.customer_name
ORDER BY COUNT(*) DESC LIMIT 1)

-- Year wise revenue 
SELECT dd.year, SUM(f.total_price) AS "Total Revenue"
FROM gold.fact_sales f 
JOIN gold.dim_date dd 
ON f.date_key = dd.date_id
GROUP by dd.year
ORDER BY 2 DESC;

-- Which Quarter of Year generated Highest Revenue
SELECT dd.quarter, SUM(f.total_price) AS "Total Revenue in Quarter"
FROM gold.fact_sales f 
JOIN gold.dim_date dd 
ON f.date_key = dd.date_id
GROUP by dd.quarter
ORDER BY 2 DESC;

-- Month wise Revenue 
SELECT dd.year, dd.month , SUM(f.total_price) AS "Total Revenue per Month of Year"
FROM gold.fact_sales f 
JOIN gold.dim_date dd 
ON f.date_key = dd.date_id
GROUP by dd.year, dd.month
ORDER BY 2 DESC;

-- Which Product ordered most
SELECT dp.product_name , dp.product_category, COUNT(*) AS "Product Ordered"
FROM gold.fact_sales f
JOIN gold.dim_product dp
ON f.product_key = dp.product_key
GROUP BY dp.product_name, dp.product_category
ORDER BY 3 DESC;

--  Product-Wise Revenue 
SELECT dp.product_name , dp.product_category, SUM(total_price) AS "Revenue Generated by Product"
FROM gold.fact_sales f
JOIN gold.dim_product dp
ON f.product_key = dp.product_key
GROUP BY dp.product_name, dp.product_category
ORDER BY 3 DESC;