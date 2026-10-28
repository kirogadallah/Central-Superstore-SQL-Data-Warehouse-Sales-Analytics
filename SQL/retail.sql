/* ================================================================
   PROJECT: Central Superstore - Advanced SQL Data Warehouse
            & Business Analytics (Mini-Project 2)

   PIPELINE (medallion architecture):
     staging  -> raw CSV load, no cleaning
     bronze   -> deduplicated raw copy (append-only history)
     silver   -> cleaned/typed data + data-quality flags (CASE)
     gold     -> star schema (fact_sales + 4 dimensions) used for
                 all business queries, the KPI view, and the
                 stored procedure below

   CONTENTS:
     1. Database/schema setup
     2. Staging -> Bronze -> Silver ETL (CTEs, CASE, MERGE)
     3. Gold layer: star schema (PK/FK, indexes)
     4. 15 business queries (Section: "15 Query")
     5. gold.category_kpi   - SQL view for category-level KPIs
     6. gold.usp_get_region_kpi - stored procedure for region KPIs
     7. Analytical report (profitability / customer behavior /
        sales trends) written as SQL comments
   ================================================================ */

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'central_dw')
    CREATE DATABASE central_dw;
GO

USE central_dw;
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'staging')
    EXEC('CREATE SCHEMA staging');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO


IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'staging' AND t.name = 'Superstore')
BEGIN
    CREATE TABLE staging.Superstore (
        RowID         INT         ,
        OrderID       VARCHAR(250),
        OrderDate     VARCHAR(250),
        ShipDate      VARCHAR(250),
        ShipMode      VARCHAR(250),
        CustomerID    VARCHAR(250),
        CustomerName  VARCHAR(250),
        Segment       VARCHAR(250),
        Country       VARCHAR(250),
        City          VARCHAR(250),
        State         VARCHAR(250),
        PostalCode    VARCHAR(250),
        Region        VARCHAR(250),
        ProductID     VARCHAR(250),
        Category      VARCHAR(250),
        SubCategory   VARCHAR(250),
        ProductName   VARCHAR(250),
        Sales         VARCHAR(250),
        Quantity      VARCHAR(250),
        Discount      VARCHAR(250),
        Profit        VARCHAR(250)    
    );
END;
GO


TRUNCATE TABLE staging.superstore;

BULK INSERT staging.superstore
FROM 'C:\Users\Lenovo\Desktop\SQL Project\Central_Superstore.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    CODEPAGE = '65001',
    MAXERRORS = 0
);
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables t JOIN sys.schemas s ON t.schema_id = s.schema_id WHERE s.name = 'bronze' AND t.name = 'Superstore')
BEGIN
    CREATE TABLE bronze.Superstore (
        bronze_id INT IDENTITY(1,1) PRIMARY KEY,
        RowID         INT        ,
        OrderID       VARCHAR(250),
        OrderDate     VARCHAR(250),
        ShipDate      VARCHAR(250),
        ShipMode      VARCHAR(250),
        CustomerID    VARCHAR(250),
        CustomerName  VARCHAR(250),
        Segment       VARCHAR(250),
        Country       VARCHAR(250),
        City          VARCHAR(250),
        State         VARCHAR(250),
        PostalCode    VARCHAR(250),
        Region        VARCHAR(250),
        ProductID     VARCHAR(250),
        Category      VARCHAR(250),
        SubCategory   VARCHAR(250),
        ProductName   VARCHAR(250),
        Sales         VARCHAR(250),
        Quantity      VARCHAR(250),
        Discount      VARCHAR(250),
        Profit        VARCHAR(250)    
    );
END;
GO

INSERT INTO bronze.Superstore (
    RowID, OrderID, OrderDate, ShipDate, ShipMode, CustomerID, CustomerName, Segment, 
    Country, City, State, PostalCode, Region, ProductID, Category, SubCategory, 
    ProductName, Sales, Quantity, Discount, Profit
)
SELECT RowID, OrderID, OrderDate, ShipDate, ShipMode, CustomerID, CustomerName, Segment, Country, City, State, PostalCode, Region, ProductID, Category, SubCategory, ProductName, Sales, Quantity, Discount, Profit
FROM staging.superstore
EXCEPT
SELECT RowID, OrderID, OrderDate, ShipDate, ShipMode, CustomerID, CustomerName, Segment, Country, City, State, PostalCode, Region, ProductID, Category, SubCategory, ProductName, Sales, Quantity, Discount, Profit
FROM bronze.Superstore;
GO


