"""
Modern vs. classic SQL benchmark harness.

Layout:
  queries/<NN_name>/old.sql            classic version (all engines)
  queries/<NN_name>/new.sql            modern version (all engines)
  queries/<NN_name>/new.postgres.sql   optional engine-specific override
                                       (same pattern works for old.<engine>.sql)

Every query should end in a small result (an aggregate or LIMIT-free
summary), so you time the engine, not Python fetching millions of rows.

Usage:
  python3 bench.py --engine duckdb   --sf 1
  python3 bench.py --engine postgres --sf 1 --pg "dbname=tpch_sf1 user=postgres"
  python3 bench.py --engine duckdb   --sf 10 --runs 5 --only 01_qualify_dedup

Outputs (in results/):
  raw_runs.csv     every timed run (the warm-up doubles as the equivalence check)
  summary.csv      median / min / max per query, variant, engine, SF
  equivalence.csv  proof that old and new return identical results
  plans/           EXPLAIN ANALYZE output for every query
  env_<engine>_sf<N>.json  hardware, OS, engine version, timestamp
"""
import argparse, csv, hashlib, json, os, platform, statistics, subprocess, time
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).parent
QDIR, OUT = ROOT / "queries", ROOT / "results"
TABLES = ["region", "nation", "supplier", "customer", "part",
          "partsupp", "orders", "lineitem"]


# ---------- engines ----------
class DuckDB:
    name = "duckdb"

    def __init__(self, sf, **_):
        import duckdb
        path = ROOT / "data" / f"tpch_sf{sf}.duckdb"
        path.parent.mkdir(exist_ok=True)
        fresh = not path.exists()
        self.con = duckdb.connect(str(path))
        if fresh:
            print(f"Generating TPC-H SF{sf} in DuckDB (one-time)...")
            try:
                self._generate(sf)
            except Exception:
                self.con.close()
                path.unlink(missing_ok=True)  # don't leave a half-built DB behind
                raise
        self.version = duckdb.__version__

    def _generate(self, sf):
        import shutil, sys, tempfile
        exe = shutil.which("tpchgen-cli") or shutil.which(
            "tpchgen-cli", path=str(Path(sys.executable).parent))
        if not exe:
            # Only if tpchgen-cli isn't installed: DuckDB's tpch extension
            # (needs to download from extensions.duckdb.org)
            print("   tpchgen-cli not found; trying DuckDB tpch extension "
                  "(pip install tpchgen-cli to skip this)")
            self.con.execute("INSTALL tpch; LOAD tpch;")
            self.con.execute(f"CALL dbgen(sf={sf})")
            print("   generated with DuckDB tpch extension")
            return
        print("   generating with tpchgen-cli")
        with tempfile.TemporaryDirectory() as tmp:
            subprocess.run([exe, "parquet", "-s", str(sf), f"--output-dir={tmp}"],
                           check=True, stdout=subprocess.DEVNULL)
            for t in TABLES:
                self.con.execute(f"CREATE TABLE {t} AS SELECT * FROM "
                                 f"read_parquet('{Path(tmp) / (t + '.parquet')}')")
        print("   generated with tpchgen-cli")

    def run(self, sql):
        return self.con.execute(sql).fetchall()

    def explain(self, sql):
        rows = self.con.execute("EXPLAIN ANALYZE " + sql).fetchall()
        return "\n".join(str(r[-1]) for r in rows)


class Postgres:
    name = "postgres"

    def __init__(self, sf, pg, **_):
        import psycopg
        self.con = psycopg.connect(pg, autocommit=True)
        self.version = self.run("SHOW server_version")[0][0]
        if not self.run("SELECT to_regclass('public.lineitem')")[0][0]:
            self._load(sf, pg)

    def _load(self, sf, pg):
        """Copy the DuckDB-generated data into Postgres so both engines
        query byte-identical data."""
        print(f"Loading TPC-H SF{sf} into Postgres from DuckDB (one-time)...")
        import tempfile
        src = DuckDB(sf).con
        with tempfile.TemporaryDirectory() as tmp:
            for t in TABLES:
                cols = src.execute(f"DESCRIBE {t}").fetchall()
                ddl = ", ".join(f"{c[0]} {c[1]}" for c in cols)  # same types work in Postgres
                self.run(f"CREATE TABLE {t} ({ddl})")
                csv_path = Path(tmp) / f"{t}.csv"
                src.execute(f"COPY {t} TO '{csv_path}' (FORMAT csv, HEADER false)")
                with self.con.cursor() as cur, \
                        cur.copy(f"COPY {t} FROM STDIN (FORMAT csv)") as cp, \
                        open(csv_path, "rb") as f:
                    while chunk := f.read(1 << 20):
                        cp.write(chunk)
                csv_path.unlink()
                print(f"   loaded {t}")
        self.run("ANALYZE")

    def run(self, sql):
        with self.con.cursor() as cur:
            cur.execute(sql)
            return cur.fetchall() if cur.description else []

    def explain(self, sql):
        return "\n".join(r[0] for r in self.run("EXPLAIN (ANALYZE, BUFFERS) " + sql))


# ---------- helpers ----------
def load_sql(qdir, variant, engine):
    override = qdir / f"{variant}.{engine}.sql"
    f = override if override.exists() else qdir / f"{variant}.sql"
    return f.read_text().strip().rstrip(";")


