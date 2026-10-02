"""Small, read-only Hermes worker for the Mac mini pilot.

It polls Supabase through the REST API, atomically claims one agent job, runs
the configured Hermes profile, and stores the response. The worker intentionally
does not expose an HTTP port and does not enable Hermes terminal/browser tools.
"""

from __future__ import annotations

import json
import os
import socket
import subprocess
import time
import traceback
from datetime import datetime, timezone
from typing import Any

import requests


SUPABASE_URL = os.environ["SUPABASE_URL"].rstrip("/")
SUPABASE_SECRET_KEY = os.environ.get("SUPABASE_SECRET_KEY") or os.environ[
    "SUPABASE_SERVICE_ROLE_KEY"
]
POLL_SECONDS = float(os.environ.get("POLL_SECONDS", "3"))
WORKER_NAME = os.environ.get("WORKER_NAME", f"mac-mini-{socket.gethostname()}")
HERMES_PROFILE_HOME = os.path.expanduser(
    os.environ.get("HERMES_PROFILE_HOME", "~/.hermes/profiles/rumar")
)
HERMES_COMMAND = os.path.expanduser(
    os.environ.get("HERMES_COMMAND", "~/.local/bin/rumar")
)
HERMES_TIMEOUT_SECONDS = int(os.environ.get("HERMES_TIMEOUT_SECONDS", "90"))


def headers() -> dict[str, str]:
    result = {
        "apikey": SUPABASE_SECRET_KEY,
        "Content-Type": "application/json",
    }
    # Legacy service_role keys are JWTs. New sb_secret_ keys belong only in
    # apikey; sending them as Bearer tokens causes authentication failures.
    if SUPABASE_SECRET_KEY.startswith("eyJ"):
        result["Authorization"] = f"Bearer {SUPABASE_SECRET_KEY}"
    return result


def claim_job() -> dict[str, Any] | None:
    response = requests.post(
        f"{SUPABASE_URL}/rest/v1/rpc/claim_next_agent_job",
        headers=headers(),
        json={"worker_name": WORKER_NAME},
        timeout=20,
    )
    response.raise_for_status()
    jobs = response.json()
    return jobs[0] if jobs else None


def update_job(job_id: str, values: dict[str, Any]) -> None:
    response = requests.patch(
        f"{SUPABASE_URL}/rest/v1/agent_jobs?id=eq.{job_id}",
        headers={**headers(), "Prefer": "return=minimal"},
        json=values,
        timeout=20,
    )
    response.raise_for_status()


def run_hermes(job: dict[str, Any]) -> str:
    payload = job.get("input") or {}
    prompt = json.dumps(payload, ensure_ascii=False)
    request = (
        "Processa esta tarefa interna da RUMAR em modo estritamente read-only. "
        "Não envies mensagens, não alteres agenda, não executes ações e não "
        "inventes dados. Se faltar informação, indica-a.\n\n"
        f"Tipo de tarefa: {job.get('kind')}\n"
        f"ID da tarefa: {job['id']}\n"
        f"Dados autenticados fornecidos pela aplicação: {prompt}"
    )

    environment = os.environ.copy()
    environment["HERMES_HOME"] = HERMES_PROFILE_HOME
    completed = subprocess.run(
        [HERMES_COMMAND, "-z", request],
        capture_output=True,
        check=False,
        env=environment,
        text=True,
        timeout=HERMES_TIMEOUT_SECONDS,
    )
    if completed.returncode != 0:
        detail = (completed.stderr or completed.stdout).strip()
        raise RuntimeError(f"Hermes terminou com código {completed.returncode}: {detail[:1200]}")

    output = completed.stdout.strip()
    if not output:
        raise RuntimeError("Hermes terminou sem devolver uma resposta")
    return output


def process(job: dict[str, Any]) -> None:
    job_id = job["id"]
    finished_at = datetime.now(timezone.utc).isoformat()
    try:
        output = run_hermes(job)
        update_job(job_id, {
            "status": "succeeded",
            "result": {"text": output, "runtime": "hermes", "worker": WORKER_NAME},
            "finished_at": finished_at,
        })
    except Exception as exc:  # keep the worker alive after one bad job
        traceback.print_exc()
        update_job(job_id, {
            "status": "failed",
            "error": f"{type(exc).__name__}: {exc}"[:2000],
            "finished_at": finished_at,
        })


def main() -> None:
    print(f"Hermes worker online: {WORKER_NAME}")
    while True:
        try:
            job = claim_job()
            if job:
                print(f"Processing {job['id']} ({job['kind']})")
                process(job)
            else:
                time.sleep(POLL_SECONDS)
        except KeyboardInterrupt:
            print("Hermes worker stopped")
            return
        except Exception:
            traceback.print_exc()
            time.sleep(min(POLL_SECONDS * 4, 30))


if __name__ == "__main__":
    main()
