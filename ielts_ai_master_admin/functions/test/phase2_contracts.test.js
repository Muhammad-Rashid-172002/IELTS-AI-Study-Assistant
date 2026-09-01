"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");

const {
  SCORING_VERSION,
  canTransitionQaState,
  canonicalVerificationUrl,
  certificateTypeEligible,
  convertObjectiveScore,
  credentialIsValid,
  nextMockQuestionNumber,
  readSharedAliases,
  resolveCredentialStatus,
  roundIeltsOverallBand,
  speakingScoring,
  writingScoring,
} = require("../phase2_contracts");

test("mock question numbering continues after existing generated batches", () => {
  assert.equal(nextMockQuestionNumber([1, 1, 2, 9, "10"]), 11);
  assert.equal(nextMockQuestionNumber([]), 1);
  assert.equal(nextMockQuestionNumber([null, "invalid", 0]), 1);
});

test("Writing uses Task Achievement for Task 1 and Task Response for Task 2", () => {
  const task1 = writingScoring({
    taskAchievement: 6.5,
    coherenceAndCohesion: 7,
    lexicalResource: 6.5,
    grammaticalRangeAndAccuracy: 6,
    overallBand: 9,
  }, "academic_task_1");
  const task2 = writingScoring({
    taskResponse: 7,
    coherenceCohesion: 6.5,
    lexicalResource: 7,
    grammarAccuracy: 6.5,
    overallBand: 4,
  }, "task_2");

  assert.equal(task1.taskCriterionName, "Task Achievement");
  assert.equal(task2.taskCriterionName, "Task Response");
  assert.equal(task1.estimatedOverallBand, 6.5);
  assert.equal(task1.modelProvidedOverallBand, 9);
  assert.equal(task2.estimatedOverallBand, 7);
  assert.equal(task2.modelProvidedOverallBand, 4);
  assert.equal(task2.scoringVersion, SCORING_VERSION);
});

test("Speaking overall is deterministic and supports legacy grammar aliases", () => {
  const result = speakingScoring({
    fluencyCoherence: 6,
    lexicalBand: 6.5,
    grammarAccuracy: 7,
    pronunciationBand: 6.5,
    overallBand: 9,
  });
  assert.deepEqual(result.criteria, {
    fluencyAndCoherence: 6,
    lexicalResource: 6.5,
    grammaticalRangeAndAccuracy: 7,
    pronunciation: 6.5,
  });
  assert.equal(result.estimatedOverallBand, 6.5);
  assert.equal(result.modelProvidedOverallBand, 9);
});

test("IELTS-style overall rounding covers quarter and three-quarter boundaries", () => {
  assert.equal(roundIeltsOverallBand(6.24), 6);
  assert.equal(roundIeltsOverallBand(6.25), 6.5);
  assert.equal(roundIeltsOverallBand(6.74), 6.5);
  assert.equal(roundIeltsOverallBand(6.75), 7);
  assert.equal(roundIeltsOverallBand(8.75), 9);
});

test("Academic and General Training Reading use separate conversions", () => {
  const academic = convertObjectiveScore({
    skill: "reading",
    track: "Academic",
    rawScore: 30,
    maximumScore: 40,
  });
  const general = convertObjectiveScore({
    skill: "reading",
    track: "General Training",
    rawScore: 30,
    maximumScore: 40,
  });
  assert.equal(academic.estimatedBand, 7);
  assert.equal(general.estimatedBand, 6);
  assert.equal(general.ieltsTrack, "general_training");
  assert.throws(() => convertObjectiveScore({
    skill: "reading",
    track: "academic",
    rawScore: 41,
    maximumScore: 40,
  }), RangeError);
});

test("short practice tests normalize to an explicit raw mark out of 40", () => {
  const result = convertObjectiveScore({
    skill: "listening",
    track: "academic",
    rawScore: 8,
    maximumScore: 10,
  });
  assert.equal(result.rawScore, 8);
  assert.equal(result.maximumScore, 10);
  assert.equal(result.normalizedRawScore, 32);
  assert.equal(result.estimatedBand, 7.5);
});

test("QA state transitions cannot bypass validation or approval", () => {
  assert.equal(canTransitionQaState("draft", "validation_passed"), true);
  assert.equal(canTransitionQaState("draft", "approved"), false);
  assert.equal(canTransitionQaState("validation_passed", "published"), false);
  assert.equal(canTransitionQaState("approved", "published"), true);
  assert.equal(canTransitionQaState("validation_passed", "draft"), true);
  assert.equal(canTransitionQaState("approved", "draft"), true);
  assert.equal(canTransitionQaState("published", "approved"), true);
  assert.equal(canTransitionQaState("published", "draft"), true);
  assert.equal(canTransitionQaState("archived", "draft"), true);
});

test("credential type and lifecycle contracts reject unsafe states", () => {
  assert.equal(credentialIsValid("valid"), true);
  assert.equal(credentialIsValid("revoked"), false);
  assert.equal(credentialIsValid(undefined), false);
  assert.equal(resolveCredentialStatus(undefined), "unknown");
  assert.equal(certificateTypeEligible({
    credentialType: "practice_completion",
    hasBand: false,
  }), true);
  assert.equal(certificateTypeEligible({
    credentialType: "practice_completion",
    hasBand: true,
  }), false);
  assert.equal(certificateTypeEligible({
    credentialType: "mock_assessment_report",
    hasBand: true,
    completeSkills: ["listening", "reading", "writing", "speaking"],
  }), true);
});

test("canonical verification URLs preserve stored legacy URLs", () => {
  assert.equal(canonicalVerificationUrl({
    storedUrl: "https://legacy.example/verify/IAM-2026-ABC",
    code: "IAM-2026-ABC",
    origin: "https://new.example/verify",
  }), "https://legacy.example/verify/IAM-2026-ABC");
  assert.equal(canonicalVerificationUrl({
    code: "IAM-2026-ABC",
    origin: "https://new.example/verify/",
  }), "https://new.example/verify/IAM-2026-ABC");
});

test("shared aliases dual-read historical profile and scoring fields", () => {
  assert.deepEqual(readSharedAliases({
    name: "Legacy Learner",
    phone: "+1",
    profileImage: "https://example/image.png",
    targetBands: {overall: 7.5},
    taskAchievement: 6.5,
    grammarBand: 6,
  }), {
    name: "Legacy Learner",
    phone: "+1",
    photoUrl: "https://example/image.png",
    targetBand: 7.5,
    taskScore: 6.5,
    speakingGrammar: 6,
  });
});
