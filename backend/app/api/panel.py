"""Small private SSR portal; no token in a URL or browser storage."""

import secrets
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal

from fastapi import APIRouter, HTTPException, Query, Request
from fastapi.responses import FileResponse, HTMLResponse, JSONResponse
from jinja2 import Environment, FileSystemLoader, select_autoescape
from sqlalchemy import exists, or_, select

from app.api.business import SessionDep, enabled
from app.core.auth import PrincipalDep
from app.core.species import Species
from app.models.business import Animal, AuditEvent
from app.models.capture import Capture
from app.models.health import HealthEvent
from app.models.portal import FieldSummary
from app.services.browser_sessions import COOKIE, new_session, set_cookie
from app.services.integrity import verify_stored_image
from app.services.registry import registry_query, render_registry, require_record

router = APIRouter()
templates = Environment(
    loader=FileSystemLoader(Path(__file__).resolve().parents[1] / "templates"),
    autoescape=select_autoescape(["html"]),
)
Lang = Literal["uz_Latn", "ru"]
TEXT = {
    "uz_Latn": {
        "title": "Chorvam — hamkorlar paneli",
        "login": "Kirish",
        "token": "Operator yoki admin API kaliti",
        "submit": "Kirish",
        "search": "ID yoki birka bo‘yicha qidirish",
        "empty": "Hali yozuv yo‘q",
        "registry": "Mollar",
        "profile": "Mol profili",
        "owner": "Egasi",
        "health": "Sog‘liq tarixi",
        "weights": "Vazn yozuvlari",
        "photos": "Suratlar",
        "audit": "Tekshiruv tarixi",
        "financial": "Moliyaviy holat",
        "lifecycle": "Hayot holati",
        "approximate": "Taxminiy, dala aniqligi tekshirilmagan",
        "offline": "Faqat serverga yuborilgan qaydlar. Telefonda qolgan ma’lumot bu yerda ko‘rinmaydi.",
        "save": "Holatni yangilash",
        "reason": "O‘zgartirish sababi",
        "version": "Versiya",
        "logout": "Chiqish",
        "next": "Keyingi",
        "previous": "Oldingi",
        "tag": "Birka / laqab",
        "actor": "Kim",
        "date": "Sana",
        "action": "Qayd",
        "details": "Tafsilot",
        "examination": "Veterinar tasdig‘i",
        "operator": "Operator yozuvi",
        "insured": "Sug‘urtalangan",
        "collateral": "Garovda",
        "open": "Ochiq",
        "active": "Faol",
        "deceased": "O‘lgan",
        "slaughtered": "So‘yilgan",
        "failed": "So‘rov bajarilmadi. Sahifani yangilang.",
        "scale": "Tarozidagi vazn (operator qaydi)",
        "slaughter": "So‘yish qaydi",
        "no_image": "Original tekshiruvi o‘tmadi",
    },
    "ru": {
        "title": "Chorvam — панель партнёров",
        "login": "Вход",
        "token": "API-ключ оператора или администратора",
        "submit": "Войти",
        "search": "Поиск по ID или бирке",
        "empty": "Записей пока нет",
        "registry": "Животные",
        "profile": "Профиль животного",
        "owner": "Владелец",
        "health": "История здоровья",
        "weights": "Записи веса",
        "photos": "Фотографии",
        "audit": "История проверок",
        "financial": "Финансовый статус",
        "lifecycle": "Состояние",
        "approximate": "Приблизительно, точность в поле не проверена",
        "offline": "Только отправленные на сервер записи. Данные, оставшиеся на телефоне, здесь не отображаются.",
        "save": "Обновить статус",
        "reason": "Причина изменения",
        "version": "Версия",
        "logout": "Выйти",
        "next": "Далее",
        "previous": "Назад",
        "tag": "Бирка / кличка",
        "actor": "Кто",
        "date": "Дата",
        "action": "Событие",
        "details": "Подробности",
        "examination": "Подтверждено ветеринаром",
        "operator": "Запись оператора",
        "insured": "Застраховано",
        "collateral": "В залоге",
        "open": "Открыто",
        "active": "Активно",
        "deceased": "Пало",
        "slaughtered": "Забито",
        "failed": "Запрос не выполнен. Обновите страницу.",
        "scale": "Вес на весах (запись оператора)",
        "slaughter": "Запись об убое",
        "no_image": "Проверка оригинала не пройдена",
    },
}


def page(name, request, lang, **values):
    nonce = secrets.token_urlsafe(24)
    browser = getattr(request.state, "browser_session", None)
    html = templates.get_template(name + ".html").render(
        t=TEXT[lang], lang=lang, nonce=nonce, csrf=browser.csrf if browser else "", **values
    )
    return HTMLResponse(
        html,
        headers={
            "Cache-Control": "no-store",
            "Referrer-Policy": "no-referrer",
            "X-Content-Type-Options": "nosniff",
            "X-Robots-Tag": "noindex, nofollow",
            "Content-Security-Policy": f"default-src 'none'; img-src 'self'; style-src 'unsafe-inline'; script-src 'nonce-{nonce}'; connect-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'",
        },
    )


@router.get("/panel/login")
def login(request: Request, lang: Lang = "uz_Latn"):
    return page("login", request, lang)


