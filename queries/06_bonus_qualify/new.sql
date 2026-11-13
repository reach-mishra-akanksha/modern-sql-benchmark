-- 06 BONUS (DuckDB only): QUALIFY. Postgres will report it as unsupported.
-- Business question: What is each customer's most recent order?
-- Latest order per customer (modern: QUALIFY)
SELECT COUNT(*) AS customers, SUM(o_totalprice) AS total
FROM (
  SELECT * FROM orders
  QUALIFY ROW_NUMBER() OVER (PARTITION BY o_custkey
                             ORDER BY o_orderdate DESC, o_orderkey DESC) = 1
) t;
