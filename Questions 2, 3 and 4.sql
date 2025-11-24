-- QUESTION 3

-- Create a trigger that checks the quantity before an INSERT on ORDER_ITEMS and ensures that the quantity is smaller or equal to the units in stock that the product has
CREATE OR REPLACE TRIGGER BI_ORDER_ITEMS_STK
BEFORE INSERT ON ORDER_ITEMS
FOR EACH ROW    

DECLARE 
    insufficient_stock_ex EXCEPTION;
    null_units_in_stock_ex EXCEPTION;

    stock_level PRODUCTS.UNITS_IN_STOCK%TYPE;

BEGIN
    -- Get the units_in_stock value from the PRODUCTS table and store it on the stock_level variable
    SELECT units_in_stock
    INTO stock_level
    FROM PRODUCTS 
    WHERE product_id = :NEW.product_id;

    -- Check if units_in_stock was NULL
    IF stock_level IS NULL THEN    
        RAISE null_units_in_stock_ex;
    END IF;

    -- Check if the quantity requested is greater than the product's stock level
    IF :NEW.quantity > stock_level THEN    
        RAISE insufficient_stock_ex;
    END IF;

EXCEPTION 
    WHEN insufficient_stock_ex THEN    
        RAISE_APPLICATION_ERROR(-20001, 'Insufficient stock.');
    WHEN null_units_in_stock_ex THEN    
        RAISE_APPLICATION_ERROR(-20002, 'The units_in_stock value in the PRODUCTS table for product with id ' || :NEW.product_id || ' is NULL.');
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20003, SQLERRM);

END BI_ORDER_ITEMS_STK;



-- DROP TABLE RESTOCK_ALERTS;

-- Create a RESTOCK_ALERTS table which stores messages logged when product stock falls below reorder_level
CREATE TABLE RESTOCK_ALERTS
(
    restock_alert_id NUMBER(9, 0) CONSTRAINT restock_alerts_restock_alert_id_pk PRIMARY KEY,
    product_id NUMBER(6, 0) CONSTRAINT restock_alerts_products_fk REFERENCES PRODUCTS(product_id),
    restock_alert_date DATE DEFAULT SYSDATE CONSTRAINT restock_alerts_restock_alert_date_nn NOT NULL,    
    restock_alert_message VARCHAR2(500) CONSTRAINT restock_alerts_restock_alert_message_nn NOT NULL 
);

-- DROP SEQUENCE restock_alert_id_seq;

-- Create the restock_alert_id sequence
CREATE SEQUENCE restock_alert_id_seq
START WITH 1
INCREMENT BY 1
NOCACHE 
NOCYCLE;
    
-- Create a trigger that decrements the units_in_stock value from the PRODUCTS table after an INSERT statement execution on the ORDER_ITEMS table
CREATE OR REPLACE TRIGGER AI_ORDER_ITEMS_UPD_STK
AFTER INSERT ON ORDER_ITEMS
FOR EACH ROW    

DECLARE
    null_quantity_ex EXCEPTION;

    reordering_level PRODUCTS.REORDER_LEVEL%TYPE;
    stock_level PRODUCTS.UNITS_IN_STOCK%TYPE;

    alert_message RESTOCK_ALERTS.RESTOCK_ALERT_MESSAGE%TYPE;

BEGIN 
    -- Check if the quantity of the inserted row on ORDER_ITEMS is NULL
    IF :NEW.quantity IS NULL THEN
        RAISE null_quantity_ex;
    END IF;

    -- Decrement the units_in_stock value in the PRODUCTS table
    UPDATE PRODUCTS 
    SET units_in_stock = units_in_stock - :NEW.quantity
    WHERE product_id = :NEW.product_id;

    -- Get the units_in_stock and reorder_level values from the PRODUCTS table
    SELECT units_in_stock, reorder_level
    INTO stock_level, reordering_level
    FROM PRODUCTS 
    WHERE product_id = :NEW.product_id;

    -- Check if the product's stock level has fallen below the reordering level
    IF stock_level < reordering_level THEN
        -- Construct the alert message
        alert_message := 'Product with product_id ' || :NEW.product_id || ' has ' || stock_level || ' units in stock which is below the reorder level of ' || reordering_level || ' units.';

        -- Insert a row into the RESTOCK_ALERTS table
        INSERT INTO RESTOCK_ALERTS(restock_alert_id, product_id, restock_alert_message)
        VALUES(RESTOCK_ALERT_ID_SEQ.nextval, :NEW.product_id, alert_message);

        -- Print the alert message
        DBMS_OUTPUT.PUT_LINE(alert_message);
    END IF;

EXCEPTION 
    WHEN null_quantity_ex THEN   
        RAISE_APPLICATION_ERROR(-20001, 'The ORDER_ITEMS table has a NULL value on quantity and therefore the Product units_in_stock value for Product with product_id ' || :NEW.product_id || ' cannot be updated.');
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20002, SQLERRM);

END AI_ORDER_ITEMS_UPD_STK;



-- QUESTION 2

