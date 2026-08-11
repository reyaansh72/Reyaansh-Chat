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
