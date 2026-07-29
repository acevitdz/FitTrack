// Fills in `imageUrl` for every exercise in data/*.json that doesn't have one
// yet, using the Pexels API (free, license-safe for this use case:
// https://www.pexels.com/license/). Every image is requested at the same
// fixed size so the library has a consistent aspect ratio.
//
// Writes back to data/*.json (the source of truth) rather than
// exercises_seed.json, so that re-running `npm run build` afterwards keeps
// the fetched images instead of wiping them out.
//
// Requires a free API key from https://www.pexels.com/api/ (sign up, no
// cost). Usage: PEXELS_API_KEY=xxxx npm run fetch-images

import { readdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dataDir = path.join(rootDir, "data");

const TARGET_WIDTH = 800;
const TARGET_HEIGHT = 600;

const apiKey = process.env.PEXELS_API_KEY;
if (!apiKey) {
  console.error("Missing PEXELS_API_KEY. Get a free key at https://www.pexels.com/api/");
  process.exit(1);
}

async function searchImage(query) {
  const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(
    query
  )}&per_page=1&orientation=landscape`;
  const res = await fetch(url, { headers: { Authorization: apiKey } });
  if (!res.ok) {
    throw new Error(`Pexels request failed: ${res.status} ${res.statusText}`);
  }
  const body = await res.json();
  const photo = body.photos?.[0];
  if (!photo) return null;

  // Fixed crop dimensions so every exercise image shares the same aspect ratio.
  return `${photo.src.original}?auto=compress&cs=tinysrgb&fit=crop&w=${TARGET_WIDTH}&h=${TARGET_HEIGHT}`;
}

async function main() {
  const files = (await readdir(dataDir)).filter((f) => f.endsWith(".json"));

  let filled = 0;
  let failed = 0;

  for (const file of files) {
    const filePath = path.join(dataDir, file);
    const entries = JSON.parse(await readFile(filePath, "utf8"));
    let changed = false;

    for (const entry of entries) {
      if (entry.imageUrl) continue;

      const query = entry.imageQuery ?? entry.name;
      try {
        const url = await searchImage(query);
        if (url) {
          entry.imageUrl = url;
          changed = true;
          filled += 1;
          console.log(`OK   ${entry.name} <- "${query}"`);
        } else {
          failed += 1;
          console.warn(`MISS ${entry.name} <- "${query}" (no results)`);
        }
      } catch (err) {
        failed += 1;
        console.warn(`FAIL ${entry.name} <- "${query}" (${err.message})`);
      }

      // Be polite to the free-tier rate limit.
      await new Promise((r) => setTimeout(r, 250));
    }

    if (changed) {
      await writeFile(filePath, JSON.stringify(entries, null, 2) + "\n", "utf8");
    }
  }

  console.log(`\nFilled ${filled} image(s), ${failed} still missing.`);
  console.log("Run `npm run build` to regenerate exercises_seed.json with the new images.");
  console.log("Review the results before pushing — Pexels search matches are not guaranteed exact.");
}

main();
