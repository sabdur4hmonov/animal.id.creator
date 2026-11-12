# Chorvam — taqdimot uchun haqiqiy holat

Kod ko‘rib chiqilgan sana: **2026-11-13**. Yakuniy test/APKlar 2026-11-12da
tugagan: 210 Flutter va 253 backend testi, analyzer/Ruff yashil; APK hash va
bundle tarkibi 2026-11-13da qayta tekshirildi. Deck: Sardorbek bergan
“Chorvam — har bir molga raqamli pasport” (15 sahifa). Shaxsiy kontaktlar
bu hujjatga ko‘chirilmagan. PDF o‘zgartirilmagan.

**Hozir** = kod va test mavjud; bu dala aniqligi yoki ishlab chiqarish kafolati
emas. **Sinovda** = hisoblash/signal bor, amaliy foyda yoki aniqlik o‘lchanishi
kerak. **Rejada** = mahsulot va’dasi hali amalga oshmagan. Quyidagi dalillar
repo ichidagi fayllar; test rasmlari va server yozuvlari sintetik.

| Deckdagi imkoniyat | Holat va aniq chegarasi | Kod / tekshiruv dalili |
|---|---|---|
| Tumshuqni kamerada olish, xira/qorong‘i kadrni tekshirish | **Hozir:** native kamera, 4 soniyali kadrlar to‘plami, eng tiniq 3 JPEGgacha; MP4 yozilmaydi. Haqiqiy dala reject chegaralari kalibrlanmagan. | `mobile/lib/burst_capture.dart`, `quality_control.dart`; `mobile/test/burst_capture_test.dart`, `burst_screen_test.dart`; `backend/tests/test_quality.py` |
| Mol IDsi va profil/rasmlar tarixi | **Hozir:** lokal L-ID, birka/laqab, suratlar, o‘lchov/tarozi tarixi. Kanonik server MAA-seriyasi, reset/reuse yo‘q. ID raqami biometrik isbot emas. | `mobile/lib/field_store.dart`, `local_profiles.dart`, `profile_views.dart`; `mobile/test/field_home_test.dart`; `backend/tests/test_registry.py` |
| Qayta skanda o‘sha molni topish | **Sinovda:** oflayn ORB geometrik signal, top nomzodlarni odam tasdiqlaydi; avtomatik ID tanlash/birlashtirish yo‘q. Haqiqiy TP/FP/FN va tezlik hali o‘lchanmagan. | `mobile/lib/advisory_scan.dart`; Android `AdvisoryOrb.kt`; `mobile/test/advisory_scan_test.dart`; `business_configs/cattle.yaml` |
| Chuqur AI/biometrik matching | **Rejada (mahsulotda):** `research/`da alohida offline embedding/evaluation vositalari bor. Tayyor model, ishlab chiqarish endpointi yoki tekshirilgan aniqlik yo‘q. | `research/biolivestock_research/embedding.py`, `matching.py`; `research/tests/test_embedding.py`, `test_matching.py` |
| Tumshuqni avtomatik kesish | **Sinovda:** species-aware YOLO wrapper bor; trained muzzle checkpoint yo‘q, sifatdan o‘tgan original `pending_model` saqlanadi. Oddiy cow detector nose modeli o‘rniga ishlatilmaydi. | `backend/app/services/detection.py`, `species_configs/cattle.yaml`; `backend/tests/test_quality.py`; `tools/verify_pilot_deployment.py` |
| Internetsiz ishlash va kechqurun serverga yuborish | **Hozir:** lokal saqlash, ZIP/CSV, muzlatilgan idempotent so‘rovlar, qo‘lda L→MAA va upload. Avtomatik fon sinxronlash yo‘q. Rasmlar, sog‘liq, egalik va profil xulosalari alohida yuboriladi. | `mobile/lib/offline_queue.dart`, `local_registration.dart`, `profile_sync.dart`; `mobile/test/local_registration_test.dart`, `profile_sync_test.dart`, `queue_backup_test.dart` |
| Molning butun hayoti/tug‘ilish/o‘sish grafigi | **Rejada:** hozir ayrim tarixlar bor; maxsus tug‘ilish qaydi, to‘liq o‘sish grafigi va farm-to-table mahsulot partiyasi zanjiri qurilmagan. | Mavjud chegarasi: `mobile/lib/profile_views.dart`, `health_records.dart`, `ownership_records.dart`; alohida birth/growth moduli yo‘q |
| Kasallik, emlash, davolash, veterinar ko‘rigi | **Hozir:** oflayn append-only hodisalar va tuzatuvchi qaydlar, MAA uchun idempotent sync. Tasdiqlangan belgi faqat serverning `veterinar` roli yozganida; ism kiritishning o‘zi tasdiq emas. Tashxis modeli yo‘q. | `mobile/lib/health_records.dart`, `health_screen.dart`; `backend/app/api/health.py`; `mobile/test/health_sync_test.dart`; `backend/tests/test_health.py`, `test_roles.py` |
| Kimdan kimga sotilgani/egalik | **Hozir:** ega ID/ism, sana, ixtiyoriy butun UZS narx, izoh; append-only tarix va server expected_version nazorati. Huquqiy mulk reyestriga integratsiya emas. | `mobile/lib/ownership_records.dart`, `ownership_screen.dart`; `backend/app/api/registry.py`; `mobile/test/ownership_records_test.dart`; `backend/tests/test_ownership_sale.py` |
| Ilova ichida savdo bozori/to‘lov | **Rejada:** savdo qaydi marketplace, e’lonlar, escrow yoki to‘lov tizimi degani emas. | Mavjud modul chegarasi: `ownership_records.dart`; marketplace/payment moduli yo‘q |
| O‘lim va so‘yish qaydi | **Hozir:** terminal holat, ID va oldingi rasmlar saqlanadi; mol jismonan so‘yilganini mustaqil isbotlamaydi. | `backend/app/api/registry.py`; `backend/tests/test_registry.py`; `mobile/test/animal_registry_test.dart` |
| Go‘sht QR tekshiruvi | **Hozir:** tasodifiy bekor qilinadigan kod, QR ulashish, public sahifa faqat ID/so‘yish sana/facility/oxirgi tasdiqlangan vet ko‘rik. Ega/GPS/narx yashirin. Laboratoriya tahlili yoki oziq-ovqat xavfsizligi kafolati emas. Ochiq domen hali yo‘q. | `backend/app/api/public_verification.py`; `mobile/lib/verification_codes.dart`; `backend/tests/test_public_verification.py`; `mobile/test/verification_codes_test.dart`; TLS Docker proof |
| Vaznni o‘lchash va go‘sht qiymati | **Sinovda:** Trukhanovsky/Schoorl matematikasi, fast/contour/same-frame-depth snapshot, repeat qoidasi, bozor narxi va carcass yield ssenariylari bor. Tarozi korreksiyasi versiyali; rejimlar aralashmaydi. Haqiqiy aniqlik kalibrlanmagan; yon suratning o‘zidan vazn chiqarilmaydi, AR hamma telefonda ishlamaydi. | `mobile/lib/ar_math.dart`, `depth_snapshot.dart`, `ar_records.dart`; `mobile/test/depth_snapshot_test.dart`, `ar_records_test.dart`, `snapshot_screen_test.dart`; `backend/tests/test_valuation.py`; `business_configs/cattle.yaml` |
| Garov/sug‘urta, bank monitoringi | **Hozir:** ruxsatli moliyaviy status qaydi, sabab/version/audit, private panel. **Rejada:** bank/sug‘urta API, avtomatik kredit qarori, polis yoki to‘lov. Kredit olishni kafolatlamaydi. | `backend/app/api/panel.py`, `registry.py`; `backend/tests/test_panel.py`, `test_roles.py`; `docs/ACCESS_ROLES.md` |
| Foydalanuvchilar va hamkorlar kirishi | **Hozir:** 5 rol, Argon2 parol, Secure/HttpOnly cookie, CSRF, urinish cheklovi, CLI foydalanuvchilar, UZ/RU panel. Bitta kelishilgan pilot doirasi; ko‘p bankli tenant isolation hali yo‘q. | `backend/app/core/roles.py`, `backend/app/api/login.py`, `tools/manage_users.py`; `backend/tests/test_roles.py`, `test_panel.py` |
| Aldov/liveness/GPS tekshiruvi | **Sinovda:** Moiré/reflection/boundary va root/emulator/mock-GPS review signallari. Liveness `not_assessed`; haqiqiy hayvon yoki go‘sht tasdig‘i emas. Nafas/mikroharakat modeli dataset kutmoqda. | `backend/app/services/anti_spoofing.py`; `backend/tests/test_anti_spoofing.py`; `docs/ANTI_SPOOF_GROUNDWORK.md` |
| Davlat birkasi va registrlar bilan ishlash | **Rejada:** birka matni saqlanadi, lekin UzChorva/VIS-CHINOR/davlat/bank reyestrlariga integratsiya yo‘q. Davlat IDsi o‘rnini bosmaydi. | `mobile/lib/field_store.dart`, `backend/app/api/panel.py`; tashqi registry connector yo‘q |
| Qo‘y va echki | **Rejada:** sheep enum/config tayyor, disabled. Qo‘y dataset/modeli va dala kalibratsiyasi kerak; echki hozirgi enumda ham yo‘q. | `species_configs/sheep.yaml`, `business_configs/sheep.yaml`; generic species konfiguratsiya testlari |
| To‘rt til, yo‘riqnoma va namoyish | **Hozir:** uz-Latn/uz-Cyrl/RU/EN; 4 qadamli guide, alohida `.demo` NAMUNA, 6 original chizma; demo upload yo‘q. Bu farm accuracy dalili emas. | `mobile/lib/field_guide.dart`, `demo_home.dart`, `app_mode.dart`; `mobile/test/field_guide_test.dart`, `demo_mode_test.dart`; APK manifest/network permission tekshiruvi |
| Pilot server, zaxira va monitoring | **Hozir (tayyorlash):** HTTPS Compose, file secrets, restore tekshiruvi, log aylanishi, monitor va UZ runbook. Lokal ajratilgan Docker/TLS/PostgreSQL tekshirildi. **Rejada:** haqiqiy server/domen, off-site saqlash va production yuklama sinovi. | `backend/docker-compose.prod.yml`; `tools/pilot_backup.py`, `pilot_monitor.py`, `verify_pilot_deployment.py`; `backend/tests/test_pilot_deployment.py`; `docs/DEPLOY_RUNBOOK.md` |

