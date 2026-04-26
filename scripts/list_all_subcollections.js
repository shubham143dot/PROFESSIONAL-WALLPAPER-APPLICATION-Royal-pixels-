const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function listAllSubcollections() {
  const snap = await db.collection('wallpapers').get();
  console.log(`Checking ${snap.size} wallpapers...`);
  for (const doc of snap.docs) {
    const subcols = await doc.ref.listCollections();
    if (subcols.length > 0) {
      console.log(`Document: ${doc.id}`);
      subcols.forEach(c => console.log(`  Subcollection: ${c.id}`));
    }
  }
  process.exit(0);
}
listAllSubcollections();
