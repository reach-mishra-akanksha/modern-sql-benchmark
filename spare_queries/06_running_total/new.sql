-- 06 Window running total
-- Business question: On which order did each customer's total spending
-- cross $1 million? (Count those orders.)
SELECT COUNT(*) AS orders_crossing_1m
FROM (
    SELECT o_totalprice,
           SUM(o_totalprice) OVER (PARTITION BY o_custkey
                                   ORDER BY o_orderdate, o_orderkey
                                   ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
               AS spent_so_far
    FROM orders
) running
WHERE spent_so_far >= 1000000
  AND spent_so_far - o_totalprice < 1000000;
