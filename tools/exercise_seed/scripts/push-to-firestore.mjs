// One-time push of exercises_seed.json into the Firestore `exercises`
// collection, per docs/TV2_TASKS.md §6. Idempotent: re-running overwrites
// the same documents (keyed by the generated `id`) instead of duplicating.
//
// Usage:
//   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json npm run push
//   (add --allow-missing-images to push even if some imageUrl are empty)

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { initializeApp, cert, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const seedFile = path.join(rootDir, "exercises_seed.json");

const allowMissingImages = process.argv.includes("--allow-missing-images");

async function main() {
  const seed = JSON.parse(await readFile(seedFile, "utf8"));

  const missingImages = seed.filter((e) => !e.imageUrl);
  if (missingImages.length > 0 && !allowMissingImages) {
    console.error(
      `Refusing to push: ${missingImages.length} exercise(s) have an empty imageUrl.`
    );
    console.error("Run `npm run fetch-images` first, or re-run with --allow-missing-images.");
    for (const e of missingImages.slice(0, 10)) console.error(` - ${e.name}`);
    process.exit(1);
  }

  const credential = process.env.GOOGLE_APPLICATION_CREDENTIALS
    ? cert(JSON.parse(await readFile(process.env.GOOGLE_APPLICATION_CREDENTIALS, "utf8")))
    : applicationDefault();

  initializeApp({ credential });
  const db = getFirestore();

  const batchSize = 400; // Firestore batch limit is 500 writes
  let written = 0;

  for (let i = 0; i < seed.length; i += batchSize) {
    const batch = db.batch();
    const chunk = seed.slice(i, i + batchSize);

    for (const exercise of chunk) {
      const { id, ...fields } = exercise;
      const ref = db.collection("exercises").doc(id);
      batch.set(
        ref,
        {
          ...fields,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true }
      );
    }

    await batch.commit();
    written += chunk.length;
    console.log(`Pushed ${written}/${seed.length}...`);
  }

  console.log(`Done. Wrote ${written} exercises to the "exercises" collection.`);
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
