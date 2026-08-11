This folder contains a minimal Node/Express server to serve the prebuilt web artifact located in the repository under `prebuilt/`.

Deployment notes:

- The GitHub Actions workflow builds `build/web` and copies the output into `prebuilt/`, then commits the updated `prebuilt/` folder back to the repository.
- On Render.com or similar hosts, `render/package.json` and `render/server.js` will be used. Set the start command to `npm start` and ensure Node 18 is used.

Local test:

```bash
cd render
npm install
npm start
# open http://localhost:3000
```

WebSocket file transfer (relay) overview

- This server exposes a WebSocket endpoint at `/ws` that acts as a simple relay for file transfers.
- Clients join a "room" by sending JSON: `{ "type": "join", "room": "ROOM_ID" }`.
- Binary messages sent over the socket are relayed to other participants in the same room.
- Control/metadata messages (JSON) are also relayed to peers in the same room.

Recommended client flow (high level):

1. Sender generates a short room token (e.g. 6-8 alphanumeric chars) and encodes a connection URL in a QR code: `https://Reyaansh-Chat.onrender.com/?room=ROOM_ID`.
2. Receiver scans QR and opens the web app; the app reads the `room` param and connects to the WebSocket `/ws` and joins the room.
3. Sender also connects to `/ws` and joins the same room. The app exchanges metadata messages to coordinate file transfer and then sends binary chunks which are relayed by the server.

Security note: this relay does not encrypt the payloads — if you need end-to-end encryption, perform client-side encryption before sending.

Limitations: this approach uses server-side relay; true peer-to-peer NAT traversal (WebRTC) is more complex but can avoid uploading file contents to the relay.
