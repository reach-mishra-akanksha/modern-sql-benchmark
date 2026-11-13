-- 03 LATERAL ... LIMIT n
-- Business question: Who are the 3 customers with the highest
-- account balance in each country?
SELECT n.n_name AS country, top3.c_name AS customer, top3.c_acctbal AS balance
FROM nation n
CROSS JOIN LATERAL (
    SELECT c.c_custkey, c.c_name, c.c_acctbal
    FROM customer c
    WHERE c.c_nationkey = n.n_nationkey
    ORDER BY c.c_acctbal DESC, c.c_custkey
    LIMIT 3
) top3
ORDER BY country, balance DESC;
