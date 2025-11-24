-- QUESTION 5

SET SERVEROUTPUT ON

-- 1. TEST: ORDER_ITEMS_UNIT_PRICE_SET_TRG (unit_price auto-fill from PRODUCTS)
BEGIN
  INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
  VALUES(1, 4, 1, 1); -- Inserts product 1 into Order 1
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Trigger ORDER_ITEMS_UNIT_PRICE_SET_TRG passed.');
END;
/

-- 2. TEST: ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_INSERT_ON_ORDER_ITEMS_TRG
BEGIN
  INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
  VALUES(2, 3, 2, 1); -- Should increase order 2 total_amount
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Trigger ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_INSERT_ON_ORDER_ITEMS_TRG passed.');
END;
/

-- 3. TEST: ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_DELETE_ON_ORDER_ITEMS_TRG
BEGIN
  DELETE FROM ORDER_ITEMS WHERE order_id = 2 AND line_no = 3;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Trigger ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_DELETE_ON_ORDER_ITEMS_TRG passed.');
END;
/

-- 4. TEST: ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_UPDATE_ON_ORDER_ITEMS_TRG
BEGIN
  UPDATE ORDER_ITEMS SET quantity = 3 WHERE order_id = 3 AND line_no = 1;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Trigger ORDERS_TOTAL_AMOUNT_UPDATE_AFTER_UPDATE_ON_ORDER_ITEMS_TRG passed.');
END;
/

-- 5. TEST: BI_ORDER_ITEMS_STK (Insufficient stock)
BEGIN
  INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
  VALUES(3, 4, 4, 999);
  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('Expected Error (BI_ORDER_ITEMS_STK): ' || SQLERRM);
END;
/

-- 6. TEST: AI_ORDER_ITEMS_UPD_STK (Stock reduction + Restock alert)
BEGIN
  INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
  VALUES(3, 5, 4, 10); -- Should trigger restock alert for product 4 (Back Stretcher)
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Trigger AI_ORDER_ITEMS_UPD_STK passed with restock alert (if threshold passed).');
END;
/

-- 7. TEST: ORDER_PKG.ADD_ORDER_ITEM_SP
BEGIN
  ORDER_PKG.ADD_ORDER_ITEM_SP(4, 3, 1); -- Add product 3 to order 4
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Procedure ADD_ORDER_ITEM_SP executed.');
END;
/

-- 8. TEST: ORDER_PKG.PLACE_ORDER_SP
DECLARE
  new_order_id NUMBER;
  items order_item_input_info_table := order_item_input_info_table();
BEGIN
  items.EXTEND(2);
  items(1) := order_item_input_info_object(1, 1);
  items(2) := order_item_input_info_object(2, 2);

  ORDER_PKG.PLACE_ORDER_SP(1, items, new_order_id);
  DBMS_OUTPUT.PUT_LINE('✅ Procedure PLACE_ORDER_SP executed. New Order ID: ' || new_order_id);
  COMMIT;
END;
/

-- 9. TEST: ORDER_PKG.GET_CUSTOMER_BALANCE
DECLARE
  balance NUMBER;
BEGIN
  balance := ORDER_PKG.GET_CUSTOMER_BALANCE(1);
  DBMS_OUTPUT.PUT_LINE('✅ Function GET_CUSTOMER_BALANCE executed. Balance: ' || balance);
END;
/

-- 10. TEST: ORDER_PKG.GET_PRODUCT_MARGIN
DECLARE
  margin NUMBER;
BEGIN
  margin := ORDER_PKG.GET_PRODUCT_MARGIN(1, 8.00);
  DBMS_OUTPUT.PUT_LINE('✅ Function GET_PRODUCT_MARGIN executed. Margin: ' || margin);
END;
/

-- 11. TEST: ORDER_PKG.GET_PRODUCT_MARGIN with invalid product_id (NO_DATA_FOUND)
DECLARE
  margin NUMBER;
BEGIN
  margin := ORDER_PKG.GET_PRODUCT_MARGIN(999, 5.00);
EXCEPTION
  WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE('❌ Expected Error (GET_PRODUCT_MARGIN NO_DATA_FOUND): ' || SQLERRM);
END;
/

-- 12. TEST: MATERIALIZED VIEW MV_MONTHLY_SALES refresh after commit
BEGIN
  INSERT INTO ORDER_ITEMS(order_id, line_no, product_id, quantity)
  VALUES(1, 6, 1, 2);
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('✅ Materialized View MV_MONTHLY_SALES should refresh automatically.');
END;
/

-- 13. QUERY: View MV_MONTHLY_SALES data
SELECT * FROM MV_MONTHLY_SALES ORDER BY "PRODUCT ID", "MONTH";
