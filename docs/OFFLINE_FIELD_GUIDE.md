# Qishloqda serversiz yig‘ish — 2026-11-04

P0 oqimi: app ichida source YAML bilan bir xil oflayn qoidalar bor. Yangi
o‘rnatilgan telefonda server yoki API token shart emas. Samolyot rejimida
**Vositalar → Oflayn operatorni sozlash** orqali lotin harflarida masalan
`SARDOR-01` kiriting. Bu operator bayonoti; serverga kirish kaliti emas.

1. **Yangi vaqtinchalik hayvon**: birka yoki laqab, xohlasangiz Unicode izoh.
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

AR va yakuniy APK/verifikatsiya holati keyingi P1 milestone va root PROGRESS.md da
qayd qilinadi. Ulangan telefon bo‘lmasa host testlar native airplane/gallery/AR
sinov o‘rnini bosmaydi.
