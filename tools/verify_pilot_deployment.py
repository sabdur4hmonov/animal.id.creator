"""Synthetic-only production-configuration proof. Fixed project, loopback ports and private fixture."""

import hashlib
import ipaddress
import json
import re
import secrets
import ssl
import subprocess
import time
from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

import cv2
import httpx
import numpy as np
from init_pilot_secrets import initialize

ROOT = Path(__file__).resolve().parents[1]
FIXTURE = ROOT / "data/verification-prod-20261112"
PROJECT = "chorvam-prodverify-20261112"
COMPOSE = ROOT / "backend/docker-compose.prod.yml"
ENV = FIXTURE / ".env"
ORIGIN = "https://localhost:18443"


def run(*command, input_text=None):
    result = subprocess.run(
        command,
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=900,
        check=False,
        input=input_text,
    )
    if result.returncode:
        (ROOT / "data/dev/prod-command-failure.log").write_text(
            result.stdout + "\n" + result.stderr, "utf-8"
        )
        raise RuntimeError(
            "Dedicated test command failed; inspect data/dev/prod-command-failure.log"
        )
    return result.stdout


def compose(*args, input_text=None):
    return run(
        "docker",
        "compose",
        "-p",
        PROJECT,
        "-f",
        str(COMPOSE),
        "--env-file",
        str(ENV),
        *args,
        input_text=input_text,
    )


def prepare():
    FIXTURE.mkdir(parents=True, exist_ok=True)
    marker = FIXTURE / "VERIFICATION_ONLY"
    if not marker.is_file():
        if any(FIXTURE.iterdir()):
            raise ValueError("Unknown fixture directory preserved; nothing started")
        marker.write_text("Synthetic isolated verification only.", "utf-8")
    private = FIXTURE / "secrets"
    if not private.exists():
        initialize(private, "SYNTHETIC")
    (FIXTURE / "storage").mkdir(exist_ok=True)
    if not ENV.exists():
        ids = run("docker", "network", "ls", "-q").split()
        networks = json.loads(run("docker", "network", "inspect", *ids)) if ids else []
        occupied = [
            ipaddress.ip_network(c["Subnet"])
            for n in networks
            for c in ((n.get("IPAM") or {}).get("Config") or [])
            if c.get("Subnet")
        ]
        subnet = next(
            ipaddress.ip_network(f"172.30.{number}.0/24")
            for number in range(42, 62)
            if not any(
                ipaddress.ip_network(f"172.30.{number}.0/24").overlaps(existing)
                for existing in occupied
                if existing.version == 4
            )
        )
        fields = {
            "CHORVAM_DOMAIN": "localhost",
            "PUBLIC_ORIGIN": ORIGIN,
            "PILOT_STORAGE_ROOT": str(FIXTURE / "storage"),
            "PILOT_SECRETS_ROOT": str(private),
            "PILOT_TLS_SNIPPET": str(ROOT / "backend/deploy/tls-local.caddy"),
            "PILOT_HTTP_BIND": "127.0.0.1:18480",
            "PILOT_HTTPS_BIND": "127.0.0.1:18443",
            "PILOT_NETWORK_SUBNET": str(subnet),
            "PILOT_PROXY_IP": str(subnet.network_address + 10),
            "PILOT_RUNTIME_IMAGE": "chorvam-verified-cpu:20261111",
        }
        with ENV.open("x", encoding="utf-8") as stream:
            stream.write(
                "\n".join(
                    k + "=" + json.dumps(v.replace("\\", "/"))
                    for k, v in fields.items()
                )
                + "\n"
            )
    config = json.loads(compose("config", "--format", "json"))
    services = config["services"]
    assert services["api"]["environment"]["PUBLIC_ORIGIN"] == ORIGIN
    assert not services["api"].get("ports") and not services["db"].get("ports")
    assert {
        (str(p["published"]), p["host_ip"]) for p in services["proxy"]["ports"]
    } == {("18443", "127.0.0.1"), ("18480", "127.0.0.1")}
    mounts = [m for m in services["api"]["volumes"] if m["target"] == "/srv/data"]
    assert (
        len(mounts) == 1
        and Path(mounts[0]["source"]).resolve() == (FIXTURE / "storage").resolve()
    )
    assert all(
        Path(s["file"]).resolve().is_relative_to(private.resolve())
        for s in config["secrets"].values()
    )
    print("Starting only the fixed synthetic prod-verification project.", flush=True)
    compose("up", "-d", "--build")
    ca = FIXTURE / "test-ca.crt"
    for _ in range(30):
        try:
            compose("cp", "proxy:/data/caddy/pki/authorities/local/root.crt", str(ca))
            context = ssl.create_default_context(cafile=str(ca))
            if (
                httpx.get(ORIGIN + "/health", verify=context, timeout=3).status_code
                == 200
            ):
                return context
        except (RuntimeError, httpx.TransportError, ssl.SSLError):
            time.sleep(1)
    raise RuntimeError("Dedicated HTTPS fixture did not become ready")


def password_user(role):
    suffix = uuid4().hex[:12]
    username = "synthetic-" + suffix
    password = secrets.token_urlsafe(24)
    filename = "password-" + suffix + ".txt"
    with (FIXTURE / "secrets" / filename).open("x", encoding="utf-8") as stream:
        stream.write(password)
    code = (
        "import os,sys; f=os.fdopen(os.open('/tmp/"
        + filename
        + "',os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600),'w'); f.write(sys.stdin.read()); f.close()"
    )
    compose("exec", "-T", "api", "python", "-c", code, input_text=password)
    compose(
        "exec",
        "-T",
        "api",
        "python",
        "/srv/tools/manage_users.py",
        "create",
        "--username",
        username,
        "--operator-id",
        "SYNTHETIC-" + suffix.upper(),
        "--role",
        role,
        "--actor",
        "SYNTHETIC-CLI",
        "--password-file",
        "/tmp/" + filename,
    )
    return username, password


