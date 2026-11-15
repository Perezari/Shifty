#!/usr/bin/env python3
"""Sends the newest build to App Review through the App Store Connect API, as one would on the version's
page in App Store Connect: the version of ios/project.yml (MARKETING_VERSION) is made if it isn't there
yet, its texts are the ones under that version in ios/store/listing.md, its build is the newest of that
version in TestFlight, and it is submitted. Of the texts, "What's New in This Version" is always there;
the app's name (in App Information), the description and the App Review notes are written when the
version's section has them. The rest of the page (the texts the section hasn't, keywords, screenshots,
App Review's contact) carries over from the version before, as App Store Connect does by itself; its
copyright and way of release are taken from that version too.

Runs on Codemagic (codemagic.yaml, workflow "review") with the key of the variable group app_store.
The build's log is public, so nothing of the key, nor the token made from it, is printed. Without
SUBMIT=yes it only looks and says what it would do:

    python ios/scripts/codemagic.py start review               # a look, nothing changes
    python ios/scripts/codemagic.py start review SUBMIT=yes    # submit
    python ios/scripts/codemagic.py log <build id> "App Review"
    python ios/scripts/review.py text                          # the version and its texts, here
"""
import base64
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

BUNDLE = "com.perezari.shifty"
API = "https://api.appstoreconnect.apple.com"
IOS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
# A version in these states is still the developer's to change and submit; in any other it is with
# Apple or already out.
EDITABLE = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "DEVELOPER_REJECTED", "REJECTED",
            "METADATA_REJECTED", "INVALID_BINARY"}
BEARER = ""


def version():
    with open(os.path.join(IOS, "project.yml"), encoding="utf-8") as f:
        return re.search(r'MARKETING_VERSION:\s*"?([0-9.]+)', f.read()).group(1)


# The texts listing.md may give a version: the bold title they are under there, their name in the log, and
# App Store Connect's limit
TEXTS = {"whatsNew": ("What's New", "What's New", 4000), "name": ("Name", "name", 30),
         "description": ("Description", "description", 4000), "notes": ("App Review notes", "App Review notes", 4000)}


def texts(v):
    """The texts in listing.md's section "## Version <v>", each the ``` block under its bold title: What's New
    always; the name, the description and the App Review notes only when the section has them."""
    with open(os.path.join(IOS, "store", "listing.md"), encoding="utf-8") as f:
        text = f.read().replace("\r\n", "\n")
    section = re.search(rf"^## Version {re.escape(v)}[ \t]*\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not section:
        sys.exit(f'listing.md has no section "## Version {v}"')
    found = {}
    for field, (title, said, limit) in TEXTS.items():
        block = re.search(rf"^\*\*{re.escape(title)}[^\n]*\n+```[^\n]*\n(.*?)\n```", section.group(1), re.M | re.S)
        if block and block.group(1).strip():
            found[field] = block.group(1).strip()
            if len(found[field]) > limit:
                sys.exit(f"listing.md's {said} of {v} is {len(found[field])} characters, over the {limit} allowed")
    if "whatsNew" not in found:
        sys.exit(f"listing.md's section of {v} has no What's New block")
    return found


def show(found, whole=False):
    """The texts for the log: the name and What's New in full, the long ones by their length and first words."""
    for field, value in found.items():
        said, limit = TEXTS[field][1:]
        if whole or field in ("name", "whatsNew"):
            print(f"\n{said} ({len(value)} of {limit}):\n{value}")
        else:
            print(f"\n{said}: {len(value)} of {limit}, beginning \"{value.splitlines()[0][:60]}…\"")


def hebrew(items):
    return [x for x in items if x["attributes"]["locale"].split("-")[0] == "he"]


# The key and the token ---------------------------------------------------------------------------

def clean(name):
    """A space, a line break or quotes pasted around a value are dropped (as testflight.sh does)."""
    return re.sub(r"[\s\"']", "", os.environ.get(name, ""))


def pem(text):
    """The key as a PEM file whatever way the variable holds it, as testflight.sh makes it."""
    text = text.strip()
    if "BEGIN" not in text:
        data = base64.b64decode(re.sub(r"\\n|\s", "", text))
        if data.startswith(b"-----"):
            text = data.decode()
    body = re.sub(r"-----[^-]+-----|\\n|\s", "", text)
    lines = "\n".join(body[i:i + 64] for i in range(0, len(body), 64))
    return f"-----BEGIN PRIVATE KEY-----\n{lines}\n-----END PRIVATE KEY-----\n"


def b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def raw(der):
    """openssl's ECDSA signature, DER (a sequence of two integers), as ES256 wants it: r then s, 32
    bytes each."""
    i = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    out = b""
    for _ in range(2):
        n = der[i + 1]
        out += der[i + 2:i + 2 + n].lstrip(b"\0").rjust(32, b"\0")
        i += 2 + n
    return out


def token(key_file, key_id, issuer):
    """App Store Connect's token: a JWT signed with the key (ES256), good for 15 minutes."""
    now = int(time.time())
    head = b64(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    claims = b64(json.dumps({"iss": issuer, "iat": now, "exp": now + 900, "aud": "appstoreconnect-v1"}).encode())
    signed = subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_file],
                            input=f"{head}.{claims}".encode(), capture_output=True)
    if signed.returncode:
        sys.exit("openssl could not sign with the key: " + signed.stderr.decode("utf-8", "replace")[:200])
    return f"{head}.{claims}.{b64(raw(signed.stdout))}"


