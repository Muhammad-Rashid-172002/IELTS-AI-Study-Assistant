"use strict";

const assert = require("node:assert/strict");
const test = require("node:test");
const {
  deletionSubjectHash,
  mobileReleaseDecision,
  ownedSpeakingAudioPath,
} = require("../phase3_security");

test("Speaking evaluation accepts only the submission owner's exact path", () => {
  const valid = ownedSpeakingAudioPath({
    userId: "learner-a",
    submissionId: "submission-1",
    storagePath: "speaking_recordings/learner-a/submission-1.m4a",
  });
  assert.equal(valid, "speaking_recordings/learner-a/submission-1.m4a");
  assert.equal(ownedSpeakingAudioPath({
    userId: "learner-a",
    submissionId: "submission-1",
    storagePath: "speaking_recordings/learner-b/submission-1.m4a",
  }), "");
  assert.equal(ownedSpeakingAudioPath({
    userId: "learner-a",
    submissionId: "submission-1",
    storagePath: "speaking_recordings/learner-a/other.m4a",
  }), "");
});

test("minimum mobile build enforcement is platform-specific and opt-in", () => {
  assert.deepEqual(mobileReleaseDecision({
    platform: "android",
    buildNumber: 14,
    minimumAndroidBuild: 15,
    minimumIosBuild: 20,
    enforcementEnabled: true,
  }), {
    supportedPlatform: true,
    minimumBuildNumber: 15,
    updateRequired: true,
  });
  assert.equal(mobileReleaseDecision({
    platform: "ios",
    buildNumber: 19,
    minimumAndroidBuild: 15,
    minimumIosBuild: 20,
    enforcementEnabled: false,
  }).updateRequired, false);
  assert.equal(mobileReleaseDecision({
    platform: "web",
    buildNumber: 1,
    minimumAndroidBuild: 15,
    minimumIosBuild: 20,
    enforcementEnabled: true,
  }).supportedPlatform, false);
});

test("account-deletion audit identity is deterministic and non-plaintext", () => {
  const first = deletionSubjectHash("learner-a");
  assert.equal(first, deletionSubjectHash("learner-a"));
  assert.notEqual(first, deletionSubjectHash("learner-b"));
  assert.equal(first.length, 64);
  assert.equal(first.includes("learner-a"), false);
});
