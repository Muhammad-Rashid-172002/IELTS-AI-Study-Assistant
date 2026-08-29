"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  calculateServerStreak,
  diagnosticScoreToBand,
  hasPlatformAdminAccess,
  isServerAttestedCompleteAssessment,
  mockSkillIsComplete,
  roundDiagnosticOverallBand,
} = require("../phase1_security");

test("server streak uses server day boundaries and is idempotent", () => {
  assert.deepEqual(calculateServerStreak({
    lastActiveDate: "2026-08-28",
    today: "2026-08-29",
    yesterday: "2026-08-28",
    currentStreak: 6,
    longestStreak: 10,
  }), {changed: true, current: 7, longest: 10});
  assert.deepEqual(calculateServerStreak({
    lastActiveDate: "2026-08-29",
    today: "2026-08-29",
    yesterday: "2026-08-28",
    currentStreak: 7,
    longestStreak: 10,
  }), {changed: false, current: 7, longest: 10});
});

test("privileged callables distinguish learners from platform admins", () => {
  assert.equal(hasPlatformAdminAccess({role: "student"}, {}), false);
  assert.equal(hasPlatformAdminAccess({}, {role: "admin"}), true);
  assert.equal(hasPlatformAdminAccess({admin: true}, {}), true);
});

test("diagnostic scoring preserves the released conversion and rounding", () => {
  assert.equal(diagnosticScoreToBand(37, 40), 8.5);
  assert.equal(diagnosticScoreToBand(0, 0), 0);
  assert.equal(roundDiagnosticOverallBand(6.24), 6);
  assert.equal(roundDiagnosticOverallBand(6.25), 6.5);
  assert.equal(roundDiagnosticOverallBand(6.75), 7);
});

test("certificate integrity rejects forged and incomplete results", () => {
  const complete = {
    serverAttested: true,
    isComplete: true,
    overallBand: 7,
    completedSkills: ["listening", "reading", "writing", "speaking"],
  };
  assert.equal(isServerAttestedCompleteAssessment(complete), true);
  assert.equal(
      isServerAttestedCompleteAssessment({...complete, serverAttested: false}),
      false,
  );
  assert.equal(
      isServerAttestedCompleteAssessment({
        ...complete,
        completedSkills: ["listening", "reading", "writing"],
      }),
      false,
  );
});

test("full mock speaking requires three owned audio answer records", () => {
  const audioAnswer = (index) => ({
    value: {
      audioStoragePath: `speaking_recordings/user/attempt_${index}.m4a`,
    },
  });
  const base = {
    skill: "speaking",
    attempt: {skillTimeSpent: {speaking: 120}},
    result: {band: 6.5},
  };
  assert.equal(
      mockSkillIsComplete({...base, answers: [0, 1, 2].map(audioAnswer)}),
      true,
  );
  assert.equal(
      mockSkillIsComplete({...base, answers: [0, 1].map(audioAnswer)}),
      false,
  );
});
