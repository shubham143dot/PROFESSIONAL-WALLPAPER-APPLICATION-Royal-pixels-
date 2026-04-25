const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function removeAllWallpapers() {
  const force = process.argv.includes('--force');
  if (!force) {
    console.log('⚠️  CRITICAL: This script will delete ALL wallpapers in the database.');
    console.log('Use --force as a command line argument to proceed.');
    process.exit(1);
  }
  try {
    const snap = await db.collection('wallpapers').get();
    let toDelete = [];
    
    snap.docs.forEach(d => {
      toDelete.push({
        id: d.id,
        data: d.data()
      });
    });

    if (toDelete.length === 0) {
      console.log('No wallpapers found in the database. It is already empty.');
      process.exit(0);
      return;
    }

    // Backup
    const backupPath = path.join(__dirname, 'all_wallpapers_backup.json');
    fs.writeFileSync(backupPath, JSON.stringify(toDelete, null, 2), 'utf-8');
    console.log(`✅ Backed up ${toDelete.length} wallpapers to ${backupPath}.`);

    // Delete in batches
    console.log(`\nDeleting ${toDelete.length} wallpapers from Firestore...`);
    let batch = db.batch();
    let count = 0;

    for (const item of toDelete) {
        const docRef = db.collection('wallpapers').doc(item.id);
        batch.delete(docRef);
        count++;

        // Commit every 500 records just in case
        if (count % 500 === 0) {
            await batch.commit();
            console.log(`Deleted ${count} wallpapers...`);
            batch = db.batch();
        }
    }
    
    // Commit the remaining
    if (count % 500 !== 0) {
        await batch.commit();
    }

    console.log('\n✅ Successfully deleted ALL wallpapers from the database.');

  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    process.exit(0);
  }
}

removeAllWallpapers();
