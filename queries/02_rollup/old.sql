-- 02 Classic: one GROUP BY per level, stitched together with UNION ALL
-- Business question: How many orders do we have at each priority level,
-- what are they worth, and what is the grand total?
SELECT * FROM (
    -- one row per priority
    SELECT o_orderpriority AS priority, COUNT(*) AS orders, SUM(o_totalprice) AS order_value
    FROM orders
    GROUP BY o_orderpriority
    UNION ALL
    -- grand total
    SELECT NULL, COUNT(*), SUM(o_totalprice)
    FROM orders
) t
ORDER BY priority NULLS LAST;
