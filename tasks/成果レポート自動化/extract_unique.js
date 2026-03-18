const fs = require('fs');
const data = JSON.parse(fs.readFileSync('/tmp/a_column.json', 'utf-8'));
const values = data.values.filter(r => r.length > 0).map(r => r[0]);
const unique = [...new Set(values)].sort();
unique.forEach(v => console.log(v));
