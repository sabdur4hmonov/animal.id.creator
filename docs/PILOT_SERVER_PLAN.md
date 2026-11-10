# Chorvam — pilot server rejasi

Tekshirilgan sana: **2026-11-10**. Bu joylashtirish taklifi: server sotib
olinmadi, akkaunt ochilmadi, real ma’lumot ko‘chirilmadi. Yakuniy tanlov va
byudjet Sardorbekniki. Narxlar provayderlarning ochiq sahifalaridan; buyurtma
oldidan joylashuv, QQS, backup va qo‘llab-quvvatlashni yozma tasdiqlash kerak.

## Tavsiya etiladigan kichik pilot

O‘zbekistondagi bitta Linux VPS: HTTPS kirish qatlami → mavjud FastAPI
konteyneri → ichki PostgreSQL; original rasmlar alohida doimiy diskda.
Boshlang‘ich mo‘ljal **4 vCPU, 8 GB RAM, 100–150 GB SSD**. Kichikroq
4 GB variant faqat yuklama o‘lchangach; mavjud CPU Torch/Ultralytics paketlari
ham RAM oladi. Muzzle checkpoint hali yo‘q: `pending_model`, GPU kerak emas.
Bu quvvat tanlovi o‘lchangan server benchmarki yoki xizmat kafolati emas.

Telefon dala payti oflayn qoladi. Operator kechqurun o‘zi ro‘yxatlash/yuborishni
bosadi: L → MAA, saqlangan original va o‘zgarmas jurnal, bir xil idempotency
kaliti bilan qayta urinish. Bu avtomatik fon sinxronlash emas. Tarozi/AR/yon
suratlar hozir ZIP orqali olinadi; tumshuq upload endpointi ularni yubormaydi.
Boshlanishida bitta kelishilgan pilot hamkor: banklararo alohida tenantlar va
to‘liq ishlab chiqarishdagi kirish boshqaruvi tayyor deb ko‘rsatilmaydi.

## O‘zbekistonda saqlash: amaldagi qoida

