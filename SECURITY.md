# Security notes — VOLT

## Current architecture
VOLT is currently a static HTML/CSS/JavaScript showcase. It does not implement user accounts, login, a database, file uploads, payments, or server-side API routes. Security controls for those features are not applicable until those features and a backend are introduced.

## Current safeguards and limits
- Do not commit API tokens, passwords, private keys, or `.env` files. `.gitignore` excludes common local secret files, but this does not remove secrets already committed to Git history.
- The Three.js module is loaded from a pinned jsDelivr version. Fonts and visual assets may load from external providers; review providers and licensing before commercial launch.
- The site has no authentication or database, so row-level security, password hashing, session-cookie flags, server-side authorization, SQL parameterization, and API response minimization are not currently applicable.
- Client-side code and HTML meta tags cannot reliably set all HTTP security headers. Configure headers at the actual hosting/CDN layer and verify them in browser developer tools or an HTTP header checker.

## Launch checklist
- [ ] Search the entire Git history for exposed credentials; rotate any exposed credential before removing it from history.
- [ ] Run secret scanning on the repository and enable GitHub secret-scanning/push-protection features if available for the repository plan.
- [ ] Review and pin/update third-party CDN dependencies; test the page after upgrades.
- [ ] Configure HTTPS and redirect HTTP to HTTPS at the hosting layer.
- [ ] Configure appropriate `Content-Security-Policy`, `X-Content-Type-Options: nosniff`, `Referrer-Policy`, and `Permissions-Policy` headers at the host. Test a CSP in report-only mode first because the current page uses an import map and external fonts/assets.
- [ ] Test mobile layout, keyboard navigation, reduced-motion behavior, WebGL fallback, and browser console/network errors.
- [ ] If a backend is added later, implement server-side authentication and authorization, rate limiting/bot controls, validated inputs, parameterized database queries, safe output encoding, upload restrictions, secure cookies, password hashing, least-privilege database policies, and dependency/security scanning before launch.

## Reporting
Do not publish live credentials in an issue. Rotate any exposed secrets immediately and report security concerns privately to the repository owner.
