const admin = require('firebase-admin');
const cloudinary = require('cloudinary').v2;
const path = require('path');

const sa = require(path.join(__dirname, 'service_account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: admin.credential.cert(sa) });
}
const db = admin.firestore();

// Cloudinary Credentials (configured via environment or .env)
const CLOUDS = [
  {
    name: 'Free',
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME_FREE || 'dl00rha3n',
    api_key: process.env.CLOUDINARY_API_KEY_FREE || '837238164488567',
    api_secret: process.env.CLOUDINARY_API_SECRET_FREE || 'YOUR_FREE_API_SECRET'
  },
  {
    name: 'Premium',
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME_PREMIUM || 'dmt6y2k6h',
    api_key: process.env.CLOUDINARY_API_KEY_PREMIUM || '174456259398661',
    api_secret: process.env.CLOUDINARY_API_SECRET_PREMIUM || 'YOUR_PREMIUM_API_SECRET'
  }
];

function normalizeUrl(url) {
  if (!url) return '';
  return url.replace(/\/v\d+\//, '/').split('?')[0];
}

async function sync() {
  console.log('--- Syncing Missing Cloudinary Images to Firestore ---');

  // 1. Get existing Firestore URLs to avoid duplicates
  const snap = await db.collection('wallpapers').get();
  const firestoreUrls = new Set();
  snap.docs.forEach(doc => {
    const data = doc.data();
    if (data.image_url) {
      firestoreUrls.add(normalizeUrl(data.image_url));
    }
  });

  let addedCount = 0;

  for (const cloud of CLOUDS) {
    console.log(`\nChecking Cloudinary account: ${cloud.name}...`);
    
    cloudinary.config({
      cloud_name: cloud.cloud_name,
      api_key: cloud.api_key,
      api_secret: cloud.api_secret,
      secure: true
    });

    let next_cursor = null;
    try {
      do {
        const result = await cloudinary.api.resources({
          type: 'upload',
          max_results: 500,
          next_cursor: next_cursor
        });

        for (const r of result.resources) {
          const norm = normalizeUrl(r.secure_url);
          
          if (!firestoreUrls.has(norm)) {
            console.log(`  ➕ Found missing image: ${r.public_id} (${cloud.name})`);
            
            // Guess a title from public_id (remove extension, replace _ with space)
            let title = r.public_id.split('/').pop().replace(/\.[^/.]+$/, "").replace(/[_-]/g, " ");
            title = title.charAt(0).toUpperCase() + title.slice(1);
            if (title.length < 3) title = "New Wallpaper";

            const newWallpaper = {
              title: title,
              image_url: r.secure_url,
              category: 'Trending', // Default category
              is_premium: cloud.name === 'Premium',
              diamondCost: cloud.name === 'Premium' ? 100 : 0,
              tags: [title.toLowerCase(), cloud.name.toLowerCase()],
              createdAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            await db.collection('wallpapers').add(newWallpaper);
            firestoreUrls.add(norm); // Add to set to prevent double-adding in same run
            addedCount++;
            console.log(`     ✅ Added to Firestore as "${title}"`);
          }
        }
        next_cursor = result.next_cursor;
      } while (next_cursor);
    } catch (err) {
      console.error(`  ❌ Error processing ${cloud.name}:`, err.message);
    }
  }

  console.log(`\nDone! Added ${addedCount} missing wallpapers to Firestore.`);
  process.exit(0);
}

sync().catch(e => {
  console.error(e);
  process.exit(1);
});
