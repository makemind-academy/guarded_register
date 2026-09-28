#!/usr/bin/env python3
"""guarded-register: one screen file for both roles; the till refuses what the role may not do and writes it to the audit log."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "tools"))
from appplayer import AppPlayer  # noqa: E402
from mcpclient import Server  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.join(HERE, "register_server")
CAP = os.path.join(HERE, "captures")

def run(role):
    with Server(["dart", "run", "bin/server.dart", f"--role={role}"], cwd=SERVER) as s:
        s.call("sale.ring", {"amount": 900})
        s.call("sale.void")
        return s.call("drawer.open")

staff, manager = run("staff"), run("manager")
assert staff["sales"] == 4 and staff["voided"] == 0 and staff["refused"] == 2, staff
assert manager["voided"] == 1 and manager["refused"] == 0, manager

ap = AppPlayer()
for role in ("staff", "manager"):
    ap.register_server(f"com.makemind.sample.register.{role}", f"Register ({role})", cwd=SERVER,
                       args=["run", "bin/server.dart", f"--role={role}"])
ap.restart()
ap.open_server("com.makemind.sample.register.staff")
ap.wait_text("SIGNED IN AS")
ap.expect_text("STAFF")
ap.tap("Ring up $9.00")
ap.wait_text("rang $9.00")
ap.tap("Void last sale")
ap.wait_text("refused")
ap.shot(f"{CAP}/01_staff.png")
ap.restart()
ap.open_server("com.makemind.sample.register.manager")
ap.wait_text("SIGNED IN AS")
ap.expect_text("MANAGER")
ap.tap("Void last sale")
ap.wait_text("void")
ap.shot(f"{CAP}/02_manager.png")
print("guarded-register: same screen, staff refused twice, manager voided once")
