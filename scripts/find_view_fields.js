const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function findViewFields() {
  const snap = await db.collection('wallpapers').get();
  const fieldsFound = new Set();
  snap.docs.forEach(doc => {
    Object.keys(doc.data()).forEach(k => {
      if (k.toLowerCase().includes('view')) {
        fieldsFound.add(k);
      }
    });
  });
  console.log('Fields containing "view":', Array.from(fieldsFound));
  process.exit(0);
}
findViewFields();
