const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function inspectHighViewDoc() {
  const docId = 'KJax58W1juiUMamtSGEA';
  const doc = await db.collection('wallpapers').doc(docId).get();
  console.log(`Document ${docId}:`);
  console.log(JSON.stringify(doc.data(), null, 2));
  
  const subcols = await doc.ref.listCollections();
  subcols.forEach(c => console.log(`  Subcollection: ${c.id}`));
  process.exit(0);
}
inspectHighViewDoc();
