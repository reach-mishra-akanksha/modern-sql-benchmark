-- 05 Classic: turn conditions into 1/0, then MIN (= all) or MAX (= any)
-- Business question: How many orders arrived completely on time,
-- and how many had at least one item returned?
SELECT
    SUM(CASE WHEN all_on_time  THEN 1 ELSE 0 END) AS fully_on_time_orders,
    SUM(CASE WHEN any_returned THEN 1 ELSE 0 END) AS orders_with_a_return
FROM (
    SELECT l_orderkey,
           MIN(CASE WHEN l_receiptdate <= l_commitdate THEN 1 ELSE 0 END) = 1 AS all_on_time,
           MAX(CASE WHEN l_returnflag = 'R'            THEN 1 ELSE 0 END) = 1 AS any_returned
    FROM lineitem
    GROUP BY l_orderkey
) per_order;
