-- 04 IS DISTINCT FROM
-- Business question: How often do customers change the priority of their
-- orders? Count every order whose priority differs from the same customer's
-- previous order (a customer's first order counts as a change).
SELECT COUNT(*) AS priority_changes
FROM (
    SELECT o_orderpriority,
           LAG(o_orderpriority) OVER (PARTITION BY o_custkey
                                      ORDER BY o_orderdate, o_orderkey) AS prev_priority
    FROM orders
) o
WHERE o_orderpriority IS DISTINCT FROM prev_priority;
