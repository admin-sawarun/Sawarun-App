# Firestore Data Model

Collections the backend reads/writes. The Flutter app shares this same database
(Firebase-direct for most CRUD); the server only touches what's listed here.

## `users/{uid}`
```
{
  username, bio, photoUrl,
  stylePreferences: ["Streetwear", ...],
  wardrobePublic: bool,
  status: "active" | "banned" | "suspended" | "verified",   // set by admin
  lastActiveAt: timestamp,        // Daily Active Users; set by requireAuth (server timestamp, ≤ once/hour/uid)
  followersCount, followingCount
}
```

### `users/{uid}/wardrobe/{itemId}`
```
{
  category, colorName, colorHex,
  fabric, season, formality,      // AI auto-tagged (Module 2)
  imageUrl, wearCount: number, createdAt
}
```

### `users/{uid}/outfitHistory/{analysisId}`  ← written by `POST /api/analysis`
```
{
  fitScore, breakdown: [{factor, score, weight, contribution}],
  styleDna: [{category, percentage}],
  detection: { clothingTypes, colorPalette, pattern, fabric, fitType, accessories },
  feedback: { summary, suggestions: [{type, text}] },
  imageUrl, createdAt
}
```

## `brands/{brandId}`
```
{
  name, logoUrl, ownerUid,
  status: "pending" | "approved" | "rejected",   // set by admin
  reviewNote, reviewedBy, reviewedAt
}
```

## `products/{productId}`
```
{
  brandId, brandName, name, price, description,
  imageUrl, websiteUrl,
  category, categoryLower,        // categoryLower used for filtering
  approved: bool, hidden: bool,
  clicks: number, createdAt
}
```

## `affiliateClicks/{autoId}`  ← written by `POST /api/affiliate/click`
```
{ productId, brandId, userId, at }
```

## `reports/{autoId}`  ← written by `POST /api/reports`, resolved by admin
```
{
  reporterUid,                    // null after the reporter deletes their account (reporterDeleted: true)
  targetType: "user" | "post" | "message",
  targetId,                       // uid | postId | "<chatId>/<messageId>"
  targetUid,                      // the reported user
  reason: "spam" | "harassment" | "nudity" | "hate" | "violence" | "fake" | "other",
  details, status: "open" | "resolved", createdAt,
  action: "dismiss" | "remove_content" | "ban_user", resolvedBy, resolvedAt
}
```

## Social collections (written by the app; deleted by `DELETE /api/users/me`)
```
posts/{postId}           → { authorUid, authorName, authorPhoto, imageUrl, likes, ... }
postLikes/{postId}_{uid} → { postId, uid, at }
follows/{follower}_{followee} → { followerUid, followingUid, createdAt }
chats/{chatId}           → { participants: [uid, uid], status, ... }
chats/{chatId}/messages/{id} → { senderId, text, imageUrl?, createdAt }
```

## Storage layout
New uploads go under per-user folders so account deletion can wipe them by prefix:
```
users/{uid}/uploads/<file>    ← POST /api/uploads, /api/uploads/bulk
users/{uid}/outfits/<file>    ← POST /api/analysis
```
(Older files in `uploads/` / `outfits/` are deleted individually via the URLs stored in Firestore.)

## `config/...`
```
config/fitScoreWeights → { trendMatch, colorHarmony, styleConsistency, silhouetteBalance, accessories }
config/home            → { featuredBrandId }
```

> **Note:** This server uses the Firebase Admin SDK, which bypasses security rules.
> The same collections still need proper **Firestore Security Rules** for the
> Flutter app's direct access (e.g. a user can only write their own wardrobe).
