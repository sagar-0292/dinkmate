# 🏓 DinkMate

> **The Court Is Yours.** — The world's first premium social, matching & marketplace app exclusively for pickleball players.

[![Deploy to Netlify](https://www.netlify.com/img/deploy/button.svg)](https://app.netlify.com/start/deploy?repository=https://github.com/YOUR-USERNAME/dinkmate)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![PWA Ready](https://img.shields.io/badge/PWA-Ready-blue)](https://web.dev/progressive-web-apps/)

---

## 📱 Live Demo

**[dinkmate-beta.netlify.app](https://dinkmate-beta.netlify.app)** ← Try it on your phone

---

## ✨ Features

| Feature | Status |
|---------|--------|
| 📸 Social feed, stories & reels | ✅ Live |
| 💛 Tinder-style player matching + swipe | ✅ Live |
| 🏪 Marketplace — gear, coaching, courts | ✅ Live |
| 💬 In-app messaging & group chats | ✅ Live |
| 👤 Player profiles with DUPR ratings | ✅ Live |
| 🔔 Notifications & activity feed | ✅ Live |
| 📣 Ads & branded partnerships (Instagram model) | ✅ Live |
| 💾 Supabase backend — real data persistence | ✅ Live |
| 🔐 User authentication (email + OAuth) | ✅ Live |
| 📊 Analytics — Plausible.io | ✅ Live |
| 📲 PWA — installable on iOS & Android | ✅ Live |
| 🌍 Offline support (Service Worker) | ✅ Live |

---

## 🚀 Deploy in 5 Minutes

### Option 1 — Netlify (recommended)
```bash
# 1. Fork this repo
# 2. Go to app.netlify.com → "Import from Git"
# 3. Select your fork → set publish directory to "public"
# 4. Click Deploy
```

### Option 2 — Manual drag-and-drop
1. Download this repo as ZIP
2. Go to [netlify.app/drop](https://app.netlify.com/drop)
3. Drag the `public/` folder onto the page
4. Done — get your shareable URL

### Option 3 — GitHub Pages
```bash
# In repo Settings → Pages → Source: main branch → /public
# URL: https://YOUR-USERNAME.github.io/dinkmate
```

---

## 🗄️ Backend Setup (Supabase)

DinkMate uses [Supabase](https://supabase.com) — a free, open-source Firebase alternative.

### 1. Create project
```
https://app.supabase.com → New project → Name: dinkmate
```

### 2. Run database schema
```bash
# Copy contents of backend/schema.sql
# Paste into Supabase → SQL Editor → Run
```

### 3. Configure environment
```bash
cp .env.example .env
# Fill in your Supabase URL and anon key from:
# Supabase Dashboard → Settings → API
```

### 4. Update the app
In `public/index.html`, find the Supabase config block and replace:
```javascript
const SUPABASE_URL = 'https://YOUR-PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-KEY';
```

---

## 📁 Project Structure

```
dinkmate/
├── public/                 ← Deployable web app
│   ├── index.html          ← Full app (all screens)
│   ├── manifest.json       ← PWA config
│   ├── sw.js               ← Service worker (offline)
│   ├── icon-192.svg        ← App icon
│   └── icon-512.svg        ← Splash icon
│
├── backend/                ← Database & server
│   ├── schema.sql          ← Full PostgreSQL schema
│   ├── rls_policies.sql    ← Row-level security
│   ├── seed_data.sql       ← Sample data for testing
│   └── backup.sh           ← Automated backup script
│
├── src/                    ← Source components (React Native future)
│   ├── db.js               ← Supabase client
│   ├── auth.js             ← Authentication helpers
│   ├── analytics.js        ← Analytics helpers
│   └── backup.js           ← Data export utilities
│
├── scripts/                ← Utility scripts
│   ├── export-data.js      ← Export all user data to JSON
│   └── import-data.js      ← Restore from backup
│
├── docs/                   ← Documentation
│   ├── SETUP.md            ← Full setup guide
│   ├── ANALYTICS.md        ← Analytics events reference
│   ├── API.md              ← Supabase API reference
│   └── ROADMAP.md          ← Feature roadmap
│
├── .env.example            ← Environment variables template
├── .gitignore              ← Git ignore rules
├── netlify.toml            ← Netlify deployment config
├── package.json            ← Project metadata
└── README.md               ← This file
```

---

## 📊 Analytics Events

Every user action is tracked. See [docs/ANALYTICS.md](docs/ANALYTICS.md) for the full reference.

Key metrics:
- **Activation rate** — % users who reach Match screen
- **Swipe-to-match rate** — matches per 10 swipes
- **Session duration** — avg time in app
- **Marketplace CTR** — product views per session

---

## 🔒 Data & Privacy

- All user data stored in your own Supabase project (you own it)
- Row-Level Security (RLS) — users can only access their own data
- GDPR compliant — data export and deletion supported
- No third-party data sharing
- Automated daily backups via `backend/backup.sh`

---

## 🗺️ Roadmap

- [x] MVP — all screens, swipe engine, marketplace, messaging
- [x] PWA — installable, offline-capable
- [x] Analytics integration
- [x] Supabase backend — real data persistence
- [ ] Real-time messaging (Supabase Realtime)
- [ ] Push notifications (OneSignal)
- [ ] DUPR API integration
- [ ] Stripe payments
- [ ] React Native iOS/Android app
- [ ] AI matching algorithm (v2)

---

## 🤝 Contributing

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Commit: `git commit -m 'Add my feature'`
4. Push: `git push origin feature/my-feature`
5. Open a Pull Request

---

## 📄 License

MIT — see [LICENSE](LICENSE)

---

## 💬 Contact

Built with ❤️ for the pickleball community.
Questions? Open an issue or email hello@dinkmate.app
