// One-off generator: embeds tools/exercise_seed/exercises_seed.json (the
// real 151-exercise catalog) into lib/data/sample_exercises.dart as a raw
// JSON string, so the Flutter demo fixture matches what's actually in
// Firestore instead of a hand-picked subset. Re-run after `npm run build`
// whenever data/*.json changes.
import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const seedPath = path.join(rootDir, "exercises_seed.json");
const outPath = path.join(rootDir, "..", "..", "lib", "data", "sample_exercises.dart");

const raw = await readFile(seedPath, "utf8");
const data = JSON.parse(raw);
if (raw.includes("'''")) {
  throw new Error("JSON contains triple single-quote, unsafe to embed as a Dart raw string");
}

const header = [
  "import 'dart:convert';",
  "",
  "import '../models/exercise.dart';",
  "",
  "/// Full " + data.length + "-exercise catalog, embedded from the real seeded data",
  "/// (tools/exercise_seed/exercises_seed.json, generated from",
  "/// tools/exercise_seed/data/*.json -- the actual source of truth already",
  "/// pushed to Firestore). Used by InMemoryExerciseRepository so the app is",
  "/// demoable offline without Firebase configured. If tools/exercise_seed/",
  "/// data changes, regenerate: node tools/exercise_seed/scripts/build-seed.mjs",
  "/// then node tools/exercise_seed/scripts/gen-flutter-fixture.mjs",
  "final List<Exercise> sampleExercises = (jsonDecode(_rawExercisesJson) as List)",
  "    .cast<Map<String, dynamic>>()",
  "    .map((raw) => Exercise.fromMap(raw['id'] as String, raw))",
  "    .toList();",
  "",
  "const String _rawExercisesJson = r'''",
].join("\n");

const footer = "\n'''\n;\n";

await writeFile(outPath, header + "\n" + JSON.stringify(data) + footer, "utf8");
console.log(`Wrote ${data.length} exercises to ${outPath}`);
