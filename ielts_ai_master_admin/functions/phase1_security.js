"use strict";

function certificateNumber(value) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}

function hasPlatformAdminAccess(token = {}, record = {}) {
  const tokenRole = String(token.role || "").toLowerCase();
  const storedRole = String(record.role || "").toLowerCase();
  return token.admin === true ||
    tokenRole === "admin" ||
    tokenRole === "super_admin" ||
    record.isAdmin === true ||
    storedRole === "admin" ||
    storedRole === "super_admin";
}

function calculateServerStreak({
  lastActiveDate,
  today,
  yesterday,
  currentStreak,
  longestStreak,
}) {
  const current = Math.max(0, Number(currentStreak || 0));
  const longest = Math.max(0, Number(longestStreak || 0));
  if (lastActiveDate === today) {
    return {changed: false, current, longest};
  }
  const next = lastActiveDate === yesterday ? current + 1 : 1;
  return {changed: true, current: next, longest: Math.max(longest, next)};
}

function isServerAttestedCompleteAssessment(data) {
  const required = ["listening", "reading", "writing", "speaking"];
  const completed = Array.isArray(data?.completedSkills) ?
    data.completedSkills.map((value) => String(value).toLowerCase()) : [];
  return data?.serverAttested === true &&
    data?.isComplete === true &&
    required.every((skill) => completed.includes(skill)) &&
    certificateNumber(data?.overallBand ?? data?.estimatedBand) > 0;
}

function diagnosticScoreToBand(correct, total) {
  if (total <= 0) return 0;
  const ratio = correct / total;
  if (ratio >= .975) return 9;
  if (ratio >= .925) return 8.5;
  if (ratio >= .875) return 8;
  if (ratio >= .80) return 7.5;
  if (ratio >= .725) return 7;
  if (ratio >= .65) return 6.5;
  if (ratio >= .575) return 6;
  if (ratio >= .50) return 5.5;
  if (ratio >= .425) return 5;
  if (ratio >= .35) return 4.5;
  return 4;
}

function roundDiagnosticOverallBand(value) {
  const whole = Math.floor(value);
  const fraction = value - whole;
  if (fraction < .25) return whole;
  if (fraction < .75) return whole + .5;
  return whole + 1;
}

function mockSkillIsComplete({skill, answers, attempt, result}) {
  if (!result || !Object.prototype.hasOwnProperty.call(
      attempt.skillTimeSpent || {},
      skill,
  )) return false;

  if (skill === "listening" || skill === "reading") return true;
  if (skill === "writing") {
    return answers.length >= 2 && answers.every(
        (answer) => String(answer.value || "").trim().length >= 20,
    ) && Number(result.band || 0) > 0;
  }
  if (skill === "speaking") {
    return answers.length >= 3 && answers.every((answer) => {
      const value = answer.value;
      return value && typeof value === "object" &&
        String(value.audioStoragePath || "").trim().length > 0;
    }) && Number(result.band || 0) > 0;
  }
  return false;
}

module.exports = {
  calculateServerStreak,
  certificateNumber,
  diagnosticScoreToBand,
  hasPlatformAdminAccess,
  isServerAttestedCompleteAssessment,
  mockSkillIsComplete,
  roundDiagnosticOverallBand,
};
