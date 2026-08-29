"use strict";

const SCORING_VERSION = "estimated_ielts_v3_2026_08";
const OBJECTIVE_CONVERSION_VERSION = "practice_raw40_v2_2026_08";
const CONTENT_SCHEMA_VERSION = 2;
const CREDENTIAL_SCHEMA_VERSION = 2;

const WRITING_TASK_1_ALIASES = new Set([
  "task_1",
  "task1",
  "academic_task_1",
  "general_task_1",
  "academic task 1",
  "general training task 1",
  "letter",
  "report",
]);

const SCORE_TABLES = {
  listening: [
    [39, 9], [37, 8.5], [35, 8], [32, 7.5], [30, 7], [26, 6.5],
    [23, 6], [18, 5.5], [16, 5], [13, 4.5], [11, 4], [8, 3.5],
    [6, 3], [4, 2.5], [0, 0],
  ],
  reading_academic: [
    [39, 9], [37, 8.5], [35, 8], [33, 7.5], [30, 7], [27, 6.5],
    [23, 6], [19, 5.5], [15, 5], [13, 4.5], [10, 4], [8, 3.5],
    [6, 3], [4, 2.5], [0, 0],
  ],
  reading_general: [
    [40, 9], [39, 8.5], [37, 8], [36, 7.5], [34, 7], [32, 6.5],
    [30, 6], [27, 5.5], [23, 5], [19, 4.5], [15, 4], [12, 3.5],
    [9, 3], [6, 2.5], [0, 0],
  ],
};

