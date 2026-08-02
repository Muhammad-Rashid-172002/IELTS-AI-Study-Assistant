const textToSpeech = require("@google-cloud/text-to-speech");
const {getStorage, getDownloadURL} =
  require("firebase-admin/storage");

const {setGlobalOptions} =
  require("firebase-functions/v2/options");

const {onDocumentCreated} =
  require("firebase-functions/v2/firestore");

const {defineSecret} =
  require("firebase-functions/params");

const logger =
  require("firebase-functions/logger");

const {initializeApp} =
  require("firebase-admin/app");

const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const storage = getStorage();
const bucket = storage.bucket();
const ttsClient = new textToSpeech.TextToSpeechClient();
const geminiApiKey = defineSecret("GEMINI_API_KEY");

const GEMINI_MODEL = "gemini-3.5-flash";
const TTS_LANGUAGE_CODE = "en-GB";
const TTS_SPEAKING_RATE = 0.92;
const MAX_TTS_CHARACTERS = 4500;

setGlobalOptions({
  region: "us-central1",
  maxInstances: 3,
  timeoutSeconds: 540,
  memory: "1GiB",
});

exports.processListeningGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;

      if (!snapshot) {
        logger.error("Generation job snapshot is missing.");
        return;
      }

      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;
      const job = snapshot.data();

      if (job.contentType !== "listening") {
        logger.info("Ignoring non-listening generation job.", {
          jobId,
          contentType: job.contentType,
        });
        return;
      }

      if (job.status !== "queued") {
        logger.info("Ignoring job because status is not queued.", {
          jobId,
          status: job.status,
        });
        return;
      }

      const requestedCount = clampNumber(
          job.requestedCount,
          1,
          10,
          1,
      );

      await jobRef.update({
        status: "generating",
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        generatedCount: 0,
        failedCount: 0,
        errorMessage: FieldValue.delete(),
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdTestIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");

        const ai = new GoogleGenAI({
          apiKey: geminiApiKey.value(),
        });

        for (let index = 0; index < requestedCount; index++) {
          try {
            logger.info("Generating listening test.", {
              jobId,
              testNumber: index + 1,
              requestedCount,
            });

            const generatedTest = await generateListeningTest({
              ai,
              job,
              sequenceNumber: index + 1,
            });

            const validation = validateListeningTest(
                generatedTest,
                job,
            );

            if (!validation.isValid) {
              throw new Error(
                  `Validation failed: ${validation.errors.join(" | ")}`,
              );
            }

            const testRef = db.collection("listening_tests").doc();

            logger.info("Generating listening audio.", {
              jobId,
              testId: testRef.id,
              testNumber: index + 1,
            });

            const audioData = await generateListeningAudio({
              testId: testRef.id,
              transcript: generatedTest.transcript,
              speakers: generatedTest.speakers,
              accent: generatedTest.accent,
            });

            await testRef.set({
              ...generatedTest,
              ...audioData,
              testId: testRef.id,
              generationJobId: jobId,
              generatedBy: "gemini",
              generatedModel: GEMINI_MODEL,
              qualityScore: validation.qualityScore,
              validationPassed: true,
              validationErrors: [],
              status: "draft",
              isPublished: false,
              order: Date.now() + index,
              timesAttempted: 0,
              averageScore: 0,
              createdBy: job.createdBy || null,
              createdAt:
                FieldValue.serverTimestamp(),
              audioGeneratedAt:
                FieldValue.serverTimestamp(),
              updatedAt:
                FieldValue.serverTimestamp(),
            });

            generatedCount++;
            createdTestIds.push(testRef.id);

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt:
                FieldValue.serverTimestamp(),
            });
          } catch (error) {
            failedCount++;

            const message = safeErrorMessage(error);
            errors.push(`Test ${index + 1}: ${message}`);

            logger.error("Listening test generation failed.", {
              jobId,
              testNumber: index + 1,
              error: message,
            });

            await jobRef.update({
              generatedCount,
              failedCount,
              lastError: message,
              updatedAt:
                FieldValue.serverTimestamp(),
            });
          }
        }

        const finalStatus = generatedCount > 0 ?
          "completed" :
          "failed";

        await jobRef.update({
          status: finalStatus,
          generatedCount,
          failedCount,
          createdTestIds,
          errors,
          completedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });

        logger.info("Listening generation job completed.", {
          jobId,
          generatedCount,
          failedCount,
          finalStatus,
        });
      } catch (error) {
        const message = safeErrorMessage(error);

        logger.error("Generation job crashed.", {
          jobId,
          error: message,
        });

        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: Math.max(failedCount, requestedCount),
          errorMessage: message,
          completedAt:
            FieldValue.serverTimestamp(),
          updatedAt:
            FieldValue.serverTimestamp(),
        });
      }
    },
);

