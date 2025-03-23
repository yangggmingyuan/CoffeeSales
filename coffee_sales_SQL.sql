-- ===========================================
-- 1. Set the Database Context
-- ===========================================
USE [caffee_sales];
GO

-- ===========================================
-- 2. Explore Raw Tables (Before Cleanup)
-- ===========================================
SELECT * FROM [dbo].[customers$];
SELECT * FROM [dbo].[orders$];
SELECT * FROM [dbo].[products$];

-- ===========================================
-- 3. Rename Columns for Consistency
-- ===========================================

-- Customers Table
EXEC sp_rename 'customers$.[Customer ID]', 'Customer_ID', 'COLUMN';
EXEC sp_rename 'customers$.[Customer Name]', 'Customer_Name', 'COLUMN';
EXEC sp_rename 'customers$.[Phone Number]', 'Phone_Number', 'COLUMN';
EXEC sp_rename 'customers$.[Address Line 1]', 'Address_Line_1', 'COLUMN';
EXEC sp_rename 'customers$.[Loyalty Card]', 'Loyalty_Card', 'COLUMN';

-- Orders Table
EXEC sp_rename 'orders$.[Order ID]', 'Order_ID', 'COLUMN';
EXEC sp_rename 'orders$.[Order Date]', 'Order_Date', 'COLUMN';
EXEC sp_rename 'orders$.[Customer ID]', 'Customer_ID', 'COLUMN';
EXEC sp_rename 'orders$.[Product ID]', 'Product_ID', 'COLUMN';
EXEC sp_rename 'orders$.[Customer Name]', 'Customer_Name', 'COLUMN';
EXEC sp_rename 'orders$.[Phone Number]', 'Phone_Number', 'COLUMN';
EXEC sp_rename 'orders$.[Coffee Type]', 'Coffee_Type', 'COLUMN';
EXEC sp_rename 'orders$.[Roast Type]', 'Roast_Type', 'COLUMN';
EXEC sp_rename 'orders$.[Unit Price]', 'Unit_Price', 'COLUMN';
EXEC sp_rename 'orders$.[Loyalty Card]', 'Loyalty_Card', 'COLUMN';
EXEC sp_rename 'orders$.[Address Line 1]', 'Address_Line_1', 'COLUMN';

-- Products Table
EXEC sp_rename 'products$.[Product ID]', 'Product_ID', 'COLUMN';
EXEC sp_rename 'products$.[Coffee Type]', 'Coffee_Type', 'COLUMN';
EXEC sp_rename 'products$.[Roast Type]', 'Roast_Type', 'COLUMN';
EXEC sp_rename 'products$.[Unit Price]', 'Unit_Price', 'COLUMN';
EXEC sp_rename 'products$.[Price per 100g]', 'Price_per_100g', 'COLUMN';

-- ===========================================
-- 4. Drop Redundant Columns
-- ===========================================
ALTER TABLE [dbo].[orders$]
DROP COLUMN 
    Customer_Name,
    Email,
    Country,
    Coffee_Type,
    Roast_Type,
    Size,
    Unit_Price,
    Sales;
-- ===========================================
-- 4. change the datatype of order_daate column.
-- ===========================================

UPDATE [orders$]
SET Order_Date = CAST(Order_Date AS DATE);

ALTER TABLE [orders$]
ALTER COLUMN Order_Date DATE;

-- ===========================================
-- 5. Handle NULL or Missing Values
-- ===========================================
-- Observation
SELECT 
    COUNT(*) AS TotalRows,
    COUNT(Customer_Name) AS NonNullCustomerNames,
    COUNT(Email) AS NonNullEmails,
    COUNT(Phone_Number) AS NonNullPhoneNumbers,
    COUNT(Address_Line_1) AS NonNullAddressLines,
    COUNT(Postcode) AS NonNullPostcodes,
    COUNT(Loyalty_Card) AS NonNullLoyaltyCards
FROM [dbo].[customers$];

-- Handling NULLs
UPDATE [dbo].[customers$]
SET 
    Customer_Name = ISNULL(Customer_Name, 'Unknown'),
    Email = ISNULL(Email, '@'),
    Phone_Number = ISNULL(Phone_Number, 'Unknown'),
    Address_Line_1 = ISNULL(Address_Line_1, 'Not Specified'),
    City = ISNULL(City, 'Unknown'),
    Country = ISNULL(Country, 'N/A'),
    Postcode = ISNULL(Postcode, 0),
    Loyalty_Card = ISNULL(Loyalty_Card, 0);

