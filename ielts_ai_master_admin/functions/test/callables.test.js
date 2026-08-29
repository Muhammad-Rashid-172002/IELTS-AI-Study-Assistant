"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {getFirestore} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {getStorage} = require("firebase-admin/storage");
const functions = require("../index");

const learnerAuth = {
  uid: "callable_learner",
  token: {role: "student", email: "learner@example.test"},
};
const adminAuth = {
  uid: "callable_admin",
  token: {role: "admin", email: "admin@example.test"},
};
const app = {appId: "phase1-emulator-test"};

test.before(async () => {
  const db = getFirestore();
  await Promise.all([
    db.doc("users/callable_learner").set({
      role: "student",
      accountStatus: "active",
    }),
    db.doc("users/suspended_learner").set({
      role: "student",
      accountStatus: "suspended",
    }),
    db.doc("admins/callable_admin").set({
      role: "admin",
      isAdmin: true,
      email: "admin@example.test",
    }),
  ]);
});

function expectCode(promise, code) {
  return assert.rejects(promise, (error) => error?.code === code);
}

test("diagnostic generation denies unauthenticated and learner callers", async () => {
  await expectCode(
      functions.createDiagnosticGenerationJob.run({data: {}, app}),
      "unauthenticated",
  );
  await expectCode(
      functions.createDiagnosticGenerationJob.run({
        auth: learnerAuth,
        data: {},
        app,
      }),
      "permission-denied",
  );
});

test("subscription review denies a learner", async () => {
  await expectCode(
      functions.reviewSubscriptionRequest.run({
        auth: learnerAuth,
        data: {requestId: "anything", action: "approve"},
        app,
      }),
      "permission-denied",
  );
});

test("account deletion requires explicit confirmation and recent authentication", async () => {
  await expectCode(functions.deleteLearnerAccount.run({
    auth: learnerAuth,
    data: {confirmation: "NO"},
    app,
  }), "invalid-argument");
  await expectCode(functions.deleteLearnerAccount.run({
    auth: learnerAuth,
    data: {confirmation: "DELETE"},
    app,
  }), "failed-precondition");
});

test("suspended learner cannot use the authenticated AI proxy", async () => {
  await expectCode(
      functions.legacyAiAssist.run({
        auth: {uid: "suspended_learner", token: {role: "student"}},
        data: {purpose: "coach_text", prompt: "Safe test prompt"},
        app,
      }),
      "permission-denied",
  );
});

test("valid admin can create a diagnostic generation job", async () => {
  const response = await functions.createDiagnosticGenerationJob.run({
    auth: adminAuth,
    app,
    data: {
      title: "Phase 1 emulator diagnostic",
      ieltsType: "Academic",
      difficulty: "Intermediate",
      topic: "Education",
      listeningQuestionCount: 10,
      readingQuestionCount: 10,
      writingTaskType: "Task 2",
      speakingPromptCount: 3,
      durationMinutes: 30,
    },
  });
  assert.equal(response.success, true);
  assert.ok(response.jobId);
  assert.ok(response.testId);
});

test("valid admin atomically approves a subscription with an audit", async () => {
  const db = getFirestore();
  const requestId = "phase1_subscription_request";
  await db.doc(`subscription_requests/${requestId}`).set({
    requestId,
    userId: "callable_learner",
    status: "pending",
    planId: "monthly",
    planTitle: "Monthly Premium",
    amount: 1000,
    currency: "PKR",
    durationDays: 30,
  });
  const response = await functions.reviewSubscriptionRequest.run({
    auth: adminAuth,
    app,
    data: {requestId, action: "approve"},
  });
  assert.equal(response.success, true);
  assert.equal(response.status, "approved");

  const [request, user, audits] = await Promise.all([
    db.doc(`subscription_requests/${requestId}`).get(),
    db.doc("users/callable_learner").get(),
    db.collection("subscription_audit_logs")
        .where("requestId", "==", requestId)
        .get(),
  ]);
  assert.equal(request.data().status, "approved");
  assert.equal(user.data().subscriptionStatus, "active");
  assert.equal(audits.size, 1);
});

test("content QA requires validation and approval before publishing", async () => {
  const db = getFirestore();
  const path = "writing_tasks/phase2_qa_task";
  await db.doc(path).set({
    title: "Independent practice task",
    status: "draft",
    generatedBy: "gemini",
    generatedModel: "test-model",
    generationJobId: "job-1",
  });

  await expectCode(functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {documentPath: path, targetState: "published"},
  }), "failed-precondition");

  const validation = await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {documentPath: path, targetState: "validation_passed"},
  });
  assert.equal(validation.success, true);

  const approval = await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {
      documentPath: path,
      targetState: "approved",
      copyrightStatus: "ai_generated_reviewed",
    },
  });
  assert.equal(approval.state, "approved");

  const publication = await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {documentPath: path, targetState: "published"},
  });
  assert.equal(publication.state, "published");
  const content = await db.doc(path).get();
  assert.equal(content.data().validationStatus, "passed");
  assert.equal(content.data().status, "published");
  assert.equal(content.data().isPublished, true);
});

