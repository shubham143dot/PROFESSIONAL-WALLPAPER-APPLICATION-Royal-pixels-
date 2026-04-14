const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const sa = require(path.join(__dirname, 'service_account.json'));
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

db.collection('wallpapers').get().then(snap => {
  const titleCount = {};
  const urlCount = {};
  const duplicates = [];

  snap.docs.forEach(d => {
    const data = d.data();
    const title = data.title ? data.title.toLowerCase() : '';
    const url = data.image_url;

    if (titleCount[title]) {
      duplicates.push({ id: d.id, title: data.title, reason: 'Duplicate Title', premium: data.is_premium });
    } else {
      titleCount[title] = true;
    }

    if (urlCount[url]) {
      if (!duplicates.find(dup => dup.id === d.id)) {
        duplicates.push({ id: d.id, title: data.title, reason: 'Duplicate Image URL', premium: data.is_premium });
      }
    } else {
      urlCount[url] = true;
    }
  });

  const output = {
    totalDuplicates: duplicates.length,
    duplicates: duplicates
  };
  
  fs.writeFileSync('duplicates_output.json', JSON.stringify(output, null, 2), 'utf8');
  console.log('Done');
  process.exit(0);
}).catch(e => { console.error(e.message); process.exit(1); });
