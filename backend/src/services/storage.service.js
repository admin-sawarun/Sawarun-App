import { randomUUID } from 'node:crypto';
import { readFile, unlink, readdir } from 'node:fs/promises';
import { basename, resolve, join } from 'node:path';

import { admin } from '../config/firebase.js';
import { env } from '../config/env.js';

/**
 * Where uploaded images live. Two drivers:
 *   - "local"    → served from this server's /uploads (dev / no-Blaze).
 *   - "firebase" → Firebase Storage (permanent, survives redeploys).
 *
 * Controllers call storeUpload(file) after multer has written the temp file to
 * disk; it returns the public URL to save in Firestore.
 */
const DRIVER = env.storage.driver;

let _bucket;
function bucket() {
  if (!_bucket) {
    const name = env.firebase.storageBucket;
    if (!name) {
      throw new Error(
        'STORAGE_DRIVER=firebase but FIREBASE_STORAGE_BUCKET is not set. ' +
          'Copy the bucket name from Firebase Console → Storage (e.g. ' +
          'savarun-app-b775b.firebasestorage.app).'
      );
    }
    _bucket = admin.storage().bucket(name);
  }
  return _bucket;
}

/**
 * Persist a multer temp file and return its public URL.
 * @param {{path:string, filename:string, mimetype?:string}} file
 * @param {string} [folder]  logical folder in the bucket, e.g. "outfits".
 */
export async function storeUpload(file, folder = 'uploads') {
  if (DRIVER === 'firebase') {
    return uploadToFirebase(file, folder);
  }
  // local: the file already sits in /uploads, served statically.
  const origin = env.publicUrl || '';
  return `${origin}/uploads/${file.filename}`;
}

async function uploadToFirebase(file, folder) {
  const data = await readFile(file.path);
  const objectPath = `${folder}/${file.filename}`;
  const token = randomUUID();

  await bucket().file(objectPath).save(data, {
    resumable: false,
    contentType: file.mimetype || 'image/jpeg',
    metadata: {
      // A download token makes the object readable via a stable URL without
      // making the whole bucket public.
      metadata: { firebaseStorageDownloadTokens: token },
    },
  });

  // Remove the local temp copy now that it's in the cloud.
  await unlink(file.path).catch(() => {});

  const encoded = encodeURIComponent(objectPath);
  return (
    `https://firebasestorage.googleapis.com/v0/b/${bucket().name}` +
    `/o/${encoded}?alt=media&token=${token}`
  );
}

/** For local driver the URL may be relative if PUBLIC_URL is unset; the
 *  controllers fall back to the request host in that case. */
export function isAbsolute(url) {
  return /^https?:\/\//i.test(url);
}

const LOCAL_UPLOAD_DIR = resolve(process.cwd(), 'uploads');

/** Per-user folder so every new upload lives under users/{uid}/…, which lets
 *  account deletion wipe a user's files by prefix. */
export function userFolder(uid, sub) {
  return `users/${uid}/${sub}`;
}

/**
 * Extract the bucket object path from a Firebase Storage download URL
 * (https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded path>?alt=media…).
 * Returns null for anything that isn't such a URL.
 */
export function storagePathFromUrl(url) {
  if (typeof url !== 'string') return null;
  const m = url.match(/^https:\/\/firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/([^?#]+)/i);
  if (!m) return null;
  try {
    return decodeURIComponent(m[1]);
  } catch {
    return null;
  }
}

/**
 * Best-effort delete of the file behind a stored URL (Firebase Storage or a
 * local /uploads file). Missing files and errors are logged, never thrown.
 */
export async function deleteByUrl(url) {
  if (typeof url !== 'string' || !url) return;
  try {
    const objectPath = storagePathFromUrl(url);
    if (objectPath) {
      await bucket().file(objectPath).delete({ ignoreNotFound: true });
      return;
    }
    const local = url.match(/\/uploads\/([^/?#]+)$/);
    if (local) {
      await unlink(join(LOCAL_UPLOAD_DIR, basename(local[1]))).catch(() => {});
    }
  } catch (err) {
    console.warn('[storage] deleteByUrl failed:', err.code || '', err.message);
  }
}

/**
 * Remove everything a user owns in storage: the users/{uid}/ prefix in the
 * bucket, plus (local driver) files in /uploads named "<uid>-…".
 */
export async function deleteUserFiles(uid) {
  if (!uid) return;
  if (env.firebase.storageBucket) {
    try {
      await bucket().deleteFiles({ prefix: `users/${uid}/`, force: true });
    } catch (err) {
      console.warn('[storage] deleteFiles(prefix) failed:', err.code || '', err.message);
    }
  }
  try {
    const names = await readdir(LOCAL_UPLOAD_DIR);
    await Promise.all(
      names
        .filter((n) => n.startsWith(`${uid}-`))
        .map((n) => unlink(join(LOCAL_UPLOAD_DIR, n)).catch(() => {}))
    );
  } catch {
    /* no local uploads dir — nothing to do */
  }
}

export { basename };