**2021-yildagi eski umumiy talablarga tayanmaslik kerak.** Amaldagi 27¹-modda
(26.03.2026, O‘RQ-1125 tahriri) O‘zbekistonda majburiy saqlanadigan toifalarni
jismoniy shaxsning biometrik/genetik ma’lumoti va telekom operatoridagi
foydalanuvchi ma’lumoti deb belgilaydi. Boshqa shaxsiy ma’lumotni chet elda
saqlash uchun tan olingan himoya darajasi, tasdiqlangan shartnomaviy/korporativ
qoidalar yoki tegishli xalqaro standart shartlaridan biri bajarilishi kerak.
[Rasmiy amaldagi qonun, 26–27¹-moddalar](https://lex.uz/docs/-4396419).

**Chorvamga tatbiq qilish — ishchi talqin:** mol tumshug‘i odam biometrikasi
emas; ega ismi, operator va shaxs bilan bog‘langan GPS shaxsiy ma’lumot bo‘lishi
mumkin. Eng sodda pilot tanlovi — asosiy baza, fayllar, log va backupni ham
O‘zbekistonda saqlash. Bu tanlovni “barcha ma’lumotga bir xil majburiy qoida”
deb reklama qilmaymiz. Ega roziligi/qonuniy asos, minimal yig‘iladigan maydonlar,
saqlash muddati, o‘chirish tartibi va davlat reyestri masalasini hamkorning
mas’uli bilan ishga tushirishdan oldin tasdiqlang. Append-only texnik jurnal
shaxsning huquqlarini bekor qilmaydi.
[Qonunning 20 va 31-moddalari](https://lex.uz/docs/-4396419).

## Ochiq narxlarni solishtirish

| Variant | Ko‘rsatilgan resurs | Oylik server narxi | Izoh/manba |
| --- | --- | --- | --- |
| Hostmaster SSD Profi | 4 CPU / 4 GB / 100 GB | 299 900 so‘m | Kichik variant; RAMni sinash shart. [Rasmiy tarif](https://hostmaster.uz/vds/tariffs/) |
| Hostmaster SSD Super | 6 CPU / 8 GB / 150 GB | 449 900 so‘m | Pilot mo‘ljaliga yaqin; soliq/backup sharti buyurtmada tasdiqlanadi. [Rasmiy tarif](https://hostmaster.uz/vds/tariffs/) |
| MyCloud Business, Toshkent | 4 vCPU / 8 GB / 100 GB | 18 000 so‘m/kun, 30 kunda 540 000 | IP va trafik sahifaga ko‘ra ichida; provayder QQS to‘lovchisi emasligini yozgan. Oy kuniga qarab farq qiladi. [Rasmiy tarif](https://mycloud.uz/en/vps-servers) |
| UzCloud, O‘zbekiston | 2 vCPU / 2 GB / 20 GB SSD / IPv4 | Kalkulyatorda 284 000 so‘m, QQS bilan | Bu konfiguratsiya bizning tavsiya etilgan RAMdan kichik. 4 vCPU/8 GB/100 GB/IP uchun shu birlik narxlarida hisob **686 000 so‘m**; bu alohida tijoriy taklif emas. [Rasmiy kalkulyator](https://uzcloud.uz/infrastructure/vm) |

**Byudjet taklifi:** asosiy server 450–690 ming + alohida joydagi backup uchun
120–200 ming = **taxminan 570–890 ming so‘m/oy**. Backup summasi rejalash
taxmini: masalan MyCloudning 1 vCPU/1 GB/20 GB Start tarifi 4 000 so‘m/kun
(30 kunda 120 ming); bu faqat backup qabul qiluvchi kichik server, ilova uchun
emas. Yetarli disk/traffic/saqlash muddati tekshiriladi. Domen yillik alohida,
admin mehnati, migratsiya, monitoring, soliq farqi va katta disk bu summaga
kirmaydi. [MyCloud narxlari](https://mycloud.uz/en/vps-servers).

HTTPS sertifikati Let’s Encrypt orqali bepul bo‘lishi mumkin; domen va serverni
boshqarish bepul emas. [Rasmiy CA ma’lumoti](https://letsencrypt.org/about/).
Hostlarning reklamadagi SLA/Tier ko‘rsatkichlari Chorvam tomonidan audit qilinmadi.

## Ishga tushirishdan oldingi amaliy ishlar

- **Tarmoq:** domen → to‘g‘ridan-to‘g‘ri HTTPS reverse proxy. Ochiq port 443
  (sertifikat usuliga qarab 80); SSH faqat ruxsat etilgan manzil/kalitlar.
  API 8000 faqat ichki/localhost, PostgreSQL internetga ochilmaydi.
  Mavjud Compose lokal ishlab chiqish uchun: API host porti va ommaviy
  development DB parolini production override orqali almashtirish hali kerak.
- **Kalitlar:** serverda alohida operator/admin kalitlari, admin kaliti telefonga
  kiritilmaydi. Har operatorga cheklangan kirish va bekor qilish tartibi.
  Hozirgi compile-time `API_TOKEN` APKdan ajratib olinishi mumkin; ommaviy
  APKda token yo‘q. Uzoq muddatli production login/provisioning hali alohida ish;
  token sozlangan development APKni ochiq tarqatmang. HTTPSdan foydalaning.
- **Disk va log:** saqlash diski va tashqi backup shifrlansin, kalit nusxasi
  alohida himoyalangan joyda. Header/token, to‘liq GPS/ega bodylarini access
  logga yozmang. Telefonning OS blokirovkasi bo‘lsin; appning lokal fayllari
  alohida ilova darajasida shifrlangan deb da’vo qilinmaydi. Gallery/cloud
  auto-backupni pilot albomi uchun o‘chiring; ZIPni USB yoki kelishilgan lokal
  himoyalangan joyga ko‘chiring.
- **Zaxira:** DBning o‘zi yetmaydi — original fayllar, upload/registry receiptlar,
  raqamlash counter/high-water dalili va configlar birgalikda saqlanadi.
  Mavjud `tools/collection_storage.py` backup vaqtida API yozuvlarini vaqtincha
  to‘xtatib DB/fayl mosligini tekshiradi; `tools/phone_backup.py` telefon ZIP
  hashlarini tekshiradi. Bu rejada ular productionda ishga tushirilmadi.
  Taxminiy maqsad: har kecha nusxa, 7 kunlik + 4 haftalik retention,
  alohida O‘zbekiston joylashuvida shifrlangan nusxa va oflayn ikkinchi nusxa.
  Joy hisobida o‘zgarmagan JPEGlarni har kuni to‘liq takrorlamaslik kerak.
- **Restore sinovi:** yangi, ajratilgan DB/diskka tiklash; raqamlar/counter,
  receiptlar, original hashlar, qayta yuborish va L → MAA bog‘lanishini tekshirish.
  Eski backup bilan amaldagi raqamlash counterini orqaga qaytarish mumkin emas.
  Taklif etilgan RPO 24 soat / RTO 4 soat — sinovdan o‘tmaguncha kafolat emas.
- **Kuzatuv:** disk bo‘sh joyi, backup yoshi, konteyner health, 5xx va upload
  kechikishi; upload hajmi/timeouts va oz sonli parallel so‘rov bilan yuklama
  testi. Model aniqligi va molni haqiqatan tanish alohida dala baholashi.

Disk misoli: 100 mol × 3 tashrif × 6 tumshuq surat × taxminiy 2 MB ≈ **3.6 GB**;
haqiqiy JPEG hajmi o‘lchanmagan. Yon suratlar, raw AR depth, DB, backup retention
va o‘sish zaxirasi bundan tashqari. 100 GB degani cheksiz saqlash emas.

## Sardorbek tanlaydigan yakuniy qadam

Hamkorning joylashuv/kirish/retention shartlari + yozma hosting narxi olingach
variant va limitni tasdiqlash. Shundan keyingina akkaunt/xarid va alohida
production sozlash topshirig‘i. Hozirgi taskda deploy, xarid va real-data upload yo‘q.
