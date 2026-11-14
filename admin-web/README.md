# Savarun admin website (admin.savarun.com)

This folder is a separate Railway service. It only serves the static Flutter web build of the admin app (`app/lib/main_admin.dart`). All data comes from the backend (`https://sawarun-app-production.up.railway.app/api/admin`), which checks for an admin Firebase token.

## Update the admin build

Run from `app/`:

```sh
flutter build web -t lib/main_admin.dart --release --base-href / --output build/admin-root
```

Then replace `admin-web/public` with the build output, leaving out `canvaskit/`. Flutter loads CanvasKit from Google's CDN.

```sh
rm -rf ../admin-web/public && mkdir ../admin-web/public
cp -r build/admin-root/. ../admin-web/public/ && rm -rf ../admin-web/public/canvaskit
```

Commit and push. Railway redeploys the service.

## Railway service settings

| Setting | Value |
|---|---|
| Source | the same GitHub repo as the backend |
| Root directory | `/admin-web` |
| Build command | none |
| Start command | `npm start` |
| Healthcheck path | `/health` |
| Variables | none (Railway sets `PORT`) |
| Custom domain | `admin.savarun.com` |

## Other places that need the domain

- **Backend `CORS_ORIGINS`** (Railway → backend service → Variables): add `https://admin.savarun.com`. Without it, every API call from the admin site fails.
- **Firebase → Authentication → Settings → Authorized domains**: add `admin.savarun.com`.
- **DNS (GoDaddy, savarun.com)**: add a CNAME record for `admin`, pointing to the target that Railway shows when you add the custom domain.