IF OBJECT_ID('silver.superstore', 'U') IS NOT NULL
    DROP TABLE silver.superstore;
GO
    CREATE TABLE silver.superstore (
        RowID INT,
        OrderID VARCHAR(250) NOT NULL,
        OrderDate DATE,
        ShipDate DATE,
        ShipMode VARCHAR(50),
        CustomerID VARCHAR(50),
        CustomerName VARCHAR(150),
        Segment VARCHAR(50),
        Country VARCHAR(50),
        City VARCHAR(50),
        State VARCHAR(50),
        PostalCode VARCHAR(30),
        Region VARCHAR(50),
        ProductID VARCHAR(50),
        Category VARCHAR(50),
        SubCategory VARCHAR(50),
        ProductName VARCHAR(500), 
        Sales DECIMAL(10, 2),
        Quantity INT,
        Discount DECIMAL(10, 2),
        Profit DECIMAL(10, 2),
        has_missing_value BIT NOT NULL DEFAULT 0,
        has_invalid_value BIT NOT NULL DEFAULT 0,
        has_outlier_value BIT NOT NULL DEFAULT 0,
        CONSTRAINT PK_silver_superstore PRIMARY KEY (RowID)
    );
go

;WITH bronze_trimmed AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY RowID 
               ORDER BY bronze_id DESC
           ) AS rn
    FROM bronze.Superstore
    WHERE NULLIF(LTRIM(RTRIM(OrderID)), '') IS NOT NULL
),
cleaned AS (
    SELECT 
        TRY_CAST(NULLIF(LTRIM(RTRIM(RowID)), '') AS INT) AS RowID,
        NULLIF(LTRIM(RTRIM(OrderID)), '') AS OrderID,
        TRY_CAST(NULLIF(LTRIM(RTRIM(OrderDate)), '') AS DATE) AS OrderDate,
        NULLIF(LTRIM(RTRIM(ShipMode)), '') AS ShipMode,
        TRY_CAST(NULLIF(LTRIM(RTRIM(ShipDate)), '') AS DATE) AS ShipDate,
        NULLIF(LTRIM(RTRIM(CustomerID)), '') AS CustomerID,
        NULLIF(LTRIM(RTRIM(CustomerName)), '') AS CustomerName,
        NULLIF(LTRIM(RTRIM(Segment)), '') AS Segment,
        NULLIF(LTRIM(RTRIM(Country)), '') AS Country,
        NULLIF(LTRIM(RTRIM(City)), '') AS City,
        NULLIF(LTRIM(RTRIM(State)), '') AS State,
        NULLIF(LTRIM(RTRIM(PostalCode)), '') AS PostalCode,
        NULLIF(LTRIM(RTRIM(Region)), '') AS Region,
        NULLIF(LTRIM(RTRIM(ProductID)), '') AS ProductID,
        NULLIF(LTRIM(RTRIM(Category)), '') AS Category,
        NULLIF(LTRIM(RTRIM(SubCategory)), '') AS SubCategory,
        NULLIF(LTRIM(RTRIM(ProductName)), '') AS ProductName,
        TRY_CAST(NULLIF(LTRIM(RTRIM(Sales)), '') AS DECIMAL(10, 2)) AS Sales,
        TRY_CAST(NULLIF(LTRIM(RTRIM(Quantity)), '') AS INT) AS Quantity,
        TRY_CAST(NULLIF(LTRIM(RTRIM(Discount)), '') AS DECIMAL(10, 2)) AS Discount,
        TRY_CAST(NULLIF(LTRIM(RTRIM(Profit)), '') AS DECIMAL(10, 2)) AS Profit
    FROM bronze_trimmed
    WHERE rn = 1
),
iqr_bounds AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Sales) OVER() AS Q1_Sales,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Sales) OVER() AS Q3_Sales,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY Profit) OVER() AS Q1_Profit,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY Profit) OVER() AS Q3_Profit
    FROM cleaned
),
flagged AS (
    SELECT 
        c.RowID,
        c.CustomerID,
        c.OrderID,  
        c.OrderDate,
        c.ShipDate,
        c.ShipMode,
        c.CustomerName,
        c.Segment,
        c.Country,
        c.City,
        c.State,
        c.PostalCode,
        c.Region,
        c.ProductID,
        c.Category,
        c.SubCategory,
        c.ProductName,
        c.Sales,
        c.Quantity,
        c.Discount,
        c.Profit,
        CASE 
            WHEN c.OrderID IS NULL OR c.OrderDate IS NULL OR c.ShipDate IS NULL OR c.ShipMode IS NULL OR 
                 c.CustomerID IS NULL OR c.CustomerName IS NULL OR c.Segment IS NULL OR c.Country IS NULL OR 
                 c.City IS NULL OR c.State IS NULL OR c.PostalCode IS NULL OR c.Region IS NULL OR 
                 c.ProductID IS NULL OR c.Category IS NULL OR c.SubCategory IS NULL OR c.ProductName IS NULL OR 
                 c.Sales IS NULL OR c.Quantity IS NULL OR c.Discount IS NULL OR c.Profit IS NULL THEN 1
            ELSE 0
        END AS has_missing_value,
        CASE 
            WHEN c.Sales < 0 OR c.Quantity < 0 OR c.Discount < 0 THEN 1
            ELSE 0
        END AS has_invalid_value,
        CASE 
            WHEN c.Sales < (b.Q1_Sales - 1.5 * (b.Q3_Sales - b.Q1_Sales)) OR c.Sales > (b.Q3_Sales + 1.5 * (b.Q3_Sales - b.Q1_Sales)) OR
                 c.Profit < (b.Q1_Profit - 1.5 * (b.Q3_Profit - b.Q1_Profit)) OR c.Profit > (b.Q3_Profit + 1.5 * (b.Q3_Profit - b.Q1_Profit)) THEN 1
            ELSE 0
        END AS has_outlier_value
    FROM cleaned c
    CROSS JOIN iqr_bounds b
)
MERGE INTO silver.superstore AS tgt
USING flagged AS src
ON tgt.RowID = src.RowID
WHEN MATCHED THEN
    UPDATE SET 
        tgt.OrderID = src.OrderID,
        tgt.OrderDate = src.OrderDate,
        tgt.ShipDate = src.ShipDate,
        tgt.ShipMode = src.ShipMode,
        tgt.CustomerID = src.CustomerID,
        tgt.CustomerName = src.CustomerName,
        tgt.Segment = src.Segment,
        tgt.Country = src.Country,
        tgt.City = src.City,
        tgt.State = src.State,
        tgt.PostalCode = src.PostalCode,
        tgt.Region = src.Region,
        tgt.ProductID = src.ProductID,
        tgt.Category = src.Category,
        tgt.SubCategory = src.SubCategory,
        tgt.ProductName = src.ProductName,
        tgt.Sales = src.Sales,
        tgt.Quantity = src.Quantity,
        tgt.Discount = src.Discount,
        tgt.Profit = src.Profit,
        tgt.has_missing_value = src.has_missing_value,
        tgt.has_invalid_value = src.has_invalid_value,
        tgt.has_outlier_value = src.has_outlier_value
