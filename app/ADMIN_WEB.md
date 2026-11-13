# Savarun web admin dashboard

A separate Flutter web app for admins. It lives in this project: the entry point is
`lib/main_admin.dart` and all its code is in `lib/admin_web/`. The consumer
app (`lib/main.dart`) is unchanged.

Only accounts with the Firebase custom claim `admin: true` can use it. Anyone
else who signs in sees "Access denied".

## Run locally

```sh
flutter run -d chrome -t lib/main_admin.dart --web-port 5700 --dart-define=BACKEND_URL=https://sawarun-app-production.up.railway.app
```

To use a local backend, leave out `--dart-define`. Debug builds default to
`http://localhost:4000`.

## Build

```sh
flutter build web -t lib/main_admin.dart --release --output build/admin --dart-define=BACKEND_URL=https://sawarun-app-production.up.railway.app
```

The consumer web build still goes to `build/web`, so the two builds don't overwrite each other.

## Deploy (Firebase Hosting, project `savarun-app-b775b`)

`firebase.json` has two hosting targets, and `.firebaserc` maps them to sites:

- `app` is `build/web`, deployed to site `savarun-app-b775b`.
- `admin` is `build/admin`, deployed to site `savarun-admin`.

Do these once:

```sh
firebase hosting:sites:create savarun-admin --project savarun-app-b775b
```

Also add `savarun-admin.web.app` (and `savarun-admin.firebaseapp.com`) under
**Firebase console → Authentication → Settings → Authorized domains**.
Without them, Google sign-in and phone sign-in fail on the deployed site.

Deploy:

```sh
firebase deploy --only hosting:admin --project savarun-app-b775b
```

Since `hosting` is now a list of targets, deploy the consumer site with
`--only hosting:app`. A plain `--only hosting` deploys both sites.

## Backend requirements

- **CORS:** in production the backend uses the `CORS_ORIGINS` allowlist when that
  variable is set. If it is set on Railway, add `https://savarun-admin.web.app`
  and `http://localhost:5700`.
- **Granting admin:** use an existing admin's "Make admin" button (Users page),
  or set the custom claim with the Admin SDK. The new admin must sign out and
  back in.

## Hosting on the Railway backend (current setup)

The admin website is also served by the backend at
`https://sawarun-app-production.up.railway.app/admin/`, so it needs no Firebase Hosting deploy.
After changing anything in `lib/admin_web/`, rebuild and copy it into the backend, then commit and push:

```
cd app
flutter build web -t lib/main_admin.dart --release --base-href /admin/ --output build/admin_rail --dart-define=BACKEND_URL=https://sawarun-app-production.up.railway.app
rm -rf ../backend/public/admin && cp -r build/admin_rail ../backend/public/admin && rm -rf ../backend/public/admin/canvaskit
```

- In Git Bash, put `MSYS_NO_PATHCONV=1` before `flutter build` so `/admin/` isn't rewritten into a Windows path.
- `canvaskit/` is removed because Flutter loads CanvasKit from the gstatic CDN. Keeping it adds about 37 MB.
- `backend/src/app.js` drops the CSP header for `/admin` only, because Flutter web and Firebase Auth need it.