@router.post("/panel/session")
def exchange(request: Request, session: SessionDep, principal: PrincipalDep):
    if not request.headers.get("Authorization", "").lower().startswith("bearer "):
        raise HTTPException(401, "An explicit bearer key is required to create a browser session")
    settings = request.app.state.settings
    token, _ = new_session(session, principal, settings)
    response = JSONResponse({"ok": True}, headers={"Cache-Control": "no-store"})
    set_cookie(response, token, settings.browser_session_seconds)
    return response


@router.post("/panel/logout")
def logout(request: Request, session: SessionDep, principal: PrincipalDep):
    browser = getattr(request.state, "browser_session", None)
    if browser:
        browser.revoked_at = datetime.now(UTC)
        session.commit()
    response = JSONResponse({"ok": True}, headers={"Cache-Control": "no-store"})
    response.delete_cookie(COOKIE, path="/", secure=True, httponly=True, samesite="strict")
    return response


@router.get("/panel")
def index(
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    lang: Lang = "uz_Latn",
    species: Species = Species.cattle,
    q: str = Query(default="", max_length=120),
    offset: int = Query(default=0, ge=0),
):
    enabled(request, species)
    query = registry_query().where(Animal.species == species)
    if principal.role == "operator":
        query = query.where(Animal.registered_by == principal.operator_id)
    if q.strip():
        pattern = "%" + q.strip().replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_") + "%"
        tag = select(FieldSummary.id).where(
            FieldSummary.species == Animal.species,
            FieldSummary.animal_id == Animal.animal_id,
            FieldSummary.payload["tag"].as_string().ilike(pattern, escape="\\"),
        )
        query = query.where(or_(Animal.animal_id.ilike(pattern, escape="\\"), exists(tag)))
    snapshots = session.execute(
        query.order_by(Animal.created_at.desc(), Animal.animal_id).offset(offset).limit(51)
    ).all()
    return page(
        "registry",
        request,
        lang,
        principal=principal,
        records=[render_registry(*r, principal) for r in snapshots[:50]],
        q=q,
        species=species.value,
        offset=offset,
        more=len(snapshots) > 50,
    )


@router.get("/panel/animals/{species}/{animal_id}")
def profile(
    species: Species,
    animal_id: str,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    lang: Lang = "uz_Latn",
):
    enabled(request, species)
    require_record(session, species, animal_id)
    if (
        principal.role == "operator"
        and require_record(session, species, animal_id).registered_by != principal.operator_id
    ):
        raise HTTPException(403, "This panel record belongs to another operator")
    snapshot = session.execute(
        registry_query().where(Animal.species == species, Animal.animal_id == animal_id)
    ).one()
    clauses = lambda table: (table.species == species, table.animal_id == animal_id)
    captures = select(Capture).where(*clauses(Capture))
    if principal.role == "operator":
        captures = captures.where(Capture.operator_id == principal.operator_id)
    events = session.scalars(
        select(AuditEvent)
        .where(*clauses(AuditEvent))
        .order_by(AuditEvent.received_at.desc(), AuditEvent.id)
        .limit(100)
    ).all()
    return page(
        "profile",
        request,
        lang,
        principal=principal,
        animal=render_registry(*snapshot, principal),
        photos=session.scalars(captures.order_by(Capture.timestamp.desc()).limit(20)).all(),
        health=session.scalars(
            select(HealthEvent)
            .where(*clauses(HealthEvent))
            .order_by(HealthEvent.event_date.desc())
            .limit(100)
        ).all(),
        summaries=session.scalars(
            select(FieldSummary)
            .where(*clauses(FieldSummary))
            .order_by(FieldSummary.observed_at.desc(), FieldSummary.id)
            .limit(100)
        ).all(),
        events=events,
        can_finance=principal.role in {"admin", "bank_officer"},
    )


@router.get("/panel/animals/{species}/{animal_id}/history")
def history(
    species: Species,
    animal_id: str,
    request: Request,
    session: SessionDep,
    principal: PrincipalDep,
    lang: Lang = "uz_Latn",
    offset: int = Query(default=0, ge=0),
):
    enabled(request, species)
    record = require_record(session, species, animal_id)
    if principal.role == "operator" and record.registered_by != principal.operator_id:
        raise HTTPException(403, "This panel record belongs to another operator")
    events = session.scalars(
        select(AuditEvent)
        .where(AuditEvent.species == species, AuditEvent.animal_id == animal_id)
        .order_by(AuditEvent.received_at.desc(), AuditEvent.id)
        .offset(offset)
        .limit(101)
    ).all()
    return page(
        "history",
        request,
        lang,
        principal=principal,
        animal_id=animal_id,
        species=species.value,
        events=events[:100],
        offset=offset,
        more=len(events) > 100,
    )


@router.get("/panel/photos/{capture_id}")
def photo(capture_id: str, request: Request, session: SessionDep, principal: PrincipalDep):
    row = session.get(Capture, capture_id)
    if row is None or (principal.role == "operator" and row.operator_id != principal.operator_id):
        raise HTTPException(404, "Photo not found")
    if verify_stored_image(request.app.state.settings.storage_root, row)["status"] != "matched":
        raise HTTPException(409, "Stored original is missing or changed")
    return FileResponse(
        request.app.state.settings.storage_root / row.file_path,
        media_type="image/jpeg",
        headers={"Cache-Control": "no-store", "X-Content-Type-Options": "nosniff"},
    )
