"use strict";

const crypto = require("crypto");

const SUPPORTED_MOBILE_PLATFORMS = new Set(["android", "ios"]);

function ownedSpeakingAudioPath({userId, submissionId, storagePath}) {
  const uid = String(userId || "").trim();
  const id = String(submissionId || "").trim();
  const path = String(storagePath || "").trim();
  if (!uid || !id || !path) return "";
  const expected = `speaking_recordings/${uid}/${id}.m4a`;
  return path === expected ? path : "";
}

function normalizeBuildNumber(value) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) return 0;
  return parsed;
}

function mobileReleaseDecision({
  platform,
  buildNumber,
  minimumAndroidBuild,
  minimumIosBuild,
  enforcementEnabled,
}) {
  const normalizedPlatform = String(platform || "").trim().toLowerCase();
  if (!SUPPORTED_MOBILE_PLATFORMS.has(normalizedPlatform)) {
    return {
      supportedPlatform: false,
      minimumBuildNumber: 0,
      updateRequired: false,
    };
  }
  const clientBuild = normalizeBuildNumber(buildNumber);
  const minimumBuild = normalizeBuildNumber(
      normalizedPlatform === "android" ?
        minimumAndroidBuild : minimumIosBuild,
  );
  return {
    supportedPlatform: true,
    minimumBuildNumber: minimumBuild,
    updateRequired: enforcementEnabled === true &&
      minimumBuild > 0 && clientBuild < minimumBuild,
  };
}

function deletionSubjectHash(uid) {
  return crypto.createHash("sha256")
      .update(`account-deletion-v1|${String(uid || "").trim()}`)
      .digest("hex");
}

module.exports = {
  deletionSubjectHash,
  mobileReleaseDecision,
  normalizeBuildNumber,
  ownedSpeakingAudioPath,
};
