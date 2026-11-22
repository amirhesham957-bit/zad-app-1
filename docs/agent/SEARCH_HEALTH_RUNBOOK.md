# Runbook: الترندز / تيك توك / العروض مابتوصلش

استخدم الـqueries دي للقراءة بس (read-only). ماتعدلش حاجة من غير ما المالك يقول.

## 1) إيه اللي واقف؟

```sql
select source, until, reason from zad_search_source_rest order by 1;
```

## 2) ميزانية البحث (CSE)

```sql
select day, purpose, used from zad_cse_budget order by day desc limit 8;
```

## 3) البحث في آخر 24 ساعة

```sql
select source, country, count(*) searches, sum(hits) hits, max(searched_at) from zad_deal_search_log where searched_at > now() - interval '24 hours' group by 1,2 order by 1,2;
```

## 4) السوشيال اللي اتلقط

```sql
select platform, country, count(*), max(found_at) from zad_social_picks group by 1,2;
```

## 5) ردود الكرون

```sql
select created, status_code, left(content,300) from net._http_response where created > now() - interval '8 hours' order by created desc limit 12;
```

## معاني اللي شفناه يوم 2026-11-22

- `tavily:432` = الكوتة خلصت. محتاج تجديد أو مفتاح جديد.
- `google_news:429` = اتحظر مؤقتاً (rate limit). بيفك نفسه بعد شوية.
- `search: none` في الـJSON بتاع الكرون = مفيش provider رجّع نتايج.
- `instagram OAuthException/110` = مشكلة في الـtoken أو الصلاحيات.
- حالة الكرون `succeeded` معناها بس إن الـHTTP call اتبعت. مش معناها إن البحث نجح. اقرا الـcontent.

## الإصلاح عند المالك

- تجديد اشتراك Tavily، أو إضافة مفتاح Brave.
- تجديد توكن Instagram.

## ملاحظات

- تيك توك مفيهوش API تجاري، فبيعتمد على البحث في الويب بس.
- YouTube على الـAPI الرسمي، وبيشتغل لوحده ومايتأثرش بالحاجات اللي فوق.
