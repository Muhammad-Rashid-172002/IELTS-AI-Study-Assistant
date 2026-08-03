const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {logger} = require("firebase-functions");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const db = getFirestore();

exports.askAiCoach = onCall(
    {
      region: "us-central1",
      secrets: [geminiApiKey],
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be signed in.",
        );
      }

      const uid = request.auth.uid;
      const message = String(request.data?.message || "").trim();

      if (!message) {
        throw new HttpsError(
            "invalid-argument",
            "Message is required.",
        );
      }

      const profile = await buildAiCoachProfile(uid);
      const history = await loadRecentCoachMessages(uid);

      const prompt = buildAiCoachPrompt({
        message,
        profile,
        history,
      });

      const response = await callGeminiCoach(prompt);
      const assistantRef = db
          .collection("users")
          .doc(uid)
          .collection("ai_coach_messages")
          .doc();

      await assistantRef.set({
        messageId: assistantRef.id,
        role: "assistant",
        text: response.text,
        intent: response.intent,
        suggestions: response.suggestions,
        profileSnapshot: profile,
        createdAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        messageId: assistantRef.id,
      };
    },
);

exports.refreshAiCoachProfile = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 120,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be signed in.",
        );
      }

      const profile = await buildAiCoachProfile(
          request.auth.uid,
      );

      await db
          .collection("users")
          .doc(request.auth.uid)
          .collection("ai_coach")
          .doc("profile")
          .set({
            ...profile,
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});

      return {success: true, profile};
    },
);

