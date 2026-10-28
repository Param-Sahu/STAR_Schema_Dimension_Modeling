# Objective

Design and implement a data warehouse dimension modeling using Star Schema in PostgreSQL by transforming raw transactional sales data into structured fact and dimension tables for efficient analytical querying.

---

## Why STAR Schema and Dimensional Modelling needed ? when we have data in single table?

<img width="1359" height="620" alt="image" src="https://github.com/user-attachments/assets/056125d2-5c8d-45dd-b31e-20c7b0b7a1cb" />

<br>

**Goal of Dimensional Modelling** : To organize data into facts and dimensions so it becomes efficient, consistent, and easy to analyze for business reporting. STAR schema reduces redundancy, improves performance, ensures consistency, and provides a scalable structure for efficient business analytics. 
 
### A. Data Redundancy 
In Single Table , Same values repeat many times, like product name , product category , region of sales etc. Which is waste of storage, repeated same value 1000 times and slow query scan and more important this cause UPDATE problems. Suppose you have to update a product name or category , in real life OLAP systems you have to UPDATE more than 1000 rows and it cause High risk of data inconsistency. With dimensions, update one row in dimension table and use its key in fact table which take much less storage.
Without dimensions, customer and product data repeat in every row. Dimensions allow controlled history tracking. Example: Customer moved from India to USA, so Dimensional models  such as STAR Schema can preserve history through slowly changing dimensions. Single tables usually overwrite or duplicate inconsistently.

### B. Data Inconsistency 
Single table in real life can contain inconsistent values, such as: North north NORTH. Same category, different values. This breaks grouping query and produce wrong aggregations. Dimensions enforce controlled and correct values. 
Data in a single table is hard to maintain, and data is inconsistent while through dimensional modelling such as STAR schema it is easy to maintain and data is consistent, it provide well organised data. Scalability is Poor in Single table but with dimensional model it is excellent.

### C. Query Performance 
Analytics OLAP queries need grouping, filtering, aggregations to find answers of business questions such as sales by month, revenue by product etc. In single table large repeated data is processed. While in Dimensional Modelling such as STAR schema query uses optimized joins and small dimension table which is easy understand to process.  With dimensional modelling , facts are numeric and compact, dimensions are small lookup tables. This improves Query performance.
In Single Table it is easy hard to reason about queries and increase chances of mistakes in queries. star schema mirrors how business users think, such as top selling product, most sales month. Fact and dimesion table provide much clearer understanding of data rather than a raw transactional table.

---

## Problem Domain Selection : 
- **Domain**: Product Sales 
- **Data Source**: Synthetic dataset (_sales.csv_) obtained from a YouTube Video
<img width="1013" height="339" alt="image" src="https://github.com/user-attachments/assets/67637aab-0e3b-4231-88f8-3bb4e2a85824" />

--- 

## Data Ingestion (Medallion Architecture)

Medallion Architecture Layers are used in this Project to load, store and clean the data:
 - Bronze Layer (public schema) → Contains Raw data (Data stored as it is )
 - Silver Layer (silver schema) → Cleaned data (De-duplication , Data type fixing, Inconsistency managed)
 - Gold Layer (gold schema) → Analytical model (Fact and Dimension Tables)

Methods Used for Data Ingestion in PostgreSQL Database are : 

### Data Import in PostgreSQL Database using pgAdmin 

The dataset (sales.csv) was initially loaded into PostgreSQL using the Import/Export feature in pgAdmin. During this step, a table public.sales_raw was created to store raw data in its original form. To ensure smooth ingestion without failures, flexible datatypes such as VARCHAR were used for most columns, including order_date. This approach helped avoid parsing errors caused by inconsistent date formats in the CSV file. The table at this stage represents the raw (Bronze layer) data without transformations.
<img width="1029" height="465" alt="image" src="https://github.com/user-attachments/assets/f7f263d2-caf2-4822-8b99-72d68ccc293f" />
<img width="1035" height="807" alt="image" src="https://github.com/user-attachments/assets/6959b11f-299a-49d7-a9b2-8d58f6b8cec1" />

### Data Ingestion in PostgreSQL Database using Pentaho ETL Tool
In addition to manual import, an ETL-based (Extract Transform Load) approach was implemented using Pentaho Data Integration (PDI). A combination of Jobs and Transformations was designed to automate the data loading process. Unlike the pgAdmin method, this Method ensured that appropriate datatypes (e.g., DATE for order_date) were applied during ingestion itself. The processed data was loaded into public.sales, forming a cleaner version of the Bronze layer. 

#### Pentaho Job : _warehouse_test_job.kjb_
<img width="711" height="387" alt="image" src="https://github.com/user-attachments/assets/e61e661f-1dea-454f-9f0e-20f0a2d13ab0" />

#### Pentaho Transformation : _warehouse_test_Transformation.ktr_
<img width="1082" height="636" alt="image" src="https://github.com/user-attachments/assets/3d4047ff-5fef-4648-8cc7-38103698f23a" />

--- 

