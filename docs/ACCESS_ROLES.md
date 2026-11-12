# Pilotda rollar va kirish

Panel: **`https://<server>/panel/login`**. Shaxsiy login/parol yoki mavjud API
kaliti bilan kiring. Parol ham, bearer kalit ham URL yoki brauzer xotirasida
saqlanmaydi. Sessiya: 8 soat, HttpOnly + Secure + SameSite=Strict; yozuvchi
so‘rovlarda CSRF token talab qilinadi. API kalitlari avvalgidek ishlaydi.

| Rol | O‘qish | Yozish |
| --- | --- | --- |
| operator | O‘z profil paneli/sog‘lig‘i/suratlari; mavjud registr API o‘qishlari | Mol ro‘yxatlash, o‘z suratlari, o‘z molining egalik/so‘yish/sog‘liq/xulosalari, QR |
| veterinar | Hamkor paneli, sog‘liq, audit, suratlar | Sog‘liq hodisasi va tuzatuvchi qayd; ID/egalik/moliya/surat yuklash yo‘q |
| bank_viewer | Hamkor paneli va qaydlar | Biznes ma’lumotini o‘zgartirmaydi |
| bank_officer | Hamkor paneli va qaydlar | Faqat moliyaviy holat: expected_version + sabab + audit |
| admin | Barcha pilot qaydlari | Barcha ruxsat etilgan amallar, bozor narxi, takrorlarni ko‘rib chiqish |

Veterinar belgisi faqat serverdagi autentifikatsiyalangan **veterinar** roli
yozgan hodisada chiqadi. Veterinar ismini qo‘lda yozish tasdiq bermaydi. Operator
vet hodisasini tuzata olmaydi; admin tuzatsa yangi qayd operator/admin qaydi,
vet tasdig‘i emas. QR ko‘rik sanasiga eski, keyin tuzatilgan vet hodisasi kirmaydi.

Bu bitta kelishilgan pilot muhit; alohida bank/fermalar tenantlari va qonuniy
ma’lumot almashish vakolati avtomatik tayyor bo‘lmaydi. Bank statusi sug‘urta
polisi yoki kredit shartnomasini o‘zi yaratmaydi.

## Foydalanuvchi yaratish — faqat server administratori

Konteyner ichida (server xarid qilingach, to‘g‘ri Compose loyihasini tanlang):

```sh
docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env exec api python /srv/tools/manage_users.py create --username pilot-admin --operator-id STAFF-ADMIN --role admin --actor LOCAL-ADMIN
docker compose -p chorvam-pilot -f backend/docker-compose.prod.yml --env-file /srv/chorvam/pilot.env exec api python /srv/tools/manage_users.py create --username pilot-vet --operator-id STAFF-VET --role veterinar --actor LOCAL-ADMIN
```

Parol terminalda yashirin so‘raladi, kamida 12 belgi. Standart parol yo‘q.
`--password-file` faqat maxfiy lokal avtomatlashtirish fayli uchun; `.secrets/`
ichida saqlang, gitga qo‘shmang. Login kichik lotin belgilarida; operator IDsi
doimiy va boshqa parol/API-kalit shaxsining IDsi bilan bir xil bo‘lolmaydi.

`set-role --username ... --role ... --actor ...`, `disable --username ...
--actor ...`, `reset-password --username ... --actor ...` shu CLI buyruqlari.
Har o‘zgarish access auditga yoziladi va faol sessiyalar bekor qilinadi.
Oxirgi faol parolli adminni o‘chirib/oddiy rolga tushirib bo‘lmaydi. Account
o‘chirish buyrug‘i yo‘q. API kalit fayli o‘zgarsa backendni qayta ishga tushiring.

Kirish cheklovi umumiy PostgreSQL hisoblagichi bilan, workerlar orasida bir xil:
standart 5 so‘rov/IP/60 soniya va 10 parol urinish/login/300 soniya. Ishonchsiz
`X-Forwarded-For` hisoblagichni chetlab o‘tolmaydi. Parol Argon2id: standart
64 MiB, 3 aylanish, 4 parallel yo‘l; qiymatlar server settingsda. HTTPS reverse
proxy va aniq ishonchli proxy chegarasi deployment bosqichida tekshiriladi.
