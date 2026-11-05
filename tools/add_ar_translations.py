"""Maintain explicit AR field translations in the four shipped catalogs."""

import json
from pathlib import Path

ROWS = """AR weight and valuation|AR vazn va qiymat|AR: вес и стоимость|AR вазн ва қиймат
Finish AR measurement|AR o‘lchovni tugatish|Завершить AR-измерение|AR ўлчовни тугатиш
Move the phone slowly until tracking is ready.|Kuzatuv tayyor bo‘lguncha telefonni sekin siljiting.|Медленно перемещайте телефон до готовности отслеживания.|Кузатув тайёр бўлгунча телефонни секин силжитинг.
5. From front/above, tap the left side of that chest section.|5. Oldindan yoki tepadan shu kesimning chap yonini bosing.|5. Спереди или сверху коснитесь левой стороны того же сечения.|5. Олдиндан ёки тепадан шу кесимнинг чап ёнини босинг.
6. Tap the right side of the same chest section.|6. Shu kesimning o‘ng yonini bosing.|6. Коснитесь правой стороны того же сечения.|6. Шу кесимнинг ўнг ёнини босинг.
Tap both endpoints of your known object first.|Avval o‘lchami ma’lum buyumning ikki uchini bosing.|Сначала коснитесь обоих концов предмета известной длины.|Аввал ўлчами маълум буюмнинг икки учини босинг.
Tap the chest section in order around the body; do not repeat the first point. Finish after at least {0} contour points.|Ko‘krak kesimi atrofida tartib bilan bosing; birinchi nuqtani takrorlamang. Kamida {0} kontur nuqtasidan so‘ng tugating.|Касайтесь точек сечения груди по порядку вокруг тела; первую не повторяйте. Завершите после минимум {0} точек контура.|Кўкрак кесими атрофида тартиб билан босинг; биринчи нуқтани такрорламанг. Камида {0} контур нуқтасидан сўнг тугатинг.
Point rejected: no reliable surface/confidence. Move slowly and retry; do not select the background.|Nuqta rad etildi: ishonchli sirt topilmadi. Sekin siljib qaytaring; fonni tanlamang.|Точка отклонена: нет надёжной поверхности/достоверности. Двигайтесь медленно и повторите; не выбирайте фон.|Нуқта рад этилди: ишончли сирт топилмади. Секин силжиб қайтаринг; фонни танламанг.
More points required. Follow the current step.|Yana nuqtalar kerak. Joriy qadamni bajaring.|Нужны ещё точки. Следуйте текущему шагу.|Яна нуқталар керак. Жорий қадамни бажаринг.
Approximate only. Animal accuracy is unverified. Fast girth is an uncalibrated ellipse estimate; contour mode is separate.|Faqat taxmin. Hayvondagi aniqlik tekshirilmagan. Tez rejim aylanasi — kalibrlanmagan ellips taxmini; kontur alohida rejim.|Только оценка. Точность на животных не проверена. Быстрый обхват — некалиброванная оценка эллипса; контур — отдельный режим.|Фақат тахмин. Ҳайвондаги аниқлик текширилмаган. Тез режим айланаси — калибрланмаган эллипс тахмини; контур алоҳида режим.
Action failed; original evidence retained. Review the diagnostic and retry.|Amal bajarilmadi; asl dalillar saqlangan. Xato tafsilotini tekshirib qaytaring.|Действие не выполнено; исходные данные сохранены. Проверьте диагностику и повторите.|Амал бажарилмади; асл далиллар сақланган. Хато тафсилотини текшириб қайтаринг.
Device AR status|Qurilma AR holati|Состояние AR устройства|Қурилма AR ҳолати
This phone does not support AR measurement. Offline photos still work.|Bu telefon AR o‘lchashni qo‘llamaydi. Offlayn suratlar ishlayveradi.|Этот телефон не поддерживает AR-измерения. Фото офлайн работают.|Бу телефон AR ўлчашни қўлламайди. Оффлайн суратлар ишлайверади.
AR support is not ready or unknown. Install/update Google Play Services for AR when online, grant camera access, then retry. Offline photos still work.|AR tayyor emas yoki holati noma’lum. Internetda Google Play Services for AR ni o‘rnating/yangilang, kameraga ruxsat bering va qaytaring. Offlayn suratlar ishlayveradi.|AR не готов или статус неизвестен. Установите/обновите Google Play Services for AR онлайн, разрешите камеру и повторите. Фото офлайн работают.|AR тайёр эмас ёки ҳолати номаълум. Интернетда Google Play Services for AR ни ўрнатинг/янгиланг, камерага рухсат беринг ва қайтаринг. Оффлайн суратлар ишлайверади.
Check AR support|AR mosligini tekshirish|Проверить поддержку AR|AR мослигини текшириш
Adult cattle only; these formulas are not validated for calves.|Faqat katta qoramol; bu formulalar buzoqlar uchun tekshirilmagan.|Только взрослый КРС; формулы не проверены для телят.|Фақат катта қорамол; бу формулалар бузоқлар учун текширилмаган.
Measurement mode|O‘lchash rejimi|Режим измерения|Ўлчаш режими
Fast: six points, estimated girth|Tez: olti nuqta, taxminiy aylana|Быстрый: шесть точек, оценка обхвата|Тез: олти нуқта, тахминий айлана
Detailed: closed 3D contour|Aniq rejim: yopiq 3D kontur|Подробный: замкнутый 3D-контур|Аниқ режим: ёпиқ 3D контур
Breed category|Zot turi|Категория породы|Зот тури
Dairy|Sut yo‘nalishi|Молочная|Сут йўналиши
Beef|Go‘sht yo‘nalishi|Мясная|Гўшт йўналиши
Optional known-object length (cm); A4 long edge = 29.7|Ixtiyoriy buyum uzunligi (cm); A4 uzun tomoni = 29.7|Длина известного предмета, необязательно (см); длинный край A4 = 29.7|Ихтиёрий буюм узунлиги (cm); A4 узун томони = 29.7
Repeat the whole measurement {0}–{1} times. The animal must remain still during each run.|To‘liq o‘lchovni {0}–{1} marta takrorlang. Har safar mol qimirlamasligi kerak.|Повторите полное измерение {0}–{1} раза. Во время каждого прохода животное должно быть неподвижно.|Тўлиқ ўлчовни {0}–{1} марта такрорланг. Ҳар сафар мол қимирламаслиги керак.
Start next AR measurement|Keyingi AR o‘lchovni boshlash|Начать следующее AR-измерение|Кейинги AR ўлчовни бошлаш
Completed repeats: {0}|Bajarilgan takrorlar: {0}|Выполнено повторов: {0}|Бажарилган такрорлар: {0}
Start a new repeat set (retain history)|Yangi takrorlar to‘plami (tarix saqlanadi)|Новая серия повторов (история сохраняется)|Янги такрорлар тўплами (тарих сақланади)
Repeat difference: {0}% (limit {1}%)|Takrorlar farqi: {0}% (chegara {1}%)|Разница повторов: {0}% (предел {1}%)|Такрорлар фарқи: {0}% (чегара {1}%)
Difference exceeds the limit. Start a new set and measure again; no correction or final valuation is applied.|Farq chegaradan katta. Yangi to‘plamda qayta o‘lchang; korreksiya va yakuniy qiymat qo‘llanmaydi.|Разница выше предела. Начните новую серию; коррекция и итоговая оценка не применяются.|Фарқ чегарадан катта. Янги тўпламда қайта ўлчанг; коррекция ва якуний қиймат қўлланмайди.
Uncorrected weight: {0} kg|Korreksiyagacha vazn: {0} kg|Вес до коррекции: {0} кг|Коррекциягача вазн: {0} kg
True scale weight is optional. Date must be within {0} days of this AR set.|Haqiqiy tarozi vazni ixtiyoriy. Sana AR to‘plamidan ko‘pi bilan {0} kun farq qilsin.|Вес на весах необязателен. Дата должна отличаться от AR-серии не более чем на {0} дней.|Ҳақиқий тарози вазни ихтиёрий. Сана AR тўпламидан кўпи билан {0} кун фарқ қилсин.
True scale weight (kg)|Haqiqiy tarozi vazni (kg)|Фактический вес на весах (кг)|Ҳақиқий тарози вазни (kg)
Weighing date YYYY-MM-DD|Tortilgan sana YYYY-MM-DD|Дата взвешивания YYYY-MM-DD|Тортилган сана YYYY-MM-DD
Save true weighing|Haqiqiy tortishni saqlash|Сохранить взвешивание|Ҳақиқий тортишни сақлаш
Calculate local correction|Lokal korreksiyani hisoblash|Рассчитать локальную коррекцию|Локал коррекцияни ҳисоблаш
In-sample MAPE before / after: {0}% / {1}%. This is not independent accuracy validation.|Shu namunalardagi MAPE oldin / keyin: {0}% / {1}%. Bu mustaqil aniqlik sinovi emas.|MAPE на этих же образцах до / после: {0}% / {1}%. Это не независимая проверка точности.|Шу намуналардаги MAPE олдин / кейин: {0}% / {1}%. Бу мустақил аниқлик синови эмас.
Apply local correction|Lokal korreksiyani qo‘llash|Применить локальную коррекцию|Локал коррекцияни қўллаш
Corrected weight: {0} kg|Korreksiyadan keyingi vazn: {0} kg|Вес после коррекции: {0} кг|Коррекциядан кейинги вазн: {0} kg
Price snapshot|Narx nusxasi|Снимок цены|Нарх нусхаси
After correction|Korreksiyadan keyin|После коррекции|Коррекциядан кейин
Save valuation snapshot|Qiymat nusxasini saqlash|Сохранить оценку|Қиймат нусхасини сақлаш
Local market prices (integer UZS per kg)|Lokal bozor narxlari (butun so‘m/kg)|Локальные рыночные цены (целые сум/кг)|Локал бозор нархлари (бутун сўм/kg)
Carcass meat price UZS/kg|Tana go‘shti narxi so‘m/kg|Цена туши сум/кг|Тана гўшти нархи сўм/kg
Optional live-weight price UZS/kg|Ixtiyoriy tirik vazn narxi so‘m/kg|Цена живого веса, необязательно, сум/кг|Ихтиёрий тирик вазн нархи сўм/kg
Price date YYYY-MM-DD|Narx sanasi YYYY-MM-DD|Дата цены YYYY-MM-DD|Нарх санаси YYYY-MM-DD
Price source / market note|Narx manbasi / bozor izohi|Источник цены / примечание о рынке|Нарх манбаси / бозор изоҳи
Save price revision|Narx versiyasini saqlash|Сохранить версию цены|Нарх версиясини сақлаш
Immutable animal measurement history: {0} records|O‘zgarmas o‘lchov tarixi: {0} yozuv|Неизменяемая история измерений: {0} записей|Ўзгармас ўлчов тарихи: {0} ёзув
Image preview unavailable; original retained.|Rasm ko‘rinmadi; asli saqlangan.|Предпросмотр недоступен; оригинал сохранён.|Расм кўринмади; асли сақланган.
Carcass: {0}–{1} kg; value: {2}–{3} UZS|Tana go‘shti: {0}–{1} kg; qiymat: {2}–{3} so‘m|Туша: {0}–{1} кг; стоимость: {2}–{3} сум|Тана гўшти: {0}–{1} kg; қиймат: {2}–{3} сўм
Live-weight value: {0} UZS|Tirik vazn qiymati: {0} so‘m|Стоимость по живому весу: {0} сум|Тирик вазн қиймати: {0} сўм"""


if __name__ == "__main__":
    root = Path(__file__).resolve().parents[1] / "mobile/assets/l10n"
    for index, locale in enumerate(("en", "uz_Latn", "ru", "uz_Cyrl")):
        path = root / f"{locale}.json"
        values = json.loads(path.read_text("utf-8"))
        for line in ROWS.splitlines():
            row = line.split("|")
            assert len(row) == 4
            values[row[0]] = row[index]
        path.write_text(
            json.dumps(values, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
