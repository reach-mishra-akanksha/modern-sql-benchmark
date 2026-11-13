-- 06 BONUS classic version: subquery + ROW_NUMBER
-- Business question: What is each customer's most recent order?
-- Latest order per customer (classic: subquery + ROW_NUMBER)
SELECT COUNT(*) AS customers, SUM(o_totalprice) AS total
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY o_custkey
                               ORDER BY o_orderdate DESC, o_orderkey DESC) AS rn
  FROM orders
) t
WHERE rn = 1;
