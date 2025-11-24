-- Drop TABLE statements:
/*
DROP TABLE ORDER_ITEMS;
DROP TABLE ORDERS;
DROP TABLE PRODUCTS;
DROP TABLE CUSTOMERS;
*/



-- Create the Customers table
CREATE TABLE CUSTOMERS
(
    customer_id NUMBER(6, 0) CONSTRAINT customers_customer_id_pk PRIMARY KEY,
    first_name VARCHAR2(40) CONSTRAINT customers_first_name_nn NOT NULL,
    last_name VARCHAR2(40) CONSTRAINT customers_last_name_nn NOT NULL,
    email VARCHAR2(80),
    phone VARCHAR2(15),
    credit_limit NUMBER(9, 2) CONSTRAINT customers_credit_limit_ck CHECK (credit_limit >= 0), 
    
    -- Make sure that the email contains an '@' and '.' character
    CONSTRAINT customers_email_at_sign_ck CHECK (INSTR(email, '@') > 0),
    CONSTRAINT customers_email_dot_sign_ck CHECK (INSTR(email, '.') > 0)
);

-- DROP SEQUENCE customer_id_seq;

-- Create the customer_id sequence
CREATE SEQUENCE customer_id_seq
START WITH 1
INCREMENT BY 1
NOCACHE 
NOCYCLE;


-- Create a trigger that autoincrements the customer_id using the sequence above each time before a row is inserted into the Customers table
CREATE OR REPLACE TRIGGER CUSTOMER_ID_AUTO_INCREMENT_TRG
BEFORE INSERT ON CUSTOMERS 
FOR EACH ROW   

BEGIN 
    SELECT customer_id_seq.NEXTVAL 
    INTO :NEW.customer_id
    FROM DUAL;
    
EXCEPTION 
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20001, 'Error while inserting the customer_id in the CUSTOMERS table: ' || SQLERRM);

END CUSTOMER_ID_AUTO_INCREMENT_TRG;
/




-- Create the Products table
CREATE TABLE PRODUCTS 
(
    product_id NUMBER(6, 0) CONSTRAINT products_product_id_pk PRIMARY KEY,
    product_name VARCHAR2(60) CONSTRAINT products_product_name_nn NOT NULL,
    unit_price NUMBER(9, 2) CONSTRAINT products_unit_price_ck CHECK(unit_price > 0),
    units_in_stock NUMBER(9, 0) CONSTRAINT products_units_in_stock_ck CHECK(units_in_stock >= 0),
    reorder_level NUMBER(9, 0) DEFAULT 0
);

-- DROP SEQUENCE product_id_seq;

-- Create the product_id sequence
CREATE SEQUENCE product_id_seq 
START WITH 1 
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- Create a trigger that autoincrements the product_id using the sequence above each time before a row is inserted into the Products table 
-- with no value provided for the product_id
CREATE OR REPLACE TRIGGER PRODUCT_ID_AUTO_INCREMENT_TRG
BEFORE INSERT ON PRODUCTS 
FOR EACH ROW   

BEGIN 
    SELECT product_id_seq.NEXTVAL 
    INTO :NEW.product_id
    FROM DUAL;

EXCEPTION 
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20001, 'Error while inserting the product_id in the PRODUCTS table: ' || SQLERRM);

END PRODUCT_ID_AUTO_INCREMENT_TRG;
/




-- Create the Orders table
CREATE TABLE ORDERS 
(
    order_id NUMBER(8, 0) CONSTRAINT orders_order_id_pk PRIMARY KEY,
    customer_id NUMBER(6, 0) CONSTRAINT orders_customers_fk REFERENCES CUSTOMERS(customer_id) ON DELETE SET NULL,
    order_date DATE DEFAULT SYSDATE,    
    order_status CHAR(1) CONSTRAINT orders_order_status_ck CHECK(order_status IN ('N', 'P', 'S', 'C')), -- New, Processing, Shipped, Cancelled
    total_amount NUMBER(12, 2) CONSTRAINT orders_total_amount_ck CHECK(total_amount >= 0)
);

-- DROP SEQUENCE order_id_seq;

-- Create the order_id sequence
CREATE SEQUENCE order_id_seq 
START WITH 1 
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- Create a trigger that autoincrements the order_id using the sequence above each time before a row is inserted into the Orders table with no value provided for the order_id
CREATE OR REPLACE TRIGGER ORDER_ID_AUTO_INCREMENT_TRG
BEFORE INSERT ON ORDERS 
FOR EACH ROW   

BEGIN 
    SELECT order_id_seq.NEXTVAL 
    INTO :NEW.order_id
    FROM DUAL;

EXCEPTION 
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20001, 'Error while inserting the order_id in the ORDERS table: ' || SQLERRM);

END ORDER_ID_AUTO_INCREMENT_TRG;
/




