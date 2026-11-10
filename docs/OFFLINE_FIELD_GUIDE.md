# Qishloqda serversiz yig‘ish — 2026-11-06

## Molni skanerlash va profil

1. **Molni skanerlash** → bitta molning tumshug‘ini markazga oling →
   standart **Video bilan olish** rejimida **Eng tiniq kadrlarni olish**ni bosing.
   4 soniya bir molning tumshug‘ini ushlang: yashil — tiniq, sariq — qimirlamang,
   qizil — yorug‘lik/fokusni yaxshilang. So‘ng eng yaxshi suratni yoki hammasini
   tanlang. Har tanlangan suratda mol ID sini alohida tasdiqlang; keyingi surat
   avtomatik ayni molga biriktirilmaydi. Jarayon to‘xtasa saqlangan suratdan davom
   eting. Video fayl saqlanmaydi, faqat tanlangan original o‘lchamdagi JPEGlar.
   Kadrlar kichik yoki kamera oqimi ishlamasa, aniq xabar bilan **Bitta surat**ga
   qaytadi. Yakuniy QCdan o‘tmagan surat qabul qilinmaydi. Bir burst bir xil
   ko‘rinish: olti turli checklist qatorini bitta burst bilan to‘ldirmang.
2. O‘xshash nomzod chiqsa, yangi va eski surat, birka va vaznni ko‘ring.
   Faqat o‘sha mol ekaniga ishonchingiz komil bo‘lsa **Ha, shu mol**ni
   bosing: surat yangi sessiya bilan o‘sha **L-…** IDga qo‘shiladi.
   **Yo‘q, boshqa mol** orqali yangi ID oching. Bu tajribaviy signal;
   app o‘zi ID tanlamaydi yoki yozuvlarni birlashtirmaydi.
3. Nomzod chiqmasa, **Yangi mol**da birka/laqabni ixtiyoriy kiriting.
   Bu avvalgi mol bo‘lsa **Saqlangan molni tanlash** orqali IDni topib
   tasdiqlang. Birka takrorlansa, yangi ID berishdan oldin ogohlantiradi.
   Eski yoki yangi molning profili ochiladi.
4. **Mollarim**da ID, birka yoki laqab bo‘yicha qidiring. Profildan
   **Yangi surat**, **AR o‘lchov** yoki **Tarozi vazni**ni tanlang.
   Qoidalardan o‘tgan AR natijasi shu profilga avtomatik yoziladi;
   o‘lchov rejimi, sanasi va ikki formula ko‘rinadi. Tarozi vazni alohida.
5. Dala sinovi: avval mollarni ro‘yxatdan o‘tkazing va haqiqiy birka↔ID
   ro‘yxatini tuting. So‘ng 5–10 tasini bosh ekrandan ataylab qayta skanerlang.
   Nomzod chiqmasa, to‘g‘ri IDni qo‘lda tanlang; boshqa IDni tasdiqlamang.
   **Vositalar**da topilgan/topilmagan qayta skanlar va yangi mollardagi
   ogohlantirishlar sanog‘ini ko‘ring. ZIPdagi `ledger/match_decisions.csv`
   qarorlarni saqlaydi. Bu sanovlar operator tasdiqlariga asoslanadi.

## Olti ko‘rinish va zaxira

P0 oqimi: app ichida source YAML bilan bir xil oflayn qoidalar bor. Yangi
o‘rnatilgan telefonda server yoki API token shart emas. Samolyot rejimida
**Vositalar → Oflayn operatorni sozlash** orqali lotin harflarida masalan
`SARDOR-01` kiriting. Bu operator bayonoti; serverga kirish kaliti emas.

1. Eski olti ko‘rinishli yig‘ish ekrani **Vositalar** orqali ochiladi.
   **Yangi vaqtinchalik hayvon**: birka yoki laqab, xohlasangiz Unicode izoh.
   App `L-…` mahalliy yorliq beradi. Uni daftarga yozing; bir hayvon uchun keyingi
   suratlarda ayni yorliqni tanlang. Bu rasmiy MAA ID emas, serverda ro‘yxatda yo‘q.
   Boshqa telefonda shu hayvonga avtomatik bog‘lanmaydi.
2. Session odatda mahalliy sana bilan `YYYY-MM-DD-V1`. Keyingi haqiqiy tashrifda
   sana/V2/V3ni moslang; bir necha ketma-ket surat alohida tashrif emas.
