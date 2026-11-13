# Savarun: Play Console answers

These are ready-to-paste answers for every Play Console section the Savarun Android app (`com.savarun.savarun`) needs before the first release. They match what the code does as of 13 Nov 2026. If a feature changes, update the matching answer.

Operator: SAWARUN TECH PRIVATE LIMITED, India. Contact: admin-sawarun@savarun.in.
Backend and public pages: https://sawarun-app-production.up.railway.app

## 1. Main store listing

| Field | Value |
|---|---|
| App name (30 chars max) | `Savarun: AI Outfit Stylist` |
| Category | Lifestyle |
| Tags | Fashion, Style, Social |
| Contact email | admin-sawarun@savarun.in |
| Website | https://sawarun-app-production.up.railway.app |
| Privacy policy URL | https://sawarun-app-production.up.railway.app/privacy-policy |

**Short description (80 chars max):**
```
Rate your outfit with AI, build a digital wardrobe and share your style.
```

**Full description:**
```
Savarun is your AI fashion stylist. Snap a photo of your outfit and get an instant Fit Score, your Style DNA and clear advice on what to add, swap or keep.

AI OUTFIT ANALYZER
• Fit Score from 0 to 100, based on trend match, colour harmony, style consistency, silhouette and accessories
• Style DNA: see your look broken down into styles like Streetwear, Minimalist or Classic
• A stylist-style report with the current trend pulse and specific suggestions
• Outfit history to track how your style improves

DIGITAL WARDROBE
• Add clothes by photo, one at a time or in bulk
• AI tags each item with category, colour, fabric, season and formality
• Filter and search your closet, and save outfit combinations like "Office Monday Look"
• Wardrobe insights: colour breakdown and gaps in your closet

STYLE COMMUNITY
• Create a profile with your style preferences
• Share outfits, follow people and discover trending styles
• Chat 1-on-1 after a chat request is accepted
• Keep your wardrobe public or private

SHOP FROM BRANDS
• Browse products from approved fashion brands
• Tap a product to buy it on the brand's own website

Safe by design: report or block any user, post or message from inside the app. Our team reviews reports within 24 hours.

Savarun is for users aged 18 and over.
```

Graphics still to make: app icon 512×512, feature graphic 1024×500, and at least 2 phone screenshots (Home, Analysis result, Wardrobe, Shop, Profile).

## 2. App access (Policy → App content → App access)

Choose **"All or some functionality is restricted"** and add these instructions:
```
Login with Phone → enter 9876543210 (country code +91 is preselected) → Send OTP.
The test code 123456 fills in automatically. No real SMS is sent.
This is a Firebase test number, so it works on any device.
```

## 3. Ads
**No**, the app does not contain ads.

## 4. Content rating (IARC questionnaire)

- Category: **Social / Communication** (users interact and share content).
- Violence, sexuality, language, controlled substances, gambling: **No**.
- Users can interact or exchange content: **Yes** (chat, posts, comments/likes).
- Shares the user's location with other users: **No**.
- Allows purchase of digital goods: **No** (shop links open brand websites).
- Unrestricted internet browsing: **No**.

## 5. Target audience and content
- Target age groups: **18 and over** only.
- The app is not designed to appeal to children.

## 6. Data safety

Data is encrypted in transit (HTTPS). Users can request deletion: **Yes**. The in-app path is Settings → Delete Account; the web page is https://sawarun-app-production.up.railway.app/account-deletion.

| Data type | Collected | Shared | Optional? | Purpose |
|---|---|---|---|---|
| Name | Yes | No | Optional (profile) | App functionality, Account management |
| Email address | Yes (Google login) | No | Optional | Account management |
| Phone number | Yes (phone login) | No | Optional | Account management |
| User IDs | Yes | No | Required | App functionality, Account management |
| Photos | Yes | **Yes, with OpenAI for outfit analysis** (processor) | Required for analysis | App functionality |
| Other user-generated content (posts, bio, wardrobe tags) | Yes | No | Optional | App functionality |
| Messages (in-app chat) | Yes | No | Optional | App functionality |
| App interactions (product clicks, follows, likes) | Yes | No | Required | App functionality, Analytics |

Notes for the form:
- Service providers that process data on our behalf (Firebase, Railway, OpenAI) do **not** count as "sharing" under Play's definition. If you are unsure, marking Photos as shared with OpenAI is the safe choice.
- Location, contacts, financial info, health, audio, files and calendar: **Not collected**.
- Data is **not** sold and is **not** used for advertising.

## 7. Other declarations
- **Account deletion URL:** https://sawarun-app-production.up.railway.app/account-deletion
- **Child safety standards** (required for social apps): https://sawarun-app-production.up.railway.app/child-safety, contact admin-sawarun@savarun.in
- News app: No. COVID-19 app: No. Government app: No. Financial features: None. Health: No.

## 8. Release signing
- Upload key: `app/android/app/upload-keystore.jks`, password in `app/android/key.properties`. **Both are gitignored, so back them up somewhere safe.** If the upload key is lost, you must ask Google to reset it.
- Upload key SHA-1: `68:79:8B:B6:BC:F2:B7:09:50:9F:98:08:49:28:34:44:1C:23:BA:E4`
- Upload key SHA-256: `58:C4:BA:4D:9A:F4:79:22:6E:2A:40:09:1C:23:95:83:A1:5C:1C:A8:5C:75:56:A2:5C:AD:CE:84:82:B7:74:97`
- After the first upload, copy the **App signing key** SHA-1 and SHA-256 from Play Console → Test and release → App integrity. Add them and the upload key SHAs in Firebase → Project settings → Android app `com.savarun.savarun`. Without them, Google login and phone OTP fail in the Play version.
