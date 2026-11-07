# BioLivestock AI — Agrobank / AgroVentures ariza va pilot qoralamasi

**2026-11-07 yangilanishi:** ommaviy nom **Chorvam**. Hozirgi tadqiqot va
yangilangan ariza matni: [CHORVAM_MARKET_AND_APPLICATION.md](CHORVAM_MARKET_AND_APPLICATION.md).
Quyidagi Oct29 qoralama tarixiy; telefon o‘rnatilishi tekshirildi, founder
Nov6 sinovida **ikki molda** to‘g‘ri amaliy sinov qilganini aniqlashtirdi.
Capture paytida mol harakati muammo; matching/vazn accuracy foizi yo‘q.
Solo eligibility va founder tanlagan pul so‘rovi hali ochiq. Pastdagi eski
holat, muddat va feature bayonotlarini yangilanmaganicha yubormang.

Tayyorlangan: 2026-10-29, Asia/Tashkent. Bu review uchun matnlar; ariza yuborilmadi, hech kimga xabar jo‘natilmadi va shartlar qabul qilinmadi. Sana, talab va formani submitdan oldin yana tekshirish kerak.

## Hozir aniq bo‘lgan holat

Sardorbekning bugungi javobi: **yakka founder**, **ishlaydigan telefon bor**, **real hayvon rasmlari hali yo‘q**. Hayvonlarga kirish topilishi mumkin, lekin kelishilgan ferma/pilot hamkori hali tasdiqlanmagan. Telefon mavjudligi eski tashqi blockerni o‘zgartirdi; native app end-to-end sinovi o‘tgan degani emas.

Repo’dagi collection/registry MVP, to‘rt til va backend verifikatsiyasi mavjud. Biometrik cattle matching, liveness aniqligi va suratdan vaznni ishonchli aniqlash tasdiqlanmagan. Synthetic database yozuvlari foydalanuvchi, pilot, revenue yoki real dataset sifatida sanalmaydi. 361 test — 2026-10-14 kod-verification natijasi; bozor traction’i emas.

## Dastur tekshiruvi va darhol hal qilinadigan savol

