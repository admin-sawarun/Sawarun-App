import { db, admin, firebaseAuth } from '../config/firebase.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { deleteByUrl, deleteUserFiles, storagePathFromUrl } from '../services/storage.service.js';
import { forgetActivity } from '../middleware/auth.js';

/** Collect every stored-file URL (Firebase Storage or /uploads) inside a doc. */
function collectFileUrls(value, out) {
  if (typeof value === 'string') {
    if (storagePathFromUrl(value) || /\/uploads\/[^/?#]+$/.test(value)) out.add(value);
  } else if (Array.isArray(value)) {
    value.forEach((v) => collectFileUrls(v, out));
  } else if (value && typeof value === 'object' && !(value instanceof admin.firestore.Timestamp)) {
    Object.values(value).forEach((v) => collectFileUrls(v, out));
  }
}

/** Gather file URLs from a document and all of its nested subcollections. */
async function collectTreeUrls(docRef, out) {
  const snap = await docRef.get();
  if (snap.exists) collectFileUrls(snap.data(), out);
  const subs = await docRef.listCollections();
  for (const col of subs) {
    const docs = await col.get();
    for (const d of docs.docs) await collectTreeUrls(d.ref, out);
  }
}

async function deleteDocs(refs) {
  if (!refs.length) return;
  const writer = db.bulkWriter();
  writer.onWriteError((err) => {
    console.warn('[delete-account] write failed:', err.documentRef.path, err.message);
    return false;
  });
  refs.forEach((r) => writer.delete(r));
  await writer.close();
}

/**
 * DELETE /api/users/me — permanently delete the caller's account and data.
 * Idempotent: each step is best-effort (logged, never aborts the rest), so a
 * retry after a partial failure finishes the job.
 */
export const deleteMe = asyncHandler(async (req, res) => {
  const uid = req.user.uid;
  const urls = new Set();
  const failures = [];

  const step = async (name, fn) => {
    try {
      await fn();
    } catch (err) {
      failures.push(name);
      console.error(`[delete-account] ${uid} step "${name}" failed:`, err.code || '', err.message);
    }
  };

  // 1. Posts authored by the user (+ their likes and any subcollections).
  await step('posts', async () => {
    const posts = await db.collection('posts').where('authorUid', '==', uid).get();
    for (const p of posts.docs) {
      await collectTreeUrls(p.ref, urls);
      const likes = await db.collection('postLikes').where('postId', '==', p.id).get();
      await deleteDocs(likes.docs.map((d) => d.ref));
      await db.recursiveDelete(p.ref);
    }
  });

  // 2. Likes the user left on other people's posts (keep counts in sync).
  await step('postLikes', async () => {
    const likes = await db.collection('postLikes').where('uid', '==', uid).get();
    for (const l of likes.docs) {
      const postId = l.data().postId;
      if (postId) {
        await db
          .collection('posts')
          .doc(postId)
          .update({ likes: admin.firestore.FieldValue.increment(-1) })
          .catch(() => {});
      }
    }
    await deleteDocs(likes.docs.map((d) => d.ref));
  });

  // 3. Follow edges in both directions.
  await step('follows', async () => {
    const [out, inc] = await Promise.all([
      db.collection('follows').where('followerUid', '==', uid).get(),
      db.collection('follows').where('followingUid', '==', uid).get(),
    ]);
    await deleteDocs([...out.docs, ...inc.docs].map((d) => d.ref));
  });

  // 4. Chat threads the user takes part in (thread + messages + images).
  await step('chats', async () => {
    const chats = await db.collection('chats').where('participants', 'array-contains', uid).get();
    for (const c of chats.docs) {
      const msgs = await c.ref.collection('messages').get();
      msgs.docs.forEach((m) => collectFileUrls(m.data().imageUrl, urls));
      await db.recursiveDelete(c.ref);
    }
  });

  // 5. Brand applications owned by the user and their products.
  await step('brands', async () => {
    const brands = await db.collection('brands').where('ownerUid', '==', uid).get();
    for (const b of brands.docs) {
      collectFileUrls(b.data().logoUrl, urls);
      const products = await db.collection('products').where('brandId', '==', b.id).get();
      products.docs.forEach((p) => collectFileUrls(p.data().imageUrl, urls));
      await deleteDocs(products.docs.map((p) => p.ref));
      await db.recursiveDelete(b.ref);
    }
  });

  // 6. Reports filed by the user stay for moderation history, anonymised.
  await step('reports', async () => {
    const reports = await db.collection('reports').where('reporterUid', '==', uid).get();
    const writer = db.bulkWriter();
    reports.docs.forEach((r) => writer.update(r.ref, { reporterUid: null, reporterDeleted: true }));
    await writer.close();
  });

  // 6b. Admin analyses log entries (images are also referenced by outfitHistory).
  await step('analysesLog', async () => {
    const logs = await db.collection('analysesLog').where('uid', '==', uid).get();
    logs.docs.forEach((l) => collectFileUrls(l.data().imageUrl, urls));
    await deleteDocs(logs.docs.map((l) => l.ref));
  });

  // 7. Affiliate click log: keep the aggregate, drop the link to the user.
  await step('affiliateClicks', async () => {
    const clicks = await db.collection('affiliateClicks').where('userId', '==', uid).get();
    const writer = db.bulkWriter();
    clicks.docs.forEach((c) => writer.update(c.ref, { userId: null }));
    await writer.close();
  });

  // 8. The profile doc and every subcollection (wardrobe, outfitHistory, outfits…).
  await step('userDoc', async () => {
    const userRef = db.collection('users').doc(uid);
    await collectTreeUrls(userRef, urls);
    await db.recursiveDelete(userRef);
  });

  // 9. Storage: every referenced file, then the whole users/{uid}/ prefix.
  await step('storageFiles', async () => {
    await Promise.all([...urls].map((u) => deleteByUrl(u)));
    await deleteUserFiles(uid);
  });

  // 10. Finally the Firebase Auth account itself.
  let authDeleted = true;
  try {
    await firebaseAuth.deleteUser(uid);
  } catch (err) {
    if (err.code !== 'auth/user-not-found') {
      authDeleted = false;
      console.error(`[delete-account] ${uid} auth deleteUser failed:`, err.code || '', err.message);
    }
  }
  forgetActivity(uid);

  if (failures.length) {
    console.warn(`[delete-account] ${uid} finished with failed steps: ${failures.join(', ')}`);
  }
  // If the Auth account survived, the user could still sign in — tell the
  // client so it can retry (the whole flow is idempotent).
  if (!authDeleted) {
    throw new ApiError(500, 'Account deletion did not complete. Please try again.');
  }

  res.json({ ok: true });
});
