const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
// Serve the prebuilt web artifact committed to `prebuilt/` in the repo
const staticDir = path.join(__dirname, '..', 'prebuilt');

app.use(express.static(staticDir, {index: false}));

// SPA fallback to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(staticDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Reyaansh-Chat web server serving from ${staticDir} on port ${PORT}`);
});
