const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function listCollections() {
  const collections = await db.listCollections();
  collections.forEach(c => console.log(`Collection: ${c.id}`));
  process.exit(0);
}
listCollections();
