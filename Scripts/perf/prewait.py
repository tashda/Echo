#!/usr/bin/env python3
"""prewait.py: waits until the test Postgres has fewer than 15 client sessions (a killed Echo leaves its sessions until the server notices),
so a run does not start into 'too many clients'. Gives up after 5 minutes and says so."""
import json, sys, time, pg8000.native
c = json.load(open("heavy-config.json"))
e = [x for x in c["connections"] if x["name"] == "Test Postgres"][0]
for _ in range(60):
    try:
        con = pg8000.native.Connection(e["username"], host=e["host"], port=e["port"], password=e.get("password", ""), database="postgres")
        n = con.run("select count(*) from pg_stat_activity where backend_type='client backend'")[0][0]; con.close()
        if n < 15: print(f"prewait: {n} Postgres client sessions, go"); sys.exit(0)
        print(f"prewait: {n} Postgres client sessions, waiting"); sys.stdout.flush()
    except Exception as ex:
        print(f"prewait: {ex}"); sys.stdout.flush()
    time.sleep(5)
print("prewait: gave up"); sys.exit(1)