WHEN NOT MATCHED THEN
    INSERT ( RowID, OrderID, OrderDate, ShipDate, ShipMode, CustomerID, CustomerName, Segment, Country, City, State, PostalCode, Region, ProductID, Category, SubCategory, ProductName, Sales, Quantity, Discount, Profit, has_missing_value, has_invalid_value, has_outlier_value)
    VALUES ( src.RowID, src.OrderID, src.OrderDate, src.ShipDate, src.ShipMode, src.CustomerID, src.CustomerName, src.Segment, src.Country, src.City, src.State, src.PostalCode, src.Region, src.ProductID, src.Category, src.SubCategory, src.ProductName, src.Sales, src.Quantity, src.Discount, src.Profit, src.has_missing_value, src.has_invalid_value, src.has_outlier_value);
GO








-- ============================================
-- 0) DROP TABLES IN CORRECT DEPENDENCY ORDER
--    (fact table must be dropped BEFORE dimensions,
--     otherwise the FOREIGN KEY constraints block the DROP)
-- ============================================
IF OBJECT_ID('gold.fact_sales', 'U') IS NOT NULL
    DROP TABLE gold.fact_sales;
GO

IF OBJECT_ID('gold.dim_customer', 'U') IS NOT NULL
    DROP TABLE gold.dim_customer;
GO

IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL
    DROP TABLE gold.dim_product;
GO

IF OBJECT_ID('gold.dim_location', 'U') IS NOT NULL
    DROP TABLE gold.dim_location;
GO

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;
GO