-- Create an object that stores the information needed to add an order_item to an existing order
CREATE OR REPLACE TYPE order_item_input_info_object AS OBJECT 
(
    product_id NUMBER(6, 0),    
    quantity NUMBER(9, 0)   
);

-- Create a table that stores object of the type defined above
CREATE OR REPLACE TYPE order_item_input_info_table AS TABLE OF order_item_input_info_object;

-- Create the ORDER_PKG package specification
CREATE OR REPLACE PACKAGE ORDER_PKG 
AS    
    -- Public procedure to insert a row into ORDERS and one or more rows into ORDER_ITEMS which have the order_id of the newly inserted ORDERS table row
    PROCEDURE PLACE_ORDER_SP
    (
        p_customer_id IN ORDERS.customer_id%TYPE,
        p_items IN order_item_input_info_table,
        p_new_order_id OUT ORDERS.order_id%TYPE 
    );

    -- Public procedure to insert a row into ORDER_ITEMS
    PROCEDURE ADD_ORDER_ITEM_SP
    (
        p_order_id IN ORDER_ITEMS.order_id%TYPE,
        p_product_id IN ORDER_ITEMS.product_id%TYPE,
        p_qty IN ORDER_ITEMS.quantity%TYPE 
    );

    -- Public function that returns the total of all open (status 'N'/New or 'P'/Processing) orders for the given customer
    FUNCTION GET_CUSTOMER_BALANCE
    (p_customer_id IN CUSTOMERS.customer_id%TYPE)
    RETURN NUMBER;

    -- Public function that returns the difference between a product's price and average cost
    FUNCTION GET_PRODUCT_MARGIN
    (
        p_product_id IN PRODUCTS.product_id%TYPE,
        p_avg_cost IN PRODUCTS.unit_price%TYPE 
    )
    RETURN NUMBER;

END ORDER_PKG;



-- Create the ORDER_PKG package body
CREATE OR REPLACE PACKAGE BODY ORDER_PKG 
AS    
    -- Public procedure to insert a row into ORDER_ITEMS
    PROCEDURE ADD_ORDER_ITEM_SP
    (
        p_order_id IN ORDER_ITEMS.order_id%TYPE,
        p_product_id IN ORDER_ITEMS.product_id%TYPE,
        p_qty IN ORDER_ITEMS.quantity%TYPE 
    ) 
    AS    
        number_of_products_in_the_order ORDER_ITEMS.line_no%TYPE;   

    BEGIN 
        -- Get the largest line_no for this order_id in the ORDER_ITEMS table
        SELECT NVL(MAX(line_no), 0) 
        INTO number_of_products_in_the_order
        FROM ORDER_ITEMS
        WHERE order_id = p_order_id;

        -- INSERT the ORDER_ITEMS row using the function arguments and the largest line_no + 1 for the line_no of the new order
        INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
        VALUES(p_order_id, number_of_products_in_the_order + 1, p_product_id, p_qty);

        -- NOTE: The units_in_stock field in the PRODUCTS table gets updated automatically by the AI_ORDER_ITEMS_UPD_STK trigger
        -- NOTE: The total_amount field in the ORDERS table gets updated automatically by the ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_INSERT_ON_ORDER_ITEMS_TRG trigger

    EXCEPTION
        WHEN OTHERS THEN    
            RAISE_APPLICATION_ERROR(-20001, SQLERRM);
    
    END ADD_ORDER_ITEM_SP;

    -- Public procedure to insert a row into ORDERS and one or more rows into ORDER_ITEMS which have the order_id of the newly inserted ORDERS table row
    PROCEDURE PLACE_ORDER_SP
    (
        p_customer_id IN ORDERS.customer_id%TYPE,
        p_items IN order_item_input_info_table,
        p_new_order_id OUT ORDERS.order_id%TYPE 
    )
    AS    
        id_order ORDER_ITEMS.ORDER_ID%TYPE;
        stock_level PRODUCTS.UNITS_IN_STOCK%TYPE;
        product_unit_price PRODUCTS.UNIT_PRICE%TYPE;

        CURSOR p_items_cursor IS     
            SELECT product_id, quantity 
            FROM TABLE(p_items);

    BEGIN 
        -- NOTE: The checking of the product stock level and the raising of an exception when the product is out of stock has been handled 
        -- in the BI_ORDER_ITEMS_STK trigger which is above

        -- Get the value of the p_new_order_id from the sequence of order_id
        SELECT order_id_seq.NEXTVAL
        INTO id_order
        FROM DUAL;

        p_new_order_id := id_order;

        -- INSERT the new ORERS table row
        INSERT INTO ORDERS(customer_id, order_date, order_status, total_amount)
        VALUES(p_customer_id, SYSDATE, 'N', 0);

        -- INSERT all the records necessary INTO the ORDER_ITEMS table using the cursor and the ADD_ORDER_ITEM_SP stored procedure that is also in this package
        FOR p_items_record IN p_items_cursor LOOP    
            ADD_ORDER_ITEM_SP(id_order, p_items_record.product_id, p_items_record.quantity);
        END LOOP;

    EXCEPTION 
        WHEN OTHERS THEN    
            RAISE_APPLICATION_ERROR(-20001, SQLERRM);
    
    END PLACE_ORDER_SP;

    -- Public function that returns the total $ amount of all open (status 'N'/New or 'P'/Processing) orders for the given customer
    FUNCTION GET_CUSTOMER_BALANCE
    (p_customer_id IN CUSTOMERS.customer_id%TYPE)
    RETURN NUMBER
    IS     
        customer_spending_amount_balance ORDERS.total_amount%TYPE; 
    
    BEGIN 
        -- Get the sum of total_amounts from the ORDERS table for rows that have the provided customer_id and that have one of the 2 required order statuses
        SELECT NVL(SUM(total_amount), 0)
        INTO customer_spending_amount_balance
        FROM ORDERS
        WHERE customer_id = p_customer_id AND order_status IN ('N', 'P');

        -- Return the query result
        RETURN customer_spending_amount_balance;

    EXCEPTION 
        WHEN OTHERS THEN    
            RAISE_APPLICATION_ERROR(-20001, SQLERRM);
    
    END GET_CUSTOMER_BALANCE;

    -- Public function that returns the difference between a product's price and average cost
    FUNCTION GET_PRODUCT_MARGIN
    (
        p_product_id IN PRODUCTS.product_id%TYPE,
        p_avg_cost IN PRODUCTS.unit_price%TYPE 
    )
    RETURN NUMBER
    IS     
        product_unit_price PRODUCTS.UNIT_PRICE%TYPE;
        
        null_unit_price_ex EXCEPTION;

    BEGIN
        -- Get the unit_price from the PRODUCTS table for the product with the specified product_id  
        SELECT unit_price 
        INTO product_unit_price
        FROM PRODUCTS  
        WHERE product_id = p_product_id;

        -- If the PRODUCTS table row has a NULL unit_price, raise the null_unit_price_ex exception
        IF product_unit_price IS NULL THEN    
            RAISE null_unit_price_ex;
        END IF;

        -- Return the difference between the unit_price and average cost of the product
        RETURN product_unit_price - p_avg_cost;

    EXCEPTION 
        WHEN null_unit_price_ex THEN    
            RAISE_APPLICATION_ERROR(-20001, 'The product with product_id ' || p_product_id || ' has a NULL unit_price.');
        WHEN NO_DATA_FOUND THEN    
            RAISE_APPLICATION_ERROR(-20002, 'No product with id ' || p_product_id || ' exists in the PRODUCTS table.');
        WHEN OTHERS THEN    
            RAISE_APPLICATION_ERROR(-20003, SQLERRM);
    
    END GET_PRODUCT_MARGIN;

