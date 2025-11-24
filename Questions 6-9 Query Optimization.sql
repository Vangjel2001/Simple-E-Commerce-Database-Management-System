-- Question 6

-- INSERT a shipped order with total_amount > $1000
UPDATE PRODUCTS 
SET units_in_stock = 12
WHERE product_id = 5;

INSERT INTO ORDERS(customer_id, order_date, order_status, total_amount)
VALUES(5, ADD_MONTHS(SYSDATE, -1), 'S', 0);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(7, 1, 5, 6);

SELECT *
FROM ORDERS;

SELECT *
FROM PRODUCTS;

SELECT *
FROM ORDER_ITEMS;



-- Run the initial query
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE UPPER(o.order_status) = 'S' -- shipped        
AND o.total_amount > 1000;

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE UPPER(o.order_status) = 'S' -- shipped        
AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost was 2

-- Improve the query by computing the stats of the 2 tables
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'CUSTOMERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE UPPER(o.order_status) = 'S' AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Surprisingly, the query cost went UP from 2 to 4 after analyzing the statistics of the tables before running the query

-- Check all the indexes of the columns of the ORDERS and CUSTOMERS tables
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS 
WHERE TABLE_NAME IN ('CUSTOMERS', 'ORDERS');

-- Let's create an index on the total_amount column on the ORDERS table
-- DROP INDEX ORDERS_TOTAL_AMOUNT_IX;

CREATE INDEX ORDERS_TOTAL_AMOUNT_IX
ON ORDERS(total_amount);

-- Refresh the stats of the ORDERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE UPPER(o.order_status) = 'S' AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The index on the total amount field has been used now to execute the query, which brought its cost down from 4 to 3
-- The index on that field helped because total_amount is used for filtering on the WHERE clause of the query

-- Let's create a function-based BITMAP index on UPPER(ORDER_STATUS) since this field has low cardinality (few distinct values which are repeated often)

-- DROP INDEX ORDERS_UPPER_ORDER_STATUS_IX;
CREATE BITMAP INDEX ORDERS_UPPER_ORDER_STATUS_IX
ON ORDERS(UPPER(ORDER_STATUS));

-- Refresh the stats of the ORDERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE UPPER(o.order_status) = 'S' AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The newly created index on UPPER(ORDER_STATUS) was not used in the query, so its cost remained the same: 3.

-- Let's try to rewrite the predicate of the query (the WHERE condition). 
-- Let's remove the UPPER function since it is known to prevent the use of indexes and decrease query performance.

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status = 'S' AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The cost of the query is still 3

-- Let's create a BITMAP index on the order_status column since it has low cardinality and re-run the query

-- DROP INDEX ORDERS_ORDER_STATUS_IX; 
CREATE BITMAP INDEX ORDERS_ORDER_STATUS_IX 
ON ORDERS(ORDER_STATUS);

-- Refresh the stats of the ORDERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR
SELECT o.order_id, c.last_name, o.total_amount 
FROM orders o JOIN customers c ON o.customer_id = c.customer_id 
WHERE o.order_status = 'S' AND o.total_amount > 1000;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The BITMAP index on order_status was not used and the query cost remained 3



-- Question 7

-- Run the initial query
SELECT p.product_name, SUM(oi.quantity) AS qty_sold 
FROM ORDER_ITEMS oi 
JOIN PRODUCTS p ON oi.product_id = p.product_id 
GROUP BY p.product_name 
ORDER BY qty_sold DESC;

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT p.product_name, SUM(oi.quantity) AS qty_sold 
FROM ORDER_ITEMS oi 
JOIN PRODUCTS p ON oi.product_id = p.product_id 
GROUP BY p.product_name 
ORDER BY qty_sold DESC;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost was 4

-- Improve the query by computing the stats of the 2 tables
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'PRODUCTS', cascade => TRUE);
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDER_ITEMS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT p.product_name, SUM(oi.quantity) AS qty_sold 
FROM ORDER_ITEMS oi 
JOIN PRODUCTS p ON oi.product_id = p.product_id 
GROUP BY p.product_name 
ORDER BY qty_sold DESC;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- Surprisingly, the query cost went UP from 4 to 8 after analyzing the statistics of the tables before running the query