-- ============================================
-- 1) dim_customer
-- ============================================
CREATE TABLE gold.dim_customer (
    CustomerID   VARCHAR(50) PRIMARY KEY,
    CustomerName VARCHAR(150),
    Segment      VARCHAR(50)
);
GO

-- Some CustomerIDs appear with slightly different CustomerName/Segment values
-- in the silver layer, so a plain SELECT DISTINCT can produce duplicate
-- CustomerIDs (which breaks the PRIMARY KEY). We pick ONE row per CustomerID.
;WITH ranked_customers AS (
    SELECT 
        CustomerID, CustomerName, Segment,
        ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY CustomerID) AS rn
    FROM silver.superstore
    WHERE CustomerID IS NOT NULL
)
INSERT INTO gold.dim_customer (CustomerID, CustomerName, Segment)
SELECT CustomerID, CustomerName, Segment
FROM ranked_customers
WHERE rn = 1;
GO


-- ============================================
-- 2) dim_product
-- ============================================
CREATE TABLE gold.dim_product (
    ProductID    VARCHAR(50) PRIMARY KEY,
    ProductName  VARCHAR(500),
    Category     VARCHAR(50),
    SubCategory  VARCHAR(50)
);
GO

-- Same fix as dim_customer: pick ONE row per ProductID to avoid PK violations.
;WITH ranked_products AS (
    SELECT 
        ProductID, ProductName, Category, SubCategory,
        ROW_NUMBER() OVER (PARTITION BY ProductID ORDER BY ProductID) AS rn
    FROM silver.superstore
    WHERE ProductID IS NOT NULL
)
INSERT INTO gold.dim_product (ProductID, ProductName, Category, SubCategory)
SELECT ProductID, ProductName, Category, SubCategory
FROM ranked_products
WHERE rn = 1;
GO


-- ============================================
-- 3) dim_location
-- ============================================
CREATE TABLE gold.dim_location (
    location_key INT IDENTITY(1,1) PRIMARY KEY,
    Country      VARCHAR(50),
    City         VARCHAR(50),
    State        VARCHAR(50),
    PostalCode   VARCHAR(30),
    Region       VARCHAR(50)
);
GO

INSERT INTO gold.dim_location (Country, City, State, PostalCode, Region)
SELECT DISTINCT Country, City, State, PostalCode, Region
FROM silver.superstore;
GO


-- ============================================
-- 4) dim_date
--    Combined (junk) date dimension: ONE row per distinct
--    (OrderDate, ShipDate) pair that actually occurs in the
--    data, with ONE surrogate date_key. This replaces the
--    earlier design of a generic calendar table referenced
--    twice from fact_sales (order_date_key + ship_date_key);
--    now fact_sales needs only a single date_key column, and
--    both the order-date and ship-date attributes for that
--    order line live together in this one table/row.
-- ============================================
CREATE TABLE gold.dim_date (
    date_key        INT IDENTITY(1,1) PRIMARY KEY,

    OrderDate       DATE NOT NULL,
    OrderDay        INT,
    OrderMonth      INT,
    OrderMonthName  VARCHAR(20),
    OrderQuarter    INT,
    OrderYear       INT,
    OrderWeekday    VARCHAR(20),

    ShipDate        DATE NOT NULL,
    ShipDay         INT,
    ShipMonth       INT,
    ShipMonthName   VARCHAR(20),
    ShipQuarter     INT,
    ShipYear        INT,
    ShipWeekday     VARCHAR(20)
);
GO

INSERT INTO gold.dim_date (
    OrderDate, OrderDay, OrderMonth, OrderMonthName, OrderQuarter, OrderYear, OrderWeekday,
    ShipDate, ShipDay, ShipMonth, ShipMonthName, ShipQuarter, ShipYear, ShipWeekday
)
SELECT DISTINCT
    OrderDate,
    DAY(OrderDate), MONTH(OrderDate), DATENAME(MONTH, OrderDate),
    DATEPART(QUARTER, OrderDate), YEAR(OrderDate), DATENAME(WEEKDAY, OrderDate),
    ShipDate,
    DAY(ShipDate), MONTH(ShipDate), DATENAME(MONTH, ShipDate),
    DATEPART(QUARTER, ShipDate), YEAR(ShipDate), DATENAME(WEEKDAY, ShipDate)
FROM silver.superstore
WHERE OrderDate IS NOT NULL AND ShipDate IS NOT NULL;
GO


