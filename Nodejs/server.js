const express = require('express');
const bodyParser = require('body-parser');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const port = process.env.PORT || 3000;
const dataDir = path.join(__dirname, 'data');
const uploadsDir = path.join(__dirname, 'uploads');

if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });
if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

app.use(cors());
app.use(bodyParser.json({ limit: '20mb' }));

function readJson(filePath, fallback) {
  try {
    if (!fs.existsSync(filePath)) return fallback;
    return JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    return fallback;
  }
}

function writeJson(filePath, data) {
  fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
}

app.get('/health', (req, res) => {
  res.json({ ok: true, mode: 'local-node' });
});

app.get('/api/health', (req, res) => {
  res.json({ ok: true, mode: 'local-node' });
});

app.get('/api/users', (req, res) => {
  const usersPath = path.join(dataDir, 'users.json');
  const users = readJson(usersPath, {});
  res.json(Object.entries(users).map(([id, value]) => ({ id, ...value })));
});

app.get('/api/users/:id', (req, res) => {
  const usersPath = path.join(dataDir, 'users.json');
  const users = readJson(usersPath, {});
  const user = users[req.params.id];
  if (!user) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(user);
});

app.post('/api/users/:id', (req, res) => {
  const usersPath = path.join(dataDir, 'users.json');
  const users = readJson(usersPath, {});
  users[req.params.id] = req.body;
  writeJson(usersPath, users);
  res.json({ ok: true });
});

app.post('/api/value/:path(*)', (req, res) => {
  const filePath = path.join(dataDir, `${req.params.path.replace(/\//g, '_')}.json`);
  const payload = req.body && typeof req.body === 'object' ? req.body : { value: req.body };
  writeJson(filePath, payload);
  res.json({ ok: true });
});

app.get('/api/value/:path(*)', (req, res) => {
  const filePath = path.join(dataDir, `${req.params.path.replace(/\//g, '_')}.json`);
  if (!fs.existsSync(filePath)) {
    res.status(404).json({ error: 'Not found' });
    return;
  }
  res.json(readJson(filePath, {}));
});

app.post('/api/collection/:path(*)', (req, res) => {
  const collectionFile = path.join(dataDir, `${req.params.path.replace(/\//g, '_')}.json`);
  const list = readJson(collectionFile, []);
  const payload = req.body && typeof req.body === 'object' ? req.body : { value: req.body };
  list.push(payload);
  writeJson(collectionFile, list);
  res.json({ ok: true });
});

app.get('/api/collection/:path(*)', (req, res) => {
  const collectionFile = path.join(dataDir, `${req.params.path.replace(/\//g, '_')}.json`);
  if (!fs.existsSync(collectionFile)) {
    res.json([]);
    return;
  }
  res.json(readJson(collectionFile, []));
});

app.post('/api/upload', (req, res) => {
  const { name, mimeType, contentBase64 } = req.body || {};
  if (!name || !contentBase64) {
    res.status(400).json({ error: 'Missing payload' });
    return;
  }
  const buffer = Buffer.from(contentBase64, 'base64');
  const safeName = String(name).replace(/[^a-zA-Z0-9._-]/g, '_');
  const filePath = path.join(uploadsDir, `${Date.now()}_${safeName}`);
  fs.writeFileSync(filePath, buffer);
  const publicUrl = `/uploads/${path.basename(filePath)}`;
  res.json({ ok: true, url: publicUrl });
});

app.use('/uploads', express.static(uploadsDir));

app.listen(port, '0.0.0.0', () => {
  console.log(`Local chat backend listening on port ${port}`);
});
