#!/usr/bin/env python3
"""One-shot, administrative CapRover export. Never run implicitly during deployment."""
import argparse
import gzip
import http.client
import json
import os
from pathlib import Path
import secrets
import ssl
import sys
import time
import urllib.error
import urllib.request

API = "https://captain.donatebot.app/api/v2"
APP = "migration-export"
EXPORT_URL = "https://migration-export.donatebot.app"

HELPER_SOURCE = r'''
import hashlib
import hmac
import http.client
import json
import os
import socket
import struct
from http.server import BaseHTTPRequestHandler, HTTPServer

class UnixHTTP(http.client.HTTPConnection):
    def __init__(self):
        super().__init__("localhost", timeout=3600)
    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect("/var/run/docker.sock")

def docker(method, path, body=None):
    conn = UnixHTTP()
    payload = None if body is None else json.dumps(body).encode()
    conn.request(method, path, payload, {"Content-Type": "application/json"})
    response = conn.getresponse()
    if response.status not in (200, 201, 101):
        response.close()
        conn.close()
        raise RuntimeError("Docker request failed")
    return conn, response

def docker_json(method, path, body=None):
    conn, response = docker(method, path, body)
    try:
        return json.load(response)
    finally:
        response.close()
        conn.close()

def frames(stream):
    def exact(size):
        chunks = []
        while size:
            chunk = stream.read(size)
            if not chunk:
                raise RuntimeError("Truncated Docker stream")
            chunks.append(chunk)
            size -= len(chunk)
        return b"".join(chunks)
    while True:
        first = stream.read(1)
        if not first:
            return
        header = first + exact(7)
        kind, length = header[0], struct.unpack(">I", header[4:])[0]
        if kind not in (1, 2) or header[1:4] != b"\0\0\0":
            raise RuntimeError("Invalid Docker stream")
        # Consume frames in bounded pieces, including large archive frames.
        while length:
            size = min(length, 65536)
            yield kind, exact(size)
            length -= size

def container(service):
    from urllib.parse import quote
    filters = quote(json.dumps({"label": ["com.docker.swarm.service.name=" + service]}))
    rows = docker_json("GET", "/containers/json?filters=" + filters)
    rows = [row for row in rows if row.get("Labels", {}).get("com.docker.swarm.service.name") == service]
    if len(rows) != 1:
        raise RuntimeError("Expected one running service container")
    return rows[0]

def execute(row, command, emit):
    result = docker_json("POST", "/containers/" + row["Id"] + "/exec", {
        "AttachStdout": True, "AttachStderr": True, "Tty": False, "Cmd": command})
    exec_id = result["Id"]
    conn, response = docker("POST", "/exec/" + exec_id + "/start", {"Detach": False, "Tty": False})
    try:
        # No Upgrade requested: Docker normally returns 200. For 101, the
        # buffered response fp owns the upgraded socket (read() would return EOF).
        stream = response.fp if response.status == 101 else response
        for kind, chunk in frames(stream):
            if kind == 1:
                emit(chunk)
            # Never expose stderr; tool failures may include sensitive content.
    finally:
        response.close()
        conn.close()
    state = docker_json("GET", "/exec/" + exec_id + "/json")
    if state.get("Running") or state.get("ExitCode") != 0:
        raise RuntimeError("Export command failed; native entrypoint must be checked")

def capture(row, command):
    parts = []
    execute(row, command, parts.append)
    return b"".join(parts)

def metadata():
    countly = container("srv-captain--countly")
    roundy = container("srv-captain--roundy")
    def image(row):
        info = docker_json("GET", "/images/" + row["ImageID"] + "/json")
        return {"id": info["Id"], "digests": info.get("RepoDigests", [])}
    return {
        "countly_image": image(countly), "roundy_image": image(roundy),
        "mongod_version": capture(countly, ["/usr/bin/mongod", "--version"]).decode("utf-8"),
        "nodejs_version": capture(countly, ["/usr/bin/nodejs", "--version"]).decode("utf-8"),
        "roundy_sha256": {name: hashlib.sha256(capture(roundy, ["cat", "/usr/src/app/" + name])).hexdigest()
                          for name in ("package.json", "yarn.lock")}}

class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    def log_message(self, *args):
        pass
    def do_GET(self):
        if not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + os.environ["EXPORT_TOKEN"]):
            self.send_error(403)
            return
        routes = {
            "/countly.archive.gz": ("srv-captain--countly", ["/usr/bin/mongodump", "--archive", "--gzip"]),
            "/roundy-source.tar.gz": ("srv-captain--roundy", ["tar", "-C", "/usr/src/app", "-czf", "-", "src", "package.json", "yarn.lock", "Dockerfile", "certs"])}
        started = False
        try:
            if self.path == "/metadata.json":
                payload = json.dumps(metadata()).encode()
                self.send_response(200)
                self.send_header("Content-Length", str(len(payload)))
                self.end_headers()
                self.wfile.write(payload)
            elif self.path in routes:
                service, command = routes[self.path]
                row = container(service)
                self.send_response(200)
                self.send_header("Transfer-Encoding", "chunked")
                self.end_headers()
                started = True
                def emit(chunk):
                    self.wfile.write(("%x\r\n" % len(chunk)).encode() + chunk + b"\r\n")
                execute(row, command, emit)
                self.wfile.write(b"0\r\n\r\n")
            else:
                self.send_error(404)
        except Exception:
            if not started:
                self.send_error(500, "Export failed; check native entrypoints")
            self.close_connection = True

HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
'''


class ExportError(Exception):
    pass