-- ============================================
-- 5) fact_sales
--    sales_key stays the PRIMARY KEY (one row per RowID/product line item).
--    OrderID is a normal (non-unique) column with a supporting index,
--    since one OrderID can span multiple line items/products.
-- ============================================
CREATE TABLE gold.fact_sales (
    sales_key       INT IDENTITY(1,1) PRIMARY KEY,
    RowID           INT NOT NULL,
    OrderID         VARCHAR(250) NOT NULL,
    CustomerID      VARCHAR(50) NOT NULL,
    ProductID       VARCHAR(50) NOT NULL,
    location_key    INT NOT NULL,
    date_key        INT NOT NULL,   -- single FK: points to the row in
                                     -- gold.dim_date holding BOTH this
                                     -- line's OrderDate and ShipDate
    ShipMode        VARCHAR(50),
    Sales           DECIMAL(10,2),
    Quantity        INT,
    Discount        DECIMAL(10,2),
    Profit          DECIMAL(10,2),
    CONSTRAINT FK_fact_customer FOREIGN KEY (CustomerID)   REFERENCES gold.dim_customer(CustomerID),
    CONSTRAINT FK_fact_product  FOREIGN KEY (ProductID)    REFERENCES gold.dim_product(ProductID),
    CONSTRAINT FK_fact_location FOREIGN KEY (location_key) REFERENCES gold.dim_location(location_key),
    CONSTRAINT FK_fact_date     FOREIGN KEY (date_key)     REFERENCES gold.dim_date(date_key)
);
GO

INSERT INTO gold.fact_sales (
    RowID, OrderID, CustomerID, ProductID, location_key,
    date_key, ShipMode, Sales, Quantity, Discount, Profit
)
SELECT 
    s.RowID,
    s.OrderID,
    dc.CustomerID,
    dp.ProductID,
    dl.location_key,
    dd.date_key,
    s.ShipMode,
    s.Sales,
    s.Quantity,
    s.Discount,
    s.Profit
FROM silver.superstore s
JOIN gold.dim_customer dc 
    ON s.CustomerID = dc.CustomerID
JOIN gold.dim_product dp 
    ON s.ProductID = dp.ProductID
JOIN gold.dim_location dl 
    ON  ISNULL(s.Country,'') = ISNULL(dl.Country,'')
    AND ISNULL(s.City,'')    = ISNULL(dl.City,'')
    AND ISNULL(s.State,'')   = ISNULL(dl.State,'')
    AND ISNULL(s.PostalCode,'') = ISNULL(dl.PostalCode,'')
    AND ISNULL(s.Region,'')  = ISNULL(dl.Region,'')
JOIN gold.dim_date dd
    ON  s.OrderDate = dd.OrderDate
    AND s.ShipDate  = dd.ShipDate;
GO

-- ============================================================
-- QUERY OPTIMIZATION: supporting indexes on gold.fact_sales
-- Rationale: every one of the 15 business queries joins
-- fact_sales to at least one dimension table on these exact
-- columns (CustomerID, ProductID, location_key, date_key) and
-- several queries also filter/group by OrderID. Without
-- indexes, SQL Server must scan the full fact table for every
-- JOIN; these non-clustered indexes let the optimizer seek
-- directly to the matching rows instead, which matters most
-- here because fact_sales is the largest table and sits on the
-- many-side of every join in this schema.
--
-- Load-then-index: these indexes are created AFTER the INSERT
-- above rather than before it. Building them post-load avoids
-- paying index-maintenance cost on every one of the ~10K rows
-- during the bulk insert; SQL Server builds each index once,
-- in a single pass, against the already-loaded data instead.
-- ============================================================

-- Speeds up lookups/joins and GROUP BY on OrderID (Q2 dedupe by
-- order, Q15 order-level reporting)
CREATE INDEX IX_fact_sales_OrderID ON gold.fact_sales (OrderID);
GO

-- Speeds up joins to gold.dim_customer (Q2, Q7, Q11, Q14, Q15)
CREATE INDEX IX_fact_sales_CustomerID ON gold.fact_sales (CustomerID);
GO

-- Speeds up joins to gold.dim_product (Q1, Q6, Q9, Q10, Q14, Q15)
CREATE INDEX IX_fact_sales_ProductID ON gold.fact_sales (ProductID);
GO

-- Speeds up joins to gold.dim_location (Q3, Q5, Q11, Q12, Q15)
CREATE INDEX IX_fact_sales_location_key ON gold.fact_sales (location_key);
GO

