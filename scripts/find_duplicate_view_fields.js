const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function findDuplicateViewFields() {
  const snap = await db.collection('wallpapers').get();
  let count = 0;
  snap.docs.forEach(doc => {
    const data = doc.data();
    if (data.viewCount !== undefined && data.view_count !== undefined) {
      console.log(`Document ${doc.id} has BOTH 'viewCount' and 'view_count'`);
      count++;
    }
  });
  console.log(`Total documents with both fields: ${count}`);
  process.exit(0);
}
findDuplicateViewFields();