function finiteNumber(value, fallback = 0) {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeCriterionBand(value) {
  const number = finiteNumber(value, 0);
  if (number <= 0) return 0;
  return Math.max(0, Math.min(9, Math.round(number * 2) / 2));
}

function roundIeltsOverallBand(value) {
  const number = Math.max(0, Math.min(9, finiteNumber(value, 0)));
  const whole = Math.floor(number);
  const fraction = number - whole;
  if (fraction < .25) return whole;
  if (fraction < .75) return Math.min(9, whole + .5);
  return Math.min(9, whole + 1);
}

function calculateCriterionOverall(values) {
  const scores = values.map(normalizeCriterionBand);
  if (scores.length !== 4 || scores.some((score) => score <= 0)) return 0;
  return roundIeltsOverallBand(
      scores.reduce((sum, score) => sum + score, 0) / scores.length,
  );
}

function normalizedTaskKind(value) {
  const normalized = String(value || "")
      .trim()
      .toLowerCase()
      .replace(/-/g, "_")
      .replace(/\s+/g, " ");
  if (WRITING_TASK_1_ALIASES.has(normalized) ||
      normalized.includes("task 1") ||
      normalized.includes("task_1")) {
    return "task_1";
  }
  return "task_2";
}

function criterionBand(value) {
  if (value && typeof value === "object") {
    return normalizeCriterionBand(value.band ?? value.score);
  }
  return normalizeCriterionBand(value);
}

function writingScoring(raw = {}, taskType) {
  const kind = normalizedTaskKind(taskType);
  const taskSource = kind === "task_1" ?
    raw.taskAchievement ?? raw.taskResponse ?? raw.taskCriterion :
    raw.taskResponse ?? raw.taskAchievement ?? raw.taskCriterion;
  const criteria = {
    task: criterionBand(taskSource),
    coherenceAndCohesion: criterionBand(
        raw.coherenceAndCohesion ?? raw.coherenceCohesion ?? raw.coherence,
    ),
    lexicalResource: criterionBand(
        raw.lexicalResource ?? raw.lexical ?? raw.vocabulary,
    ),
    grammaticalRangeAndAccuracy: criterionBand(
        raw.grammaticalRangeAndAccuracy ??
        raw.grammarAccuracy ??
        raw.grammarBand ??
        raw.grammar,
    ),
  };
  return {
    taskKind: kind,
    taskCriterionName: kind === "task_1" ?
      "Task Achievement" : "Task Response",
    criteria,
    estimatedOverallBand: calculateCriterionOverall(Object.values(criteria)),
    modelProvidedOverallBand: normalizeCriterionBand(
        raw.modelProvidedOverallBand ?? raw.overallBand,
    ),
    scoringVersion: SCORING_VERSION,
  };
}

function speakingScoring(raw = {}) {
  const criteria = {
    fluencyAndCoherence: criterionBand(
        raw.fluencyAndCoherence ?? raw.fluencyCoherence ?? raw.fluencyBand,
    ),
    lexicalResource: criterionBand(
        raw.lexicalResource ?? raw.lexicalBand ?? raw.vocabulary,
    ),
    grammaticalRangeAndAccuracy: criterionBand(
        raw.grammaticalRangeAndAccuracy ??
        raw.grammarAccuracy ??
        raw.grammarBand ??
        raw.grammar,
    ),
    pronunciation: criterionBand(
        raw.pronunciation ?? raw.pronunciationBand,
    ),
  };
  return {
    criteria,
    estimatedOverallBand: calculateCriterionOverall(Object.values(criteria)),
    modelProvidedOverallBand: normalizeCriterionBand(
        raw.modelProvidedOverallBand ?? raw.overallBand,
    ),
    scoringVersion: SCORING_VERSION,
  };
}

function normalizeIeltsTrack(value) {
  const normalized = String(value || "academic").trim().toLowerCase();
  return normalized.includes("general") ? "general_training" : "academic";
}

function convertObjectiveScore({skill, track, rawScore, maximumScore}) {
  const maximum = Math.round(finiteNumber(maximumScore, 0));
  const raw = Math.round(finiteNumber(rawScore, 0));
  if (maximum <= 0 || raw < 0 || raw > maximum) {
    throw new RangeError("Raw score must be between zero and maximum score.");
  }
  const normalizedRawScore = Math.max(
      0,
      Math.min(40, Math.round((raw / maximum) * 40)),
  );
  const normalizedSkill = String(skill || "").toLowerCase();
  const normalizedTrack = normalizeIeltsTrack(track);
  const tableKey = normalizedSkill === "listening" ?
    "listening" :
    normalizedTrack === "general_training" ?
      "reading_general" : "reading_academic";
  const table = SCORE_TABLES[tableKey];
  const match = table.find(([minimum]) => normalizedRawScore >= minimum);
  return {
    ieltsTrack: normalizedTrack,
    rawScore: raw,
    maximumScore: maximum,
    normalizedRawScore,
    estimatedBand: match ? match[1] : 0,
    conversionTableVersion: OBJECTIVE_CONVERSION_VERSION,
  };
}

const QA_STATES = new Set([
  "draft",
  "validation_passed",
  "approved",
  "published",
  "archived",
]);

function canTransitionQaState(from, to) {
  const current = String(from || "draft").toLowerCase();
  const target = String(to || "").toLowerCase();
  if (!QA_STATES.has(target) || current === target) return false;
  if (target === "archived") return true;
  if (target === "draft") {
    return current === "validation_passed" ||
      current === "approved" ||
      current === "archived" ||
      current === "published";
  }
  if (current === "published" && target === "approved") return true;
  return (current === "draft" && target === "validation_passed") ||
    (current === "validation_passed" && target === "approved") ||
    (current === "approved" && target === "published");
}

function resolveCredentialStatus(value) {
  const status = String(value || "").trim().toLowerCase();
  return ["valid", "revoked"].includes(status) ? status : "unknown";
}

function credentialIsValid(value) {
  return resolveCredentialStatus(value) === "valid";
}

function certificateTypeEligible({credentialType, hasBand, completeSkills}) {
  const type = String(credentialType || "").toLowerCase();
  if (type === "practice_completion") return !hasBand;
  if (type !== "mock_assessment_report") return false;
  const completed = Array.isArray(completeSkills) ?
    completeSkills.map((value) => String(value).toLowerCase()) : [];
  return hasBand === true &&
    ["listening", "reading", "writing", "speaking"]
        .every((skill) => completed.includes(skill));
}

function canonicalVerificationUrl({storedUrl, code, origin}) {
  const stored = String(storedUrl || "").trim();
  if (/^https:\/\//i.test(stored)) return stored;
  const base = String(origin || "").trim().replace(/\/+$/, "");
  return `${base}/${encodeURIComponent(String(code || "").trim())}`;
}

function readSharedAliases(data = {}) {
  const targetBands = data.targetBands && typeof data.targetBands === "object" ?
    data.targetBands : {};
  return {
    name: String(data.fullName ?? data.name ?? "").trim(),
    phone: String(data.phoneNumber ?? data.phone ?? "").trim(),
    photoUrl: String(data.photoUrl ?? data.profileImage ?? "").trim(),
    targetBand: finiteNumber(targetBands.overall ?? data.targetBand, 0),
    taskScore: criterionBand(data.taskResponse ?? data.taskAchievement),
    speakingGrammar: criterionBand(
        data.grammaticalRangeAndAccuracy ??
        data.grammarAccuracy ??
        data.grammarBand,
    ),
  };
}

module.exports = {
  CONTENT_SCHEMA_VERSION,
  CREDENTIAL_SCHEMA_VERSION,
  OBJECTIVE_CONVERSION_VERSION,
  QA_STATES,
  SCORING_VERSION,
  calculateCriterionOverall,
  canTransitionQaState,
  canonicalVerificationUrl,
  certificateTypeEligible,
  convertObjectiveScore,
  credentialIsValid,
  normalizeCriterionBand,
  normalizeIeltsTrack,
  normalizedTaskKind,
  readSharedAliases,
  resolveCredentialStatus,
  roundIeltsOverallBand,
  speakingScoring,
  writingScoring,
};
