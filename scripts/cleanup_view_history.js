const admin = require('firebase-admin');
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

async function cleanupViewHistory() {
  console.log('--- Starting View History Cleanup ---');

  const usersSnap = await db.collection('users').get();
  console.log(`Found ${usersSnap.size} users.`);

  let totalDeleted = 0;

  for (const userDoc of usersSnap.docs) {
    const userId = userDoc.id;
    const historySnap = await db.collection('users').doc(userId).collection('view_history').get();
    
    if (historySnap.empty) continue;

    const wallpaperViews = {}; // wallpaperId -> [docIds]
    
    historySnap.docs.forEach(doc => {
      const data = doc.data();
      const wpId = data.wallpaperId;
      if (!wpId) return;

      if (!wallpaperViews[wpId]) {
        wallpaperViews[wpId] = [];
      }
      wallpaperViews[wpId].push({
        id: doc.id,
        timestamp: data.timestamp ? data.timestamp.toDate() : new Date(0)
      });
    });

    const batch = db.batch();
    let batchCount = 0;

    for (const wpId in wallpaperViews) {
      const views = wallpaperViews[wpId];
      if (views.length > 1) {
        // Sort by timestamp descending (newest first)
        views.sort((a, b) => b.timestamp - a.timestamp);
        
        // Keep the first one, delete the rest
        for (let i = 1; i < views.length; i++) {
          batch.delete(db.collection('users').doc(userId).collection('view_history').doc(views[i].id));
          batchCount++;
          totalDeleted++;
        }
      }
    }

    if (batchCount > 0) {
      console.log(`Deleting ${batchCount} duplicates for user ${userId}...`);
      await batch.commit();
    }
  }

  console.log(`\nCleanup complete! Total duplicates deleted: ${totalDeleted}`);
  process.exit(0);
}

cleanupViewHistory().catch(e => {
  console.error(e);
  process.exit(1);
});