3. **Oldindan 1/2, 2/2; chap 15° 1/2, 2/2; o‘ng 15° 1/2, 2/2**: jami olti
   distinct ko‘rinish. App saqlangan sidecar yozuvlari bo‘yicha `4/6` kabi hisoblaydi,
   keyingi bo‘sh ko‘rinishni tavsiya qiladi; bu haqiqiy rakursni AI tekshiruvi emas.
4. Kamera: bitta butun tumshuq, tiniq burun teksturasi, bir tekis yorug‘lik.
   Odatda 40–60 cm dan boshlang, xavfsizlik va fokusga qarab moslang. Handler
   hayvonni boshqarsin; xavfli aylanib o‘lchash yoki qorin tagiga kirish yo‘q.
5. QCdan keyin **telefonda saqlandi**: original + immutable queue metadata va key.
   `BioLivestock` galereya albomiga alohida nusxa ham yoziladi. Galereya ruxsati
   rad bo‘lsa ogohlantirish chiqadi, durable original bekor qilinmaydi. Galereya
   fotosini tahrirlash app originalini o‘zgartirmaydi. Gallery picker yo‘q.
6. **Keyingi surat**ni bosing. Samolyot rejimida appni yopib qayta oching:
   yorliq/surat va checklist saqlanishini shaxsiy telefonda tekshiring.
7. Kun oxirida **Vositalar → Zaxira nusxasini chiqarish**. ZIPni share orqali
   telefondan tashqariga, masalan kompyuter yoki boshqa diskka saqlang. Appdagi
   vaqtinchalik ZIP ikkinchi nusxa emas. Uninstall/clear data qilmang.

ZIP: queue originals/journals, field roster/scan/gallery sidecars, `ledger/roster.csv`
va `ledger/scans.csv` hamda hash manifest. CSVdagi GPS yo‘q bo‘lsa bo‘sh. Operator,
label, tag/izoh, session/view, vaqt, key, relative path va SHA-256 saqlanadi.
Excel formula-injectiondan saqlash uchun CSVda xavfli boshlanuvchi matnga apostrof
qo‘shiladi; raw JSONda Unicode asl holida qoladi. Buzuq raw fayllar backupda qoladi;
CSV faqat o‘qiladigan yozuvlardan hosil bo‘ladi, u raw evidence o‘rnini bosmaydi.

Kompyuterda rootdan:

```powershell
.\.venv\Scripts\python.exe tools/phone_backup.py verify --bundle 'D:\Backups\phone.zip'
.\.venv\Scripts\python.exe tools/phone_backup.py extract --bundle 'D:\Backups\phone.zip' --destination 'D:\Backups\recovery-NEW'
```

Provisional suratlar avtomatik upload/register qilinmaydi. Ularni keyin canonical
serverdagi doimiy ID bilan review qilib bog‘lash alohida ish; eski journalni qayta
yorliqlash yoki metadata’ni edit qilish yo‘q. Online server/cached qoidalar va
oldingi authenticated manual upload mavjud server IDlar uchun saqlanadi.

Release APK shaxsiy sideload uchun mavjud debug key bilan sign qilinadi; production
signing emas. Uchinchi tomon gallery-save plugin: `gal 2.3.3` (BSD-3-Clause), faqat app
olgan surat nusxasini albomga chiqarish uchun. Android API ≤29 storage write
permission va API29 legacy album access; Android30+ own MediaStore insert uchun
read-media/gallery-import permission so‘ralmaydi. iOS album uchun Photos matnlari
bor, lekin iOS native build/runtime Windowsda tekshirilmagan.

## P1: offlayn AR o‘lchash va vazn — amaliy tartib

**Holat:** kod va sun’iy geometriya sinovlari mavjud; haqiqiy telefon/animal
aniqligi tekshirilmagan. Bu avtomatik anatomik nuqta topuvchi model emas:
ekranda nuqtalarni siz bosasiz, ARCore metrik masofani beradi, app hisoblaydi.

### Uydan chiqishdan oldin

1. APKni USB orqali telefonga ko‘chiring va ochib o‘rnating (yoki pastdagi adb).
   Oldingi appni o‘chirmang, Clear data qilmang; yangilab o‘rnating.