-- ===========================================
-- 6. Business Insights Queries
-- ===========================================

-- Most Expensive Product
SELECT TOP 1
    Product_ID,
    Coffee_Type,
    Roast_Type,
    Size,
    Unit_Price
FROM [dbo].[products$]
ORDER BY Unit_Price DESC;

-- Product with Highest Sales
WITH total_product_sales AS (
    SELECT 
        p.Product_ID,
        p.Coffee_Type,
        SUM(o.Quantity) AS total_sales
    FROM 
        [dbo].[products$] p
    JOIN 
        [dbo].[orders$] o ON p.Product_ID = o.Product_ID
    GROUP BY 
        p.Product_ID, p.Coffee_Type
)
SELECT 
    Product_ID,
    Coffee_Type,
    total_sales
FROM total_product_sales
ORDER BY total_sales DESC;

-- Top 10 Products by Income
WITH total_product_sales AS (
    SELECT 
        p.Product_ID,
        p.Coffee_Type,
        SUM(o.Quantity) AS total_sales
    FROM 
        [dbo].[products$] p
    JOIN 
        [dbo].[orders$] o ON p.Product_ID = o.Product_ID
    GROUP BY 
        p.Product_ID, p.Coffee_Type
)
SELECT TOP 10
    t.Product_ID,
    t.Coffee_Type,
    t.total_sales,
    p.Profit,
    ROUND(t.total_sales * p.Profit, 0) AS Incomes
FROM 
    total_product_sales t
JOIN 
    [dbo].[products$] p ON t.Product_ID = p.Product_ID
ORDER BY Incomes DESC;

-- Top 10 Customers by Total Spending
WITH customer_orders AS (
    SELECT 
        o.Customer_ID,
        c.Customer_Name,
        o.Product_ID,
        o.Quantity,
        p.Unit_Price
    FROM 
        [dbo].[orders$] o
    JOIN 
        [dbo].[customers$] c ON o.Customer_ID = c.Customer_ID
    JOIN 
        [dbo].[products$] p ON o.Product_ID = p.Product_ID
),
customer_spending_details AS (
    SELECT 
        Customer_ID,
        Customer_Name,
        (Quantity * Unit_Price) AS total_spend
    FROM customer_orders
)
SELECT TOP 10
    Customer_ID,
    Customer_Name,
    SUM(total_spend) AS total_spend
FROM customer_spending_details
GROUP BY Customer_ID, Customer_Name
ORDER BY total_spend DESC;

-- Country with Most Customers
SELECT 
    Country,
    COUNT(*) AS Total_Customers
FROM [dbo].[customers$]
GROUP BY Country;

-- Top 3 Cities in the US by Customers
SELECT TOP 3
    City,
    COUNT(Customer_ID) AS Total_Customers
FROM [dbo].[customers$]
WHERE Country = 'United States'
GROUP BY City
ORDER BY Total_Customers DESC;

-- Categorize Products by Profit and Price
SELECT 
    Product_ID,
    Coffee_Type,
    Roast_Type,
    Size,
    CASE 
        WHEN Profit < 1 THEN 'Low Profit'
        WHEN Profit >= 1 AND Profit < 3 THEN 'Healthy Profit'
        ELSE 'High Profit'
    END AS Profit_Category,
    CASE 
        WHEN Unit_Price <= 10 THEN 'Low Price'
        WHEN Unit_Price > 10 AND Unit_Price <= 20 THEN 'Medium Price'
        ELSE 'High Price'
    END AS Price_Category
FROM [dbo].[products$];

-- Profit trend over time (yearly)
WITH yearly_profits AS (
    SELECT 
        YEAR(o.Order_Date) AS Order_Year,
        SUM(o.Quantity * p.Profit) AS Annual_Profit
    FROM 
        [dbo].[orders$] o
    JOIN 
        [dbo].[products$] p ON o.Product_ID = p.Product_ID
    GROUP BY 
        YEAR(o.Order_Date)
)
SELECT 
    Order_Year,
    Annual_Profit
FROM 
    yearly_profits
ORDER BY 
    Order_Year;



