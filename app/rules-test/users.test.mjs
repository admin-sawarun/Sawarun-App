/**
 * Firestore rules tests for profiles, private contact, blocks, follows,
 * outfit history and reports. Run with `npm test` (see README).
 */
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  addDoc,
  collection,
  serverTimestamp,
} from 'firebase/firestore';

const ALICE = 'alice';
const BOB = 'bob';

const testEnv = await initializeTestEnvironment({
  projectId: 'savarun-rules-test-users',
  firestore: {
    rules: readFileSync('firestore.rules', 'utf8'),
    host: '127.0.0.1',
    port: 8080,
  },
});

const results = [];
async function check(name, fn) {
  try {
    await fn();
    results.push(['PASS', name]);
  } catch (err) {
    results.push(['FAIL', `${name} — ${err.message.split('\n')[0]}`]);
  }
}

const as = (uid) => testEnv.authenticatedContext(uid).firestore();
const userRef = (db, uid) => doc(db, 'users', uid);

// ── Profile create (AuthService._ensureUserDoc) ──
const firstLoginDoc = (uid) => ({
  uid,
  name: 'Alice',
  photoURL: null,
  bio: '',
  style: null,
  wardrobePublic: true,
  followers: 0,
  following: 0,
  createdAt: serverTimestamp(),
});

await check('owner can create their profile doc', async () => {
  await assertSucceeds(setDoc(userRef(as(ALICE), ALICE), firstLoginDoc(ALICE)));
});
await check('profile create cannot carry email/phone', async () => {
  await assertFails(
    setDoc(userRef(as(BOB), BOB), { ...firstLoginDoc(BOB), email: 'b@x.com' })
  );
});
await check('profile create cannot self-verify', async () => {
  await assertFails(
    setDoc(userRef(as(BOB), BOB), { ...firstLoginDoc(BOB), status: 'verified' })
  );
});
await check('profile create cannot seed follower counts', async () => {
  await assertFails(
    setDoc(userRef(as(BOB), BOB), { ...firstLoginDoc(BOB), followers: 999 })
  );
});
await check('cannot create someone else\'s profile', async () => {
  await assertFails(setDoc(userRef(as(ALICE), BOB), firstLoginDoc(BOB)));
});
await check('bob creates his profile', async () => {
  await assertSucceeds(setDoc(userRef(as(BOB), BOB), firstLoginDoc(BOB)));
});

// ── Profile update (ProfileRepository) ──
await check('owner can edit name/bio/username/style (merge set)', async () => {
  await assertSucceeds(
    setDoc(userRef(as(ALICE), ALICE),
      { name: 'Al', bio: 'hi', username: 'al', style: 'Casual' }, { merge: true })
  );
});
await check('owner can set photoURL and wardrobePublic', async () => {
  await assertSucceeds(updateDoc(userRef(as(ALICE), ALICE), { photoURL: 'https://x/y.jpg' }));
  await assertSucceeds(updateDoc(userRef(as(ALICE), ALICE), { wardrobePublic: false }));
});
for (const [field, value] of [
  ['status', 'verified'],
  ['verified', true],
  ['banned', false],
  ['role', 'admin'],
  ['isAdmin', true],
  ['followers', 1000],
  ['following', 5],
  ['lastActiveAt', 1],
  ['email', 'a@x.com'],
]) {
  await check(`owner cannot write server-only field ${field}`, async () => {
    await assertFails(updateDoc(userRef(as(ALICE), ALICE), { [field]: value }));
  });
}
await check('others cannot edit a profile', async () => {
  await assertFails(updateDoc(userRef(as(BOB), ALICE), { bio: 'pwned' }));
});
await check('signed-in users can read profiles', async () => {
  await assertSucceeds(getDoc(userRef(as(BOB), ALICE)));
});

// ── Private contact ──
const contact = (db, uid) => doc(db, 'users', uid, 'private', 'contact');
await check('owner can write and read their contact doc', async () => {
  await assertSucceeds(
    setDoc(contact(as(ALICE), ALICE),
      { email: 'a@x.com', phone: null, updatedAt: serverTimestamp() }, { merge: true })
  );
  await assertSucceeds(getDoc(contact(as(ALICE), ALICE)));
});
await check('others cannot read the contact doc', async () => {
  await assertFails(getDoc(contact(as(BOB), ALICE)));
});
await check('contact doc rejects extra fields / other ids', async () => {
  await assertFails(setDoc(contact(as(ALICE), ALICE), { email: 'a', role: 'admin' }));
  await assertFails(setDoc(doc(as(ALICE), 'users', ALICE, 'private', 'other'), { email: 'a' }));
});

