-- 01 FILTER (WHERE ...)
-- Business question: Each year, how many items did we ship,
-- how many went by air, and how many arrived late?
SELECT
    EXTRACT(YEAR FROM l_shipdate)                         AS ship_year,
    COUNT(*)                                              AS total_items,
    COUNT(*) FILTER (WHERE l_shipmode = 'AIR')            AS air_items,
    COUNT(*) FILTER (WHERE l_receiptdate > l_commitdate)  AS late_items
FROM lineitem
GROUP BY EXTRACT(YEAR FROM l_shipdate)
ORDER BY ship_year;
