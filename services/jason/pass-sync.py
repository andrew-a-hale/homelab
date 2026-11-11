#!/usr/bin/python
import csv
import time
import subprocess

with open("pass.csv", mode="r") as f:
    rows = csv.DictReader(f)
    for row in rows:
        name = row["name"]
        user = row["email"] if row["email"] else row["username"]
        pw = row["password"].encode("utf-8")
        cmd = subprocess.Popen(
            [
                "pass",
                "insert",
                "-f",
                "-e",
                f"{name}-{user}",
            ],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            start_new_session=True,
        )

        assert cmd.stdin
        cmd.stdin.write(pw)
        print(f"read: {name}-{user} -- {pw}")
        time.sleep(0.1)
