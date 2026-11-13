// Give (or remove) the Savarun admin role for one account.
// The admin website and /api/admin/* only work for accounts with the
// `admin` custom claim. Admins sign in to the admin website with email +
// password, so create the admin with an email.
//
// Usage, from the backend folder (uses the same Firebase credentials as the server):
//   node scripts/set-admin.js admin@savarun.in --create "Str0ng-Passw0rd"   # create + make admin
//   node scripts/set-admin.js admin@savarun.in                              # make an existing account admin
//   node scripts/set-admin.js admin@savarun.in --password "N3w-Passw0rd"    # change its password
//   node scripts/set-admin.js admin@savarun.in --remove                     # take the role away
//   node scripts/set-admin.js +919876543210                                 # phone accounts work too
//
// After a change, sign out and sign in again on the admin website.
import { firebaseAuth } from '../src/config/firebase.js';

const [who, flag, value] = process.argv.slice(2);
if (!who) {
  console.error('Usage: node scripts/set-admin.js <email | +91phone> [--create <password> | --password <password> | --remove]');
  process.exit(1);
}

const isEmail = who.includes('@');
const needsPassword = flag === '--create' || flag === '--password';
if (needsPassword && (!value || value.length < 8)) {
  console.error('Give a password of at least 8 characters after ' + flag + '.');
  process.exit(1);
}

async function findUser() {
  try {
    return isEmail
      ? await firebaseAuth.getUserByEmail(who)
      : await firebaseAuth.getUserByPhoneNumber(who);
  } catch (e) {
    if (e.code === 'auth/user-not-found') return null;
    throw e;
  }
}

let user = await findUser();

if (!user) {
  if (flag !== '--create' || !isEmail) {
    console.error(`No account found for ${who}. To create an admin: node scripts/set-admin.js <email> --create "<password>"`);
    process.exit(1);
  }
  user = await firebaseAuth.createUser({ email: who, password: value, emailVerified: true, displayName: 'Savarun Admin' });
  console.log(`Created account ${who}.`);
} else if (needsPassword) {
  await firebaseAuth.updateUser(user.uid, { password: value });
  console.log(`Password updated for ${who}.`);
}

const makeAdmin = flag !== '--remove';
const claims = { ...(user.customClaims || {}) };
if (makeAdmin) claims.admin = true;
else delete claims.admin;
await firebaseAuth.setCustomUserClaims(user.uid, claims);
if (!makeAdmin) await firebaseAuth.revokeRefreshTokens(user.uid);

console.log(`${makeAdmin ? 'Admin role given to' : 'Admin role removed from'} ${who} (uid ${user.uid}).`);
console.log('Sign out and sign in again on the admin website to see the change.');
process.exit(0);
