const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(sa)
  });
}

const db = admin.firestore();

async function backupWallpapers() {
  console.log('--- Wallpaper Backup Started ---');
  try {
    const snapshot = await db.collection('wallpapers').get();
    const wallpapers = [];

    snapshot.forEach(doc => {
      wallpapers.push({
        id: doc.id,
        ...doc.data()
      });
    });

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const filename = `wallpapers_backup_${timestamp}.json`;
    const filepath = path.join(__dirname, filename);

    fs.writeFileSync(filepath, JSON.stringify(wallpapers, null, 2));

    console.log(`✅ Successfully backed up ${wallpapers.length} wallpapers.`);
    console.log(`📁 Backup file: ${filepath}`);

    // Also update a 'latest' backup for easy reference
    const latestPath = path.join(__dirname, 'wallpapers_latest_backup.json');
    fs.writeFileSync(latestPath, JSON.stringify(wallpapers, null, 2));
    console.log(`✅ Updated latest backup at ${latestPath}`);

  } catch (error) {
    console.error('❌ Error during backup:', error);
  } finally {
    process.exit(0);
  }
}

backupWallpapers();