-- Speeds up joins to gold.dim_date (Q4, Q8, Q13, Q15) - now a single
-- index since fact_sales has only one date_key column (see redesign above)
CREATE INDEX IX_fact_sales_date_key ON gold.fact_sales (date_key);
GO







--================================
--  15 Query 
--==================================


-- Q1: What are the total sales and total profit generated by each
--     product category? 
SELECT p.Category, SUM(f.Sales) AS TotalSales, SUM(f.Profit) AS TotalProfit
FROM gold.fact_sales f
JOIN gold.dim_product p ON f.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY TotalSales DESC;



-- Q2: Who are our top 10 customers by total sales value?


SELECT TOP 10 (CustomerName), SUM(Sales) as total_Sales
FROM gold.fact_sales f
LEFT JOIN gold.dim_customer c
    on c.CustomerID =f.CustomerID
GROUP BY CustomerName
ORDER BY total_Sales DESC


-- Q3: How do sales and profit break down by geographic region?

SELECT l.Region, SUM(f.Sales) AS TotalSales, SUM(f.Profit) AS TotalProfit
FROM gold.fact_sales f
INNER JOIN gold.dim_location l ON f.location_key = l.location_key
GROUP BY l.Region



-- Q4: What is the total sales trend by year and month?

SELECT d.OrderYear, d.OrderMonthName, SUM(f.Sales) AS TotalSales
FROM gold.fact_sales f
LEFT JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY d.OrderYear, d.OrderMonthName
ORDER BY d.OrderYear, TotalSales DESC;



-- Q5: What is the average discount given and number of orders
--     per shipping mode? 

SELECT f.ShipMode , Avg(Discount) As Averae_Discount 
FROM gold.fact_sales f LEFT JOIN gold.dim_location l
    ON f.location_key=l.location_key
GROUP BY f.ShipMode;



-- Q6: What are the top 5 most profitable products within each
--     category? 
WITH product_profit AS (
    SELECT TOP (5) p.Category, p.ProductName, SUM(f.Profit) AS TotalProfit,
           ROW_NUMBER() OVER (PARTITION BY p.Category ORDER BY SUM(f.Profit) DESC) AS rnk
    FROM gold.fact_sales f
    JOIN gold.dim_product p ON f.ProductID = p.ProductID
    GROUP BY p.Category, p.ProductName
)
SELECT Category, ProductName, TotalProfit
FROM product_profit
WHERE rnk <= 5
ORDER BY Category, rnk;



-- Q7: Which customers generate more sales than the average customer? 

WITH customer_sales AS (
    SELECT c.CustomerID, c.CustomerName, SUM(f.Sales) AS TotalSales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_customer c ON f.CustomerID = c.CustomerID
    GROUP BY c.CustomerID, c.CustomerName
)
SELECT CustomerName, TotalSales
FROM customer_sales
WHERE TotalSales > (SELECT AVG(TotalSales) FROM customer_sales)
ORDER BY TotalSales DESC;



-- Q8: How are total sales growing (or declining) month over month?

WITH monthly_sales AS (
    SELECT d.OrderYear AS year, d.OrderMonth AS month, SUM(f.Sales) AS TotalSales
    FROM gold.fact_sales f
    LEFT JOIN gold.dim_date d ON f.date_key = d.date_key
    GROUP BY d.OrderYear, d.OrderMonth
)
SELECT year, month, TotalSales,
       LAG(TotalSales) OVER (ORDER BY year, month) AS PrevMonthSales,
       TotalSales - LAG(TotalSales) OVER (ORDER BY year, month) AS Growth
FROM monthly_sales
ORDER BY year, month;



-- Q9: What is the profit margin percentage for each sub-category,
--     ranked from most to least profitable? 
WITH sub_summary AS (
    SELECT p.SubCategory, SUM(f.Sales) AS TotalSales, SUM(f.Profit) AS TotalProfit
    FROM gold.fact_sales f
    JOIN gold.dim_product p ON f.ProductID = p.ProductID
    GROUP BY p.SubCategory
)
SELECT SubCategory, TotalSales, TotalProfit,
       CAST(TotalProfit * 100.0 / TotalSales AS DECIMAL(5,2)) AS Profitmargin
FROM sub_summary
ORDER BY Profitmargin DESC;




