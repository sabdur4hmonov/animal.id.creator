"""Inject lost COMMIT acknowledgement on a real, isolated PostgreSQL capture."""

import argparse
import json
from pathlib import Path

from collection_storage import run

SCRIPT = r'''
import hashlib, json
from datetime import UTC, datetime
from uuid import uuid4
import cv2, numpy as np, psycopg
from sqlalchemy import func, select
from sqlalchemy.exc import OperationalError
from app.core.database import SessionLocal, engine
from app.core.settings import get_settings
from app.core.species import Species, load_species_configs
from app.core.security_config import load_security_configs
from app.models.capture import Capture
from app.models.upload_receipt import UploadReceipt
from app.models.business import Animal, AuditEvent, DuplicateCase
from app.schemas.capture import CaptureMetadata
from app.services.collection import collect_capture
from app.services.detection import NoseDetector
settings = get_settings()
key = uuid4().hex
metadata = CaptureMetadata(animal_id='ACK-' + key[:12], species='cattle',
    operator_id='audit-commit-probe', timestamp=datetime.now(UTC), gps=None)
image = np.random.default_rng(int(key[:8], 16)).integers(50,201,(480,640,3),dtype=np.uint8)
content = cv2.imencode('.jpg', image)[1].tobytes()
config = load_species_configs(settings.species_config_dir)[Species.cattle]
security = load_security_configs(settings.security_config_dir)[Species.cattle]
detector = NoseDetector(settings.model_root)
real_commit = engine.dialect.do_commit
def lost_ack(connection):
    real_commit(connection)
    raise psycopg.OperationalError('Synthetic lost COMMIT acknowledgement after real commit')
engine.dialect.do_commit = lost_ack
try:
    with SessionLocal() as session:
        try:
            collect_capture(content, metadata, config, detector, settings, session, security, key)
        except OperationalError:
            pass
        else:
            raise AssertionError('Fault was not injected')
finally:
    engine.dialect.do_commit = real_commit
with SessionLocal() as session:
    record = session.scalar(select(Capture).where(Capture.animal_id == metadata.animal_id))
    assert record is not None
    path = settings.storage_root / record.file_path
    assert path.is_file()
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record.stored_sha256
    result = collect_capture(content, metadata, config, detector, settings, session, security, key)
    assert result['id'] == record.id
    assert session.scalar(select(func.count()).select_from(Capture).where(Capture.animal_id == metadata.animal_id)) == 1
    assert session.scalar(select(func.count()).select_from(UploadReceipt).where(UploadReceipt.request_key == key)) == 1
    print(json.dumps({'synthetic':True, 'database':'postgresql',
        'fault':'lost COMMIT acknowledgement after real commit', 'capture_id':record.id,
        'file_path':record.file_path, 'stored_sha256':record.stored_sha256,
        'retry_same_capture':True, 'capture_count':1, 'receipt_count':1, 'original_retained':True}))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", default="biolivestock-reliability")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error("Evidence output must be new")
    # Restrict this write-producing fault probe to the explicitly isolated test stack.
    if args.project != "biolivestock-reliability":
        parser.error("Use only the isolated biolivestock-reliability test project")
    import subprocess
    result = run(args.project, "exec", "-T", "api", "python", "-",
                 input=SCRIPT.encode(), stdout=subprocess.PIPE)
    evidence = json.loads(result.stdout)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("x", encoding="utf-8") as stream:
        json.dump(evidence, stream, indent=2)
    print(f"Verified retained PostgreSQL evidence and same-key replay: {args.output}")


if __name__ == "__main__":
    main()