## Data Cleaning and Transformation (Silver Layer)

After loading the raw data into the Bronze layer, the next step was to prepare it for analysis by creating a cleaned version in the Silver layer (silver.sales). The raw dataset contained inconsistencies in datatypes, formatting issues, and duplicate records, which made it unsuitable for direct analytical use. Therefore, several cleaning and transformation steps were applied.

**Fixed datatypes (e.g., VARCHAR → DATE)** : First, datatypes were corrected. Columns that were initially stored as generic types (such as VARCHAR) during ingestion were converted into appropriate formats. For example, the order_date column was transformed into the DATE datatype to enable proper time-based analysis. Numeric columns like quantity, price_per_quantity, and total_price were also ensured to have consistent numeric formats.

```sql
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
```

**Removed duplicates** : Duplicate records were then identified and removed to ensure data accuracy. Duplicates were removed, not merged because in this synthetic dataset I found same customer_id with different customer name and vice-versa. This step was important to avoid inflated counts or incorrect aggregations in later analysis.

<img width="538" height="419" alt="image" src="https://github.com/user-attachments/assets/cf422e4d-ed72-4aa3-89c0-31a3933878df" />

**Standardized Data** : Data standardization was also performed on specific columns. The customer_email field was cleaned to maintain a consistent format, ensuring it could be reliably used for identifying customers. Similarly, the product_category column contained inconsistent categories to the product name in synthetic dataset, which were corrected to maintain uniformity across records. 

<img width="344" height="253" alt="image" src="https://github.com/user-attachments/assets/2ade727b-0018-49fd-ad78-bbbf9c769805" />

<img width="904" height="290" alt="image" src="https://github.com/user-attachments/assets/ccc019e2-4b35-4257-8cf3-3462fea93dae" />

Finally, mismatched or inconsistent values across rows were corrected using targeted UPDATE queries. This included fixing incorrect entries and aligning values to a consistent format. As a result of these steps, the Silver layer table (silver.sales) became a clean and structured transactional dataset, suitable for building dimension and fact tables in the Gold layer.

---

## Star Schema Design (Gold Layer)

<img width="1124" height="865" alt="image" src="https://github.com/user-attachments/assets/59e79b53-88bc-4494-aded-0f4f8e5cabab" />

### Fact Table: fact_sales 
- fact_id (PK)		: Unique row identifier (no business meaning) SERIAL Datatype
- customer_key (FK)	: Links to customer dimension 
- product_key (FK)	: Links to product dimension
- date_key (FK)		: Links to date dimension
- region_key (FK)		: Links to region dimension
- quantity		: Number of items sold 			-- Additive Fact
- price_per_quantity	: Unit price (price per quantity)		-- Non Additive Fact
- total_price		: Total transaction value 		-- Additive Fact

Fact table stores measurable data (metrics). quantity and total_price are additive facts because these can be added across all dimension and produce meaningful outcomes, while price_per_quantity non-additive because summing price_per_quantity is meaningless. Correct aggregation for price_per_quantity is AVG() average it.

### Dimension Tables
Dimension Tables store descriptive or contextual data (qualitative) such as customer information (name, contact information etc.), dates (year, month, day , weekday etc.), product information (product name , category etc.).

#### 1. dim_customer
- customer_key (PK)	: SERIAL Surrogate key
- customer_id		: Original ID from source
- customer_name
- customer_email
- country 

**dim_customer** is used for customer-based analysis (e.g., country-wise sales)

#### 2. dim_product
- product_key (PK)	: Surrogate key SERIAL datatype
- product_id		: Original ID
- product_name
- product_ category 

**dim_product** is used for product/category analysis

#### 3. dim_date
- date_id (PK)		: Integer format (YYYYMMDD) , Surrogate Key
- order_date 		: Actual date (DATE datatype YYYY-MM-DD)
- day			:  Integer Derived field
- month 			:  Integer Derived field
- year			:  Integer Derived field
- quarter			:  Integer Derived fields (Quarter 1 2 3 4)

**dim_date** enables time-based analysis without recalculation

#### 4. dim_region
- region_key (PK)		: Surrogate key SERIAL datatype
- sales_region		: Region name

**dim_region** is used for geographical analysis

---

## Key Design Decisions

- Surrogate keys: Avoid dependency on inconsistent source IDs
- Single fact table: Centralized storage of metrics
- Defined grain: Transactional Grain -> One row = one product in one order
- Foreign keys: Maintain referential integrity

---

## Star Schema Relationships
- fact_sales → dim_customer via customer_key
- fact_sales → dim_product via product_key
- fact_sales → dim_date via date_id
- fact_sales → dim_region via region_key 

One Fact table at center and single level of dimensions around it, forms Star Schema.

## Business Use Cases / Queries
Performed analytical queries on this gold schema, fact and dimension tables, such as:
- Total revenue by year
- Product-wise revenue
- Highest selling products
- Region-wise sales analysis
- Dashboard Preparation and Report Generation for Business perspective.

---

## Thank You for Reading