END ORDER_PKG;



-- QUESTION 4

-- Design and run the query
SELECT product_id AS "PRODUCT ID", TRUNC(order_date, 'MM') AS "MONTH", 
SUM(quantity) AS "TOTAL QUANTITY", TO_CHAR(SUM(quantity * unit_price), '$999999.99') AS "TOTAL REVENUE"
FROM ORDERS JOIN ORDER_ITEMS USING(order_id)
GROUP BY product_id, TRUNC(order_date, 'MM');

-- Design a query to show the calculations and check the results of the last query
SELECT product_id AS "PRODUCT ID", TRUNC(order_date, 'MM') AS "MONTH", 
quantity, unit_price, TO_CHAR((quantity * unit_price), '$999999.99') AS "QUANTITY * PRICE"
FROM ORDERS JOIN ORDER_ITEMS USING(order_id)
ORDER BY product_id, TRUNC(order_date, 'MM');

-- Create the Materialized View Logs on the ORDERS and ORDER_ITEMS tables since these are the tables involved in the query

-- Create the Materialized View log on the ORDERS table
-- DROP MATERIALIZED VIEW LOG ON ORDERS;

CREATE MATERIALIZED VIEW LOG ON ORDERS 
WITH ROWID, SEQUENCE(order_id, order_date)
INCLUDING NEW VALUES;

-- Create the Materialized View log on the ORDER_ITEMS table
-- DROP MATERIALIZED VIEW LOG ON ORDER_ITEMS;

CREATE MATERIALIZED VIEW LOG ON ORDER_ITEMS 
WITH ROWID, SEQUENCE (order_id, product_id, quantity, unit_price)
INCLUDING NEW VALUES;

-- Create the Materialized View 
-- DROP MATERIALIZED VIEW MV_MONTHLY_SALES;

CREATE MATERIALIZED VIEW MV_MONTHLY_SALES
BUILD IMMEDIATE 
REFRESH FAST
ON COMMIT 
AS 
SELECT product_id AS "PRODUCT ID", TRUNC(order_date, 'MM') AS "MONTH", 
SUM(quantity) AS "TOTAL QUANTITY", SUM(quantity * unit_price) AS "TOTAL REVENUE ($)"
FROM ORDERS JOIN ORDER_ITEMS USING(order_id)
GROUP BY product_id, TRUNC(order_date, 'MM');

-- Get the results of the Materialized View
SELECT *
FROM MV_MONTHLY_SALES;

