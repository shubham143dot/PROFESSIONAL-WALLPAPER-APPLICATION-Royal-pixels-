/**
 * Royal Pixels – Add New Wallpapers (Append-only, no deletions)
 *
 * NEW FREE wallpapers:
 *   - White Cat
 *   - Sand Man
 *
 * NEW PREMIUM wallpapers:
 *   - Lord Krishna
 *
 * Run:
 *   node scripts/add_new_wallpapers.js
 */

const admin = require('firebase-admin');
const path  = require('path');

const serviceAccount = require(path.join(__dirname, 'service_account.json'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// ── New FREE wallpapers ───────────────────────────────────────────────────────
const NEW_FREE_WALLPAPERS = [];

// ── New PREMIUM wallpapers ─────────────────────────────────────────────────────
const NEW_PREMIUM_WALLPAPERS = [
  {
    title:      'blue eyes',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774806438/WhatsApp_Image_2026-03-29_at_11.14.48_PM_1_qhbwh8.jpg',
    category:   'Abstract',
    is_premium: true,
    price:      30.0,
    tags:       ['blue', 'eyes', 'abstract'],
  },
  {
    title:      'the sky',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774806438/WhatsApp_Image_2026-03-29_at_11.14.48_PM_2_ekvqyv.jpg',
    category:   'Nature',
    is_premium: true,
    price:      30.0,
    tags:       ['sky', 'nature', 'clouds'],
  },
  {
    title:      'elder rings',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774806438/WhatsApp_Image_2026-03-29_at_11.14.48_PM_ild7iz.jpg',
    category:   'Gaming',
    is_premium: true,
    price:      100.0,
    tags:       ['elden ring', 'gaming', 'game', 'rpg'],
  },
  {
    title:      'gradient',
    image_url:  'https://res.cloudinary.com/dl00rha3n/image/upload/v1774806438/WhatsApp_Image_2026-03-29_at_11.14.49_PM_g2zh72.jpg',
    category:   'Abstract',
    is_premium: true,
    price:      30.0,
    tags:       ['gradient', 'abstract', 'colors'],
  },
];

async function addNewWallpapers() {
  console.log('\n══════════════════════════════════════════════════════');
  console.log('  Royal Pixels – Add New Wallpapers (Append Only)');
  console.log('══════════════════════════════════════════════════════\n');

  // Add free wallpapers
  console.log(`➕ Adding ${NEW_FREE_WALLPAPERS.length} new free wallpaper(s)...\n`);
  for (const wallpaper of NEW_FREE_WALLPAPERS) {
    const docRef = await db.collection('wallpapers').add(wallpaper);
    console.log(`   ✅ "${wallpaper.title}" added (ID: ${docRef.id})`);
    console.log(`      Category: ${wallpaper.category} | Premium: No`);
  }

  // Add premium wallpapers
  console.log(`\n➕ Adding ${NEW_PREMIUM_WALLPAPERS.length} new premium wallpaper(s)...\n`);
  for (const wallpaper of NEW_PREMIUM_WALLPAPERS) {
    const docRef = await db.collection('wallpapers').add(wallpaper);
    console.log(`   ✅ "${wallpaper.title}" added (ID: ${docRef.id})`);
    console.log(`      Category: ${wallpaper.category} | Premium: Yes | Price: ₹${wallpaper.price}`);
  }

  console.log('\n══════════════════════════════════════════════════════');
  console.log('  Done! Hot-reload or restart the app to see changes.');
  console.log('══════════════════════════════════════════════════════\n');

  process.exit(0);
}

addNewWallpapers().catch(err => {
  console.error('\n❌ Error:', err.message);
  process.exit(1);
});
