#!/usr/bin/env python3
"""Ensure OwnLoom is reachable directly over NetBird for admin peers.

Requires a NetBird personal/service access token in NETBIRD_TOKEN or
NETBIRD_API_TOKEN. The script is intentionally narrow: it only creates the
admins -> ownloom-core TCP/80 policy and verifies/repairs the nazar.studio
custom DNS zone record for ownloom.nazar.studio.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
from typing import Any

API = os.environ.get("NETBIRD_API_URL", "https://api.netbird.io/api").rstrip("/")
DEFAULT_TOKEN_FILE = "/root/.nazar-secrets/netbird-api-token"


def load_token() -> str | None:
    token = os.environ.get("NETBIRD_TOKEN") or os.environ.get("NETBIRD_API_TOKEN")
    if token:
        return token

    token_file = os.environ.get("NETBIRD_TOKEN_FILE", DEFAULT_TOKEN_FILE)
    try:
        st = os.stat(token_file)
    except FileNotFoundError:
        return None

    if st.st_mode & 0o077:
        die(f"refusing to read {token_file}: permissions must be 0600 or stricter")
    with open(token_file, "r", encoding="utf-8") as fh:
        return fh.read().strip()


TOKEN = load_token()

POLICY_NAME = "admins-to-ownloom-web"
ZONE_DOMAIN = "nazar.studio"
OWNLOOM_FQDN = "ownloom.nazar.studio"
OWNLOOM_NETBIRD_IP = "100.124.202.128"


def die(message: str) -> None:
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def request(method: str, path: str, body: dict[str, Any] | None = None) -> Any:
    if not TOKEN:
        die(f"set NETBIRD_TOKEN/NETBIRD_API_TOKEN or store the token in {DEFAULT_TOKEN_FILE}")
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={
            "Accept": "application/json",
            "Authorization": f"Token {TOKEN}",
            **({"Content-Type": "application/json"} if body is not None else {}),
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        die(f"{method} {path} failed with HTTP {exc.code}: {detail}")
    except urllib.error.URLError as exc:
        die(f"{method} {path} failed: {exc}")


def as_list(value: Any) -> list[Any]:
    if isinstance(value, list):
        return value
    if isinstance(value, dict):
        for key in ("items", "groups", "policies", "records", "zones"):
            if isinstance(value.get(key), list):
                return value[key]
    return []


def groups_by_name() -> dict[str, dict[str, Any]]:
    groups = as_list(request("GET", "/groups"))
    return {g.get("name"): g for g in groups if isinstance(g, dict) and g.get("name")}


def ensure_policy(groups: dict[str, dict[str, Any]]) -> None:
    admins = groups.get("admins") or die("missing NetBird group: admins")
    ownloom = groups.get("ownloom-core") or die("missing NetBird group: ownloom-core")

    policies = as_list(request("GET", "/policies"))
    existing = next((p for p in policies if isinstance(p, dict) and p.get("name") == POLICY_NAME), None)
    if existing:
        print(f"policy exists: {POLICY_NAME} ({existing.get('id')})")
        return

    created = request(
        "POST",
        "/policies",
        {
            "name": POLICY_NAME,
            "description": "Allow admin browser clients to reach the OwnLoom private web UI directly over NetBird. Shell access remains via nazar.",
            "enabled": True,
            "source_posture_checks": [],
            "rules": [
                {
                    "name": "ownloom-web-http",
                    "description": "OwnLoom nginx/web app and /zellij/ via HTTP inside NetBird",
                    "enabled": True,
                    "action": "accept",
                    "bidirectional": False,
                    "protocol": "tcp",
                    "ports": ["80"],
                    "sources": [admins["id"]],
                    "destinations": [ownloom["id"]],
                }
            ],
        },
    )
    print(f"created policy: {POLICY_NAME} ({created.get('id') if isinstance(created, dict) else 'ok'})")


def ensure_zone_distribution(zone: dict[str, Any], group_ids: list[str]) -> dict[str, Any]:
    current = list(zone.get("distribution_groups") or [])
    wanted = list(dict.fromkeys(current + group_ids))
    if wanted == current:
        print(f"zone distribution ok: {ZONE_DOMAIN}")
        return zone

    body = {
        "name": zone.get("name") or ZONE_DOMAIN,
        "domain": zone.get("domain") or ZONE_DOMAIN,
        "enabled": zone.get("enabled", True),
        "enable_search_domain": zone.get("enable_search_domain", False),
        "distribution_groups": wanted,
    }
    updated = request("PUT", f"/dns/zones/{zone['id']}", body)
    print(f"updated zone distribution: {ZONE_DOMAIN}")
    return updated if isinstance(updated, dict) else zone


def ensure_dns(groups: dict[str, dict[str, Any]]) -> None:
    zones = as_list(request("GET", "/dns/zones"))
    zone = next((z for z in zones if isinstance(z, dict) and z.get("domain") == ZONE_DOMAIN), None)

    distribution_names = ["admins", "proxmox-hosts", "vms"]
    distribution_ids = []
    for name in distribution_names:
        group = groups.get(name) or die(f"missing NetBird group for DNS distribution: {name}")
        distribution_ids.append(group["id"])

    if not zone:
        zone = request(
            "POST",
            "/dns/zones",
            {
                "name": ZONE_DOMAIN,
                "domain": ZONE_DOMAIN,
                "enabled": True,
                "enable_search_domain": False,
                "distribution_groups": distribution_ids,
            },
        )
        if not isinstance(zone, dict) or not zone.get("id"):
            die("failed to create DNS zone")
        print(f"created DNS zone: {ZONE_DOMAIN} ({zone['id']})")
    else:
        zone = ensure_zone_distribution(zone, distribution_ids)

    records = as_list(request("GET", f"/dns/zones/{zone['id']}/records"))
    record = next((r for r in records if isinstance(r, dict) and r.get("name") == OWNLOOM_FQDN), None)
    body = {"name": OWNLOOM_FQDN, "type": "A", "content": OWNLOOM_NETBIRD_IP, "ttl": 300}

    if not record:
        created = request("POST", f"/dns/zones/{zone['id']}/records", body)
        print(f"created DNS record: {OWNLOOM_FQDN} -> {OWNLOOM_NETBIRD_IP} ({created.get('id') if isinstance(created, dict) else 'ok'})")
    elif record.get("type") != "A" or record.get("content") != OWNLOOM_NETBIRD_IP:
        request("PUT", f"/dns/zones/{zone['id']}/records/{record['id']}", body)
        print(f"updated DNS record: {OWNLOOM_FQDN} -> {OWNLOOM_NETBIRD_IP}")
    else:
        print(f"DNS record ok: {OWNLOOM_FQDN} -> {OWNLOOM_NETBIRD_IP}")


def main() -> None:
    groups = groups_by_name()
    ensure_policy(groups)
    ensure_dns(groups)
    print("done: OwnLoom direct NetBird web access is configured for admins")


if __name__ == "__main__":
    main()
