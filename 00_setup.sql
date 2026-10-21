-- แก้ path ให้ตรงตำแหน่งที่เก็บ CSV ในเครื่อง (DuckDB Desktop/CLI)
CREATE OR REPLACE TABLE products AS SELECT * FROM read_csv_auto('products.csv');
CREATE OR REPLACE TABLE customers AS SELECT * FROM read_csv_auto('customers.csv');
CREATE OR REPLACE TABLE orders AS SELECT * FROM read_csv_auto('orders.csv');
-- สถานะ Completed เท่านั้นคือรายได้จริง
CREATE OR REPLACE VIEW fact_sales AS
SELECT o.order_id, CAST(o.order_date AS DATE) AS order_date,
       o.customer_id, o.product_id, o.quantity, o.unit_price, o.discount_pct,
       o.channel,
       ROUND(o.quantity * o.unit_price * (1 - o.discount_pct/100.0),2) AS net_sales
FROM orders o WHERE o.status='Completed';
SELECT COUNT(*) AS n_orders FROM orders;
SELECT COUNT(*) AS n_completed FROM fact_sales;
