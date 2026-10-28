Sen BioLivestock AI loyihasini davom ettirayotgan coding agentsan. Quyidagi kontekstni loyiha bo‘yicha yagona boshlang‘ich topshiriq sifatida qabul qil. Avval mavjud ishni tushunib ol; loyihani boshidan yaratma va tayyor modullarni qayta yozma.

1. LOYIHA, EGASI VA JORIY HOLAT

Loyiha: BioLivestock AI. Egasi: Sardorbek. U bilan asosan o‘zbekcha, oddiy va aniq muloqot qil. Loyiha Windows’da D:\Coding projects\moliddetector papkasida. Git remote origin: https://github.com/sabdur4hmonov/animal.id.creator.git.

Git repo va commit history allaqachon mavjud. Git init/initial scaffoldni takrorlama, historyni rewrite/reset qilma va oldingi ma’lum commitga majburan checkout qilma.

Maqsad: dastlab qoramol tumshuq/noseprint suratlarini sifatli yig‘ish, keyin ishonchli ma’lumotlar asosida biometrik identifikatsiya/matching, liveness, vazn/baholash va kelajakda qo‘ylarni qo‘shish. Qassobxonada ID bo‘yicha egasi va so‘yish qaydini ko‘rish ham talab qilingan. Hozirgi qaydlar haqiqiy hayvonning biometrik shaxsini yoki amalda so‘yilganini mustaqil isbotlamaydi.

Ushbu handoff 2026-10-29, Asia/Tashkent sanasida loyiha fayllari va jonli git tekshiruvi asosida tayyorlandi. Handoffdan oldingi HEAD: 3a960fc; working tree toza edi. Cached origin/main bilan remote-only/local-only: 0/22; bugun fetch/push qilinmadi, shuning uchun GitHub’dagi hozirgi holat tasdiqlangan deb aytma. Handoff hujjati keyingi documentation commit bilan qo‘shilishi mumkin; haqiqiy HEADni git orqali tekshir.

Oxirgi to‘liq kod/test/build tekshiruvi 2026-10-14. 29-oktabrda kod o‘zgartirilmadi va testlar qayta bajarilmadi. Flutter SDK launcher hozir ham C:\src\flutter\bin\flutter.bat manzilida mavjud. APKning joriy SHA-256 qiymati quyidagi tarixiy build bilan mosligi 29-oktabrda qayta tekshirildi.

2. HAR SESSIYADA ISHLASH QOIDALARI

Avval rootdagi D:\Coding projects\moliddetector\PROGRESS.md va mavjud bo‘lsa AGENTS.md ni o‘qi. Root PROGRESS.md — asosiy persistent memory; docs/PROGRESS.md tarixiy yo‘naltiruvchi. Keyin git status, git log, tegishli kod/config/docsni jonli tekshir. Eski progress ichidagi “latest”, test sonlari yoki “hali yo‘q” gaplarini yangi bo‘lim va haqiqiy kod bilan solishtir: hujjatda tarixiy milestone’lar ham saqlangan.

Sardorbek oddiy qarorlar uchun qayta-qayta savol berilishini istamaydi. Reversible kod tuzatish, refaktor, test va kutubxona/fayl tuzilishi qarorlarini o‘zing qil, sababini PROGRESS.md ga yoz. Haqiqiy yangi talab bo‘lmasa ishlayotgan kodga keraksiz feature yoki test qo‘shma. Topilgan xatolarni dalil bilan tuzat; “100% hamma narsa tayyor” yoki real accuracy tasdiqlandi deb da’vo qilma.

Muhim milestone’larni lokal aniq nomli commit qil. GitHub’ga avtomatik push qilma; Sardorbekning oldingi bir martalik push ruxsati doimiy ruxsat emas. Pul, tashqi akkaunt/credential, litsenziya ruxsati, data o‘chirish, breaking schema/live cutover yoki hujjatlar hal qilmagan katta mahsulot tanlovi zarur bo‘lsa so‘ra. Sirlarni terminalga yoki javobga chiqarmagin. Kod kommentlari inglizcha, funksiyalar kichik va testlanadigan bo‘lsin.

Har sessiya oxirida va kontekst tugashidan oldin PROGRESS.md ni yangila: nima qurildi, nima bajarib tekshirildi, nima faqat mock/synthetic, blockerlar, keyingi aniq qadam, qarorlar va git holati. Fizik telefonni yoki real datasetni kod bilan almashtirib bo‘lmaydi. Telefon yo‘qligi backend ishlariga to‘sqinlik qilmaydi. Zarur yangi ish qolmagan bo‘lsa shunchaki to‘xta va faktlarni xabar qil; vaqt to‘ldirish uchun feature yaratma.

3. ROADMAP VA KEYINGI TALABLAR

