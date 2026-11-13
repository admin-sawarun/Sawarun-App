// Give (or remove) the Savarun admin role for one account.
// The admin panel (Profile → Settings → Admin Dashboard) and /api/admin/*
// only work for accounts with the `admin` custom claim.
//
// Usage, from the backend folder (uses the same Firebase credentials as the server):
//   node scripts/set-admin.js +919876543210          # by phone number
//   node scripts/set-admin.js someone@gmail.com      # by email
//   node scripts/set-admin.js +919876543210 --remove # take the role away
//
// The person must log out and log in again for the change to show in the app.
import { firebaseAuth } from '../src/config/firebase.js';

const [who, flag] = process.argv.slice(2);
if (!who) {
  console.error('Usage: node scripts/set-admin.js <phone +91… | email> [--remove]');
  process.exit(1);
}

const user = who.includes('@')
  ? await firebaseAuth.getUserByEmail(who)
  : await firebaseAuth.getUserByPhoneNumber(who);

const makeAdmin = flag !== '--remove';
const claims = { ...(user.customClaims || {}), admin: makeAdmin };
if (!makeAdmin) delete claims.admin;
await firebaseAuth.setCustomUserClaims(user.uid, claims);

console.log(`${makeAdmin ? 'Admin role given to' : 'Admin role removed from'} ${who} (uid ${user.uid}).`);
console.log('Log out and log in again in the app to see the change.');
process.exit(0);
