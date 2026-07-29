// One-time brainstorming aid: pulls exercise names + categories + equipment
// from the open wger.de API and saves the raw response locally for reference.
//
// This is intentionally NOT part of the production data pipeline:
//   - names/categories are only used as inspiration when authoring data/*.json
//   - content is rewritten by hand in Vietnamese (never copied verbatim)
//   - wger.de images are never used (license risk, see docs/TV2_TASKS.md §6)
//   - this script is never called at app runtime, only manually, once
//
// Usage: npm run fetch-reference

import { mkdir, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const outDir = path.join(rootDir, "reference");

const BASE_URL = "https://wger.de/api/v2";
const PAGE_SIZE = 100;
const LANGUAGE_ENGLISH = 2; // wger language id for English

async function fetchAllPages(endpoint) {
  const results = [];
  let url = `${BASE_URL}/${endpoint}/?limit=${PAGE_SIZE}`;

  while (url) {
    const res = await fetch(url);
    if (!res.ok) {
      throw new Error(`wger.de request failed: ${res.status} ${res.statusText} (${url})`);
    }
    const body = await res.json();
    results.push(...body.results);
    url = body.next;
  }

  return results;
}

async function main() {
  await mkdir(outDir, { recursive: true });

  console.log("Fetching exercise categories (muscle group ideas)...");
  const categories = await fetchAllPages("exercisecategory");

  console.log("Fetching equipment list (equipment naming ideas)...");
  const equipment = await fetchAllPages("equipment");

  console.log("Fetching exercise names (English, for brainstorming only)...");
  const exerciseInfo = await fetchAllPages("exerciseinfo");
  const nameIdeas = exerciseInfo
    .map((entry) => {
      const translation = entry.translations?.find((t) => t.language === LANGUAGE_ENGLISH);
      return translation
        ? {
            id: entry.id,
            name: translation.name,
            category: entry.category?.name,
            equipment: entry.equipment?.map((e) => e.name),
          }
        : null;
    })
    .filter(Boolean);

  await writeFile(
    path.join(outDir, "categories.json"),
    JSON.stringify(categories, null, 2)
  );
  await writeFile(
    path.join(outDir, "equipment.json"),
    JSON.stringify(equipment, null, 2)
  );
  await writeFile(
    path.join(outDir, "exercise-name-ideas.json"),
    JSON.stringify(nameIdeas, null, 2)
  );

  console.log(`Saved ${categories.length} categories, ${equipment.length} equipment types,`);
  console.log(`and ${nameIdeas.length} exercise name ideas to ./reference/`);
  console.log("Reminder: use these only as brainstorming input for data/*.json — do not copy");
  console.log("content or images from wger.de directly.");
}

main().catch((err) => {
  console.error(err.message);
  process.exitCode = 1;
});
