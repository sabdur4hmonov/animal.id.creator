"""Explicit snapshot translations and removal of obsolete anatomical UI prompts."""

import json
from pathlib import Path

ROWS = """Snapshot: left + right, optional front|Muzlatilgan kadr: chap + o‘ng, old tomon ixtiyoriy|Стоп-кадр: слева + справа, спереди по желанию|Музлатилган кадр: чап + ўнг, олд томон ихтиёрий
Capture frame|Kadrni olish|Снять кадр|Кадрни олиш
Keep the whole animal in view. Capture one sharp frame with current depth, then mark the frozen image.|Molning butun gavdasini kadrga sig‘diring. Depth tayyor bo‘lganda tiniq kadr oling, keyin muzlagan rasmda nuqtalarni bosing.|Поместите всё тело в кадр. Снимите чёткий кадр с текущей глубиной, затем отметьте точки на неподвижном изображении.|Молнинг бутун гавдасини кадрга сиғдиринг. Depth тайёр бўлганда тиниқ кадр олинг, кейин музлаган расмда нуқталарни босинг.
No raw depth for this exact camera frame. Move slowly and capture again; no substitute depth is used.|Aynan shu kadrga tegishli depth yo‘q. Sekin siljib qayta oling; boshqa kadr depth’i ishlatilmaydi.|Нет исходной глубины именно этого кадра. Медленно переместитесь и снимите снова; глубина другого кадра не используется.|Айнан шу кадрга тегишли depth йўқ. Секин силжиб қайта олинг; бошқа кадр depth’и ишлатилмайди.
1 — Front end (the frontmost part of the chest)|1 — Old uchi (ko‘krakning eng oldinga chiqqan joyi)|1 — Передний край (самая выступающая вперёд часть груди)|1 — Олд учи (кўкракнинг энг олдинга чиққан жойи)
2 — Back end (under the tail)|2 — Orqa uchi (dumning tagi)|2 — Задний край (под хвостом)|2 — Орқа учи (думнинг таги)
3 — Top of the back (highest point above the front legs)|3 — Orqa tepasi (old oyoqlar ustida, orqaning eng baland joyi)|3 — Верх спины (самая высокая точка над передними ногами)|3 — Орқа тепаси (олд оёқлар устида, орқанинг энг баланд жойи)
4 — Bottom of the chest (directly below point 3, behind the front legs)|4 — Ko‘krak tagi (3-nuqtaning to‘g‘ri pastida, old oyoqlar orqasida)|4 — Низ груди (прямо под точкой 3, за передними ногами)|4 — Кўкрак таги (3-нуқтанинг тўғри пастида, олд оёқлар орқасида)
1/3 Left side|1/3 Chap yon|1/3 Левый бок|1/3 Чап ён
2/3 Right side|2/3 O‘ng yon|2/3 Правый бок|2/3 Ўнг ён
3/3 Front (optional)|3/3 Old tomon (ixtiyoriy)|3/3 Спереди (необязательно)|3/3 Олд томон (ихтиёрий)
Frozen frame: take your time. Points use only this saved depth and camera pose.|Kadr muzlatilgan: shoshilmang. Nuqtalar faqat shu kadrning saqlangan depth’i va kamera holatidan hisoblanadi.|Кадр неподвижен: не спешите. Точки вычисляются только по сохранённым глубине и положению камеры этого кадра.|Кадр музлатилган: шошилманг. Нуқталар фақат шу кадрнинг сақланган depth’и ва камера ҳолатидан ҳисобланади.
Points ready. Save this frame.|Nuqtalar tayyor. Shu kadrni saqlang.|Точки готовы. Сохраните этот кадр.|Нуқталар тайёр. Шу кадрни сақланг.
Left edge of the chest (behind the front legs)|Ko‘krakning chap chekkasi (old oyoqlar orqasida)|Левый край груди (за передними ногами)|Кўкракнинг чап чеккаси (олд оёқлар орқасида)
Right edge of the same chest section|Shu ko‘krak kesimining o‘ng chekkasi|Правый край того же сечения груди|Шу кўкрак кесимининг ўнг чеккаси
Point rejected: this pixel has no reliable depth. Retake the frame if needed.|Nuqta rad etildi: shu pikselda ishonchli depth yo‘q. Kerak bo‘lsa kadrni qayta oling.|Точка отклонена: в этом пикселе нет надёжной глубины. При необходимости переснимите кадр.|Нуқта рад этилди: шу пикселда ишончли depth йўқ. Керак бўлса кадрни қайта олинг.
Undo last point|Oxirgi nuqtani bekor qilish|Отменить последнюю точку|Охирги нуқтани бекор қилиш
Retake frame|Qayta olish|Переснять|Қайта олиш
Save frozen frame|Muzlatilgan kadrni saqlash|Сохранить стоп-кадр|Музлатилган кадрни сақлаш
Capture left and right separately. Front width is optional. Never measure between different frames.|Chap va o‘ng yonni alohida oling. Old kadr kengligi ixtiyoriy. Turli kadrlardagi nuqtalar orasida masofa hisoblanmaydi.|Снимите левый и правый бок отдельно. Ширина спереди необязательна. Между точками разных кадров расстояния не считаются.|Чап ва ўнг ённи алоҳида олинг. Олд кадр кенглиги ихтиёрий. Турли кадрлардаги нуқталар орасида масофа ҳисобланмайди.
Snapshot mode requires Depth API. Depth is unavailable or unconfirmed; fast/contour and offline photos remain available.|Muzlatilgan kadr uchun Depth API shart. Depth yo‘q yoki hali tasdiqlanmagan; tez/kontur rejimi va oflayn suratlar ishlayveradi.|Для стоп-кадра нужен Depth API. Глубина недоступна или не подтверждена; быстрый/контурный режимы и фото офлайн остаются доступны.|Музлатилган кадр учун Depth API шарт. Depth йўқ ёки ҳали тасдиқланмаган; тез/контур режими ва офлайн суратлар ишлайверади.
First measure {1} different animals in six-point mode ({0}/{1}). Optional front width bypasses the ratio requirement.|Avval {1} ta turli molni 6 nuqtali rejimda o‘lchang ({0}/{1}). Old kadr kengligi bo‘lsa nisbat talab qilinmaydi.|Сначала измерьте {1} разных животных в режиме 6 точек ({0}/{1}). При наличии ширины спереди коэффициент не нужен.|Аввал {1} та турли молни 6 нуқтали режимда ўлчанг ({0}/{1}). Олд кадр кенглиги бўлса нисбат талаб қилинмайди.
Capture next snapshot|Keyingi kadrni olish|Снять следующий кадр|Кейинги кадрни олиш
Finish snapshot set|Kadrlar to‘plamini yakunlash|Завершить серию кадров|Кадрлар тўпламини якунлаш
Width measured from optional front frame.|Kenglik old kadrdan bevosita o‘lchangan.|Ширина измерена непосредственно на переднем кадре.|Кенглик олд кадрдан бевосита ўлчанган.
Approximate, uncalibrated; width ratio from {0} animals, revision {1}.|Taxminiy, kalibrlanmagan; kenglik nisbati {0} ta hayvondan, versiya {1}.|Приблизительно, без калибровки; отношение ширины по {0} животным, версия {1}.|Тахминий, калибрланмаган; кенглик нисбати {0} та ҳайвондан, версия {1}.
Keep the animal still with a handler. Stay safe; never crawl underneath. Tap only the named body point. Restart if the animal moves.|Yordamchi molni tinch ushlasin. Tagiga kirmang. Faqat aytilgan joyni bosing. Mol qimirlasa qayta boshlang.|Помощник удерживает животное неподвижно. Не залезайте под него. Отмечайте только названное место. При движении начните заново.|Ёрдамчи молни тинч ушласин. Тагига кирманг. Фақат айтилган жойни босинг. Мол қимирласа қайта бошланг."""

OLD = {
    "1. Tap the shoulder joint.",
    "2. Tap the pin bone.",
    "3. Tap the withers above the chest, behind the front legs.",
    "4. Tap the brisket below that same chest section.",
    "Keep the animal still with a handler. Stay safe; never crawl underneath. Tap only the named anatomical point. Restart if the animal moves.",
}

if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1]
    for index, locale in enumerate(("en", "uz_Latn", "ru", "uz_Cyrl")):
        path = root / f"mobile/assets/l10n/{locale}.json"
        values = json.loads(path.read_text("utf-8"))
        for key in OLD:
            values.pop(key, None)
        for line in ROWS.splitlines():
            row = line.split("|")
            assert len(row) == 4
            values[row[0]] = row[index]
        path.write_text(
            json.dumps(values, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
    # The previous maintenance helper must never reintroduce removed terms.
    previous = root / "tools/add_ar_translations.py"
    text = previous.read_text("utf-8")
    previous.write_text(
        "\n".join(line for line in text.split("\n") if line.split("|")[0] not in OLD),
        encoding="utf-8",
    )
