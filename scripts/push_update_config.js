const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));

if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}

const db = admin.firestore();

async function pushUpdate(buildNumber, versionName, force = true) {
  const config = {
    latest_build_number: buildNumber,
    min_build_number: force ? buildNumber : (buildNumber - 1),
    latest_version_name: versionName,
    store_url: "https://play.google.com/store/apps/details?id=com.royalpixels.app",
    release_notes: "• Improved View Counts & Like system\n• Fixed 'Disappearing Wallpapers' bug\n• Added Weather-based features\n• Performance optimizations"
  };

  await db.collection('app_config').doc('update').set(config);
  console.log('✅ Update configuration pushed to Firestore:');
  console.log(JSON.stringify(config, null, 2));
  process.exit(0);
}

// Defaulting to 18 for the latest stable build with fixes
const targetBuild = 19; 
const targetVersion = "1.2.9";

pushUpdate(targetBuild, targetVersion, true).catch(err => {
  console.error('❌ Error pushing update:', err);
  process.exit(1);
});
