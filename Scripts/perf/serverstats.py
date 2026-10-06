#!/usr/bin/env python3
"""serverstats.py snapshot <file> | diff <before> <after> [top]: what the test servers did between two moments.

SQL Server: every statement's execution count, time, reads and rows (sys.dm_exec_query_stats); the diff lists
the statements that ran in between, busiest first. PostgreSQL: transactions, rows returned and fetched, blocks
read and the catalog tables most scanned (pg_stat_database / pg_stat_all_tables). Passwords come from the
automation config (ECHO_AUTOMATION_CONFIG or .echo-automation/config.json) and are never printed.
Needs `pip install python-tds pg8000`."""
import json, os, sys

def config():
    path = os.environ.get("ECHO_AUTOMATION_CONFIG") or os.path.join(os.path.dirname(__file__), "..", "..", ".echo-automation", "config.json")
    if not os.path.exists(path): path = "/Users/k/Development/Echo/.echo-automation/config.json"
    return {c["name"]: c for c in json.load(open(path))["connections"]}

def mssql(entry):
    import pytds
    return pytds.connect(entry["host"], port=entry["port"], user=entry["username"], password=entry.get("password", ""),
                         database="master", autocommit=True, login_timeout=15, timeout=60, validate_host=False)

def snapshot():
    out = {}
    for name, entry in config().items():
        try:
            if entry["type"] == "mssql":
                con = mssql(entry); cur = con.cursor()
                cur.execute("""SELECT CONVERT(varchar(64), s.sql_handle, 1) + ':' + CONVERT(varchar(10), s.statement_start_offset) AS k,
                       LEFT(REPLACE(REPLACE(SUBSTRING(t.text, s.statement_start_offset/2 + 1,
                         (CASE WHEN s.statement_end_offset = -1 THEN LEN(CONVERT(nvarchar(max), t.text)) * 2 ELSE s.statement_end_offset END - s.statement_start_offset)/2 + 1),
                         CHAR(13), ' '), CHAR(10), ' '), 220) AS txt,
                       s.execution_count, s.total_worker_time, s.total_logical_reads, s.total_rows, s.total_elapsed_time
                       FROM sys.dm_exec_query_stats s CROSS APPLY sys.dm_exec_sql_text(s.sql_handle) t""")
                rows = {r[0]: {"text": r[1], "n": r[2], "cpu_us": r[3], "reads": r[4], "rows": r[5], "elapsed_us": r[6]} for r in cur.fetchall()}
                cur.execute("SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE is_user_process = 1")
                out[name] = {"type": "mssql", "statements": rows, "sessions": cur.fetchone()[0]}
            else:
                import pg8000.native
                con = pg8000.native.Connection(entry["username"], host=entry["host"], port=entry["port"], database="postgres", password=entry.get("password", ""))
                db = con.run("SELECT sum(xact_commit + xact_rollback), sum(tup_returned), sum(tup_fetched), sum(blks_read), sum(blks_hit) FROM pg_stat_database")[0]
                tables = {f"{r[0]}.{r[1]}": [r[2] or 0, r[3] or 0] for r in con.run(
                    "SELECT schemaname, relname, seq_scan, idx_scan FROM pg_stat_all_tables WHERE schemaname IN ('pg_catalog','information_schema')")}
                sessions = con.run("SELECT count(*) FROM pg_stat_activity WHERE backend_type = 'client backend'")[0][0]
                out[name] = {"type": "postgresql", "xacts": int(db[0] or 0), "tup_returned": int(db[1] or 0), "tup_fetched": int(db[2] or 0),
                             "blks_read": int(db[3] or 0), "blks_hit": int(db[4] or 0), "tables": tables, "sessions": sessions}
        except Exception as error:
            out[name] = {"error": str(error)[:200]}
    return out

def diff(before, after, top):
    for name, a in after.items():
        b = before.get(name, {})
        print(f"== {name}")
        if "error" in a or "error" in b: print("  ", a.get("error") or b.get("error")); continue
        if a["type"] == "mssql":
            rows = []
            for k, v in a["statements"].items():
                old = b["statements"].get(k, {"n": 0, "cpu_us": 0, "reads": 0, "rows": 0, "elapsed_us": 0})
                if v["n"] > old["n"]:
                    rows.append((v["n"] - old["n"], (v["cpu_us"] - old["cpu_us"]) / 1000, v["reads"] - old["reads"], v["rows"] - old["rows"], (v["elapsed_us"] - old["elapsed_us"]) / 1000, v["text"]))
            rows.sort(reverse=True)
            print(f"   {sum(r[0] for r in rows)} statements ({len(rows)} distinct), {sum(r[3] for r in rows)} rows, {sum(r[1] for r in rows):.0f} ms server CPU, "
                  f"{sum(r[4] for r in rows):.0f} ms elapsed; sessions {b['sessions']} -> {a['sessions']}")
            print("      n   cpu_ms  reads     rows  elapsed_ms  statement")
            for n, cpu, reads, nrows, elapsed, text in rows[:top]:
                print(f"  {n:5d} {cpu:8.0f} {reads:6d} {nrows:8d} {elapsed:10.0f}  {text[:150]}")
        else:
            print(f"   transactions {a['xacts'] - b['xacts']}, rows returned {a['tup_returned'] - b['tup_returned']}, fetched {a['tup_fetched'] - b['tup_fetched']}, "
                  f"blocks read {a['blks_read'] - b['blks_read']} (hit {a['blks_hit'] - b['blks_hit']}); sessions {b['sessions']} -> {a['sessions']}")
            scans = sorted(((v[0] + v[1] - b["tables"].get(k, [0, 0])[0] - b["tables"].get(k, [0, 0])[1], k) for k, v in a["tables"].items()), reverse=True)
            for n, k in scans[:top]:
                if n > 0: print(f"  {n:6d} scans  {k}")

if __name__ == "__main__":
    if sys.argv[1] == "snapshot":
        json.dump(snapshot(), open(sys.argv[2], "w"))
    elif sys.argv[1] == "diff":
        diff(json.load(open(sys.argv[2])), json.load(open(sys.argv[3])), int(sys.argv[4]) if len(sys.argv) > 4 else 25)