test("manually authored content can enter provenance before validation", async () => {
  const db = getFirestore();
  const path = "reading_tests/phase2_manual_provenance";
  await db.doc(path).set({
    title: "Original admin-authored practice passage",
    status: "draft",
    isPublished: false,
  });

  const validation = await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {
      documentPath: path,
      targetState: "validation_passed",
      sourceType: "admin_authored",
      sourceReference: "internal-original-content-brief-2026-08",
    },
  });
  assert.equal(validation.state, "validation_passed");

  await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {
      documentPath: path,
      targetState: "approved",
      copyrightStatus: "original_content_reviewed",
    },
  });
  await functions.transitionContentQaState.run({
    auth: adminAuth,
    app,
    data: {documentPath: path, targetState: "published"},
  });

  const content = (await db.doc(path).get()).data();
  assert.equal(content.sourceType, "admin_authored");
  assert.equal(
      content.sourceReference,
      "internal-original-content-brief-2026-08",
  );
  assert.equal(content.copyrightStatus, "original_content_reviewed");
  assert.equal(content.status, "published");
});

test("credential verification treats unknown status as invalid and preserves revoked records", async () => {
  const db = getFirestore();
  const verificationCode = "IAM-2026-ABCDEF1234";
  await db.doc(`certificate_verifications/${verificationCode}`).set({
    verificationCode,
    certificateId: "legacy-certificate",
    title: "Legacy Practice Credential",
    userName: "Legacy Learner",
  });

  const unknown = await functions.verifyCertificate.run({
    data: {verificationCode},
    rawRequest: {ip: "127.0.0.2", headers: {}},
  });
  assert.equal(unknown.found, true);
  assert.equal(unknown.certificate.status, "unknown");

  const update = await functions.updateCertificateStatus.run({
    auth: adminAuth,
    app,
    data: {
      verificationCode,
      status: "revoked",
      reason: "Issued record requires administrative review.",
    },
  });
  assert.equal(update.status, "revoked");

  const revoked = await functions.verifyCertificate.run({
    data: {verificationCode},
    rawRequest: {ip: "127.0.0.3", headers: {}},
  });
  assert.equal(revoked.certificate.status, "revoked");
  assert.match(revoked.certificate.revocationReason, /administrative review/);
});

test("server account deletion removes nested, top-level, registry, Storage, and Auth data", async () => {
  const uid = "phase3_delete_learner";
  const verificationCode = "IAM-2026-DELETE12345";
  const db = getFirestore();
  const auth = getAuth();
  const bucket = getStorage().bucket();
  await auth.createUser({uid, email: "delete@example.test"});
  await Promise.all([
    db.doc(`users/${uid}`).set({role: "student", email: "delete@example.test"}),
    db.doc(`users/${uid}/mock_attempts/attempt`).set({status: "completed"}),
    db.doc(`users/${uid}/mock_attempts/attempt/answers/q1`).set({value: "A"}),
    db.doc(`users/${uid}/private_billing/google_play`).set({tokenHash: "hash"}),
    db.doc(`users/${uid}/certificates/certificate`).set({verificationCode}),
    db.doc(`certificate_verifications/${verificationCode}`).set({
      verificationCode,
      certificatePath: `users/${uid}/certificates/certificate`,
      userName: "Delete Learner",
      status: "valid",
    }),
    db.doc("writing_submissions/delete_submission").set({userId: uid}),
    db.doc("subscription_requests/delete_request").set({userId: uid}),
    bucket.file(`profile_images/${uid}.jpg`).save(Buffer.from("image"), {
      contentType: "image/jpeg",
    }),
    bucket.file(`speaking_recordings/${uid}/answer.m4a`).save(
        Buffer.from("audio"),
        {contentType: "audio/mp4"},
    ),
  ]);

  const response = await functions.deleteLearnerAccount.run({
    auth: {
      uid,
      token: {
        role: "student",
        email: "delete@example.test",
        auth_time: Math.floor(Date.now() / 1000),
      },
    },
    data: {confirmation: "DELETE"},
    app,
  });
  assert.equal(response.success, true);

  const [
    user,
    nestedAnswer,
    writing,
    request,
    registry,
    audits,
    profileImage,
    speakingAudio,
  ] = await Promise.all([
    db.doc(`users/${uid}`).get(),
    db.doc(`users/${uid}/mock_attempts/attempt/answers/q1`).get(),
    db.doc("writing_submissions/delete_submission").get(),
    db.doc("subscription_requests/delete_request").get(),
    db.doc(`certificate_verifications/${verificationCode}`).get(),
    db.collection("account_deletion_audit").where("status", "==", "completed").get(),
    bucket.file(`profile_images/${uid}.jpg`).exists(),
    bucket.file(`speaking_recordings/${uid}/answer.m4a`).exists(),
  ]);
  assert.equal(user.exists, false);
  assert.equal(nestedAnswer.exists, false);
  assert.equal(writing.exists, false);
  assert.equal(request.exists, false);
  assert.equal(registry.exists, false);
  assert.ok(audits.size >= 1);
  assert.equal(profileImage[0], false);
  assert.equal(speakingAudio[0], false);
  await assert.rejects(
      auth.getUser(uid),
      (error) => error?.code === "auth/user-not-found",
  );
});