## Deckda ishlatish mumkin bo‘lgan qisqa gap

“Chorvamning oflayn yig‘ish MVPsi qurilgan: surat, ID, profil, sog‘liq/egalik
tarixi, qo‘lda tasdiqlanadigan qayta skan signali va hamkorlar paneli bor.
Biometrik tanish va vaznning dala aniqligini pilotda o‘lchaymiz.”

## Tajriba va biznes raqamlarini aytish qoidasi

- Founder xabari: **2026-11-06** kuni harakat/xiralik sabab ikki haqiqiy molda
  to‘liqroq sinab ko‘rilgan. Urinishlar va to‘g‘ri/noto‘g‘ri natijalar sanalmagan.
  “6-noyabr” — sana; “6 mol muvaffaqiyatli tanildi” yoki foiz deyilmaydi.
- 2 ferma / 100 mol / 3 tashrif / 90% qayta topish — taklif etilgan pilot
  **maqsadlari**, bajarilgan natija emas. TP, missed, false warning va vaqtni
  qo‘lda tasdiqlangan ID bilan har urinishda yozing; denominatorlarni ko‘rsating.
- $30,000 — so‘ralayotgan byudjet; olingan investitsiya emas. Agrobank bilan
  amaldagi shartnoma yoki pullik mijoz borligi tasdiqlanmagan.
- Deckdagi bozor statistikasi va dastur muddatlari alohida sanali manbalardan;
  ushbu kod auditi ularni bugungi holat sifatida qayta tekshirmagan.
- Eng yangi APKlar telefonda tekshirilmagan. Lokal test, sintetik Docker proof
  va founderning avvalgi dala xabari bir xil darajadagi dalil emas.

Keyingi dala vazifalari: haqiqiy mollarni birka bilan bog‘lab, ikki sessiyada
JPEGlar va qayta skan qarorlarini yig‘ish; tiniqlik/rad etish/vaqtni sanash;
mustaqil tarozi va o‘lchovlarni yozish. Pul/akkaunt talab qiladigan server va
hamkor ruxsatlari kelishilgach runbook orqali alohida deploy qilinadi.

Litsenziya chegarasi: backenddagi avvaldan mavjud Ultralytics AGPL/Enterprise
variantlarida; butun stackni GPL/AGPL-free deb bo‘lmaydi. Yangi copyleft paket
qo‘shilmadi. Tijoriy detector uchun litsenziya/mahsulot qarori Sardorbekniki;
hech narsa sotib olinmadi yoki qayta litsenziyalanmadi. Manba: [upstream
litsenziya sahifasi](https://www.ultralytics.com/license).
