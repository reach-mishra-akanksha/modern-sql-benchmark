-- 06 Classic: self-join each order to all of that customer's earlier orders
-- Business question: On which order did each customer's total spending
-- cross $1 million? (Count those orders.)
SELECT COUNT(*) AS orders_crossing_1m
FROM (
    SELECT o1.o_orderkey,
           o1.o_totalprice,
           SUM(o2.o_totalprice) AS spent_so_far
    FROM orders o1
    JOIN orders o2
      ON  o2.o_custkey = o1.o_custkey
      AND (o2.o_orderdate < o1.o_orderdate
           OR (o2.o_orderdate = o1.o_orderdate AND o2.o_orderkey <= o1.o_orderkey))
    GROUP BY o1.o_orderkey, o1.o_totalprice
) running
WHERE spent_so_far >= 1000000
  AND spent_so_far - o_totalprice < 1000000;
