import { readdir, readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { MUSCLES, validateExercise, slugify } from "../schema.mjs";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const dataDir = path.join(rootDir, "data");
const outFile = path.join(rootDir, "exercises_seed.json");

async function main() {
  const files = (await readdir(dataDir)).filter((f) => f.endsWith(".json"));

  const allErrors = [];
  const seenIds = new Set();
  const seenNames = new Set();
  const countByMuscle = Object.fromEntries(MUSCLES.map((m) => [m, 0]));
  const result = [];

  for (const file of files) {
    const muscleKey = path.basename(file, ".json");
    if (!MUSCLES.includes(muscleKey)) {
      allErrors.push(`${file}: filename "${muscleKey}" is not a valid muscle enum key`);
      continue;
    }

    const raw = await readFile(path.join(dataDir, file), "utf8");
    let entries;
    try {
      entries = JSON.parse(raw);
    } catch (e) {
      allErrors.push(`${file}: invalid JSON (${e.message})`);
      continue;
    }

    for (const entry of entries) {
      if (entry.primaryMuscle !== muscleKey) {
        allErrors.push(
          `${file} / "${entry.name}": primaryMuscle "${entry.primaryMuscle}" does not match filename "${muscleKey}"`
        );
      }

      const errors = validateExercise(entry, file);
      if (errors.length > 0) {
        allErrors.push(...errors);
        continue;
      }

      if (seenNames.has(entry.name)) {
        allErrors.push(`${file}: duplicate exercise name "${entry.name}"`);
        continue;
      }
      seenNames.add(entry.name);

      let id = slugify(entry.name, entry.id);
      if (seenIds.has(id)) {
        // Vietnamese diacritics are lossy once stripped (e.g. "tạ đòn" and
        // "tạ đơn" both become "ta don"), so disambiguate deterministically
        // instead of treating every collision as an authoring error.
        let suffix = 2;
        while (seenIds.has(`${id}-${suffix}`)) suffix += 1;
        id = `${id}-${suffix}`;
      }
      seenIds.add(id);

      const { imageQuery, ...schemaFields } = entry;
      result.push({ id, ...schemaFields });
      countByMuscle[muscleKey] += 1;
    }
  }

  if (allErrors.length > 0) {
    console.error(`Build failed with ${allErrors.length} error(s):\n`);
    for (const err of allErrors) console.error(` - ${err}`);
    process.exitCode = 1;
    return;
  }

  await writeFile(outFile, JSON.stringify(result, null, 2) + "\n", "utf8");

  console.log(`Wrote ${result.length} exercises to ${path.relative(rootDir, outFile)}`);
  console.log("Count per muscle:");
  for (const [muscle, count] of Object.entries(countByMuscle)) {
    console.log(`  ${muscle}: ${count}`);
  }

  const missingImages = result.filter((e) => !e.imageUrl).length;
  if (missingImages > 0) {
    console.log(
      `\n${missingImages} exercise(s) still have an empty imageUrl. Run "npm run fetch-images" (needs PEXELS_API_KEY) before pushing.`
    );
  }
}

main();
