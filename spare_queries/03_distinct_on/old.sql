-- 03 Classic: number the rows, then keep row 1
-- Business question: What is each customer's most recent order?
-- (Wrapped in COUNT/SUM so the benchmark times the query, not the
--  transfer of ~100k rows to Python.)
SELECT COUNT(*) AS customers, SUM(o_totalprice) AS latest_order_value
FROM (
    SELECT o_custkey, o_orderkey, o_orderdate, o_totalprice,
           ROW_NUMBER() OVER (PARTITION BY o_custkey
                              ORDER BY o_orderdate DESC, o_orderkey DESC) AS rn
    FROM orders
) ranked
WHERE rn = 1;
