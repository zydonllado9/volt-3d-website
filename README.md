# VOLT — 3D Flavor Orbit

A responsive product landing page featuring an actual Three.js 3D scene.

## Project structure

```text
volt-3d-website/
├── index.html
├── README.md
├── css/
│   └── style.css
└── js/
    └── main.js
```

## Features

- Real-time 3D cans rendered with Three.js and WebGL
- Three selectable flavors
- Pointer-responsive motion and animated orbit elements
- Responsive desktop and mobile layout
- CSS reduced-motion support

## Run locally

Three.js is loaded as an ES module from jsDelivr, so serve the files over HTTP instead of opening `index.html` directly.

**Python**
```bash
python -m http.server 8000
```
Then visit `http://localhost:8000`.

**VS Code:** Install the Live Server extension, right-click `index.html`, then choose **Open with Live Server**.

## Publish with GitHub Pages

1. Upload `index.html`, `README.md`, and the `css` and `js` folders to the root of your repository.
2. In GitHub, open **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select `main` and `/ (root)`, then save.
5. Wait for deployment to finish; GitHub will show the published URL in the Pages section.

## Dependencies

- Three.js 0.166.1 from jsDelivr CDN
- An internet connection is needed to load Three.js.

## Before commercial use

This is a concept demo. Replace placeholder brand copy and artwork, test on real mobile devices, and review third-party licensing and performance before launch.
