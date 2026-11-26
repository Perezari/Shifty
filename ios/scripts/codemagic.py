#!/usr/bin/env python3
"""The app's builds on Codemagic, from the computer (codemagic.yaml): the latest builds, starting one,
following it to the end, the errors of a failed one, a step's log, and its screenshots. The API token is
read from ~/.codemagic-token, outside the repository (Codemagic: Account settings, API token).

A build takes some of the month's free minutes, so one is started only when the user asks for it. When
Codemagic refuses (its free minutes spent, HTTP 402), testflight and review go to CircleCI's free Macs instead
(.circleci/config.yml: the pipeline "shifty" of the Sogia project, whose variables hold the App Store key; its
token in ~/.circleci-token, the project in circleci.json beside this script). Such a build is
"circleci:<pipeline id>", which wait, errors and log take as well.

    python ios/scripts/codemagic.py builds
    python ios/scripts/codemagic.py start testflight      # or: screenshots, review [SUBMIT=yes]
    python ios/scripts/codemagic.py start testflight circleci   # straight to CircleCI
    python ios/scripts/codemagic.py wait <build id>
    python ios/scripts/codemagic.py errors <build id>
    python ios/scripts/codemagic.py log <build id> [words of the step's name]   # else the last step
    python ios/scripts/codemagic.py artifacts <build id> [folder]   # into ios/build/screenshots
    python ios/scripts/codemagic.py cancel <build id>
"""
import json
import os
import sys
import time
import urllib.error
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


def log(build, words=None):
    """A step's whole log: those whose name holds the words, or else the last step."""
    actions = build.get("buildActions", [])
    chosen = [a for a in actions if words.lower() in (a.get("name") or "").lower()] if words else actions[-1:]
    for action in chosen:
        print(f"== {action.get('name')} ({action.get('status')})")
        for sub in action.get("subactions") or [action]:
            if sub.get("logUrl"):
                print(get(sub["logUrl"]))


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


CIRCLE_API = "https://circleci.com/api"
CIRCLE_TOKEN_FILE = os.path.join(os.path.expanduser("~"), ".circleci-token")
# The project's slug ("circleci/<org id>/<project id>", an organization joined through CircleCI's GitHub App) and
# the pipeline's definition id. Not secrets.
CIRCLE_PROJECT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "circleci.json")


def circle_project():
    with open(CIRCLE_PROJECT, encoding="utf-8") as f:
        return json.load(f)