docs/ROADMAP.md besh bosqichni belgilaydi:
- Phase 1: cattle kamera capture, QC, muzzle detection/crop, strukturali lokal data yig‘ish va threshold kalibratsiyasi.
- Phase 2: reviewed cattle dataset, embeddings/matching, train/validation/test ajratish, FAR/FRR va noma’lum hayvonlar bilan baholash; production vector-search tanlovi natijalardan keyin.
- Phase 3: real genuine/attack videolar, liveness/anti-spoofing va o‘lchangan xato darajalari.
- Phase 4: real o‘lcham/vazn va bozor ma’lumotlari bilan weight/valuation kalibratsiyasi.
- Phase 5: sheep dataset/model/config kalibratsiyasi, keyin ikki tur bilan pilot.

Dastlab faqat Phase 1, auth/B2B/liveness/weight va matching yo‘q bo‘lishi so‘ralgan. Keyin Sardorbek datasetga bog‘liq bo‘lmagan auth/admin/B2B, deterministic weight math, advisory anti-spoofing va offline research groundwork’ni alohida ruxsat bilan qo‘shdirgan. Shuning uchun mavjud qo‘shimchalarni “Phase 1 scope buzilgan” deb olib tashlama. Biroq qolgan matching/embedding model ishini real labeled data bo‘lmasdan kengaytirma; yangi sheep modeli yoki sheep crop logic yozma. Cloud, production rollout va CI/CD hali kiritilmagan.

4. STACK VA REPO XARITASI

- Mobile: Flutter, faqat native camera plugin; gallery picker yo‘q. Android/iOS scaffold bor, desktop/web capture yo‘q. Geolocator, Dart local QC, filesystem queue, ZIP export/share mavjud.
- Backend: FastAPI/Python, SQLAlchemy, PostgreSQL 16, Alembic, OpenCV, Ultralytics YOLOv8n detection wrapper; Docker + Compose. CPU runtime, GPU talab qilinmaydi.
- Storage: filesystem original/crop rasmlar + PostgreSQL metadata. Production vector DB yo‘q.
- Flutter pinned versiya: 3.47.5 / Dart 3.13.4; SDK C:\src\flutter. Python .venv\Scripts\python.exe. Python/PostgreSQL image digestlari, Linux CPU dependency lock, apt pinlari va pubspec.lock mavjud. Windows venvga Linux requirements-docker.lock ni o‘rnatma. OpenCV distributivlarini parallel o‘rnatib cv2 konfliktini qaytarma. Asossiz dependency upgrade qilma.
- mobile/android/gradle.properties ichidagi kotlin.incremental=false saqlansin. Bu loyiha D: va Gradle/Pub cache C: bo‘lganda Kotlin “this and base files have different roots” crashini tuzatadi. Flutter SDK hozir o‘rnatilgan; “SDK install pending” — eski tarixiy holat.

Repo:
backend/app/api, core, models, services, schemas, main.py; backend/alembic/versions; backend/tests; Dockerfile, docker-compose.yml va requirements fayllari.
mobile/lib, mobile/test, mobile/tool, mobile/assets/l10n.
species_configs/cattle.yaml va sheep.yaml; business_configs/; security_configs/.
models/<species>/ — ignored model binaries; backend/app/models/ esa SQLAlchemy modellaridir.
research/ — alohida offline tajribalar, configs, templates va tests.
tools/ — credentials init, backup/reconcile/restore, phone ZIP recovery, research CLI va Docker verification.
docs/ — roadmap, architecture, field guide, data requirements, security, valuation, anti-spoof, registry, design, languages, audit/validation.
data/, .env, .secrets/, real images, weights, local DB, build outputs, venv, IDE/cache fayllari gitignore’da. Ularni commit qilma. Hozir yangi AGENTS.md topilmadi; kelajak sessiyada yana tekshir.

5. SPECIES CONFIG PATTERN — QAYTA MUHOKAMA QILINMAYDIGAN QAROR

species enum/field = cattle | sheep backend, mobile, metadata, research va DB bo‘ylab mavjud. Cattle enabled; sheep enabled:false. Model, crop, QC, numbering, business va security parametrlari species bo‘yicha YAML’da. Ikkinchi tur keyin config/model qo‘shish va kalibratsiya bilan ishlashi kerak; alohida ishlov berish code path yaratma. UI tarjima label’i species API qiymatini o‘zgartirmaydi. Sheep config borligi sheep funksiyasi amalda yoqilgan degani emas.

6. CAPTURE, QC, DETECTION VA METADATA — QURILGAN

Oqim: native live camera → capture → local advisory QC → durable offline queue → authenticated idempotent multipart upload → server validation/QC → optional muzzle detection/crop va crop QC → filesystem/PostgreSQL.

