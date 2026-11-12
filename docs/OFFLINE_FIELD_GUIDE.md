# Qishloqda serversiz yig‘ish — 2026-11-12

## Molni skanerlash va profil

### Taqdimot uchun alohida NAMUNA ilovasi

**Chorvam NAMUNA** — `.demo` paketli alohida APK. Unda olti chizilgan mol,
namuna ID va profil bor; barcha sahifalarda NAMUNA yozuvi qoladi. Bu real
suratlar, vazn, sog‘liq yoki tanish aniqligi dalili emas. Taqdimotda kartani
bosib namuna profilini oching, yo‘riqnomani ko‘rsating. Namuna surat olmaydi,
AR o‘lchamaydi va serverga yubora olmaydi (Android internet ruxsati ham yo‘q).
Haqiqiy dala yig‘ishi uchun oddiy **Chorvam** ishlatiladi. Ikki paketning
operatori, yozuvlari va sozlamalari alohida; NAMUNA bazani ko‘chirmaydi.

### Birinchi ochilish yo‘riqnomasi

Birinchi ochilishda to‘rt qisqa sahifa chiqadi: tumshuqdan tiniq kadrlar olish,
molni o‘zingiz tasdiqlash, chap/o‘ng yon suratlar, alohida ZIP zaxira.
**Keyingi sahifa** bilan o‘ting, oxirida **Yig‘ishni boshlash**ni bosing.
**Hozircha o‘tkazish** ham ko‘rilganini saqlaydi. Istalgan payt
**Vositalar → Qisqa yo‘riqnoma**dan qayta oching. Bu kamera ochmaydi,
operator ID yoki hayvon yozuvlarini o‘zgartirmaydi. Yon suratdan vazn
chiqmaydi; qayta skanda taklifni har safar o‘zingiz tasdiqlaysiz.

### Hamkorlar paneliga ma’lumot yuborish

MAAga ro‘yxatlangan profilda **Profil ma’lumotlarini panelga yuborish**:
birka/laqab, saqlangan yaroqli AR vazn xulosalari va tarozi qaydlari yuboriladi.
Bu alohida, qo‘lda bajariladigan amal; internet uzilsa ayni tugmani qayta bosing.
Rasm yuborish avvalgi alohida oqim orqali. Xom depth/AR nuqtalari telefon va
ZIPda qoladi. Panel faqat serverga yuborilgan narsani ko‘rsatadi.
Panel manzili: serverning `/panel/login` sahifasi. CLI orqali berilgan shaxsiy
login/parol yoki avvalgi API kaliti bilan kiring. Admin/operator/veterinar/bank
rollari farq qiladi; faqat ruxsatli rol moliyaviy holatni o‘zgartiradi. Brauzer uchun
HTTPS kerak; localhost sinovi alohida test muhitida bajariladi.

### So‘yish qaydi uchun QR

Serverda so‘yilgani qayd etilgan MAA profilida **So‘yish qaydi QR**ni oching.
Internet va o‘sha operator kaliti bilan kod yarating, PNGni ulashing.
QRni ochgan odam faqat ID, so‘yish sanasi, qassobxona kodi va tasdiqlangan
veterinar ko‘rigi sanasini ko‘radi. Ega, GPS va narx ochiq sahifada chiqmaydi.
Internet bo‘lmasa saqlangan QR ko‘rinadi, ammo uning hali faol ekanligi
tekshirilmaydi. Xato kodni sabab yozib bekor qiling; yangi kod alohida yaratiladi.
Bu registrdagi qayd, go‘shtning laboratoriya xavfsizlik tasdig‘i emas.
Ommaviy HTTPS manzil server sozlamasida belgilanishi kerak.

### Sog‘liq va emlashlar

Profil → **Sog‘liq va emlashlar** → emlash/davolash/kasallik/ko‘rik turi,
sana (`YYYY-MM-DD`), tavsif; veterinar ismi va izoh ixtiyoriy. **Qaydni saqlash**
oflayn ishlaydi. Xatoni **Tuzatuvchi qayd qo‘shish** orqali to‘g‘rilang: eski
yozuv o‘chmaydi. Oflayn qayd **Operator yozuvi**. Faqat mos saqlangan server
javobida muallif roli `veterinar` bo‘lsa **Veterinar tomonidan tasdiqlangan**
belgisi chiqadi; ism yozishning o‘zi tasdiq emas. Boshqa veterinarning
serverdagi qaydlari private panelda ko‘rinadi; telefonda to‘liq ikki tomonlama
tarix yuklash yo‘q. MAA va asl operator kaliti bo‘lsa **Sog‘liq tarixini
yuborish**; aloqa uzilsa ayni tugma bilan davom eting. ZIPda `ledger/health.csv`
va asl JSONlar qoladi. Bu tashxis yoki dori tavsiyasi emas.

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

### Sotuv va egalik tarixi

