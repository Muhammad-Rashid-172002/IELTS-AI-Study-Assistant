"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");

const projectId = "ielts-ai-master-phase1-test";
let environment;

test.before(async () => {
  environment = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "..", "firestore.rules"),
          "utf8",
      ),
    },
    storage: {
      rules: fs.readFileSync(
          path.join(__dirname, "..", "..", "storage.rules"),
          "utf8",
      ),
    },
  });
});

test.after(async () => {
  await environment?.cleanup();
});

async function seed() {
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc("users/learner").set({
      role: "student",
      accountStatus: "active",
      currentBand: null,
    });
    await db.doc("users/other").set({role: "student"});
    await db.doc("admins/admin").set({role: "admin", isAdmin: true});
    await db.doc("mock_test_bank/academic/listening/published").set({
      status: "published",
      correctAnswers: ["A"],
    });
    await db.doc("mock_test_bank/academic/listening/draft").set({
      status: "draft",
      correctAnswers: ["SECRET"],
    });
    await db.doc("users/learner/mock_attempts/attempt").set({
      attemptId: "attempt",
      userId: "learner",
      status: "in_progress",
    });
    await db.doc("users/learner/mock_attempts/submitted_attempt").set({
      attemptId: "submitted_attempt",
      userId: "learner",
      status: "submitted",
    });
    await db.doc("subscription_requests/request").set({
      userId: "learner",
      status: "pending",
    });
    await db.doc("diagnostic_tests/published").set({
      status: "published",
      isPublished: true,
      title: "Reviewed content",
      correctAnswers: ["A"],
    });
  });
}

test("unauthenticated clients cannot access learner or assessment data", async () => {
  await environment.clearFirestore();
  await seed();
  const db = environment.unauthenticatedContext().firestore();
  await assertFails(db.doc("users/learner").get());
  await assertFails(
      db.doc("mock_test_bank/academic/listening/published").get(),
  );
});

test("learner cannot forge scores, results, certificates, or subscriptions", async () => {
  await environment.clearFirestore();
  await seed();
  const db = environment.authenticatedContext("learner").firestore();
  await assertFails(db.doc("users/learner").update({currentBand: 9}));
  await assertFails(
      db.doc("users/learner/diagnostic_results/forged").set({
        overallBand: 9,
        serverAttested: true,
      }),
  );
  await assertFails(
      db.doc("users/learner/certificates/forged").set({status: "valid"}),
  );
  await assertFails(
      db.doc("subscription_requests/request").update({status: "approved"}),
  );
});

test("nested mock bank exposes published content but not drafts", async () => {
  await environment.clearFirestore();
  await seed();
  const learner = environment.authenticatedContext("learner").firestore();
  await assertSucceeds(
      learner.doc("mock_test_bank/academic/listening/published").get(),
  );
  await assertFails(
      learner.doc("mock_test_bank/academic/listening/draft").get(),
  );
});

test("mock answers and jobs are owner-scoped", async () => {
  await environment.clearFirestore();
  await seed();
  const learner = environment.authenticatedContext("learner").firestore();
  const other = environment.authenticatedContext("other").firestore();
  const answer = learner.doc(
      "users/learner/mock_attempts/attempt/answers/listening_q1",
  );
  await assertSucceeds(answer.set({
    attemptId: "attempt",
    questionId: "q1",
    skill: "listening",
    value: "A",
  }));
  await assertFails(answer.update({questionId: "changed"}));
  await assertFails(other.doc(answer.path).get());
  await assertSucceeds(learner.collection("mock_evaluation_jobs").add({
    attemptId: "submitted_attempt",
    userId: "learner",
    status: "queued",
  }));
  await assertFails(other.collection("mock_evaluation_jobs").add({
    attemptId: "submitted_attempt",
    userId: "learner",
    status: "queued",
  }));
});

test("admin can manage QA content but cannot bypass subscription callable", async () => {
  await environment.clearFirestore();
  await seed();
  const admin = environment.authenticatedContext("admin").firestore();
  await assertSucceeds(
      admin.doc("diagnostic_tests/new").set({status: "draft"}),
  );
  await assertFails(
      admin.doc("diagnostic_tests/new").update({
        status: "published",
        isPublished: true,
      }),
  );
  await assertSucceeds(
      admin.doc("diagnostic_tests/new").update({title: "Editable draft"}),
  );
  await assertFails(
      admin.doc("subscription_requests/request").update({status: "approved"}),
  );
});