Asosiy endpointlar: GET /health; GET /api/v1/species; POST /api/v1/captures. Upload multipart image va JSON-string metadata oladi: animal_id, species, timezone-aware timestamp, operator_id, nullable gps; optional device_signals/gps_evidence. Operator credential principaliga mos bo‘lishi shart. Capture time UTCga normalize qilinadi; GPS yo‘q bo‘lsa null, to‘qima koordinata yo‘q. Server receipt time, quality metrics, config snapshot, hashes, paths va detection provenance qo‘shadi. Session/farm/camera/tag/view — alohida ledger/research maydonlari; ularni bilmasdan strict upload JSONga qo‘shma.

Original storage: data/<species>/<animal_id>/<UTC-date>/<capture-uuid>_original.jpg. UUID overwrite’ni oldini oladi. JPEG/PNG, default limit 15 MiB va 25 million decoded pixel. EXIF orientation qo‘llanadi, server normalized JPEG’dan EXIFni olib tashlaydi. Portable animal ID 1–64 ASCII harf/raqam/underscore/hyphen, birinchi belgi alphanumeric; Windows reserved nomlar/path traversal rad etiladi.

Joriy cattle.yaml: config_version=3; original short side >=480, long side >=640; blur analysis max dimension=640, Laplacian variance minimum=100; grayscale mean 40–215; dark pixels <=25 va bright >=230 ulushi har biri <=0.6. Lighting histogram original oriented pixelsdan; faqat blur analysis resize qilinadi. Mobile check advisory, backend yakuniy. Quality score identity confidence emas, field kalibratsiya hali kerak. Pose/occlusion uchun fake tekshiruv yaratma.

YOLO: models/cattle/yolov8n-muzzle.pt, class_name=muzzle, confidence=0.5, image_size=640. Aynan bitta muzzle kerak; box minimum128x128, frame area >=1%, edge clearance >=1%, padding10%. Crop quality ham tekshiriladi. Configlar manba, ushbu promptdagi qiymatlarni code’ga hardcode qilma.

Haqiqiy trained cattle muzzle checkpoint hali berilmagan. Qaror qat’iy: original QCdan o‘tsa crop_status=pending_model, crop_path=null, fake crop/detection yo‘q. Generic COCO cow box nose detector emas. YOLO avtomatik weight download qilmaydi. Noto‘g‘ri class/buzuq mavjud model 503, no/multiple muzzle yoki framing/crop QC xatosi 422. Model qo‘shilsa yangi uploadlarda ishlaydi; old pending rasmlar avtomatik reprocess qilinmaydi.

Yuklashdan oldin/keyin checkpoint hash/fingerprint tekshiriladi; yuklash vaqtida almashtirilsa noto‘g‘ri provenance yozish o‘rniga 503. Model inference serialize qilinadi; har checkpoint path uchun eski cache versiyalari yig‘ilib qolmaydi.

7. OFFLINE, IDEMPOTENCY, STORAGE VA RECOVERY — QURILGAN

Settings bir marta serverdan cache qilinadi. Local-QC-passing surat application-support storage’da original bytes + immutable metadata + stable random request key bilan saqlangandan keyingina “Saved on this phone” ko‘rinadi. Offline collect/next/restart recovery ishlovi bor. Upload qo‘lda; background uploader/automatic purge yo‘q. Uploaddan keyin ham originals/receipts qoladi.

Bir capture’ni retry qilganda aynan bir bytes, metadata, backend/operator scope va Idempotency-Key ishlatiladi. PostgreSQL append-only upload receipts/transaction locks parallel retry’ni bir capture/UUIDga bog‘laydi. O‘sha key/body replay eski response’ni qaytaradi; o‘zgargan payload 409. Timeout yangi key yaratish sababi emas. Eski keyless klient safe replay kafolatiga ega emas. Mobile backend capability’ni tekshiradi.

Typed journal har faylni alohida validate qiladi; corruption sog‘lom entry’larni yashirmaydi. Boshqa operator/backend yozuvlari, missing/corrupt/partial fayllar review uchun saqlanadi. Pending va receipts 50 tadan paging. 1,800 synthetic 64 KiB queue payload bilan host benchmark bajarilgan; phone tezligi yoki real-photo memory isboti emas.

Server fsync/commit tartibi va uncertain COMMIT handling tuzatilgan. COMMIT acknowledgement noaniq bo‘lsa evidence saqlanadi; retry/reconcile qilinadi. Filesystem+SQL mutlaq atomic emas; orphanlarni avtomatik o‘chirma. Receipt replay original hash/crop mavjudligini tekshiradi. Symlink/junction/path redirect yozishdan oldin rad etiladi.

Phone backup: verified ZIP, original/journal/upload va registry receipts, corrupt/partial evidence; credentials/settings chiqarilmaydi. ZIPni native share orqali appdan tashqariga saqlash kerak; app ichidagi temporary export ikkinchi durable nusxa emas. tools/phone_backup.py verify/extract faqat evidence recovery; live queue/DB’ni avtomatik almashtirmaydi yoki upload qilmaydi.

