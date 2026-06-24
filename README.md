# CM50 — Supabase Integration

Complete waitlist & investor validation system backed by Supabase.

---

## File structure

```
cm50-supabase/
├── index.html          ← Landing page (waitlist + survey forms)
├── admin.html          ← Protected admin dashboard
├── sql/
│   └── schema.sql      ← Run once in Supabase SQL Editor
├── js/
│   └── supabase-client.js  ← Shared client module (reference)
└── README.md
```

---

## 1. Create a Supabase project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. Click **New project** → choose your organisation → give it a name (e.g. `cm50`) → set a strong database password → pick a region close to your users.
3. Wait ~2 minutes for the project to provision.

---

## 2. Run the database schema

1. In your Supabase dashboard, go to **SQL Editor** (left sidebar).
2. Click **New query**.
3. Open `sql/schema.sql` from this folder and paste the entire contents.
4. Click **Run** (or press `Ctrl+Enter`).

This creates:
- `public.waitlist` table with all required columns and constraints
- Unique index on `email` (prevents duplicate signups)
- `updated_at` auto-trigger
- Row Level Security policies (public INSERT, authenticated SELECT/UPDATE)
- `waitlist_stats` view (aggregate stats for admin)
- `waitlist_by_day` view (signups per day)

---

## 3. Create an admin user

Supabase Auth is used to protect the admin dashboard.

1. Go to **Authentication → Users** in your dashboard.
2. Click **Add user → Create new user**.
3. Enter your admin email and a strong password.
4. Click **Create user**.

> You can add multiple admin users the same way.

---

## 4. Set your credentials

You need two values from **Settings → API**:

| Variable | Where to find it |
|---|---|
| `SUPABASE_URL` | "Project URL" — looks like `https://xyzabc.supabase.co` |
| `SUPABASE_ANON_KEY` | "anon public" key — starts with `eyJ…` |

Open **both** `index.html` and `admin.html` and replace the two placeholder constants near the top of each `<script>` block:

```js
// index.html  (line ~388)
const SUPABASE_URL      = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

// admin.html  (line ~316)
const SUPABASE_URL      = 'YOUR_SUPABASE_PROJECT_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';
```

> **Security note:** The `anon` key is safe to expose in browser code — it is intentionally public. Row Level Security policies ensure anonymous users can only INSERT, never SELECT or DELETE. Only authenticated admin users can read data.

---

## 5. Deploy

The project is two plain HTML files — no build step required.

### Option A — Static hosting (recommended)

Upload `index.html` and `admin.html` to any static host:

| Platform | Steps |
|---|---|
| **Vercel** | `npx vercel` in this folder, or drag-drop in the dashboard |
| **Netlify** | Drag the `cm50-supabase` folder onto netlify.com/drop |
| **GitHub Pages** | Push to a repo, enable Pages from the repo settings |
| **Cloudflare Pages** | Connect repo or drag-drop in the dashboard |
| **AWS S3 + CloudFront** | Upload files, enable static website hosting |

### Option B — Serve locally for testing

```bash
# Python 3
python3 -m http.server 3000

# Node.js (npx)
npx serve .

# Then open:
# http://localhost:3000/index.html
# http://localhost:3000/admin.html
```

---

## 6. Add your domain to Supabase CORS (if needed)

If you host on a custom domain (e.g. `cm50.io`), add it to the allowed origins:

1. **Authentication → URL Configuration** in your Supabase dashboard.
2. Add your site URL under **Site URL**.
3. Add `https://yourdomain.com` under **Redirect URLs** if you ever enable email magic links.

For the `anon` key / REST API, Supabase allows all origins by default. No additional CORS config is needed for basic INSERT/SELECT operations.

---

## How the data flows

### Waitlist form submission (`index.html`)

1. User fills in email (required), first name (optional), investment range (optional).
2. Client-side validation: format check with regex.
3. `INSERT` into `public.waitlist` with `source = 'waitlist_top'` or `'waitlist_bottom'`.
4. **Duplicate email** → Postgres unique constraint returns error code `23505` → graceful success shown (user sees confirmation, no double entry).
5. **DB error** → inline error message shown, form stays open.
6. Count strip refreshes via a `SELECT COUNT(*)` with `head: true`.

### Survey submission (`index.html`)

1. User completes 4-question step flow.
2. On submit, `UPSERT` into `public.waitlist` with survey fields (`reason`, `investing_frequency`, `objection`, `investment_range` from Q1, `source = 'survey'`).
3. Anonymous survey rows use a synthetic internal email so they don't conflict with real waitlist entries.

### Admin dashboard (`admin.html`)

1. Supabase Auth `signInWithPassword` — session stored in `localStorage`.
2. All data fetched via `SELECT * FROM waitlist ORDER BY created_at DESC LIMIT 1000`.
3. Aggregations (counts, capital estimates, distributions) computed client-side for speed.
4. Four tabs: Overview · Waitlist · Survey · All submissions.
5. Session persists across page refreshes (auto-refresh token enabled).

---

## Waitlist table schema (reference)

| Column | Type | Notes |
|---|---|---|
| `id` | `uuid` | Primary key, auto-generated |
| `email` | `text` | Required, unique |
| `first_name` | `text` | Optional |
| `investment_range` | `text` | e.g. `'5000-10000'` |
| `reason` | `text` | Survey Q2 answer key |
| `investing_frequency` | `text` | Survey Q3 answer key |
| `objection` | `text` | Survey Q4 answer key |
| `source` | `text` | `waitlist_top`, `waitlist_bottom`, or `survey` |
| `created_at` | `timestamptz` | Auto-set on INSERT |
| `updated_at` | `timestamptz` | Auto-updated via trigger |

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Failed to fetch" on form submit | Check `SUPABASE_URL` has no trailing slash and is the correct project |
| Sign-in says "Invalid login credentials" | Create user in **Auth → Users** in your dashboard |
| Admin sees no data after sign-in | Check RLS — confirm `allow_authenticated_select` policy exists (`sql/schema.sql` step 4) |
| Duplicate email shows error instead of success | Verify error code handling: the code checks `error.code === '23505'` |
| Count stays at `—` | The anon key needs `SELECT` on `waitlist` for `COUNT`. RLS `allow_public_select` is not included by design — add one limited to `COUNT(*)` if desired, or use a Postgres function |

---

## Security checklist

- [x] Row Level Security enabled on `waitlist`
- [x] Public INSERT only — no public SELECT or DELETE
- [x] Admin reads protected by Supabase Auth
- [x] Email validated client-side (regex) and server-side (Postgres CHECK constraint)
- [x] Duplicate emails rejected at DB level (UNIQUE constraint)
- [x] `anon` key used in browser (not `service_role`)
- [x] `service_role` key never exposed to the browser

---

*CM50 is under development and not currently available for investment.*