Profil → **Egalik tarixi → Sotildi / egasi o‘zgardi**. Yangi ega yorlig‘i va
ismi, sana hamda o‘tkazish izohini kiriting. Narx ixtiyoriy: faqat **butun so‘m
(UZS)**. Qayd avval telefonda append-only saqlanadi; bu to‘lov yoki huquqiy
mulk tasdig‘i emas. ZIPda `ledger/ownership.csv` va asl yozuvlar bor.

MAA va asl operator kaliti bo‘lsa **Egalik tarixini yuborish**. App server
versiyasini so‘rovdan oldin saqlaydi. Aloqa uzilsa ayni tugma bilan davom eting;
yangi yozuv/kalit bilan avvalgi transferni qayta yaratmang. Serverdagi egasi
yoki versiya o‘zgargan bo‘lsa, xato ko‘rsatiladi; app o‘zi yangi versiyaga
moslab yubormaydi. Sana kun aniqligida kiritiladi (API uchun UTC 00:00), hodisaning
o‘lchangan aniq soati deb qaralmaydi. Sotuv qaydi bir molning ID sini o‘zgartirmaydi.

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

Vaqtinchalik suratlar avtomatik yuborilmaydi. Server va operator kaliti sozlangan
bo‘lsa, **profil → Serverga ro‘yxatlash / yuborishni takrorlash** yoki
**Vositalar → Serverga ro‘yxatdan o‘tkazish → mollarni tanlash**ni bosing.
Ega yorlig‘i (masalan `FARM-01`, pasport raqami emas) va ismini kiriting.
App doimiy IDni olib **L-… → MAA…** bog‘lanishini saqlaydi, keyin shu molning
tumshuq originallarini yuboradi. Yon gavda suratlari bu endpointga yuborilmaydi.

Javob yo‘qolsa/yuborish to‘xtasa ayni tugmani yana bosing: o‘sha kalit va muzlatilgan
ega ma’lumoti bilan davom etadi, ikkinchi ID so‘ramaydi. L-ID, eski metadata,
GPS, sana va jurnallar o‘zgarmaydi; server yuklash uchun alohida MAA yozuv bor.
Profilda yuborilmagan suratlar sonini tekshiring. Server kaliti suratni olgan
**asl operator**ga tegishli bo‘lishi kerak; farq qilsa xabar chiqadi, asl operator
uchun sozlang. Qo‘lda eski metadata yoki jurnalni tahrirlamang. Ma’lum 4xx rad
javobi qayta yangi kalitga aylantirilmaydi: ZIPni saqlab, sababini tekshiring.
Bog‘lanish server/operator doirasida: boshqa endpoint/operatorga ko‘chirayotganda
eski dalillar tekshirilmaguncha yangi ID chiqarilmaydi. ZIPda
`ledger/registrations.csv`, `ledger/registered_uploads.csv` va xom receiptlar bor.
Kalitsiz release oflayn ishlaydi; u serverga ulanish sozlangan degani emas.

Release APK shaxsiy sideload uchun mavjud debug key bilan sign qilinadi; production
signing emas. Uchinchi tomon gallery-save plugin: `gal 2.3.3` (BSD-3-Clause), faqat app
olgan surat nusxasini albomga chiqarish uchun. Android API ≤29 storage write
permission va API29 legacy album access; Android30+ own MediaStore insert uchun
read-media/gallery-import permission so‘ralmaydi. iOS album uchun Photos matnlari
bor, lekin iOS native build/runtime Windowsda tekshirilmagan.

## ARsiz telefon: vazn uchun chap/o‘ng gavda suratlari

1. Mol profilida **Vazn uchun yon suratlar** → **Chap yon surat**.
   Taxminan **3–4 m** uzoqlikdan boshlang: butun gavda, oyoq va dum sig‘sin.
   Sxemaga qarang; tekis yorug‘likda surat oling. O‘ng yonini ham alohida oling.
2. Bu **tumshuq surati emas**: tanish signali yoki olti ko‘rinish checklistiga
   qo‘shilmaydi. Hozir gavda suratidan **vazn hisoblanmaydi**; kelajak modeli
   uchun dalil yig‘iladi. 23117RA68Gda ARCore yo‘q — AR vazni chiqmaydi.
3. Haqiqiy tarozi bo‘lsa profilda **Tarozi vazni** → kg va tortilgan sana.
   Suratga eng yaqin, ko‘pi bilan **7 kun** farqli haqiqiy tortish bog‘lanadi.
   Imkon bo‘lsa o‘sha kun torting; taxminiy AR vaznini tarozi deb kiritmang.
4. ZIPda original JPEG/append-only qayd va `ledger/side_photos.csv` bor:
   ID, chap/o‘ng, sana, hash, mos tarozi yozuvi va kun farqi. Keyin tarozi
   qo‘shilganda raw surat qaydi tahrirlanmaydi, eksportdagi bog‘lanish yangilanadi.

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