-- Check all the indexes of the columns of the ORDER_ITEMS and PRODUCTS tables
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS 
WHERE TABLE_NAME IN ('ORDER_ITEMS', 'PRODUCTS');

-- Let's create an index on the product_name field on the PRODUCTS table

-- DROP INDEX PRODUCTS_PRODUCT_NAME_IX;
CREATE INDEX PRODUCTS_PRODUCT_NAME_IX
ON PRODUCTS(product_name);

-- Refresh the stats of the PRODUCTS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'PRODUCTS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT p.product_name, SUM(oi.quantity) AS qty_sold 
FROM ORDER_ITEMS oi 
JOIN PRODUCTS p ON oi.product_id = p.product_id 
GROUP BY p.product_name 
ORDER BY qty_sold DESC;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The index created on the product_name field has been used to execute the query and the query cost dropped from 8 to 7
-- This happened because this field is used on the GROUP BY clause



-- QUESTION 8

-- Add the city column on the CUSTOMERS table
ALTER TABLE CUSTOMERS 
ADD city VARCHAR2(100);

-- Add city values to the rows in the CUSTOMERS table
UPDATE CUSTOMERS 
SET city = 'Manchester'
WHERE customer_id BETWEEN 1 AND 3;

UPDATE CUSTOMERS 
SET city = 'Bristol'
WHERE customer_id BETWEEN 4 AND 6;

-- Add the NOT NULL constraint to the city field
ALTER TABLE CUSTOMERS 
MODIFY city VARCHAR2(100) NOT NULL;



-- Run the initial query
SELECT c.city, SUM(o.total_amount) AS total_spent 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
GROUP BY c.city 
HAVING  SUM(o.total_amount) > 5000;

-- Let's modify the query for total_amount > 1500 instead of total_amount > 5000 in order for the query to return some results
SELECT c.city, SUM(o.total_amount) AS total_spent 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
GROUP BY c.city 
HAVING  SUM(o.total_amount) > 1500;

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.city, SUM(o.total_amount) AS total_spent 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
GROUP BY c.city 
HAVING  SUM(o.total_amount) > 1500;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost was 7

-- Improve the query performance by computing the stats of the 2 tables
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'CUSTOMERS', cascade => TRUE);
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.city, SUM(o.total_amount) AS total_spent 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
GROUP BY c.city 
HAVING  SUM(o.total_amount) > 1500;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost remained the same even after analyzing table statistics: 7. 

-- Check all the indexes of the columns of the CUSTOMERS and ORDERS tables
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS 
WHERE TABLE_NAME IN ('CUSTOMERS', 'ORDERS');

-- Let's create an index on the city field on the CUSTOMERS table
-- The city field has low cardinality because there are only 2 unique city values and each of them is repeated 3 times
-- Therefore, a BITMAP index on the city field would be more helpful than a B-TREE (DEFAULT) index

-- DROP INDEX CUSTOMERS_CITY_IX;

CREATE BITMAP INDEX CUSTOMERS_CITY_IX
ON CUSTOMERS(city);

-- Refresh the stats of the CUSTOMERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'CUSTOMERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.city, SUM(o.total_amount) AS total_spent 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
GROUP BY c.city 
HAVING  SUM(o.total_amount) > 1500;

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The BITMAP index created on the city field has been used to execute the query and the query cost dropped from 7 to 6
-- This happened because this field is used on the GROUP BY clause



-- Second Part Of Question 8

-- Run the initial query
SELECT oi.order_id, p.product_name, oi.quantity, p.units_in_stock 
FROM ORDER_ITEMS oi JOIN PRODUCTS p 
ON oi.product_id = p.product_id 
WHERE p.units_in_stock < 10; 

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR  
SELECT oi.order_id, p.product_name, oi.quantity, p.units_in_stock 
FROM ORDER_ITEMS oi JOIN PRODUCTS p 
ON oi.product_id = p.product_id 
WHERE p.units_in_stock < 10; 

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost was 7. The statistics for the ORDER_ITEMS and PRODUCTS tables were calculated above AFTER the changes in those tables so
-- we do no need to re-analyze them until these tables change again.