async function generateListeningTest({
  ai,
  job,
  sequenceNumber,
}) {
  const section = clampNumber(job.section, 1, 4, 1);
  const questionCount = getQuestionCount(section, job.mode);

  const prompt = buildListeningPrompt({
    ieltsType: job.ieltsType || "Academic",
    section,
    questionType: job.questionType || "Form completion",
    difficulty: job.difficulty || "Intermediate",
    accent: job.accent || "British",
    mode: job.mode || "practice",
    questionCount,
    sequenceNumber,
  });

const response = await ai.models.generateContent({
  model: GEMINI_MODEL,
  contents: `${prompt}

Return valid JSON only.
Do not wrap the response in markdown code fences.
Follow this exact structure:
{
  "title": "string",
  "description": "string",
  "scenario": "string",
  "instructions": "string",
  "durationSeconds": 420,
  "transcript": "string",
  "speakers": [
    {
      "name": "string",
      "role": "string",
      "voiceStyle": "string"
    }
  ],
  "questions": [
    {
      "number": 1,
      "section": ${section},
      "type": "${job.questionType || "Form completion"}",
      "prompt": "string",
      "options": [],
      "correctAnswer": "string",
      "acceptedAnswers": ["string"],
      "explanation": "string",
      "distractorExplanation": "string",
      "keywords": ["string"],
      "wordLimit": "NO MORE THAN TWO WORDS"
    }
  ],
  "recommendedPractice": ["string"]
}
`,
  config: {
    temperature: 0.7,
    maxOutputTokens: 8000,
  },
});

  if (!response.text) {
    throw new Error("Gemini returned an empty response.");
  }

  let parsed;

  try {
    parsed = JSON.parse(response.text);
  } catch (error) {
    throw new Error(
        `Gemini returned invalid JSON: ${safeErrorMessage(error)}`,
    );
  }

  return normalizeListeningTest(parsed, {
    ieltsType: job.ieltsType || "Academic",
    section,
    questionType: job.questionType || "Form completion",
    difficulty: job.difficulty || "Intermediate",
    accent: job.accent || "British",
    mode: job.mode || "practice",
    questionCount,
  });
}

function buildListeningPrompt({
  ieltsType,
  section,
  questionType,
  difficulty,
  accent,
  mode,
  questionCount,
  sequenceNumber,
}) {
  return `
Create one completely original IELTS-style Listening practice test.

This is independent practice material. Do not copy, quote, reproduce,
paraphrase closely, or claim affiliation with Cambridge IELTS,
British Council, IDP, or any official IELTS examination paper.

TEST SETTINGS
- IELTS type: ${ieltsType}
- Listening section: ${section}
- Primary question type: ${questionType}
- Difficulty: ${difficulty}
- Accent context: ${accent}
- Mode: ${mode}
- Number of questions: ${questionCount}
- Unique generation sequence: ${sequenceNumber}

SECTION RULES
${sectionRules(section)}

STRICT QUALITY REQUIREMENTS
1. Create a natural and realistic listening scenario.
2. Transcript and questions must be fully synchronized.
3. Answers must appear in the transcript in question-number order.
4. Every question must have exactly one unambiguous correct answer.
5. Multiple-choice distractors must be plausible but clearly incorrect.
6. Completion answers should normally be one to three words or a number.
7. Do not require outside knowledge.
8. Avoid culturally sensitive, political, medical, violent, sexual,
   discriminatory, or controversial content.
9. Use original names, places, organizations and situations.
10. The transcript must be long enough to support every question.
11. The transcript must sound natural when converted to speech.
12. Include realistic paraphrasing and signposting.
13. Question numbering must begin at 1 and remain sequential.
14. acceptedAnswers must include reasonable capitalization or spelling
    variants where appropriate.
15. keywords must contain words that help locate the answer.
16. explanation must state why the answer is correct.
17. distractorExplanation must explain why misleading information is wrong.
18. Output JSON only and follow the supplied response schema exactly.

Create a high-quality test suitable for a serious international IELTS
preparation application.
`;
}