async function buildAiCoachProfile(uid) {
  const userRef = db.collection("users").doc(uid);

  const [
    userDoc,
    listening,
    reading,
    writing,
    speaking,
    mockAttempts,
    lessonProgress,
  ] = await Promise.all([
    userRef.get(),
    userRef.collection("listening_results")
        .orderBy("timestamp", "desc")
        .limit(20)
        .get(),
    userRef.collection("reading_results")
        .orderBy("timestamp", "desc")
        .limit(20)
        .get(),
    userRef.collection("writing_results")
        .orderBy("timestamp", "desc")
        .limit(20)
        .get(),
    userRef.collection("speaking")
        .orderBy("timestamp", "desc")
        .limit(20)
        .get(),
    userRef.collection("mock_attempts")
        .orderBy("startedAt", "desc")
        .limit(10)
        .get(),
    userRef.collection("lesson_progress")
        .where("completed", "==", true)
        .get(),
  ]);

  const user = userDoc.data() || {};

  const skillBands = {
    listening: averageBand(listening.docs),
    reading: averageBand(reading.docs),
    writing: averageBand(writing.docs),
    speaking: averageBand(speaking.docs),
  };

  const sorted = Object.entries(skillBands)
      .sort((a, b) => a[1] - b[1]);

  const validBands = Object.values(skillBands)
      .filter((value) => value > 0);

  const overallBand = validBands.length > 0 ?
    roundBand(
        validBands.reduce((sum, value) => sum + value, 0) /
        validBands.length,
    ) :
    0;

  const weakQuestionTypes = {
    listening: collectWeakTypes(listening.docs),
    reading: collectWeakTypes(reading.docs),
  };

  const profile = {
    overallBand,
    targetBand: Number(user.targetBand || 7),
    streak: Number(user.streak || 0),
    weakestSkill: capitalize(
        sorted[0]?.[0] || "reading",
    ),
    strongestSkill: capitalize(
        sorted[sorted.length - 1]?.[0] || "listening",
    ),
    skillBands,
    weakQuestionTypes,
    completedLessons: lessonProgress.size,
    completedPractice:
      listening.size + reading.size + writing.size + speaking.size,
    completedMocks: mockAttempts.docs.filter(
        (doc) => doc.data().status === "completed",
    ).length,
  };

  await userRef
      .collection("ai_coach")
      .doc("profile")
      .set({
        ...profile,
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

  return profile;
}

function averageBand(docs) {
  const values = docs
      .map((doc) => {
        const data = doc.data();
        return Number(
            data.band ||
            data.overallBand ||
            data.estimatedBand ||
            0,
        );
      })
      .filter((value) => value > 0);

  if (values.length === 0) return 0;

  return roundBand(
      values.reduce((sum, value) => sum + value, 0) /
      values.length,
  );
}

function collectWeakTypes(docs) {
  const stats = {};

  for (const doc of docs) {
    const data = doc.data();
    const performance = data.questionTypePerformance;

    if (!performance || typeof performance !== "object") {
      continue;
    }

    for (const [type, value] of Object.entries(performance)) {
      const accuracy = Number(
          typeof value === "object" ?
            value.accuracy :
            value,
      );

      if (!stats[type]) {
        stats[type] = {
          totalAccuracy: 0,
          count: 0,
        };
      }

      stats[type].totalAccuracy += accuracy;
      stats[type].count++;
    }
  }

  return Object.entries(stats)
      .map(([type, value]) => ({
        type,
        accuracy: value.count > 0 ?
          Number(
              (value.totalAccuracy / value.count).toFixed(1),
          ) :
          0,
      }))
      .sort((a, b) => a.accuracy - b.accuracy)
      .slice(0, 5);
}

async function loadRecentCoachMessages(uid) {
  const snapshot = await db
      .collection("users")
      .doc(uid)
      .collection("ai_coach_messages")
      .orderBy("createdAt", "desc")
      .limit(12)
      .get();

  return snapshot.docs
      .map((doc) => doc.data())
      .reverse()
      .map((message) => ({
        role: message.role,
        text: message.text,
      }));
}

function buildAiCoachPrompt({
  message,
  profile,
  history,
}) {
  return `
You are an expert IELTS AI Coach. You are not a generic chatbot.

USER PROGRESS PROFILE
${JSON.stringify(profile, null, 2)}

RECENT CONVERSATION
${JSON.stringify(history, null, 2)}

CURRENT USER MESSAGE
${message}

CAPABILITIES
- Daily study recommendations
- Explain wrong answers
- Generate targeted practice
- Create study plans
- Explain Writing feedback
- Explain Speaking feedback
- Vocabulary practice
- Motivation
- Exam strategy
- Weekly progress review
- Weakness detection

RULES
1. Use the real progress profile in every relevant answer.
2. Mention the user's weakest skill or weak question type when useful.
3. Give specific and actionable advice.
4. Do not claim an official IELTS score.
5. Keep the answer supportive but honest.
6. When asked for a study plan, include duration and daily tasks.
7. When explaining an incorrect answer, explain:
   - why the chosen answer is wrong
   - why the correct answer is right
   - the rule or evidence
   - one prevention tip
8. Return JSON only.

Return:
{
  "intent": "daily_recommendation",
  "text": "Detailed answer",
  "suggestions": [
    "Start Reading Practice",
    "Review True/False/Not Given"
  ]
}
`;
}

async function callGeminiCoach(prompt) {
  const {GoogleGenAI} = await import("@google/genai");
  const ai = new GoogleGenAI({
    apiKey: geminiApiKey.value(),
  });

  const models = [
    "gemini-3.5-flash",
    "gemini-3.6-flash",
    "gemini-3.1-flash-lite",
  ];

  let lastError;

  for (const model of models) {
    try {
      const result = await ai.models.generateContent({
        model,
        contents: prompt,
        config: {
          temperature: 0.35,
          maxOutputTokens: 5000,
          responseMimeType: "application/json",
        },
      });

      const raw = String(result.text || "")
          .replace(/```json/gi, "")
          .replace(/```/g, "")
          .trim();

      const parsed = JSON.parse(raw);

      return {
        intent: String(parsed.intent || "general"),
        text: String(parsed.text || "No response generated."),
        suggestions: Array.isArray(parsed.suggestions) ?
          parsed.suggestions
              .map((item) => String(item))
              .slice(0, 4) :
          [],
      };
    } catch (error) {
      lastError = error;
      logger.warn("AI Coach model failed; switching model.", {
        model,
        error: String(error),
      });
    }
  }

  throw new HttpsError(
      "resource-exhausted",
      "AI Coach is temporarily unavailable. Please try again shortly.",
      String(lastError),
  );
}

function roundBand(value) {
  return Math.round(Number(value || 0) * 2) / 2;
}

function capitalize(value) {
  const text = String(value || "");
  return text.charAt(0).toUpperCase() + text.slice(1);
}
