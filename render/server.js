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

// Create HTTP server and attach WebSocket server for file relay
const http = require('http');
const server = http.createServer(app);

const { WebSocketServer } = require('ws');

// Rooms map: roomId -> Set of sockets
const rooms = new Map();

const wss = new WebSocketServer({ noServer: true, path: '/ws' });

wss.on('connection', (ws) => {
  ws.roomId = null;
  ws.on('message', (data, isBinary) => {
    // If message is binary, simply forward to other participants in room
    if (isBinary) {
      if (!ws.roomId) return;
      const sockets = rooms.get(ws.roomId) || new Set();
      for (const s of sockets) {
        if (s !== ws && s.readyState === s.OPEN) s.send(data, { binary: true });
      }
      return;
    }

    // Otherwise expect JSON control messages
    let msg = null;
    try {
      msg = JSON.parse(data.toString());
    } catch (e) {
      console.warn('Invalid JSON message', e);
      return;
    }

    if (msg.type === 'join' && msg.room) {
      ws.roomId = msg.room;
      let sockets = rooms.get(msg.room);
      if (!sockets) {
        sockets = new Set();
        rooms.set(msg.room, sockets);
      }
      sockets.add(ws);
      // notify others
      for (const s of sockets) {
        if (s !== ws && s.readyState === s.OPEN) {
          s.send(JSON.stringify({ type: 'peer-joined', room: msg.room }));
        }
      }
      return;
    }

    if (msg.type === 'leave') {
      if (ws.roomId) {
        const sockets = rooms.get(ws.roomId);
        if (sockets) sockets.delete(ws);
        ws.roomId = null;
      }
      return;
    }

    // Relay control messages (metadata) to other peers in the room
    if (ws.roomId && msg) {
      const sockets = rooms.get(ws.roomId) || new Set();
      for (const s of sockets) {
        if (s !== ws && s.readyState === s.OPEN) s.send(JSON.stringify(msg));
      }
    }
  });

  ws.on('close', () => {
    if (ws.roomId) {
      const sockets = rooms.get(ws.roomId);
      if (sockets) {
        sockets.delete(ws);
        if (sockets.size === 0) rooms.delete(ws.roomId);
      }
    }
  });
});

server.on('upgrade', (request, socket, head) => {
  // Let ws handle upgrades to /ws
  wss.handleUpgrade(request, socket, head, (ws) => {
    wss.emit('connection', ws, request);
  });
});

server.listen(PORT, () => {
  console.log(`Reyaansh-Chat web server serving from ${staticDir} on port ${PORT}`);
  console.log('WebSocket endpoint available at /ws');
});
