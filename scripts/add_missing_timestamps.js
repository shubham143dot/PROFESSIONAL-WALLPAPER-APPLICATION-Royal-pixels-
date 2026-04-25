const admin = require('firebase-admin');
const path = require('path');

// Logic for fetching service account (same as check_duplicates.js)
const sa = require(path.join(__dirname, 'service_account.json'));

if (!admin.apps.length) {
    admin.initializeApp({
        credential: admin.credential.cert(sa)
    });
}

const db = admin.firestore();

async function addMissingTimestamps() {
    console.log('--- Starting Database Fix: Adding Missing Timestamps ---');
    
    const collectionRef = db.collection('wallpapers');
    const snapshot = await collectionRef.get();
    
    console.log(`Analyzing ${snapshot.size} wallpapers...`);
    
    let updatedCount = 0;
    const batch = db.batch();
    
    // Fallback date for wallpapers missing 'created_at' (e.g., 2026-03-01)
    const fallbackDate = new Date('2026-03-01T00:00:00Z');
    
    snapshot.docs.forEach((doc) => {
        const data = doc.data();
        
        if (!data.created_at) {
            batch.update(doc.ref, {
                created_at: admin.firestore.Timestamp.fromDate(fallbackDate)
            });
            updatedCount++;
        }
    });
    
    if (updatedCount > 0) {
        await batch.commit();
        console.log(`Successfully updated ${updatedCount} wallpapers with missing timestamps.`);
    } else {
        console.log('No wallpapers were missing timestamps.');
    }
    
    process.exit(0);
}

addMissingTimestamps().catch((err) => {
    console.error('Error updating timestamps:', err);
    process.exit(1);
});