def circle(method, path, body=None):
    """CircleCI's API (path from /api, e.g. "/v2/pipeline/<id>"), with the token; its JSON."""
    token = open(CIRCLE_TOKEN_FILE, encoding="ascii").read().strip()
    request = urllib.request.Request(
        CIRCLE_API + path,
        method=method,
        headers={"Circle-Token": token, "Content-Type": "application/json", "Accept": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        text = response.read().decode("utf-8", "replace")
        return json.loads(text) if text else None


def circle_start(workflow, variables):
    """The build on CircleCI's Macs: the pipeline on main with run = the workflow, and SUBMIT its review's.
    Its id, as "circleci:<pipeline id>"."""
    if workflow not in ("testflight", "review"):
        sys.exit(f"CircleCI runs testflight and review here, not {workflow}.")
    project = circle_project()
    parameters = {"run": workflow}
    if workflow == "review":
        parameters["submit"] = variables.get("SUBMIT") or "look"
    body = {"definition_id": project["definition"], "config": {"branch": "main"}, "checkout": {"branch": "main"},
            "parameters": parameters}
    started = circle("POST", f"/v2/project/{project['project']}/pipeline/run", body)
    return f"circleci:{started['id']}"


def circle_jobs(pipeline):
    jobs = []
    for workflow in circle("GET", f"/v2/pipeline/{pipeline}/workflow").get("items", []):
        jobs += circle("GET", f"/v2/workflow/{workflow['id']}/job").get("items", [])
    return jobs


def circle_wait(pipeline):
    """A pipeline to its end: each workflow's outcome, and a failed one's errors."""
    finished = {"success", "failed", "error", "canceled", "not_run", "unauthorized"}
    while True:
        workflows = circle("GET", f"/v2/pipeline/{pipeline}/workflow").get("items", [])
        if workflows and all(w.get("status") in finished for w in workflows):
            break
        time.sleep(30)
    for w in workflows:
        print(f"circleci:{pipeline}  {w.get('name')}  {w.get('status')}  {w.get('created_at', '')[:16]} - {(w.get('stopped_at') or '')[:16]}")
    if any(w.get("status") != "success" for w in workflows):
        circle_errors(pipeline)


def circle_steps(pipeline):
    """Each job's steps' actions (API v1.1), with the job."""
    slug = circle_project()["project"]
    for job in circle_jobs(pipeline):
        if not job.get("job_number"):
            continue
        detail = circle("GET", f"/v1.1/project/{slug}/{job['job_number']}")
        for step in detail.get("steps", []):
            for action in step.get("actions", []):
                yield job, action


def circle_output(action):
    with urllib.request.urlopen(action["output_url"], timeout=120) as response:
        output = json.loads(response.read().decode("utf-8", "replace"))
    return "".join(part.get("message", "") for part in output)


def circle_errors(pipeline):
    """The failed steps' error lines, or their ends."""
    for job, action in circle_steps(pipeline):
        if action.get("status") not in ("failed", "timedout") or not action.get("output_url"):
            continue
        print(f"Failed: {action.get('name')} (job {job.get('name')})")
        log = circle_output(action).splitlines()
        found = [entry for entry in log if "error:" in entry or "FAILED" in entry]
        for entry in found[-40:] or log[-40:]:
            print("  " + entry.strip())


def circle_log(pipeline, words=None):
    """The output of the steps whose name has `words` (all of them without), in UTF-8 for its Hebrew."""
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    for job, action in circle_steps(pipeline):
        if (words and words.lower() not in (action.get("name") or "").lower()) or not action.get("output_url"):
            continue
        print(f"== {action.get('name')} ({action.get('status')})")
        print(circle_output(action).rstrip())


command = sys.argv[1] if len(sys.argv) > 1 else "builds"
circleci = len(sys.argv) > 2 and sys.argv[2].startswith("circleci:")
pipeline = sys.argv[2].split(":", 1)[1] if circleci else None
if command == "builds":
    for item in call("GET", f"/builds?appId={APP}").get("builds", [])[:8]:
        print(line(item))
elif command == "start":
    workflow = sys.argv[2]
    rest = sys.argv[3:]
    straight = bool(rest) and rest[0] == "circleci"
    variables = dict(arg.split("=", 1) for arg in (rest[1:] if straight else rest))
    if straight:
        print(circle_start(workflow, variables))
    else:
        body = {"appId": APP, "workflowId": workflow, "branch": "main"}
        if variables:
            body["environment"] = {"variables": variables}
        try:
            started = call("POST", "/builds", body)
            print(started.get("buildId"))
        except urllib.error.HTTPError as error:
            if error.code != 402:
                raise
            print("Codemagic's free minutes are spent (HTTP 402); on CircleCI's Macs:")
            print(circle_start(workflow, variables))
elif command == "wait" and circleci:
    circle_wait(pipeline)
elif command == "errors" and circleci:
    circle_errors(pipeline)
elif command == "log" and circleci:
    circle_log(pipeline, sys.argv[3] if len(sys.argv) > 3 else None)
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
elif command == "log":
    log(build(sys.argv[2]), sys.argv[3] if len(sys.argv) > 3 else None)
elif command == "cancel":
    call("POST", f"/builds/{sys.argv[2]}/cancel")
    print(line(build(sys.argv[2])))
elif command == "artifacts":
    here = os.path.dirname(os.path.abspath(__file__))
    folder = sys.argv[3] if len(sys.argv) > 3 else os.path.join(here, "..", "build", "screenshots")
    artifacts(build(sys.argv[2]), os.path.normpath(folder))
else:
    sys.exit(__doc__)