def api(route, payload, token=None):
    headers = {"Content-Type": "application/json", "x-namespace": "captain"}
    if token:
        headers["x-captain-auth"] = token
    body = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(API + route, body, headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            result = json.load(response)
    except (urllib.error.URLError, ValueError) as error:
        raise ExportError("CapRover API request failed: " + route) from error
    if not isinstance(result, dict) or result.get("status") != 100:
        raise ExportError("CapRover rejected request: " + route)
    return result.get("data")


def export_request(name, token):
    return urllib.request.Request(EXPORT_URL + "/" + name, headers={"Authorization": "Bearer " + token})


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise ExportError("Export redirect refused")


def download(opener, name, token, output):
    path = output / name
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "wb") as target, opener.open(export_request(name, token), timeout=3600) as response:
            while chunk := response.read(65536):
                target.write(chunk)
        if name.endswith(".gz"):
            with gzip.open(path, "rb") as archive:
                while archive.read(65536):
                    pass
        return path
    except Exception:
        path.unlink(missing_ok=True)
        raise


def run(args):
    output = Path(args.output_dir)
    output.mkdir(mode=0o700, parents=False, exist_ok=True)
    if not output.is_dir() or output.stat().st_mode & 0o077:
        raise ExportError("Output directory must be private (mode 0700)")
    password = Path(args.password_file).read_text().rstrip("\r\n")
    login = api("/login", {"password": password})
    del password
    if not isinstance(login, dict) or not isinstance(login.get("token"), str):
        raise ExportError("Invalid login response")
    auth = login["token"]
    route = "/user/apps/appDefinitions"
    definitions = api(route, None, auth)
    if not isinstance(definitions, dict) or not isinstance(definitions.get("appDefinitions"), list):
        raise ExportError("Invalid app definitions response")
    if any(app.get("appName") == APP for app in definitions["appDefinitions"]):
        raise ExportError("migration-export already exists; refusing to modify or delete it")
    created = False
    try:
        api(route + "/register", {"appName": APP, "hasPersistentData": False}, auth)
        created = True
        definitions = api(route, None, auth)
        own = [app for app in definitions["appDefinitions"] if app.get("appName") == APP]
        if len(own) != 1:
            raise ExportError("Helper definition missing after registration")
        token = secrets.token_hex(32)
        update = dict(own[0])
        update.update({"appName": APP, "notExposeAsWebApp": False, "containerHttpPort": 8080,
                       "envVars": [{"key": "EXPORT_TOKEN", "value": token}],
                       "volumes": [], "serviceUpdateOverride": json.dumps({
                           "TaskTemplate": {"ContainerSpec": {
                               "Image": "python:3.13-alpine", "Command": ["python3"],
                               "Args": ["-u", "-c", HELPER_SOURCE], "ReadOnly": True,
                               "Mounts": [{"Type": "bind", "Source": "/var/run/docker.sock",
                                           "Target": "/var/run/docker.sock", "ReadOnly": True}]},
                               "Resources": {"Limits": {"MemoryBytes": 128 * 1024 * 1024, "NanoCPUs": 200000000}},
                               "RestartPolicy": {"Condition": "none"}}})})
        api(route + "/update", update, auth)
        # Probe only the unauthenticated rejection over HTTP: no bearer or data.
        readiness = urllib.request.build_opener(NoRedirect())
        deadline = time.monotonic() + 180
        while True:
            try:
                with readiness.open("http://migration-export.donatebot.app/metadata.json", timeout=10):
                    raise ExportError("Helper unexpectedly accepted unauthenticated request")
            except urllib.error.HTTPError as error:
                status = error.code
                error.close()
                if status == 403:
                    break
            except (urllib.error.URLError, TimeoutError):
                pass
            if time.monotonic() >= deadline:
                raise ExportError("Helper route did not become ready")
            time.sleep(3)
        api(route + "/enablebasedomainssl", {"appName": APP}, auth)
        opener = urllib.request.build_opener(NoRedirect(), urllib.request.HTTPSHandler(context=ssl.create_default_context()))
        deadline = time.monotonic() + 180
        while True:
            try:
                with opener.open(export_request("metadata.json", token), timeout=15) as response:
                    metadata = json.load(response)
                if not isinstance(metadata, dict) or set(metadata) != {
                    "countly_image", "roundy_image", "mongod_version", "nodejs_version", "roundy_sha256"
                }:
                    raise ExportError("Invalid helper metadata response")
                break
            except (urllib.error.URLError, TimeoutError):
                if time.monotonic() >= deadline:
                    raise ExportError("Helper HTTPS route did not become ready") from None
                time.sleep(3)
        # Metadata readiness probes are deliberately small; archives are streamed once.
        path = output / "metadata.json"
        with os.fdopen(os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600), "w") as target:
            json.dump(metadata, target, indent=2)
            target.write("\n")
        paths = [path]
        if not args.metadata_only:
            paths += [download(opener, name, token, output) for name in ("countly.archive.gz", "roundy-source.tar.gz")]
        print(json.dumps(metadata, indent=2))
        for path in paths:
            print(f"{path.name}: {path.stat().st_size} bytes")
    finally:
        if created:
            api(route + "/delete", {"appName": APP, "volumes": []}, auth)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--password-file", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--metadata-only", action="store_true")
    args = parser.parse_args()
    try:
        run(args)
    except ExportError as error:
        print(str(error), file=sys.stderr)
        return 1
    except Exception:
        # Do not print remote bodies, URLs carrying credentials, or exception data.
        print("Export failed; helper cleanup was attempted if registered. Check API/entrypoints and helper existence before retrying.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
