-- 05 bool_and() / bool_or()
-- Business question: How many orders arrived completely on time,
-- and how many had at least one item returned?
SELECT
    SUM(CASE WHEN all_on_time  THEN 1 ELSE 0 END) AS fully_on_time_orders,
    SUM(CASE WHEN any_returned THEN 1 ELSE 0 END) AS orders_with_a_return
FROM (
    SELECT l_orderkey,
           bool_and(l_receiptdate <= l_commitdate) AS all_on_time,
           bool_or(l_returnflag = 'R')             AS any_returned
    FROM lineitem
    GROUP BY l_orderkey
) per_order;
