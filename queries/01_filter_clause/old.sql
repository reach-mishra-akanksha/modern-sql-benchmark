-- 01 Classic: CASE inside the aggregate
-- Business question: Each year, how many items did we ship,
-- how many went by air, and how many arrived late?
SELECT
    EXTRACT(YEAR FROM l_shipdate)                              AS ship_year,
    COUNT(*)                                                   AS total_items,
    COUNT(CASE WHEN l_shipmode = 'AIR' THEN 1 END)             AS air_items,
    COUNT(CASE WHEN l_receiptdate > l_commitdate THEN 1 END)   AS late_items
FROM lineitem
GROUP BY EXTRACT(YEAR FROM l_shipdate)
ORDER BY ship_year;
