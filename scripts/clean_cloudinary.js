const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const path = require('path');

// 1. Initialize Firebase
const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

// 2. Cloudinary Credentials (as provided by user)
const CLOUDS = [
  {
    name: 'Free',
    cloud_name: 'dl00rha3n',
    api_key: '837238164488567',
    api_secret: 'bdHDsHE2QyXzqt5UNLJMzxrrpu8'
  },
  {
    name: 'Premium',
    cloud_name: 'dmt6y2k6h',
    api_key: '174456259398661',
    api_secret: 'OxI0nRoL8RNK7xRJYVQJtX6cEhs'
  }
];

/**
 * Normalizes a Cloudinary URL by removing the version segment (v123456789/)
 * to allow accurate comparison even if the version changes.
 */
function normalizeUrl(url) {
  if (!url) return '';
  // Match the v + digits + / pattern and remove it
  return url.replace(/\/v\d+\//, '/');
}

async function runSync() {
  console.log('--- STARTING WALLPAPER SYNC & CLEANUP ---');
  
  // 3. Fetch all active URLs from Firestore
  console.log('Step 1: Fetching active wallpapers from Firestore...');
  const snap = await db.collection('wallpapers').get();
  const activeUrls = new Set();
  snap.docs.forEach(doc => {
    const url = doc.data().image_url;
    if (url) {
      activeUrls.add(normalizeUrl(url));
    }
  });
  console.log(`Found ${activeUrls.size} unique active wallpaper URLs in Firestore.`);

  let totalDeleted = 0;

  // 4. Process each Cloudinary account
  for (const cloud of CLOUDS) {
    console.log(`\nProcessing Account: ${cloud.name} (${cloud.cloud_name})`);
    
    cloudinary.config({
      cloud_name: cloud.cloud_name,
      api_key: cloud.api_key,
      api_secret: cloud.api_secret,
      secure: true
    });

    let resources = [];
    let next_cursor = null;

    console.log('Listing all assets in Cloudinary (this may take a moment)...');
    try {
      do {
        const result = await cloudinary.api.resources({
          type: 'upload',
          prefix: '',
          max_results: 500,
          next_cursor: next_cursor
        });
        resources = resources.concat(result.resources);
        next_cursor = result.next_cursor;
      } while (next_cursor);

      console.log(`Found ${resources.length} total files in ${cloud.name} account.`);

      // Identify orphans
      const orphans = resources.filter(res => {
        const normalizedResUrl = normalizeUrl(res.secure_url);
        return !activeUrls.has(normalizedResUrl);
      });

      console.log(`Identified ${orphans.length} orphaned files (not in app).`);

      if (orphans.length > 0) {
        console.log(`DELETING ${orphans.length} orphaned files...`);
        
        const publicIds = orphans.map(o => o.public_id);
        
        // Chunk deletions into groups of 100 as per Cloudinary limits
        for (let i = 0; i < publicIds.length; i += 100) {
          const chunk = publicIds.slice(i, i + 100);
          const deleteResult = await cloudinary.api.delete_resources(chunk);
          console.log(`  - Deleted batch ${Math.floor(i/100) + 1} (${chunk.length} items)`);
        }
        
        totalDeleted += orphans.length;
        console.log(`Cleanup of ${cloud.name} account finished.`);
      } else {
        console.log(`No action needed for ${cloud.name} account.`);
      }

    } catch (err) {
      console.error(`Error processing ${cloud.name}:`, err.message);
    }
  }

  console.log('\n--- SYNC COMPLETED ---');
  console.log(`Total files deleted from Cloudinary: ${totalDeleted}`);
  process.exit(0);
}

runSync().catch(e => {
  console.error('Fatal Error:', e);
  process.exit(1);
});
