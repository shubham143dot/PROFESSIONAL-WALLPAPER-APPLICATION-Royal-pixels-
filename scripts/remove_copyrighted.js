const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const copyrightedTerms = [
  'marvel', 'dc', 'avengers', 'iron man', 'ironman', 'spider-man', 'spiderman', 'batman', 
  'superman', 'wonder woman', 'flash', 'captain america', 'thor', 'hulk', 'black widow', 
  'black panther', 'doctor strange', 'wolverine', 'x-men', 'xmen', 'deadpool',
  'disney', 'mickey', 'minnie', 'donald duck', 'goofy', 'frozen', 'elsa', 'moana', 
  'star wars', 'jedi', 'sith', 'darth vader', 'yoda', 'mandalorian', 'luke skywalker',
  'anime', 'naruto', 'dragon ball', 'goku', 'vegeta', 'one piece', 'luffy', 'zoro',
  'bleach', 'ichigo', 'demon slayer', 'tanjiro', 'nezuko', 'my hero academia', 'midoriya',
  'attack on titan', 'eren', 'mikasa', 'jujutsu kaisen', 'gojo', 'itadori',
  'pokemon', 'pikachu', 'charizard', 'nintendo', 'mario', 'zelda', 'link',
  'harry potter', 'hogwarts', 'lord of the rings', 'gandalf', 'frodo',
  'gta', 'grand theft auto', 'fortnite', 'minecraft', 'roblox', 'cyberpunk',
  'god of war', 'kratos', 'halo', 'master chief', 'spartans'
];

async function removeCopyrighted() {
  try {
    const snap = await db.collection('wallpapers').get();
    let toDelete = [];
    
    snap.docs.forEach(d => {
      const data = d.data();
      const title = (data.title || '').toLowerCase();
      const category = (data.category_name || '').toLowerCase();
      let tags = [];
      if (Array.isArray(data.tags)) {
        tags = data.tags.map(t => t.toLowerCase());
      } else if (typeof data.tags === 'string') {
        tags = data.tags.split(',').map(t => t.trim().toLowerCase());
      }

      let flaggedTerms = new Set();
      const checkForMatch = (text) => {
        if (!text) return;
        for (const term of copyrightedTerms) {
          if (text.includes(term)) {
            flaggedTerms.add(term);
          }
        }
      }

      checkForMatch(title);
      checkForMatch(category);
      tags.forEach(t => checkForMatch(t));

      if (flaggedTerms.size > 0) {
        toDelete.push({
          id: d.id,
          data: data,
          flaggedBy: Array.from(flaggedTerms)
        });
      }
    });

    if (toDelete.length === 0) {
      console.log('No copyrighted wallpapers found to delete.');
      process.exit(0);
      return;
    }

    // Backup the data before deleting, to adhere to strict safety protocols!
    const backupPath = path.join(__dirname, 'copyrighted_backup.json');
    fs.writeFileSync(backupPath, JSON.stringify(toDelete, null, 2), 'utf-8');
    console.log(`✅ Backed up ${toDelete.length} wallpapers to ${backupPath}. If this was a mistake, we can restore them.`);

    console.log(`\nDeleting ${toDelete.length} wallpapers from Firestore...`);
    const batch = db.batch();
    for (const item of toDelete) {
      console.log(`  Deleting: ${item.data.title} (ID: ${item.id})`);
      const docRef = db.collection('wallpapers').doc(item.id);
      batch.delete(docRef);
    }
    
    await batch.commit();
    console.log('\n✅ Successfully deleted the copyrighted wallpapers from the database.');

  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    process.exit(0);
  }
}

removeCopyrighted();