-- Create the Order_items table
CREATE TABLE ORDER_ITEMS
(
    order_id NUMBER(8, 0) CONSTRAINT order_items_orders_fk REFERENCES ORDERS(order_id) ON DELETE CASCADE,
    line_no NUMBER(2, 0),
    product_id NUMBER(6, 0) CONSTRAINT order_items_products_fk REFERENCES PRODUCTS(product_id) ON DELETE SET NULL,
    quantity NUMBER(9, 0) CONSTRAINT order_items_quantity_ck CHECK(quantity > 0),
    unit_price NUMBER(9, 2),

    CONSTRAINT order_items_order_id_line_no_pk PRIMARY KEY(order_id, line_no) 
);

-- Create a trigger that sets the value of unit_price on the Order_items table equal to the unit_price in the Products table
-- value on an INSERT or UPDATE operation on the Order_items table
-- Do this before every insert or update and get the value of unit_price on the Products table by using the product_id foreign key value on the Order_items table
CREATE OR REPLACE TRIGGER ORDER_ITEMS_UNIT_PRICE_SET_TRG
BEFORE INSERT OR UPDATE ON ORDER_ITEMS 
FOR EACH ROW

DECLARE 
    null_unit_price_ex EXCEPTION;
    price_per_unit PRODUCTS.unit_price%TYPE;

BEGIN 

    -- Get the unit_price value from the Products table and store it on the local variable price_per_unit
    SELECT unit_price 
    INTO price_per_unit
    FROM PRODUCTS 
    WHERE product_id = :NEW.product_id;

    -- If the unit_price is NULL, raise the null_unit_price exception
    IF price_per_unit IS NULL THEN    
        RAISE null_unit_price_ex;
    END IF;

    -- Get the unit_price value from the price_per_unit variable and put it on the Order_items table row into the unit_price column
    :NEW.unit_price := price_per_unit;
    

EXCEPTION 
    WHEN null_unit_price_ex THEN    
        RAISE_APPLICATION_ERROR(-20001, 'The unit_price value in the PRODUCTS table for Product with product_id ' || :NEW.product_id || ' is NULL.');
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20002, SQLERRM);

END ORDER_ITEMS_UNIT_PRICE_SET_TRG;
/

-- Create a trigger that increments the total_amount value in the Orders table after each time
-- a row is inserted into the Order_items table
CREATE OR REPLACE TRIGGER ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_INSERT_ON_ORDER_ITEMS_TRG
AFTER INSERT ON ORDER_ITEMS 
FOR EACH ROW 

DECLARE 
    order_items_amount ORDERS.total_amount%TYPE;
    null_quantity_ex EXCEPTION;
    null_unit_price_ex EXCEPTION;

BEGIN
    -- Check for null values of quantity and unit_price and raise exceptions if either of them is null 
    IF :NEW.quantity IS NULL THEN   
        RAISE null_quantity_ex;
    ELSIF :NEW.unit_price IS NULL THEN    
        RAISE null_unit_price_ex;
    END IF;

    -- Calculate the amount paid in the order item as quantity * price
    order_items_amount := :NEW.quantity * :NEW.unit_price;

    -- Add the amount paid in the order item to the total_amount on the Orders table
    UPDATE ORDERS 
    SET total_amount = total_amount + order_items_amount
    WHERE order_id = :NEW.order_id;

