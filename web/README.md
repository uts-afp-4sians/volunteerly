# web — Volunteerly landing & support page

Static marketing + support site for the Volunteerly iOS app, used for the App
Store **Support URL** and **Marketing URL**. Built with Vite + React + TypeScript
+ Tailwind v4, deployed to GitHub Pages.

- **Live URL:** https://uts-afp-4sians.github.io/volunteerly/
- Design tokens mirror the iOS app (`volunteerly/Shared/DesignSystem`,
  `Assets.xcassets`) — see `src/index.css` `@theme`.

## Develop

```sh
mise run web:dev       # or: cd web && bun run dev
mise run web:build     # production build → web/dist
mise run web:preview   # serve the built output
```

## Deploy

Pushing to `main` with changes under `web/**` triggers
`.github/workflows/deploy-web.yml`, which builds with bun and publishes to Pages.

**One-time setup:** in the GitHub repo, Settings → Pages → *Build and deployment*
→ Source: **GitHub Actions**.

## Notes

- Vite `base` is `/volunteerly/` (project Pages live under the repo sub-path).
- `public/icon.png` is copied from the iOS `AppIcon`; refresh it if the icon changes.
- Update `APP_STORE_URL` in `src/App.tsx` once the App Store listing is live.
