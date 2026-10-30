#!/usr/bin/env python3
"""The app's builds on Codemagic, from the computer (codemagic.yaml): the latest builds, starting one,
following it to the end, the errors of a failed one, and its screenshots. The API token is read from
~/.codemagic-token, outside the repository (Codemagic: Account settings, API token).

A build takes some of the month's free minutes, so one is started only when the user asks for it.

    python ios/scripts/codemagic.py builds
    python ios/scripts/codemagic.py start testflight      # or: screenshots
    python ios/scripts/codemagic.py wait <build id>
    python ios/scripts/codemagic.py errors <build id>
    python ios/scripts/codemagic.py artifacts <build id> [folder]   # into ios/build/screenshots
"""
import json
import os
import sys
import time
import urllib.request

APP = "6ae23e4ef34c6bdabbcf201b"
API = "https://api.codemagic.io"
TOKEN = open(os.path.join(os.path.expanduser("~"), ".codemagic-token"), encoding="ascii").read().strip()


def get(url):
    request = urllib.request.Request(url, headers={"x-auth-token": TOKEN})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", "replace")


def call(method, path, body=None):
    request = urllib.request.Request(
        API + path,
        method=method,
        headers={"x-auth-token": TOKEN, "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode("utf-8")
        return json.loads(text) if text else None


def build(build_id):
    data = call("GET", f"/builds/{build_id}")
    return data.get("build", data)


def minutes(build):
    """Minutes from start to end, from Codemagic's ISO times ("2026-10-29T20:01:05.656000+00:00")."""
    from datetime import datetime
    if not build.get("startedAt") or not build.get("finishedAt"):
        return ""
    start, end = (datetime.fromisoformat(build[key]) for key in ("startedAt", "finishedAt"))
    return f"{(end - start).total_seconds() / 60:.1f} min"


def line(build):
    commit = build.get("commit") or {}
    message = (commit.get("commitMessage") or "").splitlines()[0][:60] if commit.get("commitMessage") else ""
    return f"{build['_id']}  {build.get('fileWorkflowId') or '?':<11} {build.get('status'):<9} {minutes(build):>8}  {(commit.get('hash') or '')[:7]} {message}"


def errors(build):
    """The failed step's log: its error lines, or its end when it has none."""
    for action in build.get("buildActions", []):
        if action.get("status") != "failed":
            continue
        print(f"Failed: {action.get('name')}")
        for sub in action.get("subactions") or [action]:
            if sub.get("status") != "failed" or not sub.get("logUrl"):
                continue
            log = get(sub["logUrl"]).splitlines()
            found = [entry for entry in log if "error:" in entry or "FAILED" in entry]
            for entry in found or log[-40:]:
                print("  " + entry.strip())


def artifacts(build, folder):
    """The build's files into the folder, each by its name: the screenshots' PNGs, which Codemagic gives in
    one zip."""
    import io
    import zipfile
    os.makedirs(folder, exist_ok=True)
    for artifact in build.get("artefacts", []):
        request = urllib.request.Request(artifact["url"], headers={"x-auth-token": TOKEN})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        files = {os.path.basename(artifact["name"]): data}
        if artifact["name"].endswith(".zip"):
            archive = zipfile.ZipFile(io.BytesIO(data))
            files = {os.path.basename(entry.filename): archive.read(entry)
                     for entry in archive.infolist() if not entry.is_dir()}
        for name, content in sorted(files.items()):
            with open(os.path.join(folder, name), "wb") as out:
                out.write(content)
            print(os.path.join(folder, name))


command = sys.argv[1] if len(sys.argv) > 1 else "builds"
if command == "builds":
    for item in call("GET", f"/builds?appId={APP}").get("builds", [])[:8]:
        print(line(item))
elif command == "start":
    workflow = sys.argv[2]
    started = call("POST", "/builds", {"appId": APP, "workflowId": workflow, "branch": "main"})
    print(started.get("buildId"))
elif command == "wait":
    while True:
        current = build(sys.argv[2])
        if current.get("status") in ("finished", "failed", "canceled", "timeout", "skipped"):
            break
        time.sleep(30)
    print(line(current))
    if current.get("status") != "finished":
        print(current.get("message") or "")
        errors(current)
elif command == "errors":
    errors(build(sys.argv[2]))
elif command == "artifacts":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, "..", "build", "screenshots")
    artifacts(build(sys.argv[2]), os.path.normpath(folder))
else:
    sys.exit(__doc__)
