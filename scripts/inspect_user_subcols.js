const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function inspectUserSubcollections() {
  const userId = '79jBx4hgV2bwq32AxtxLtwczlTB2';
  const docRef = db.collection('users').doc(userId);
  const subcols = await docRef.listCollections();
  for (const c of subcols) {
    const snap = await c.limit(5).get();
    console.log(`Subcollection: ${c.id}`);
    snap.docs.forEach(d => console.log(`  Doc: ${d.id} -> ${JSON.stringify(d.data())}`));
  }
  process.exit(0);
}
inspectUserSubcollections();