2. Internet borida kamera ruxsatini bering, Google Play Services for ARni
   o‘rnating/yangilang. Vaqtinchalik hayvonni tanlab **AR vazn va qiymat → AR
   mosligini tekshirish**. Model, Android, availability, Depth va AR service
   versiyasi ko‘rinadi. `UNKNOWN` — mos emas degani emas; qayta tekshiring.
   `UNSUPPORTED_DEVICE_NOT_CAPABLE` bo‘lsa AR ishlamaydi, surat yig‘ish ishlaydi.
   Depth yo‘q bo‘lsa haqiqiy feature-point confidence bilan cheklangan yo‘l bor;
   ishonchli nuqta bo‘lmasa hisob berilmaydi. Fon/polni mol o‘rniga bosmang.
3. Samolyot rejimini yoqing. Operator, yangi lokal hayvon, olti rasm, albom,
   qayta ochish, AR va ZIP chiqarishni oldindan sinang. Quyidagi host sinovlari
   telefonning shu amallarini bajargan degani emas.

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices -l
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" install -r 'D:\Coding projects\moliddetector\mobile\build\app\outputs\flutter-apk\app-release.apk'
```

### Asosiy rejim: muzlatilgan chap + o‘ng kadr

**Depth API shart.** Depth yo‘q yoki hali tasdiqlanmagan bo‘lsa olish tugmasi
o‘chiq; tez/kontur rejimlari va oflayn suratlar qoladi. Boshqa kadr depth’i yoki
to‘qima kenglik bilan natija chiqarilmaydi.

1. Ayni hayvon yorlig‘i → **AR vazn va qiymat** → katta qoramol va zot turi.
   Asosiy tanlov **Muzlatilgan kadr: chap + o‘ng**.
2. **1/3 Chap yon:** butun gavda sig‘sin (2–3 metrdan boshlang, fokus/Depthga
   qarab moslang). Jonli kamerada **Kadrni olish**. Aynan shu kadrning depth’i
   tayyor bo‘lmasa xabar chiqadi: sekin siljib yana kadr oling.
3. Muzlagan rasmda shoshilmay, sariq ajratilgan sxemaga qarab 4 joyni bosing:
   **1 Old uchi** — ko‘krakning eng oldinga chiqqan joyi;
   **2 Orqa uchi** — dumning tagi;
   **3 Orqa tepasi** — old oyoqlar ustidagi eng baland joy;
   **4 Ko‘krak tagi** — 3-nuqtaning to‘g‘ri pastida, old oyoqlar orqasida.
   Ishonchsiz depth pikseli rad etiladi; fonni bosmang. **Oxirgi nuqtani bekor
   qilish** va **Qayta olish** bor. Tugagach kadrni saqlang.
4. **2/3 O‘ng yon:** boshqa tomondan yangi kadrda ayni 4 joy. Sxema ko‘zgudek
   aylanadi. Har segment faqat o‘z kadridan olinadi: mol kadrlar orasida siljisa
   ham chap kadrdan o‘ng kadrgacha masofa hisoblanmaydi.
5. **3/3 Old tomon (ixtiyoriy):** o‘sha ko‘krak kesimining, old oyoqlar orqasidagi
   chap/o‘ng chekkalari ko‘rinsa, yangi kadrda shu **2 nuqta**. Bunda kenglik
   bevosita olinadi; oldindan 3 hayvon kerak emas. To‘silib qolgan chekkani
   fon/pol bilan almashtirmang.
6. Old kadrni olmasangiz: ayni telefonda/species/zot guruhida kamida **3 turli
   molning muvaffaqiyatli 6 nuqtali tez o‘lchovi** kerak. App `k/3`ni ko‘rsatadi.
   Yetmasa ikki yon kadr natija bermaydi: old kadr oling yoki avval 3 molni tez
   rejimda o‘lchang. Bir molga qayta yangi yorliq berib Nni oshirmang. Oldingi
   v2 fast yozuvlari ham hisobga olinadi.
7. **Kadrlar to‘plamini yakunlash.** Xom chap/o‘ng uzunlik va chuqurlik saqlanadi;
   yakuniy uzunlik/chuqurlik ularning o‘rtachasi. Mavjud 5% farq qoidasidan
   oshsa yangi to‘plamda qayta oling; yakuniy baho/korreksiya qo‘llanmaydi.
8. Natija **taxminiy, kalibrlanmagan**. Old kadr bo‘lmasa kenglik = o‘rtacha
   chuqurlik × o‘rganilgan median nisbat, `width_source: learned_ratio:<revision>`.
   Old kadr bo‘lsa `width_source: front_snapshot`. Girth — Ramanujan II ellipsi.
   Ikkala vazn formulasi, narx, baho va tarozi bo‘limlari quyidagidek ishlaydi.

Bir xil ma’lumot/policy bilan nisbat revision’i qayta ochishda o‘zgarmaydi;
yangi mos fast yozuvlari kelsa yangi append-only revision. Old kadr va nisbat
korreksiyalari aralashmaydi; yangi nisbat revision’i ham alohida guruh.
Kenglik uchun **N=3** va tarozi korreksiyasi uchun **N=10** boshqa chegaralar.
Bir suratni ikki yon sifatida qayta ishlatish rad etiladi.

Kadr olishda molni imkon qadar tinch tuting; muzlagan rasmda shoshilmang:
nuqta belgilashga jonli tracking yoki 180 s cheklov qo‘yilmaydi. Tagiga kirmang.
App harakatni aniqlamaydi; haqiqiy telefon/hayvon aniqligi hali tekshirilmagan.

### Muqobil 6 nuqtali tez rejim va narx

1. Birka/laqabga mos **ayni L- yorliqni** tanlang. Bir molga qayta-qayta yangi
   yorliq bermang: kalibratsiya turli yorliqlarni turli hayvon deb hisoblaydi.
2. Olti tumshuq rasmini yuqoridagi P0 tartibida oling. **AR vazn va qiymat**ni
   oching. Katta qoramol ekanini tasdiqlang, sut/go‘sht zot turini tanlang.
3. Muqobil **Tez** rejim: kamera kuzatuvi tayyor bo‘lgach:
   - 1 old uchi → 2 orqa uchi (dum tagi): tana uzunligi;
   - 3 orqa tepasi → 4 uning to‘g‘ri pastidagi ko‘krak tagi: chuqurlik;
   - 5 oldindan/tepadan o‘sha kesim chap yoni → 6 o‘ng yoni: kenglik.
   Yashil belgilar qabul qilingan metrik nuqtalar. **Tugatish**ni bosing.
   Ko‘krak aylanasi Ramanujan II ellips perimetri bilan taxmin qilinadi;
   bu **taxminiy girth, kalibrlanmagan**, lenta o‘lchovi yoki kafolat emas.
4. Ixtiyoriy shkala tekshiruvi: boshlashdan oldin o‘lchami aniq buyumning cm
   uzunligini yozing (A4ning uzun tomoni 29.7 cm, bukilmagan/tekis bo‘lsin).
   Avval uning ikki uchini bosing. Ma’lum qiymatni app o‘zi taxmin qilmaydi.
   Xato 5% dan katta bo‘lsa to‘plam rad qilinadi; bu fizik reference hisobga
   kiritilgan degani emas, ARCore metri alohida shkala manbasi.
5. Mol bir joyda tinch tursin, yordamchi boshqarsin. Qimirlasa bekor qilib
   boshidan oling. App nafas/mikroharakatni o‘lchamaydi. Tracking yo‘qolsa,
   anchor 3 cm dan ko‘p siljisa yoki 180 s oshsa qayta boshlash kerak.
   Nuqta confidence <0.8 bo‘lsa qabul qilinmaydi. Xavfli joyga kirmang.
6. Bir to‘liq o‘lchovni boshidan **2 marta**, kerak bo‘lsa **3 marta** bajaring.
   Rejim/zot bir xil qolsin. Farq = (max−min)/o‘rtacha ×100; uzunlik, aylana,
   tez rejim chuqurlik/kengligi va ikkala formula vaznining eng katta farqi
   olinadi. Chegara 5%; oshsa eski dalillarni saqlagan holda **yangi to‘plam**
   boshlang. Bir yaxshi urinishdan yakuniy baho chiqmaydi.
7. Go‘sht narxini **tana go‘shti uchun butun so‘m/kg**, haqiqiy kuzatilgan sana
   `YYYY-MM-DD` va bozor/manba izohi bilan kiriting. Xohlasangiz tirik vazn
   narxini alohida kiriting. Boneless go‘sht narxini tana narxi deb kiritmang.
   **Narx versiyasini saqlash**, keyin **Qiymat nusxasini saqlash**.
   Trukhanovsky va Schoorl alohida natija; tana go‘shti 50–58% taxmin oralig‘i.
   Bu statistik ishonch oralig‘i emas, haqiqiy bozor narxini app topmaydi.

**Aniq/kontur rejim** alohida variant: uzunlikning ikki nuqtasi, so‘ng oldingi
oyoqlar ortidagi bitta ko‘krak kesimi bo‘ylab tartibli kamida 8 (ko‘pi 128)
nuqta. Birinchi nuqtani oxirida takrorlamang, yopilish avtomatik. Kontur tekis,
oddiy, to‘liq bo‘lsin; kesishgan, qayta ustidan ketgan yoki chiziq kontur rad
qilinadi. Molning tagiga kirmang: xavfsiz to‘liq kontur olinmasa tez rejimdan
foydalaning. “Aniq rejim” nomi real aniqlik kafolati emas. Rejimlarni aralashtirmang.

### Tarozi va lokal korreksiya

- Haqiqiy tarozida tortgan bo‘lsangiz kg+sana yozib saqlang; bu ixtiyoriy.
  Sana ARdan ko‘pi bilan 7 kun farq qilishi mumkin, kelajak sana qabul qilinmaydi.
  Vazn o‘zgargan bo‘lsa yaqin sananing o‘zida qayta AR oling.
- **Lokal korreksiyani hisoblash**: kamida 10 turli hayvon, ayni species/rejim/
  zot/formula/config hash guruhi kerak. Bir hayvonning ko‘p rasmlari Nni oshirmaydi;
  eng oxirgi tortish versiyasi olinadi. Median haqiqiy/tuzatilmagan nisbat
  saqlanadi. N<10 da tugma hisob/namuna sonini ko‘rsatadi, korreksiya qo‘llanmaydi.
- N yetarli bo‘lsa yoqish/o‘chirish mumkin; oldingi va keyingi vazn hamda narx
  birga ko‘rinadi. MAPE shu o‘qitilgan namunalarning xatosi, mustaqil test emas.
  Har yangi hisob alohida revision, raw dalillar/narx/tortish o‘zgartirilmaydi.
  Yangi tortish yoki qayta kalibratsiya joriy korreksiyani o‘chiradi; qayta yoqing.
  Config o‘zgarsa eski koeffitsient boshqa guruhga avtomatik ko‘chmaydi.

### Kun oxiri

Hayvonning o‘lchov tarixida nuqtalar, segmentlar, confidence/tracking, shkala,
vaqt/config, ikkala formula va 1–2 JPEG screenshot raw JSONda saqlanadi.
Yarim/bekor urinish dalillari ham qoladi; process majburan o‘ldirilgan bo‘lsa
hali tugallanmagan native urinishni tiklash kafolatlanmaydi, oldin saqlanganlar qoladi.
ZIPga `ledger/measurements.csv`, `ledger/prices.csv` ham qo‘shiladi; CSV raw
`queue/field-measurement-*.json` yo‘lini beradi. JPEGlar raw JSONdagi
`raw.screenshots_jpeg_base64` ichida, CSVga uzun rasm matni ko‘chirilmaydi.
Yangi snapshot kadrlar `snapshot_frame` yozuvining `raw.jpeg_base64`, to‘liq
`depth_u16le_base64`, `confidence_u8_base64`, pose/intrinsics va view→image
moslashuvi bilan saqlanadi. Pikselxy/confidence va frame timestamp/hashlar ham
bor. CSVda frame/view, width_source, ratio revision/N va xom yozuv yo‘li chiqadi.
Qayta olingan/bekor qilingan kadrlar ham tarixdan o‘chirilmaydi. App tarixida
`snapshot_capture` xom kadr yozuvi nuqtalash ekrani ochilishidan oldin saqlanadi.
App yopilib qolsa tugallanmagan to‘plam avtomatik davom ettirilmaydi: yangi
to‘plam boshlang; oldingi xom kadrlar tarix/ZIPda qoladi.
rasm va metadata ko‘rinadi; katta binary matnlar faqat original JSON/ZIPda qoladi.
ZIPni **telefondan tashqariga** ko‘chiring va yuqoridagi verify bilan tekshiring.

Texnik manba va litsenziyalar: root NOTICE va README. ARCore 1.54.0 rasmiy API,
original lokal OpenGL renderer; ruxsatsiz GitHub renderer kodi olinmagan.
Google sample source Apache-2.0, runtime AAR esa alohida ARCore Additional Terms.
