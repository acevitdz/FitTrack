export const MUSCLES = [
  "nguc",
  "lung_tren",
  "lung_duoi",
  "vai_truoc",
  "vai_giua",
  "vai_sau",
  "tay_truoc",
  "tay_sau",
  "dui_truoc",
  "dui_sau",
  "mong",
  "bap_chan",
  "bung",
];

export const EQUIPMENT = [
  "khong_dung_cu",
  "ta_don",
  "ta_doi",
  "day_khang_luc",
  "ghe_tap",
  "may_tap_nguc",
  "may_keo_xo",
  "may_tap_chan",
  "xa_ngang",
];

export const DIFFICULTIES = ["beginner", "intermediate", "advanced"];

const REQUIRED_STRING_FIELDS = ["name", "primaryMuscle", "quickTip"];
const REQUIRED_ARRAY_FIELDS = [
  "secondaryMuscles",
  "equipment",
  "instructions",
  "commonMistakes",
];

export function validateExercise(entry, sourceFile) {
  const errors = [];
  const where = `${sourceFile} / "${entry.name ?? "(no name)"}"`;

  for (const field of REQUIRED_STRING_FIELDS) {
    if (typeof entry[field] !== "string" || entry[field].trim() === "") {
      errors.push(`${where}: missing/empty required string field "${field}"`);
    }
  }

  for (const field of REQUIRED_ARRAY_FIELDS) {
    if (!Array.isArray(entry[field])) {
      errors.push(`${where}: field "${field}" must be an array`);
    }
  }

  if (Array.isArray(entry.instructions) && entry.instructions.length < 2) {
    errors.push(`${where}: "instructions" should have at least 2 steps`);
  }

  if (!MUSCLES.includes(entry.primaryMuscle)) {
    errors.push(`${where}: primaryMuscle "${entry.primaryMuscle}" not in enum`);
  }

  if (Array.isArray(entry.secondaryMuscles)) {
    for (const m of entry.secondaryMuscles) {
      if (!MUSCLES.includes(m)) {
        errors.push(`${where}: secondaryMuscles contains invalid value "${m}"`);
      }
    }
    if (entry.secondaryMuscles.includes(entry.primaryMuscle)) {
      errors.push(`${where}: secondaryMuscles duplicates primaryMuscle`);
    }
  }

  if (Array.isArray(entry.equipment)) {
    if (entry.equipment.length === 0) {
      errors.push(`${where}: equipment must not be empty (use "khong_dung_cu" if none)`);
    }
    for (const eq of entry.equipment) {
      if (!EQUIPMENT.includes(eq)) {
        errors.push(`${where}: equipment contains invalid value "${eq}"`);
      }
    }
  }

  if (!DIFFICULTIES.includes(entry.difficulty)) {
    errors.push(`${where}: difficulty "${entry.difficulty}" not in enum`);
  }

  if (
    typeof entry.suggestedRestSeconds !== "number" ||
    !Number.isFinite(entry.suggestedRestSeconds) ||
    entry.suggestedRestSeconds <= 0
  ) {
    errors.push(`${where}: suggestedRestSeconds must be a positive number`);
  }

  return errors;
}

export function slugify(name, id) {
  if (id) return id;
  return name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/đ/g, "d")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/(^-|-$)/g, "");
}
