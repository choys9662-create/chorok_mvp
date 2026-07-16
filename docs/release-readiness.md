# Release readiness — 2026-07-16

## Verified locally

- `flutter analyze` passed.
- `flutter test`: 158 passed, 1 skipped.
- Web release builds passed in real and design/mock modes.
- `flutter build ios --release --no-codesign` passed.
- The Flutter `.env` asset contains only `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
- The deployed Naver user-info proxy returns `401` without an Authorization header.
- Every non-automatic GitHub secret referenced by the current production workflow exists.

## Production Supabase snapshot

- Read-only checks found 47 migrations.
- The temporary timezone backup tables no longer exist.
- `delete_own_account()` is not executable by `anon`; it remains executable by `authenticated`.
- Security Advisor has 0 errors and 30 warnings.
- Local migration files cannot safely be pushed: 42 files / 41 unique versions versus 47 remote versions, two matching timestamps, and duplicate local version `20260518`.

## Applied in this run

- `20260716053311_harden_following_access_and_rpc_grants`:
  - private books and reading sessions now require an accepted follow;
  - four post-login RPCs no longer execute for `anon`;
  - future public-schema functions receive no default client execute grant;
  - four mutable function search paths are fixed.
- Post-apply checks confirmed the policy roles/conditions, RPC grants, default ACL, and search paths. Security Advisor warnings fell from 38 to 30.

### Emergency rollback for that migration

Only use a new reviewed migration if the authenticated app fails:

```sql
drop policy if exists books_select_following on public.books;
create policy books_select_following on public.books for select to public using (
  exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = books.user_id)
);
drop policy if exists sessions_select_following on public.reading_sessions;
create policy sessions_select_following on public.reading_sessions for select to public using (
  exists (select 1 from public.follows f where f.follower_id = auth.uid() and f.following_id = reading_sessions.user_id)
);
grant execute on function public.get_feed_activities(text, integer), public.live_reader_counts(), public.nearby_reader_count(integer), public.search_public_profiles(text, integer) to anon;
alter default privileges for role postgres in schema public grant execute on functions to anon, authenticated;
alter function public.popular_authors(integer) reset search_path;
alter function public.popular_books(integer) reset search_path;
alter function public.normalize_username(text) reset search_path;
alter function public.set_reading_started_at() reset search_path;
```

## Deliberately pending

1. **Migration rebaseline** — requires a frozen remote writer, CLI access token plus database password, then history repair and a reviewed `db pull` baseline. CI database deployment stays disabled until this is complete.
2. **Aladin credential rotation** — production `aladin-search` previously contained a hardcoded credential. Rotate it, set `ALADIN_API_KEY` as a Supabase secret, then deploy the recovered function source.
3. **Legal publication** — `https://chorok-web.web.app` exists, but its current privacy/terms paths return the generic site page. Supply the operator/business/contact/effective-date/overseas-transfer facts, then deploy real policy pages and links.
4. **Sign in with Apple** — confirm paid Apple Developer membership and enable the capability before adding its entitlement. The existing Release Family Controls entitlement remains intentionally untouched.
5. **Advisor warnings** — 30 warnings remain: managed extension placement, two anonymous privileged functions, eight authenticated privileged functions, Anonymous Sign-Ins enabled, and leaked-password protection disabled. Audit the remaining RPCs and change the two Auth dashboard settings before calling the app launch-ready.
