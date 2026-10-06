#!/usr/bin/env python3
import json, os, sys
D = os.environ.get("ECHO_PERF_SCRIPTS", os.path.dirname(os.path.abspath(__file__)) + "/scenarios")
M, P = "Test MSSQL", "Test Postgres"
def sec(server, t, w=2.0, label=None): return {"action":"section","server":server,"target":t,"wait":w,"label":label or f"sec {t}"}
def q(server, sql, w=3.0, label=None): return {"action":"query","server":server,"target":sql,"wait":w,"label":label or f"query {sql[:30]}"}
def tool(server, t, w=3.0): return {"action":"tool","server":server,"target":t,"wait":w,"label":f"tool {t}"}
def tab(t="next", w=1.0, label=None): return {"action":"tab","target":t,"wait":w,"label":label or f"tab {t}"}
def win(t, w=2.0): return {"action":"window","target":t,"wait":w,"label":f"window {t}"}
def scroll(t, d, s=1.5, w=0.5): return {"action":"scroll","target":t,"distance":d,"seconds":s,"wait":w,"label":f"scroll {t} {d}"}
def page(t="next", w=1.5): return {"action":"page","target":t,"wait":w,"label":f"page {t}"}
def menu(p, w=2.0): return {"action":"menu","target":p,"wait":w,"label":f"menu {p}"}
def settings(t, w=1.5): return {"action":"settings","target":t,"wait":w,"label":f"settings {t}"}
def typ(text, s=0.1): return {"action":"type","target":text,"seconds":s,"wait":1.0,"label":"type"}
def structure(server, t, w=4.0): return {"action":"structure","server":server,"target":t,"wait":w,"label":f"structure {t}"}
def diagram(server, t, w=4.0): return {"action":"diagram","server":server,"target":t,"wait":w,"label":f"diagram {t}"}
def close(t="tab", w=1.0): return {"action":"closeTab","wait":w,"label":"closeTab"} if t=="tab" else {"action":"close","target":t,"wait":w,"label":f"close {t}"}
def w(sec_): return {"wait":sec_,"label":"wait"}

S = {}
S["sidebar"] = ([M,P], [w(2)] +
  [sec(M,t) for t in ["Security","Server Objects","Agent Jobs","Management","Databases"]*2] +
  [{"action":"folder","server":M,"target":"AdventureWorks2022","wait":3,"label":"open-aw"},
   scroll("sidebar",900,2), scroll("sidebar",-900,2),
   {"action":"collapse","server":M,"wait":2,"label":"collapse"},{"action":"expand","server":M,"wait":2,"label":"expand"},
   {"action":"collapse","server":P,"wait":2,"label":"collapse pg"},{"action":"expand","server":P,"wait":2,"label":"expand pg"}])
S["sidebar-pg"] = ([P], [w(2)] + [sec(P,t) for t in ["Security","Activity","Management","Databases"]*2]
  + [{"action":"folder","server":P,"target":"postgres","wait":3,"label":"open-db"}, scroll("sidebar",600,1.5), scroll("sidebar",-600,1.5)])
tabsetup = ([q(M,"SELECT TOP 5000 * FROM Sales.SalesOrderDetail",3), q(M,"SELECT * FROM sys.objects",2), q(P,"SELECT g, md5(g::text) FROM generate_series(1,20000) g",3),
   q(M,"EXEC sp_who2",2), q(P,"SELECT * FROM pg_stat_activity",2), q(M,"SELECT TOP 100 * FROM Person.Person",2),
   tool(M,"activity"), tool(M,"serverProperties"), tool(P,"activity"), tool(M,"errorLog"), tool(M,"maintenance")])
S["tabs"] = ([M,P], [w(2)] + tabsetup + [tab("next",0.8) for _ in range(14)] + [tab("previous",0.8) for _ in range(8)] +
   [tab("first",1),tab("last",1),tab("3",1),tab("1",1),win("overview",2),win("overview",2)] + [close("tab",0.8) for _ in range(4)] + [w(2)])
S["tabs-sections"] = ([M,P], [w(2)] + tabsetup[:6] + [tool(M,"activity")] +
   [sec(M,t,2.0) for t in ["Security","Server Objects","Agent Jobs","Management","Databases"]*2] + [tab("next",1) for _ in range(6)] + [sec(M,"Security",2),tab("next",1),sec(M,"Databases",2)])
S["windows"] = ([M,P], [w(2)] + tabsetup[:6] + [win("sidebar",2.5),win("sidebar",2.5),win("inspector",2.5),win("inspector",2.5),win("sidebar",1.5),win("inspector",1.5),win("sidebar",1.5),win("inspector",1.5)] +
   [page("next",1.5)]*0 + [menu("View/Inspector Page/History",2),menu("View/Inspector Page/Bookmarks",2),menu("View/Inspector Page/Notifications",2),menu("View/Inspector Page/Details",2)])
S["slides"] = ([M], [w(2), q(M,"SELECT TOP 2000 * FROM Sales.SalesOrderDetail",4), sec(M,"Security",2), sec(M,"Databases",2)] +
   [x for _ in range(3) for x in (win("sidebar",1.6),win("sidebar",1.6),win("inspector",1.6),win("inspector",1.6))] + [sec(M,"Security",2),sec(M,"Management",2),sec(M,"Databases",2),sec(M,"Security",2),sec(M,"Databases",2)])