function sectionRules(section) {
  switch (section) {
    case 1:
      return `
- Two speakers in an everyday social situation.
- Suitable contexts: booking, registration, accommodation, services,
  courses, appointments or local facilities.
- Language should be accessible and practical.
- Form, note or table completion is especially suitable.
`;
    case 2:
      return `
- One main speaker giving information in an everyday social context.
- Suitable contexts: tours, public facilities, orientation, events,
  transport or community services.
- Map labelling, matching and multiple choice are suitable.
- Use clear signposting and moderate paraphrasing.
`;
    case 3:
      return `
- Two to four speakers in an educational or training context.
- Suitable contexts: students discussing a project, tutorial,
  presentation or research task.
- Include realistic opinion changes and distractors.
- Matching and multiple choice are especially suitable.
`;
    case 4:
      return `
- One speaker delivering an academic-style lecture.
- Use structured academic content with clear organization.
- Note, summary and sentence completion are especially suitable.
- Use stronger paraphrasing and denser information than earlier sections.
`;
    default:
      return "";
  }
}

async function generateListeningAudio({
  testId,
  transcript,
  speakers,
  accent,
}) {
  const cleanTranscript = String(transcript || "").trim();

  if (!cleanTranscript) {
    throw new Error("Cannot generate audio because transcript is empty.");
  }

  if (cleanTranscript.length > MAX_TTS_CHARACTERS) {
    throw new Error(
        `Transcript is too long for standard TTS: ${cleanTranscript.length} ` +
        `characters. Maximum allowed is ${MAX_TTS_CHARACTERS}.`,
    );
  }

  const ssml = buildDialogueSsml(cleanTranscript, speakers);
  const request = {
    input: {ssml},
    voice: {
      languageCode: TTS_LANGUAGE_CODE,
      ssmlGender: "NEUTRAL",
    },
    audioConfig: {
      audioEncoding: "MP3",
      speakingRate: TTS_SPEAKING_RATE,
      pitch: 0,
      volumeGainDb: 0,
    },
  };

  const [response] = await ttsClient.synthesizeSpeech(request);

  if (!response.audioContent) {
    throw new Error("Cloud Text-to-Speech returned empty audio content.");
  }

  const audioBuffer = Buffer.isBuffer(response.audioContent) ?
    response.audioContent :
    Buffer.from(response.audioContent);

  if (audioBuffer.length === 0) {
    throw new Error("Generated audio buffer is empty.");
  }

  const storagePath = `listening_audio/${testId}.mp3`;
  const file = bucket.file(storagePath);

  await file.save(audioBuffer, {
    resumable: false,
    contentType: "audio/mpeg",
    metadata: {
      cacheControl: "public,max-age=31536000,immutable",
      metadata: {
        testId,
        accent: String(accent || "British"),
        generatedBy: "google-cloud-text-to-speech",
      },
    },
  });

  const audioUrl = await getDownloadURL(file);
  const estimatedDurationSeconds = estimateAudioDuration(cleanTranscript);

  logger.info("Listening audio generated successfully.", {
    testId,
    storagePath,
    bytes: audioBuffer.length,
    estimatedDurationSeconds,
  });

  return {
    audioUrl,
    audioStoragePath: storagePath,
    audioStatus: "ready",
    audioFormat: "mp3",
    audioLanguageCode: TTS_LANGUAGE_CODE,
    audioSpeakingRate: TTS_SPEAKING_RATE,
    audioDurationSeconds: estimatedDurationSeconds,
    audioProvider: "google-cloud-text-to-speech",
  };
}