-- Q10: Which products sell above the average total sales of all
--      products? (Flags top-performing products for restocking)
SELECT p.ProductName, SUM(f.Sales) AS TotalSales
FROM gold.fact_sales f
LEFT JOIN gold.dim_product p ON f.ProductID = p.ProductID
GROUP BY p.ProductName
HAVING SUM(f.Sales) > ( SELECT AVG(ProductTotal) 
FROM (
        SELECT SUM(Sales) AS ProductTotal
        FROM gold.fact_sales
        GROUP BY ProductID
    ) AS avg_tot_Sales
)
ORDER BY TotalSales DESC;



-- Q11: Which customers have never placed an order in the West region?

SELECT c.CustomerName
FROM gold.dim_customer c
WHERE c.CustomerID NOT IN (
    SELECT DISTINCT f.CustomerID
    FROM gold.fact_sales f
    JOIN gold.dim_location l ON f.location_key = l.location_key
    WHERE l.Region = 'West'
);



-- Q12: What is the single highest sale value recorded in each state?
-- FIX: the original version reused the same alias (l) for both the
-- outer and inner queries, so "WHERE l.State = l.State" compared the
-- inner table to itself instead of correlating with the outer row -
-- it always returned only the single global max sale. Using a
-- distinct alias (l2) for the inner query fixes the correlation so
-- one row per state is returned.
SELECT l.State, l.City, f.Sales
FROM gold.fact_sales f
JOIN gold.dim_location l ON f.location_key = l.location_key
WHERE f.Sales = (
    SELECT MAX(f2.Sales)
    FROM gold.fact_sales f2
    JOIN gold.dim_location l2 ON f2.location_key = l2.location_key
    WHERE l2.State = l.State
)
ORDER BY f.Sales DESC;



-- Q13: What is the average number of days between order date and
--      ship date for each shipping mode? 
SELECT f.ShipMode,
       AVG(DATEDIFF(DAY, d.OrderDate, d.ShipDate)) AS AvgShippingDays
FROM gold.fact_sales f
LEFT JOIN gold.dim_date d ON f.date_key = d.date_key
GROUP BY f.ShipMode
ORDER BY AvgShippingDays;



-- Q14: For each customer segment, which product category generates
--      the highest sales? 
WITH segment_category AS (
    SELECT c.Segment, p.Category, SUM(f.Sales) AS TotalSales,
           RANK() OVER (PARTITION BY c.Segment ORDER BY SUM(f.Sales) DESC) AS rnk
    FROM gold.fact_sales f
    JOIN gold.dim_customer c ON f.CustomerID = c.CustomerID
    JOIN gold.dim_product p ON f.ProductID = p.ProductID
    GROUP BY c.Segment, p.Category
)
SELECT Segment, Category, TotalSales
FROM segment_category
WHERE rnk = 1;



-- Q15: Which individual orders resulted in a loss (negative profit),
--      and what are the full details of those transactions?

SELECT f.OrderID, c.CustomerName, p.ProductName, l.State, d.OrderDate,
       f.Sales, f.Discount, f.Profit
FROM gold.fact_sales f
JOIN gold.dim_customer c ON f.CustomerID = c.CustomerID
JOIN gold.dim_product p ON f.ProductID = p.ProductID
JOIN gold.dim_location l ON f.location_key = l.location_key
JOIN gold.dim_date d ON f.date_key = d.date_key
WHERE f.Profit < 0
ORDER BY f.Profit ASC;


-- ============================================================
--  VIEW: gold.category_kpi
--  Purpose: Shows total sales, total profit, total quantity,
--  and profit margin % for each product category.
-- ============================================================
IF OBJECT_ID('gold.category_kpi', 'V') IS NOT NULL
    DROP VIEW gold.category_kpi;
GO
 
CREATE VIEW gold.category_kpi AS
SELECT
    p.Category,
    SUM(f.Sales)    AS TotalSales,
    SUM(f.Profit)   AS TotalProfit,
    SUM(f.Quantity) AS TotalQuantity,
    CAST(SUM(f.Profit) * 100.0 / SUM(f.Sales) AS DECIMAL(6,2)) AS ProfitMargin
FROM gold.fact_sales f
JOIN gold.dim_product p ON f.ProductID = p.ProductID
GROUP BY p.Category;
GO


SELECT * FROM gold.category_kpi;
GO


