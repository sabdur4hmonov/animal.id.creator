from html import escape
from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from pydantic import Field

from app.api.business import SessionDep, enabled
from app.api.registry import RequestKey
from app.core.auth import OperatorDep
from app.core.rate_limit import allowed
from app.core.species import Species
from app.schemas.common import StrictInput
from app.services import public_verification as service
from app.services.registry import run_operation

router = APIRouter()
root = "/api/v1/registry/animals/{species}/{animal_id}/verification-codes"


class IssueInput(StrictInput):
    pass


class RevokeInput(StrictInput):
    reason: str = Field(min_length=1, max_length=1000)


@router.post(root, status_code=201)
def issue(
    species: Species,
    animal_id: str,
    data: IssueInput,
    request: Request,
    session: SessionDep,
    principal: OperatorDep,
    key: RequestKey,
):
    enabled(request, species)
    service.manage(session, species, animal_id, principal)
    return run_operation(
        session,
        principal,
        key,
        f"qr_issue:{species.value}:{animal_id}",
        data,
        lambda: service.issue(session, species, animal_id, principal, key, request.app.state.settings),
    )


@router.get(root)
def codes(species: Species, animal_id: str, request: Request, session: SessionDep, principal: OperatorDep):
    enabled(request, species)
    return service.code_list(session, species, animal_id, principal)


@router.post(root + "/{code_id}/revoke")
def revoke(
    species: Species,
    animal_id: str,
    code_id: UUID,
    data: RevokeInput,
    request: Request,
    session: SessionDep,
    principal: OperatorDep,
    key: RequestKey,
):
    enabled(request, species)
    service.manage(session, species, animal_id, principal)
    return run_operation(
        session,
        principal,
        key,
        f"qr_revoke:{species.value}:{animal_id}:{code_id}",
        data,
        lambda: service.revoke(session, species, animal_id, str(code_id), data.reason.strip(), principal),
    )


TEXT = {
    "uz_Latn": [
        "So‘yish qaydini tekshirish",
        "Mol IDsi",
        "So‘yish sanasi",
        "Qassobxona kodi",
        "Oxirgi veterinar ko‘rigi",
        "Qayd etilmagan",
        "Bu registr yozuvi, laboratoriya tahlili emas. Hayvon/go‘sht aynanligi va xavfsizligi mustaqil tasdiqlanmagan.",
        "Kod topilmadi yoki bekor qilingan.",
        "So‘rovlar ko‘p. Birozdan keyin qayta tekshiring.",
    ],
    "uz_Cyrl": [
        "Сўйиш қайдини текшириш",
        "Мол IDси",
        "Сўйиш санаси",
        "Қассобхона коди",
        "Охирги ветеринар кўриги",
        "Қайд этилмаган",
        "Бу регистр ёзуви, лаборатория таҳлили эмас. Ҳайвон/гўшт айнанлиги ва хавфсизлиги мустақил тасдиқланмаган.",
        "Код топилмади ёки бекор қилинган.",
        "Сўровлар кўп. Бироздан кейин қайта текширинг.",
    ],
    "ru": [
        "Проверка записи об убое",
        "ID животного",
        "Дата убоя",
        "Код бойни",
        "Последний осмотр ветеринара",
        "Не записано",
        "Это запись реестра, не лабораторный анализ. Идентичность животного/мяса и безопасность независимо не подтверждены.",
        "Код не найден или отозван.",
        "Слишком много запросов. Повторите позже.",
    ],
    "en": [
        "Slaughter record check",
        "Animal ID",
        "Slaughter date",
        "Facility code",
        "Last veterinary examination",
        "Not recorded",
        "This is a registry record, not a laboratory test. Animal/meat identity and safety are not independently verified.",
        "Code not found or revoked.",
        "Too many requests. Try again later.",
    ],
}


def public_page(text, record, status):
    fields = ["animal_id", "slaughter_date", "facility_id", "last_veterinary_examination_date"]
    content = (
        "".join(
            f"<dt>{escape(text[i + 1])}</dt><dd>{escape(str(record.get(key) or text[5]))}</dd>"
            for i, key in enumerate(fields)
        )
        if record
        else ""
    )
    message = "" if record else f"<p>{escape(text[8] if status == 429 else text[7])}</p>"
    body = f"""<!doctype html><html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
    <title>Chorvam</title><style>body{{font:1.1rem system-ui;max-width:40rem;margin:2rem auto;padding:1rem;overflow-wrap:anywhere;background:#f8f6ee;color:#1e3a2b}}h1{{font-size:1.6rem}}dd{{margin:0 0 1rem;font-weight:600}}nav a{{margin-right:1rem}}aside{{border:2px solid #e0a33b;padding:1rem}}</style>
    <nav><a href="?lang=uz_Latn">O‘zbek</a><a href="?lang=uz_Cyrl">Ўзбек</a><a href="?lang=ru">Русский</a><a href="?lang=en">English</a></nav>
    <h1>Chorvam — {escape(text[0])}</h1>{message}<dl>{content}</dl><aside>{escape(text[6])}</aside></html>"""
    headers = {
        "Cache-Control": "no-store",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
        "X-Robots-Tag": "noindex, nofollow",
        "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'",
    }
    return HTMLResponse(body, status_code=status, headers=headers)


@router.get("/verify/{token}", response_class=HTMLResponse)
def verify(
    token: str,
    request: Request,
    session: SessionDep,
    lang: Literal["uz_Latn", "uz_Cyrl", "ru", "en"] = "uz_Latn",
):
    settings = request.app.state.settings
    peer = request.client.host if request.client else "unknown"
    if not allowed(
        session, peer, "public_qr", settings.public_rate_requests, settings.public_rate_window_seconds
    ):
        return public_page(TEXT[lang], None, 429)
    record = service.public_record(session, token)
    return public_page(TEXT[lang], record, 200 if record else 404)