S["tabswitch"] = ([M,P], [w(2)] + [q(M,"SELECT TOP 300 * FROM Person.Person",2.0) for _ in range(3)] + [q(P,"SELECT g, md5(g::text) FROM generate_series(1,300) g",2.0) for _ in range(3)] +
   [tab("next",1.0) for _ in range(12)] + [tab("previous",1.0) for _ in range(6)] + [w(1)])
S["editor-mssql"] = ([M], [w(2), q(M,"",1.5,"empty tab"), typ("SELECT TOP 10 * FROM Sales.SalesOrderHeader soh JOIN Sales.SalesOrderDetail sod ON sod.SalesOrderID = soh.SalesOrderID WHERE soh.", 0.08),
   typ("SalesOrderID > 5",0.08), w(1), menu("Query/Run",4), typ("\nSELECT * FROM Pe",0.1), w(1.5)])
S["rows100k-mssql"] = ([M], [w(2), q(M,"SELECT * FROM Sales.SalesOrderDetail",12,"121k rows"), scroll("grid",20000,3), scroll("grid",-20000,3), scroll("gridx",800,1.5), scroll("gridx",-800,1.5),
   scroll("grid",50000,2), q(M,"SELECT * FROM Production.TransactionHistory",12,"113k rows"), scroll("grid",30000,3), tab("previous",2), tab("next",2)])
S["rows100k-pg"] = ([P], [w(2), q(P,"SELECT g AS id, md5(g::text) AS hash, now() - (g || ' seconds')::interval AS ts, g % 97 AS bucket, repeat('x', 20) AS pad FROM generate_series(1,250000) g",14,"250k rows"),
   scroll("grid",20000,3), scroll("grid",-20000,3), scroll("gridx",600,1.5), scroll("gridx",-600,1.5), scroll("grid",60000,2), tab("previous",2), tab("next",2)])
S["settings"] = ([M], [w(2), menu("Echo/Settings",3)] + [x for sct in ["general","notifications","appearance","editor","databases","sidebar","search","queryResults","echoSense","diagrams","applicationCache","keyboardShortcuts"]
   for x in (settings(sct,1.5), scroll("settings",2500,2.0,0.5), scroll("settings",-2500,1.0,0.5))] + [close("settings",1)])
S["manage"] = ([M,P], [w(2), menu("Connect/Manage Connections",3), scroll("manage",1500,1.5), scroll("manage",-1500,1.5), w(2), close("manage",1), w(1)])
S["structure"] = ([M,P], [w(2), structure(M,"AdventureWorks2022/Sales.SalesOrderHeader",5), structure(M,"AdventureWorks2022/Production.Product",5), structure(P,"postgres/public.netflix_shows",5), tab("previous",2), tab("previous",2), tab("next",2),
   diagram(M,"AdventureWorks2022/Sales.SalesOrderHeader",6), tab("previous",2)])
S["procs"] = ([M,P], [w(2), q(M,"EXEC sp_help 'Sales.SalesOrderHeader'",4), q(M,"EXEC sp_who2",4), q(M,"EXEC sp_spaceused",4), q(M,"EXEC dbo.uspGetBillOfMaterials @StartProductID = 800, @CheckDate = '2013-01-01'",5),
   q(P,"SELECT * FROM pg_stat_database",3), q(P,"SELECT proname FROM pg_proc",3), tab("previous",1.5),tab("previous",1.5),tab("next",1.5)])
S["toolpages"] = ([M,P], [w(2), tool(M,"activity",3)] + [page("next",1.5) for _ in range(6)] + [tool(M,"maintenance",3)] + [page("next",1.5) for _ in range(5)] +
   [tool(M,"serverProperties",3)] + [page("next",1.5) for _ in range(5)] + [tool(P,"activity",3)] + [page("next",1.5) for _ in range(5)] + [tool(M,"jobs",3), tool(M,"extendedEvents",3), tool(M,"profiler",3), tool(M,"serverSecurity",3), tool(M,"tuningAdvisor",3)] + [page("next",1.5) for _ in range(3)])
S["connect"] = ([], [w(1), {"action":"connect","server":M,"wait":8,"label":"connect mssql"},{"action":"connect","server":P,"wait":8,"label":"connect pg"}, sec(M,"Security",2), sec(P,"Security",2)])
S["menus-all"] = ([M,P], [w(2), q(M,"SELECT 1",2), menu("File/New Query Tab",2), menu("File/Next Tab",1), menu("File/Previous Tab",1), menu("View/Toggle Sidebar",2), menu("View/Toggle Sidebar",2),
   menu("View/Show Tab Overview",2), menu("View/Show Tab Overview",2), menu("View/Show Bottom Panel",2), menu("View/Show Bottom Panel",2), menu("View/Show Inspector",2), menu("View/Show Inspector",2),
   menu("View/Command Palette",2), menu("View/Search",2), menu("Query/Format Query",2), menu("View/Reload Tab",2), menu("File/Reopen Closed Tab",2), menu("File/Close Query Tab",2), menu("Window/Performance Monitor",3), menu("Window/Autocomplete Management",3)])

if __name__ == "__main__":
    os.makedirs(D, exist_ok=True)
    for name,(connect,steps) in S.items():
        json.dump({"connect":connect,"steps":steps}, open(f"{D}/{name}.json","w"), indent=1)
        total = sum(s.get("wait",0)+(s.get("seconds",0) if s.get("action") in("scroll",) else 0)+(len(s.get("target","")) * s.get("seconds",0.1) if s.get("action")=="type" else 0) for s in steps)
        print(name, int(total))
