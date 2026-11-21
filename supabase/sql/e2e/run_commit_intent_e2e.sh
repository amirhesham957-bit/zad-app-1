#!/usr/bin/env bash
# م٢.٥ e2e محلي: Postgres (حاوية zadpg أو أي postgres:17) + PostgREST + كود العقل الحقيقي. مش الحي أبداً.
set -euo pipefail
cd "$(dirname "$0")/../../.."
PG=${PG_CONTAINER:-zadpg}; DB=${E2E_DB:-t_e2e_commit_intent}; PORT=${E2E_PORT:-3901}; REST=${E2E_REST:-zad-e2e-rest}; SECRET=e2e-local-secret-at-least-32-characters-long
docker exec "$PG" dropdb -U postgres --if-exists "$DB"; docker exec "$PG" createdb -U postgres "$DB"
for f in supabase/sql/tests/events_ledger_scaffold.sql supabase/migrations/20261121160000_events_ledger.sql \
         supabase/sql/tests/commit_intent_scaffold.sql supabase/migrations/20261121180000_commit_intent.sql \
         supabase/migrations/20261121200000_commit_intent_merge.sql supabase/migrations/20261121220000_commit_intent_domains.sql supabase/sql/tests/commit_intent_shopping_scaffold.sql \
         supabase/migrations/20261121230000_commit_intent_shopping.sql supabase/sql/tests/commit_intent_pharmacy_scaffold.sql \
         supabase/migrations/20261122000000_commit_intent_pharmacy.sql supabase/sql/tests/commit_intent_money_scaffold.sql \
         supabase/migrations/20261122010000_commit_intent_money.sql supabase/sql/tests/commit_intent_budgets_scaffold.sql \
         supabase/migrations/20261122020000_commit_intent_money_budgets.sql supabase/migrations/20261122030000_commit_intent_every_domain.sql \
         supabase/sql/e2e/commit_intent_e2e_scaffold.sql; do
  docker exec -i "$PG" psql -U postgres -d "$DB" -v ON_ERROR_STOP=1 -q < "$f" > /dev/null
done
docker rm -f $REST > /dev/null 2>&1 || true
docker run -d --name $REST -p $PORT:3000 \
  -e PGRST_DB_URI="postgres://authenticator:pg@$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$PG"):5432/$DB" \
  -e PGRST_DB_SCHEMAS=public -e PGRST_DB_ANON_ROLE=anon -e PGRST_JWT_SECRET="$SECRET" postgrest/postgrest:v12.2.3 > /dev/null
trap 'docker rm -f $REST > /dev/null' EXIT
ready=0; for _ in $(seq 40); do curl -sf localhost:$PORT/ > /dev/null && { ready=1; break; }; sleep 0.5; done
[ "$ready" = 1 ] || { docker logs $REST | tail -5; echo "PostgREST never came up"; exit 1; }
KEY=$(deno eval --quiet "
  const k = await crypto.subtle.importKey('raw', new TextEncoder().encode('$SECRET'), {name:'HMAC',hash:'SHA-256'}, false, ['sign']);
  const b = (o) => btoa(JSON.stringify(o)).replace(/=+\$/,'').replace(/\+/g,'-').replace(/\//g,'_');
  const body = b({alg:'HS256',typ:'JWT'}) + '.' + b({role:'service_role'});
  const sig = new Uint8Array(await crypto.subtle.sign('HMAC', k, new TextEncoder().encode(body)));
  console.log(body + '.' + btoa(String.fromCharCode(...sig)).replace(/=+\$/,'').replace(/\+/g,'-').replace(/\//g,'_'));")
E2E_URL=http://localhost:$PORT E2E_KEY=$KEY deno run --allow-all --no-check supabase/sql/e2e/commit_intent_e2e.ts