[Rasmiy dastur](https://www.agroventures.uz/accelerator): 9-noyabr 2026 deadline, 12 hafta, MVP va **2–5 founder** mezoni; muntazam qatnashish kutiladi. Demak solo eligibility ochiq savol. Biznes/ferma hamkorini asossiz hammuassis deb yozmaslik kerak.

[Fond FAQ](https://www.agroventures.uz/): $25k–$500k imkoniyati loyiha bosqichiga bog‘liq; investitsiya odatda equity/investitsion instrument bilan. Bepul akseleratsiya investitsiyaning ham ulushsizligi yoki pul berilishini anglatmaydi.

[To‘g‘ridan-to‘g‘ri forma](https://www.agroventures.uz/application): pitch fayli 20 MBgacha; traction yo‘q bo‘lsa nol qabul qilinadi. Formada pul so‘rovi ham bor. Oferta alohida o‘qiladi; qabulning o‘zi pilot, xarid yoki investitsiya kafolati emas. [StartupBase e’loni](https://new.startupbase.uz/en/events/256) shu dasturga yo‘naltiradi. Telegram posti browser orqali o‘qilmadi; uning o‘ziga tekshirilgan manba sifatida tayanilmadi.

**Sardorbek yuborishi uchun tayyor, hali yuborilmagan xabar:**

> Assalomu alaykum. Men Sardorbek, BioLivestock AI asoschisiman. Qoramolni doimiy ID bilan ro‘yxatga olish, surat yig‘ish va egalik/o‘lim/so‘yish qaydlarini yuritish uchun dastlabki ishlaydigan MVP ishlab chiqilgan. Agrobank ekotizimida data collection va aktivlarni qayd etish bo‘yicha pilot taklif qilmoqchiman. Hozir yakka asoschiman. Sahifangizdagi 2–5 founder talabi majburiymi yoki solo founder arizasi ham ko‘rib chiqiladimi? Ariza berishdan oldin shu mezonni aniqlashtirmoqchiman. Rahmat.

Kontaktni rasmiy saytdagi aloqa bo‘limidan tekshir. Ushbu xabarni Codex yubormadi. Yakka founder uchun rozilik yoki kerakli haqiqiy jamoa bo‘lmaguncha eligibility tasdiqlandi deb yozilmaydi.

## Bankka qanday pozitsiyalash kerak

**Asosiy taklif:** qoramol aktivlari haqida izchil raqamli yozuv va qayta tekshirishga tayyor surat dalillarini yig‘ish; keyingi bosqichda noseprint asosidagi identity tekshiruvini real data bilan baholash.

Bu Agrobankka mosligi haqidagi **bizning gipotezamiz**, bankning tasdiqlangan buyurtmasi emas. Pilotda aniqlanadigan muammo: operator hayvonni takroriy tashrifda avvalgi yozuvga qanday bog‘laydi, kim qachon nimalarni qayd etgan, egalik/terminal hodisalar tarixi va dalillar qayerda saqlanadi? Bank xodimlari bilan suhbatlarsiz “Agrobank hozir aynan shuncha zarar ko‘ryapti” deyilmaydi.

Bugungi MVP bilan taklif qilish mumkin:

- Bitta canonical backenddan takror ishlatilmaydigan permanent ID; keyingi tashrifda o‘sha IDdan foydalanish.
- Telefonda kamera, lokal QC, oflayn saqlash va xavfsiz retry; keyin tekshiriladigan server originali.
- Ega tarixi, financial status, authenticated operator, GPS mavjud bo‘lsa joylashuv va vaqt qaydlari.
- O‘lim/so‘yish arxivi, optional uploaded capture UUID/hash va o‘zgartirilmaydigan tarix.
- Operator/adminga berilgan ruxsatlar, backup/restore va exact-image reuse review.

Bu funksiyalar physical identity, legal ownership, amaldagi garov yoki haqiqiy so‘yilganlikni mustaqil tasdiqlamaydi. Biometrik matching bo‘lmasdan boshqa fotosuratdagi ayni hayvonni avtomatik topish yoki ikki IDni birlashtirish va’da qilinmaydi. Internal MAA ID davlat birkasi emas; pilotda mavjud mustaqil ear-tag/ledger bilan bog‘lanadi.

## Arizaga qo‘yiladigan tayyor loyiha tavsifi

### O‘zbekcha

BioLivestock AI — qoramolni doimiy raqamli ID bilan ro‘yxatga olish va uning hayot sikliga oid suratli qaydlarni yig‘ish uchun ishlab chiqilayotgan AgriTech yechim. Dastlabki MVP telefonda kamera orqali sifat nazoratli surat olish, internet bo‘lmaganda saqlash, serverga qayta yuborishda nusxa yaratmaslik, egalik tarixi hamda o‘lim va so‘yish xabarlarini yuritishni qo‘llab-quvvatlaydi. Interfeys o‘zbek lotin/kirill, rus va ingliz tillarida mavjud.

Agrobank bilan taklifimiz — hamkor fermalarda aktiv yozuvlarining to‘liqligi, takroriy tashriflarda mustaqil birka bilan bog‘lanishi va tekshiruv jarayoni qulayligini o‘lchaydigan cheklangan pilot. Shu jarayonda keyingi cattle noseprint identifikatsiyasini baholash uchun tasdiqlangan hayvon/session suratlari yig‘iladi. Hozir biometrik aniqlik tasdiqlanmagan; uni real dala ma’lumotlari asosida tekshirish rejalashtirilgan. Pilot qarz yoki sug‘urta qarorini avtomatik qabul qilmaydi. Bizga farm hamkorlari, biznes jarayonini tushunadigan pilot egasi va field-validation yordami kerak.

Real hayvon suratlari hali yig‘ilmagan; hozirgi texnik tekshiruvlar asosan synthetic/mock ma’lumotlar bilan bajarilgan. Telefon mavjud, lekin native end-to-end dala sinovi hali tasdiqlanmagan.

### English

BioLivestock AI is an early-stage AgriTech product for persistent cattle registration and evidence-based livestock records. Its initial MVP supports camera-only capture, image-quality checks, offline storage, safe upload retries, ownership history, and reported death or slaughter events. The interface supports Uzbek Latin and Cyrillic, Russian and English.

We propose a limited pilot with partner farms to measure record completeness, independently tagged animal continuity across visits, and field-workflow usability. The pilot would also create a reviewed, multi-session muzzle dataset for evaluating future noseprint identification. Cattle biometric accuracy has not yet been validated, and recorded events do not independently prove physical identity or slaughter. The initial pilot will not automate lending or insurance decisions. We seek farm access, an operational pilot sponsor and support for field validation before wider deployment.

Real-animal image collection has not yet begun. Current technical checks primarily use synthetic data and mocks; physical-device field validation remains to be completed.

## Formani to‘ldirish uchun javoblar

Quyidagi matnlar formaga mos draft. Shaxsiy yoki tijoriy faktlar tasdiqlanmaguncha ularni to‘ldirib yuborma.

| Mavzu | Draft / kiritiladigan qiymat |
| --- | --- |
| Loyiha | BioLivestock AI |
| Rahbar va aloqa | Sardorbekning to‘liq F.I.O., telefon va emaili — tasdiqlanishi kerak; repo yoki taxmindan to‘ldirma. |
| Sektor | AgriTech; qo‘shimcha yo‘nalish sifatida AI. Formaning mavjud variantlaridan eng mosini tanlash. |
| Geografiya | O‘zbekiston — Sardorbek tasdiqlashi kerak. |
| Bosqich | Ichki tekshirilgan collection/registry MVP; physical-device va farm validation boshlanmagan. |
| Mahsulot matni | Yuqoridagi o‘zbekcha yoki inglizcha tavsif. Belgilar limitini forma ichida tekshirish. |
| Asoschilar | Hozir bitta: Sardorbek. Hamkor, AI assistant yoki kelajakdagi xodimni founder sifatida qo‘shma. Solo eligibility javobini ol. |
| Til ko‘nikmasi | Founderning haqiqiy English darajasi kerak; tarjima tayyorligi speaking fluency emas. |
| Real traction | Faol foydalanuvchi, to‘lovchi mijoz va tushum founder tomonidan tasdiqlanmagan. Haqiqatan yo‘q bo‘lsa 0; test operatorlari/SQL rows/test rasmlari hisoblanmaydi. |
| Kim foydalanadi | Pilotda fermadagi mas’ul operatorlar va aktiv monitoringi bilan shug‘ullanuvchi bank/hamkor tashkilot xodimlari. Buyer va byudjet egasi suhbatlarda aniqlanadi. |
| Tijoriy yo‘l | B2B dastur litsenziyasi/support va onboarding; keyinchalik tashkilot/aktiv hajmiga qarab narxlashni tekshirish. Hozircha to‘lovga tayyorlik tasdiqlanmagan; amaldagi SaaS/cloud shartnomasi yo‘q. |
| Oldingi dastur | Founder ma’lumoti kerak. Qatnashmagan bo‘lsa formaning ko‘rsatmasiga mos ravishda None. |
| Qatnashish vaqti | 12 haftaga haqiqiy vaqt/safar imkonini founder tasdiqlaydi; avtomatik Ha emas. |
| Nima uchun dastur | MVP field-test, biznes modelini tekshirish, farm/bank mutaxassislari bilan pilot va investment readiness. Mavjud bo‘lmagan regional expansion natijalarini yozma. |
| Havolalar | Faqat tekshirilgan demo/pitch/repo; GitHub’da lokal eng yangi commitlar bor deb taxmin qilma. Token, backend/.secrets, GPS/egalar ma’lumotlari yoki real backupni public link qilma. |
| E’lon manbasi | innoWIUT Entrepreneur’s Lab orqali ko‘rgan e’lon; formadagi variantga qarab aniq yozish. Universitet bilan affiliation bor deb da’vo qilma. |

**12 oylik natija matni — taklif etilayotgan maqsadlar, bugungi traction emas:**

> Dastlabki maqsad — ikki farmda 100 qoramol bilan uch tashrifli data-quality va registry pilotini yakunlash, kamida 1,800 ta alohida usable original suratni mustaqil animal/session labels bilan yig‘ish va review qilish. Keyin mavjud offline baseline uchun oldindan ajratilgan validation/test natijalarini hisoblash, operator jarayonining vaqt va xatolarini o‘lchash hamda tijoriy qiziqishni tekshirish. 12 oy ichida bitta pullik pilot yoki yozma xarid niyatiga erishishni maqsad qilamiz. Ferma, jamoa, data va xavfsizlik tayyorgarligi yetarli bo‘lsa keyingi mijozlarga o‘tish rejasini tuzamiz; bu kelishilgan shartnoma yoki kafolatlangan natija emas.

## So‘raladigan mablag‘: muhokama uchun variant

Formadagi dollar summasini faqat $500,000 e’lon qilinganiga qarab tanlamaymiz. Hozirgi bosqichga mos **$25,000 pre-seed / olti oylik validation byudjeti**ni dastlabki muhokama varianti sifatida taklif qilamiz. Bu Sardorbek tasdiqlagan pul so‘rovi ham, olingan quote ham emas. Equity, valuation yoki moliyalashtirish instrumenti belgilanmadi.

| Ish yo‘nalishi | Taxminiy draft, USD |
| --- | ---: |
| Field collection: tashrif/operator, qurilma va saqlash ehtiyojlari | 4,500 |
| Mobile/backend ishonchliligi va pilotga moslash | 8,000 |
| Mustaqil label/review va shartli ML evaluation | 6,000 |
| Pilot onboarding, qo‘llab-quvvatlash va mijoz intervyulari | 4,000 |
| Zaxira | 2,500 |
| Jami | 25,000 |

Haqiqiy muddat, contractor narxi, founderning o‘z ishi, safar va jihoz xarajatlari bilan qayta hisoblash kerak. Bir xil xarajatni ikki qatorda sanama. Ariza yuborishdan oldin summa va har bir assumption tasdiqlanadi. Bu draft hech qanday xarid yoki majburiyatga ruxsat emas.

## 12 haftalik pilot: taklif, hamkor bilan kelishilmagan

**Birinchi tor use case:** mustaqil ear-tag bilan bog‘langan qoramol yozuvlari va qayta tashrifdagi dalil yig‘ish jarayoni. Bank core tizimiga write/integration yoki avtomatik kredit qarori dastlabki scope emas. Hamkor ajratgan ruxsatli, izolyatsion pilot muhiti kerak; current local-dev token/HTTP yechimi bank production security approval o‘rnini bosmaydi.

| Hafta | Bizning taklif etayotgan ishimiz | Ko‘rsatiladigan natija |
| --- | --- | --- |
| 1–2 | Solo/team holatini hal qilish; bank/farm workflow intervyulari; pilot mas’uli, ma’lumotga ruxsat, xavfsizlik va o‘lchash protokoli; real telefonda smoke test | Kelishilgan tor use case, manual baseline va tekshirilgan device flow |
| 3–6 | Ikki farm/100 cattle rejasini imkoniyatga qarab bajarish; mustaqil roster, uch tashrif, har tashrifda olti surat; upload/QC va qo‘lda nose review | Dataset coverage hisoboti, crop→original UUID/session linkage; uncertain identity alohida chiqariladi |
| 7–8 | Registry/owner/history/offline oqimini operatorlar bilan tekshirish; data yetarli bo‘lsa mavjud frozen baseline orqali offline identity baholashi | Workflow xatolari va validation/test hisoboti; data yetmasa bu qism incomplete deb ochiq belgilanadi |
| 9–10 | Takroriy tekshiruv vazifasini oldingi qo‘lda usul bilan solishtirish, operator feedback, xarajat va tijoriy suhbatlar | Jarayon va buyer/willingness-to-pay dalillari; qarz qarorlariga ta’sir qilmaydi |
| 11–12 | Natijani tahlil qilish, qolgan cheklovlar, narx/tijoriy keyingi bosqich, demo material | Go/no-go tavsiya va pilot yakuniy hisoboti; haqiqiy bo‘lsa hamkor niyat xati |

100 hayvon — mavjud field guide’dagi birinchi pilot floor; rare false-accept xavfini isbotlaydigan production sample-size emas. Bank kerakli natijani boshqacha belgilasa protokol oldindan qayta kelishiladi. Hech qanday fake dataset, avtomatik reviewed=true, birka o‘rniga nose-similarity ground truth yoki synthetic suratni real traction deb ko‘rsatish yo‘q.

### Oldindan belgilash taklif etilayotgan mezonlar

- Barcha evaluation namunalari uchun mustaqil tag/session linkage; unresolved identity evaluationga kiritilmaydi. Hisobotda exclude qilinganlar va yo‘qolgan follow-up’lar soni ham bo‘ladi.
- Maqsad — hayvonlarning kamida 90%ida rejalangan uch tashrif yozuvi; 1,800 usable surat collection target. Erishilmagan qismi ochiq ko‘rsatiladi, copied frames bilan to‘ldirilmaydi.
- Field offline/restart/retry stsenariylarida original yo‘qotilishi, takroriy server record va o‘zgargan metadata kuzatuvi; har natija aniq urinishlar soni bilan. Kuzatilgan nol xato universal reliability kafolati emas.
- Tekshiruv vaqtini o‘lchash: bir xil vazifa va mustaqil roster bilan manual vs app median vaqt; dastlabki yaxshilanish maqsadi 25%, natija emas. Operator/learning-order farqi nazorat qilinadi.
- Kamida bitta operatsion buyer/pilot sponsor bilan natija review. Pullik pilot/LOI — maqsad; hali mavjud emas.
- Data yetarli bo‘lsa hayvonlar bo‘yicha disjoint train/validation/test, turli-session gallery/query va unknown cohort; threshold validationda freeze, testda FAR/FRR/wrong/unknown accepts counts bilan. “99% accuracy” yoki tasdiqlanmagan liveness/weight claim yo‘q.

## Arizagacha nima foydali: 100 mol topish shart emas

Birinchi navbatda solo eligibility aniqlanadi. Shu bilan parallel real telefonda native capture → oflayn/restart → upload/receipt va registry jarayonini test record bilan sinash mumkin. So‘ng ruxsatli **5–10 qoramol** bilan kichik field smoke test qilish foydali: kamera ishlaydimi, operator tumshuqni tiniq oladimi, QC sharoitga mosmi? Bu biometrik accuracy yoki to‘liq pilot natijasi emas.

Har hayvonga barqaror ID, mustaqil ear-tag tasdig‘i, vaqt/session va distinct rasmlar kerak. Qo‘llanma: [DATA_COLLECTION_GUIDE.md](DATA_COLLECTION_GUIDE.md). Model yo‘qligida pending_model tabiiy holat; demo’da guide rectangle’ni AI detector natijasi deb ko‘rsatma.

**Ichki tayyorgarlik jadvali:**

- 29–30-oktabr: solo eligibility xabari, founder kontaktlari va qatnashish imkonini aniqlash; phone smoke test.
- 31-oktabr–3-noyabr: imkon bo‘lsa ruxsatli kichik field sample, 3–5 customer discovery suhbat; bo‘lmasa ochiq pre-field status.
- 4–6-noyabr: founder tasdiqlagan application, pitch fayli va 60 soniya video; barcha claims tekshiruvi.
- 7-noyabr: ichki topshirish maqsadi; rasmiy deadline 9-noyabr. Aniq yopilish soati/timezone hali tasdiqlanmagan, oxirgi soatga qoldirmaslik.

## 60 soniyalik video uchun ssenariy

0–15s: “Men Sardorbek, BioLivestock AI asoschisiman. Pilotda tekshirmoqchi bo‘lgan muammomiz: qoramol aktivini qayta tashrifda avvalgi yozuvga bog‘lash va uning egalik/hodisa tarixini izchil yuritish.”

15–30s: “Bizning dastlabki MVP doimiy ID, kamera orqali sifat nazoratli surat yig‘ish, oflayn saqlash va tekshiriladigan operator tarixini qo‘llab-quvvatlaydi. Interfeys to‘rt til va yozuv variantida ishlaydi.”

30–45s: “Agrobank bilan hamkor fermalarda bank va fermer uchun qaysi yozuvlar foydali ekanini amalda sinashni istaymiz. Keyingi noseprint baholashi uchun mustaqil tasdiqlangan hayvon/session ma’lumotlari kerak; hozir biometrik aniqlikni tasdiqladik deb aytmaymiz.”

45–60s: “Dasturdan maqsadimiz — tor pilot, sifatli dataset va o‘lchangan workflow natijasi. Mentorlar va hamkorlar bilan texnik MVPni real mijoz ehtiyojiga moslab, tijoriy modelni tekshirmoqchimiz.”

Vaqt — ssenariy belgisi, measured speaking duration emas. Tabiiy ovoz bilan rehearsal qilinadi. Telefon ekranidagi haqiqiy oqimni ko‘rsatish yoki host demo ekanini aniq belgilash; mockni farm recording deb taqdim etmaslik kerak.

## Pitch fayli uchun kontent rejasi — deck hali yaratilmagan

1. BioLivestock AI va bankka taklif etilayotgan tor pilot.
2. Customer discovery’da tekshiriladigan muammo va kim foydalanuvchi/buyer.
3. Bugungi haqiqiy MVP oqimi va ko‘rinadigan demo.
4. Farm operatoridan bank review’gacha qiymat gipotezasi; kredit qarorini almashtirmaydi.
5. Tayyor / synthetic-only / real dataga blocked funksiyalar.
6. 12 haftalik pilot, ruxsatli farm access va independent ground truth.
7. KPI va false-claim qilmasdan o‘lchanadigan natijalar.
8. B2B tijoriy model, haqiqiy traction bo‘lmasa nol va customer discovery rejasi.
9. Founderning haqiqiy tajribasi va solo eligibility / mavjud skill gaplar; fake cofounder yo‘q.
10. Hamkorlik so‘rovi, draft byudjet va keyingi bosqich uchun go/no-go.

Bu outline — tayyor PPTX/PDF emas. Shaxsiy/jamoa faktlari, eligibility, money ask va telefon demo tasdiqlangandan keyin upload qilinadigan deck tayyorlanadi. TAM/revenue/fraud reduction foizlari uchun manba yoki real pilot data bo‘lmasa raqam qo‘yilmaydi.

## Keyingi review uchun yetishmayotgan faktlar

Founderning to‘liq F.I.O./kontaktlari, joylashuvi, haqiqiy tajribasi va English darajasi; 12 haftaga qatnashish imkoniyati; real foydalanuvchi/to‘lov/tushum sonlari; oldingi dasturlar; solo eligibility javobi; ferma bilan ruxsatli kelishuv va phone smoke-test natijasi; $25k varianti yoki boshqa asoslangan byudjet bo‘yicha qaror. Bu bo‘shliqlar tasdiqlanmaguncha application submission qilinmaydi. Hech kimga Codex nomidan yoki Sardorbek nomidan xabar yuborilmagan.