def fingerprint(rows):
    """Order-independent hash of a result set (rounded to absorb float noise)."""
    norm = sorted(repr(tuple(round(v, 6) if isinstance(v, float) else v for v in r))
                  for r in rows)
    return len(rows), hashlib.md5("\n".join(norm).encode()).hexdigest()


def env_info(engine, sf):
    def sh(cmd):
        try:
            return subprocess.check_output(cmd, shell=True, text=True, stderr=subprocess.DEVNULL).strip()
        except Exception:
            return None
    return {
        "timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "engine": engine.name, "engine_version": engine.version, "sf": sf,
        "os": platform.platform(), "python": platform.python_version(),
        "cpu": sh("sysctl -n machdep.cpu.brand_string")
               or sh("lscpu | grep 'Model name' | cut -d: -f2 | xargs")
               or platform.processor(),
        "cpu_count": os.cpu_count(),
        "ram_gb": sh("free -g | awk '/Mem/{print $2}'")
                  or sh("echo $(( $(sysctl -n hw.memsize) / 1073741824 ))"),
        "git_commit": sh("git rev-parse --short HEAD"),
    }


def append_csv(path, rows, header):
    new = not path.exists()
    with path.open("a", newline="") as f:
        w = csv.DictWriter(f, fieldnames=header)
        if new:
            w.writeheader()
        w.writerows(rows)


# ---------- main ----------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", choices=["duckdb", "postgres"], required=True)
    ap.add_argument("--sf", type=float, default=1)
    ap.add_argument("--runs", type=int, default=5, help="timed runs (after 1 warm-up)")
    ap.add_argument("--pg", default="dbname=tpch user=postgres")
    ap.add_argument("--only", help="run a single query folder")
    a = ap.parse_args()
    sf = int(a.sf) if a.sf == int(a.sf) else a.sf

    engine = (DuckDB if a.engine == "duckdb" else Postgres)(sf=sf, pg=a.pg)
    OUT.mkdir(exist_ok=True)
    (OUT / "plans").mkdir(exist_ok=True)
    (OUT / f"env_{engine.name}_sf{sf}.json").write_text(
        json.dumps(env_info(engine, sf), indent=2))

    qdirs = sorted(d for d in QDIR.iterdir() if d.is_dir())
    if a.only:
        qdirs = [d for d in qdirs if d.name == a.only]

    for qd in qdirs:
        q = qd.name
        sqls = {v: load_sql(qd, v, engine.name) for v in ("old", "new")}
        base = dict(query=q, engine=engine.name, engine_version=engine.version, sf=sf)

        # 1) support + equivalence check (doubles as the warm-up run)
        fp = {}
        for v, sql in sqls.items():
            try:
                fp[v] = fingerprint(engine.run(sql))
            except Exception as e:
                fp[v] = ("UNSUPPORTED", str(e).splitlines()[0][:200])
        supported = {v: fp[v][0] != "UNSUPPORTED" for v in fp}
        equal = all(supported.values()) and fp["old"] == fp["new"]
        append_csv(OUT / "equivalence.csv", [{
            **base, "old_rows": fp["old"][0], "new_rows": fp["new"][0],
            "old_hash": fp["old"][1], "new_hash": fp["new"][1], "identical": equal,
        }], list(base) + ["old_rows", "new_rows", "old_hash", "new_hash", "identical"])
        status = "identical" if equal else ("MISMATCH" if all(supported.values())
                                            else f"unsupported: {[v for v,s in supported.items() if not s]}")
        print(f"[{engine.name} SF{sf}] {q}: {status}")
        if all(supported.values()) and not equal:
            print("   -> results differ; fix the rewrite before trusting timings")

        # 2) timed runs, interleaving old/new and alternating which goes first
        raw = []
        for i in range(a.runs):
            order = ["old", "new"] if i % 2 == 0 else ["new", "old"]
            for v in order:
                if not supported[v]:
                    continue
                t0 = time.perf_counter()
                engine.run(sqls[v])
                raw.append({**base, "variant": v, "run": i + 1,
                            "seconds": round(time.perf_counter() - t0, 6)})
        append_csv(OUT / "raw_runs.csv", raw, list(base) + ["variant", "run", "seconds"])

        # 3) summary + plans
        summ = []
        for v in ("old", "new"):
            ts = [r["seconds"] for r in raw if r["variant"] == v]
            if ts:
                summ.append({**base, "variant": v, "median_s": round(statistics.median(ts), 6),
                             "min_s": min(ts), "max_s": max(ts), "n": len(ts)})
                plan = engine.explain(sqls[v])
                (OUT / "plans" / f"{q}__{engine.name}__sf{sf}__{v}.txt").write_text(
                    f"-- {sqls[v]}\n\n{plan}")
        append_csv(OUT / "summary.csv", summ,
                   list(base) + ["variant", "median_s", "min_s", "max_s", "n"])
        if len(summ) == 2:
            o, n = summ[0]["median_s"], summ[1]["median_s"]
            print(f"   old {o:.4f}s | new {n:.4f}s | new/old = {n/o:.2f}x")


if __name__ == "__main__":
    main()
