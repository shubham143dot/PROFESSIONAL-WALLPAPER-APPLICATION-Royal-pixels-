const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function checkUserHistory() {
  const usersSnap = await db.collection('users').get();
  for (const userDoc of usersSnap.docs) {
    const subcols = await userDoc.ref.listCollections();
    subcols.forEach(c => console.log(`User ${userDoc.id} has subcollection: ${c.id}`));
  }
  process.exit(0);
}
checkUserHistory();
