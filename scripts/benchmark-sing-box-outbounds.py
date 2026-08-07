#!/usr/bin/env python3
"""Benchmark sing-box outbounds through isolated local SOCKS listeners.

The input may be plain JSON or an age-encrypted file. Results contain tags and
measurements only; outbound credentials are kept in a mode-0700 temporary dir.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import json
import os
import re
import socket
import statistics
import subprocess
import sys
import tempfile
import time
import urllib.parse
from pathlib import Path
from typing import Any


PROFILES = {
    "quick": {"latency_runs": 3, "download_mb": 5, "upload_mb": 2, "transfer_runs": 1, "fast_streams": 2},
    "standard": {"latency_runs": 7, "download_mb": 25, "upload_mb": 10, "transfer_runs": 2, "fast_streams": 4},
    "deep": {"latency_runs": 15, "download_mb": 100, "upload_mb": 50, "transfer_runs": 3, "fast_streams": 8},
}

WEB_URLS = [
    "https://www.google.com/generate_204",
    "https://github.com/",
    "https://www.wikipedia.org/",
    "https://www.youtube.com/",
]


def run(command: list[str], **kwargs: Any) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, text=True, check=False, **kwargs)


def load_outbounds(path: Path, identity: str | None) -> list[dict[str, Any]]:
    data = path.read_bytes()
    if data.startswith(b"age-encryption.org/"):
        command = ["age", "--decrypt"]
        if identity:
            command += ["--identity", os.path.expanduser(identity)]
        command.append(str(path))
        result = subprocess.run(command, capture_output=True, check=False)
        if result.returncode:
            sys.stderr.write(result.stderr.decode(errors="replace"))
            raise SystemExit("could not decrypt the outbounds file")
        data = result.stdout
    try:
        value = json.loads(data)
    except json.JSONDecodeError as error:
        raise SystemExit(f"invalid outbound JSON: {error}") from error
    if not isinstance(value, list):
        raise SystemExit("outbounds file must contain a JSON array")
    return value


def free_port() -> int:
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def median(values: list[float]) -> float | None:
    return round(statistics.median(values), 2) if values else None


def curl(proxy: str, url: str, *, method: str = "GET", upload: Path | None = None, timeout: int = 90) -> dict[str, Any]:
    marker = "__BENCHMARK__"
    command = [
        "curl", "--silent", "--show-error", "--location", "--proxy", proxy,
        "--noproxy", "", "--max-time", str(timeout), "--output", os.devnull,
        "--write-out", marker + "%{http_code}\t%{time_starttransfer}\t%{time_total}\t%{size_download}\t%{size_upload}\t%{speed_download}\t%{speed_upload}",
    ]
    if method == "POST":
        command += ["--request", "POST", "--header", "Content-Type: application/octet-stream"]
    if upload:
        command += ["--data-binary", f"@{upload}"]
    command.append(url)
    started = time.monotonic()
    result = run(command, capture_output=True)
    elapsed = time.monotonic() - started
    if marker not in result.stdout:
        return {"ok": False, "error": result.stderr.strip() or f"curl exit {result.returncode}", "wall_s": elapsed}
    fields = result.stdout.rsplit(marker, 1)[1].split("\t")
    try:
        code, ttfb, total, downloaded, uploaded, down_bps, up_bps = fields
        return {
            "ok": result.returncode == 0 and 200 <= int(code) < 400,
            "http": int(code), "ttfb_ms": float(ttfb) * 1000, "total_s": float(total),
            "download_bytes": int(float(downloaded)), "upload_bytes": int(float(uploaded)),
            "download_mbps": float(down_bps) * 8 / 1_000_000,
            "upload_mbps": float(up_bps) * 8 / 1_000_000,
            "error": result.stderr.strip() or None,
        }
    except (ValueError, TypeError) as error:
        return {"ok": False, "error": f"could not parse curl output: {error}"}


def curl_text(proxy: str, url: str, timeout: int = 30) -> str:
    result = run([
        "curl", "--fail", "--silent", "--show-error", "--location", "--proxy", proxy,
        "--noproxy", "", "--max-time", str(timeout), url,
    ], capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or f"curl exit {result.returncode}")
    return result.stdout


def wait_for_socks(process: subprocess.Popen[Any], port: int) -> None:
    deadline = time.monotonic() + 8
    while time.monotonic() < deadline:
        if process.poll() is not None:
            raise RuntimeError("sing-box exited before opening its SOCKS listener")
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=0.1):
                return
        except OSError:
            time.sleep(0.05)
    raise RuntimeError("timed out waiting for the sing-box SOCKS listener")


def start_sing_box(binary: str, outbound: dict[str, Any], directory: Path) -> tuple[subprocess.Popen[Any], str]:
    port = free_port()
    selected = dict(outbound)
    selected["tag"] = "benchmark-out"
    config = {
        "log": {"disabled": True},
        "inbounds": [{"type": "socks", "tag": "benchmark-in", "listen": "127.0.0.1", "listen_port": port}],
        "outbounds": [selected],
        "route": {"final": "benchmark-out", "auto_detect_interface": True},
    }
    config_path = directory / "config.json"
    config_path.write_text(json.dumps(config), encoding="utf-8")
    config_path.chmod(0o600)
    process = subprocess.Popen([binary, "run", "--config", str(config_path)], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    wait_for_socks(process, port)
    return process, f"socks5h://127.0.0.1:{port}"


def fast_targets(proxy: str, count: int) -> list[str]:
    page = curl_text(proxy, "https://fast.com/")
    scripts = re.findall(r'<script[^>]+src=["\']([^"\']+)', page)
    for source in reversed(scripts):
        script_url = urllib.parse.urljoin("https://fast.com/", source)
        script = curl_text(proxy, script_url)
        match = re.search(r'token\s*:\s*["\']([^"\']+)', script)
        if not match:
            continue
        api = "https://api.fast.com/netflix/speedtest/v2?" + urllib.parse.urlencode({
            "https": "true", "token": match.group(1), "urlCount": count,
        })
        payload = json.loads(curl_text(proxy, api))
        return [target["url"] for target in payload.get("targets", [])][:count]
    raise RuntimeError("could not find the current Fast.com API token")


def test_fast(proxy: str, streams: int) -> dict[str, Any]:
    try:
        targets = fast_targets(proxy, streams)
        if not targets:
            raise RuntimeError("Fast.com returned no targets")
        started = time.monotonic()
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(targets)) as pool:
            results = list(pool.map(lambda url: curl(proxy, url, timeout=120), targets))
        elapsed = time.monotonic() - started
        downloaded = sum(result.get("download_bytes", 0) for result in results if result.get("ok"))
        return {
            "ok": all(result.get("ok") for result in results), "streams": len(targets),
            "download_mb": round(downloaded / 1_000_000, 2),
            "download_mbps": round(downloaded * 8 / elapsed / 1_000_000, 2) if elapsed else 0,
            "seconds": round(elapsed, 2),
        }
    except Exception as error:
        return {"ok": False, "error": str(error)}


def speedtest_server(proxy: str) -> tuple[str, str]:
    payload = json.loads(curl_text(proxy, "https://www.speedtest.net/api/js/servers?engine=js&limit=10&https_functional=true"))
    if not payload:
        raise RuntimeError("Speedtest.net returned no servers")
    server = payload[0]
    base = server["url"].rsplit("/", 1)[0]
    label = f"{server.get('name', '?')}, {server.get('country', '?')} ({server.get('sponsor', '?')})"
    return base, label


def test_speedtest(proxy: str, payload: Path) -> dict[str, Any]:
    """Use the nearest Ookla server's HTTP endpoints through SOCKS.

    This is intentionally not the official adaptive Ookla CLI, which cannot use
    a SOCKS proxy without changing system routes.
    """
    try:
        base, label = speedtest_server(proxy)
        latency = [curl(proxy, f"{base}/latency.txt?x={index}", timeout=20) for index in range(3)]
        downloads = [curl(proxy, f"{base}/random4000x4000.jpg?x={index}", timeout=90) for index in range(3)]
        upload = curl(proxy, f"{base}/upload.php", method="POST", upload=payload, timeout=90)
        return {
            "ok": any(item.get("ok") for item in downloads) and upload.get("ok", False),
            "server": label,
            "latency_ms": median([item["ttfb_ms"] for item in latency if item.get("ok")]),
            "download_mbps": median([item["download_mbps"] for item in downloads if item.get("ok")]),
            "upload_mbps": round(upload.get("upload_mbps", 0), 2) if upload.get("ok") else None,
        }
    except Exception as error:
        return {"ok": False, "error": str(error)}


def benchmark(binary: str, outbound: dict[str, Any], settings: dict[str, int], root: Path) -> dict[str, Any]:
    tag = str(outbound.get("tag", "untagged"))
    result: dict[str, Any] = {"tag": tag, "type": outbound.get("type")}
    directory = root / str(abs(hash(tag)))
    directory.mkdir(mode=0o700)
    process: subprocess.Popen[Any] | None = None
    try:
        process, proxy = start_sing_box(binary, outbound, directory)
        exit_checks = [curl(proxy, "https://www.cloudflare.com/cdn-cgi/trace", timeout=20) for _ in range(3)]
        exit_check = next((check for check in exit_checks if check.get("ok")), exit_checks[-1])
        if not exit_check.get("ok"):
            raise RuntimeError(f"proxy connectivity failed three times: {exit_check.get('error') or exit_check.get('http')}")

        latency_results = [
            curl(proxy, f"https://speed.cloudflare.com/__down?bytes=0&run={index}", timeout=20)
            for index in range(settings["latency_runs"])
        ]
        result["latency"] = {
            "median_ttfb_ms": median([item["ttfb_ms"] for item in latency_results if item.get("ok")]),
            "successful_runs": sum(bool(item.get("ok")) for item in latency_results),
        }

        down_bytes = settings["download_mb"] * 1_000_000
        downloads = [
            curl(proxy, f"https://speed.cloudflare.com/__down?bytes={down_bytes}&run={index}", timeout=180)
            for index in range(settings["transfer_runs"])
        ]
        result["cloudflare_download_mbps"] = median([item["download_mbps"] for item in downloads if item.get("ok")])

        upload_path = root / "upload.bin"
        uploads = [
            curl(proxy, "https://speed.cloudflare.com/__up", method="POST", upload=upload_path, timeout=180)
            for _ in range(settings["transfer_runs"])
        ]
        result["cloudflare_upload_mbps"] = median([item["upload_mbps"] for item in uploads if item.get("ok")])

        pages = [curl(proxy, url, timeout=60) for url in WEB_URLS]
        result["web"] = {
            "median_ttfb_ms": median([item["ttfb_ms"] for item in pages if item.get("ok")]),
            "median_load_ms": median([item["total_s"] * 1000 for item in pages if item.get("ok")]),
            "successful_pages": sum(bool(item.get("ok")) for item in pages),
        }
        result["speedtest"] = test_speedtest(proxy, upload_path)
        result["fast_com"] = test_fast(proxy, settings["fast_streams"])
        result["ok"] = result["latency"]["successful_runs"] > 0
    except Exception as error:
        result.update({"ok": False, "error": str(error)})
    finally:
        if process:
            process.terminate()
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                process.kill()
    return result


def rank(results: list[dict[str, Any]]) -> list[dict[str, Any]]:
    good = [item for item in results if item.get("ok")]
    maxima = {
        key: max((float(item.get(key) or 0) for item in good), default=1)
        for key in ("cloudflare_download_mbps", "cloudflare_upload_mbps")
    }
    max_fast = max((float(item.get("fast_com", {}).get("download_mbps") or 0) for item in good if item.get("fast_com", {}).get("ok")), default=1)
    max_speedtest = max((float(item.get("speedtest", {}).get("download_mbps") or 0) for item in good if item.get("speedtest", {}).get("ok")), default=1)
    for item in good:
        latency = float(item.get("latency", {}).get("median_ttfb_ms") or 10_000)
        web = float(item.get("web", {}).get("median_load_ms") or 30_000)
        fast = float(item.get("fast_com", {}).get("download_mbps") or 0) if item.get("fast_com", {}).get("ok") else 0
        speedtest = float(item.get("speedtest", {}).get("download_mbps") or 0) if item.get("speedtest", {}).get("ok") else 0
        score = (
            25 * float(item.get("cloudflare_download_mbps") or 0) / maxima["cloudflare_download_mbps"]
            + 15 * float(item.get("cloudflare_upload_mbps") or 0) / maxima["cloudflare_upload_mbps"]
            + 20 * fast / max_fast
            + 15 * speedtest / max_speedtest
            + 15 * min(1, 100 / latency)
            + 10 * min(1, 1000 / web)
        )
        item["score"] = round(score, 2)
    return sorted(results, key=lambda item: (not item.get("ok"), -float(item.get("score", 0))))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file", type=Path, help="plain or age-encrypted sing-box outbounds JSON array")
    parser.add_argument("--identity", default="~/.ssh/id_ed25519", help="age identity (default: %(default)s)")
    parser.add_argument("--sing-box", default="sing-box", help="sing-box executable")
    parser.add_argument("--profile", choices=PROFILES, default="standard")
    parser.add_argument("--exclude", default="Россия", help="regex for tags to skip (default: %(default)s)")
    parser.add_argument("--include", help="only test tags matching this regex")
    parser.add_argument("--output", type=Path, help="write JSON results here as well as stdout")
    parser.add_argument("--random-order", action="store_true", help="shuffle test order to reduce time bias")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    outbounds = load_outbounds(args.file, args.identity)
    excluded = re.compile(args.exclude) if args.exclude else None
    included = re.compile(args.include) if args.include else None
    candidates = [
        item for item in outbounds
        if item.get("type") not in {"selector", "direct", "block", "dns"}
        and (not excluded or not excluded.search(str(item.get("tag", ""))))
        and (not included or included.search(str(item.get("tag", ""))))
    ]
    if args.random_order:
        import random
        random.SystemRandom().shuffle(candidates)
    if not candidates:
        raise SystemExit("no matching proxy outbounds")

    settings = PROFILES[args.profile]
    with tempfile.TemporaryDirectory(prefix="sing-box-benchmark-") as temporary:
        root = Path(temporary)
        root.chmod(0o700)
        upload = root / "upload.bin"
        with upload.open("wb") as file:
            file.truncate(settings["upload_mb"] * 1_000_000)
        results = []
        for index, outbound in enumerate(candidates, 1):
            print(f"[{index}/{len(candidates)}] {outbound.get('tag')}", file=sys.stderr, flush=True)
            results.append(benchmark(args.sing_box, outbound, settings, root))

    document = {
        "tested_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "profile": args.profile,
        "settings": settings,
        "notes": [
            "Latency is proxied HTTPS time-to-first-byte, not ICMP ping.",
            "Speedtest uses the nearest Ookla server HTTP endpoints, not the official CLI.",
            "Fast.com uses its current API and concurrent Netflix CDN targets.",
        ],
        "results": rank(results),
    }
    rendered = json.dumps(document, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.write_text(rendered, encoding="utf-8")
    print(rendered, end="")


if __name__ == "__main__":
    main()
