"""Explicit catalogs for the offline pilot backlog; no translation service."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROWS = [
    (
        "Health and vaccinations",
        "Sog‘liq va emlashlar",
        "Соғлиқ ва эмлашлар",
        "Здоровье и прививки",
    ),
    ("Vaccination", "Emlash", "Эмлаш", "Вакцинация"),
    ("Treatment", "Davolash", "Даволаш", "Лечение"),
    ("Illness", "Kasallik", "Касаллик", "Заболевание"),
    (
        "Veterinary examination",
        "Veterinar ko‘rigi",
        "Ветеринар кўриги",
        "Ветеринарный осмотр",
    ),
    (
        "Add health record",
        "Sog‘liq qaydini qo‘shish",
        "Соғлиқ қайдини қўшиш",
        "Добавить запись о здоровье",
    ),
    (
        "Add correcting record",
        "Tuzatuvchi qayd qo‘shish",
        "Тузатувчи қайд қўшиш",
        "Добавить исправление",
    ),
    (
        "Event date YYYY-MM-DD",
        "Hodisa sanasi YYYY-MM-DD",
        "Ҳодиса санаси YYYY-MM-DD",
        "Дата события ГГГГ-ММ-ДД",
    ),
    ("Description", "Tavsif", "Тавсиф", "Описание"),
    (
        "Veterinarian name (optional)",
        "Veterinar ismi (ixtiyoriy)",
        "Ветеринар исми (ихтиёрий)",
        "Имя ветеринара (необязательно)",
    ),
    ("Notes", "Izoh", "Изоҳ", "Примечание"),
    ("Save record", "Qaydni saqlash", "Қайдни сақлаш", "Сохранить запись"),
    (
        "Check the date and required description.",
        "Sana va majburiy tavsifni tekshiring.",
        "Сана ва мажбурий тавсифни текширинг.",
        "Проверьте дату и обязательное описание.",
    ),
    (
        "Sync health history",
        "Sog‘liq tarixini yuborish",
        "Соғлиқ тарихини юбориш",
        "Отправить историю здоровья",
    ),
    (
        "Reported history, not a diagnosis. Corrections keep every earlier record.",
        "Bu kiritilgan tarix, tashxis emas. Tuzatish avvalgi qaydni o‘chirmaydi.",
        "Бу киритилган тарих, ташхис эмас. Тузатиш аввалги қайдни ўчирмайди.",
        "Это история записей, не диагноз. Исправления сохраняют прежние записи.",
    ),
    ("Operator record", "Operator yozuvi", "Оператор ёзуви", "Запись оператора"),
    ("Correcting record", "Tuzatuvchi qayd", "Тузатувчи қайд", "Исправляющая запись"),
]


def main():
    for column, locale in enumerate(("en", "uz_Latn", "uz_Cyrl", "ru")):
        path = ROOT / "mobile/assets/l10n" / f"{locale}.json"
        data = json.loads(path.read_text("utf-8"))
        data.update({row[0]: row[column] for row in ROWS})
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", "utf-8")


if __name__ == "__main__":
    main()
