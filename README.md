# VOLT — Find Your Frequency

A responsive, dark-neon product concept website with a live Three.js 3D showcase.

## Features
- Interactive 3D can display with drag-to-rotate interaction
- Eased product entrance, floating motion, scroll-linked movement, and drifting particles
- Metallic studio lighting, condensation details, and flavor-specific label textures
- Three selectable flavor concepts that highlight the matching can
- Responsive layout designed for desktop, tablet, and mobile
- Brand sections, flavor cards, motion graphics, and clear navigation
- Keyboard-accessible flavor buttons and reduced-motion support
- CSS-rendered three-can fallback when WebGL initialization is unavailable
- Open Graph and search metadata

## Project structure
```
volt-3d-website/
├── index.html
├── README.md
├── css/
│   └── style.css
└── js/
    └── main.js
```

## Run locally
Three.js loads as an ES module from jsDelivr, so serve the files over HTTP.

```bash
python -m http.server 8000
```

Open http://localhost:8000.

## GitHub Pages
The site is configured to publish from the `main` branch and root folder. After commits, allow GitHub Pages a short time to rebuild:
https://zydonllado9.github.io/volt-3d-website/

## Before commercial use
VOLT is a fictional concept brand. Replace placeholder copy and artwork, validate all product claims, test on real devices, and review third-party licensing before using this as a commercial site.


## Verification notes
- Source-level checks verified the three flavor buttons, internal section anchors, reduced-motion hooks, renderer cleanup, and the CSS fallback selectors.
- The deployed site still needs a real-browser pass for visual layout, network asset loading, and browser console errors. The connected GitHub tool does not provide an interactive browser session.
- Three.js is loaded as an ES module from jsDelivr, and the font and photographic lifestyle assets are external resources; those require an internet connection.
