# Publication audit — 2026-11-10

User explicitly authorized ordinary fast-forward pushes for the five-stage
Chorvam task. No force push, rebase, history rewrite or device installation.

GitHub REST repository metadata confirmed public visibility. Live remote main
was eaaf85738e6f5681ac74afe0d3bf898688b22070, identical to cached origin/main
and an ancestor of local 5910f35828a7f675714bd9c45eb0c47b84ed81d5 (33 ahead).

Read-only tools/audit_publication.py inspected 305 tracked paths and the
667 distinct objects in HEAD plus outgoing history. No forbidden secret/data/
APK/weights/keystore path or high-confidence credential signature was found.
Credential literal review and documentation personal-phone review found none.
Ignore checks passed for local data, APK, .env, .secrets/tokens.json, JKS,
and model weights. Raw audit is ignored under data/dev/.

Manually reviewed documentation references to owner data/GPS and tracked media:
quality-clipping fixtures are synthetic; UI previews are host mocks; the
measurement reference is a drawn cow diagram; platform assets are scaffold
icons. No real animal photos, owner records, backups/restore data or personal
phone numbers found in these tracked files. Founder name is permitted.
Device/user-reported test identifiers in progress are technical evidence, not
owner data. No privacy-redaction commit was necessary. The referenced personal
pitch PDF remains outside this repository.

This is a bounded automated and manual review, not a guarantee against every
possible credential format. Stop publication and report if later checks find
a secret. Recheck live remote ancestry immediately before each push.