def verify(context):
    private = json.loads((FIXTURE / "secrets/tokens.json").read_text("utf-8"))
    with httpx.Client(
        base_url=ORIGIN,
        verify=context,
        timeout=60,
        headers={"Authorization": "Bearer " + private["operator"]["token"]},
    ) as client:
        redirect = httpx.get(
            "http://localhost:18480/panel/login?lang=ru",
            follow_redirects=False,
            timeout=10,
        )
        assert (
            redirect.status_code == 308
            and redirect.headers["location"] == ORIGIN + "/panel/login?lang=ru"
        )
        issued = client.post(
            "/api/v1/registry/animals",
            json={
                "species": "cattle",
                "owner": {"owner_id": "SYNTHETIC", "name": "PRIVATE SYNTHETIC OWNER"},
            },
            headers={"Idempotency-Key": uuid4().hex},
        )
        assert issued.status_code == 201, issued.status_code
        label = issued.json()["animal_id"]
        metadata = {
            "animal_id": label,
            "species": "cattle",
            "operator_id": private["operator"]["operator_id"],
            "timestamp": datetime.now(UTC).isoformat(),
            "gps": None,
        }
        image = cv2.imencode(
            ".jpg",
            np.random.default_rng(17).integers(50, 201, (480, 640, 3), dtype=np.uint8),
        )[1].tobytes()
        key = uuid4().hex
        send = lambda: client.post(
            "/api/v1/captures",
            files={"image": ("SYNTHETIC.jpg", image, "image/jpeg")},
            data={"metadata": json.dumps(metadata)},
            headers={"Idempotency-Key": key},
        )
        saved = send()
        assert saved.status_code == 201, saved.text
        capture = saved.json()
        assert capture["crop_status"] == "pending_model" and send().json() == capture
        original = FIXTURE / "storage" / capture["file_path"]
        assert (
            hashlib.sha256(original.read_bytes()).hexdigest()
            == capture["stored_sha256"]
        )
        root = f"/api/v1/registry/animals/cattle/{label}"
        username, password = password_user("veterinar")
        with httpx.Client(base_url=ORIGIN, verify=context, timeout=60) as portal:
            response = portal.post(
                "/panel/login",
                json={"username": username, "password": password},
                headers={"X-Chorvam-Login": "1", "Origin": ORIGIN},
            )
            assert (
                response.status_code == 200
                and "Secure" in response.headers["set-cookie"]
            )
            profile = portal.get("/panel")
            assert profile.status_code == 200 and "veterinar" in profile.text
            assert "__Host-chorvam=" in profile.request.headers.get("cookie", "")
            csrf = re.search(r'name="csrf-token" content="([^"]+)"', profile.text)[1]
            body = {
                "local_event_key": uuid4().hex,
                "kind": "examination",
                "event_date": datetime.now(UTC).date().isoformat(),
                "description": "SYNTHETIC HTTPS CHECK",
            }
            assert (
                portal.post(
                    root + "/health",
                    json=body,
                    headers={"Idempotency-Key": uuid4().hex},
                ).status_code
                == 403
            )
            event = portal.post(
                root + "/health",
                json=body,
                headers={"Idempotency-Key": uuid4().hex, "X-CSRF-Token": csrf},
            )
            assert (
                event.status_code == 201
                and event.json()["verified_by_veterinarian"] is True
            )
            assert portal.get("/panel/photos/" + capture["id"]).status_code == 200
        retired = client.post(
            root + "/retirement",
            json={
                "expected_version": 1,
                "observed_at": datetime.now(UTC).isoformat(),
                "reason": "PRIVATE SYNTHETIC REASON",
                "lifecycle": "slaughtered",
                "facility_id": "SYNTHETIC-FACILITY",
            },
            headers={"Idempotency-Key": uuid4().hex},
        )
        assert retired.status_code == 200, retired.status_code
        qr = client.post(
            root + "/verification-codes",
            json={},
            headers={"Idempotency-Key": uuid4().hex},
        )
        assert qr.status_code == 201, qr.status_code
        code = qr.json()
        page = httpx.get(code["url"], verify=context, timeout=15)
        assert page.status_code == 200 and label in page.text
        assert (
            "PRIVATE SYNTHETIC OWNER" not in page.text
            and "PRIVATE SYNTHETIC REASON" not in page.text
        )
        token = code["url"].rsplit("/", 1)[1]
        logs = compose("logs", "--no-color", "--tail", "500", "api", "proxy")
        assert token not in logs and password not in logs
        assert private["operator"]["token"] not in logs
        return {
            "animal_id": label,
            "capture_id": capture["id"],
            "verified_ca_and_hostname": True,
            "https_password_cookie_roundtrip": True,
            "csrf_rejected_then_vet_write": True,
            "private_photo": True,
            "upload_replay_and_stored_hash": True,
            "pending_model": True,
            "public_qr_private_fields_absent": True,
            "qr_and_credentials_absent_from_access_logs": True,
            "normal_stacks_changed": False,
            "synthetic_only": True,
        }


def main():
    context = prepare()
    evidence = verify(context)
    evidence.update(project=PROJECT, verified_at=datetime.now(UTC).isoformat())
    output = FIXTURE / ("evidence-https-" + uuid4().hex + ".json")
    output.write_text(json.dumps(evidence, indent=2), "utf-8")
    print("Synthetic HTTPS proof passed; " + str(output), flush=True)


if __name__ == "__main__":
    main()
