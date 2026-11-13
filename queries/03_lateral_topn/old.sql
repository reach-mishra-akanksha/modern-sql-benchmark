-- 03 Classic: rank every row, then keep ranks 1-3
-- Business question: Who are the 3 customers with the highest
-- account balance in each country?
SELECT country, customer, balance
FROM (
    SELECT n.n_name AS country, c.c_name AS customer, c.c_acctbal AS balance,
           ROW_NUMBER() OVER (PARTITION BY c.c_nationkey
                              ORDER BY c.c_acctbal DESC, c.c_custkey) AS rn
    FROM customer c
    JOIN nation n ON n.n_nationkey = c.c_nationkey
) ranked
WHERE rn <= 3
ORDER BY country, balance DESC;