tools/collection_storage.py reconcile read-only; backup PostgreSQL dump, capture index, configs va evidence files oladi; har fayl hash tekshiriladi. Restore faqat yangi biolivestock_restore_* database va absent storage destination’ga. Live cutover avtomatik emas. Restore faqat row count emas, barcha copied file hashes, capture index va kerak bo‘lsa registry/audit row contents bilan tekshiriladi. Old nusxalarni yoki orphanlarni o‘chirma; docker compose down -v ishlatma.

8. PERMANENT ID, EGALIK, O‘LIM VA SO‘YISH — QURILGAN

Sardorbek “mol olganda” deganda o‘lganda deganini aniqlashtirgan; death bilan sale’ni almashtirma. Egasini o‘zgartirish alohida.

Yangi cattle ID: MAA00000001…MAA99999999, keyin MAB00000001; MAZ… dan MBA…; oxiri MZZ99999999. M + AA..ZZ + 8 raqam = 11 belgi. 676 blok, har biri99,999,999; maksimum67,599,999,324 ID. Chegarada 503, wrap/reset/reuse yo‘q. Eski M00000001 yoki boshqa valid legacy IDlarni o‘zgartirma. Bir prefix’ning mavjud 64-bit ordinal counter’i davom etadi; bo‘sh raqamlar bo‘lishi mumkin. Sheep S-prefiksi configda, disabled.

Faqat bitta canonical backend/DB ID beradi. Mustaqil test/restore DB’lardan haqiqiy ID bermagin. Live counter/prefix/width/seriesni reset qilma yoki asossiz o‘zgartirma. Eski backupdan yozishga qaytish keyin chiqarilgan IDlar bilan reconciliation talab qiladi. Unique number bitta fizik hayvonga ikki xil ID berilmaganini biometrik tasdiqlamaydi.

Alembic head0005 additive: animal_number_counters, animal_profiles, registry_receipts; old captures/IDs qolgan. Migrationlar0001 capture,0002 registration/evidence,0003 rates,0004 upload receipts,0005 registry. Destructive schema almashtirish kerak emas.

POST /api/v1/registry/animals: species + owner{owner_id,name} → permanent ID. GET list/detail; POST /animals/{species}/{id}/owner; POST .../retirement; GET .../history; GET .../slaughter-check. Owner/death/slaughter mutationlar key, expected_version, aware observed_at, nullable GPS, reason bilan. slaughtered uchun facility_id kerak; optional capture_id matching permitted uploaded frame’ga bog‘lanadi, UUID/hash saqlanadi. Local request key capture UUID emas.

Lifecycle active/deceased/slaughtered. O‘lim/so‘yish active ro‘yxatdan arxivga o‘tkazadi; physical delete, ID reuse yoki reactivation yo‘q. Old photos/owners/history saqlanadi. Financial status alohida; arxiv loan/insurance’ni avtomatik yopmaydi. Kechikkan old capture arxivdagi mavjud IDga evidence sifatida upload bo‘lishi mumkin, hayvon qayta faol bo‘lmaydi.

Original registrar/admin o‘zgartira oladi; trusted authenticated operatorlar lookup qiladi. Owner refs account/legal title/consent proof emas. slaughter-check — registry record only, biometric_identity_verified=false va independent_slaughter_verified=false.

Mobile register/lookup/owner/death/slaughter/archive/history mavjud. Issued ID foydalanuvchi tasdiqlamaguncha saqlanadi; lost response/restart boshqa yangi ID chiqarmaydi. Registry journal original body/GPS/time/key’ni retry’da saqlaydi; known rejections fresh review talab qiladi. Cross-instance UI-isolate guard, expected_version race protection, one-query coherent snapshots, failed lookup old positive card’ni tozalash, refresh, history paging va capture UUID attachment tuzatilgan.

9. AUTH, B2B/G2B VA MINIMAL ADMIN — QURILGAN, CHEGARALARI ANIQ

