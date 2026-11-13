-- 04 Classic: spell out the NULL cases by hand
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
WHERE o_orderpriority <> prev_priority
   OR (o_orderpriority IS NULL AND prev_priority IS NOT NULL)
   OR (o_orderpriority IS NOT NULL AND prev_priority IS NULL);