-- Check all the indexes of the columns of the ORDER_ITEMS and PRODUCTS tables
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS 
WHERE TABLE_NAME IN ('ORDER_ITEMS', 'PRODUCTS');

-- Create an index on the units_in_stock column in the PRODUCTS table
-- DROP INDEX PRODUCTS_UNITS_IN_STOCK_IX;

CREATE INDEX PRODUCTS_UNITS_IN_STOCK_IX
ON PRODUCTS(units_in_stock);

-- Refresh the stats of the PRODUCTS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'PRODUCTS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR  
SELECT oi.order_id, p.product_name, oi.quantity, p.units_in_stock 
FROM ORDER_ITEMS oi JOIN PRODUCTS p 
ON oi.product_id = p.product_id 
WHERE p.units_in_stock < 10; 

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The index created on the units_in_stock field has been used to execute the query and the query cost dropped from 7 to 5
-- This happened because this field is used on the WHERE clause for filtering



-- QUESTION 9

-- Run the initial query
SELECT c.customer_id, c.last_name, o.order_id, o.total_amount 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
WHERE o.order_status = 'P' AND   
o.total_amount > 
( 
    SELECT AVG(total_amount) 
    FROM   orders 
    WHERE  order_status = 'P' 
);

-- Check all the indexes of the columns of the CUSTOMERS and ORDERS tables
SELECT TABLE_NAME, INDEX_NAME, COLUMN_NAME
FROM USER_IND_COLUMNS 
WHERE TABLE_NAME IN ('CUSTOMERS', 'ORDERS');

-- Drop most of the indexes on the ORDERS table so that we can check the initial query performance when there are not many indexes on the tables
DROP INDEX ORDERS_TOTAL_AMOUNT_IX;
DROP INDEX ORDERS_UPPER_ORDER_STATUS_IX;
DROP INDEX ORDERS_ORDER_STATUS_IX;

-- Refresh the stats of the ORDERS table since there are less indexes on it now. The CUSTOMERS table statistics were calculated above and the table
-- state has not changed since they were calculated, so there is no need to re-analyze this table.
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.customer_id, c.last_name, o.order_id, o.total_amount 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
WHERE o.order_status = 'P' AND   
o.total_amount > 
( 
    SELECT AVG(total_amount) 
    FROM   orders 
    WHERE  order_status = 'P' 
);

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The query cost was 7.

-- Let's re-create the index on the order status column and re-run the query

-- DROP INDEX ORDERS_ORDER_STATUS_IX;
CREATE BITMAP INDEX ORDERS_ORDER_STATUS_IX 
ON ORDERS(ORDER_STATUS);

-- Refresh the stats of the ORDERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.customer_id, c.last_name, o.order_id, o.total_amount 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
WHERE o.order_status = 'P' AND   
o.total_amount > 
( 
    SELECT AVG(total_amount) 
    FROM   orders 
    WHERE  order_status = 'P' 
);

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The index created on the order_status field has not been used to execute the query and the query cost remained 7

-- Let's re-create the index on the total_amount column and re-run the query

-- DROP INDEX ORDERS_TOTAL_AMOUNT_IX;

CREATE INDEX ORDERS_TOTAL_AMOUNT_IX
ON ORDERS(total_amount);

-- Refresh the stats of the ORDERS table since there is a new index on it now
EXEC DBMS_STATS.GATHER_TABLE_STATS(ownname => 'HR', tabname => 'ORDERS', cascade => TRUE);

-- Capture the cost statistics of the query
EXPLAIN PLAN FOR 
SELECT c.customer_id, c.last_name, o.order_id, o.total_amount 
FROM CUSTOMERS c JOIN ORDERS o 
ON o.customer_id = c.customer_id 
WHERE o.order_status = 'P' AND   
o.total_amount > 
( 
    SELECT AVG(total_amount) 
    FROM   orders 
    WHERE  order_status = 'P' 
);

SELECT *
FROM TABLE(DBMS_XPLAN.DISPLAY);

-- The index on total_amount has been used and the query cost went from 7 to 5. Also, now the order_status column's index has also been used to execute the query.
-- The indexes created on these columns helped with query performance because order_status is on the WHERE condition of both the inner and outer queries.
-- total_amount is used on the WHERE clause of the outer query and on the AVG aggregate function of the INNER query.


