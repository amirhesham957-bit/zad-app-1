# النسخة الاحتياطية لقاعدة البيانات

**قرار المالك ٢٠٢٦-١١-٠٧:** نفضل على باقة سوبابيز المجانية دلوقتي. المجانية مافيهاش نسخ احتياطية
ترجعها من اللوحة (Pro = آخر ٧ أيام)، ولا حماية الباسوردات المسربة (Pro وفوق — من دوكس سوبابيز).
البديل: `.github/workflows/db-backup.yml`.

## بيعمل إيه
كل ليلة ٢:٢٣ UTC (أو يدوي من Actions ← DB Backup ← Run workflow):
`supabase db dump` للأدوار والهيكل والداتا ⇐ `tar.gz` ⇐ تشفير AES-256 بـ`gpg` بعبارة سر ⇐
artifact اسمه `zad-db-<التاريخ>` بيتمسح بعد ٧ أيام. الرن بيفشل أحمر لو سر ناقص، أو لو الداتا
مافيهاش `zad_entitlements` أو `zad_transactions` أو `auth.users`، أو لو الملف طلع من غير تشفير.

## اللي على المالك مرة واحدة
1. اعمل عبارة سر طويلة (٢٠ حرف أو أكتر)، واحفظها في مدير كلمات السر. **لو ضاعت، النسخ كلها ماتتفتحش.**
2. GitHub ← الريبو ← Settings ← Secrets and variables ← Actions ← New repository secret:
   `ZAD_BACKUP_PASSPHRASE` = العبارة. (الجلسة مالهاش صلاحية على أسرار Actions — لازم إيد.)
3. Actions ← DB Backup ← Run workflow، وتأكد إن الرن أخضر وفيه artifact.

`SUPABASE_ACCESS_TOKEN` و`SUPABASE_DB_PASSWORD` موجودين أصلاً لنشر `edge-functions.yml`.

## الاسترجاع
نزّل الـartifact من صفحة الرن، وبعدين:
```bash
gpg -d zad-db-YYYYMMDD-HHMM.tar.gz.gpg | tar xz      # بيطلب العبارة
# DB_URL = Connection string (Session pooler) من لوحة المشروع ← Connect
psql "$DB_URL" -f roles.sql
psql "$DB_URL" -f schema.sql
psql "$DB_URL" -c 'SET session_replication_role = replica' -f data.sql
```
الاسترجاع على **مشروع جديد فاضي** الأول، مش فوق الإنتاج — نفس خطوات دوكس سوبابيز
«Backup and restore using the CLI». الأسرار (Edge Function secrets) والكرون اللي بيقرا
`zad_cron_secret` مش جوه الدامب بالشكل اللي يشتغل لوحده — لازم يتراجعوا بعد الاسترجاع.

## حدودها
- ٧ أيام بس، ومفيش Point-in-Time: اللي اتكتب بعد آخر نسخة ضايع.
- الـartifacts بتتحسب من مساحة GitHub Actions اللي خلصت مرة قبل كده (٢٠٢٦-٠٩-١٢، من الـAPK).
  القاعدة ~١٠٥ ميجا والدامب المضغوط أصغر بكتير، بس لو المساحة خلصت تاني الرفع هيفشل أحمر.
- ملفات Storage (صور الفواتير والنشرات) **مش** جوه الدامب — بس صفوفها.