// ── Blocks ──
const block = (db, uid, other) => doc(db, 'users', uid, 'blocked', other);
await check('owner can block, read and unblock', async () => {
  await assertSucceeds(setDoc(block(as(ALICE), ALICE, BOB), { createdAt: serverTimestamp() }));
  await assertSucceeds(getDoc(block(as(ALICE), ALICE, BOB)));
  await assertSucceeds(deleteDoc(block(as(ALICE), ALICE, BOB)));
});
await check('block doc may contain only createdAt', async () => {
  await assertFails(setDoc(block(as(ALICE), ALICE, BOB), { createdAt: serverTimestamp(), note: 'x' }));
});
await check('others cannot read or write my blocks', async () => {
  await assertFails(getDoc(block(as(BOB), ALICE, BOB)));
  await assertFails(setDoc(block(as(BOB), ALICE, BOB), { createdAt: serverTimestamp() }));
});

// ── Follows (FollowRepository) ──
const edge = (db, a, b) => doc(db, 'follows', `${a}_${b}`);
const edgeBody = (a, b) => ({ followerUid: a, followingUid: b, createdAt: serverTimestamp() });
await check('alice can follow bob', async () => {
  await assertSucceeds(setDoc(edge(as(ALICE), ALICE, BOB), edgeBody(ALICE, BOB)));
});
await check('cannot follow yourself', async () => {
  await assertFails(setDoc(edge(as(ALICE), ALICE, ALICE), edgeBody(ALICE, ALICE)));
});
await check('cannot follow on behalf of someone else', async () => {
  await assertFails(setDoc(edge(as(ALICE), BOB, ALICE), edgeBody(BOB, ALICE)));
});
await check('follow doc id must be follower_following', async () => {
  await assertFails(setDoc(doc(as(BOB), 'follows', 'random'), edgeBody(BOB, ALICE)));
  await assertFails(addDoc(collection(as(BOB), 'follows'), edgeBody(BOB, ALICE)));
});
await check('follow doc rejects extra fields', async () => {
  await assertFails(setDoc(edge(as(BOB), BOB, ALICE), { ...edgeBody(BOB, ALICE), x: 1 }));
});
await check('only the follower can unfollow', async () => {
  await assertFails(deleteDoc(edge(as(BOB), ALICE, BOB)));
  await assertSucceeds(deleteDoc(edge(as(ALICE), ALICE, BOB)));
});

// ── Outfit history (backend-written) ──
await check('client cannot write outfit history', async () => {
  await assertFails(
    addDoc(collection(as(ALICE), 'users', ALICE, 'outfitHistory'), { fitScore: 100 })
  );
});
await check('owner can read their outfit history', async () => {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', ALICE, 'outfitHistory', 'h1'), { fitScore: 70 });
  });
  await assertSucceeds(getDoc(doc(as(ALICE), 'users', ALICE, 'outfitHistory', 'h1')));
});
await check('client cannot update or delete outfit history', async () => {
  await assertFails(updateDoc(doc(as(ALICE), 'users', ALICE, 'outfitHistory', 'h1'), { fitScore: 100 }));
  await assertFails(deleteDoc(doc(as(ALICE), 'users', ALICE, 'outfitHistory', 'h1')));
});

// ── Reports (backend-only) ──
await check('client cannot write or read reports', async () => {
  await assertFails(addDoc(collection(as(ALICE), 'reports'), { target: BOB }));
  await assertFails(getDoc(doc(as(ALICE), 'reports', 'r1')));
});

// ── Posts ──
await check('posts cannot be created with inflated likes', async () => {
  await assertFails(addDoc(collection(as(ALICE), 'posts'), { authorUid: ALICE, likes: 50 }));
  await assertSucceeds(addDoc(collection(as(ALICE), 'posts'), { authorUid: ALICE, likes: 0 }));
});

await testEnv.cleanup();

for (const [status, name] of results) {
  console.log(`${status === 'PASS' ? '  ok  ' : ' FAIL '} ${name}`);
}
const failed = results.filter(([s]) => s === 'FAIL').length;
console.log(`\n${results.length - failed}/${results.length} passed`);
process.exit(failed ? 1 : 0);