# The API -----------------------------------------------------------------------------------------

class Refused(Exception):
    def __init__(self, status, method, path, text):
        try:
            found = json.loads(text).get("errors", [])
            text = "\n".join(f"  {e.get('code')}: {e.get('title')}. {e.get('detail') or ''}".rstrip()
                             for e in found) or text
        except ValueError:
            pass
        super().__init__(f"{method} {path} → {status}\n{text}")
        self.status = status


def api(method, path, query=None, body=None):
    url = API + path + ("?" + urllib.parse.urlencode(query) if query else "")
    request = urllib.request.Request(url, method=method,
                                     data=json.dumps(body).encode() if body is not None else None,
                                     headers={"Authorization": f"Bearer {BEARER}",
                                              "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            text = response.read().decode("utf-8")
            return json.loads(text) if text else {}
    except urllib.error.HTTPError as error:
        raise Refused(error.code, method, path, error.read().decode("utf-8", "replace")) from None


def state(item):
    """A version's state, or App Information's."""
    a = item["attributes"]
    return a.get("appVersionState") or a.get("state") or a.get("appStoreState") or "?"


def related(kind, item_id):
    return {"data": {"type": kind, "id": item_id}}


# The submission ----------------------------------------------------------------------------------

def main():
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    v = version()
    store = texts(v)
    if sys.argv[1:] == ["text"]:
        print(f"Version {v}")
        show(store, whole=True)
        return
    submit = os.environ.get("SUBMIT", "").strip().lower() == "yes"
    key_id, issuer, p8 = clean("APPLE_API_KEY"), clean("APPLE_API_ISSUER"), os.environ.get("APPLE_API_KEY_P8", "")
    if not (key_id and issuer and p8.strip()):
        sys.exit("Needs APPLE_API_KEY, APPLE_API_ISSUER and APPLE_API_KEY_P8 (the variable group app_store)")
    global BEARER
    handle, key_file = tempfile.mkstemp(suffix=".p8")
    try:
        with os.fdopen(handle, "w") as f:
            f.write(pem(p8))
        BEARER = token(key_file, key_id, issuer)
    finally:
        os.remove(key_file)

    apps = api("GET", "/v1/apps", {"filter[bundleId]": BUNDLE})["data"]
    if not apps:
        sys.exit(f"No app with the bundle ID {BUNDLE}")
    app_id = apps[0]["id"]
    print(f"App: {apps[0]['attributes']['name']} ({app_id})")

    builds = api("GET", "/v1/builds", {"filter[app]": app_id, "filter[preReleaseVersion.version]": v,
                                       "filter[expired]": "false", "sort": "-uploadedDate", "limit": "5"})["data"]
    for b in builds:
        a = b["attributes"]
        print(f"Build {v} ({a['version']}): {a['processingState']}, uploaded {a['uploadedDate']}, "
              f"non-exempt encryption {a.get('usesNonExemptEncryption')}")
    valid = [b for b in builds if b["attributes"]["processingState"] == "VALID"]
    if not valid:
        sys.exit(f"No processed build of {v} in TestFlight yet")
    build = valid[0]
    number = build["attributes"]["version"]

    versions = api("GET", f"/v1/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS", "limit": "10"})["data"]
    versions.sort(key=lambda x: x["attributes"].get("createdDate") or "", reverse=True)
    for x in versions[:3]:
        a = x["attributes"]
        print(f"Version {a['versionString']}: {state(x)}, release {a.get('releaseType')}, "
              f"copyright {'set' if a.get('copyright') else 'empty'}")
    current = next((x for x in versions if x["attributes"]["versionString"] == v), None)
    previous = next((x for x in versions if x["attributes"]["versionString"] != v), None)
    if current and state(current) not in EDITABLE:
        print(f"{v} is {state(current)} already: nothing to do.")
        return
    if previous:
        locales = api("GET", f"/v1/appStoreVersions/{previous['id']}/appStoreVersionLocalizations")["data"]
        print(f"Texts of {previous['attributes']['versionString']}: " + ", ".join(
            f"{l['attributes']['locale']} (description {'set' if l['attributes'].get('description') else 'empty'})"
            for l in locales))

    reviews = api("GET", "/v1/reviewSubmissions", {
        "filter[app]": app_id, "filter[platform]": "IOS",
        "filter[state]": "READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES"})["data"]
    for r in reviews:
        print(f"Open review submission: {r['attributes']['state']}")
    if any(r["attributes"]["state"] != "READY_FOR_REVIEW" for r in reviews):
        sys.exit("Something of the app is with App Review already: submit after it.")

    infos = api("GET", f"/v1/apps/{app_id}/appInfos")["data"]
    for info in infos:
        names = hebrew(api("GET", f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"])
        print(f"App Information {state(info)}: " + ", ".join(f'"{n["attributes"].get("name")}"' for n in names))

    if not submit:
        print(f"\nA look only, nothing changed. With SUBMIT=yes: {'version ' + v + ' made' if not current else v}, "
              f"build {number} on it, these texts of listing.md written, and it submitted to App Review:")
        show(store)
        return

    if not current:
        attributes = {"platform": "IOS", "versionString": v}
        if previous:
            a = previous["attributes"]
            if a.get("copyright"):
                attributes["copyright"] = a["copyright"]
            if a.get("releaseType") in ("MANUAL", "AFTER_APPROVAL"):
                attributes["releaseType"] = a["releaseType"]
        current = api("POST", "/v1/appStoreVersions", body={"data": {
            "type": "appStoreVersions", "attributes": attributes,
            "relationships": {"app": related("apps", app_id)}}})["data"]
        print(f"Made version {v}")
    version_id = current["id"]

    api("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", body=related("builds", build["id"]))
    print(f"Its build: {v} ({number})")

    locales = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")["data"]
    page = {field: store[field] for field in ("whatsNew", "description") if field in store}
    if not hebrew(locales):
        sys.exit("The version has no Hebrew texts: " + ", ".join(t["attributes"]["locale"] for t in locales))
    for t in hebrew(locales):
        api("PATCH", f"/v1/appStoreVersionLocalizations/{t['id']}", body={"data": {
            "type": "appStoreVersionLocalizations", "id": t["id"], "attributes": page}})
    print("Its " + " and ".join(TEXTS[field][1] for field in page) + ": written")

    if "name" in store:
        # The name is App Information's, which has a copy of its own to change while a version is prepared
        infos = api("GET", f"/v1/apps/{app_id}/appInfos")["data"]
        open_info = next((i for i in infos if state(i) in EDITABLE), None)
        if not open_info:
            sys.exit("No App Information open to change the name in: " + ", ".join(state(i) for i in infos))
        names = hebrew(api("GET", f"/v1/appInfos/{open_info['id']}/appInfoLocalizations")["data"])
        if not names:
            sys.exit("App Information has no Hebrew name to change")
        for n in names:
            if n["attributes"].get("name") != store["name"]:
                api("PATCH", f"/v1/appInfoLocalizations/{n['id']}", body={"data": {
                    "type": "appInfoLocalizations", "id": n["id"], "attributes": {"name": store["name"]}}})
        print(f"Its name: {store['name']}")

    if "notes" in store:
        try:
            detail = api("GET", f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail")["data"]
        except Refused as refused:
            if refused.status != 404:
                raise
            detail = None
        if not detail:
            sys.exit("The version has no App Review Information to write the notes in: fill it in App Store Connect, "
                     "then run again")
        api("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", body={"data": {
            "type": "appStoreReviewDetails", "id": detail["id"], "attributes": {"notes": store["notes"]}}})
        print("Its App Review notes: written")

    draft = next((r for r in reviews if r["attributes"]["state"] == "READY_FOR_REVIEW"), None)
    if not draft:
        draft = api("POST", "/v1/reviewSubmissions", body={"data": {
            "type": "reviewSubmissions", "attributes": {"platform": "IOS"},
            "relationships": {"app": related("apps", app_id)}}})["data"]
    try:
        api("POST", "/v1/reviewSubmissionItems", body={"data": {
            "type": "reviewSubmissionItems",
            "relationships": {"reviewSubmission": related("reviewSubmissions", draft["id"]),
                              "appStoreVersion": related("appStoreVersions", version_id)}}})
    except Refused as refused:
        items = api("GET", f"/v1/reviewSubmissions/{draft['id']}/items", {"include": "appStoreVersion"})["data"]
        def holds(item):
            link = ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data") or {}
            return link.get("id") == version_id
        if refused.status != 409 or not any(holds(i) for i in items):
            raise
        print("(the version was in the submission already)")
    done = api("PATCH", f"/v1/reviewSubmissions/{draft['id']}", body={"data": {
        "type": "reviewSubmissions", "id": draft["id"], "attributes": {"submitted": True}}})["data"]
    after = api("GET", f"/v1/appStoreVersions/{version_id}")["data"]
    print(f"Submitted: {v} ({number}), the submission {done['attributes'].get('state')}, the version {state(after)}")


if __name__ == "__main__":
    try:
        main()
    except Refused as refused:
        sys.exit(f"App Store Connect refused:\n{refused}")