function buildDialogueSsml(transcript, speakers) {
  const knownSpeakers = Array.isArray(speakers) ?
    speakers
        .map((speaker) => String(speaker.name || "").trim())
        .filter(Boolean) :
    [];

  const genderBySpeaker = new Map();

  knownSpeakers.forEach((speakerName, index) => {
    genderBySpeaker.set(
        speakerName.toLowerCase(),
        index % 2 === 0 ? "female" : "male",
    );
  });

  const lines = transcript
      .split(/\r?\n+/)
      .map((line) => line.trim())
      .filter(Boolean);

  const ssmlLines = lines.map((line, index) => {
    const match = line.match(/^([^:]{1,50}):\s*(.+)$/);

    if (!match) {
      return `<voice language="${TTS_LANGUAGE_CODE}" gender="neutral">` +
        `${escapeSsml(line)}</voice><break time="450ms"/>`;
    }

    const speakerName = match[1].trim();
    const spokenText = match[2].trim();
    const key = speakerName.toLowerCase();

    if (!genderBySpeaker.has(key)) {
      genderBySpeaker.set(key, index % 2 === 0 ? "female" : "male");
    }

    const gender = genderBySpeaker.get(key);

    return `<voice language="${TTS_LANGUAGE_CODE}" gender="${gender}">` +
      `${escapeSsml(spokenText)}</voice><break time="500ms"/>`;
  });

  return `<speak>${ssmlLines.join("")}</speak>`;
}

function escapeSsml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&apos;");
}

function estimateAudioDuration(transcript) {
  const wordCount = String(transcript || "")
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .length;

  const wordsPerMinute = 145 * TTS_SPEAKING_RATE;
  const speechSeconds = Math.ceil((wordCount / wordsPerMinute) * 60);
  const dialoguePauses = Math.max(
      0,
      String(transcript || "").split(/\r?\n+/).filter(Boolean).length - 1,
  );

  return Math.max(1, speechSeconds + Math.ceil(dialoguePauses * 0.5));
}

function normalizeListeningTest(test, settings) {
  return {
    title: String(test.title || "").trim(),
    description: String(test.description || "").trim(),
    scenario: String(test.scenario || "").trim(),
    instructions: String(test.instructions || "").trim(),
    ieltsType: settings.ieltsType,
    section: settings.section,
    questionType: settings.questionType,
    difficulty: settings.difficulty,
    accent: settings.accent,
    mode: settings.mode,
    durationSeconds: clampNumber(
        test.durationSeconds,
        180,
        1800,
        420,
    ),
    totalQuestions: settings.questionCount,
    transcript: String(test.transcript || "").trim(),
    speakers: Array.isArray(test.speakers) ?
      test.speakers.map((speaker) => ({
        name: String(speaker.name || "").trim(),
        role: String(speaker.role || "").trim(),
        voiceStyle: String(speaker.voiceStyle || "").trim(),
      })) :
      [],
    questions: Array.isArray(test.questions) ?
      test.questions.map((question, index) => ({
        number: index + 1,
        section: settings.section,
        type: String(
            question.type || settings.questionType,
        ).trim(),
        prompt: String(question.prompt || "").trim(),
        options: Array.isArray(question.options) ?
          question.options.map((value) => String(value).trim()) :
          [],
        correctAnswer:
          String(question.correctAnswer || "").trim(),
        acceptedAnswers:
          Array.isArray(question.acceptedAnswers) ?
            question.acceptedAnswers
                .map((value) => String(value).trim())
                .filter(Boolean) :
            [String(question.correctAnswer || "").trim()],
        explanation:
          String(question.explanation || "").trim(),
        distractorExplanation:
          String(question.distractorExplanation || "").trim(),
        keywords: Array.isArray(question.keywords) ?
          question.keywords
              .map((value) => String(value).trim())
              .filter(Boolean) :
          [],
        wordLimit: String(question.wordLimit || "").trim(),
      })) :
      [],
    recommendedPractice:
      Array.isArray(test.recommendedPractice) ?
        test.recommendedPractice
            .map((value) => String(value).trim())
            .filter(Boolean) :
        [],
    audioUrl: null,
    audioStoragePath: null,
    audioStatus: "pending",
  };
}

