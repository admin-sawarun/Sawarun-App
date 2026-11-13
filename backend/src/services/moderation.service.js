import { db } from '../config/firebase.js';
import { deleteByUrl } from './storage.service.js';

/**
 * Delete a post, its likes (postLikes where postId == id), any subcollections
 * and its Storage image. Returns false if the post didn't exist.
 * Shared by report resolution and the admin posts moderation endpoint.
 */
export async function removePost(postId) {
  const postRef = db.collection('posts').doc(postId);
  const post = await postRef.get();
  if (!post.exists) return false;
  const data = post.data();
  const likes = await db.collection('postLikes').where('postId', '==', postId).get();
  const writer = db.bulkWriter();
  likes.docs.forEach((d) => writer.delete(d.ref));
  await writer.close();
  await db.recursiveDelete(postRef);
  await deleteByUrl(data.imageUrl);
  return true;
}
