-- Lab Week13: Modern Data Warehouse และ AI Analytics
-- รันหลัง 00_setup.sql จากโฟลเดอร์ Week13 (ตาราง orders, customers, products, view fact_sales)

-- ===== Part A: SQL Review =====

-- A1 SELECT / LIMIT: 10 แถวแรก
SELECT order_id, order_date, quantity, channel
FROM orders
LIMIT 10;

-- A2 WHERE / ORDER BY: รายการ Completed ช่องทางออนไลน์ ล่าสุด 10 แถว
SELECT order_id, order_date, customer_id, product_id, quantity, channel, status
FROM orders
WHERE status = 'Completed' AND channel = 'ออนไลน์'
ORDER BY order_date DESC
LIMIT 10;

-- A3 GROUP BY / COUNT: จำนวนสินค้าแยกตาม category
SELECT p.category, COUNT(*) AS n_products
FROM products p
GROUP BY p.category
ORDER BY n_products DESC;

-- A4 INNER JOIN: ชื่อสินค้า จำนวนที่ซื้อ ราคาต่อหน่วย
SELECT p.product_name, o.quantity, o.unit_price
FROM orders o
INNER JOIN products p ON o.product_id = p.product_id
ORDER BY p.product_name;

-- A5 JOIN + SUM: ยอดขายสุทธิรวมตามจังหวัด (มากไปน้อย)
SELECT c.province, ROUND(SUM(f.net_sales), 2) AS total_net_sales
FROM fact_sales f
INNER JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.province
ORDER BY total_net_sales DESC;

-- A6 Aggregation: ยอดขายสุทธิรวมแต่ละ category
SELECT p.category, ROUND(SUM(f.net_sales), 2) AS total_net_sales
FROM fact_sales f
INNER JOIN products p ON f.product_id = p.product_id
GROUP BY p.category
ORDER BY total_net_sales DESC;

-- A7 TOP-N: ลูกค้า 5 รายที่ยอดซื้อสะสมสูงสุด
SELECT c.customer_id, c.customer_name, ROUND(SUM(f.net_sales), 2) AS total_spent
FROM fact_sales f
INNER JOIN customers c ON f.customer_id = c.customer_id
GROUP BY c.customer_id, c.customer_name
ORDER BY total_spent DESC
LIMIT 5;

-- A8 HAVING: สินค้าที่ทำรายได้มากกว่า 2,000 บาท
SELECT p.product_name, ROUND(SUM(f.net_sales), 2) AS total_net_sales
FROM fact_sales f
INNER JOIN products p ON f.product_id = p.product_id
GROUP BY p.product_name
HAVING SUM(f.net_sales) > 2000
ORDER BY total_net_sales DESC;

-- ===== Part B: Modern Data Warehouse =====

-- B1 Star Schema: Fact = fact_sales; Dimensions = customers, products, dim_date, dim_channel
-- ตรวจ key ที่ใช้เชื่อม: fact.customer_id -> customers.customer_id,
-- fact.product_id -> products.product_id, fact.order_date -> dim_date.date_day,
-- fact.channel -> dim_channel.channel
CREATE OR REPLACE VIEW dim_date AS
SELECT DISTINCT order_date AS date_day,
       YEAR(order_date) AS year_num,
       MONTH(order_date) AS month_num,
       DAYNAME(order_date) AS day_name
FROM fact_sales;

CREATE OR REPLACE VIEW dim_channel AS
SELECT DISTINCT channel FROM fact_sales;

-- B2 Data Mart: รายได้รายเดือน แยก category และ channel
CREATE OR REPLACE VIEW mart_monthly_sales AS
SELECT DATE_TRUNC('month', f.order_date) AS sales_month,
       p.category,
       f.channel,
       ROUND(SUM(f.net_sales), 2) AS total_net_sales,
       COUNT(*) AS n_items
FROM fact_sales f
INNER JOIN products p ON f.product_id = p.product_id
GROUP BY 1, 2, 3;

SELECT * FROM mart_monthly_sales ORDER BY sales_month, category, channel;

-- B3 Data Quality: 3 ประเด็น
-- (ก) customer_id หาย หรือไม่พบในตาราง customers
SELECT o.order_id, o.customer_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
WHERE o.customer_id IS NULL OR TRIM(o.customer_id) = '' OR c.customer_id IS NULL;

-- (ข) quantity ไม่สมเหตุสมผล (<= 0 หรือ ผิดปกติสูง)
SELECT order_id, quantity, unit_price
FROM orders
WHERE quantity IS NULL OR quantity <= 0 OR quantity > 20;

-- (ค) product_id ไม่พบในตาราง products
SELECT o.order_id, o.product_id
FROM orders o
LEFT JOIN products p ON o.product_id = p.product_id
WHERE p.product_id IS NULL;

-- ===== Part C: AI Analytics =====

-- C1 Time Series: ยอดขายรายวัน + Moving Average 7 แถวล่าสุด
-- หมายเหตุ: ROWS 6 PRECEDING ใช้ "7 แถวข้อมูล" ไม่ใช่ "7 วันปฏิทิน"
-- ถ้าบางวันไม่มีขาย วันนั้นจะไม่มีแถว ทำให้ 7 แถวครอบคลุมมากกว่า 7 วัน
WITH daily AS (
    SELECT order_date, ROUND(SUM(net_sales), 2) AS daily_sales
    FROM fact_sales
    GROUP BY order_date
)
SELECT order_date,
       daily_sales,
       ROUND(AVG(daily_sales) OVER (
           ORDER BY order_date
           ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7_rows
FROM daily
ORDER BY order_date DESC
LIMIT 10;

-- C2 Customer Features: last_order, frequency, monetary (จาก fact_sales)
-- recency_days คำนวณเทียบวันที่ล่าสุดในข้อมูล
SELECT c.customer_id,
       MAX(f.order_date) AS last_order,
       DATE_DIFF('day', MAX(f.order_date), (SELECT MAX(order_date) FROM fact_sales)) AS recency_days,
       COUNT(DISTINCT f.order_id) AS frequency,
       ROUND(SUM(f.net_sales), 2) AS monetary
FROM customers c
LEFT JOIN fact_sales f ON c.customer_id = f.customer_id
GROUP BY c.customer_id
ORDER BY monetary DESC NULLS LAST;
