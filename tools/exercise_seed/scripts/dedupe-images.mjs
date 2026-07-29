// Repairs duplicate imageUrl values across data/*.json. Pexels' top-1 result
// for similar gym-equipment queries often returns the exact same photo for
// different exercises (e.g. "seated calf raise machine" and "seated leg curl
// machine" both surfaced the same generic gym-machine stock photo).
//
// Strategy: for every group of exercises currently sharing one photo, keep
// the first entry's image and re-search for the rest, pulling a wider result
// page (not just the top-1) and picking the first candidate whose photo id
// hasn't already been used anywhere in the catalog. Falls back to a broadened
// query (drop the most specific word) if the primary query's pool is
// exhausted.
//
// Usage: PEXELS_API_KEY=xxxx node scripts/dedupe-images.mjs

import { readdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dataDir = path.join(rootDir, "data");

const TARGET_WIDTH = 800;
const TARGET_HEIGHT = 600;
const PAGE_SIZE = 15;

const apiKey = process.env.PEXELS_API_KEY;
if (!apiKey) {
  console.error("Missing PEXELS_API_KEY. Get a free key at https://www.pexels.com/api/");
  process.exit(1);
}

function photoIdFromUrl(url) {
  const m = url.match(/photos\/(\d+)\/pexels-photo/);
  return m ? m[1] : null;
}

function toImageUrl(photo) {
  return `${photo.src.original}?auto=compress&cs=tinysrgb&fit=crop&w=${TARGET_WIDTH}&h=${TARGET_HEIGHT}`;
}

async function searchCandidates(query) {
  const url = `https://api.pexels.com/v1/search?query=${encodeURIComponent(
    query
  )}&per_page=${PAGE_SIZE}&orientation=landscape`;
  const res = await fetch(url, { headers: { Authorization: apiKey } });
  if (!res.ok) {
    throw new Error(`Pexels request failed: ${res.status} ${res.statusText}`);
  }
  const body = await res.json();
  return body.photos ?? [];
}

function broadenedQuery(query) {
  const words = query.split(" ");
  return words.length > 1 ? words.slice(0, -1).join(" ") : null;
}

async function pickUnusedPhoto(query, usedIds) {
  const queriesToTry = [query, broadenedQuery(query)].filter(Boolean);

  for (const q of queriesToTry) {
    const candidates = await searchCandidates(q);
    for (const photo of candidates) {
      const id = String(photo.id);
      if (!usedIds.has(id)) {
        return { photo, id, queryUsed: q };
      }
    }
  }
  return null;
}

async function main() {
  const files = (await readdir(dataDir)).filter((f) => f.endsWith(".json"));
  const allEntries = []; // { file, entry }
  const usedIds = new Set();

  for (const file of files) {
    const entries = JSON.parse(await readFile(path.join(dataDir, file), "utf8"));
    for (const entry of entries) {
      allEntries.push({ file, entry });
    }
  }

  // Group by current photo id to find duplicates.
  const byPhotoId = new Map();
  for (const item of allEntries) {
    const id = photoIdFromUrl(item.entry.imageUrl);
    if (!id) continue;
    if (!byPhotoId.has(id)) byPhotoId.set(id, []);
    byPhotoId.get(id).push(item);
  }

  const toRefetch = [];
  for (const [id, group] of byPhotoId) {
    if (group.length <= 1) {
      usedIds.add(id); // unique image, keep it reserved
      continue;
    }
    // Keep the first one as-is, refetch the rest.
    usedIds.add(id);
    for (const item of group.slice(1)) {
      toRefetch.push(item);
    }
  }

  console.log(`Found ${toRefetch.length} exercise(s) needing a replacement image.\n`);

  const changedFiles = new Set();
  let fixed = 0;
  let unresolved = 0;

  for (const { file, entry } of toRefetch) {
    const query = entry.imageQuery ?? entry.name;
    try {
      const result = await pickUnusedPhoto(query, usedIds);
      if (result) {
        entry.imageUrl = toImageUrl(result.photo);
        usedIds.add(result.id);
        changedFiles.add(file);
        fixed += 1;
        console.log(`OK   ${entry.name} <- "${result.queryUsed}" (photo ${result.id})`);
      } else {
        unresolved += 1;
        console.warn(`STUCK ${entry.name} <- "${query}" (no unused candidates found, left as-is)`);
      }
    } catch (err) {
      unresolved += 1;
      console.warn(`FAIL ${entry.name} <- "${query}" (${err.message})`);
    }
    await new Promise((r) => setTimeout(r, 250));
  }

  for (const file of changedFiles) {
    const entries = allEntries.filter((i) => i.file === file).map((i) => i.entry);
    await writeFile(path.join(dataDir, file), JSON.stringify(entries, null, 2) + "\n", "utf8");
  }

  console.log(`\nFixed ${fixed}, unresolved ${unresolved}.`);
  console.log("Run `npm run build` to regenerate exercises_seed.json.");
}

main();
