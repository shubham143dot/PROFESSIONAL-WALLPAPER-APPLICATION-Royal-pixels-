const admin = require('firebase-admin');
const path = require('path');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// A heuristic list of known copyrighted terms (lowercase)
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

async function checkCopyright() {
  try {
    const snap = await db.collection('wallpapers').get();
    console.log(`Total wallpapers: ${snap.size}`);
    
    let potentiallyCopyrighted = [];
    let safe = [];
    
    snap.docs.forEach(d => {
      const data = d.data();
      const title = (data.title || '').toLowerCase();
      const category = (data.category_name || '').toLowerCase(); // If category exists
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
        potentiallyCopyrighted.push({
          id: d.id,
          title: data.title,
          flaggedBy: Array.from(flaggedTerms)
        });
      } else {
        safe.push({
          id: d.id,
          title: data.title
        });
      }
    });

    console.log('\n--- POTENTIALLY COPYRIGHTED WALLPAPERS ---');
    if (potentiallyCopyrighted.length === 0) {
      console.log('None found based on our rules.');
    } else {
      potentiallyCopyrighted.forEach(w => {
        console.log(`- [${w.id}] "${w.title}" -> Matched terms: [${w.flaggedBy.join(', ')}]`);
      });
      console.log(`Total Potentially Copyrighted: ${potentiallyCopyrighted.length}`);
    }

  } catch (e) {
    console.error('Error:', e.message);
  } finally {
    process.exit(0);
  }
}

checkCopyright();
