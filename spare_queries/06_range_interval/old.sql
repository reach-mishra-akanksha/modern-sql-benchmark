-- 06 Classic: self-join each order to the same customer's orders in the window
-- Business question: How many orders came from a customer who had spent
-- more than $500,000 in the 90 days up to and including that order?
SELECT COUNT(*) AS big_spender_orders
FROM (
    SELECT o1.o_orderkey, SUM(o2.o_totalprice) AS spent_last_90d
    FROM orders o1
    JOIN orders o2
      ON  o2.o_custkey = o1.o_custkey
      AND o2.o_orderdate BETWEEN o1.o_orderdate - INTERVAL '89 days' AND o1.o_orderdate
    GROUP BY o1.o_orderkey
) rolling
WHERE spent_last_90d > 500000;