test("published content cannot be materially edited without returning to draft", async () => {
  await environment.clearFirestore();
  await seed();
  const admin = environment.authenticatedContext("admin").firestore();
  await assertFails(
      admin.doc("diagnostic_tests/published").update({
        title: "Changed after publication",
      }),
  );
  await assertFails(
      admin.doc("diagnostic_tests/published").update({
        correctAnswers: ["FORGED"],
      }),
  );
  await assertSucceeds(
      admin.doc("diagnostic_tests/new").set({
        status: "draft",
        isPublished: false,
        title: "Draft",
      }),
  );
  await assertSucceeds(
      admin.doc("diagnostic_tests/new").update({title: "Edited draft"}),
  );
});

test("certificate registry is server-only even for authenticated admins", async () => {
  await environment.clearFirestore();
  await seed();
  const admin = environment.authenticatedContext("admin").firestore();
  const registry = admin.doc("certificate_verifications/IAM-2026-ABCDEF1234");
  await assertFails(registry.set({status: "valid", userName: "Forged"}));
  await assertFails(registry.get());
});

test("ordinary speaking submissions require the owner's exact audio path", async () => {
  await environment.clearFirestore();
  await seed();
  const learner = environment.authenticatedContext("learner").firestore();
  await assertSucceeds(learner.doc("speaking_submissions/owned").set({
    submissionId: "owned",
    userId: "learner",
    audioStoragePath: "speaking_recordings/learner/owned.m4a",
    status: "queued",
  }));
  await assertFails(learner.doc("speaking_submissions/cross_user").set({
    submissionId: "cross_user",
    userId: "learner",
    audioStoragePath: "speaking_recordings/other/cross_user.m4a",
    status: "queued",
  }));
  await assertFails(learner.doc("speaking_submissions/forged").set({
    submissionId: "forged",
    userId: "learner",
    audioStoragePath: "speaking_recordings/learner/forged.m4a",
    status: "queued",
    report: {estimatedOverallBand: 9},
  }));
});

test("diagnostic speaking uploads are owner-scoped and audio-only", async () => {
  const learner = environment.authenticatedContext("learner").storage();
  const other = environment.authenticatedContext("other").storage();
  const own = learner.ref(
      "diagnostic_speaking/learner/test/answer.m4a",
  );
  await assertSucceeds(own.putString("audio", "raw", {contentType: "audio/mp4"}));
  await assertFails(
      other.ref("diagnostic_speaking/learner/test/other.m4a")
          .putString("audio", "raw", {contentType: "audio/mp4"}),
  );
  await assertFails(
      learner.ref("diagnostic_speaking/learner/test/file.txt")
          .putString("text", "raw", {contentType: "text/plain"}),
  );
});

test("profile images are owner-scoped, image-only, and deletion-lock aware", async () => {
  const learner = environment.authenticatedContext("learner").storage();
  const other = environment.authenticatedContext("other").storage();
  const own = learner.ref("profile_images/learner.jpg");
  await assertSucceeds(
      own.putString("image", "raw", {contentType: "image/jpeg"}),
  );
  await assertSucceeds(own.getMetadata());
  await assertFails(other.ref("profile_images/learner.jpg").getMetadata());
  await assertFails(
      other.ref("profile_images/learner.jpg")
          .putString("image", "raw", {contentType: "image/jpeg"}),
  );
  await assertFails(
      learner.ref("profile_images/learner.png")
          .putString("image", "raw", {contentType: "image/png"}),
  );

  await environment.withSecurityRulesDisabled(async (context) => {
    await context.firestore().doc("account_deletion_locks/learner").set({
      status: "in_progress",
    });
  });
  await assertFails(
      learner.ref("speaking_recordings/learner/locked.m4a")
          .putString("audio", "raw", {contentType: "audio/mp4"}),
  );
  await assertFails(
      environment.authenticatedContext("learner").firestore()
          .doc("users/learner/saved_words/locked")
          .set({word: "blocked"}),
  );
});
