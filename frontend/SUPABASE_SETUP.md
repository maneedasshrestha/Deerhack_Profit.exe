# Supabase signup wiring — your setup steps (Android, native Google)

The app code is done. It uses **native Google sign-in → `signInWithIdToken`**, writes a
**`profiles`** row, and uploads the avatar to a **`avatars`** Storage bucket.
Until you supply config via `--dart-define`, the app safely falls back to the mock
sign-in, so it keeps running.

Do the steps below, then run with the `--dart-define` command at the bottom.

Your Android package name (you'll need it): **`com.example.frontend`**

---

## 1. Supabase project → URL + anon key
1. Open your project at https://supabase.com/dashboard.
2. **Project Settings → API**. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon / public** key (the long `eyJ…` JWT) → `SUPABASE_ANON_KEY`
3. Note your **project ref** (the `xxxx` in `https://xxxx.supabase.co`) — used in step 2.

---

## 2. Google Cloud Console → OAuth client IDs
Console: https://console.cloud.google.com/apis/credentials (create/select a project).

### 2a. OAuth consent screen
- **APIs & Services → OAuth consent screen** → External → fill app name + your email.
- Add scopes `.../auth/userinfo.email`, `.../auth/userinfo.profile`, `openid`.
- While in **Testing** mode, add your Google account under **Test users** (otherwise
  sign-in is blocked).

### 2b. Web client (used by Supabase + as `GOOGLE_WEB_CLIENT_ID`)
- **Credentials → Create credentials → OAuth client ID → Web application**.
- **Authorized redirect URIs** → add:
  `https://<YOUR-PROJECT-REF>.supabase.co/auth/v1/callback`
- Save. Copy the **Client ID** → this is `GOOGLE_WEB_CLIENT_ID`. Copy the **Client secret** too (step 4).

### 2c. Android client (so the device is allowed to issue ID tokens)
- **Create credentials → OAuth client ID → Android**.
- **Package name:** `com.example.frontend`
- **SHA-1 fingerprint:** get your *debug* SHA-1 (see step 3), paste it.
- Save. Copy this **Android Client ID** (needed in step 4b).

> Release builds use a different SHA-1 — add a second Android client (or the release
> SHA-1) before shipping a signed APK.

---

## 3. Get your debug SHA-1
Easiest (from the project root, in the `android` folder):

```bash
cd android && ./gradlew signingReport
```
Look for the **`debug`** variant's `SHA1:` line.

Or directly via keytool:

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```
On Windows the keystore is at `%USERPROFILE%\.android\debug.keystore`.

---

## 4. Supabase → enable Google provider
**Authentication → Providers → Google** (or **Sign In / Providers**):
1. **Enable** it.
2. Paste the **Web** client ID (2b) into **Client ID** and the **Client secret** into **Client Secret**.
3. **Authorized Client IDs** (critical for native sign-in): add **both** the
   **Web client ID** and the **Android client ID** (2c), comma-separated. This is what
   lets Supabase accept the ID token minted on the device (its audience is one of these).
4. Save.

---

## 5. Database → `profiles` table + RLS
**SQL Editor → New query**, run:

```sql
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  full_name    text,
  email        text,
  photo_url    text,
  exam_id      text,
  exam_name    text,
  exam_date    timestamptz,
  target_marks int,
  total_marks  int,
  daily_hours  numeric,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles for select using (auth.uid() = id);

create policy "profiles_insert_own"
  on public.profiles for insert with check (auth.uid() = id);

create policy "profiles_update_own"
  on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);
```

---

## 6. Storage → `avatars` bucket + policies
Run in the SQL Editor (creates a **public** bucket so the avatar URL renders directly):

```sql
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- Each user may write only under a folder named after their own uid: avatars/<uid>/...
create policy "avatars_insert_own"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_update_own"
  on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "avatars_read_all"
  on storage.objects for select using (bucket_id = 'avatars');
```

(The app uploads to `avatars/<uid>/avatar.jpg`, matching these policies.)

---

## 7. Run the app with your config
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<YOUR-PROJECT-REF>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGci... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=<WEB-CLIENT-ID>.apps.googleusercontent.com
```

> Use the **Web** client ID for `GOOGLE_WEB_CLIENT_ID` (not the Android one). On Android,
> google_sign_in passes it as `serverClientId`; the Android client is matched behind the
> scenes by package name + SHA-1.

To avoid typing it each time, put the three values in `dart_defines.json`:
```json
{ "SUPABASE_URL": "...", "SUPABASE_ANON_KEY": "...", "GOOGLE_WEB_CLIENT_ID": "..." }
```
and run `flutter run --dart-define-from-file=dart_defines.json`
(add that file to `.gitignore` if you prefer not to commit it).

---

## Verify it worked
- Tap **Continue with Google** → native account sheet (not a browser).
- Finish onboarding → **Table Editor → profiles** shows your row; **Storage → avatars**
  shows `…/avatar.jpg`; **Authentication → Users** shows your account.

## Gotchas
- "Access blocked / app not verified" → add your account under **Test users** (2a).
- Sign-in returns null/no token → SHA-1 or package name mismatch in the **Android** client (2c).
- `PostgrestException 42501` (RLS) → re-check the policies in steps 5–6.
- minSdk: google_sign_in needs 21+. This project uses Flutter's default, which is fine.
