# Modern vs. classic SQL benchmark

    pip install duckdb "psycopg[binary]" tpchgen-cli
    python3 bench.py --engine duckdb   --sf 1
    python3 bench.py --engine duckdb   --sf 10
    python3 bench.py --engine postgres --sf 1  --pg "dbname=tpch_sf1 user=postgres"
    python3 bench.py --engine postgres --sf 10 --pg "dbname=tpch_sf10 user=postgres"

Postgres is loaded from the DuckDB-generated data, so both engines query identical rows.
Add a clause by creating `queries/NN_name/old.sql` and `new.sql`.
If an engine needs a different spelling, add `new.<engine>.sql`.
A query an engine can't parse is recorded as unsupported, not as a crash.


Data is generated with tpchgen-cli (falls back to DuckDB's tpch extension if it isn't installed). Postgres is loaded via CSV COPY from the DuckDB
copy, so no DuckDB extensions are needed for Postgres.
