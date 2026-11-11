"""Explicit catalogs for the offline pilot backlog; no translation service."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROWS = [
    ('Send profile summary to panel','Profil ma’lumotlarini panelga yuborish','Профил маълумотларини панелга юбориш','Отправить сведения профиля в панель'),
    ('Reason','Sabab','Сабаб','Причина'),
    ('Slaughter verification QR','So‘yish qaydi QR kodi','Сўйиш қайди QR коди','QR записи об убое'),
    ('QR is available only after slaughter is recorded on the server. This is a registry record, not a laboratory test.',
     'QR faqat serverda so‘yish qaydi bor bo‘lsa beriladi. Bu registr yozuvi, laboratoriya tahlili emas.',
     'QR фақат серверда сўйиш қайди бор бўлса берилади. Бу регистр ёзуви, лаборатория таҳлили эмас.',
     'QR доступен только после записи об убое на сервере. Это запись реестра, не лабораторный анализ.'),
    ('Saved copy. Connect to check whether the code is still active.','Saqlangan nusxa. Kod hali faol ekanini internetda tekshiring.',
     'Сақланган нусха. Код ҳали фаол эканини интернетда текширинг.','Сохранённая копия. Подключитесь, чтобы проверить актуальность кода.'),
    ('Connect and register this animal to manage its QR code.','QR kod uchun serverga ulanib molni ro‘yxatlang.',
     'QR код учун серверга уланиб молни рўйхатланг.','Подключитесь и зарегистрируйте животное для управления QR.'),
    ('Refresh code status','Kod holatini yangilash','Код ҳолатини янгилаш','Обновить статус кода'),
    ('Create verification QR','Tekshiruv QR kodini olish','Текширув QR кодини олиш','Создать QR проверки'),
    ('Code revoked','Kod bekor qilingan','Код бекор қилинган','Код отозван'),
    ('Share QR','QR kodni ulashish','QR кодни улашиш','Поделиться QR'),
    ('Revoke code','Kodni bekor qilish','Кодни бекор қилиш','Отозвать код'),
    ('Revoke verification code','Tekshiruv kodini bekor qilish','Текширув кодини бекор қилиш','Отозвать код проверки'),
    ('Registry record only, not a laboratory test. Check the QR online.','Bu faqat registr yozuvi, laboratoriya tahlili emas. QR kodni internetda tekshiring.',
     'Бу фақат регистр ёзуви, лаборатория таҳлили эмас. QR кодни интернетда текширинг.','Только запись реестра, не лабораторный анализ. Проверьте QR онлайн.'),
    ("Ownership history", "Egalik tarixi", "Эгалик тарихи", "История владельцев"),
    (
        "Sold / owner changed",
        "Sotildi / egasi o‘zgardi",
        "Сотилди / эгаси ўзгарди",
        "Продано / смена владельца",
    ),
    (
        "New owner reference",
        "Yangi ega yorlig‘i",
        "Янги эга ёрлиғи",
        "Код нового владельца",
    ),
    ("New owner name", "Yangi ega ismi", "Янги эга исми", "Имя нового владельца"),
    (
        "Sale price, whole UZS (optional)",
        "Sotuv narxi, butun so‘m (ixtiyoriy)",
        "Сотув нархи, бутун сўм (ихтиёрий)",
        "Цена, целые сумы (необязательно)",
    ),
    (
        "Transfer notes (required)",
        "O‘tkazish izohi (majburiy)",
        "Ўтказиш изоҳи (мажбурий)",
        "Причина передачи (обязательно)",
    ),
    (
        "Check the owner, date, notes and whole-sum price.",
        "Ega, sana, izoh va butun so‘mdagi narxni tekshiring.",
        "Эга, сана, изоҳ ва бутун сўмдаги нархни текширинг.",
        "Проверьте владельца, дату, причину и цену в целых сумах.",
    ),
    (
        "Save ownership report",
        "Egalik qaydini saqlash",
        "Эгалик қайдини сақлаш",
        "Сохранить запись о владельце",
    ),
    (
        "Sync ownership history",
        "Egalik tarixini yuborish",
        "Эгалик тарихини юбориш",
        "Отправить историю владельцев",
    ),
    (
        "Operator-reported ownership, not verified legal title or payment.",
        "Bu operator kiritgan egalik tarixi; huquqiy mulk yoki to‘lov tasdig‘i emas.",
        "Бу оператор киритган эгалик тарихи; ҳуқуқий мулк ёки тўлов тасдиғи эмас.",
        "Это запись оператора, не подтверждение права собственности или оплаты.",
    ),
    ("{0} UZS", "{0} so‘m", "{0} сўм", "{0} сум"),
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
