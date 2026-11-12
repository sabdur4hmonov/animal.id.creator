# Chorvam — pilot serverga chiqarish tartibi

Holat: **2026-11-12**. Bu tayyorlash to‘plami. Server/domen sotib olinmadi,
real ma’lumot yoki ishlayotgan oddiy stack o‘zgartirilmadi. Avval
[PILOT_SERVER_PLAN.md](PILOT_SERVER_PLAN.md) va [ACCESS_ROLES.md](ACCESS_ROLES.md).

## 1. Tashqi ishlar — Sardorbek tasdig‘i bilan

O‘zbekistondagi server, domen, DNS, hamkorning ma’lumotga kirish vakolati va
zaxiraning ikkinchi xavfsiz joyini kelishing. Boshlang‘ich reja 4 vCPU / 8 GB
RAM / 100–150 GB SSD, benchmark kafolati emas. Ko‘payadigan backup va restore
clone uchun ham disk ajrating. Shu ishlar tayyor bo‘lmaguncha public deploy yo‘q.

Yangi Linux serverda Docker Engine + Compose v2 va Python 3.12+ kerak.
[Dockerning rasmiy Ubuntu tartibi](https://docs.docker.com/engine/install/ubuntu/).
Hostda Torch/Ultralytics o‘rnatish shart emas; backup/monitor standart Python
bilan ishlaydi. Faqat SSH va 80/443 kirishi ochiladi; PostgreSQL/API host porti yo‘q.

## 2. Kod, yangi maxfiy fayllar va disk

Yangi server uchun; mavjud papka yoki bazani almashtirmang:

```sh
sudo git clone https://github.com/sabdur4hmonov/animal.id.creator.git /opt/chorvam
sudo install -d -m 0700 /srv/chorvam
sudo python3 /opt/chorvam/tools/init_pilot_secrets.py --output /srv/chorvam/secrets --prefix PILOT
sudo chown 10001:10001 /srv/chorvam/secrets/database_url /srv/chorvam/secrets/api_keys.json
sudo chmod 0400 /srv/chorvam/secrets/database_url /srv/chorvam/secrets/api_keys.json
sudo install -d -o 10001 -g 10001 -m 0700 /srv/chorvam/storage
sudo install -d -m 0700 /srv/chorvam/backups /srv/chorvam/restore-checks
sudo cp /opt/chorvam/backend/deploy/.env.example /srv/chorvam/pilot.env
sudo chmod 0600 /srv/chorvam/pilot.env
sudoedit /srv/chorvam/pilot.env
```

**Oldin oflayn surat olingan bo‘lsa**, secret yaratish buyrug‘iga
`--operator-id ASL_OFLAYN_OPERATOR` qo‘shing: ilovadagi Vositalar’da ko‘ringan
aniq ID. Keyinchalik xato operator bilan suratlarni yuborish uchun eski
metadata/IDni tahrirlamang. Kalitlar hali mavjud bo‘lsa init qayta ishlamaydi;
ustidan yozish/raqam counterini reset qilish yo‘q.

Env faylda `CHORVAM_DOMAIN` va `PUBLIC_ORIGIN=https://haqiqiy-domen`ni to‘ldiring.
`.invalid` misoli ataylab haqiqiy manzil emas. DNS shu serverga qarasin.
`PILOT_STORAGE_ROOT`/`PILOT_SECRETS_ROOT` yuqoridagi yangi yo‘llar bo‘lsin.
Private subnet bo‘shligini tekshiring; uni almashtirsangiz proxy IP ham o‘sha
subnetdan bo‘lsin. API faqat shu bitta proxy IPdan forwarded header qabul qiladi.
Local testning runtime image override yoki `tls-local.caddy`ini public serverga
ko‘chirmang: standart base/image va `tls-public.caddy` ishlatiladi.

Secret fayllarda standart parol yo‘q. `tokens.json` — administratorning shaxsiy
fayli, gitga/ommaviy APKga/logga tushmasin. API konteyneri UID 10001 bilan
readonly ishlaydi; yuqoridagi ikki faylning egasi shuning uchun moslanadi.
Database URL fayldan o‘qiladi; Compose’da API paroli environment qiymati emas.

## 3. Ishga tushirish va kirish

```sh
cd /opt/chorvam
sudo docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env config --quiet
sudo docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env up -d --build
sudo docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env ps
curl --fail https://HAQIQIY_DOMEN/health
sudo docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env exec api python /srv/tools/manage_users.py create --username pilot-admin --operator-id STAFF-ADMIN --role admin --actor LOCAL-ADMIN
```

Admin paroli terminalda yashirin so‘raladi. `STAFF-ADMIN` API-kalitdagi
`PILOT-ADMIN`dan boshqa shaxs; bir IDni ikki xil hisobga berish taqiqlangan.
Panel: `/panel/login`. Kerakli veterinar/bank xodimlarini shu CLI orqali
tegishli rol bilan yarating. Tashxis/garov/sug‘urta huquqini o‘zboshimchalik bilan
hamkorga bermang; bitta kelishilgan pilotdagi real vakolatga moslang.

`/health`: database `ok`, muzzle model **pending_model** — checkpoint hali yo‘q.
HTTPS sertifikatini Caddy oladi/yangilaydi. Public QR registr qaydi, laboratoriya
tahlili yoki go‘sht xavfsizligi tasdig‘i emas. Vaznlar taxminiy; real dala aniqligi
va kalibratsiya hali isbotlanmagan. Moliyaviy status shartnoma yaratmaydi.

## 4. Zaxira, restore tekshiruvi va monitoring

Avval qo‘lda bir marta:

```sh
cd /opt/chorvam
sudo python3 tools/pilot_backup.py --compose-file backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env --project chorvam-pilot --storage-root /srv/chorvam/storage --backup-root /srv/chorvam/backups --restore-root /srv/chorvam/restore-checks
sudo python3 tools/pilot_monitor.py --url https://HAQIQIY_DOMEN/health --project chorvam-pilot --disk-root /srv/chorvam --backup-root /srv/chorvam/backups
```

Backup qisqa vaqt **faqat ko‘rsatilgan loyihaning API**sini to‘xtatadi va oldin
ishlab turgan bo‘lsa qayta yoqadi. PG dump + original rasmlar + config + SHA
manifest; keyin yangi `biolivestock_restore_...` baza va yangi clone papkada
tekshiruv. Table counts, schema revision, rasm hash/inventory va raqam counter
yuqori chegarasi solishtiriladi. Natija `*-verified.json`da, bundle tashqarisida.
Clone hech qachon ishchi bazaga ulanmaydi yoki uning raqamlarini orqaga surmaydi.

Hech qanday backup, clone yoki orphan avtomatik o‘chirilmaydi. Diskni nazorat
qiling: standart kamida 10 GiB bo‘sh joy, backup yoshi 26 soatdan oshmasligi kerak.
Clonelar ham joy oladi. `.backup-running` qolib ketsa avval jarayonni tekshiring;
tool birovning lockini o‘zi o‘chirmaydi. Backup shaxsiy ma’lumot/hashlarni o‘z
ichiga oladi: 0700/0600 himoya, ikkinchi shifrlangan xavfsiz nusxa kerak.
Secretlar va TLS kalitlari bu collection bundle ichiga kirmaydi; ularni ham
alohida himoyalangan joyda saqlang. Ikkinchi joy/xarajat hali tanlanmagan.

Keyin yangi serverda vaqt rejasini yoqing:

```sh
cd /opt/chorvam
sudo install -m 0644 backend/deploy/chorvam-backup.service backend/deploy/chorvam-backup.timer backend/deploy/chorvam-monitor.service backend/deploy/chorvam-monitor.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now chorvam-backup.timer chorvam-monitor.timer
sudo systemctl list-timers 'chorvam-*'
sudo journalctl -u chorvam-backup.service -u chorvam-monitor.service --since today
```

Backup 02:00 **Asia/Tashkent**, monitoring har 5 daqiqada. Systemd unitlari
tayyorlangan, haqiqiy Linux VPSda yoqilgani tekshirilmagan. Monitor xatoda nonzero
qaytaradi/jurnalga yozadi; tashqi SMS/email xizmati ulanmagan.
Docker loglari 10 MB × 3/service aylantiriladi. API access URI logi o‘chiq;
Caddy URI/headersni chiqarib tashlaydi: QR token, cookie va bearer kalit loglanmaydi.

## 5. Avariya va yangilash

Avval tekshirilgan backup oling; kodni oddiy fast-forward bilan yangilang.
Migrations additive, ammo deploy oldidan yangi nusxada tekshiring. `down -v`,
ishchi bazaga `pg_restore --clean`, counter reset yoki eski backupni livega
ulash bu tartibning qismi emas. Real restore/promotion — alohida Sardorbek
tasdig‘i va backupdan keyingi chiqarilgan IDlar yuqori chegarasini tekshirish
bilan. Noma’lum yuqori chegarada yangi ID chiqarmang. [ANIMAL_REGISTRY.md](ANIMAL_REGISTRY.md).

## Lokal dalilni qayta bajarish

Repo `.venv`dan `python tools/verify_pilot_deployment.py`: faqat
`chorvam-prodverify-20261112`, loopback 18443/18480 va ignored
`data/verification-prod-20261112` ishlatiladi. Boshqa stackka tegmaydi. Mahalliy
CA faqat test klientiga beriladi; Windows trust-store o‘zgarmaydi. Sintetik JPEG
upload/replay/hash/pending_model, haqiqiy TLS cookie/CSRF/vet oqimi, QR maxfiyligi
va log redaction tekshiriladi. Bu brauzerning vizual/JavaScript yoki telefon
sinovi emas. Sovuq yangi VPS buildi emas: lokal tekshiruv tasdiqlangan CPU runtime
qatlamini qayta ishlatgan, barcha pinned dependencylar va yangi kod konteynerda ishlagan.