function validateListeningTest(test, job) {
  const errors = [];
  let score = 100;

  const requestedCount = getQuestionCount(
      clampNumber(job.section, 1, 4, 1),
      job.mode,
  );

  if (!test.title || test.title.length < 8) {
    errors.push("Title is missing or too short.");
    score -= 10;
  }

  if (!test.transcript || test.transcript.length < 500) {
    errors.push("Transcript is too short.");
    score -= 20;
  }

  if (!Array.isArray(test.questions) ||
      test.questions.length !== requestedCount) {
    errors.push(
        `Expected ${requestedCount} questions, ` +
        `received ${test.questions?.length || 0}.`,
    );
    score -= 25;
  }

  const normalizedTranscript =
    normalizeText(test.transcript);

  const seenPrompts = new Set();

  for (let index = 0;
    index < (test.questions || []).length;
    index++) {
    const question = test.questions[index];
    const expectedNumber = index + 1;

    if (question.number !== expectedNumber) {
      errors.push(
          `Question ${expectedNumber} has invalid numbering.`,
      );
      score -= 3;
    }

    if (!question.prompt) {
      errors.push(
          `Question ${expectedNumber} has no prompt.`,
      );
      score -= 5;
    }

    const normalizedPrompt =
      normalizeText(question.prompt);

    if (seenPrompts.has(normalizedPrompt)) {
      errors.push(
          `Question ${expectedNumber} is duplicated.`,
      );
      score -= 8;
    }

    seenPrompts.add(normalizedPrompt);

    if (!question.correctAnswer) {
      errors.push(
          `Question ${expectedNumber} has no answer.`,
      );
      score -= 8;
    }

    const normalizedAnswer =
      normalizeText(question.correctAnswer);

if (normalizedAnswer &&
    !normalizedTranscript.includes(normalizedAnswer)) {
  const acceptedAnswers = Array.isArray(question.acceptedAnswers)
    ? question.acceptedAnswers
    : [];

  const finalAnswerFound = acceptedAnswers.some((answer) => {
    const normalizedAccepted = normalizeText(answer);
    return normalizedAccepted &&
        normalizedTranscript.includes(normalizedAccepted);
  });

  if (!finalAnswerFound) {
    score -= 3;

    logger.warn("Answer not found exactly in transcript.", {
      questionNumber: expectedNumber,
      answer: question.correctAnswer,
    });
  }
}

    if (!Array.isArray(question.acceptedAnswers) ||
        question.acceptedAnswers.length === 0) {
      errors.push(
          `Question ${expectedNumber} has no accepted answers.`,
      );
      score -= 4;
    }

    if (!question.explanation) {
      errors.push(
          `Question ${expectedNumber} has no explanation.`,
      );
      score -= 3;
    }

    if (!Array.isArray(question.keywords) ||
        question.keywords.length === 0) {
      errors.push(
          `Question ${expectedNumber} has no keywords.`,
      );
      score -= 3;
    }

    if (Array.isArray(question.options) &&
        question.options.length > 0) {
      const normalizedOptions =
        question.options.map(normalizeText);

      const answerInOptions =
        normalizedOptions.includes(normalizedAnswer);

      if (!answerInOptions) {
        errors.push(
            `Question ${expectedNumber} answer ` +
            "is not present in options.",
        );
        score -= 6;
      }

      if (new Set(normalizedOptions).size !==
          normalizedOptions.length) {
        errors.push(
            `Question ${expectedNumber} contains duplicate options.`,
        );
        score -= 5;
      }
    }
  }

  return {
    isValid: errors.length === 0 && score >= 80,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

function getQuestionCount(section, mode) {
  if (String(mode).toLowerCase() === "full") {
    return 40;
  }

  if ([1, 2, 3, 4].includes(section)) {
    return 10;
  }

  return 10;
}

function clampNumber(
    value,
    minimum,
    maximum,
    fallback,
) {
  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return fallback;
  }

  return Math.min(
      maximum,
      Math.max(minimum, Math.round(parsed)),
  );
}

function normalizeText(value) {
  return String(value || "")
      .toLowerCase()
      .replace(/[^\p{L}\p{N}]+/gu, " ")
      .trim();
}

function safeErrorMessage(error) {
  if (error instanceof Error) {
    return error.message.substring(0, 1000);
  }

  return String(error).substring(0, 1000);
}