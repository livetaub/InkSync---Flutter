# InkSync Marketing Site

The public-facing marketing website for [InkSync](https://inksyncnote.com) — a smart, cross-platform note-taking app. Built with React, TypeScript, and Vite.

## Getting Started

### Prerequisites

- Node.js 18+
- npm

### Install Dependencies

```bash
npm install
```

### Run Locally

```bash
npm run dev
```

The dev server starts at `http://localhost:5173` by default.

### Build for Production

```bash
npm run build
```

The output is generated in the `dist/` directory.

### Deploy

The site is deployed to **Cloudflare Pages**. Push to the main branch or run:

```bash
npm run build
# Upload the `dist/` folder to Cloudflare Pages
```

## Environment Variables

Create a `.env` file in the project root with the following variables:

| Variable | Description |
| --- | --- |
| `VITE_SUPABASE_URL` | Supabase project URL (used for fetching live pricing) |
| `VITE_SUPABASE_ANON_KEY` | Supabase anonymous/public key |

> **Note:** The site works without these variables — pricing will fall back to hardcoded defaults.

## Tech Stack

- **React 19** + **TypeScript**
- **Vite** — build tool
- **Supabase** — pricing data
- **Cloudflare Pages** — hosting
