#!/usr/bin/env python3
"""pgwatch.py <seconds>: every 3 s prints how many client sessions the test Postgres has, and what they are doing."""
import json, sys, time, collections, pg8000.native
c = json.load(open("heavy-config.json")); e = [x for x in c["connections"] if x["name"] == "Test Postgres"][0]
t0 = time.time()
while time.time() - t0 < float(sys.argv[1]):
    try:
        con = pg8000.native.Connection(e["username"], host=e["host"], port=e["port"], password=e.get("password", ""), database="postgres")
        rows = con.run("select datname, state, left(coalesce(application_name,''),20), count(*) from pg_stat_activity where backend_type='client backend' and pid<>pg_backend_pid() group by 1,2,3 order by 4 desc")
        total = sum(r[3] for r in rows); con.close()
        print(f"{time.time()-t0:5.0f}s total={total} " + "; ".join(f"{r[0]}/{r[1]}/{r[2]}={r[3]}" for r in rows[:6])); sys.stdout.flush()
    except Exception as ex: print(f"{time.time()-t0:5.0f}s ERR {str(ex)[:80]}"); sys.stdout.flush()
    time.sleep(3)
