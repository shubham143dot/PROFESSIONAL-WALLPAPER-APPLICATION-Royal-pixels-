const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function inspect() {
  const snap = await db.collection('wallpapers').get();
  console.log(`Total wallpapers: ${snap.size}`);
  const withViewCount = snap.docs.filter(d => d.data().view_count !== undefined);
  const withViews = snap.docs.filter(d => d.data().views !== undefined);
  console.log(`Wallpapers with 'view_count': ${withViewCount.length}`);
  console.log(`Wallpapers with 'views': ${withViews.length}`);
  
  if (withViewCount.length > 0) {
    console.log('Sample view_count:', withViewCount[0].data().view_count);
  }
  if (withViews.length > 0) {
    console.log('Sample views:', withViews[0].data().views);
  }
  process.exit(0);
}
inspect();
