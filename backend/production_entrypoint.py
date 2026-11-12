"""Fail closed on missing secret/proxy configuration before starting the pilot API."""

import ipaddress
import os
import subprocess
from pathlib import Path
from urllib.parse import urlsplit


def configure(environment):
    location = environment.get("DATABASE_URL_FILE", "")
    if not location:
        raise ValueError("Mount DATABASE_URL_FILE; production has no fallback password")
    value = Path(location).read_text("utf-8").strip()
    parsed = urlsplit(value)
    if (
        parsed.scheme != "postgresql+psycopg"
        or parsed.hostname != "db"
        or parsed.path != "/biolivestock"
        or not parsed.password
        or parsed.username != "biolivestock"
        or parsed.port != 5432
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("Expected the private pilot PostgreSQL service secret")
    proxy = environment.get("FORWARDED_ALLOW_IPS", "")
    public = urlsplit(environment.get("PUBLIC_ORIGIN", ""))
    if (
        public.scheme != "https"
        or not public.hostname
        or public.username
        or public.password
        or public.query
        or public.fragment
        or public.path not in ("", "/")
    ):
        raise ValueError("Set the canonical HTTPS PUBLIC_ORIGIN")
    if not proxy or not ipaddress.ip_address(proxy).is_private:
        raise ValueError("Set the one private reverse-proxy IP; wildcard forwarding is forbidden")
    environment.pop("DATABASE_URL", None)
    return proxy


def main():
    proxy = configure(os.environ)
    subprocess.run(["alembic", "upgrade", "head"], check=True)
    os.execvp(
        "uvicorn",
        [
            "uvicorn",
            "app.main:app",
            "--host",
            "0.0.0.0",
            "--port",
            "8000",
            "--proxy-headers",
            "--forwarded-allow-ips",
            proxy,
            "--no-access-log",
        ],
    )


if __name__ == "__main__":
    main()
