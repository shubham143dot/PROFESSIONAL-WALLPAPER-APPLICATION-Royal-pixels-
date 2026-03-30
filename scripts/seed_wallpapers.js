/**
 * Royal Pixels – Firestore Wallpaper Seeder
 *
 * Steps:
 *   1. Go to Firebase Console → Project Settings → Service Accounts
 *      → "Generate new private key" → save as scripts/service_account.json
 *   2. Install deps (one-time):
 *        cd scripts && npm install firebase-admin
 *   3. Run:
 *        node scripts/seed_wallpapers.js
 *
 * What it does:
 *   - Deletes ALL free wallpapers in `wallpapers` collection
 *   - Adds 4 free wallpapers: Time Stone, Thor, Porsche GT3, Uchiha Itachi Classic
 *   - Deletes ALL premium wallpapers in `wallpapers` collection
 *   - Adds 2 premium wallpapers: iPhone 15, iPhone 17 Pro Max
 */

const admin = require('firebase-admin');
const path  = require('path');

// ── Load service account ──────────────────────────────────────────────────────
const serviceAccount = require(path.join(__dirname, 'service_account.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── Free wallpapers to seed ───────────────────────────────────────────────────
const FREE_WALLPAPERS = [
  {
    title:      'Time Stone',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774675099/image4_a7imnz.jpg',
    category:   'Abstract',
    is_premium: false,
    price:      0.0,
    tags:       ['stone', 'time', 'abstract', 'scenic'],
  },
  {
    title:      'Thor',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774675098/image1_mwjrlw.jpg',
    category:   'Movies',
    is_premium: false,
    price:      0.0,
    tags:       ['thor', 'marvel', 'superhero', 'avengers'],
  },
  {
    title:      'Porsche GT3',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774675098/image3_vhtf8g.jpg',
    category:   'Cars',
    is_premium: false,
    price:      0.0,
    tags:       ['porsche', 'gt3', 'car', 'sports car'],
  },
  {
    title:      'Uchiha Itachi Classic',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774675098/image2_fjpvw7.jpg',
    category:   'Anime',
    is_premium: false,
    price:      0.0,
    tags:       ['itachi', 'uchiha', 'naruto', 'anime'],
  },
];

// ── Premium wallpapers to seed ─────────────────────────────────────────────────
const PREMIUM_WALLPAPERS = [
  {
    title:      'iPhone 15',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774680500/image6_vfxpk4.jpg',
    category:   'Technology',
    is_premium: true,
    price:      10.0,
    tags:       ['iphone', 'apple', 'iphone15', 'tech', 'smartphone'],
  },
  {
    title:      'iPhone 17 Pro Max',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774680501/image5_dnd1zp.jpg',
    category:   'Technology',
    is_premium: true,
    price:      10.0,
    tags:       ['iphone', 'apple', 'iphone17', 'promax', 'tech', 'smartphone'],
  },
];

async function seedWallpapers() {
  console.log('\n══════════════════════════════════════════════════════');
  console.log('  Royal Pixels – Wallpaper Seeder');
  console.log('══════════════════════════════════════════════════════\n');

  // 1. Delete ALL existing FREE wallpapers
  console.log('🗑️  Deleting all existing free wallpapers...');
  const freeSnap = await db.collection('wallpapers')
    .where('is_premium', '==', false)
    .get();

  if (freeSnap.empty) {
    console.log('   (none found – skipping deletion)');
  } else {
    const batchSize = 500;
    let count = 0;
    let batch = db.batch();
    for (const doc of freeSnap.docs) {
      console.log(`   Deleting: ${doc.id} (${doc.data().title || doc.data().category || 'untitled'})`);
      batch.delete(doc.ref);
      count++;
      if (count % batchSize === 0) {
        await batch.commit();
        batch = db.batch();
      }
    }
    if (count % batchSize !== 0) await batch.commit();
    console.log(`   ✅ Deleted ${freeSnap.size} free wallpaper(s)\n`);
  }

  // 2. Add all free wallpapers
  console.log(`➕ Adding ${FREE_WALLPAPERS.length} free wallpapers...\n`);
  for (const wallpaper of FREE_WALLPAPERS) {
    const docRef = await db.collection('wallpapers').add(wallpaper);
    console.log(`   ✅ "${wallpaper.title}" added (ID: ${docRef.id})`);
    console.log(`      Category: ${wallpaper.category} | Premium: No`);
  }

  // 3. Delete ALL existing PREMIUM wallpapers
  console.log('\n🗑️  Deleting all existing premium wallpapers...');
  const premiumSnap = await db.collection('wallpapers')
    .where('is_premium', '==', true)
    .get();

  if (premiumSnap.empty) {
    console.log('   (none found – skipping deletion)');
  } else {
    const batchSizeP = 500;
    let countP = 0;
    let batchP = db.batch();
    for (const doc of premiumSnap.docs) {
      console.log(`   Deleting: ${doc.id} (${doc.data().title || 'untitled'})`);
      batchP.delete(doc.ref);
      countP++;
      if (countP % batchSizeP === 0) {
        await batchP.commit();
        batchP = db.batch();
      }
    }
    if (countP % batchSizeP !== 0) await batchP.commit();
    console.log(`   ✅ Deleted ${premiumSnap.size} premium wallpaper(s)\n`);
  }

  // 4. Add all premium wallpapers
  console.log(`➕ Adding ${PREMIUM_WALLPAPERS.length} premium wallpapers...\n`);
  for (const wallpaper of PREMIUM_WALLPAPERS) {
    const docRef = await db.collection('wallpapers').add(wallpaper);
    console.log(`   ✅ "${wallpaper.title}" added (ID: ${docRef.id})`);
    console.log(`      Category: ${wallpaper.category} | Premium: Yes | Price: ₹${wallpaper.price}`);
  }

  console.log('\n══════════════════════════════════════════════════════');
  console.log('  Done! Hot-reload or restart the app to see changes.');
  console.log('══════════════════════════════════════════════════════\n');

  process.exit(0);
}

seedWallpapers().catch(err => {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
});
