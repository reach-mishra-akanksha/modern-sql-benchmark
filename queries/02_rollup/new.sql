-- 02 ROLLUP
-- Business question: How many orders do we have at each priority level,
-- what are they worth, and what is the grand total?
SELECT
    o_orderpriority    AS priority,
    COUNT(*)           AS orders,
    SUM(o_totalprice)  AS order_value
FROM orders
GROUP BY ROLLUP (o_orderpriority)
ORDER BY priority NULLS LAST;