-- ============================================================
--  STORED PROCEDURE: gold.usp_get_region_kpi
--  Purpose: Returns total sales, total profit, and order count
--  for a given region, directly supporting regional KPI
--  reporting. If no region is passed, it returns the KPIs for
--  all regions - the query logic (JOIN + aggregation) is written
--  once here and reused every time the procedure is called,
--  instead of being copy-pasted for each report run.
--
--  Parameter:
--    @Region VARCHAR(50) = NULL  -> optional region filter
-- ============================================================
IF OBJECT_ID('gold.usp_get_region_kpi', 'P') IS NOT NULL
    DROP PROCEDURE gold.usp_get_region_kpi;
GO

CREATE PROCEDURE gold.usp_get_region_kpi
    @Region VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.Region,
        COUNT(DISTINCT f.OrderID) AS OrderCount,
        SUM(f.Sales)              AS TotalSales,
        SUM(f.Profit)             AS TotalProfit,
        CAST(SUM(f.Profit) * 100.0 / SUM(f.Sales) AS DECIMAL(6,2)) AS ProfitMarginPct
    FROM gold.fact_sales f
    JOIN gold.dim_location l ON f.location_key = l.location_key
    WHERE @Region IS NULL OR l.Region = @Region
    GROUP BY l.Region
    ORDER BY TotalSales DESC;
END;
GO

-- Example usage:
-- EXEC gold.usp_get_region_kpi;                 -- all regions
-- EXEC gold.usp_get_region_kpi @Region = 'Central'; -- one region only
EXEC gold.usp_get_region_kpi;
GO


 ----------------------------------------------------------------------
 --analytical reports 
------------------------------------------------------------------------


/* ----------------------------------------------------------------
   1) PROFITABILITY
   ---------------------------------------------------------------- */
 
-- Profit by Category (Q1 / gold.category_kpi)
-- Technology: $170,416.29 sales | $28,718.84 profit | 16.85% margin
-- Office Supplies: $167,026.33 sales | $8,604.85 profit | 5.15% margin
-- Furniture: $163,797.26 sales | -$2,894.75 profit | -1.77% margin
-- FINDING: Furniture is the only category losing money despite
--          near-equal sales to Technology.
 
-- Profit Margin by Sub-Category (Q9)
-- Best margins: Copiers (41.6%, $37.3K sales), Labels (43.8%, small base)
-- FINDING: Copiers are the strongest performer on both volume and margin.
 
-- Loss-Making Orders (Q15)
-- 722 orders recorded a loss, mostly copier/binding equipment in some sta.
-- Linked to Q5: First Class shipments carry the highest avg discount (26.6%).
-- FINDING: Heavy discounting on premium shipping is likely driving losses.
 
 
/* ----------------------------------------------------------------
   2) CUSTOMER BEHAVIOR
   ---------------------------------------------------------------- */
 
-- Top 10 Customers (Q2)
-- #1 Tamara Chand: $18,437.14 (~50% more than #2, Adrian Barton: $12,181.60)
-- FINDING: Revenue is concentrated at the very top of the customer list.
 
-- Top Category per Segment (Q14)
-- Consumer -> Office Supplies ($93,111.40)
-- Corporate -> Technology ($64,772.48)
-- Home Office -> Technology ($32,953.06)
-- FINDING: Purchasing behavior differs clearly by segment.
 
-- Regional Coverage (Q3, Q11)
-- Dataset contains Central region only ($501,239.88 sales).
-- LIMITATION: No real cross-region comparison possible with this file alone.
 
 
/* ----------------------------------------------------------------
   3) SALES TRENDS
   ---------------------------------------------------------------- */
 
-- Monthly Pattern (Q4)
-- September consistently peaks (e.g., Sep 2013: $34,408.69).
-- FINDING: Recurring seasonal spike, likely worth planning around.
 
-- Month-over-Month Growth (Q8)
-- High volatility: e.g., 2013 swung from -$2,115.23 (Apr) to +$5,597.82 (Jun).
-- FINDING: Sales are volatile month to month, not steadily trending.
 
-- Shipping Performance (Q13)
-- Same Day: 0 days | First Class: 2 | Second Class: 3 | Standard: 4
-- FINDING: Fulfillment times match shipping mode labels reliably.
 
 
/* ----------------------------------------------------------------
   RECOMMENDATIONS
   ----------------------------------------------------------------
   1. Investigate Furniture's negative margin (discounts/costs).
   2. Cap discounting on First Class shipments.
   3. Grow the Copiers sub-category (best margin + volume).
   4. Target marketing by segment (Office Supplies vs Technology).
   5. Plan inventory/staffing around the September sales peak.
   6. Add East/South/West data for real regional analysis.
   ---------------------------------------------------------------- */