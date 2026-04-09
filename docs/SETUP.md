# DinkMate — Full Setup Guide

## Prerequisites
- GitHub account (free) — github.com
- Supabase account (free) — supabase.com
- Netlify account (free) — netlify.com
- Node.js 18+ (optional, for local dev)

---

## Step 1 — Fork & Clone

```bash
# Fork on GitHub, then:
git clone https://github.com/YOUR-USERNAME/dinkmate.git
cd dinkmate
cp .env.example .env
```

---

## Step 2 — Supabase Setup (database + auth)

### 2a. Create project
1. Go to https://app.supabase.com → New project
2. Name: `dinkmate`, choose a strong password, pick your region
3. Wait ~2 minutes for provisioning

### 2b. Run the schema
1. In Supabase dashboard → SQL Editor → New query
2. Copy contents of `backend/schema.sql` → Run
3. Copy contents of `backend/rls_policies.sql` → Run

### 2c. Get your keys
1. Settings → API
2. Copy `Project URL` → your `SUPABASE_URL`
3. Copy `anon public` key → your `SUPABASE_ANON_KEY`
4. Copy `service_role` key → your `SUPABASE_SERVICE_KEY` (keep private!)

### 2d. Configure the app
Open `public/index.html`, find this block (near the bottom, in the `<script>` tag):
```javascript
window.DINKMATE_CONFIG = {
  supabaseUrl: 'https://YOUR-PROJECT.supabase.co',
  supabaseKey: 'YOUR-ANON-KEY'
};
```
Replace with your actual values.

### 2e. Enable Auth providers
Supabase Dashboard → Authentication → Providers:
- ✅ Email (enabled by default)
- ✅ Google (add OAuth credentials from console.cloud.google.com)
- ✅ Apple (add credentials from developer.apple.com)

---

## Step 3 — Deploy to Netlify

### Option A: GitHub integration (auto-deploys on push)
1. Go to app.netlify.com → Add new site → Import from Git
2. Select your fork
3. Build settings:
   - Build command: *(leave empty)*
   - Publish directory: `public`
4. Click Deploy
5. Set custom domain: Site Settings → Domain → `dinkmate-beta.netlify.app`

### Option B: Drag-and-drop
1. Go to app.netlify.com/drop
2. Drag the `public/` folder onto the page

### Add secrets (for GitHub Actions auto-deploy)
In GitHub repo → Settings → Secrets → Actions:
- `NETLIFY_AUTH_TOKEN` — from Netlify Profile → Personal access tokens
- `NETLIFY_SITE_ID` — from Netlify Site Settings → General → Site ID

---

## Step 4 — Analytics

### Plausible (recommended — privacy-first)
1. Sign up at plausible.io → Add site → enter your Netlify URL
2. In `public/index.html`, find the Plausible script and replace `YOUR-DOMAIN.netlify.app`
3. Dashboard updates within 24 hours of first visitors

### Netlify Analytics (built-in, no setup)
Site dashboard → Analytics → Enable (shows basic stats free)

---

## Step 5 — Set Up Backups

```bash
# Set environment variables
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_SERVICE_KEY="your-service-role-key"

# Run manual backup
bash backend/backup.sh

# Set up daily automated backup (cron)
crontab -e
# Add: 0 2 * * * cd /path/to/dinkmate && bash backend/backup.sh
```

### Cloud backup (optional)
Uncomment the S3/R2 upload line in `backend/backup.sh` and configure:
```bash
AWS_BUCKET=your-bucket
AWS_REGION=us-east-1
```

---

## Step 6 — Share with 500 Users

Once deployed, share the link in your message:

```
Try DinkMate (beta): https://dinkmate-beta.netlify.app

On iPhone: Safari → Share → Add to Home Screen
On Android: Chrome → Menu → Add to Home Screen
```

---

## Local Development

```bash
npm install
npm run dev
# Opens http://localhost:3000
```

---

## Export All Data

```bash
# Export everything
node scripts/export-data.js

# Export one user's data
node scripts/export-data.js --user USER-UUID

# Export one table
node scripts/export-data.js --table profiles
```

---

## Troubleshooting

**App shows blank page**
→ Check browser console for errors
→ Verify `public/index.html` exists and is not empty

**Supabase connection fails**
→ Check SUPABASE_URL and SUPABASE_ANON_KEY are set correctly in index.html
→ Check Supabase project is not paused (free tier pauses after 1 week inactivity)
→ App runs in demo mode without Supabase — no data is saved

**PWA not installing on iPhone**
→ Must be opened in Safari (not Chrome on iOS)
→ Site must be HTTPS (Netlify provides this automatically)
→ Tap Share icon → "Add to Home Screen"

**Analytics not showing**
→ Plausible takes 24h to populate
→ Ad blockers may block tracking — Plausible is usually unblocked
→ Check the domain in the script tag matches your Netlify URL exactly
