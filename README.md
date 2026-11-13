# Is modern SQL slower?

A reproducible benchmark that tests a common belief: that modern SQL clauses
"look pretty but don't perform." Each modern clause is compared with the classic
way people usually write the same query, on the same data and engine.

## What's compared

| # | Modern clause | Classic equivalent | Business question (TPC-H) |
|---|---|---|---|
| 01 | `FILTER (WHERE …)` | `COUNT(CASE WHEN … END)` | Each year: items shipped, by air, and late |
| 02 | `ROLLUP` | `GROUP BY` + `UNION ALL` | Orders and value per priority, plus a grand total |
| 03 | `LATERAL … LIMIT n` | `ROW_NUMBER() <= n` | Top 3 customers by balance in each country |
| 04 | `IS DISTINCT FROM` | hand-written `NULL` checks | How often customers change order priority |
| 05 | `bool_and()` / `bool_or()` | `MIN`/`MAX(CASE … 1 ELSE 0)` | Orders fully on time; orders with any return |
| 06 | `QUALIFY` (bonus, DuckDB only) | subquery + `ROW_NUMBER()` | Each customer's most recent order |

Every query pair lives in `queries/NN_name/old.sql` and `new.sql`.

## Results

Ratio of median runtimes, **new ÷ old** (below 1 = modern is faster).
Ties are within ±10%.

| Clause | DuckDB SF1 | DuckDB SF10 | Postgres SF1 | Postgres SF10 |
|---|---|---|---|---|
| 01 `FILTER` | 0.97 | 1.01 | 0.97 | 0.97 |
| 02 `ROLLUP` | 1.42 | 1.65 | 1.04 | 1.09 |
| 03 `LATERAL` | 1.01 | 0.98 | 1.75 | 4.28 |
| 04 `IS DISTINCT FROM` | 0.93 | 0.93 | 1.01 | 0.99 |
| 05 `bool_and/or` | 0.90 | 0.90 | 0.98 | 0.96 |
| 06 `QUALIFY` | 1.01 | 1.00 | unsupported | unsupported |

Absolute times are not comparable across engines: DuckDB is a columnar
analytics engine and is much faster overall. Compare ratios within an engine.

Full data: `results/summary.csv` (medians), `results/raw_runs.csv` (every run),
`results/equivalence.csv` (proof old and new return identical results),
`results/plans/` (query plans), `results/env_*.json` (machine and versions).

## Method

- **Data:** TPC-H at scale factors 1 (~1 GB) and 10 (~10 GB), generated with
  [`tpchgen-cli`](https://github.com/clflushopt/tpchgen-rs). Postgres is loaded
  from the same DuckDB copy, so both engines query identical rows.
- **Engines:** DuckDB 1.5.6 and PostgreSQL 18.6, default configuration,
  **no indexes**.
- **Equivalence:** before timing, both versions run once and their results are
  compared (row count + order-independent hash). A pair is only timed if the
  results are identical. A clause an engine can't parse is logged as unsupported.
- **Timing:** 5 timed runs per version after the check run, alternating old and
  new and switching which goes first each round. The median is reported.
- **Small outputs:** queries end in a small result (an aggregate or a few rows),
  so timings measure the engine rather than transferring rows to Python.

## Reproduce it

```bash
pip install duckdb "psycopg[binary]" tpchgen-cli
python3 bench.py --engine duckdb   --sf 1
python3 bench.py --engine duckdb   --sf 10
createdb tpch_sf1 && createdb tpch_sf10
python3 bench.py --engine postgres --sf 1  --pg "dbname=tpch_sf1"
python3 bench.py --engine postgres --sf 10 --pg "dbname=tpch_sf10"
```

Results are appended to `results/`; delete that folder for a fresh run.
To add a clause, create `queries/NN_name/old.sql` and `new.sql`. If an engine
needs different spelling, add `new.<engine>.sql` (e.g. `new.postgres.sql`).

`spare_queries/` holds extra pairs that were tested but not benchmarked
(`DISTINCT ON`, a window running total, and a `RANGE BETWEEN INTERVAL` rolling
window).

## Article

Coming soon.
