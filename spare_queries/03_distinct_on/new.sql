-- 03 DISTINCT ON
-- Business question: What is each customer's most recent order?
-- (Wrapped in COUNT/SUM so the benchmark times the query, not the
--  transfer of ~100k rows to Python.)
SELECT COUNT(*) AS customers, SUM(o_totalprice) AS latest_order_value
FROM (
    SELECT DISTINCT ON (o_custkey)
           o_custkey, o_orderkey, o_orderdate, o_totalprice
    FROM orders
    ORDER BY o_custkey, o_orderdate DESC, o_orderkey DESC
) latest;
