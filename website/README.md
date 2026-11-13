# Savarun website

The marketing site for Savarun, built with React, Vite and react-router-dom. It has these pages: Home, Features, How it works, For Brands, FAQ, About and Contact.

## Develop and build

- `npm install`, then `npm run dev` starts a dev server at http://localhost:5174.
- `npm run build` builds into `../backend/public/web`. The backend serves that folder at the same URL as the API.
- Commit `backend/public/web` after every build. Railway does not build the website.

## How the backend serves it

The wiring is in `backend/src/app.js`.

- `WEBSITE_ROUTES` (`/`, `/features`, `/how-it-works`, `/for-brands`, `/faq`, `/about`, `/contact`) return `public/web/index.html` with `Cache-Control: no-cache`.
- `/web-assets` holds the hashed JS and CSS bundles, cached for 1 year (immutable).
- `/site` holds the images, cached for 7 days.
- `/privacy-policy`, `/terms`, `/account-deletion` and `/child-safety` are separate static HTML pages in `backend/public/`, not part of this site. The footer links to them with plain `<a>` tags.

To add a page:

1. Add its route in `src/App.jsx`.
2. Add the same path to `WEBSITE_ROUTES` in `backend/src/app.js`.
3. Add it to `NAV` in `src/components/Layout.jsx` if it belongs in the menu.

## Rules from helmet's CSP

- Don't use inline `<script>` tags or inline event handlers. Inline `style` attributes are fine.
- Keep every image local, in `public/site/`. The CSP sets `img-src 'self' data:`, so external images are blocked.

## Going live on Google Play

`src/components/common.jsx` has two settings: `PLAY_URL` and `PLAY_LIVE`.

- While `PLAY_LIVE` is `false`, both store badges show "Coming soon" and can't be clicked. The header button says "Get early access", and the Contact page shows a "Want to know when Savarun launches?" box.
- When the app is published, set `PLAY_LIVE = true`, run `npm run build`, and commit. The Google Play badge, the header button and the footer then link to `PLAY_URL`.
- The App Store badge stays "Coming soon" until the iOS app is out. It is hard-coded in `StoreButtons`.

## Where things are

- Pages: `src/pages/`
- Header, footer and reveal-on-scroll: `src/components/Layout.jsx`
- Shared constants (`PLAY_URL`, `PLAY_LIVE`, `EMAIL`, the Fit Score factors) and shared components: `src/components/common.jsx`
- Device frames around real app screenshots, plus the Fit Score ring and bars: `src/components/Mockups.jsx`
- Section visuals (wardrobe, community, shop, inspiration grid): `src/components/Visuals.jsx`
- Icons (SVG sprite): `src/components/icons.svg.html`
- Styles: `src/styles.css`. The colours come from `app/lib/core/theme/app_colors.dart`.
- Images: `public/site/`.
  - `screen_*.webp` are real app screenshots from `docs/store-assets/screens/`, resized to 600px wide.
  - `photo_*`, `street_*` and `garment_*` are Pexels stock photos (free licence, no attribution needed).
  - The logo comes from `app/lib/assest/`.

When the app UI changes, replace the `screen_*.webp` files with new screenshots: about 600px wide WebP, aspect 1080x2180.