EXCEPTION 
    WHEN null_quantity_ex THEN    
        RAISE_APPLICATION_ERROR(-20001, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the quantity on the order item is NULL.');
    WHEN null_unit_price_ex THEN    
        RAISE_APPLICATION_ERROR(-20002, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the unit_price on the order item is NULL.');
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20003, SQLERRM);

END ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_INSERT_ON_ORDER_ITEMS_TRG;
/

-- Create a trigger that decrements the total_amount value in the Orders table after each time
-- a row is deleted from the Order_items table
CREATE OR REPLACE TRIGGER ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_DELETE_ON_ORDER_ITEMS_TRG
AFTER DELETE ON ORDER_ITEMS 
FOR EACH ROW 

DECLARE 
    order_items_amount ORDERS.total_amount%TYPE;
    null_quantity_ex EXCEPTION;
    null_unit_price_ex EXCEPTION;

BEGIN 
    -- Check for null values of quantity and unit_price and raise exceptions if either of them is null 
    IF :OLD.quantity IS NULL THEN   
        RAISE null_quantity_ex;
    ELSIF :OLD.unit_price IS NULL THEN    
        RAISE null_unit_price_ex;
    END IF;

    -- Calculate the amount paid in the order item as quantity * price
    order_items_amount := :OLD.quantity * :OLD.unit_price;

    -- Deduct the amount paid in the deleted order item from the total_amount on the Orders table
    UPDATE ORDERS 
    SET total_amount = total_amount - order_items_amount
    WHERE order_id = :OLD.order_id;

EXCEPTION 
    WHEN null_quantity_ex THEN    
        RAISE_APPLICATION_ERROR(-20001, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the quantity on the order item is NULL.');
    WHEN null_unit_price_ex THEN    
        RAISE_APPLICATION_ERROR(-20002, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the unit_price on the order item is NULL.');
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20003, SQLERRM);

END ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_DELETE_ON_ORDER_ITEMS_TRG;
/

-- Create a trigger that updates the total_amount value in the Orders table after each time
-- a row is updated in the Order_items table
CREATE OR REPLACE TRIGGER ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_UPDATE_ON_ORDER_ITEMS_TRG
AFTER UPDATE ON ORDER_ITEMS
FOR EACH ROW

DECLARE 
    new_order_items_amount ORDERS.total_amount%TYPE;
    old_order_items_amount ORDERS.total_amount%TYPE;

    null_old_quantity_ex EXCEPTION;
    null_old_unit_price_ex EXCEPTION;

    null_new_quantity_ex EXCEPTION;
    null_new_unit_price_ex EXCEPTION;

BEGIN
    IF NEW.quantity != OLD.quantity OR NEW.unit_price != OLD.unit_price OR NEW.order_id != OLD.order_id THEN    

        -- Check for null old values of quantity and unit_price and raise exceptions if either of them is null 
        IF :OLD.quantity IS NULL THEN   
            RAISE null_old_quantity_ex;
        ELSIF :OLD.unit_price IS NULL THEN    
            RAISE null_old_unit_price_ex;
        END IF;

        -- Calculate the old value of amount paid in the order item as old quantity * old price 
        old_order_items_amount := :OLD.quantity * :OLD.unit_price;

        -- Deduct the old amount paid from the total_amount on the Orders table
        UPDATE ORDERS 
        SET total_amount = total_amount - old_order_items_amount
        WHERE order_id = :OLD.order_id;

        -- Check for null new values of quantity and unit_price and raise exceptions if either of them is null 
        IF :NEW.quantity IS NULL THEN   
            RAISE null_new_quantity_ex;
        ELSIF :NEW.unit_price IS NULL THEN    
            RAISE null_new_unit_price_ex;
        END IF;

        -- Calculate the new value of amount paid in the order item as new quantity * new price
        new_order_items_amount := :NEW.quantity * :NEW.unit_price;

        -- Add the new amount paid in the order item to the total_amount on the Orders table
        UPDATE ORDERS 
        SET total_amount = total_amount + new_order_items_amount
        WHERE order_id = :NEW.order_id;

    END IF;

EXCEPTION
    WHEN null_old_quantity_ex THEN    
        RAISE_APPLICATION_ERROR(-20001, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the old quantity on the order item is NULL.');
    WHEN null_old_unit_price_ex THEN    
        RAISE_APPLICATION_ERROR(-20002, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the old unit_price on the order item is NULL.');
    WHEN null_new_quantity_ex THEN    
        RAISE_APPLICATION_ERROR(-20003, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the new quantity on the order item is NULL.');
    WHEN null_new_unit_price_ex THEN    
        RAISE_APPLICATION_ERROR(-20004, 'The order total amount cannot be updated on the ORDERS table for order with order_id ' || :NEW.order_id || ' because the new unit_price on the order item is NULL.');    
    WHEN OTHERS THEN    
        RAISE_APPLICATION_ERROR(-20005, SQLERRM);

END ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_UPDATE_ON_ORDER_ITEMS_TRG;
/



-- Insert 6 records into the CUSTOMERS table

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('Jannick', 'Jones', 'jannickjones@gmail.com', '0687997864', 100);

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('John', 'Stones', 'johnstones@gmail.com', '0675896865', 100);

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('Anne', 'Frank', 'annefrank@gmail.com', '0664448722', 100);

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('Stella', 'Smith', 'stellasmith@gmail.com', '0663339913', 100);

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('Nick', 'Jannsen', 'nickjannsen@gmail.com', '0694575821', 100);

INSERT INTO CUSTOMERS(first_name, last_name, email, phone, credit_limit) 
VALUES('Joanne', 'Calderwood', 'joannecalderwood@gmail.com', '0674966839', 100);

COMMIT;



-- Insert 6 records into the PRODUCTS table

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Cervical Neck Pillow', 9.99, 15, 5);

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Electrical Foot Massager', 19.99, 10, 4);

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Electrical Neck And Back Massager', 24.99, 12, 6);

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Back Stretcher', 9.99, 15, 7);

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Ergonomical Chair', 199.99, 8, 3);

INSERT INTO PRODUCTS(product_name, unit_price, units_in_stock, reorder_level)
VALUES('Electrical Eyes Massager', 19.99, 11, 5);

COMMIT;



-- Insert 6 records into the ORDERS table

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(1, 'N', 0);

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(2, 'N', 0);

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(3, 'P', 0);

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(4, 'S', 0);

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(5, 'N', 0);

INSERT INTO ORDERS(customer_id, order_status, total_amount)
VALUES(6, 'P', 0);

COMMIT;



-- Insert 11 records into the ORDER_ITEMS table

-- Order 1
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(1, 1, 1, 1);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(1, 2, 2, 1);

-- Order 2
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(2, 1, 3, 1);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(2, 2, 4, 2);

-- Order 3
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(3, 1, 1, 2);

-- Order 4
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(4, 1, 2, 1);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(4, 2, 3, 1);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(4, 3, 4, 3);

-- Order 5
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(5, 1, 5, 1);

INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(5, 2, 6, 1);

-- Order 6
INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
VALUES(6, 1, 6, 2);

COMMIT;