Local operator/admin bearer keys, serverda SHA-256 hash, ignored backend/.secrets/ ichida credentials fayllari. tools/init_local_credentials.py bir marta ishga tushiriladi; mavjud keylarni regenerate/overwrite qilma. Mobile’ga faqat operator key. /api/v1/* protected; /health va API docs/schema public. Credentials bo‘lmasa fail closed. Bu production login/account/tenant/agency integration emas; development compile-time token binary’dan olinishi mumkin. Public production deployment hali vazifa emas.

Animal financial status = open / insured / collateral. Admin expected_version + reason bilan o‘zgartiradi; audit append-only. Registration existing species/id bo‘lsa409. Exact oriented-pixel image reuse duplicate review case yaratadi; same-key upload retry o‘zi qo‘shimcha case yaratmaydi. Fingerprint concurrency himoyasi va stored-file integrity endpoint bor. Admin cases’ni flag/confirm/dismiss/reopen qiladi. Bu near-duplicate/biometric matching emas; boshqa rakursdagi bir hayvonni avtomatik topmaydi, identities merge yoki rasmlarni delete qilmaydi.

Minimal admin UI — Swagger /docs → Authorize. Mavjud routes: /api/v1/animals va /{species}/{id}/status; /api/v1/admin/duplicates; /api/v1/admin/audit; /api/v1/admin/captures/{uuid}/integrity. Captures, audit va receipts uchun append-only DB guards mavjud. Immutable GPS/time/operator metadata haqiqiy GPS yoki ishonchli hardware isboti emas.

10. WEIGHT/VALUATION VA ANTI-SPOOF GROUNDWORK — QURILGAN, EMPIRIK TASDIQ YO‘Q

Weight engine oddiy suratdan trained vision prediction qilmaydi. Adult cattle uchun supplied cm yoki calibrated_3d geometry:
- Trukhanovsky (“Truxanov” talqini): chest girth cm × straight body length cm × breed factor /100; dairy2, beef2.5.
- Schoorl: (chest girth cm +22)^2 /100.
- Cattle carcass scenario50–58%; sheep45–52% faqat disabled config. Carcass kg = live kg × yield; scenario value = carcass kg × carcass price/kg. Bu boneless-meat yield yoki confidence interval emas.

3D pipeline ma’lum uzunlikdagi reference, body endpoints va ordered closed chest contour oladi. Low confidence, zero scale, repeated/collinear/self-intersecting/non-planar geometry rad qilinadi; points avtomatik reorder/hull qilinmaydi. Oddiy 2D nose/side photo’dan chest girth yoki3D o‘ylab topilmaydi.

Decimal money, explicit currency, versioned append-only carcass price rate + source/time/config snapshot. Admin POST /api/v1/admin/market-rates; GET /api/v1/market-rates/{species}; POST /api/v1/valuation. Real price seed/feed yo‘q; missing rate409; quote concurrency expected_latest_id bilan. Real scale weights, anatomy/geometry calibration va bozor kuzatuvlari hali kerak; output real_world_accuracy_verified=false.

Anti-spoof: Fourier/Moiré periodicity, bright reflection components, quadrilateral screen/paper boundaries; Android root/emulator hints; Geolocator mock flag, accuracy/fix time, Haversine speed/time anomalies. security_configs YAML’dan. Flags advisory, uploadni liveness sababli rad qilmaydi. liveness_verdict=not_assessed; presentation_medium=undetermined; client_evidence_trusted=false. iOS unsupported signal null, fake clean emas. Synthetic texture/rectangle/control testlar bor, real screen/paper-vs-animal discrimination tasdiqlanmagan. Breathing/micro-movement labeled real video datasetga blocked. Hardware attestation/Play Integrity implement qilinmagan.

11. PHASE 2 OFFLINE RESEARCH — BOR, PRODUCTION MATCHING EMAS

research/ va tools/research.py: reviewed CSV import → JSON manifest validation → feature extraction → exact cosine evaluation. Frozen ImageNet ResNet18 avgpool baseline,512 dimensions, L2 normalization, padded-square resize. Official weights SHA tekshiriladi, weights_only=True, implicit download yo‘q; ignored models/cattle/research/ da. Bular trained cattle embeddings emas.

Manifest: sample_id, species, independent animal_id, session_id, split(train/validation/test), role(train/gallery/query), relative image_path, SHA-256, reviewed_muzzle=true; optional farm_id/camera_id. Animal splits disjoint; same-animal gallery/query turli sessions; unknown query ID gallery’da bo‘lmaydi. Validator unsafe paths, changed bytes, exact file/oriented-pixel reuse, mixed species, unreviewed samples va identity/session leakage’ni rad etadi. Pending original avtomatik reviewed emas.

Validation’da threshold tanla/freeze qil, testni keyin bahola; CLI’dagi0.8 faqat misol, approved cutoff emas. FAR/FRR/pair counts, known failures/wrong accepts va unknown accepts denominators bilan; bo‘sh cohort uchun null. Equal-score identity tie ambiguous/rejected. NumPy exact cosine baseline bor, production vector DB/identity endpoint/operational threshold tanlanmagan. Single stock-image extraction va repeat cosine1.0 smoke proof, recognition accuracy emas.

Real multi-animal/multi-session labeled muzzle dataset hali tasdiqlanmagan. Old public dataset reconnaissance access/license/session label’larni hal qilmagan; ularni tekshirmay import/download yoki training boshlama. Dataset/account/licensing Sardorbekning tashqi inputini talab qilishi mumkin. Mavjud research’ni asossiz kengaytirma.

12. MOBILE DESIGN VA TO‘RT TIL — QURILGAN

Native forest-green/ivory/mint dizayn, system Roboto/tabular ID digits, camera positioning aid va fixed capture actions. Tabs: Capture / Saved / Animals / Tools. Guide rectangle detector/liveness natijasi emas. QC/GPS/metadata, queue/receipts, backup va settings review mavjud. Public livestock app references ko‘rilgan, lekin authenticated competitor walkthrough yoki real phone visual verification deb da’vo qilinmaydi. Host mock screenshots docs/design/ da.

Til variantlari: o‘zbek lotin(default uz-Latn), o‘zbek kirill(uz-Cyrl), rus(ru), English(en). Vositalar/Tools → Til/yozuv. Har biri220-message UTF-8 catalog mobile/assets/l10n/ da. Choice application-support preferences/language.json orqali restartdan keyin qoladi; flush/rename, failed-save old choice, corrupt preference visible recovery bor. UiText template’lari render-time resolve qilinadi. Til o‘zgarganda ochiq original, kamera, metadata, queue/request keys saqlanadi.

Names/notes Unicode; hech qachon auto-transliteration qilma. Permanent IDs, owner/facility refs ASCII; Cyrillic М Latin M emas. API species/status enum, timestamps, UUID/hashlar tarjima qilinmaydi. Placeholder ichidagi user braces yangi template emas. QC/server guidance tarjima, raw technical evidence saqlanadi. Flutter’ning Uzbek-Latin system widgetlari uchun Cyrillic adaptation bor: labels/plurals/dates/context menus; raw arguments va internal Cupertino date-order tokens o‘zgarmaydi. OS permission dialogs/keyboard OS language’ga qaraydi.

Oxirgi tuzatishlardan biri: uncached startup’da asl authentication/network xatosi noto‘g‘ri “no species enabled” xabariga almashtirilmaydi. Narrow320x720 va200% text overflow tuzatilgan va testlangan. iOS build/native pluginlar Windows’da tasdiqlanmagan.

13. DATA COLLECTION PROTOKOLI

Asosiy amaliy qo‘llanma: docs/DATA_COLLECTION_GUIDE.md. 100 cattle pilot floor: ikkita farmda50tadan, ayni hayvonlarga day0/7/14 uch tashrif; har safar6 distinct usable photo:2 front,2 chap15°,2 o‘ng15°. Jami18/hayvon,1800 original. Bu rare-error reliability sample-size kafolati emas. 40–60cm boshlang‘ich masofa, bitta butun muzzle kadr kengligining taxminan1/3–1/2,10% margins; bu empirical detector limits emas.

Permanent canonical animal ID bir marta beriladi. F01-C001… kabi cohort_slot alohida ledger’da IDga map qilinadi; raqamlarni o‘zing ishlab chiqma. Har tashrifda tag/handler bilan mustaqil identity confirmation. Session F01-YYYYMMDD-V1/V2/V3, haqiqiy turli tashrif/day; burst/yorug‘lik o‘zgartirish yangi session emas.

roster.csv: permanent ID/tag, cohort, identity verifier/time/reference, breed/sex/age/health, owner/farm/permission; scans.csv: session/farm/camera/view/distance/light/time/GPS/operator/request key, keyin uploaded UUID/path. Uncertain identity exclude qilinadi. GPS va missing fields to‘qilmaydi; EXIF stripped bo‘lgani uchun unga tayanma. Tag/body references muzzle datasetga kiritilmaydi; collection app gallery picker bilan almashtirilmaydi.

Per farm split:20 train;10 validation-enrolled +5 validation-unknown;10 test-enrolled +5 test-unknown. Train jami40, validation30, test30. Enrolled V1 gallery, V2/V3 query; unknown V2/V3 query only, V1 evaluation’dan tashqarida. Original server evidence rename qilinmaydi; reviewed research crop’lar alohida data/research/crops/ ostida UUIDga bog‘lanadi. Session/tag/farm metadata field guide’dagi ledger’dan manifestga o‘tadi. Sheep hali yig‘ilmaydi.

14. OXIRGI VERIFICATION, ARTEFAKT VA GIT MILESTONE’LARI

2026-10-14:204 backend/tooling +48 research =252 Python;109 Flutter, ichida16 localization cases; jami361 distinct test passed. Ruff/changed-file format va Flutter analyzer clean. Known upstream TestClient/httpx deprecation bor. Host mock/synthetic testlar real hardware/animal proof emas; bu testlar29-oktabrda qayta ishga tushirilmagan.

Actual isolated Docker/PostgreSQL upload/QC/pending_model, row+file+hash, source/config hashes, concurrent ID allocation/replay, owner200/409 race, terminal capture link, four-script Unicode owner/note/history/replay verified. Old real image upload proof ham hujjatlarda bor, ammo single image multi-animal training data emas. Sardorbek oldin normal Docker health200 va healthy containers’ni ko‘rgan; tarixiy xabarni bugungi jonli status bilan aralashtirma.

Oxirgi APK: D:\Coding projects\moliddetector\mobile\build\app\outputs\flutter-apk\app-debug.apk.
SHA-256: a4012b93d54f4f980680d9c1fcdf58836d7d91f2d41b7dc07a0202dddd966a3f.
Build50.3s, operator token define qilinmagan. Four embedded catalogs source bytes bilan mos; APK hash29-oktabrda yana mos chiqdi. Credential-configured build/run README orqali. Debug APK physical E2E confirmation emas.

Test stack biolivestock-reliability:port18001,data/reliability; numbering boundary stack:18002,data/numbering.14-oktabrda test services exit0 bilan stopped, volumes/evidence saqlangan; bugun container runtime qayta tekshirilmadi. Numbering test counter intentionally exhausted; real ID uchun ishlatma. Normal collection stack oldingi tekshiruvlarda deploy/o‘zgartirilmagan; yangi kod u yerda ishlayapti deb taxmin qilma.

Evidence: data/reliability/evidence/registry-i18n-20261014.json, unicode-20261014.json, i18n-restore-20261014.json. Backup data/backups/i18n-20261014 → clone DB biolivestock_restore_i18n_20261014 va data/restores/i18n-20261014.65 profiles,72 animals,140 audits,111 registry receipts,13 captures/12 upload receipts,1 counter. Barcha asosiy row contents, file hashes, capture index/countlar teng, reconciliation healthy. Bular synthetic test store sonlari, real farm dataset hajmi emas. Eski backup/clonelar ham retained; secrets/weights/data gitda bo‘lmasligi normal.

Asosiy oxirgi commitlar:
3a960fc — multilingual docs, APK va Unicode recovery evidence.
6298ddc — uncached authentication guidance.
0895f84 — four-language persisted UI.
9339d2a — detector checkpoint provenance/cache.
c93e34e — old MVP completion audit.
8d82675 /5dd1274 — registry/mobile/storage fixes.
bba7a96 /35efa25 — mobile/backend MAA-series support.

Audit fixes ichida: original-pixel lighting histograms, uncertain COMMIT evidence retention, per-file typed journal recovery, all-file restore verification, planar/simple3D contour validation, oriented-pixel research duplicate rejection, coherent registry SQL snapshot, failed lookup stale-card clearing, history paging, cross-instance journal guard, optional UUID attachment, linked-path guards va dependency pins mavjud. Ularni qayta buzadigan “soddalashtirish” qilma.

15. QAYERDA TO‘XTAGANMIZ VA NIMADAN DAVOM ETAMIZ

Data-independent MVP, requested groundwork, topilgan audit xatolari, dizayn, permanent numbering/ownership/lifecycle va multilingual UI bajarilgan. Bu besh bosqichning hammasi yoki production biometrics tayyor degani emas.

Oldingi oxirgi xabarga ko‘ra Sardorbekning suv tekkan test telefoni ta’mirda, physical testing muddatsiz blocked edi. Avvalgi USB device ID23117RA68G faqat tarixiy ma’lumot; qaytsa adb devices bilan joriy qurilmani tekshir. 29-oktabrda telefon tuzalgani haqida yangi tasdiq yo‘q. Real reviewed cattle identity/session dataset, trained muzzle checkpoint, genuine/attack videos, measured weights/calibrated anatomy va market data ham hali taqdim etilgani tasdiqlanmagan. Sardorbek rasmlar yig‘ayotganini aytgan; tayyor deb taxmin qilma.

Davom etish tartibi:
A) Live repo/progress/config/statusni o‘qi. Yangi talab yoki yangi data/phone kelgan-kelmaganini mavjud fayllardan tekshir. Faqat tashqi input kerak bo‘lib haqiqatan to‘xtasang Sardorbekdan so‘ra.
B) Telefon bo‘lsa: canonical backend/data’ni backup qil, kerakli migration/config/code versiyasini tekshir, review qilingan backend va operator-configured app’ni ishga tushir. Native camera/permissions/GPS/keyboard, four-language restart, offline capture/restart/retry, ID issue/ack, legacy lookup, owner transfer, terminal archive, history/capture attachment va ZIP sharing’ni synthetic recordsda haqiqiy telefon bilan tekshir.
C) Real cattle data bo‘lsa: field guide identity/session/permission/completeness tekshiruvi → manual crop/review → CSV import/manifest validation → muzzle detector training/evaluation uchun tegishli labels → mavjud frozen research baseline bilan leakage-free validation/test. Validation’dan thresholdni freeze qil, keyin held-out test. Aniqlik yetarli isbotlanmasdan production identification/abattoir proofga aylantirma.
D) Labeled attack/genuine video bo‘lsa liveness; actual scale/calibrated measurements/market sources bo‘lsa weight/valuation empirical kalibratsiyasi. Sheep keyin, hozir disabled.
E) Hech yangi input bo‘lmasa, yangi concrete bug/regression bo‘lganini dalil bilan ko‘rib tuzatish mumkin. Qolgan ish data/hardware’ga bog‘liq bo‘lsa coding tugagan ko‘rsatish uchun fake inference, yangi matching experiment, sheep logic, cloud yoki CI/CD boshlama.

16. LOCAL START VA TEKSHIRUV BUYRUQLARI

Quyidagilar PowerShell uchun; mavjud .venv/credentials’ni o‘chirib qayta yaratma. C:\src\flutter\bin PATH’da bo‘lmasa to‘liq flutter.bat pathdan foydalan.

Backend:
Set-Location 'D:\Coding projects\moliddetector'
# Faqat credentials hali yo‘q bo‘lsa:
.\.venv\Scripts\python.exe tools/init_local_credentials.py
Set-Location 'D:\Coding projects\moliddetector\backend'
docker compose up --build -d
# Startup Alembic upgrade qiladi. Health http://localhost:8000/health; docs http://localhost:8000/docs.

Phone:
Set-Location 'D:\Coding projects\moliddetector\mobile'
flutter doctor
adb devices
flutter pub get --enforce-lockfile
adb reverse tcp:8000 tcp:8000
$localKeys = Get-Content '../backend/.secrets/tokens.json' -Raw | ConvertFrom-Json
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 --dart-define="API_TOKEN=$($localKeys.operator.token)" --dart-define="OPERATOR_ID=$($localKeys.operator.operator_id)"
# Tokenni Write-Output/logga chiqarma. Backendni avval ishga tushir. ADB reverse reconnectdan keyin qayta kerak.
# Default10.0.2.2 emulator adresidir; real phone uchun yuqoridagi URL define shart.
# flutter clean faqat zarur build muammosida, har safar emas. kotlin.incremental=false ni saqla.

Tests:
Set-Location 'D:\Coding projects\moliddetector'
.\.venv\Scripts\python.exe -m pytest -c research/pyproject.toml backend/tests research/tests -q -p no:cacheprovider
.\.venv\Scripts\python.exe -m ruff check backend research tools
Set-Location 'D:\Coding projects\moliddetector\mobile'
flutter analyze
flutter test
flutter build apk --debug

Research data tayyor bo‘lgandagina rootdan:
.\.venv\Scripts\python.exe tools/research.py import-csv --config research/species_configs/cattle.yaml --csv data/research/muzzle_annotations.csv --dataset-root data/research/crops --output data/research/manifest-NEW.json
.\.venv\Scripts\python.exe tools/research.py validate --config research/species_configs/cattle.yaml --manifest data/research/manifest-NEW.json --dataset-root data/research/crops
# Extraction/evaluation va explicit model/threshold/provenance buyruqlari docs/PHASE2_RESEARCH.md da. Mavjud outputni overwrite qilma.

17. TAFSILOT UCHUN MANBALAR

Barcha yo‘llar D:\Coding projects\moliddetector ga nisbatan:
PROGRESS.md — joriy holat va tarixiy dalillar; README.md — local setup.
docs/ROADMAP.md va ARCHITECTURE.md — fazalar va species architecture.
docs/DATA_COLLECTION_GUIDE.md va DATA_REQUIREMENTS.md — farm protokoli va tashqi inputlar.
docs/ANIMAL_REGISTRY.md — permanent IDs, owner/lifecycle, terminal reports.
docs/SECURITY_AND_REGISTRY.md — auth/admin/status/duplicates/provenance.
docs/COLLECTION_RELIABILITY.md va COLLECTION_IMPROVEMENTS_2026-10-13.md — offline/retry/backup/restore/benchmark/pins.
docs/PHASE2_RESEARCH.md — mavjud offline baseline va manifest.
docs/WEIGHT_AND_VALUATION.md va ANTI_SPOOF_GROUNDWORK.md — prototip hisob va advisory signallar.
docs/LANGUAGES.md va MOBILE_DESIGN.md, docs/design/ — tillar va UI.
docs/CODE_AUDIT_2026-10-13.md, AUDIT_REPAIRS_2026-10-13.md, MVP_COMPLETION_2026-10-14.md, VALIDATION.md — topilmalar/tuzatish/verification. Eski test soni yoki APK hashini eng oxirgi bilan aralashtirma.

Endi shu kontekstdan davom et: avval haqiqatni tekshir, ayni to‘xtagan joydan ishni ol, tayyor ishni qayta yaratma. Natijalarni “built / directly verified / synthetic-only / unverified / externally blocked” deb aniq ajratib yoz. Keyingi ish mavjud real inputga mos bo‘lsin; loyiha va dalillarni asra.
