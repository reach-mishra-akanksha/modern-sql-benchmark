-- 06 RANGE BETWEEN INTERVAL (time-based rolling window)
-- Business question: How many orders came from a customer who had spent
-- more than $500,000 in the 90 days up to and including that order?
SELECT COUNT(*) AS big_spender_orders
FROM (
    SELECT SUM(o_totalprice) OVER (PARTITION BY o_custkey
                                   ORDER BY o_orderdate
                                   RANGE BETWEEN INTERVAL '89 days' PRECEDING AND CURRENT ROW)
               AS spent_last_90d
    FROM orders
) rolling
WHERE spent_last_90d > 500000;
