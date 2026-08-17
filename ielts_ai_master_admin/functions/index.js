const crypto = require("crypto");
const {GoogleAuth} = require("google-auth-library");
const textToSpeech = require("@google-cloud/text-to-speech");
const {getStorage, getDownloadURL} =
  require("firebase-admin/storage");
const {getAuth} = require("firebase-admin/auth");
const nodemailer = require("nodemailer");

const {setGlobalOptions} =
  require("firebase-functions/v2/options");

const {onDocumentCreated} =
  require("firebase-functions/v2/firestore");

const {onCall, HttpsError} =
  require("firebase-functions/v2/https");

const {onSchedule} =
  require("firebase-functions/v2/scheduler");

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
const smtpAppPassword = defineSecret("SMTP_APP_PASSWORD");

const GOOGLE_PLAY_PACKAGE_NAME = "com.rashidapps.ieltsaimaster";
const GOOGLE_PLAY_PRODUCT_IDS = new Set([
  "ielts_premium_monthly",
  "ielts_premium_quarterly",
  "ielts_premium_yearly",
]);

const GOOGLE_PLAY_PRODUCT_LABELS = {
  ielts_premium_monthly: "Monthly Premium",
  ielts_premium_quarterly: "3-Month Premium",
  ielts_premium_yearly: "Annual Premium",
};

const googlePlayAuth = new GoogleAuth({
  scopes: ["https://www.googleapis.com/auth/androidpublisher"],
});

const GEMINI_MODELS = [
  "gemini-3.5-flash",
  "gemini-3.6-flash",
  "gemini-3.1-flash-lite",
];
const TTS_LANGUAGE_CODE = "en-GB";
const TTS_SPEAKING_RATE = 0.92;
const MAX_TTS_SSML_BYTES = 4500;
const MAX_GENERATION_ATTEMPTS = 3;
const MAX_API_RETRIES = 3;
const MAX_STORAGE_RETRIES = 3;
const MAX_READING_GENERATION_ATTEMPTS = 5;
const MAX_READING_PASSAGE_ATTEMPTS = 3;

const SUPPORTED_QUESTION_TYPES_BY_SECTION = {
  1: new Set([
    "Form completion",
    "Note completion",
    "Table completion",
    "Sentence completion",
    "Short answers",
    "Multiple choice",
  ]),
  2: new Set([
    "Note completion",
    "Table completion",
    "Summary completion",
    "Multiple choice",
    "Matching",
    "Map labelling",
    "Diagram labelling",
    "Sentence completion",
    "Short answers",
  ]),
  3: new Set([
    "Note completion",
    "Flowchart completion",
    "Summary completion",
    "Multiple choice",
    "Matching",
    "Sentence completion",
    "Short answers",
  ]),
  4: new Set([
    "Note completion",
    "Table completion",
    "Flowchart completion",
    "Summary completion",
    "Multiple choice",
    "Diagram labelling",
    "Sentence completion",
    "Short answers",
  ]),
};

setGlobalOptions({
  region: "us-central1",
  maxInstances: 3,
  timeoutSeconds: 540,
  memory: "1GiB",
});


/**
 * Sends a premium branded verification email for the currently signed-in user.
 * Firebase Admin generates the secure verification action link; Gmail/Workspace
 * SMTP is used only for delivery. The SMTP app password stays in Secret Manager.
 */
exports.sendCustomVerificationEmail = onCall(
    {
      secrets: [smtpAppPassword],
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to request email verification.",
        );
      }

      const uid = request.auth.uid;
      const auth = getAuth();
      const user = await auth.getUser(uid);

      if (!user.email) {
        throw new HttpsError(
            "failed-precondition",
            "No email address is associated with this account.",
        );
      }

      if (user.emailVerified) {
        return {
          success: true,
          alreadyVerified: true,
          message: "Your email address is already verified.",
        };
      }

      const displayName = String(user.displayName || "").trim();
      const firstName = displayName ? displayName.split(/\s+/)[0] : "there";
      const email = user.email.trim();

      try {
        const verificationLink = await auth.generateEmailVerificationLink(
            email,
            {
              url: "https://ielts-ai-study-assistant.web.app/",
              handleCodeInApp: false,
            },
        );

        const transporter = nodemailer.createTransport({
          host: "smtp.gmail.com",
          port: 465,
          secure: true,
          auth: {
            user: "ceo@korvenzatech.com",
            pass: smtpAppPassword.value(),
          },
        });

        await transporter.sendMail({
          from: '"IELTS AI Master" <noreply@korvenzatech.com>',
          to: email,
          replyTo: "info@korvenzatech.com",
          subject: "Verify your email | IELTS AI Master",
          text:
            `Hi ${firstName},\n\n` +
            "Welcome to IELTS AI Master. Please verify your email address " +
            "to secure your account and continue.\n\n" +
            `${verificationLink}\n\n` +
            "This verification link is intended only for you. If you did not " +
            "create an IELTS AI Master account, you can safely ignore this email.\n\n" +
            "IELTS AI Master\nPowered by KorvenzaTech",
          html: buildVerificationEmailHtml({
            firstName,
            verificationLink,
          }),
        });

        logger.info("Custom verification email sent.", {uid});

        return {
          success: true,
          alreadyVerified: false,
          message: "Verification email sent successfully.",
        };
      } catch (error) {
        logger.error("Custom verification email failed.", {
          uid,
          error: safeErrorMessage(error),
        });

        throw new HttpsError(
            "internal",
            "We could not send the verification email right now. Please try again.",
        );
      }
    },
);

function buildVerificationEmailHtml({firstName, verificationLink}) {
  const safeName = escapeEmailHtml(firstName);
  const safeLink = escapeEmailHtml(verificationLink);
  const year = new Date().getUTCFullYear();

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>Verify your email</title>
</head>
<body style="margin:0;padding:0;background:#f4f7fb;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">Verify your email to finish setting up your IELTS AI Master account.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f4f7fb;padding:40px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;">
        <tr><td style="padding:0 8px 22px;text-align:center;">
          <div style="font-size:24px;font-weight:800;letter-spacing:-0.6px;color:#0b1220;">IELTS <span style="color:#2563eb;">AI Master</span></div>
          <div style="margin-top:6px;font-size:12px;letter-spacing:1.8px;text-transform:uppercase;color:#64748b;">Learn · Practice · Improve</div>
        </td></tr>
        <tr><td style="background:#ffffff;border:1px solid #e5eaf1;border-radius:24px;overflow:hidden;box-shadow:0 18px 50px rgba(15,23,42,.08);">
          <div style="height:6px;background:linear-gradient(90deg,#2563eb,#7c3aed,#06b6d4);"></div>
          <div style="padding:46px 46px 40px;">
            <div style="width:56px;height:56px;line-height:56px;text-align:center;border-radius:16px;background:#eff6ff;color:#2563eb;font-size:26px;font-weight:800;margin-bottom:28px;">✓</div>
            <h1 style="margin:0 0 14px;font-size:30px;line-height:1.2;letter-spacing:-.8px;color:#0f172a;">Verify your email address</h1>
            <p style="margin:0 0 18px;font-size:16px;line-height:1.75;color:#475569;">Hi ${safeName},</p>
            <p style="margin:0 0 28px;font-size:16px;line-height:1.75;color:#475569;">Welcome to <strong style="color:#0f172a;">IELTS AI Master</strong>. Confirm your email address to secure your account and unlock your learning experience.</p>
            <table role="presentation" cellspacing="0" cellpadding="0" border="0"><tr><td style="border-radius:12px;background:#2563eb;">
              <a href="${safeLink}" style="display:inline-block;padding:15px 28px;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">Verify email address</a>
            </td></tr></table>
            <p style="margin:28px 0 0;font-size:13px;line-height:1.7;color:#94a3b8;">For your security, use the button above only if you created this account. If you did not sign up for IELTS AI Master, no action is required.</p>
            <div style="margin-top:30px;padding-top:26px;border-top:1px solid #edf0f4;">
              <p style="margin:0 0 8px;font-size:12px;font-weight:700;color:#64748b;">Button not working?</p>
              <p style="margin:0;font-size:11px;line-height:1.6;color:#94a3b8;word-break:break-all;">${safeLink}</p>
            </div>
          </div>
        </td></tr>
        <tr><td style="padding:26px 20px 0;text-align:center;">
          <p style="margin:0 0 7px;font-size:12px;color:#64748b;">IELTS AI Master · Powered by KorvenzaTech</p>
          <p style="margin:0;font-size:11px;color:#94a3b8;">© ${year} KorvenzaTech. All rights reserved.</p>
          <p style="margin:10px 0 0;font-size:10px;line-height:1.5;color:#a8b1c0;">IELTS AI Master is an independent preparation platform and is not affiliated with or endorsed by IELTS, Cambridge University Press & Assessment, British Council, or IDP.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}

function escapeEmailHtml(value) {
  return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#039;");
}



/**
 * Sends a premium branded password-reset email.
 *
 * This callable intentionally does not require an authenticated Firebase user,
 * because users normally request a password reset while signed out.
 * To reduce account-enumeration risk, the public response is generic whether
 * or not the supplied address belongs to a Firebase account.
 */
exports.sendCustomPasswordResetEmail = onCall(
    {
      secrets: [smtpAppPassword],
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      const email = String(request.data?.email || "").trim().toLowerCase();

      if (!isValidEmailAddress(email)) {
        throw new HttpsError(
            "invalid-argument",
            "Please enter a valid email address.",
        );
      }

      const genericResponse = {
        success: true,
        message:
          "If an IELTS AI Master account exists for this email, " +
          "password reset instructions have been sent.",
      };

      const auth = getAuth();

      try {
        // Check server-side only. Never reveal account existence to the caller.
        const user = await auth.getUserByEmail(email);

        const resetLink = await auth.generatePasswordResetLink(
            email,
            {
              url: "https://ielts-ai-study-assistant.web.app/",
              handleCodeInApp: false,
            },
        );

        const displayName = String(user.displayName || "").trim();
        const firstName = displayName ? displayName.split(/\s+/)[0] : "there";

        const transporter = createKorvenzaMailTransport();

        await transporter.sendMail({
          from: '"IELTS AI Master" <noreply@korvenzatech.com>',
          to: email,
          replyTo: "info@korvenzatech.com",
          subject: "Reset your password | IELTS AI Master",
          text:
            `Hi ${firstName},\n\n` +
            "We received a request to reset the password for your " +
            "IELTS AI Master account.\n\n" +
            `${resetLink}\n\n` +
            "If you did not request a password reset, you can safely ignore " +
            "this email. Your password will remain unchanged.\n\n" +
            "For your security, never share this link with anyone.\n\n" +
            "IELTS AI Master\nPowered by KorvenzaTech",
          html: buildPasswordResetEmailHtml({
            firstName,
            resetLink,
          }),
        });

        logger.info("Custom password reset email sent.", {
          uid: user.uid,
        });

        return genericResponse;
      } catch (error) {
        const code = String(error?.code || "");

        // Do not reveal whether an account exists for the supplied email.
        if (code === "auth/user-not-found") {
          logger.info("Password reset requested for unknown email.");
          return genericResponse;
        }

        logger.error("Custom password reset email failed.", {
          error: safeErrorMessage(error),
        });

        throw new HttpsError(
            "internal",
            "We could not process the password reset request right now. " +
            "Please try again.",
        );
      }
    },
);


function createKorvenzaMailTransport() {
  return nodemailer.createTransport({
    host: "smtp.gmail.com",
    port: 465,
    secure: true,
    auth: {
      user: "ceo@korvenzatech.com",
      pass: smtpAppPassword.value(),
    },
  });
}


function buildPasswordResetEmailHtml({firstName, resetLink}) {
  const safeName = escapeEmailHtml(firstName);
  const safeLink = escapeEmailHtml(resetLink);
  const year = new Date().getUTCFullYear();

  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta name="x-apple-disable-message-reformatting">
  <title>Reset your password</title>
</head>
<body style="margin:0;padding:0;background:#f4f7fb;font-family:Inter,-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Arial,sans-serif;color:#0f172a;">
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;">Securely reset the password for your IELTS AI Master account.</div>
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="background:#f4f7fb;padding:40px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" border="0" style="max-width:620px;">
        <tr><td style="padding:0 8px 22px;text-align:center;">
          <div style="font-size:24px;font-weight:800;letter-spacing:-0.6px;color:#0b1220;">IELTS <span style="color:#2563eb;">AI Master</span></div>
          <div style="margin-top:6px;font-size:12px;letter-spacing:1.8px;text-transform:uppercase;color:#64748b;">Learn · Practice · Improve</div>
        </td></tr>

        <tr><td style="background:#ffffff;border:1px solid #e5eaf1;border-radius:24px;overflow:hidden;box-shadow:0 18px 50px rgba(15,23,42,.08);">
          <div style="height:6px;background:linear-gradient(90deg,#2563eb,#7c3aed,#06b6d4);"></div>

          <div style="padding:46px 46px 40px;">
            <div style="width:56px;height:56px;line-height:56px;text-align:center;border-radius:16px;background:#eff6ff;color:#2563eb;font-size:25px;font-weight:800;margin-bottom:28px;">↻</div>

            <h1 style="margin:0 0 14px;font-size:30px;line-height:1.2;letter-spacing:-.8px;color:#0f172a;">Reset your password</h1>

            <p style="margin:0 0 18px;font-size:16px;line-height:1.75;color:#475569;">Hi ${safeName},</p>

            <p style="margin:0 0 28px;font-size:16px;line-height:1.75;color:#475569;">
              We received a request to reset the password for your
              <strong style="color:#0f172a;">IELTS AI Master</strong> account.
              Use the secure button below to choose a new password.
            </p>

            <table role="presentation" cellspacing="0" cellpadding="0" border="0">
              <tr><td style="border-radius:12px;background:#2563eb;">
                <a href="${safeLink}" style="display:inline-block;padding:15px 28px;font-size:15px;font-weight:700;color:#ffffff;text-decoration:none;border-radius:12px;">Reset password</a>
              </td></tr>
            </table>

            <div style="margin-top:30px;padding:18px 20px;border-radius:14px;background:#f8fafc;border:1px solid #e8edf4;">
              <p style="margin:0 0 6px;font-size:13px;font-weight:700;color:#334155;">Security notice</p>
              <p style="margin:0;font-size:13px;line-height:1.7;color:#64748b;">
                If you did not request this password reset, no action is required.
                Your existing password will remain unchanged. Never forward or
                share this reset link with anyone.
              </p>
            </div>

            <div style="margin-top:30px;padding-top:26px;border-top:1px solid #edf0f4;">
              <p style="margin:0 0 8px;font-size:12px;font-weight:700;color:#64748b;">Button not working?</p>
              <p style="margin:0;font-size:11px;line-height:1.6;color:#94a3b8;word-break:break-all;">${safeLink}</p>
            </div>
          </div>
        </td></tr>

        <tr><td style="padding:26px 20px 0;text-align:center;">
          <p style="margin:0 0 7px;font-size:12px;color:#64748b;">IELTS AI Master · Powered by KorvenzaTech</p>
          <p style="margin:0;font-size:11px;color:#94a3b8;">© ${year} KorvenzaTech. All rights reserved.</p>
          <p style="margin:10px 0 0;font-size:10px;line-height:1.5;color:#a8b1c0;">IELTS AI Master is an independent preparation platform and is not affiliated with or endorsed by IELTS, Cambridge University Press & Assessment, British Council, or IDP.</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
}


function isValidEmailAddress(value) {
  if (!value || value.length > 254) return false;
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}


/**
 * Verifies a Google Play subscription purchase on the server, acknowledges
 * valid initial purchases, and writes the Premium entitlement to Firestore.
 *
 * Flutter sends only:
 *   - productId
 *   - purchaseToken
 *
 * No Google service-account credential is placed inside the mobile app.
 */
exports.verifyGooglePlaySubscription = onCall(
    {
      timeoutSeconds: 60,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to verify a subscription.",
        );
      }

      const productId = String(request.data?.productId || "").trim();
      const purchaseToken =
        String(request.data?.purchaseToken || "").trim();

      if (!GOOGLE_PLAY_PRODUCT_IDS.has(productId)) {
        throw new HttpsError(
            "invalid-argument",
            "Unknown Google Play subscription product.",
        );
      }

      if (!purchaseToken || purchaseToken.length < 20) {
        throw new HttpsError(
            "invalid-argument",
            "A valid Google Play purchase token is required.",
        );
      }

      try {
        const verified = await verifyGooglePlaySubscriptionPurchase({
          purchaseToken,
          expectedProductId: productId,
        });

        if (!verified.productMatched) {
          throw new HttpsError(
              "failed-precondition",
              "The verified Google Play purchase does not match this product.",
          );
        }

        await saveGooglePlayEntitlement({
          uid: request.auth.uid,
          productId,
          purchaseToken,
          purchase: verified.purchase,
          entitlement: verified.entitlement,
        });

        if (verified.entitlement.isPremium &&
            verified.purchase.acknowledgementState ===
              "ACKNOWLEDGEMENT_STATE_PENDING") {
          await acknowledgeGooglePlaySubscription({
            productId,
            purchaseToken,
          });
        }

        logger.info("Google Play subscription verified.", {
          uid: request.auth.uid,
          productId,
          subscriptionState: verified.purchase.subscriptionState,
          isPremium: verified.entitlement.isPremium,
          expiryTime: verified.entitlement.expiryTime,
        });

        return {
          verified: true,
          isPremium: verified.entitlement.isPremium,
          productId,
          planTitle: GOOGLE_PLAY_PRODUCT_LABELS[productId] || "Premium",
          subscriptionState: verified.purchase.subscriptionState || "",
          expiryTime: verified.entitlement.expiryTime,
          autoRenewing: verified.entitlement.autoRenewing,
          testPurchase: Boolean(verified.purchase.testPurchase),
          message: verified.entitlement.isPremium ?
            "Premium subscription verified." :
            "This subscription is not currently entitled to Premium access.",
        };
      } catch (error) {
        if (error instanceof HttpsError) throw error;

        logger.error("Google Play subscription verification failed.", {
          uid: request.auth.uid,
          productId,
          error: safeErrorMessage(error),
        });

        throw new HttpsError(
            "internal",
            "Google Play could not verify this subscription right now.",
        );
      }
    },
);


/**
 * Refreshes the signed-in user's currently stored Google Play purchase token.
 * Call this when the Premium screen opens or when the user restores purchases.
 */
exports.syncGooglePlaySubscription = onCall(
    {
      timeoutSeconds: 60,
      memory: "512MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "You must be signed in to refresh subscription status.",
        );
      }

      const result = await syncGooglePlayEntitlementForUser(request.auth.uid);

      return {
        verified: result.verified,
        isPremium: result.isPremium,
        productId: result.productId || "",
        subscriptionState: result.subscriptionState || "",
        expiryTime: result.expiryTime || null,
        autoRenewing: Boolean(result.autoRenewing),
        message: result.message,
      };
    },
);


/**
 * Safety net for renewals, cancellations, expirations and payment failures.
 * This does not replace Google Play RTDN for very large apps, but it keeps
 * Firestore entitlement state fresh even when the user does not open the
 * Premium screen after a renewal/cancellation.
 */
exports.refreshGooglePlaySubscriptions = onSchedule(
    {
      schedule: "every 6 hours",
      timeZone: "Etc/UTC",
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async () => {
      const snapshot = await db.collection("users")
          .where("subscriptionProvider", "==", "google_play")
          .limit(250)
          .get();

      let checked = 0;
      let active = 0;
      let inactive = 0;
      let failed = 0;

      for (const userDoc of snapshot.docs) {
        try {
          const result =
            await syncGooglePlayEntitlementForUser(userDoc.id);
          checked++;

          if (result.isPremium) {
            active++;
          } else {
            inactive++;
          }
        } catch (error) {
          failed++;
          logger.error("Scheduled Play subscription refresh failed.", {
            uid: userDoc.id,
            error: safeErrorMessage(error),
          });
        }
      }

      logger.info("Scheduled Google Play subscription refresh completed.", {
        checked,
        active,
        inactive,
        failed,
      });
    },
);


async function syncGooglePlayEntitlementForUser(uid) {
  const billingRef = db.collection("users")
      .doc(uid)
      .collection("private_billing")
      .doc("google_play");

  const billingSnapshot = await billingRef.get();

  if (!billingSnapshot.exists) {
    return {
      verified: false,
      isPremium: false,
      message: "No verified Google Play subscription is saved for this account.",
    };
  }

  const billing = billingSnapshot.data() || {};
  const productId = String(billing.productId || "").trim();
  const purchaseToken = String(billing.purchaseToken || "").trim();

  if (!GOOGLE_PLAY_PRODUCT_IDS.has(productId) || !purchaseToken) {
    await disableGooglePlayPremium(uid, {
      reason: "missing_or_invalid_saved_purchase",
      productId,
    });

    return {
      verified: false,
      isPremium: false,
      productId,
      message: "Saved Google Play subscription details are incomplete.",
    };
  }

  const verified = await verifyGooglePlaySubscriptionPurchase({
    purchaseToken,
    expectedProductId: productId,
  });

  await saveGooglePlayEntitlement({
    uid,
    productId,
    purchaseToken,
    purchase: verified.purchase,
    entitlement: verified.entitlement,
  });

  if (verified.entitlement.isPremium &&
      verified.purchase.acknowledgementState ===
        "ACKNOWLEDGEMENT_STATE_PENDING") {
    await acknowledgeGooglePlaySubscription({
      productId,
      purchaseToken,
    });
  }

  return {
    verified: true,
    isPremium: verified.entitlement.isPremium,
    productId,
    subscriptionState: verified.purchase.subscriptionState || "",
    expiryTime: verified.entitlement.expiryTime,
    autoRenewing: verified.entitlement.autoRenewing,
    message: verified.entitlement.isPremium ?
      "Google Play Premium access is active." :
      "No active Google Play Premium entitlement remains.",
  };
}


async function verifyGooglePlaySubscriptionPurchase({
  purchaseToken,
  expectedProductId,
}) {
  const accessToken = await getGooglePlayAccessToken();

  const url =
    "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    `applications/${encodeURIComponent(GOOGLE_PLAY_PACKAGE_NAME)}/` +
    "purchases/subscriptionsv2/tokens/" +
    encodeURIComponent(purchaseToken);

  const response = await fetch(url, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: "application/json",
    },
  });

  const body = await readGoogleApiResponse(response);

  if (!response.ok) {
    const message = googleApiErrorMessage(body, response.status);
    throw new Error(
        `Google Play subscription lookup failed (${response.status}): ` +
        message,
    );
  }

  const lineItems = Array.isArray(body.lineItems) ? body.lineItems : [];
  const productMatched = lineItems.some(
      (item) => String(item.productId || "") === expectedProductId,
  );

  const entitlement = evaluateGooglePlayEntitlement(body, expectedProductId);

  return {
    purchase: body,
    productMatched,
    entitlement,
  };
}


function evaluateGooglePlayEntitlement(purchase, expectedProductId) {
  const state = String(purchase.subscriptionState || "");

  const matchingItems = (Array.isArray(purchase.lineItems) ?
    purchase.lineItems :
    []).filter(
      (item) => String(item.productId || "") === expectedProductId,
    );

  let latestExpiry = null;
  let autoRenewing = false;

  for (const item of matchingItems) {
    const expiry = Date.parse(String(item.expiryTime || ""));

    if (Number.isFinite(expiry) &&
        (latestExpiry === null || expiry > latestExpiry)) {
      latestExpiry = expiry;
    }

    if (item.autoRenewingPlan &&
        item.autoRenewingPlan.autoRenewEnabled === true) {
      autoRenewing = true;
    }
  }

  const now = Date.now();
  const notExpired = latestExpiry !== null && latestExpiry > now;

  // ACTIVE and IN_GRACE_PERIOD retain entitlement.
  // CANCELED can also retain entitlement until lineItems.expiryTime.
  // PENDING, PAUSED, ON_HOLD and EXPIRED do not receive Premium here.
  const entitledState = new Set([
    "SUBSCRIPTION_STATE_ACTIVE",
    "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
    "SUBSCRIPTION_STATE_CANCELED",
  ]).has(state);

  return {
    isPremium: entitledState && notExpired && matchingItems.length > 0,
    expiryTime: latestExpiry === null ?
      null :
      new Date(latestExpiry).toISOString(),
    autoRenewing,
  };
}


async function saveGooglePlayEntitlement({
  uid,
  productId,
  purchaseToken,
  purchase,
  entitlement,
}) {
  const userRef = db.collection("users").doc(uid);
  const billingRef = userRef
      .collection("private_billing")
      .doc("google_play");

  const expiryDate = entitlement.expiryTime ?
    new Date(entitlement.expiryTime) :
    null;

  const batch = db.batch();

  batch.set(
      billingRef,
      {
        provider: "google_play",
        packageName: GOOGLE_PLAY_PACKAGE_NAME,
        productId,
        purchaseToken,
        purchaseTokenHash:
          crypto.createHash("sha256").update(purchaseToken).digest("hex"),
        subscriptionState: String(purchase.subscriptionState || ""),
        acknowledgementState:
          String(purchase.acknowledgementState || ""),
        autoRenewing: Boolean(entitlement.autoRenewing),
        expiryTime: expiryDate,
        isPremium: Boolean(entitlement.isPremium),
        isTestPurchase: Boolean(purchase.testPurchase),
        lastVerifiedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  batch.set(
      userRef,
      {
        isPremium: Boolean(entitlement.isPremium),
        premium: Boolean(entitlement.isPremium),
        subscription: entitlement.isPremium ?
          (GOOGLE_PLAY_PRODUCT_LABELS[productId] || "Premium") :
          "Free",
        premiumPlan: entitlement.isPremium ?
          (GOOGLE_PLAY_PRODUCT_LABELS[productId] || "Premium") :
          "",
        subscriptionProvider: "google_play",
        googlePlayProductId: productId,
        googlePlaySubscriptionState:
          String(purchase.subscriptionState || ""),
        googlePlayAutoRenewing: Boolean(entitlement.autoRenewing),
        subscriptionExpiry: expiryDate,
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
  );

  await batch.commit();
}


async function disableGooglePlayPremium(uid, {
  reason,
  productId = "",
}) {
  await db.collection("users").doc(uid).set(
      {
        isPremium: false,
        premium: false,
        subscription: "Free",
        premiumPlan: "",
        subscriptionProvider: "google_play",
        googlePlayProductId: productId,
        googlePlaySubscriptionState: reason,
        googlePlayAutoRenewing: false,
        subscriptionUpdatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
      {merge: true},
  );
}


async function acknowledgeGooglePlaySubscription({
  productId,
  purchaseToken,
}) {
  const accessToken = await getGooglePlayAccessToken();

  const url =
    "https://androidpublisher.googleapis.com/androidpublisher/v3/" +
    `applications/${encodeURIComponent(GOOGLE_PLAY_PACKAGE_NAME)}/` +
    `purchases/subscriptions/${encodeURIComponent(productId)}/tokens/` +
    `${encodeURIComponent(purchaseToken)}:acknowledge`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({}),
  });

  if (response.ok) return;

  const body = await readGoogleApiResponse(response);
  const message = googleApiErrorMessage(body, response.status);

  // If another trusted path already acknowledged the purchase, entitlement
  // remains valid. Treat explicit already-acknowledged responses as harmless.
  if (message.toLowerCase().includes("already acknowledged")) {
    return;
  }

  throw new Error(
      `Google Play acknowledgement failed (${response.status}): ${message}`,
  );
}


async function getGooglePlayAccessToken() {
  const client = await googlePlayAuth.getClient();
  const tokenResponse = await client.getAccessToken();
  const token = typeof tokenResponse === "string" ?
    tokenResponse :
    tokenResponse?.token;

  if (!token) {
    throw new Error("Could not obtain Google Play Developer API access token.");
  }

  return token;
}


async function readGoogleApiResponse(response) {
  const text = await response.text();

  if (!text) return {};

  try {
    return JSON.parse(text);
  } catch (_) {
    return {raw: text};
  }
}


function googleApiErrorMessage(body, status) {
  if (body?.error?.message) return String(body.error.message);
  if (body?.raw) return String(body.raw);
  return `Google API request failed with HTTP ${status}.`;
}


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

      const jobValidationError = validateGenerationJob(job);
      if (jobValidationError) {
        await jobRef.update({
          status: "failed",
          failedCount: clampNumber(job.requestedCount, 1, 10, 1),
          errorMessage: jobValidationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        logger.error("Invalid listening generation job.", {
          jobId,
          error: jobValidationError,
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

            const result = await generateValidUniqueListeningTest({
              ai,
              job,
              sequenceNumber: index + 1,
              jobId,
              testNumber: index + 1,
            });
            const generatedTest = result.test;
            const validation = result.validation;

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
              generatedModel: result.model,
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


async function generateValidUniqueListeningTest({
  ai,
  job,
  sequenceNumber,
  jobId,
  testNumber,
}) {
  const failures = [];

  for (let attempt = 1; attempt <= MAX_GENERATION_ATTEMPTS; attempt++) {
    try {
      const generated = await generateListeningTest({
        ai,
        job,
        sequenceNumber: sequenceNumber * 10 + attempt,
      });
      const test = generated.test;

      const validation = validateListeningTest(test, job);

      if (!validation.isValid) {
        throw new Error(
            `Validation failed: ${validation.errors.join(" | ")}`,
        );
      }

      const duplicate = await findLikelyDuplicate(test);
      if (duplicate) {
        throw new Error(
            `Possible duplicate content detected: ${duplicate.id}`,
        );
      }

      return {test, validation, model: generated.model};
    } catch (error) {
      const message = safeErrorMessage(error);
      failures.push(`Attempt ${attempt}: ${message}`);

      logger.warn("Listening content attempt failed.", {
        jobId,
        testNumber,
        attempt,
        error: message,
      });

      if (isPermanentQuotaError(error) ||
          attempt === MAX_GENERATION_ATTEMPTS) {
        break;
      }

      await sleep(1200 * attempt);
    }
  }

  throw new Error(
      `Unable to create a valid listening test after ` +
      `${MAX_GENERATION_ATTEMPTS} attempts. ${failures.join(" || ")}`,
  );
}


async function callGeminiWithRetry(ai, request) {
  const fallbackErrors = [];

  for (let modelIndex = 0;
    modelIndex < GEMINI_MODELS.length;
    modelIndex++) {
    const model = GEMINI_MODELS[modelIndex];
    let lastError;

    for (let attempt = 1; attempt <= MAX_API_RETRIES; attempt++) {
      try {
        logger.info("Calling Gemini model.", {
          model,
          attempt,
        });

        const response = await ai.models.generateContent({
          ...request,
          model,
        });

        return {response, model};
      } catch (error) {
        lastError = error;
        const message = safeErrorMessage(error);
        const shouldSwitchModel =
          isGeminiQuotaError(error) ||
          isGeminiModelUnavailableError(error);

        if (shouldSwitchModel) {
          fallbackErrors.push(`${model}: ${message}`);

          const nextModel = GEMINI_MODELS[modelIndex + 1];
          if (nextModel) {
            logger.warn("Gemini model unavailable; switching model.", {
              currentModel: model,
              nextModel,
              reason: isGeminiQuotaError(error) ?
                "quota_exhausted" :
                "model_unavailable",
              error: message,
            });
          } else {
            logger.warn("Gemini model unavailable; no fallback remains.", {
              currentModel: model,
              error: message,
            });
          }

          break;
        }

        if (!isRetryableError(error) || attempt === MAX_API_RETRIES) {
          throw error;
        }

        const delayMs = 1500 * Math.pow(2, attempt - 1);
        logger.warn("Gemini request failed; retrying same model.", {
          model,
          attempt,
          delayMs,
          error: message,
        });
        await sleep(delayMs);
      }
    }

    if (lastError &&
        !isGeminiQuotaError(lastError) &&
        !isGeminiModelUnavailableError(lastError)) {
      throw lastError;
    }
  }

  const details = fallbackErrors.length > 0 ?
    fallbackErrors.join(" | ") :
    "No model returned a successful response.";

  throw new Error(
      "All configured Gemini models are rate-limited, unavailable, or " +
      "exhausted. Please try again later or check billing and model access. " +
      `Details: ${details}`,
  );
}

function validateGenerationJob(job) {
  const section = clampNumber(job.section, 1, 4, 1);
  const questionType = String(job.questionType || "").trim();
  const allowedTypes = SUPPORTED_QUESTION_TYPES_BY_SECTION[section];

  if (!questionType) {
    return "Question type is required.";
  }

  if (!allowedTypes || !allowedTypes.has(questionType)) {
    return `Question type "${questionType}" is not supported in Section ` +
      `${section}.`;
  }

  if (String(job.mode || "").toLowerCase() === "full") {
    return "Full mode must be created as four separate 10-question sections.";
  }

  return null;
}


function normalizeOptions(values) {
  if (!Array.isArray(values)) return [];

  return values
      .map((value) => {
        if (value && typeof value === "object") {
          return String(
              value.text || value.label || value.value || "",
          ).trim();
        }

        return String(value || "").trim();
      })
      .map((value) => value.replace(/^[A-Da-d][.)\-:]\s*/, "").trim())
      .filter(Boolean);
}


function normalizeCorrectAnswer(answer, rawOptions) {
  const options = normalizeOptions(rawOptions);
  const raw = String(answer || "").trim();

  if (!raw) return "";

  const letterMatch = raw.match(/^\s*([A-Da-d])(?:[.)\-:]|\s|$)/);
  if (letterMatch) {
    const optionIndex = letterMatch[1].toUpperCase().charCodeAt(0) - 65;
    if (options[optionIndex]) return options[optionIndex];
  }

  const cleaned = raw.replace(/^[A-Da-d][.)\-:]\s*/, "").trim();
  const normalizedCleaned = normalizeText(cleaned);

  const exactOption = options.find(
      (option) => normalizeText(option) === normalizedCleaned,
  );

  return exactOption || cleaned;
}


function normalizeAcceptedAnswers(values, answer, rawOptions) {
  const correctAnswer = normalizeCorrectAnswer(answer, rawOptions);
  const accepted = Array.isArray(values) ?
    values.map((value) => String(value || "").trim()).filter(Boolean) :
    [];

  if (correctAnswer &&
      !accepted.some(
          (value) => normalizeText(value) === normalizeText(correctAnswer),
      )) {
    accepted.unshift(correctAnswer);
  }

  return accepted.length > 0 ? accepted : [correctAnswer].filter(Boolean);
}


function answerAppearsInTranscript(question, normalizedTranscript) {
  const candidates = [
    question.correctAnswer,
    ...(Array.isArray(question.acceptedAnswers) ?
      question.acceptedAnswers :
      []),
  ];

  return candidates.some((answer) => {
    const normalized = normalizeText(answer);
    if (!normalized) return false;

    if (normalizedTranscript.includes(normalized)) return true;

    const simplified = normalizeAnswerForComparison(answer);
    const simplifiedTranscript =
      normalizeAnswerForComparison(normalizedTranscript);

    return simplified &&
      simplifiedTranscript.includes(simplified);
  });
}


function normalizeAnswerForComparison(value) {
  return normalizeText(value)
      .replace(/\b(\d+)(st|nd|rd|th)\b/g, "$1")
      .replace(/\bzero\b/g, "0")
      .replace(/\bone\b/g, "1")
      .replace(/\btwo\b/g, "2")
      .replace(/\bthree\b/g, "3")
      .replace(/\bfour\b/g, "4")
      .replace(/\bfive\b/g, "5")
      .replace(/\bsix\b/g, "6")
      .replace(/\bseven\b/g, "7")
      .replace(/\beight\b/g, "8")
      .replace(/\bnine\b/g, "9");
}


async function retryOperation(operation, {
  attempts,
  operationName,
}) {
  let lastError;

  for (let attempt = 1; attempt <= attempts; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;

      if (attempt === attempts || !isRetryableError(error)) {
        throw error;
      }

      const delayMs = 1000 * Math.pow(2, attempt - 1);
      logger.warn(`${operationName} failed; retrying.`, {
        attempt,
        delayMs,
        error: safeErrorMessage(error),
      });
      await sleep(delayMs);
    }
  }

  throw lastError || new Error(`${operationName} failed.`);
}


function isRetryableError(error) {
  const message = safeErrorMessage(error).toLowerCase();

  return message.includes("429") ||
    message.includes("resource_exhausted") ||
    message.includes("socket hang up") ||
    message.includes("econnreset") ||
    message.includes("etimedout") ||
    message.includes("timeout") ||
    message.includes("503") ||
    message.includes("502") ||
    message.includes("internal") ||
    message.includes("unavailable");
}


function isGeminiQuotaError(error) {
  const message = safeErrorMessage(error).toLowerCase();

  return message.includes("429") ||
    message.includes("resource_exhausted") ||
    message.includes("quota exceeded") ||
    message.includes("rate limit") ||
    message.includes("free_tier_requests") ||
    message.includes("generaterequestsperday") ||
    message.includes("perdayperprojectpermodel-freetier");
}


function isGeminiModelUnavailableError(error) {
  const message = safeErrorMessage(error).toLowerCase();

  return message.includes("404") ||
    message.includes("not_found") ||
    message.includes("model is no longer available") ||
    message.includes("is no longer available") ||
    message.includes("model not found") ||
    message.includes("unsupported model");
}


function isPermanentQuotaError(error) {
  const message = safeErrorMessage(error).toLowerCase();

  return message.includes("all configured gemini models") ||
    message.includes("free_tier_requests") ||
    message.includes("generaterequestsperday") ||
    message.includes("perdayperprojectpermodel-freetier");
}


function sleep(milliseconds) {
  return new Promise((resolve) => setTimeout(resolve, milliseconds));
}


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

  const geminiResult = await callGeminiWithRetry(ai, {
    contents: `${prompt}

Return valid JSON only.
Do not wrap the response in markdown code fences.
For selectable question types, options must be plain text values and
correctAnswer must equal the complete text of exactly one option.
Do not return only A, B, C or D as correctAnswer.
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
      temperature: 0.65,
      maxOutputTokens: 8000,
      responseMimeType: "application/json",
    },
  });

  const response = geminiResult.response;

  if (!response.text) {
    throw new Error("Gemini returned an empty response.");
  }

  let parsed;

  try {
const cleanedResponse = String(response.text || "")
    .replace(/```json/gi, "")
    .replace(/```/g, "")
    .trim();

const start = cleanedResponse.indexOf("{");
const end = cleanedResponse.lastIndexOf("}");

if (start === -1 || end === -1) {
  throw new Error("Gemini did not return JSON.");
}

const jsonOnly = cleanedResponse.substring(start, end + 1);

parsed = JSON.parse(jsonOnly);
  } catch (error) {
    throw new Error(
        `Gemini returned invalid JSON: ${safeErrorMessage(error)}`,
    );
  }

  return {
    test: normalizeListeningTest(parsed, {
      ieltsType: job.ieltsType || "Academic",
      section,
      questionType: job.questionType || "Form completion",
      difficulty: job.difficulty || "Intermediate",
      accent: job.accent || "British",
      mode: job.mode || "practice",
      questionCount,
    }),
    model: geminiResult.model,
  };
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

QUESTION TYPE RULES
${questionTypeRules(questionType)}

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
19. Avoid repeating common scenarios used in earlier tests.
20. Do not always create community centre, course registration,
    booking, membership, accommodation, or application scenarios.
21. Select a varied scenario from areas such as:
    travel booking, medical appointment, library membership,
    event registration, vehicle rental, local services,
    sports club, lost property, volunteering, repair service,
    restaurant booking, insurance enquiry, or training enrolment.
22. Generate a distinct title, setting, names, facts and answer pattern.

Create a high-quality test suitable for a serious international IELTS
preparation application.
`;
}


function questionTypeRules(questionType) {
  const type = String(questionType || "").toLowerCase();

  if (type.includes("multiple choice")) {
    return `
- Every question must contain exactly 4 concise plain-text options.
- Do not prefix options with A, B, C or D.
- correctAnswer must equal the complete text of exactly one option.
- Never use only a letter such as A, B, C or D as correctAnswer.
- The transcript must clearly support the correct option through meaning,
  but the full option sentence does not need to appear word-for-word.
- Use realistic distractors based on information heard before or after the answer.
- Do not use text-entry blanks for this activity.
`;
  }

  if (type.includes("matching")) {
    return `
- Represent each matching item as a selectable question.
- Every question must contain the same 4 to 7 labelled options.
- correctAnswer must exactly match one option.
- Include plausible unused or repeated distractors where appropriate.
`;
  }

  if (type.includes("map") || type.includes("diagram")) {
    return `
- Represent each labelled location as a multiple-choice item because the app
  currently renders selectable labels instead of an image canvas.
- Provide 4 concise location or label options for every question.
- correctAnswer must exactly match one option.
- Transcript must contain clear spatial language and direction changes.
`;
  }

  if (type.includes("form") || type.includes("note") ||
      type.includes("table") || type.includes("flowchart") ||
      type.includes("summary") || type.includes("sentence")) {
    return `
- questions[].options must be an empty array.
- Prompts must include a clearly marked blank such as [1], [2], and so on.
- Answers must normally be one to three words or a number.
- wordLimit must contain a realistic IELTS-style instruction.
`;
  }

  return `
- Use short-answer text entry.
- questions[].options must be an empty array.
- Answers must be concise, directly supported by the transcript and unambiguous.
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


async function findLikelyDuplicate(test) {
  const titleKey = normalizeText(test.title);
  const scenarioKey = normalizeText(test.scenario);

  const snapshot = await db.collection("listening_tests")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const existingTitle = normalizeText(data.title);
    const existingScenario = normalizeText(data.scenario);

    if (titleKey && existingTitle === titleKey) return doc;
    if (scenarioKey && existingScenario === scenarioKey) return doc;
  }

  return null;
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

  const ssmlChunks = splitTranscriptIntoSsmlChunks(
      cleanTranscript,
      speakers,
  );

  if (ssmlChunks.length === 0) {
    throw new Error("No valid TTS chunks were created from the transcript.");
  }

  const audioBuffers = [];

  for (let index = 0; index < ssmlChunks.length; index++) {
    const ssml = ssmlChunks[index];
    const ssmlBytes = Buffer.byteLength(ssml, "utf8");

    logger.info("Generating listening audio chunk.", {
      testId,
      chunkNumber: index + 1,
      totalChunks: ssmlChunks.length,
      ssmlBytes,
    });

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
      throw new Error(
          `Cloud TTS returned empty audio for chunk ${index + 1}.`,
      );
    }

    const chunkBuffer = Buffer.isBuffer(response.audioContent) ?
      response.audioContent :
      Buffer.from(response.audioContent);

    if (chunkBuffer.length === 0) {
      throw new Error(
          `Generated audio chunk ${index + 1} is empty.`,
      );
    }

    audioBuffers.push(chunkBuffer);
  }

  const audioBuffer = Buffer.concat(audioBuffers);

  if (audioBuffer.length === 0) {
    throw new Error("Final generated audio buffer is empty.");
  }

  const storagePath = `listening_audio/${testId}.mp3`;
  const file = bucket.file(storagePath);

  await retryOperation(
      () => file.save(audioBuffer, {
        resumable: false,
        contentType: "audio/mpeg",
        metadata: {
          cacheControl: "public,max-age=31536000,immutable",
          metadata: {
            testId,
            accent: String(accent || "British"),
            generatedBy: "google-cloud-text-to-speech",
            chunkCount: String(ssmlChunks.length),
          },
        },
      }),
      {
        attempts: MAX_STORAGE_RETRIES,
        operationName: "Firebase Storage audio upload",
      },
  );

  const audioUrl = await getDownloadURL(file);
  const estimatedDurationSeconds = estimateAudioDuration(cleanTranscript);

  logger.info("Listening audio generated successfully.", {
    testId,
    storagePath,
    bytes: audioBuffer.length,
    chunkCount: ssmlChunks.length,
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
    audioChunkCount: ssmlChunks.length,
  };
}


function splitTranscriptIntoSsmlChunks(transcript, speakers) {
  const sourceLines = String(transcript || "")
      .split(/\r?\n+/)
      .map((line) => line.trim())
      .filter(Boolean);

  const safeLines = [];

  for (const line of sourceLines) {
    const singleLineSsml = buildDialogueSsml(line, speakers);

    if (Buffer.byteLength(singleLineSsml, "utf8") <=
        MAX_TTS_SSML_BYTES) {
      safeLines.push(line);
      continue;
    }

    safeLines.push(...splitOversizedTranscriptLine(line, speakers));
  }

  const chunks = [];
  let currentLines = [];

  for (const line of safeLines) {
    const candidateLines = [...currentLines, line];
    const candidateSsml = buildDialogueSsml(
        candidateLines.join("\n"),
        speakers,
    );

    if (Buffer.byteLength(candidateSsml, "utf8") <=
        MAX_TTS_SSML_BYTES) {
      currentLines = candidateLines;
      continue;
    }

    if (currentLines.length > 0) {
      chunks.push(buildDialogueSsml(
          currentLines.join("\n"),
          speakers,
      ));
    }

    currentLines = [line];
  }

  if (currentLines.length > 0) {
    chunks.push(buildDialogueSsml(
        currentLines.join("\n"),
        speakers,
    ));
  }

  for (const chunk of chunks) {
    const bytes = Buffer.byteLength(chunk, "utf8");

    if (bytes > MAX_TTS_SSML_BYTES) {
      throw new Error(
          `Generated SSML chunk is too large: ${bytes} bytes.`,
      );
    }
  }

  return chunks;
}


function splitOversizedTranscriptLine(line, speakers) {
  const match = String(line).match(/^([^:]{1,50}):\s*(.+)$/);
  const speakerPrefix = match ? `${match[1].trim()}: ` : "";
  const spokenText = match ? match[2].trim() : String(line).trim();
  const words = spokenText.split(/\s+/).filter(Boolean);

  if (words.length === 0) {
    return [];
  }

  const parts = [];
  let currentWords = [];

  for (const word of words) {
    const candidateWords = [...currentWords, word];
    const candidateLine = speakerPrefix + candidateWords.join(" ");
    const candidateSsml = buildDialogueSsml(
        candidateLine,
        speakers,
    );

    if (Buffer.byteLength(candidateSsml, "utf8") <=
        MAX_TTS_SSML_BYTES) {
      currentWords = candidateWords;
      continue;
    }

    if (currentWords.length === 0) {
      throw new Error(
          "A single transcript word is too large for Cloud TTS.",
      );
    }

    parts.push(speakerPrefix + currentWords.join(" "));
    currentWords = [word];
  }

  if (currentWords.length > 0) {
    parts.push(speakerPrefix + currentWords.join(" "));
  }

  return parts;
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
        options: normalizeOptions(question.options),
        correctAnswer: normalizeCorrectAnswer(
            question.correctAnswer,
            question.options,
        ),
        acceptedAnswers: normalizeAcceptedAnswers(
            question.acceptedAnswers,
            question.correctAnswer,
            question.options,
        ),
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
    const selectionType = isSelectionQuestionType(
        question.type || job.questionType,
    );

    if (!selectionType &&
        normalizedAnswer &&
        !answerAppearsInTranscript(question, normalizedTranscript)) {
      logger.warn("Text answer not found exactly in transcript.", {
        questionNumber: expectedNumber,
        answer: question.correctAnswer,
      });
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

    const options = Array.isArray(question.options) ?
      question.options :
      [];

    if (selectionType && options.length < 3) {
      errors.push(
          `Question ${expectedNumber} requires at least 3 options.`,
      );
      score -= 8;
    }

    if (!selectionType && options.length > 0) {
      errors.push(
          `Question ${expectedNumber} should not contain options.`,
      );
      score -= 5;
    }

    if (options.length > 0) {
      const normalizedOptions = options.map(normalizeText);
      const answerInOptions = normalizedOptions.includes(normalizedAnswer);

      if (!answerInOptions) {
        errors.push(
            `Question ${expectedNumber} answer is not present in options.`,
        );
        score -= 6;
      }

      if (new Set(normalizedOptions).size !== normalizedOptions.length) {
        errors.push(
            `Question ${expectedNumber} contains duplicate options.`,
        );
        score -= 5;
      }
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

function isSelectionQuestionType(value) {
  const type = String(value || "").toLowerCase();
  return type.includes("multiple choice") ||
    type.includes("matching") ||
    type.includes("map") ||
    type.includes("diagram");
}

function getQuestionCount(section, mode) {
  if (String(mode).toLowerCase() === "full") {
    throw new Error(
        "Full mode must be created as four separate 10-question sections.",
    );
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
// ============================================================================
// READING MODULE
// ============================================================================

const READING_QUESTION_TYPES = new Set([
  "Multiple choice",
  "True / False / Not Given",
  "Yes / No / Not Given",
  "Matching headings",
  "Matching information",
  "Matching features",
  "Sentence endings",
  "Summary completion",
  "Sentence completion",
  "Note completion",
  "Table completion",
  "Flowchart completion",
  "Diagram labels",
  "Short answers",
]);

exports.processReadingGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      if (job.contentType !== "reading" || job.status !== "queued") return;

      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;
      const requestedCount = clampNumber(job.requestedCount, 1, 5, 1);

      const validationError = validateReadingGenerationJob(job);
      if (validationError) {
        await jobRef.update({
          status: "failed",
          generatedCount: 0,
          failedCount: requestedCount,
          errorMessage: validationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await jobRef.update({
        status: "generating",
        generatedCount: 0,
        failedCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: FieldValue.delete(),
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdTestIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        for (let index = 0; index < requestedCount; index++) {
          try {
            logger.info("Generating reading test.", {
              jobId,
              testNumber: index + 1,
              requestedCount,
            });

            const generated = await generateValidUniqueReadingTest({
              ai,
              job,
              sequenceNumber: index + 1,
              jobId,
              testNumber: index + 1,
            });
            const validation = generated.validation;

            const testRef = db.collection("reading_tests").doc();

            const generatedQuestionTypes =
              collectReadingQuestionTypes(generated.test.questions);
            const requestedQuestionType =
              normalizeReadingQuestionType(job.questionType);
            const primaryQuestionType =
              requestedQuestionType ||
              (generatedQuestionTypes.length === 1 ?
                generatedQuestionTypes[0] :
                "");

            await testRef.set({
              ...generated.test,
              mode: normalizeReadingMode(
                  generated.test.mode || job.mode || "passage",
              ),
              questionType: primaryQuestionType || null,
              primaryQuestionType: primaryQuestionType || null,
              questionTypeKey: primaryQuestionType ?
                toReadingQuestionTypeKey(primaryQuestionType) :
                null,
              questionTypes: generatedQuestionTypes,
              questionTypeKeys: generatedQuestionTypes.map(
                  toReadingQuestionTypeKey,
              ),
              testId: testRef.id,
              generationJobId: jobId,
              generatedBy: "gemini",
              generatedModel: generated.model,
              qualityScore: validation.qualityScore,
              validationPassed: true,
              validationErrors: [],
              validationWarnings: generated.warnings || [],
              possibleDuplicate: Boolean(generated.possibleDuplicate),
              duplicateOfTestId: generated.duplicateOfTestId || null,
              status: "draft",
              isPublished: false,
              order: Date.now() + index,
              timesAttempted: 0,
              averageScore: 0,
              createdBy: job.createdBy || null,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });

            generatedCount++;
            createdTestIds.push(testRef.id);

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (error) {
            failedCount++;
            const message = safeErrorMessage(error);
            errors.push(`Test ${index + 1}: ${message}`);

            logger.error("Reading test generation failed.", {
              jobId,
              testNumber: index + 1,
              error: message,
            });

            await jobRef.update({
              generatedCount,
              failedCount,
              lastError: message,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }

        await jobRef.update({
          status: generatedCount > 0 ? "completed" : "failed",
          generatedCount,
          failedCount,
          createdTestIds,
          errors,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        const message = safeErrorMessage(error);
        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: Math.max(failedCount, requestedCount),
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);


async function generateValidUniqueReadingTest({
  ai,
  job,
  sequenceNumber,
  jobId,
  testNumber,
}) {
  const failures = [];
  let lastValidResult = null;
  let lastDuplicate = null;

  for (let attempt = 1;
    attempt <= MAX_READING_GENERATION_ATTEMPTS;
    attempt++) {
    try {
      const generated = await generateReadingTest({
        ai,
        job,
        sequenceNumber: sequenceNumber * 100 + attempt,
      });

      const validation = validateReadingTest(generated.test, job);
      if (!validation.isValid) {
        throw new Error(
            `Reading validation failed: ${validation.errors.join(" | ")}`,
        );
      }

      lastValidResult = {
        ...generated,
        validation,
      };

      const duplicate = await findLikelyReadingDuplicate(generated.test);
      if (!duplicate) {
        return {
          ...lastValidResult,
          warnings: validation.warnings || [],
          possibleDuplicate: false,
          duplicateOfTestId: null,
        };
      }

      lastDuplicate = duplicate;
      failures.push(
          `Attempt ${attempt}: possible duplicate of ${duplicate.id}`,
      );

      logger.warn("Reading duplicate detected; regenerating content.", {
        jobId,
        testNumber,
        attempt,
        duplicateTestId: duplicate.id,
      });
    } catch (error) {
      const message = safeErrorMessage(error);
      failures.push(`Attempt ${attempt}: ${message}`);

      logger.warn("Reading content attempt failed.", {
        jobId,
        testNumber,
        attempt,
        error: message,
      });

      if (isPermanentQuotaError(error)) {
        break;
      }
    }

    if (attempt < MAX_READING_GENERATION_ATTEMPTS) {
      await sleep(1200 * attempt);
    }
  }

  // A valid test should not be discarded only because its generated title or
  // opening resembles older content. Save it as a draft with a warning so the
  // administrator can review it before publishing.
  if (lastValidResult) {
    logger.warn("Saving valid reading test with duplicate-review warning.", {
      jobId,
      testNumber,
      duplicateTestId: lastDuplicate?.id || null,
    });

    return {
      ...lastValidResult,
      warnings: [
        ...(lastValidResult.validation.warnings || []),
        "Possible similarity with existing content. Admin review required.",
      ],
      possibleDuplicate: true,
      duplicateOfTestId: lastDuplicate?.id || null,
    };
  }

  throw new Error(
      "Unable to create a valid reading test after " +
      `${MAX_READING_GENERATION_ATTEMPTS} attempts. ` +
      failures.join(" || "),
  );
}


function validateReadingGenerationJob(job) {
  const ieltsType = String(job.ieltsType || "Academic");
  const mode = normalizeReadingMode(job.mode);
  const questionType = normalizeReadingQuestionType(job.questionType);

  if (!["Academic", "General Training"].includes(ieltsType)) {
    return "IELTS type must be Academic or General Training.";
  }

  const allowedModes = [
    "academic",
    "general",
    "passage",
    "question_type",
    "timed",
    "full",
    "speed",
    "practice",
    "exam",
  ];

  if (!allowedModes.includes(mode)) {
    return `Unsupported reading mode: ${mode}.`;
  }

  if (questionType && !READING_QUESTION_TYPES.has(questionType)) {
    return `Unsupported reading question type: ${questionType}.`;
  }

  if (mode === "question_type" && !questionType) {
    return "Question Type Practice requires a question type.";
  }

  return null;
}

function getReadingPlan(job) {
  const mode = normalizeReadingMode(job.mode);
  const requestedType = normalizeReadingQuestionType(job.questionType);
  const isQuestionTypePractice = mode === "question_type";

  if (mode === "full" || mode === "academic" || mode === "general" ||
      mode === "exam") {
    return {
      passageCount: 3,
      questionCounts: [13, 13, 14],
      durationSeconds: 3600,
      fullTest: true,
      toolsEnabled: mode !== "exam" && mode !== "full",
      questionType: "",
    };
  }

  if (mode === "timed") {
    return {
      passageCount: 1,
      questionCounts: [13],
      durationSeconds: 1200,
      fullTest: false,
      toolsEnabled: false,
      questionType: requestedType,
    };
  }

  if (mode === "speed") {
    return {
      passageCount: 1,
      questionCounts: [5],
      durationSeconds: clampNumber(job.durationSeconds, 300, 900, 600),
      fullTest: false,
      toolsEnabled: true,
      questionType: requestedType || "Multiple choice",
      speedReading: true,
    };
  }

  if (isQuestionTypePractice) {
    return {
      passageCount: 1,
      questionCounts: [
        clampNumber(job.questionCount, 5, 15, 10),
      ],
      durationSeconds: clampNumber(job.durationSeconds, 600, 1800, 1200),
      fullTest: false,
      toolsEnabled: true,
      questionType: requestedType,
    };
  }

  const requestedPassages = mode === "passage" || mode === "practice" ?
    1 :
    clampNumber(job.passageCount, 1, 3, 1);
  const requestedQuestions = clampNumber(job.questionCount, 5, 20, 10);

  return {
    passageCount: requestedPassages,
    questionCounts: Array.from(
        {length: requestedPassages},
        () => requestedQuestions,
    ),
    durationSeconds: requestedPassages === 1 ? 1200 : 3600,
    fullTest: false,
    toolsEnabled: true,
    questionType: requestedType,
  };
}

async function generateReadingTest({ai, job, sequenceNumber}) {
  const plan = getReadingPlan(job);
  const passages = [];
  const allQuestions = [];
  const usedModels = [];
  let questionOffset = 0;

  for (let passageIndex = 0;
    passageIndex < plan.passageCount;
    passageIndex++) {
    const generated = await generateReadingPassage({
      ai,
      job,
      passageNumber: passageIndex + 1,
      questionCount: plan.questionCounts[passageIndex],
      questionOffset,
      sequenceNumber,
      fullTest: plan.fullTest,
    });

    passages.push(generated.passage);
    allQuestions.push(...generated.questions);
    usedModels.push(generated.model);
    questionOffset += plan.questionCounts[passageIndex];
  }

  const primaryModel = usedModels[0] || GEMINI_MODELS[0];
  const titlePrefix = job.ieltsType === "General Training" ?
    "General Training" :
    "Academic";

  return {
    model: primaryModel,
    test: {
      title: String(
          job.title ||
          `${titlePrefix} Reading ${plan.fullTest ? "Full Test" : "Practice"}`,
      ),
      description: String(
          job.description ||
          "AI-generated IELTS-style reading practice with detailed analytics.",
      ),
      ieltsType: job.ieltsType || "Academic",
      mode: normalizeReadingMode(job.mode || "passage"),
      difficulty: job.difficulty || "Intermediate",
      questionType: plan.questionType || null,
      primaryQuestionType: plan.questionType || null,
      questionTypeKey: plan.questionType ?
        toReadingQuestionTypeKey(plan.questionType) :
        null,
      questionTypes: collectReadingQuestionTypes(allQuestions),
      questionTypeKeys: collectReadingQuestionTypes(allQuestions)
          .map(toReadingQuestionTypeKey),
      durationSeconds: plan.durationSeconds,
      totalQuestions: allQuestions.length,
      totalPassages: passages.length,
      fullTest: plan.fullTest,
      toolsEnabled: plan.toolsEnabled !== false,
      speedReading: Boolean(plan.speedReading),
      targetWordsPerMinute: plan.speedReading ? 220 : null,
      passages,
      questions: allQuestions,
      recommendedPractice: buildReadingRecommendations(allQuestions),
    },
  };
}

async function generateReadingPassage({
  ai,
  job,
  passageNumber,
  questionCount,
  questionOffset,
  sequenceNumber,
  fullTest,
}) {
  const ieltsType = job.ieltsType || "Academic";
  const questionType = planQuestionType(job);
  const difficulty = job.difficulty || "Intermediate";
  const failures = [];

  for (let attempt = 1;
    attempt <= MAX_READING_PASSAGE_ATTEMPTS;
    attempt++) {
    try {
      const prompt = buildReadingPrompt({
        ieltsType,
        mode: normalizeReadingMode(job.mode),
        difficulty,
        passageNumber,
        questionCount,
        questionOffset,
        questionType,
        sequenceNumber: sequenceNumber * 10 + attempt,
        fullTest,
      });

      const result = await callGeminiWithRetry(ai, {
        contents: prompt,
        config: {
          temperature: 0.45,
          maxOutputTokens: 14000,
          responseMimeType: "application/json",
        },
      });

      const response = result.response;
      if (!response.text) {
        throw new Error("Gemini returned an empty reading response.");
      }

      const parsed = await parseReadingJsonWithRepair({
        ai,
        rawText: response.text,
        sourceModel: result.model,
      });

      const passage = normalizeReadingPassage(
          parsed.passage || parsed,
          passageNumber,
          ieltsType,
          difficulty,
      );

      const questions = normalizeReadingQuestions(
          parsed.questions,
          passageNumber,
          questionOffset,
          questionCount,
          questionType,
      );

      const passageValidation = validateGeneratedReadingPassage({
        passage,
        questions,
        expectedQuestionCount: questionCount,
        requestedType: questionType,
      });

      if (!passageValidation.isValid) {
        throw new Error(
            `Generated passage validation failed: ` +
            passageValidation.errors.join(" | "),
        );
      }

      return {
        passage,
        questions,
        model: result.model,
      };
    } catch (error) {
      const message = safeErrorMessage(error);
      failures.push(`Attempt ${attempt}: ${message}`);

      logger.warn("Reading passage generation attempt failed.", {
        passageNumber,
        attempt,
        error: message,
      });

      if (isPermanentQuotaError(error) ||
          attempt === MAX_READING_PASSAGE_ATTEMPTS) {
        break;
      }

      await sleep(1000 * attempt);
    }
  }

  throw new Error(
      `Unable to generate Reading passage ${passageNumber}. ` +
      failures.join(" || "),
  );
}

async function parseReadingJsonWithRepair({
  ai,
  rawText,
  sourceModel,
}) {
  const cleanedJson = cleanGeminiJson(rawText);

  try {
    return JSON.parse(cleanedJson);
  } catch (firstError) {
    logger.warn("Gemini returned malformed reading JSON.", {
      sourceModel,
      responseLength: String(rawText || "").length,
      cleanedLength: cleanedJson.length,
      error: safeErrorMessage(firstError),
    });
  }

  const locallyRepaired = repairCommonJsonFormatting(cleanedJson);

  try {
    const parsed = JSON.parse(locallyRepaired);

    logger.info("Reading JSON repaired locally.", {
      sourceModel,
      repairedLength: locallyRepaired.length,
    });

    return parsed;
  } catch (localRepairError) {
    logger.warn("Local reading JSON repair was insufficient.", {
      sourceModel,
      error: safeErrorMessage(localRepairError),
    });
  }

  const repairedJson = await repairReadingJsonWithGemini({
    ai,
    brokenJson: locallyRepaired,
    sourceModel,
  });

  try {
    const parsed = JSON.parse(repairedJson);

    logger.info("Reading JSON repaired by Gemini.", {
      sourceModel,
      repairedLength: repairedJson.length,
    });

    return parsed;
  } catch (finalError) {
    throw new Error(
        "Gemini returned invalid reading JSON even after automatic repair: " +
        safeErrorMessage(finalError),
    );
  }
}


function cleanGeminiJson(rawText) {
  let text = String(rawText || "")
      .replace(/^\uFEFF/, "")
      .replace(/```json/gi, "")
      .replace(/```javascript/gi, "")
      .replace(/```js/gi, "")
      .replace(/```/g, "")
      .trim();

  const firstBrace = text.indexOf("{");
  const lastBrace = text.lastIndexOf("}");

  if (firstBrace >= 0 && lastBrace > firstBrace) {
    text = text.substring(firstBrace, lastBrace + 1);
  }

  return text
      .replace(
          // eslint-disable-next-line no-control-regex
          /[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g,
          "",
      )
      .trim();
}


function repairCommonJsonFormatting(rawJson) {
  return String(rawJson || "")
      .replace(/,\s*([}\]])/g, "$1")
      .replace(/[“”]/g, '"')
      .replace(/[‘’]/g, "'")
      .trim();
}

async function repairReadingJsonWithGemini({
  ai,
  brokenJson,
  sourceModel,
}) {
  const repairPrompt = `
Repair the malformed JSON below.

STRICT RULES
1. Return JSON only.
2. Do not wrap the response in markdown code fences.
3. Preserve all passage and question information.
4. Fix syntax only: missing commas, extra commas, quotation marks,
   escaping, brackets, braces, and truncated structural punctuation.
5. Keep this top-level structure:
   {
     "passage": {...},
     "questions": [...]
   }
6. Do not add commentary before or after the JSON.
7. The result must be directly parseable by JSON.parse().

SOURCE MODEL
${sourceModel}

MALFORMED JSON
${brokenJson}
`;

  const repairResult = await callGeminiWithRetry(ai, {
    contents: repairPrompt,
    config: {
      temperature: 0,
      maxOutputTokens: 12000,
      responseMimeType: "application/json",
    },
  });

  const repairedText = repairResult.response.text;

  if (!repairedText) {
    throw new Error("Gemini JSON repair returned an empty response.");
  }

  logger.info("Gemini completed reading JSON repair.", {
    sourceModel,
    repairModel: repairResult.model,
    repairedResponseLength: repairedText.length,
  });

  return repairCommonJsonFormatting(
      cleanGeminiJson(repairedText),
  );
}


function buildReadingPrompt({
  ieltsType,
  mode,
  difficulty,
  passageNumber,
  questionCount,
  questionOffset,
  questionType,
  sequenceNumber,
  fullTest,
}) {
  const contextRules = ieltsType === "General Training" ?
    generalTrainingPassageRules(passageNumber) :
    academicPassageRules(passageNumber);

  const normalizedType = normalizeReadingQuestionType(questionType);
  const questionRule = normalizedType ?
    `Create every question as "${normalizedType}".` :
    "Use a balanced mixture of valid IELTS Reading question types.";
  const modeRules = readingModeRules(mode);
  const typeRules = readingQuestionTypeRules(normalizedType);

  return `
Create one completely original IELTS-style Reading passage and its questions.

This is independent practice material. Do not copy, quote, reproduce, or
closely paraphrase official IELTS, Cambridge, British Council, IDP,
newspapers, books, websites, or other copyrighted passages.

SETTINGS
- IELTS type: ${ieltsType}
- Mode: ${mode}
- Difficulty: ${difficulty}
- Passage number: ${passageNumber}
- Questions required: ${questionCount}
- First global question number: ${questionOffset + 1}
- Last global question number: ${questionOffset + questionCount}
- Full test: ${fullTest}
- Unique generation seed: ${sequenceNumber}

MODE RULES
${modeRules}

PASSAGE RULES
${contextRules}

QUESTION DESIGN
- ${questionRule}
- Allowed types are exactly:
  Multiple choice
  True / False / Not Given
  Yes / No / Not Given
  Matching headings
  Matching information
  Matching features
  Sentence endings
  Summary completion
  Sentence completion
  Note completion
  Table completion
  Flowchart completion
  Diagram labels
  Short answers
${typeRules}

STRICT VALIDATION RULES
1. Return exactly ${questionCount} questions.
2. Number questions globally from ${questionOffset + 1} to
   ${questionOffset + questionCount}, without gaps or duplicates.
3. Every answer must be fully supported by the passage.
4. Every question must include a non-empty prompt, correctAnswer,
   acceptedAnswers, explanation, evidenceText, paragraphIndex, and keywords.
5. evidenceText must be a short verbatim excerpt that exists in the passage.
6. paragraphIndex is zero-based and must identify the evidence paragraph.
7. For selectable questions, correctAnswer must equal one complete option.
8. For text-entry questions, options must be [] and wordLimit must be set.
9. Do not place the correct answer visibly inside a completion blank.
10. Avoid ambiguity, outside knowledge, trick wording, and duplicated prompts.
11. Use original topics, names, numbers, organizations, and examples.
12. The passage must contain enough information for every question.
13. Output JSON only. Do not use markdown fences or commentary.

Return exactly this JSON shape:
{
  "passage": {
    "title": "string",
    "topic": "string",
    "text": "paragraph 1\\n\\nparagraph 2\\n\\nparagraph 3",
    "simplifiedExplanation": "plain-English passage explanation",
    "synonyms": {
      "important passage word": ["synonym 1", "synonym 2"]
    }
  },
  "questions": [
    {
      "number": ${questionOffset + 1},
      "type": "${normalizedType || "Multiple choice"}",
      "prompt": "complete visible question text",
      "options": ["option 1", "option 2", "option 3", "option 4"],
      "correctAnswer": "complete correct option or concise text answer",
      "acceptedAnswers": ["correct answer"],
      "explanation": "why the answer is correct",
      "evidenceText": "exact supporting excerpt from the passage",
      "paragraphIndex": 0,
      "keywords": ["locator word", "paraphrase"],
      "wordLimit": ""
    }
  ]
}
`;
}

function readingModeRules(mode) {
  switch (normalizeReadingMode(mode)) {
    case "academic":
      return "- Build a complete Academic Reading test with increasing difficulty.";
    case "general":
      return "- Build a complete General Training Reading test using practical, workplace, and general-interest texts.";
    case "full":
    case "exam":
      return "- This passage belongs to a strict 60-minute, 40-question full test. Do not include hints in question wording.";
    case "timed":
      return "- Create a focused 20-minute passage containing 13 exam-standard questions.";
    case "speed":
      return "- Create a concise passage suitable for words-per-minute training, followed by 5 comprehension checks.";
    case "question_type":
      return "- All questions must use only the selected question type.";
    case "passage":
    case "practice":
    default:
      return "- Create one focused passage-practice activity with learning support.";
  }
}

function readingQuestionTypeRules(questionType) {
  const type = normalizeReadingQuestionType(questionType);
  if (!type) {
    return `
- Use 2 to 4 suitable question types.
- Keep questions grouped by type, as in a real IELTS Reading paper.
`;
  }

  if (type === "Multiple choice") {
    return `
- Every question must have exactly four unique options.
- Do not prefix options with letters.
- correctAnswer must exactly equal one complete option.
`;
  }

  if (type === "True / False / Not Given") {
    return `
- options must be exactly ["True", "False", "Not Given"].
- Use True for agreement with factual passage information.
- Use False for direct contradiction.
- Use Not Given only when the passage does not state the information.
`;
  }

  if (type === "Yes / No / Not Given") {
    return `
- options must be exactly ["Yes", "No", "Not Given"].
- Test the writer's views or claims, not simple factual details.
`;
  }

  if (type === "Matching headings") {
    return `
- Each prompt must identify one paragraph to match.
- Provide 5 to 8 reusable heading options for every question.
- Include plausible extra headings.
`;
  }

  if (type === "Matching information" || type === "Matching features") {
    return `
- Provide 4 to 8 reusable labelled options for every question.
- correctAnswer must exactly equal one option.
- State clearly what must be matched.
`;
  }

  if (type === "Sentence endings") {
    return `
- Each prompt must be an incomplete sentence beginning.
- Provide 4 to 7 possible endings.
- correctAnswer must exactly equal one ending.
`;
  }

  if (type === "Summary completion" ||
      type === "Sentence completion" ||
      type === "Note completion" ||
      type === "Table completion" ||
      type === "Flowchart completion") {
    return `
- options must be [].
- Every prompt must contain a visible blank: __________.
- Provide a realistic wordLimit such as NO MORE THAN TWO WORDS.
- correctAnswer must be concise and must fit grammatically in the blank.
`;
  }

  if (type === "Diagram labels") {
    return `
- Represent each diagram label as a text-selectable question.
- Provide 4 to 7 concise label options for every question.
- correctAnswer must exactly equal one option.
`;
  }

  return `
- Use short-answer text entry.
- options must be [].
- Include a realistic wordLimit.
- correctAnswer must be concise and unambiguous.
`;
}

function academicPassageRules(passageNumber) {
  const level = passageNumber === 1 ?
    "accessible academic" :
    passageNumber === 2 ?
      "moderately complex academic" :
      "advanced academic";

  return `
- Write an original ${level} passage.
- Suitable topics include science, history, environment, technology,
  psychology, education, architecture, culture, or research.
- Use ${passageNumber === 1 ? "750-900" : "850-1050"} words.
- Use 7-11 well-structured paragraphs.
- Difficulty must increase with passage number.
`;
}

function generalTrainingPassageRules(passageNumber) {
  if (passageNumber === 1) {
    return `
- Create 2-3 short practical texts such as notices, advertisements,
  timetables, public information, local services, or instructions.
- Combine them into one passage separated by clear headings.
- Use 500-700 words total.
`;
  }

  if (passageNumber === 2) {
    return `
- Create workplace-related texts such as policies, job descriptions,
  staff guidance, training materials, or procedures.
- Use 650-850 words total.
`;
  }

  return `
- Create one long general-interest passage.
- Use 850-1050 words and 8-11 paragraphs.
- The tone should be informative and increasingly complex.
`;
}

function normalizeReadingPassage(
    raw,
    passageNumber,
    ieltsType,
    difficulty,
) {
  const text = String(raw.text || "").trim();
  const paragraphs = text
      .split(/\n\s*\n/)
      .map((value) => value.trim())
      .filter(Boolean);

  const synonyms = raw.synonyms && typeof raw.synonyms === "object" ?
    raw.synonyms :
    {};

  return {
    passageId: `passage_${passageNumber}`,
    passageNumber,
    title: String(raw.title || `Passage ${passageNumber}`).trim(),
    topic: String(raw.topic || "General").trim(),
    text,
    paragraphs,
    wordCount: text.split(/\s+/).filter(Boolean).length,
    difficulty,
    ieltsType,
    simplifiedExplanation: String(
        raw.simplifiedExplanation ||
        "Read the passage carefully and identify its main argument.",
    ).trim(),
    synonyms,
  };
}

function normalizeReadingQuestions(
    rawQuestions,
    passageNumber,
    questionOffset,
    expectedCount,
    requestedType,
) {
  const source = Array.isArray(rawQuestions) ? rawQuestions : [];
  const normalizedRequestedType =
    normalizeReadingQuestionType(requestedType);

  return source.slice(0, expectedCount).map((question, index) => {
    const type = normalizeReadingQuestionType(
        question.type ||
        question.questionType ||
        normalizedRequestedType ||
        "Short answers",
    );

    let options = normalizeOptions(
        question.options || question.choices || question.headings,
    );

    if (type === "True / False / Not Given") {
      options = ["True", "False", "Not Given"];
    } else if (type === "Yes / No / Not Given") {
      options = ["Yes", "No", "Not Given"];
    }

    const rawAnswer =
      question.correctAnswer ??
      question.answer ??
      question.correct ??
      question.expectedAnswer;

    let correctAnswer = normalizeCorrectAnswer(rawAnswer, options);

    if ((type === "True / False / Not Given" ||
         type === "Yes / No / Not Given") &&
        correctAnswer) {
      correctAnswer = normalizeReadingLabelAnswer(correctAnswer, type);
    }

    const rawPrompt =
      question.prompt ??
      question.question ??
      question.sentence ??
      question.stem ??
      question.statement ??
      question.text ??
      "";

    const prompt = normalizeReadingPrompt({
      prompt: rawPrompt,
      type,
      correctAnswer,
      number: questionOffset + index + 1,
    });

    const acceptedAnswers = normalizeAcceptedAnswers(
        question.acceptedAnswers || question.alternativeAnswers,
        correctAnswer,
        options,
    );

    return {
      number: questionOffset + index + 1,
      passageNumber,
      type,
      prompt,
      options: isReadingSelectionType(type) ? options : [],
      correctAnswer,
      acceptedAnswers,
      explanation: String(
          question.explanation ||
          question.reason ||
          `The passage directly supports "${correctAnswer}".`,
      ).trim(),
      evidenceText: String(
          question.evidenceText ||
          question.evidence ||
          question.sourceText ||
          "",
      ).trim(),
      paragraphIndex: clampNumber(
          question.paragraphIndex,
          0,
          30,
          0,
      ),
      keywords: normalizeStringArray(question.keywords),
      wordLimit: isReadingSelectionType(type) ?
        "" :
        String(
            question.wordLimit ||
            question.instruction ||
            "NO MORE THAN THREE WORDS",
        ).trim(),
    };
  });
}

function normalizeReadingPrompt({
  prompt,
  type,
  correctAnswer,
  number,
}) {
  let value = String(prompt || "").trim();

  if (!value) return "";

  value = value
      .replace(/\[\s*blank\s*\]/gi, "__________")
      .replace(/<\s*blank\s*>/gi, "__________")
      .replace(/\{\s*blank\s*\}/gi, "__________");

  if (isReadingCompletionType(type)) {
    const answer = String(correctAnswer || "").trim();
    if (answer && !value.includes("_____")) {
      const answerPattern = new RegExp(escapeRegExp(answer), "i");
      if (answerPattern.test(value)) {
        value = value.replace(answerPattern, "__________");
      } else {
        value = `${value} __________`;
      }
    }

    if (!value.includes("_____")) {
      value = `${value} [${number}] __________`;
    }
  }

  return value;
}

function normalizeReadingQuestionType(value) {
  const raw = String(value || "").trim();
  const normalized = raw.toLowerCase()
      .replace(/[_-]+/g, " ")
      .replace(/\s+/g, " ");

  const aliases = new Map([
    ["multiple choice", "Multiple choice"],
    ["true false not given", "True / False / Not Given"],
    ["true / false / not given", "True / False / Not Given"],
    ["yes no not given", "Yes / No / Not Given"],
    ["yes / no / not given", "Yes / No / Not Given"],
    ["matching headings", "Matching headings"],
    ["matching information", "Matching information"],
    ["matching features", "Matching features"],
    ["sentence endings", "Sentence endings"],
    ["summary completion", "Summary completion"],
    ["sentence completion", "Sentence completion"],
    ["note completion", "Note completion"],
    ["table completion", "Table completion"],
    ["flowchart completion", "Flowchart completion"],
    ["flow chart completion", "Flowchart completion"],
    ["diagram labels", "Diagram labels"],
    ["diagram labelling", "Diagram labels"],
    ["diagram labeling", "Diagram labels"],
    ["short answers", "Short answers"],
    ["short answer", "Short answers"],
  ]);

  return aliases.get(normalized) || raw;
}

function toReadingQuestionTypeKey(value) {
  return String(value || "")
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "_")
      .replace(/^_+|_+$/g, "");
}


function collectReadingQuestionTypes(questions) {
  const types = new Set();

  for (const question of Array.isArray(questions) ? questions : []) {
    const type = normalizeReadingQuestionType(
        question?.type || question?.questionType,
    );

    if (type && READING_QUESTION_TYPES.has(type)) {
      types.add(type);
    }
  }

  return Array.from(types);
}


function normalizeReadingMode(value) {
  const normalized = String(value || "passage").trim().toLowerCase()
      .replace(/[\s-]+/g, "_");

  const aliases = new Map([
    ["academic_reading", "academic"],
    ["general_training", "general"],
    ["general_training_reading", "general"],
    ["passage_practice", "passage"],
    ["question_type_practice", "question_type"],
    ["timed_reading", "timed"],
    ["full_reading_test", "full"],
    ["speed_reading", "speed"],
    ["speed_reading_exercise", "speed"],
  ]);

  return aliases.get(normalized) || normalized;
}

function planQuestionType(job) {
  const mode = normalizeReadingMode(job.mode);
  const type = normalizeReadingQuestionType(job.questionType);
  return mode === "question_type" || type ? type : "";
}

function normalizeReadingLabelAnswer(answer, type) {
  const value = normalizeText(answer);
  const labels = type === "True / False / Not Given" ?
    ["True", "False", "Not Given"] :
    ["Yes", "No", "Not Given"];

  return labels.find((label) => normalizeText(label) === value) ||
    String(answer || "").trim();
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) return [];
  return value
      .map((item) => String(item || "").trim())
      .filter(Boolean);
}

function isReadingCompletionType(value) {
  const type = normalizeReadingQuestionType(value);
  return type === "Summary completion" ||
    type === "Sentence completion" ||
    type === "Note completion" ||
    type === "Table completion" ||
    type === "Flowchart completion" ||
    type === "Short answers";
}

function escapeRegExp(value) {
  return String(value || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function validateGeneratedReadingPassage({
  passage,
  questions,
  expectedQuestionCount,
  requestedType,
}) {
  const errors = [];

  if (!passage.text || passage.wordCount < 250) {
    errors.push("Passage text is missing or too short.");
  }

  if (!Array.isArray(questions) ||
      questions.length !== expectedQuestionCount) {
    errors.push(
        `Expected ${expectedQuestionCount} questions, ` +
        `received ${questions?.length || 0}.`,
    );
  }

  for (const question of questions || []) {
    if (!question.prompt) {
      errors.push(`Question ${question.number} has no visible prompt.`);
    }
    if (!question.correctAnswer) {
      errors.push(`Question ${question.number} has no correct answer.`);
    }
    if (requestedType &&
        normalizeReadingQuestionType(question.type) !==
        normalizeReadingQuestionType(requestedType)) {
      errors.push(
          `Question ${question.number} has type "${question.type}" ` +
          `instead of "${requestedType}".`,
      );
    }
    if (isReadingSelectionType(question.type) &&
        question.options.length < 3) {
      errors.push(
          `Question ${question.number} requires at least 3 options.`,
      );
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

function validateReadingTest(test, job) {
  const errors = [];
  const warnings = [];
  let score = 100;
  const plan = getReadingPlan(job);
  const expectedQuestions =
    plan.questionCounts.reduce((sum, value) => sum + value, 0);

  if (!test.title || test.title.length < 8) {
    errors.push("Reading title is missing or too short.");
    score -= 10;
  }

  if (!Array.isArray(test.passages) ||
      test.passages.length !== plan.passageCount) {
    errors.push(
        `Expected ${plan.passageCount} passages, ` +
        `received ${test.passages?.length || 0}.`,
    );
    score -= 25;
  }

  if (!Array.isArray(test.questions) ||
      test.questions.length !== expectedQuestions) {
    errors.push(
        `Expected ${expectedQuestions} reading questions, ` +
        `received ${test.questions?.length || 0}.`,
    );
    score -= 30;
  }

  for (const passage of test.passages || []) {
    if (!passage.text || passage.wordCount < 250) {
      errors.push(`Passage ${passage.passageNumber} is too short.`);
      score -= 10;
    }
  }

  const seenNumbers = new Set();
  const seenPrompts = new Set();

  for (const question of test.questions || []) {
    if (seenNumbers.has(question.number)) {
      errors.push(`Duplicate reading question number ${question.number}.`);
      score -= 5;
    }
    seenNumbers.add(question.number);

    const promptKey = normalizeText(question.prompt);
    if (!promptKey) {
      errors.push(`Reading question ${question.number} has no prompt.`);
      score -= 5;
    } else if (seenPrompts.has(promptKey)) {
      errors.push(`Reading question ${question.number} is duplicated.`);
      score -= 5;
    }
    seenPrompts.add(promptKey);

    if (!question.correctAnswer) {
      errors.push(`Reading question ${question.number} has no answer.`);
      score -= 7;
    }

    if (!question.explanation) {
      warnings.push(
          `Reading question ${question.number} has no explanation.`,
      );
      score -= 2;
    }

    if (!question.evidenceText) {
      warnings.push(
          `Reading question ${question.number} has no evidenceText.`,
      );
      score -= 2;
    }

    if (isReadingSelectionType(question.type)) {
      if (!Array.isArray(question.options) ||
          question.options.length < 3) {
        errors.push(
            `Reading question ${question.number} requires selectable options.`,
        );
        score -= 7;
      } else {
        const normalizedOptions = question.options.map(normalizeText);
        if (!normalizedOptions.includes(normalizeText(
            question.correctAnswer,
        ))) {
          errors.push(
              `Reading question ${question.number} answer is not in options.`,
          );
          score -= 7;
        }

        if (new Set(normalizedOptions).size !== normalizedOptions.length) {
          errors.push(
              `Reading question ${question.number} has duplicate options.`,
          );
          score -= 5;
        }
      }
    } else if (question.options.length > 0) {
      warnings.push(
          `Reading question ${question.number} contains unused options.`,
      );
      score -= 1;
    }

    if (isReadingCompletionType(question.type) &&
        !question.prompt.includes("_____")) {
      errors.push(
          `Completion question ${question.number} has no visible blank.`,
      );
      score -= 5;
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    warnings,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

function isReadingSelectionType(value) {
  const type = normalizeReadingQuestionType(value);
  return type === "Multiple choice" ||
    type === "True / False / Not Given" ||
    type === "Yes / No / Not Given" ||
    type === "Matching headings" ||
    type === "Matching information" ||
    type === "Matching features" ||
    type === "Sentence endings" ||
    type === "Diagram labels";
}

async function findLikelyReadingDuplicate(test) {
  const titleKey = normalizeText(test.title);
  const firstPassage = test.passages?.[0]?.text || "";
  const fingerprint = normalizeText(firstPassage).slice(0, 450);

  const snapshot = await db.collection("reading_tests")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const existingTitle = normalizeText(data.title);
    const existingFingerprint = normalizeText(
        data.passages?.[0]?.text || "",
    ).slice(0, 450);

    const exactTitleAndOpening =
      titleKey &&
      titleKey === existingTitle &&
      fingerprint &&
      fingerprint === existingFingerprint;

    if (exactTitleAndOpening) return doc;
  }

  return null;
}

function buildReadingRecommendations(questions) {
  const counts = {};
  for (const question of questions || []) {
    counts[question.type] = (counts[question.type] || 0) + 1;
  }

  return Object.entries(counts)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([type]) => `Review strategies for ${type}.`);
}
// ============================================================================
// WRITING MODULE
// ============================================================================

const WRITING_TASK_TYPES = new Set([
  "Line graph",
  "Bar chart",
  "Pie chart",
  "Table",
  "Map",
  "Process diagram",
  "Mixed charts",
  "Formal letter",
  "Semi-formal letter",
  "Informal letter",
  "Opinion essay",
  "Discussion essay",
  "Advantages/disadvantages",
  "Problem/solution",
  "Two-part question",
  "Direct question essay",
]);

const WRITING_MODES = new Set([
  "academic_task_1",
  "general_task_1",
  "task_2",
  "lesson",
  "model_answer",
]);

exports.processWritingGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      if (job.contentType !== "writing" || job.status !== "queued") return;

      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;
      const requestedCount = clampNumber(job.requestedCount, 1, 5, 1);
      const validationError = validateWritingGenerationJob(job);

      if (validationError) {
        await jobRef.update({
          status: "failed",
          generatedCount: 0,
          failedCount: requestedCount,
          errorMessage: validationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await jobRef.update({
        status: "generating",
        generatedCount: 0,
        failedCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: FieldValue.delete(),
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdTaskIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        for (let index = 0; index < requestedCount; index++) {
          try {
            logger.info("Generating writing task.", {
              jobId,
              taskNumber: index + 1,
              requestedCount,
            });

            const generated = await generateValidWritingTask({
              ai,
              job,
              sequenceNumber: index + 1,
              jobId,
              taskNumber: index + 1,
            });

            const taskRef = db.collection("writing_tasks").doc();

            await taskRef.set({
              ...generated.task,
              taskId: taskRef.id,
              generationJobId: jobId,
              generatedBy: "gemini",
              generatedModel: generated.model,
              qualityScore: generated.validation.qualityScore,
              validationPassed: true,
              validationErrors: [],
              status: "draft",
              isPublished: false,
              order: Date.now() + index,
              timesAttempted: 0,
              averageBand: 0,
              createdBy: job.createdBy || null,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });

            generatedCount++;
            createdTaskIds.push(taskRef.id);

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (error) {
            failedCount++;
            const message = safeErrorMessage(error);
            errors.push(`Task ${index + 1}: ${message}`);

            logger.error("Writing task generation failed.", {
              jobId,
              taskNumber: index + 1,
              error: message,
            });

            await jobRef.update({
              generatedCount,
              failedCount,
              lastError: message,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }

        await jobRef.update({
          status: generatedCount > 0 ? "completed" : "failed",
          generatedCount,
          failedCount,
          createdTaskIds,
          errors,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        const message = safeErrorMessage(error);

        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: Math.max(failedCount, requestedCount),
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);

exports.processWritingEvaluationJob = onDocumentCreated(
    {
      document: "writing_submissions/{submissionId}",
      secrets: [geminiApiKey],
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const submission = snapshot.data();
      const submissionId = event.params.submissionId;
      const submissionRef = snapshot.ref;

      if (submission.status !== "queued") return;

      const answer = String(submission.answer || "").trim();
      const taskQuestion = String(submission.taskQuestion || "").trim();

      if (!taskQuestion || answer.length < 40) {
        await submissionRef.update({
          status: "failed",
          errorMessage:
            "A valid writing question and a longer answer are required.",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await submissionRef.update({
        status: "evaluating",
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        const evaluation = await evaluateWritingSubmission({
          ai,
          submission,
        });

        await submissionRef.update({
          status: "completed",
          report: evaluation.report,
          evaluatedModel: evaluation.model,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        if (submission.userId) {
          const userRef = db.collection("users").doc(submission.userId);
          const resultRef = userRef.collection("writing_results").doc();

          await resultRef.set({
            resultId: resultRef.id,
            submissionId,
            taskId: submission.taskId || null,
            title: submission.title || "Writing Practice",
            taskCategory: submission.taskCategory || "task_2",
            taskType: submission.taskType || "Opinion essay",
            mode: submission.mode || "practice",
            wordCount: countWords(answer),
            durationUsedSeconds:
              clampNumber(submission.durationUsedSeconds, 0, 7200, 0),
            overallBand: evaluation.report.overallBand,
            taskAchievementBand:
              evaluation.report.taskAchievement.band,
            coherenceBand:
              evaluation.report.coherenceAndCohesion.band,
            lexicalBand:
              evaluation.report.lexicalResource.band,
            grammarBand:
              evaluation.report.grammaticalRangeAndAccuracy.band,
            weakAreas: evaluation.report.actionPlan,
            completedAt: FieldValue.serverTimestamp(),
          });

          await userRef.set({
            writingBand: evaluation.report.overallBand,
            lastWritingResultAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      } catch (error) {
        const message = safeErrorMessage(error);

        logger.error("Writing evaluation failed.", {
          submissionId,
          error: message,
        });

        await submissionRef.update({
          status: "failed",
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);

function validateWritingGenerationJob(job) {
  const category = String(job.taskCategory || "").trim();
  const taskType = String(job.taskType || "").trim();

  if (!WRITING_MODES.has(category)) {
    return `Unsupported writing category: ${category}.`;
  }

  if (category !== "lesson" &&
      category !== "model_answer" &&
      !WRITING_TASK_TYPES.has(taskType)) {
    return `Unsupported writing task type: ${taskType}.`;
  }

  if (category === "academic_task_1" &&
      ![
        "Line graph",
        "Bar chart",
        "Pie chart",
        "Table",
        "Map",
        "Process diagram",
        "Mixed charts",
      ].includes(taskType)) {
    return `${taskType} is not an Academic Task 1 type.`;
  }

  if (category === "general_task_1" &&
      ![
        "Formal letter",
        "Semi-formal letter",
        "Informal letter",
      ].includes(taskType)) {
    return `${taskType} is not a General Training Task 1 type.`;
  }

  if (category === "task_2" &&
      ![
        "Opinion essay",
        "Discussion essay",
        "Advantages/disadvantages",
        "Problem/solution",
        "Two-part question",
        "Direct question essay",
      ].includes(taskType)) {
    return `${taskType} is not a Task 2 essay type.`;
  }

  return null;
}

async function generateValidWritingTask({
  ai,
  job,
  sequenceNumber,
  jobId,
  taskNumber,
}) {
  const failures = [];

  for (let attempt = 1; attempt <= 4; attempt++) {
    try {
      const generated = await generateWritingTask({
        ai,
        job,
        sequenceNumber: sequenceNumber * 10 + attempt,
      });

      const validation = validateWritingTask(generated.task, job);

      if (!validation.isValid) {
        throw new Error(
            `Writing validation failed: ${validation.errors.join(" | ")}`,
        );
      }

      const duplicate = await findLikelyWritingDuplicate(generated.task);
      if (duplicate) {
        throw new Error(
            `Possible duplicate writing task detected: ${duplicate.id}`,
        );
      }

      return {
        ...generated,
        validation,
      };
    } catch (error) {
      const message = safeErrorMessage(error);
      failures.push(`Attempt ${attempt}: ${message}`);

      logger.warn("Writing content attempt failed.", {
        jobId,
        taskNumber,
        attempt,
        error: message,
      });

      if (isPermanentQuotaError(error)) break;
      if (attempt < 5) await sleep(1200 * attempt);
    }
  }

  throw new Error(
      "Unable to create a valid writing task. " + failures.join(" || "),
  );
}

async function generateWritingTask({ai, job, sequenceNumber}) {
  const category = String(job.taskCategory || "task_2");
  const taskType = String(job.taskType || "Opinion essay");
  const difficulty = String(job.difficulty || "Intermediate");

  const prompt = buildWritingTaskPrompt({
    category,
    taskType,
    difficulty,
    sequenceNumber,
  });

  const result = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.65,
      maxOutputTokens: 8000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty writing task response.");
  }

  let parsed;
  try {
    parsed = JSON.parse(
        result.response.text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim(),
    );
  } catch (error) {
    throw new Error(
        `Gemini returned invalid writing JSON: ${safeErrorMessage(error)}`,
    );
  }

  return {
    model: result.model,
    task: normalizeWritingTask(parsed, {
      category,
      taskType,
      difficulty,
    }),
  };
}

function buildWritingTaskPrompt({
  category,
  taskType,
  difficulty,
  sequenceNumber,
}) {
  return `
Create one completely original IELTS-style Writing task.

This is independent preparation content. Do not reproduce, closely paraphrase,
or claim affiliation with Cambridge IELTS, British Council, IDP, or any
official IELTS test.

SETTINGS
- Category: ${category}
- Task type: ${taskType}
- Difficulty: ${difficulty}
- Unique generation sequence: ${sequenceNumber}

${writingCategoryRules(category, taskType)}

STRICT REQUIREMENTS
1. The prompt must be realistic, internationally appropriate and unambiguous.
2. Avoid political persuasion, hate, violence, explicit content and medical
   diagnosis.
3. Provide a detailed task checklist.
4. Provide a Band 8 model answer that directly answers the generated task.
5. The model answer must meet the appropriate word requirement.
6. Provide a paragraph plan and useful vocabulary.
7. For Academic Task 1, include complete chart/map/process data in structured
   JSON so the Flutter app can render a text-based visual description.
8. For General Task 1, clearly state the recipient, situation and three bullet
   points.
9. For Task 2, include a balanced, arguable issue and clear instruction.
10. Output JSON only.

Return exactly:
{
  "title": "string",
  "description": "string",
  "instructions": "string",
  "taskQuestion": "string",
  "taskCategory": "${category}",
  "taskType": "${taskType}",
  "minimumWords": 250,
  "durationSeconds": 2400,
  "checklist": ["string"],
  "planningPoints": ["string"],
  "usefulVocabulary": [
    {"word": "string", "meaning": "string", "example": "string"}
  ],
  "visualData": {
    "title": "string",
    "description": "string",
    "categories": ["string"],
    "series": [
      {"name": "string", "values": [1, 2, 3]}
    ],
    "stages": ["string"],
    "locations": ["string"]
  },
  "band8ModelAnswer": "string",
  "modelAnswerNotes": ["string"],
  "lesson": {
    "overview": "string",
    "structure": ["string"],
    "commonMistakes": ["string"],
    "examTips": ["string"]
  }
}
`;
}

function writingCategoryRules(category, taskType) {
  if (category === "academic_task_1") {
    return `
ACADEMIC TASK 1 RULES
- Generate a ${taskType}.
- minimumWords must be 150.
- durationSeconds must be 1200.
- Require an introduction, a clear overview and selective comparisons.
- Do not ask for opinions or explanations of causes unless the visual itself
  requires process description.
- visualData must contain enough exact figures, stages or map changes for a
  student to write a complete answer.
`;
  }

  if (category === "general_task_1") {
    return `
GENERAL TRAINING TASK 1 RULES
- Generate a ${taskType}.
- minimumWords must be 150.
- durationSeconds must be 1200.
- Include a realistic situation and exactly three bullet points.
- Tone must match the selected letter type.
- The model answer must include a suitable opening and closing.
`;
  }

  if (category === "task_2") {
    return `
WRITING TASK 2 RULES
- Generate a ${taskType}.
- minimumWords must be 250.
- durationSeconds must be 2400.
- The task must support a clear position, logical paragraphing and relevant
  examples.
- The Band 8 answer should be approximately 280-340 words.
`;
  }

  return `
- Create a practical IELTS Writing lesson and model answer resource.
- Include clear examples, common mistakes and an actionable checklist.
`;
}

function normalizeWritingTask(raw, settings) {
  const category = settings.category;
  const minimumWords = category === "task_2" ? 250 : 150;
  const durationSeconds = category === "task_2" ? 2400 : 1200;

  return {
    title: String(raw.title || "").trim(),
    description: String(raw.description || "").trim(),
    instructions: String(raw.instructions || "").trim(),
    taskQuestion: String(raw.taskQuestion || "").trim(),
    taskCategory: category,
    taskType: settings.taskType,
    difficulty: settings.difficulty,
    minimumWords: clampNumber(
        raw.minimumWords,
        minimumWords,
        minimumWords,
        minimumWords,
    ),
    durationSeconds: clampNumber(
        raw.durationSeconds,
        durationSeconds,
        durationSeconds,
        durationSeconds,
    ),
    checklist: cleanStringArray(raw.checklist),
    planningPoints: cleanStringArray(raw.planningPoints),
    usefulVocabulary: Array.isArray(raw.usefulVocabulary) ?
      raw.usefulVocabulary.map((item) => ({
        word: String(item?.word || "").trim(),
        meaning: String(item?.meaning || "").trim(),
        example: String(item?.example || "").trim(),
      })).filter((item) => item.word) :
      [],
    visualData: normalizeWritingVisualData(raw.visualData),
    band8ModelAnswer: String(raw.band8ModelAnswer || "").trim(),
    modelAnswerNotes: cleanStringArray(raw.modelAnswerNotes),
    lesson: {
      overview: String(raw.lesson?.overview || "").trim(),
      structure: cleanStringArray(raw.lesson?.structure),
      commonMistakes: cleanStringArray(raw.lesson?.commonMistakes),
      examTips: cleanStringArray(raw.lesson?.examTips),
    },
    modes: ["practice", "draft", "exam"],
  };
}

function normalizeWritingVisualData(value) {
  const raw = value && typeof value === "object" ? value : {};
  return {
    title: String(raw.title || "").trim(),
    description: String(raw.description || "").trim(),
    categories: cleanStringArray(raw.categories),
    series: Array.isArray(raw.series) ?
      raw.series.map((item) => ({
        name: String(item?.name || "").trim(),
        values: Array.isArray(item?.values) ?
          item.values.map((number) => Number(number) || 0) :
          [],
      })).filter((item) => item.name) :
      [],
    stages: cleanStringArray(raw.stages),
    locations: cleanStringArray(raw.locations),
  };
}

function cleanStringArray(value) {
  return Array.isArray(value) ?
    value.map((item) => String(item || "").trim()).filter(Boolean) :
    [];
}

function validateWritingTask(task, job) {
  const errors = [];
  let score = 100;

  if (!task.title || task.title.length < 8) {
    errors.push("Writing title is missing or too short.");
    score -= 10;
  }

  if (!task.taskQuestion || task.taskQuestion.length < 50) {
    errors.push("Writing task question is too short.");
    score -= 25;
  }

  if (!Array.isArray(task.checklist) || task.checklist.length < 4) {
    errors.push("Writing checklist requires at least four items.");
    score -= 10;
  }

  if (!task.band8ModelAnswer ||
      countWords(task.band8ModelAnswer) < task.minimumWords) {
    errors.push("Band 8 model answer does not meet the word requirement.");
    score -= 25;
  }

  if (job.taskCategory === "academic_task_1" &&
      !task.visualData.description &&
      task.visualData.series.length === 0 &&
      task.visualData.stages.length === 0 &&
      task.visualData.locations.length === 0) {
    errors.push("Academic Task 1 requires usable visual data.");
    score -= 20;
  }

  if (!task.lesson.overview ||
      task.lesson.structure.length < 2 ||
      task.lesson.examTips.length < 2) {
    errors.push("Writing lesson guidance is incomplete.");
    score -= 10;
  }

  return {
    isValid: errors.length === 0,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

async function findLikelyWritingDuplicate(task) {
  const titleKey = normalizeText(task.title);
  const questionKey = normalizeText(task.taskQuestion).slice(0, 350);

  const snapshot = await db.collection("writing_tasks")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const sameTitle = normalizeText(data.title) === titleKey;
    const sameQuestion =
      normalizeText(data.taskQuestion).slice(0, 350) === questionKey;

    if (sameTitle && sameQuestion) return doc;
  }

  return null;
}

async function evaluateWritingSubmission({ai, submission}) {
  const answer = String(submission.answer || "").trim();
  const taskQuestion = String(submission.taskQuestion || "").trim();
  const category = String(submission.taskCategory || "task_2");
  const taskType = String(submission.taskType || "Opinion essay");
  const minimumWords = category === "task_2" ? 250 : 150;

  const prompt = `
Act as a careful IELTS Writing evaluator.

Evaluate the response using the four public IELTS Writing criteria. This is an
estimated educational score, not an official IELTS result.

TASK CATEGORY: ${category}
TASK TYPE: ${taskType}
MINIMUM WORDS: ${minimumWords}

TASK QUESTION
${taskQuestion}

CANDIDATE ANSWER
${answer}

ASSESSMENT RULES
1. Evaluate only the supplied answer against the supplied task.
2. Use half-band increments from 0 to 9.
3. For Task 1 use Task Achievement. For Task 2 use Task Response.
4. Check whether an Academic Task 1 overview is present.
5. Identify grammar errors, repeated vocabulary, informal words and weak
   paragraphs.
6. Give sentence-by-sentence corrections without inventing extra errors.
7. Create an improved answer preserving the candidate's main ideas.
8. Create a practical action plan.
9. Return JSON only.

Return exactly:
{
  "overallBand": 6.5,
  "summary": "string",
  "wordCount": ${countWords(answer)},
  "minimumWordsMet": true,
  "taskAchievement": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "coherenceAndCohesion": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "lexicalResource": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "grammaticalRangeAndAccuracy": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "grammarErrors": [
    {
      "original": "string",
      "correction": "string",
      "explanation": "string"
    }
  ],
  "repeatedVocabulary": [
    {
      "word": "string",
      "count": 3,
      "alternatives": ["string"]
    }
  ],
  "informalWords": [
    {
      "word": "string",
      "formalAlternative": "string"
    }
  ],
  "missingOverview": false,
  "weakParagraphs": [
    {
      "paragraphNumber": 2,
      "issue": "string",
      "suggestion": "string"
    }
  ],
  "sentenceCorrections": [
    {
      "original": "string",
      "improved": "string",
      "reason": "string"
    }
  ],
  "improvedVersion": "string",
  "actionPlan": ["string"]
}
`;

  const result = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.25,
      maxOutputTokens: 10000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty writing evaluation.");
  }

  let parsed;
  try {
    parsed = JSON.parse(
        result.response.text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim(),
    );
  } catch (error) {
    throw new Error(
        `Gemini returned invalid evaluation JSON: ` +
        safeErrorMessage(error),
    );
  }

  return {
    model: result.model,
    report: normalizeWritingReport(parsed, {
      answer,
      minimumWords,
      category,
    }),
  };
}

function normalizeWritingReport(raw, settings) {
  const normalizeCriterion = (value) => ({
    band: normalizeBand(value?.band),
    feedback: String(value?.feedback || "").trim(),
    strengths: cleanStringArray(value?.strengths),
    improvements: cleanStringArray(value?.improvements),
  });

  return {
    overallBand: normalizeBand(raw.overallBand),
    summary: String(raw.summary || "").trim(),
    wordCount: countWords(settings.answer),
    minimumWordsMet: countWords(settings.answer) >= settings.minimumWords,
    taskAchievement: normalizeCriterion(raw.taskAchievement),
    coherenceAndCohesion:
      normalizeCriterion(raw.coherenceAndCohesion),
    lexicalResource: normalizeCriterion(raw.lexicalResource),
    grammaticalRangeAndAccuracy:
      normalizeCriterion(raw.grammaticalRangeAndAccuracy),
    grammarErrors: normalizeObjectArray(raw.grammarErrors, [
      "original",
      "correction",
      "explanation",
    ]),
    repeatedVocabulary: Array.isArray(raw.repeatedVocabulary) ?
      raw.repeatedVocabulary.map((item) => ({
        word: String(item?.word || "").trim(),
        count: clampNumber(item?.count, 1, 100, 1),
        alternatives: cleanStringArray(item?.alternatives),
      })).filter((item) => item.word) :
      [],
    informalWords: normalizeObjectArray(raw.informalWords, [
      "word",
      "formalAlternative",
    ]),
    missingOverview:
      settings.category === "academic_task_1" &&
      Boolean(raw.missingOverview),
    weakParagraphs: Array.isArray(raw.weakParagraphs) ?
      raw.weakParagraphs.map((item) => ({
        paragraphNumber:
          clampNumber(item?.paragraphNumber, 1, 50, 1),
        issue: String(item?.issue || "").trim(),
        suggestion: String(item?.suggestion || "").trim(),
      })).filter((item) => item.issue) :
      [],
    sentenceCorrections:
      normalizeObjectArray(raw.sentenceCorrections, [
        "original",
        "improved",
        "reason",
      ]),
    improvedVersion: String(raw.improvedVersion || "").trim(),
    actionPlan: cleanStringArray(raw.actionPlan),
  };
}

function normalizeObjectArray(value, keys) {
  if (!Array.isArray(value)) return [];

  return value.map((item) => {
    const result = {};
    for (const key of keys) {
      result[key] = String(item?.[key] || "").trim();
    }
    return result;
  }).filter((item) => Object.values(item).some(Boolean));
}

function normalizeBand(value) {
  const parsed = Number(value);
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(9, Math.round(parsed * 2) / 2));
}

function countWords(value) {
  return String(value || "")
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .length;
}

// ============================================================================
// SPEAKING MODULE
// ============================================================================

const SPEAKING_MODES = new Set([
  "ai_partner",
  "full_test",
  "part_1",
  "part_2",
  "part_3",
  "pronunciation",
  "fluency",
  "daily_challenge",
]);

const SPEAKING_PARTS = new Set([1, 2, 3]);

exports.processSpeakingGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      if (job.contentType !== "speaking" || job.status !== "queued") return;

      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;
      const requestedCount = clampNumber(job.requestedCount, 1, 5, 1);
      const validationError = validateSpeakingGenerationJob(job);

      if (validationError) {
        await jobRef.update({
          status: "failed",
          generatedCount: 0,
          failedCount: requestedCount,
          errorMessage: validationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await jobRef.update({
        status: "generating",
        generatedCount: 0,
        failedCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: FieldValue.delete(),
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdTestIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        for (let index = 0; index < requestedCount; index++) {
          try {
            logger.info("Generating speaking test.", {
              jobId,
              testNumber: index + 1,
              requestedCount,
            });

            const generated = await generateValidUniqueSpeakingTest({
              ai,
              job,
              sequenceNumber: index + 1,
              jobId,
              testNumber: index + 1,
            });

            const testRef = db.collection("speaking_tests").doc();
            let modelAudio = {
              modelAudioUrl: null,
              modelAudioStoragePath: null,
              modelAudioStatus: "not_requested",
            };

            const modelText = selectSpeakingModelAudioText(generated.test);
            if (modelText) {
              try {
                modelAudio = await generateSpeakingModelAudio({
                  testId: testRef.id,
                  text: modelText,
                  accent: generated.test.accent,
                });
              } catch (audioError) {
                logger.warn("Speaking model audio generation failed.", {
                  testId: testRef.id,
                  error: safeErrorMessage(audioError),
                });
                modelAudio = {
                  modelAudioUrl: null,
                  modelAudioStoragePath: null,
                  modelAudioStatus: "failed",
                  modelAudioError: safeErrorMessage(audioError),
                };
              }
            }

            await testRef.set({
              ...generated.test,
              ...modelAudio,
              testId: testRef.id,
              generationJobId: jobId,
              generatedBy: "gemini",
              generatedModel: generated.model,
              qualityScore: generated.validation.qualityScore,
              validationPassed: true,
              validationErrors: [],
              status: "draft",
              isPublished: false,
              order: Date.now() + index,
              timesAttempted: 0,
              averageBand: 0,
              createdBy: job.createdBy || null,
              createdAt: FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            });

            generatedCount++;
            createdTestIds.push(testRef.id);

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (error) {
            failedCount++;
            const message = safeErrorMessage(error);
            errors.push(`Test ${index + 1}: ${message}`);

            logger.error("Speaking test generation failed.", {
              jobId,
              testNumber: index + 1,
              error: message,
            });

            await jobRef.update({
              generatedCount,
              failedCount,
              lastError: message,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }

        await jobRef.update({
          status: generatedCount > 0 ? "completed" : "failed",
          generatedCount,
          failedCount,
          createdTestIds,
          errors,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      } catch (error) {
        const message = safeErrorMessage(error);
        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: Math.max(failedCount, requestedCount),
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);

exports.processSpeakingEvaluationJob = onDocumentCreated(
    {
      document: "speaking_submissions/{submissionId}",
      secrets: [geminiApiKey],
      retry: false,
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const submission = snapshot.data();
      if (submission.status !== "queued") return;

      const submissionId = event.params.submissionId;
      const submissionRef = snapshot.ref;
      const storagePath = String(submission.audioStoragePath || "").trim();

      if (!storagePath) {
        await submissionRef.update({
          status: "failed",
          errorMessage: "Audio storage path is required.",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await submissionRef.update({
        status: "evaluating",
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      try {
        const audioFile = bucket.file(storagePath);
        const [exists] = await audioFile.exists();
        if (!exists) throw new Error("Recorded speaking audio was not found.");

        const [metadata] = await audioFile.getMetadata();
        const sizeBytes = Number(metadata.size || 0);
        if (sizeBytes > 20 * 1024 * 1024) {
          throw new Error("Speaking recording exceeds the 20 MB limit.");
        }

        const [audioBuffer] = await audioFile.download();
        if (!audioBuffer || audioBuffer.length === 0) {
          throw new Error("Recorded speaking audio is empty.");
        }

        const mimeType = String(
            submission.audioMimeType ||
            metadata.contentType ||
            "audio/mp4",
        );

        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        const evaluation = await evaluateSpeakingSubmission({
          ai,
          submission,
          audioBuffer,
          mimeType,
        });

        await submissionRef.update({
          status: "completed",
          report: evaluation.report,
          evaluatedModel: evaluation.model,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        if (submission.userId) {
          const userRef = db.collection("users").doc(submission.userId);
          const resultRef = userRef.collection("speaking_results").doc();

          await resultRef.set({
            resultId: resultRef.id,
            submissionId,
            testId: submission.testId || null,
            title: submission.title || "Speaking Practice",
            mode: submission.mode || "part_1",
            part: clampNumber(submission.part, 0, 3, 0),
            overallBand: evaluation.report.overallBand,
            fluencyBand: evaluation.report.fluencyAndCoherence.band,
            lexicalBand: evaluation.report.lexicalResource.band,
            grammarBand:
              evaluation.report.grammaticalRangeAndAccuracy.band,
            pronunciationBand: evaluation.report.pronunciation.band,
            speakingSpeedWpm: evaluation.report.speakingSpeedWpm,
            pauseCount: evaluation.report.pauseCount,
            fillerCount: evaluation.report.fillerWords.length,
            durationSeconds:
              clampNumber(submission.durationSeconds, 0, 1200, 0),
            actionPlan: evaluation.report.actionPlan,
            completedAt: FieldValue.serverTimestamp(),
          });

          await userRef.set({
            speakingBand: evaluation.report.overallBand,
            lastSpeakingResultAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          }, {merge: true});
        }
      } catch (error) {
        const message = safeErrorMessage(error);
        logger.error("Speaking evaluation failed.", {
          submissionId,
          error: message,
        });

        await submissionRef.update({
          status: "failed",
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);

function validateSpeakingGenerationJob(job) {
  const mode = String(job.mode || "part_1").trim().toLowerCase();
  const part = clampNumber(job.part, 0, 3, 0);

  if (!SPEAKING_MODES.has(mode)) {
    return `Unsupported speaking mode: ${mode}.`;
  }

  if (part > 0 && !SPEAKING_PARTS.has(part)) {
    return `Unsupported speaking part: ${part}.`;
  }

  return null;
}

async function generateValidUniqueSpeakingTest({
  ai,
  job,
  sequenceNumber,
  jobId,
  testNumber,
}) {
  const failures = [];

  for (let attempt = 1; attempt <= 5; attempt++) {
    try {
      const generated = await generateSpeakingTest({
        ai,
        job,
        sequenceNumber: sequenceNumber * 10 + attempt,
      });

      const validation = validateSpeakingTest(generated.test, job);
      if (!validation.isValid) {
        throw new Error(
            `Speaking validation failed: ${validation.errors.join(" | ")}`,
        );
      }

      const duplicate = await findLikelySpeakingDuplicate(generated.test);
      if (duplicate) {
        throw new Error(
            `Possible duplicate speaking test detected: ${duplicate.id}`,
        );
      }

      return {
        ...generated,
        validation,
      };
    } catch (error) {
      const message = safeErrorMessage(error);
      failures.push(`Attempt ${attempt}: ${message}`);

      logger.warn("Speaking content attempt failed.", {
        jobId,
        testNumber,
        attempt,
        error: message,
      });

      if (isPermanentQuotaError(error)) break;
      if (attempt < 5) await sleep(1200 * attempt);
    }
  }

  const finalFailure = failures[failures.length - 1] ||
    "No valid response was returned.";
  throw new Error(
      `Unable to create a valid speaking test after 5 attempts. ${finalFailure}`,
  );
}

async function generateSpeakingTest({ai, job, sequenceNumber}) {
  const mode = String(job.mode || "part_1").trim().toLowerCase();
  const accent = String(job.accent || "British").trim();
  const difficulty = String(job.difficulty || "Intermediate").trim();
  const requestedPart = clampNumber(job.part, 0, 3, 0);

  const prompt = buildSpeakingPrompt({
    mode,
    accent,
    difficulty,
    requestedPart,
    sequenceNumber,
  });

  const result = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.65,
      maxOutputTokens: 10000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty speaking response.");
  }

  let parsed;
  try {
    const cleanedResponse = String(result.response.text || "")
        .replace(/```json/gi, "")
        .replace(/```/g, "")
        .trim();
    const start = cleanedResponse.indexOf("{");
    const end = cleanedResponse.lastIndexOf("}");
    if (start === -1 || end === -1 || end <= start) {
      throw new Error("Gemini did not return a JSON object.");
    }
    parsed = JSON.parse(cleanedResponse.substring(start, end + 1));
  } catch (error) {
    throw new Error(
        `Gemini returned invalid speaking JSON: ${safeErrorMessage(error)}`,
    );
  }

  return {
    model: result.model,
    test: normalizeSpeakingTest(parsed, {
      mode,
      accent,
      difficulty,
      requestedPart,
    }),
  };
}

function buildSpeakingPrompt({
  mode,
  accent,
  difficulty,
  requestedPart,
  sequenceNumber,
}) {
  return `
Create one completely original IELTS-style Speaking practice activity.

This is independent preparation material. Do not copy or closely paraphrase
Cambridge IELTS, British Council, IDP, or any official test.

SETTINGS
- Mode: ${mode}
- Requested part: ${requestedPart || "automatic"}
- Difficulty: ${difficulty}
- Examiner accent: ${accent}
- Unique sequence: ${sequenceNumber}

IELTS FORMAT
- Part 1: introduction and familiar questions, approximately 4–5 minutes.
- Part 2: one cue card, 1-minute preparation, notes, and up to 2 minutes speaking.
- Part 3: abstract follow-up discussion, approximately 4–5 minutes.
- Full test must contain all three parts in order.

MODE-SPECIFIC REQUIREMENTS
${speakingModeRules(mode, requestedPart)}

QUALITY REQUIREMENTS
1. Questions must be natural, clear, culturally neutral and internationally suitable.
2. Part 1 questions must be familiar and personal but not intrusive.
3. Part 2 must include one topic plus EXACTLY FOUR bullet prompts. Store those
   four prompts in the Part 2 question's answerGuide array. The answerGuide array
   must have exactly 4 non-empty strings: never 3, never 5, and never include the
   main cue-card topic as one of the four prompts.
4. Part 3 must logically develop the Part 2 theme with deeper discussion.
5. Include realistic AI follow-up questions.
6. Include concise model answers for practice and shadowing.
7. Include pronunciation targets with stress and intonation guidance written in
   ordinary English, not IPA.
8. Include useful vocabulary, collocations and sentence frames.
9. Do not include unsafe, discriminatory, political persuasion, sexual,
   violent, or medical-diagnosis content.
10. Output JSON only.

Return exactly:
{
  "title": "string",
  "description": "string",
  "mode": "${mode}",
  "accent": "${accent}",
  "difficulty": "${difficulty}",
  "estimatedDurationSeconds": 900,
  "parts": [
    {
      "part": 1,
      "title": "Introduction and Interview",
      "instructions": "string",
      "preparationSeconds": 0,
      "speakingSeconds": 300,
      "questions": [
        {
          "number": 1,
          "question": "string",
          "followUpQuestions": ["string"],
          "modelAnswer": "string",
          "answerGuide": ["string"],
          "usefulVocabulary": ["string"],
          "pronunciationTargets": [
            {
              "word": "string",
              "stressHint": "string",
              "intonationHint": "string"
            }
          ]
        }
      ]
    }
  ],
  "dailyChallenge": {
    "prompt": "string",
    "targetSeconds": 60,
    "focus": "string"
  },
  "pronunciationPractice": {
    "sentences": ["string"],
    "wordStressTips": ["string"],
    "intonationTips": ["string"],
    "shadowingText": "string"
  },
  "fluencyTraining": {
    "prompt": "string",
    "targetSeconds": 120,
    "fillerReductionTips": ["string"],
    "linkingPhrases": ["string"]
  },
  "evaluationFocus": ["string"]
}
`;
}

function speakingModeRules(mode, requestedPart) {
  if (mode === "full_test") {
    return `
- Create Part 1 with 8 questions, Part 2 with one cue card, and Part 3 with
  6 discussion questions.
- Total experience should resemble a complete 11–14 minute speaking test.
`;
  }

  if (mode === "part_1" || requestedPart === 1) {
    return `
- Return only Part 1.
- Create 10 familiar questions across two or three related topics.
`;
  }

  if (mode === "part_2" || requestedPart === 2) {
    return `
- Return only Part 2.
- Create one cue card with exactly four bullet prompts.
- The Part 2 question object MUST use answerGuide for the cue-card bullets.
- answerGuide MUST be a JSON array containing exactly 4 concise strings.
- Example shape: "answerGuide": ["who or what it was", "when and where it happened", "what happened", "why it was important to you"].
- Include 60 seconds preparation and 120 seconds speaking time.
`;
  }

  if (mode === "part_3" || requestedPart === 3) {
    return `
- Return only Part 3.
- Create 8 analytical discussion questions with logical follow-ups.
`;
  }

  if (mode === "pronunciation") {
    return `
- Focus on accent-neutral intelligibility, word stress, sentence stress,
  connected speech and intonation.
- Include 8 short practice sentences and one shadowing passage.
`;
  }

  if (mode === "fluency") {
    return `
- Focus on speaking continuously, reducing fillers and using linking phrases.
- Include one 2-minute prompt and staged fluency drills.
`;
  }

  if (mode === "daily_challenge") {
    return `
- Create one focused 60-second speaking challenge with a clear daily goal.
`;
  }

  return `
- Create an interactive AI Speaking Partner session with 8 questions and
  adaptive follow-up prompts across Parts 1, 2 and 3 difficulty.
`;
}

function normalizeSpeakingTest(raw, settings) {
  const parts = Array.isArray(raw.parts) ?
    raw.parts.map((part, partIndex) => ({
      part: clampNumber(part?.part, 1, 3, partIndex + 1),
      title: String(part?.title || `Part ${partIndex + 1}`).trim(),
      instructions: String(part?.instructions || "").trim(),
      preparationSeconds:
        clampNumber(part?.preparationSeconds, 0, 120, 0),
      speakingSeconds:
        clampNumber(part?.speakingSeconds, 30, 360, 120),
      questions: Array.isArray(part?.questions) ?
        part.questions.map((question, questionIndex) => ({
          number: questionIndex + 1,
          question: String(question?.question || "").trim(),
          followUpQuestions: cleanStringArray(question?.followUpQuestions),
          modelAnswer: String(question?.modelAnswer || "").trim(),
          answerGuide: part?.part === 2 || partIndex === 1 ?
            normalizePart2CuePrompts(question) :
            cleanStringArray(question?.answerGuide),
          usefulVocabulary: cleanStringArray(question?.usefulVocabulary),
          pronunciationTargets:
            normalizePronunciationTargets(question?.pronunciationTargets),
        })) :
        [],
    })) :
    [];

  return {
    title: String(raw.title || "").trim(),
    description: String(raw.description || "").trim(),
    mode: settings.mode,
    accent: settings.accent,
    difficulty: settings.difficulty,
    estimatedDurationSeconds:
      clampNumber(raw.estimatedDurationSeconds, 60, 1800, 600),
    parts,
    dailyChallenge: {
      prompt: String(raw.dailyChallenge?.prompt || "").trim(),
      targetSeconds:
        clampNumber(raw.dailyChallenge?.targetSeconds, 30, 180, 60),
      focus: String(raw.dailyChallenge?.focus || "").trim(),
    },
    pronunciationPractice: {
      sentences: cleanStringArray(raw.pronunciationPractice?.sentences),
      wordStressTips:
        cleanStringArray(raw.pronunciationPractice?.wordStressTips),
      intonationTips:
        cleanStringArray(raw.pronunciationPractice?.intonationTips),
      shadowingText:
        String(raw.pronunciationPractice?.shadowingText || "").trim(),
    },
    fluencyTraining: {
      prompt: String(raw.fluencyTraining?.prompt || "").trim(),
      targetSeconds:
        clampNumber(raw.fluencyTraining?.targetSeconds, 30, 300, 120),
      fillerReductionTips:
        cleanStringArray(raw.fluencyTraining?.fillerReductionTips),
      linkingPhrases:
        cleanStringArray(raw.fluencyTraining?.linkingPhrases),
    },
    evaluationFocus: cleanStringArray(raw.evaluationFocus),
    transcriptVisibleInExam: false,
    recordingReplayEnabled: true,
  };
}

function normalizePart2CuePrompts(question) {
  const direct = cleanStringArray(question?.answerGuide);
  const followUps = cleanStringArray(question?.followUpQuestions);
  const combined = [];
  const seen = new Set();

  for (const value of [...direct, ...followUps]) {
    const cleaned = String(value || "")
        .replace(/^[•*\-–—\d.)\s]+/, "")
        .trim();
    const key = normalizeText(cleaned);
    if (!cleaned || !key || seen.has(key)) continue;
    seen.add(key);
    combined.push(cleaned);
  }

  const fallback = [
    "who or what it was",
    "when and where it happened",
    "what happened or what you did",
    "why it was important or memorable to you",
  ];

  for (const value of fallback) {
    if (combined.length >= 4) break;
    const key = normalizeText(value);
    if (!seen.has(key)) {
      seen.add(key);
      combined.push(value);
    }
  }

  return combined.slice(0, 4);
}

function normalizePronunciationTargets(value) {
  if (!Array.isArray(value)) return [];
  return value.map((item) => ({
    word: String(item?.word || "").trim(),
    stressHint: String(item?.stressHint || "").trim(),
    intonationHint: String(item?.intonationHint || "").trim(),
  })).filter((item) => item.word);
}

function validateSpeakingTest(test, job) {
  const errors = [];
  let score = 100;

  if (!test.title || test.title.length < 8) {
    errors.push("Speaking title is missing or too short.");
    score -= 10;
  }

  if (!Array.isArray(test.parts) || test.parts.length === 0) {
    errors.push("Speaking test has no parts.");
    score -= 30;
  }

  const mode = String(job.mode || "part_1").toLowerCase();
  if (mode === "full_test") {
    const partNumbers = new Set(test.parts.map((part) => part.part));
    if (![1, 2, 3].every((part) => partNumbers.has(part))) {
      errors.push("Full speaking test must include Parts 1, 2 and 3.");
      score -= 25;
    }
  }

  for (const part of test.parts || []) {
    if (!Array.isArray(part.questions) || part.questions.length === 0) {
      errors.push(`Part ${part.part} has no questions.`);
      score -= 15;
      continue;
    }

    for (const question of part.questions) {
      if (!question.question || question.question.length < 8) {
        errors.push(
            `Part ${part.part}, question ${question.number} is invalid.`,
        );
        score -= 5;
      }
    }

    if (part.part === 2) {
      const cueQuestion = part.questions[0];
      if (!cueQuestion || !Array.isArray(cueQuestion.answerGuide) ||
          cueQuestion.answerGuide.length !== 4 ||
          cueQuestion.answerGuide.some((prompt) => !String(prompt).trim())) {
        errors.push("Part 2 cue card must contain exactly four bullet prompts.");
        score -= 15;
      }
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

async function findLikelySpeakingDuplicate(test) {
  const titleKey = normalizeText(test.title);
  const firstQuestion = normalizeText(
      test.parts?.[0]?.questions?.[0]?.question || "",
  );

  const snapshot = await db.collection("speaking_tests")
      .orderBy("createdAt", "desc")
      .limit(100)
      .get();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const existingTitle = normalizeText(data.title);
    const existingQuestion = normalizeText(
        data.parts?.[0]?.questions?.[0]?.question || "",
    );

    if (titleKey && titleKey === existingTitle) return doc;
    if (firstQuestion && firstQuestion === existingQuestion) return doc;
  }

  return null;
}

function selectSpeakingModelAudioText(test) {
  const shadowing = String(
      test.pronunciationPractice?.shadowingText || "",
  ).trim();
  if (shadowing) return shadowing;

  const model = String(
      test.parts?.[0]?.questions?.[0]?.modelAnswer || "",
  ).trim();
  return model;
}

async function generateSpeakingModelAudio({testId, text, accent}) {
  const cleanText = String(text || "").trim();
  if (!cleanText) {
    return {
      modelAudioUrl: null,
      modelAudioStoragePath: null,
      modelAudioStatus: "not_requested",
    };
  }

  const request = {
    input: {text: cleanText.substring(0, 4500)},
    voice: {
      languageCode: "en-GB",
      ssmlGender: "NEUTRAL",
    },
    audioConfig: {
      audioEncoding: "MP3",
      speakingRate: 0.92,
      pitch: 0,
    },
  };

  const [response] = await retryOperation(
      () => ttsClient.synthesizeSpeech(request),
      {
        attempts: MAX_API_RETRIES,
        operationName: "Speaking model audio synthesis",
      },
  );

  if (!response.audioContent) {
    throw new Error("Cloud TTS returned empty speaking model audio.");
  }

  const buffer = Buffer.isBuffer(response.audioContent) ?
    response.audioContent :
    Buffer.from(response.audioContent);

  const storagePath = `speaking_model_audio/${testId}.mp3`;
  const file = bucket.file(storagePath);

  await retryOperation(
      () => file.save(buffer, {
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
      }),
      {
        attempts: MAX_STORAGE_RETRIES,
        operationName: "Speaking model audio upload",
      },
  );

  return {
    modelAudioUrl: await getDownloadURL(file),
    modelAudioStoragePath: storagePath,
    modelAudioStatus: "ready",
  };
}

async function evaluateSpeakingSubmission({
  ai,
  submission,
  audioBuffer,
  mimeType,
}) {
  const questionText = String(submission.questionText || "").trim();
  const mode = String(submission.mode || "part_1").trim();
  const part = clampNumber(submission.part, 0, 3, 0);

  const prompt = `
Act as a careful IELTS Speaking evaluator.

This is an estimated educational assessment, not an official IELTS score.
Listen to the candidate recording and assess only the audible performance.

CONTEXT
- Mode: ${mode}
- Part: ${part || "not specified"}
- Question: ${questionText || "Open speaking practice"}
- Recording duration: ${submission.durationSeconds || 0} seconds

ASSESSMENT CRITERIA
1. Fluency and Coherence
2. Lexical Resource
3. Grammatical Range and Accuracy
4. Pronunciation

ADVANCED ANALYSIS
- Speaking speed in approximate words per minute
- Pauses and unusually long silences
- Fillers
- Repetition
- Answer relevance
- Vocabulary range
- Sentence variety
- Accent-neutral intelligibility
- Word stress
- Intonation
- Likely mispronounced words
- Suggested improvements
- One short shadowing practice sentence

Use half-band increments from 0 to 9.
Do not penalize a natural regional accent. Focus on intelligibility.
Do not invent exact words if the audio is unclear; mark uncertain observations.

Return JSON only:
{
  "overallBand": 6.5,
  "summary": "string",
  "transcript": "string",
  "fluencyAndCoherence": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "lexicalResource": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "grammaticalRangeAndAccuracy": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "pronunciation": {
    "band": 6.5,
    "feedback": "string",
    "strengths": ["string"],
    "improvements": ["string"]
  },
  "speakingSpeedWpm": 120,
  "pauseCount": 5,
  "longPauses": [
    {"approximateTime": "00:15", "observation": "string"}
  ],
  "fillerWords": [
    {"word": "um", "count": 3}
  ],
  "repetitions": ["string"],
  "answerRelevance": {
    "scorePercent": 85,
    "feedback": "string"
  },
  "vocabularyRange": ["string"],
  "sentenceVariety": ["string"],
  "wordStressAnalysis": ["string"],
  "intonationAnalysis": ["string"],
  "mispronouncedWords": [
    {
      "word": "string",
      "heardAs": "string",
      "practiceHint": "string"
    }
  ],
  "shadowingPractice": {
    "text": "string",
    "focus": "string"
  },
  "suggestedImprovements": ["string"],
  "actionPlan": ["string"]
}
`;

  const result = await callGeminiWithRetry(ai, {
    contents: [
      {
        role: "user",
        parts: [
          {text: prompt},
          {
            inlineData: {
              mimeType,
              data: audioBuffer.toString("base64"),
            },
          },
        ],
      },
    ],
    config: {
      temperature: 0.2,
      maxOutputTokens: 10000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty speaking evaluation.");
  }

  let parsed;
  try {
    parsed = JSON.parse(
        result.response.text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim(),
    );
  } catch (error) {
    throw new Error(
        `Gemini returned invalid speaking evaluation JSON: ` +
        safeErrorMessage(error),
    );
  }

  return {
    model: result.model,
    report: normalizeSpeakingReport(parsed),
  };
}

function normalizeSpeakingReport(raw) {
  const criterion = (value) => ({
    band: normalizeBand(value?.band),
    feedback: String(value?.feedback || "").trim(),
    strengths: cleanStringArray(value?.strengths),
    improvements: cleanStringArray(value?.improvements),
  });

  return {
    overallBand: normalizeBand(raw.overallBand),
    summary: String(raw.summary || "").trim(),
    transcript: String(raw.transcript || "").trim(),
    fluencyAndCoherence: criterion(raw.fluencyAndCoherence),
    lexicalResource: criterion(raw.lexicalResource),
    grammaticalRangeAndAccuracy:
      criterion(raw.grammaticalRangeAndAccuracy),
    pronunciation: criterion(raw.pronunciation),
    speakingSpeedWpm:
      clampNumber(raw.speakingSpeedWpm, 0, 300, 0),
    pauseCount: clampNumber(raw.pauseCount, 0, 200, 0),
    longPauses: normalizeObjectArray(raw.longPauses, [
      "approximateTime",
      "observation",
    ]),
    fillerWords: Array.isArray(raw.fillerWords) ?
      raw.fillerWords.map((item) => ({
        word: String(item?.word || "").trim(),
        count: clampNumber(item?.count, 1, 100, 1),
      })).filter((item) => item.word) :
      [],
    repetitions: cleanStringArray(raw.repetitions),
    answerRelevance: {
      scorePercent:
        clampNumber(raw.answerRelevance?.scorePercent, 0, 100, 0),
      feedback: String(raw.answerRelevance?.feedback || "").trim(),
    },
    vocabularyRange: cleanStringArray(raw.vocabularyRange),
    sentenceVariety: cleanStringArray(raw.sentenceVariety),
    wordStressAnalysis: cleanStringArray(raw.wordStressAnalysis),
    intonationAnalysis: cleanStringArray(raw.intonationAnalysis),
    mispronouncedWords:
      normalizeObjectArray(raw.mispronouncedWords, [
        "word",
        "heardAs",
        "practiceHint",
      ]),
    shadowingPractice: {
      text: String(raw.shadowingPractice?.text || "").trim(),
      focus: String(raw.shadowingPractice?.focus || "").trim(),
    },
    suggestedImprovements:
      cleanStringArray(raw.suggestedImprovements),
    actionPlan: cleanStringArray(raw.actionPlan),
  };
}

// ============================================================================
// VOCABULARY MODULE
// ============================================================================

const VOCABULARY_CATEGORIES = new Set([
  "academic",
  "topic",
  "band_5",
  "band_6",
  "band_7",
  "band_8_9",
  "collocations",
  "phrasal_verbs",
  "synonyms",
  "spelling",
]);

const VOCABULARY_BANDS = new Set([
  "Band 5",
  "Band 6",
  "Band 7",
  "Band 8",
  "Band 8-9",
  "Band 9",
]);

exports.processVocabularyGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      if (job.contentType !== "vocabulary" || job.status !== "queued") {
        return;
      }

      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;
      const requestedCount = clampNumber(job.requestedCount, 1, 50, 10);
      const validationError = validateVocabularyGenerationJob(job);

      if (validationError) {
        await jobRef.update({
          status: "failed",
          generatedCount: 0,
          failedCount: requestedCount,
          errorMessage: validationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await jobRef.update({
        status: "generating",
        generatedCount: 0,
        failedCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: FieldValue.delete(),
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdWordIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        const batches = splitVocabularyBatch(requestedCount, 10);

        for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
          const batchSize = batches[batchIndex];

          try {
            logger.info("Generating vocabulary batch.", {
              jobId,
              batchNumber: batchIndex + 1,
              batchSize,
            });

            const generated = await generateVocabularyBatch({
              ai,
              job,
              count: batchSize,
              sequenceNumber: batchIndex + 1,
            });

            for (const rawWord of generated.words) {
              try {
                const word = normalizeVocabularyWord(rawWord, job);
                const validation = validateVocabularyWord(word);

                if (!validation.isValid) {
                  throw new Error(
                      `Vocabulary validation failed: ` +
                      validation.errors.join(" | "),
                  );
                }

                const duplicate = await findVocabularyDuplicate(word.word);
                if (duplicate) {
                  failedCount++;
                  errors.push(
                      `Duplicate skipped: ${word.word} (${duplicate.id})`,
                  );
                  continue;
                }

                const wordRef = db.collection("vocabulary_words").doc();

                await wordRef.set({
                  ...word,
                  wordId: wordRef.id,
                  generationJobId: jobId,
                  generatedBy: "gemini",
                  generatedModel: generated.model,
                  qualityScore: validation.qualityScore,
                  validationPassed: true,
                  validationErrors: [],
                  status: "draft",
                  isPublished: false,
                  publishedAt: null,
                  createdBy: job.createdBy || null,
                  createdAt: FieldValue.serverTimestamp(),
                  updatedAt: FieldValue.serverTimestamp(),
                  savedCount: 0,
                  learnedCount: 0,
                  masteredCount: 0,
                  reviewCount: 0,
                  averageAccuracy: 0,
                });

                generatedCount++;
                createdWordIds.push(wordRef.id);
              } catch (wordError) {
                failedCount++;
                errors.push(safeErrorMessage(wordError));
              }
            }

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (batchError) {
            failedCount += batchSize;
            errors.push(
                `Batch ${batchIndex + 1}: ${safeErrorMessage(batchError)}`,
            );
          }
        }

        await jobRef.update({
          status: generatedCount > 0 ? "completed" : "failed",
          generatedCount,
          failedCount,
          createdWordIds,
          errors,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        logger.info("Vocabulary generation job completed.", {
          jobId,
          generatedCount,
          failedCount,
        });
      } catch (error) {
        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: Math.max(failedCount, requestedCount),
          errorMessage: safeErrorMessage(error),
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    },
);

function validateVocabularyGenerationJob(job) {
  const category = String(job.category || "academic").trim();
  const band = String(job.band || "Band 7").trim();

  if (!VOCABULARY_CATEGORIES.has(category)) {
    return `Unsupported vocabulary category: ${category}.`;
  }

  if (!VOCABULARY_BANDS.has(band)) {
    return `Unsupported vocabulary band: ${band}.`;
  }

  return null;
}

function splitVocabularyBatch(total, maximumBatchSize) {
  const batches = [];
  let remaining = total;

  while (remaining > 0) {
    const size = Math.min(remaining, maximumBatchSize);
    batches.push(size);
    remaining -= size;
  }

  return batches;
}

async function generateVocabularyBatch({
  ai,
  job,
  count,
  sequenceNumber,
}) {
  const category = String(job.category || "academic").trim();
  const band = String(job.band || "Band 7").trim();
  const topic = String(job.topic || "General IELTS").trim();
  const translationLanguage =
    String(job.translationLanguage || "Urdu").trim();
  const difficulty = String(job.difficulty || "Intermediate").trim();

  const prompt = `
Create ${count} completely original IELTS vocabulary entries.

SETTINGS
- Category: ${category}
- IELTS band: ${band}
- Topic: ${topic}
- Difficulty: ${difficulty}
- Translation language: ${translationLanguage}
- Unique generation sequence: ${sequenceNumber}

CATEGORY GUIDANCE
${vocabularyCategoryRules(category)}

STRICT REQUIREMENTS
1. Every entry must be useful for IELTS Listening, Reading, Writing or Speaking.
2. Avoid obscure, archaic, offensive, political persuasion, sexual, violent,
   medical-diagnosis or discriminatory vocabulary.
3. Meanings must be clear, concise and learner-friendly.
4. Translation must be natural ${translationLanguage}, not transliteration.
5. Pronunciation must be a simple learner-friendly respelling.
6. IPA must use valid English IPA notation.
7. Example sentence must be original and suitable for IELTS.
8. Synonyms, antonyms and collocations must be accurate.
9. For spelling category, include commonMistake and spellingTip.
10. For collocations, include natural word combinations.
11. For phrasal verbs, explain separability where relevant.
12. Do not generate duplicate words within the response.
13. Return JSON only.

Return exactly:
{
  "words": [
    {
      "word": "string",
      "meaning": "string",
      "translation": "string",
      "pronunciation": "string",
      "ipa": "string",
      "partOfSpeech": "noun|verb|adjective|adverb|phrase|phrasal verb",
      "exampleSentence": "string",
      "synonyms": ["string"],
      "antonyms": ["string"],
      "collocations": ["string"],
      "topic": "${topic}",
      "category": "${category}",
      "band": "${band}",
      "difficulty": "${difficulty}",
      "commonMistake": "string",
      "spellingTip": "string",
      "usageNote": "string",
      "wordFamily": ["string"],
      "register": "formal|neutral|informal",
      "modules": ["Listening", "Reading", "Writing", "Speaking"]
    }
  ]
}
`;

  const result = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.55,
      maxOutputTokens: 12000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty vocabulary response.");
  }

  let parsed;
  try {
    parsed = JSON.parse(
        result.response.text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim(),
    );
  } catch (error) {
    throw new Error(
        `Gemini returned invalid vocabulary JSON: ` +
        safeErrorMessage(error),
    );
  }

  if (!Array.isArray(parsed.words)) {
    throw new Error("Vocabulary response does not contain a words array.");
  }

  return {
    words: parsed.words,
    model: result.model,
  };
}

function vocabularyCategoryRules(category) {
  switch (category) {
    case "academic":
      return "Use formal academic words suitable for essays and passages.";
    case "topic":
      return "Use vocabulary strongly connected to the requested IELTS topic.";
    case "band_5":
      return "Use accessible foundation words and simple natural examples.";
    case "band_6":
      return "Use flexible upper-intermediate vocabulary.";
    case "band_7":
      return "Use precise, less common vocabulary without sounding unnatural.";
    case "band_8_9":
      return "Use advanced, nuanced vocabulary with accurate register.";
    case "collocations":
      return "Prioritize natural adjective-noun, verb-noun and adverb-adjective combinations.";
    case "phrasal_verbs":
      return "Create useful phrasal verbs with clear meanings and usage notes.";
    case "synonyms":
      return "Focus on paraphrasing groups and explain differences in nuance.";
    case "spelling":
      return "Focus on frequently misspelled IELTS words and spelling rules.";
    default:
      return "";
  }
}

function normalizeVocabularyWord(raw, job) {
  return {
    word: String(raw.word || "").trim(),
    meaning: String(raw.meaning || "").trim(),
    translation: String(raw.translation || "").trim(),
    pronunciation: String(raw.pronunciation || "").trim(),
    ipa: String(raw.ipa || "").trim(),
    partOfSpeech: String(raw.partOfSpeech || "").trim(),
    exampleSentence: String(raw.exampleSentence || "").trim(),
    synonyms: cleanStringArray(raw.synonyms).slice(0, 8),
    antonyms: cleanStringArray(raw.antonyms).slice(0, 8),
    collocations: cleanStringArray(raw.collocations).slice(0, 10),
    topic: String(raw.topic || job.topic || "General IELTS").trim(),
    category: String(raw.category || job.category || "academic").trim(),
    band: String(raw.band || job.band || "Band 7").trim(),
    difficulty:
      String(raw.difficulty || job.difficulty || "Intermediate").trim(),
    commonMistake: String(raw.commonMistake || "").trim(),
    spellingTip: String(raw.spellingTip || "").trim(),
    usageNote: String(raw.usageNote || "").trim(),
    wordFamily: cleanStringArray(raw.wordFamily).slice(0, 10),
    register: String(raw.register || "neutral").trim().toLowerCase(),
    modules: cleanStringArray(raw.modules).filter((module) =>
      ["Listening", "Reading", "Writing", "Speaking"].includes(module),
    ),
    normalizedWord: normalizeText(raw.word),
    translationLanguage:
      String(job.translationLanguage || "Urdu").trim(),
  };
}

function validateVocabularyWord(word) {
  const errors = [];
  let score = 100;

  if (!word.word || word.word.length < 2) {
    errors.push("Word is missing or too short.");
    score -= 25;
  }

  if (!word.meaning || word.meaning.length < 10) {
    errors.push("Meaning is missing or too short.");
    score -= 20;
  }

  if (!word.exampleSentence || word.exampleSentence.length < 20) {
    errors.push("Example sentence is missing or too short.");
    score -= 15;
  }

  if (!word.partOfSpeech) {
    errors.push("Part of speech is missing.");
    score -= 10;
  }

  if (!VOCABULARY_CATEGORIES.has(word.category)) {
    errors.push(`Unsupported category: ${word.category}.`);
    score -= 15;
  }

  if (word.synonyms.length === 0) {
    score -= 5;
  }

  if (word.collocations.length === 0) {
    score -= 5;
  }

  return {
    isValid: errors.length === 0,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}

async function findVocabularyDuplicate(word) {
  const normalizedWord = normalizeText(word);
  if (!normalizedWord) return null;

  const snapshot = await db.collection("vocabulary_words")
      .where("normalizedWord", "==", normalizedWord)
      .limit(1)
      .get();

  return snapshot.empty ? null : snapshot.docs[0];
}

// ============================================================================
// FULL MOCK TEST MODULE
// ============================================================================

const MOCK_TRACKS = new Set([
  "academic",
  "general_training",
]);

const MOCK_SKILLS = new Set([
  "listening",
  "reading",
  "writing",
  "speaking",
]);

const MOCK_DIFFICULTIES = new Set([
  "Foundation",
  "Intermediate",
  "Upper Intermediate",
  "Advanced",
  "Expert",
]);

exports.processMockTestGenerationJob = onDocumentCreated(
    {
      document: "generation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;

      if (job.contentType !== "mock_test") {
        return;
      }

      if (job.status !== "queued") {
        logger.info("Ignoring mock generation job because status is not queued.", {
          jobId,
          status: job.status,
        });
        return;
      }

      const validationError = validateMockGenerationJob(job);
      const requestedCount = clampNumber(job.requestedCount, 1, 40, 1);

      if (validationError) {
        await jobRef.update({
          status: "failed",
          generatedCount: 0,
          failedCount: requestedCount,
          errorMessage: validationError,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      await jobRef.update({
        status: "generating",
        generatedCount: 0,
        failedCount: 0,
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        errorMessage: FieldValue.delete(),
      });

      await updateParentMockGenerationState({
        job,
        skillStatus: "generating",
      });

      let generatedCount = 0;
      let failedCount = 0;
      const createdQuestionIds = [];
      const errors = [];

      try {
        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        const batches = splitMockGenerationBatches(
            requestedCount,
            job.skill,
        );

        for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
          const batchSize = batches[batchIndex];

          try {
            logger.info("Generating mock question batch.", {
              jobId,
              batchNumber: batchIndex + 1,
              batchSize,
              track: job.track,
              skill: job.skill,
              questionType: job.questionType,
            });

            const generated = await generateMockQuestionBatch({
              ai,
              job,
              count: batchSize,
              sequenceNumber: batchIndex + 1,
              jobId,
            });

            let sharedAudio = null;

            if (job.skill === "listening" &&
                generated.transcript &&
                generated.questions.length > 0) {
              const audioId = `mock_${jobId}_${batchIndex + 1}_${Date.now()}`;

              sharedAudio = await generateListeningAudio({
                testId: audioId,
                transcript: generated.transcript,
                speakers: generated.speakers,
                accent: generated.accent || "British",
              });
            }

            for (const rawQuestion of generated.questions) {
              try {
                const normalized = normalizeMockQuestion(rawQuestion, {
                  job,
                  transcript: generated.transcript,
                  sharedAudio,
                });

                const questionValidation =
                  validateGeneratedMockQuestion(normalized, job);

                if (!questionValidation.isValid) {
                  throw new Error(
                      `Mock question validation failed: ` +
                      questionValidation.errors.join(" | "),
                  );
                }

                const questionRef = db
                    .collection("mock_test_bank")
                    .doc(String(job.track))
                    .collection(String(job.skill))
                    .doc();

                await questionRef.set({
                  ...normalized,
                  questionId: questionRef.id,
                  generationJobId: jobId,
                  generatedBy: "gemini",
                  generatedModel: generated.model,
                  qualityScore: questionValidation.qualityScore,
                  validationPassed: true,
                  validationErrors: [],
                  status: "draft",
                  isPublished: false,
                  publishedAt: null,
                  mockTestId: job.mockTestId || null,
                  createdBy: job.createdBy || null,
                  createdAt: FieldValue.serverTimestamp(),
                  updatedAt: FieldValue.serverTimestamp(),
                });

                generatedCount++;
                createdQuestionIds.push(questionRef.id);
              } catch (questionError) {
                failedCount++;
                errors.push(safeErrorMessage(questionError));
              }
            }

            await jobRef.update({
              generatedCount,
              failedCount,
              updatedAt: FieldValue.serverTimestamp(),
            });
          } catch (batchError) {
            failedCount += batchSize;
            errors.push(
                `Batch ${batchIndex + 1}: ${safeErrorMessage(batchError)}`,
            );
          }
        }

        const finalStatus = generatedCount > 0 ? "completed" : "failed";

        await jobRef.update({
          status: finalStatus,
          generatedCount,
          failedCount,
          createdQuestionIds,
          errors,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        await updateParentMockGenerationState({
          job,
          generatedCount,
          failedCount,
          skillStatus: finalStatus,
          errorMessage: errors.join(" | "),
        });

        logger.info("Mock question generation job completed.", {
          jobId,
          generatedCount,
          failedCount,
          finalStatus,
        });
      } catch (error) {
        const message = safeErrorMessage(error);

        const finalFailedCount = Math.max(
            failedCount,
            requestedCount,
        );

        await jobRef.update({
          status: "failed",
          generatedCount,
          failedCount: finalFailedCount,
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        await updateParentMockGenerationState({
          job,
          generatedCount,
          failedCount: finalFailedCount,
          skillStatus: "failed",
          errorMessage: message,
        });

        logger.error("Mock generation job crashed.", {
          jobId,
          error: message,
        });
      }
    },
);

function validateMockGenerationJob(job) {
  const track = String(job.track || "").trim();
  const skill = String(job.skill || "").trim();
  const difficulty = String(job.difficulty || "Intermediate").trim();
  const questionType = String(job.questionType || "").trim();

  if (!MOCK_TRACKS.has(track)) {
    return `Unsupported mock track: ${track}.`;
  }

  if (!MOCK_SKILLS.has(skill)) {
    return `Unsupported mock skill: ${skill}.`;
  }

  if (!MOCK_DIFFICULTIES.has(difficulty)) {
    return `Unsupported mock difficulty: ${difficulty}.`;
  }

  if (!questionType) {
    return "Mock question type is required.";
  }

  return null;
}

function splitMockGenerationBatches(total, skill) {
  const maximumBatchSize =
    skill === "listening" || skill === "reading" ? 10 : 3;

  const batches = [];
  let remaining = total;

  while (remaining > 0) {
    const size = Math.min(remaining, maximumBatchSize);
    batches.push(size);
    remaining -= size;
  }

  return batches;
}

async function generateMockQuestionBatch({
  ai,
  job,
  count,
  sequenceNumber,
  jobId,
}) {
  const track = String(job.track);
  const skill = String(job.skill);
  const difficulty = String(job.difficulty || "Intermediate");
  const questionType = String(job.questionType || "multiple_choice");

  const prompt = buildMockGenerationPrompt({
    track,
    skill,
    difficulty,
    questionType,
    count,
    sequenceNumber,
  });

  const result = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: skill === "writing" || skill === "speaking" ? 0.65 : 0.45,
      maxOutputTokens: 14000,
      responseMimeType: "application/json",
    },
  });

  if (!result.response.text) {
    throw new Error("Gemini returned an empty mock question response.");
  }

  let parsed;
  try {
    parsed = JSON.parse(
        result.response.text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim(),
    );
  } catch (error) {
    throw new Error(
        `Gemini returned invalid mock JSON: ${safeErrorMessage(error)}`,
    );
  }

  if (!Array.isArray(parsed.questions)) {
    throw new Error("Mock response does not contain a questions array.");
  }

  if (parsed.questions.length !== count) {
    throw new Error(
        `Expected ${count} mock questions, received ` +
        `${parsed.questions.length}.`,
    );
  }

  logger.info("Mock question batch generated.", {
    jobId,
    skill,
    count,
    model: result.model,
  });

  return {
    questions: parsed.questions,
    transcript: String(parsed.transcript || "").trim(),
    speakers: Array.isArray(parsed.speakers) ? parsed.speakers : [],
    accent: String(parsed.accent || "British"),
    model: result.model,
  };
}

function buildMockGenerationPrompt({
  track,
  skill,
  difficulty,
  questionType,
  count,
  sequenceNumber,
}) {
  const skillRules = mockSkillGenerationRules(
      skill,
      questionType,
      track,
      count,
  );

  return `
Create ${count} original IELTS-style ${skill} mock test item(s).

This is independent practice material. Do not copy, quote, reproduce, or
closely paraphrase official IELTS, Cambridge, British Council, or IDP tests.

SETTINGS
- IELTS track: ${track}
- Skill: ${skill}
- Question type: ${questionType}
- Difficulty: ${difficulty}
- Unique sequence: ${sequenceNumber}
- Required item count: ${count}

${skillRules}

GENERAL RULES
1. Content must be original, internationally understandable and appropriate.
2. Avoid political persuasion, graphic violence, sexual content, diagnosis,
   discrimination and other unsafe or controversial material.
3. Every objective question must have an unambiguous answer.
4. Options must be plain text without A/B/C/D prefixes.
5. Question numbers must begin at 1 and remain sequential.
6. Explanations must be concise and educational.
7. Return JSON only and follow the schema exactly.

Return exactly:
{
  "transcript": "Listening only; otherwise empty string",
  "accent": "British",
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
      "sectionId": "section_1",
      "type": "${questionType}",
      "prompt": "string",
      "passage": "Reading passage or writing source material; otherwise empty",
      "options": [],
      "correctAnswers": ["string"],
      "marks": 1,
      "explanation": "string",
      "wordLimit": "string",
      "metadata": {
        "topic": "string",
        "part": 1,
        "taskType": "string",
        "preparationSeconds": 0,
        "speakingSeconds": 0
      }
    }
  ]
}
`;
}

function mockSkillGenerationRules(skill, questionType, track, count) {
  if (skill === "listening") {
    return `
LISTENING RULES
- Create one coherent transcript long enough for all ${count} questions.
- Answers must appear in the transcript in question-number order.
- Include realistic paraphrasing and distractors.
- Provide speakers and a natural accent context.
- Store the transcript once; every generated question may share the same audio.
- Multiple-choice items require exactly 4 options.
- Completion and short-answer items require options: [].
`;
  }

  if (skill === "reading") {
    return `
READING RULES
- Create one original ${track === "academic" ? "academic" : "general-interest"}
  passage long enough for all ${count} questions.
- Repeat the same complete passage in every question.passage field.
- Use clear paragraphing and realistic IELTS-level complexity.
- Multiple-choice questions require exactly 4 options.
- True/False/Not Given and Yes/No/Not Given require the complete answer text.
- Completion answers must respect the supplied word limit.
`;
  }

  if (skill === "writing") {
    return `
WRITING RULES
- Create ${count} authentic IELTS writing task prompt(s).
- For writing_task_1:
  ${track === "academic" ?
    "Create a chart, table, map or process description using detailed text data." :
    "Create a formal, semi-formal or informal letter situation."}
- For writing_task_2, create an opinion, discussion, advantages/disadvantages,
  problem/solution or two-part essay prompt.
- correctAnswers must be [] because writing is AI evaluated.
- marks must be 1.
- metadata.taskType must clearly identify the task.
`;
  }

  return `
SPEAKING RULES
- Create ${count} IELTS Speaking item(s) for Part 1, Part 2 or Part 3.
- metadata.part must be 1, 2 or 3.
- Part 2 must include a complete cue card and bullet prompts.
- Part 2 preparationSeconds must be 60 and speakingSeconds must be 120.
- correctAnswers must be [] because speaking is AI evaluated.
- Questions must support natural follow-up discussion.
`;
}

function normalizeMockQuestion(rawQuestion, {
  job,
  transcript,
  sharedAudio,
}) {
  const rawMetadata = rawQuestion.metadata &&
    typeof rawQuestion.metadata === "object" ?
    rawQuestion.metadata :
    {};

  const options = normalizeOptions(rawQuestion.options);
  const correctAnswers = Array.isArray(rawQuestion.correctAnswers) ?
    rawQuestion.correctAnswers
        .map((value) => String(value || "").trim())
        .filter(Boolean) :
    [];

  return {
    track: String(job.track),
    skill: String(job.skill),
    number: clampNumber(rawQuestion.number, 1, 100, 1),
    sectionId: String(rawQuestion.sectionId || "section_1").trim(),
    type: String(rawQuestion.type || job.questionType).trim(),
    prompt: String(rawQuestion.prompt || "").trim(),
    passage: String(rawQuestion.passage || "").trim(),
    transcript: String(transcript || "").trim(),
    audioUrl: sharedAudio?.audioUrl || "",
    audioStoragePath: sharedAudio?.audioStoragePath || "",
    audioDurationSeconds: sharedAudio?.audioDurationSeconds || 0,
    options,
    correctAnswers,
    marks: clampNumber(rawQuestion.marks, 1, 10, 1),
    explanation: String(rawQuestion.explanation || "").trim(),
    wordLimit: String(rawQuestion.wordLimit || "").trim(),
    difficulty: String(job.difficulty || "Intermediate"),
    metadata: {
      ...rawMetadata,
      topic: String(rawMetadata.topic || "").trim(),
      part: clampNumber(rawMetadata.part, 0, 3, 0),
      taskType: String(rawMetadata.taskType || "").trim(),
      preparationSeconds:
        clampNumber(rawMetadata.preparationSeconds, 0, 600, 0),
      speakingSeconds:
        clampNumber(rawMetadata.speakingSeconds, 0, 1200, 0),
    },
  };
}

function validateGeneratedMockQuestion(question, job) {
  const errors = [];
  let score = 100;

  if (!question.prompt || question.prompt.length < 8) {
    errors.push("Prompt is missing or too short.");
    score -= 30;
  }

  if (!question.sectionId) {
    errors.push("Section ID is missing.");
    score -= 10;
  }

  if (question.skill === "reading" &&
      (!question.passage || question.passage.length < 150)) {
    errors.push("Reading passage is missing or too short.");
    score -= 25;
  }

  if (question.skill === "listening" &&
      (!question.transcript || question.transcript.length < 150)) {
    errors.push("Listening transcript is missing or too short.");
    score -= 25;
  }

  const type = String(question.type).toLowerCase();
  const isSelectable = type.includes("multiple_choice") ||
    type.includes("multiple select");

  if (isSelectable && question.options.length < 3) {
    errors.push("Selectable question does not have enough options.");
    score -= 20;
  }

  if ((question.skill === "listening" ||
       question.skill === "reading") &&
      question.correctAnswers.length === 0) {
    errors.push("Objective question has no correct answer.");
    score -= 25;
  }

  if (String(job.skill) === "writing" &&
      !question.metadata.taskType) {
    errors.push("Writing task type is missing.");
    score -= 15;
  }

  return {
    isValid: errors.length === 0,
    errors,
    qualityScore: Math.max(0, Math.min(100, score)),
  };
}


async function updateParentMockGenerationState({
  job,
  generatedCount = 0,
  failedCount = 0,
  skillStatus,
  errorMessage = "",
}) {
  const mockTestId = String(job.mockTestId || "").trim();
  const skill = String(job.skill || "").trim();

  if (!mockTestId || !MOCK_SKILLS.has(skill)) {
    return;
  }

  const mockRef = db.collection("mock_tests").doc(mockTestId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(mockRef);
    if (!snapshot.exists) return;

    const data = snapshot.data() || {};
    const requiredBySkill = {
      ...(data.requiredBySkill || {}),
    };
    const generatedBySkill = {
      ...(data.generatedBySkill || {}),
    };
    const failedBySkill = {
      ...(data.failedBySkill || {}),
    };
    const jobStatusBySkill = {
      ...(data.jobStatusBySkill || {}),
    };

    // Each skill uses one active generation job in the automatic flow.
    // Retry jobs add only missing questions, so increments are safe.
    generatedBySkill[skill] =
      Number(generatedBySkill[skill] || 0) + Number(generatedCount || 0);
    failedBySkill[skill] =
      Number(failedBySkill[skill] || 0) + Number(failedCount || 0);
    jobStatusBySkill[skill] = skillStatus;

    const selectedSkills = Array.isArray(data.skills) ?
      data.skills :
      Object.keys(requiredBySkill);

    const totalRequired = selectedSkills.reduce(
        (sum, currentSkill) =>
          sum + Number(requiredBySkill[currentSkill] || 0),
        0,
    );
    const totalGenerated = selectedSkills.reduce(
        (sum, currentSkill) =>
          sum + Number(generatedBySkill[currentSkill] || 0),
        0,
    );
    const totalFailed = selectedSkills.reduce(
        (sum, currentSkill) =>
          sum + Number(failedBySkill[currentSkill] || 0),
        0,
    );

    const allComplete = selectedSkills.every((currentSkill) => {
      return Number(generatedBySkill[currentSkill] || 0) >=
        Number(requiredBySkill[currentSkill] || 0);
    });

    const allFinished = selectedSkills.every((currentSkill) => {
      const status = String(jobStatusBySkill[currentSkill] || "");
      return status === "completed" || status === "failed";
    });

    let parentStatus = "generating";
    if (allComplete) {
      parentStatus = "ready";
    } else if (allFinished && totalFailed > 0) {
      parentStatus = "generation_failed";
    }

    const progress = totalRequired > 0 ?
      Math.min(
          100,
          Math.round((totalGenerated / totalRequired) * 100),
      ) :
      0;

    transaction.set(mockRef, {
      generatedBySkill,
      failedBySkill,
      jobStatusBySkill,
      totalRequired,
      totalGenerated,
      totalFailed,
      generationProgress: progress,
      status: parentStatus,
      isReady: allComplete,
      generationError: errorMessage ?
        String(errorMessage).slice(0, 3000) :
        data.generationError || "",
      readyAt: allComplete ?
        FieldValue.serverTimestamp() :
        data.readyAt || null,
      updatedAt: FieldValue.serverTimestamp(),
    }, {merge: true});
  });
}

// ---------------------------------------------------------------------------
// Full Mock Evaluation
// ---------------------------------------------------------------------------

exports.processMockEvaluationJob = onDocumentCreated(
    {
      document: "mock_evaluation_jobs/{jobId}",
      secrets: [geminiApiKey],
      retry: false,
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) return;

      const job = snapshot.data();
      const jobId = event.params.jobId;
      const jobRef = snapshot.ref;

      if (job.status !== "queued") return;

      const userId = String(job.userId || "").trim();
      const attemptId = String(job.attemptId || "").trim();

      if (!userId || !attemptId) {
        await jobRef.update({
          status: "failed",
          errorMessage: "userId and attemptId are required.",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return;
      }

      const attemptRef = db
          .collection("users")
          .doc(userId)
          .collection("mock_attempts")
          .doc(attemptId);

      await jobRef.update({
        status: "evaluating",
        startedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      await attemptRef.set({
        status: "evaluating",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      try {
        const attemptSnapshot = await attemptRef.get();
        if (!attemptSnapshot.exists) {
          throw new Error("Mock attempt was not found.");
        }

        const attempt = attemptSnapshot.data();
        const config = attempt.config || {};
        const track = String(config.track || "academic");
        const targetBand = Number(config.targetBand || 7);
        const configuredSkills = Array.isArray(config.skills) ?
          config.skills :
          ["listening", "reading", "writing", "speaking"];

        const answersSnapshot = await attemptRef
            .collection("answers")
            .get();

        const answers = answersSnapshot.docs.map((doc) => ({
          id: doc.id,
          ...doc.data(),
        }));

        const skillResults = {};
        const strengths = [];
        const weaknesses = [];

        const {GoogleGenAI} = await import("@google/genai");
        const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});

        for (const skill of configuredSkills) {
          if (!MOCK_SKILLS.has(skill)) continue;

          const skillAnswers = answers.filter(
              (answer) => String(answer.skill) === skill,
          );

          const timeSpentSeconds = Number(
              attempt.skillTimeSpent?.[skill] || 0,
          );

          if (skill === "listening" || skill === "reading") {
            const objective = await evaluateObjectiveMockSkill({
              track,
              skill,
              answers: skillAnswers,
              timeSpentSeconds,
            });

            skillResults[skill] = objective;

            if (objective.accuracy >= 75) {
              strengths.push(
                  `${capitalizeMockLabel(skill)} accuracy is strong.`,
              );
            } else {
              weaknesses.push(
                  `${capitalizeMockLabel(skill)} accuracy needs improvement.`,
              );
            }
          } else {
            const subjective = await evaluateSubjectiveMockSkill({
              ai,
              skill,
              answers: skillAnswers,
              timeSpentSeconds,
              targetBand,
            });

            skillResults[skill] = subjective;

            if (subjective.band >= targetBand) {
              strengths.push(
                  `${capitalizeMockLabel(skill)} is at or above the target band.`,
              );
            } else {
              weaknesses.push(
                  `${capitalizeMockLabel(skill)} is below the target band.`,
              );
            }
          }
        }

        const bands = Object.values(skillResults)
            .map((result) => Number(result.band || 0))
            .filter((band) => band > 0);

        const overallBand = bands.length > 0 ?
          roundMockBand(
              bands.reduce((sum, band) => sum + band, 0) / bands.length,
          ) :
          0;

        const targetGap = Math.max(
            0,
            Number((targetBand - overallBand).toFixed(1)),
        );

        const suggestedNextMockDate = new Date();
        suggestedNextMockDate.setDate(
            suggestedNextMockDate.getDate() + (targetGap >= 1 ? 7 : 10),
        );

        const sevenDayPlan = buildMockSevenDayPlan({
          skillResults,
          targetBand,
        });

        const result = {
          overallBand,
          targetBand,
          targetGap,
          skills: skillResults,
          strengths: uniqueMockStrings(strengths).slice(0, 6),
          weaknesses: uniqueMockStrings(weaknesses).slice(0, 6),
          suggestedNextMockDate:
            TimestampFromDateSafe(suggestedNextMockDate),
          sevenDayPlan,
          evaluatedAt: FieldValue.serverTimestamp(),
        };

        await attemptRef.set({
          status: "completed",
          result,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        await jobRef.update({
          status: "completed",
          overallBand,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        logger.info("Mock evaluation completed.", {
          jobId,
          userId,
          attemptId,
          overallBand,
        });
      } catch (error) {
        const message = safeErrorMessage(error);

        await attemptRef.set({
          status: "evaluation_failed",
          evaluationError: message,
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});

        await jobRef.update({
          status: "failed",
          errorMessage: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        logger.error("Mock evaluation failed.", {
          jobId,
          userId,
          attemptId,
          error: message,
        });
      }
    },
);

async function evaluateObjectiveMockSkill({
  track,
  skill,
  answers,
  timeSpentSeconds,
}) {
  let rawScore = 0;
  let totalMarks = 0;
  const typeStats = {};

  for (const answer of answers) {
    const questionId = String(answer.questionId || "").trim();
    if (!questionId) continue;

    const questionSnapshot = await db
        .collection("mock_test_bank")
        .doc(track)
        .collection(skill)
        .doc(questionId)
        .get();

    if (!questionSnapshot.exists) continue;

    const question = questionSnapshot.data();
    const marks = clampNumber(question.marks, 1, 10, 1);
    const correctAnswers = Array.isArray(question.correctAnswers) ?
      question.correctAnswers :
      [];
    const type = String(question.type || "unknown");

    totalMarks += marks;

    if (!typeStats[type]) {
      typeStats[type] = {correct: 0, total: 0};
    }
    typeStats[type].total++;

    if (mockAnswerIsCorrect(answer.value, correctAnswers)) {
      rawScore += marks;
      typeStats[type].correct++;
    }
  }

  const accuracy = totalMarks > 0 ?
    Number(((rawScore / totalMarks) * 100).toFixed(1)) :
    0;

  const questionTypeAccuracy = {};
  for (const [type, stats] of Object.entries(typeStats)) {
    questionTypeAccuracy[type] = stats.total > 0 ?
      Number(((stats.correct / stats.total) * 100).toFixed(1)) :
      0;
  }

  return {
    band: skill === "listening" ?
      listeningRawToBand(rawScore) :
      readingRawToBand(rawScore),
    rawScore,
    totalMarks,
    accuracy,
    timeSpentSeconds,
    criteria: {},
    questionTypeAccuracy,
  };
}

function mockAnswerIsCorrect(value, correctAnswers) {
  const expected = correctAnswers
      .map((answer) => normalizeAnswerForComparison(answer))
      .filter(Boolean);

  if (Array.isArray(value)) {
    const actual = value
        .map((answer) => normalizeAnswerForComparison(answer))
        .filter(Boolean)
        .sort();

    return actual.length === expected.length &&
      actual.every((answer, index) => answer === expected.sort()[index]);
  }

  const actual = normalizeAnswerForComparison(value);
  return expected.includes(actual);
}

async function evaluateSubjectiveMockSkill({
  ai,
  skill,
  answers,
  timeSpentSeconds,
  targetBand,
}) {
  const answerText = answers.map((answer, index) => {
    return `Response ${index + 1}: ${String(answer.value || "").trim()}`;
  }).join("\n\n");

  if (!answerText.trim()) {
    return {
      band: 0,
      rawScore: 0,
      totalMarks: answers.length,
      accuracy: 0,
      timeSpentSeconds,
      criteria: {},
      questionTypeAccuracy: {},
    };
  }

  const criteria = skill === "writing" ?
    [
      "taskAchievement",
      "coherenceAndCohesion",
      "lexicalResource",
      "grammaticalRangeAndAccuracy",
    ] :
    [
      "fluencyAndCoherence",
      "lexicalResource",
      "grammaticalRangeAndAccuracy",
      "pronunciation",
    ];

  const prompt = `
Evaluate the following IELTS ${skill} mock responses.

TARGET BAND: ${targetBand}

RESPONSES
${answerText}

Return JSON only:
{
  "band": 6.5,
  "criteria": {
    "${criteria[0]}": 6.5,
    "${criteria[1]}": 6.5,
    "${criteria[2]}": 6.5,
    "${criteria[3]}": 6.5
  },
  "strengths": ["string"],
  "weaknesses": ["string"]
}

Use IELTS-style band descriptors. Do not claim this is an official IELTS score.
For Speaking, if only text/transcript is available, evaluate pronunciation
conservatively and explain the limitation internally through a lower-confidence
criterion score.
`;

  const response = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.2,
      maxOutputTokens: 2500,
      responseMimeType: "application/json",
    },
  });

  const parsed = JSON.parse(
      response.response.text
          .replace(/```json/gi, "")
          .replace(/```/g, "")
          .trim(),
  );

  const criteriaResult = {};
  for (const key of criteria) {
    criteriaResult[key] = roundMockBand(
        Number(parsed.criteria?.[key] || 0),
    );
  }

  return {
    band: roundMockBand(Number(parsed.band || 0)),
    rawScore: 0,
    totalMarks: answers.length,
    accuracy: 0,
    timeSpentSeconds,
    criteria: criteriaResult,
    questionTypeAccuracy: {},
    strengths: Array.isArray(parsed.strengths) ? parsed.strengths : [],
    weaknesses: Array.isArray(parsed.weaknesses) ? parsed.weaknesses : [],
  };
}

function listeningRawToBand(score) {
  if (score >= 39) return 9;
  if (score >= 37) return 8.5;
  if (score >= 35) return 8;
  if (score >= 32) return 7.5;
  if (score >= 30) return 7;
  if (score >= 26) return 6.5;
  if (score >= 23) return 6;
  if (score >= 18) return 5.5;
  if (score >= 16) return 5;
  if (score >= 13) return 4.5;
  return score > 0 ? 4 : 0;
}

function readingRawToBand(score) {
  if (score >= 39) return 9;
  if (score >= 37) return 8.5;
  if (score >= 35) return 8;
  if (score >= 33) return 7.5;
  if (score >= 30) return 7;
  if (score >= 27) return 6.5;
  if (score >= 23) return 6;
  if (score >= 19) return 5.5;
  if (score >= 15) return 5;
  if (score >= 13) return 4.5;
  return score > 0 ? 4 : 0;
}

function roundMockBand(value) {
  const safe = Math.max(0, Math.min(9, Number(value || 0)));
  return Math.round(safe * 2) / 2;
}

function buildMockSevenDayPlan({
  skillResults,
  targetBand,
}) {
  const orderedSkills = Object.entries(skillResults)
      .sort((a, b) => Number(a[1].band || 0) - Number(b[1].band || 0))
      .map(([skill]) => skill);

  const fallbackSkills = [
    "reading",
    "listening",
    "writing",
    "speaking",
  ];

  const skills = orderedSkills.length > 0 ? orderedSkills : fallbackSkills;

  return Array.from({length: 7}, (_, index) => {
    const skill = skills[index % skills.length];
    const result = skillResults[skill] || {};
    const band = Number(result.band || 0);

    return {
      day: index + 1,
      skill: capitalizeMockLabel(skill),
      task: mockPlanTask(skill, band, targetBand),
    };
  });
}

function mockPlanTask(skill, band, targetBand) {
  const gap = Math.max(0, targetBand - band);
  const intensity = gap >= 1 ? "timed intensive" : "focused";

  if (skill === "listening") {
    return `Complete one ${intensity} listening section, review every wrong ` +
      `answer, and record spelling/paraphrase mistakes.`;
  }

  if (skill === "reading") {
    return `Complete one ${intensity} reading passage, track time per question ` +
      `type, and review evidence for every answer.`;
  }

  if (skill === "writing") {
    return `Write one IELTS task under time pressure, then revise task response, ` +
      `cohesion, vocabulary and grammar using the feedback.`;
  }

  return `Record one speaking practice session, reduce fillers, improve answer ` +
    `development, and repeat weak responses with clearer pronunciation.`;
}

function capitalizeMockLabel(value) {
  const text = String(value || "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

function uniqueMockStrings(values) {
  return [...new Set(
      values
          .map((value) => String(value || "").trim())
          .filter(Boolean),
  )];
}

function TimestampFromDateSafe(date) {
  const {Timestamp} = require("firebase-admin/firestore");
  return Timestamp.fromDate(date);
}

// ============================================================================
// AI COACH MODULE
// ============================================================================

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
      const responseInstruction = String(
          request.data?.responseInstruction || "",
      ).trim();

      if (!message) {
        throw new HttpsError(
            "invalid-argument",
            "Message is required.",
        );
      }

      if (message.length > 6000) {
        throw new HttpsError(
            "invalid-argument",
            "Message is too long.",
        );
      }

      try {
        const profile = await buildAiCoachProfile(uid);
        const history = await loadRecentCoachMessages(uid);

        const prompt = buildAiCoachPrompt({
          message,
          profile,
          history,
          responseInstruction,
        });

        const response = await callGeminiCoach(prompt);

        // Final safety cleaning in case Gemini still returns Markdown.
        const cleanedText = cleanAiCoachResponse(response.text);

        if (!cleanedText) {
          throw new Error("Gemini returned an empty AI Coach response.");
        }

        const assistantRef = db
            .collection("users")
            .doc(uid)
            .collection("ai_coach_messages")
            .doc();

        await assistantRef.set({
          messageId: assistantRef.id,
          role: "assistant",
          text: cleanedText,
          intent: String(response.intent || "general"),
          suggestions: Array.isArray(response.suggestions) ?
            response.suggestions
                .map((value) => cleanAiCoachResponse(value))
                .filter(Boolean)
                .slice(0, 4) :
            [],
          profileSnapshot: profile,
          model: response.model || null,
          responseFormat: "professional_plain_text",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {
          success: true,
          messageId: assistantRef.id,
        };
      } catch (error) {
        const messageText = safeErrorMessage(error);

        logger.error("AI Coach request failed.", {
          uid,
          error: messageText,
        });

        if (error instanceof HttpsError) {
          throw error;
        }

        throw new HttpsError(
            "internal",
            "AI Coach could not generate a response. Please try again.",
            messageText,
        );
      }
    },
);
function cleanAiCoachResponse(value) {
  return String(value || "")
      .replace(/```(?:json|javascript|js|dart|text)?/gi, "")
      .replace(/```/g, "")
      .replace(/^#{1,6}\s*/gm, "")
      .replace(/\*\*([^*]+?)\*\*/g, "$1")
      .replace(/__([^_]+?)__/g, "$1")
      .replace(/^\s*\*\s+/gm, "• ")
      .replace(/^\s*-\s+/gm, "• ")
      .replace(/^\s*>\s?/gm, "")
      .replace(/\[([^\]]+)]\([^)]+\)/g, "$1")
      .replace(/`([^`]+)`/g, "$1")
      .replace(/(^|[\s([{])\*([^*\n]+?)\*(?=$|[\s.,!?;:)\]}])/gm, "$1$2")
      .replace(/(^|[\s([{])_([^_\n]+?)_(?=$|[\s.,!?;:)\]}])/gm, "$1$2")
      .replace(/[\u002A\u0060]/g, "")
      .replace(/[ \t]+\n/g, "\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
}

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

      try {
        const profile = await buildAiCoachProfile(
            request.auth.uid,
        );

        return {
          success: true,
          profile,
        };
      } catch (error) {
        const messageText = safeErrorMessage(error);

        logger.error("AI Coach profile refresh failed.", {
          uid: request.auth.uid,
          error: messageText,
        });

        throw new HttpsError(
            "internal",
            "AI Coach profile could not be refreshed.",
            messageText,
        );
      }
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
    userRef.collection("listening_results").limit(30).get(),
    userRef.collection("reading_results").limit(30).get(),
    userRef.collection("writing_results").limit(30).get(),
    userRef.collection("speaking").limit(30).get(),
    userRef.collection("mock_attempts").limit(20).get(),
    userRef.collection("lesson_progress")
        .where("completed", "==", true)
        .get(),
  ]);

  const user = userDoc.data() || {};

  const skillBands = {
    listening: averageAiCoachBand(listening.docs),
    reading: averageAiCoachBand(reading.docs),
    writing: averageAiCoachBand(writing.docs),
    speaking: averageAiCoachBand(speaking.docs),
  };

  const completedSkillEntries = Object.entries(skillBands)
      .filter(([, band]) => band > 0)
      .sort((a, b) => a[1] - b[1]);

  const validBands = completedSkillEntries.map(([, band]) => band);

  const overallBand = validBands.length > 0 ?
    roundAiCoachBand(
        validBands.reduce((sum, value) => sum + value, 0) /
        validBands.length,
    ) :
    0;

  const weakestSkill = completedSkillEntries.length > 0 ?
    capitalizeAiCoachLabel(completedSkillEntries[0][0]) :
    "Not enough data";

  const strongestSkill = completedSkillEntries.length > 0 ?
    capitalizeAiCoachLabel(
        completedSkillEntries[completedSkillEntries.length - 1][0],
    ) :
    "Not enough data";

  const weakQuestionTypes = {
    listening: collectAiCoachWeakTypes(listening.docs),
    reading: collectAiCoachWeakTypes(reading.docs),
  };

  const latestWritingFeedback =
    extractLatestAiCoachFeedback(writing.docs, "writing");
  const latestSpeakingFeedback =
    extractLatestAiCoachFeedback(speaking.docs, "speaking");
  const latestMockSummary =
    extractLatestAiCoachMockSummary(mockAttempts.docs);

  const completedMocks = mockAttempts.docs.filter((doc) => {
    const status = String(doc.data().status || "").toLowerCase();
    return status === "completed" || status === "submitted";
  }).length;

  const profile = {
    overallBand,
    targetBand: Number(
        user.targetBand ||
        user.target_band ||
        7,
    ),
    streak: Number(user.streak || 0),
    weakestSkill,
    strongestSkill,
    skillBands,
    weakQuestionTypes,
    latestWritingFeedback,
    latestSpeakingFeedback,
    latestMockSummary,
    completedLessons: lessonProgress.size,
    completedPractice:
      listening.size + reading.size + writing.size + speaking.size,
    completedMocks,
    generatedAt: new Date().toISOString(),
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

function averageAiCoachBand(docs) {
  const values = docs
      .map((doc) => {
        const data = doc.data() || {};
        const result = data.result &&
          typeof data.result === "object" ?
          data.result :
          {};

        return Number(
            data.band ||
            data.overallBand ||
            data.estimatedBand ||
            data.bandScore ||
            result.overallBand ||
            result.band ||
            0,
        );
      })
      .filter((value) => Number.isFinite(value) && value > 0);

  if (values.length === 0) return 0;

  return roundAiCoachBand(
      values.reduce((sum, value) => sum + value, 0) /
      values.length,
  );
}

function collectAiCoachWeakTypes(docs) {
  const stats = {};

  for (const doc of docs) {
    const data = doc.data() || {};
    const performance =
      data.questionTypePerformance ||
      data.question_type_performance ||
      data.typePerformance ||
      data.result?.questionTypePerformance;

    if (!performance || typeof performance !== "object") {
      continue;
    }

    for (const [type, value] of Object.entries(performance)) {
      const rawAccuracy = typeof value === "object" ?
        value.accuracy ?? value.percentage ?? value.score :
        value;
      const accuracy = Number(rawAccuracy);

      if (!Number.isFinite(accuracy)) continue;

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

function extractLatestAiCoachFeedback(docs, skill) {
  const sortedDocs = [...docs].sort((a, b) => {
    return aiCoachDocumentTime(b.data()) -
      aiCoachDocumentTime(a.data());
  });

  const latest = sortedDocs[0]?.data() || {};
  if (Object.keys(latest).length === 0) return null;

  if (skill === "writing") {
    return {
      band: Number(
          latest.band ||
          latest.overallBand ||
          latest.estimatedBand ||
          0,
      ),
      taskAchievement:
        safeAiCoachText(
            latest.taskAchievement ||
            latest.taskResponse,
        ),
      coherence:
        safeAiCoachText(
            latest.coherence ||
            latest.coherenceAndCohesion,
        ),
      lexical:
        safeAiCoachText(
            latest.lexical ||
            latest.lexicalResource,
        ),
      grammar:
        safeAiCoachText(
            latest.grammar ||
            latest.grammaticalRangeAndAccuracy,
        ),
      improvement:
        safeAiCoachText(
            latest.improvement ||
            latest.actionPlan,
        ),
    };
  }

  return {
    band: Number(
        latest.band ||
        latest.overallBand ||
        latest.estimatedBand ||
        0,
    ),
    fluency:
      safeAiCoachText(
          latest.fluency ||
          latest.fluencyAndCoherence,
      ),
    lexical:
      safeAiCoachText(
          latest.lexical ||
          latest.lexicalResource,
      ),
    grammar:
      safeAiCoachText(
          latest.grammar ||
          latest.grammaticalRangeAndAccuracy,
      ),
    pronunciation:
      safeAiCoachText(latest.pronunciation),
    improvement:
      safeAiCoachText(
          latest.improvement ||
          latest.suggestedImprovements,
      ),
  };
}

function extractLatestAiCoachMockSummary(docs) {
  const sortedDocs = [...docs].sort((a, b) => {
    return aiCoachDocumentTime(b.data()) -
      aiCoachDocumentTime(a.data());
  });

  const latest = sortedDocs[0]?.data() || {};
  if (Object.keys(latest).length === 0) return null;

  const result = latest.result &&
    typeof latest.result === "object" ?
    latest.result :
    {};

  return {
    status: String(latest.status || ""),
    overallBand: Number(
        result.overallBand ||
        latest.overallBand ||
        0,
    ),
    skills: result.skills || latest.skillResults || {},
    strengths: Array.isArray(result.strengths) ?
      result.strengths.slice(0, 5) :
      [],
    weaknesses: Array.isArray(result.weaknesses) ?
      result.weaknesses.slice(0, 5) :
      [],
  };
}

function aiCoachDocumentTime(data) {
  const candidates = [
    data.updatedAt,
    data.completedAt,
    data.timestamp,
    data.createdAt,
    data.startedAt,
  ];

  for (const value of candidates) {
    if (value && typeof value.toMillis === "function") {
      return value.toMillis();
    }

    const parsed = Date.parse(String(value || ""));
    if (Number.isFinite(parsed)) return parsed;
  }

  return 0;
}

function safeAiCoachText(value) {
  if (typeof value === "string") {
    return value.slice(0, 1500);
  }

  if (value && typeof value === "object") {
    return JSON.stringify(value).slice(0, 1500);
  }

  return "";
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
        role: String(message.role || "user"),
        text: String(message.text || "").slice(0, 4000),
      }));
}

function buildAiCoachPrompt({
  message,
  profile,
  history,
  responseInstruction = "",
}) {
  const defaultResponseInstruction = `
You are IELTS AI Coach, a premium and professional IELTS tutor.

STRICT RESPONSE FORMATTING RULES

1. Return plain text inside the JSON "text" field.
2. Never use Markdown heading symbols such as #, ## or ###.
3. Never use Markdown emphasis symbols such as **, __ or single *.
4. Never use Markdown code fences or backticks.
5. Never use hyphens or stars as bullet markers.
6. Use the bullet character • for unordered lists.
7. Use short plain-text section titles written in uppercase.
8. Keep paragraphs short, clear and easy to scan.
9. Use British English.
10. End with one practical next step.

For a speaking cue card, use this plain-text structure:

SPEAKING CUE CARD

Topic:
A clear speaking topic

YOU SHOULD SAY

• First point
• Second point
• Third point
• Fourth point

BAND IMPROVEMENT TIPS

• First tip
• Second tip
• Third tip

PRACTICE STEPS

1. Prepare for one minute.
2. Speak for one to two minutes.
3. Review fluency, vocabulary and grammar.

COACH TIP

One personalised improvement tip.

NEXT STEP

One clear action for the learner.
`;

  const formattingInstruction = responseInstruction.trim() ||
    defaultResponseInstruction.trim();

  return `
You are an expert IELTS AI Coach inside an IELTS preparation application.
You are not a generic chatbot.

RESPONSE FORMAT INSTRUCTION
${formattingInstruction}

USER PROGRESS PROFILE
${JSON.stringify(profile, null, 2)}

RECENT CONVERSATION
${JSON.stringify(history, null, 2)}

CURRENT USER MESSAGE
${message}

CAPABILITIES
• Daily study recommendations
• Explain wrong answers
• Generate targeted practice
• Create study plans
• Explain Writing feedback
• Explain Speaking feedback
• Vocabulary practice
• Motivation
• Exam strategy
• Weekly progress review
• Weakness detection

COACHING RULES
1. Use the real progress profile whenever it is relevant.
2. Never invent results that are not present in the profile.
3. If there is not enough progress data, clearly say so and give a starter plan.
4. Mention the weakest skill or weak question type when useful.
5. Give specific and actionable advice.
6. Never claim an official IELTS score.
7. Use terms such as "estimated band" or "likely band".
8. When asked for a study plan, include duration and daily tasks.
9. When explaining an incorrect answer, explain why the selected answer is
   wrong, why the correct answer is right, the supporting rule or evidence,
   and one prevention tip.
10. When generating practice, provide a complete task and keep the answer
    hidden until the learner asks for it.
11. Keep the tone encouraging, professional and concise.
12. Follow the response format instruction above.
13. Return valid JSON only.

Return exactly this JSON structure:
{
  "intent": "daily_recommendation",
  "text": "Professional plain-text answer without Markdown symbols",
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

  try {
    const result = await callGeminiWithRetry(ai, {
      contents: prompt,
      config: {
        temperature: 0.35,
        maxOutputTokens: 5000,
        responseMimeType: "application/json",
      },
    });

    const raw = String(result.response.text || "").trim();
    if (!raw) {
      throw new Error("AI Coach received an empty Gemini response.");
    }

    const parsed = parseAiCoachJson(raw);

    return {
      intent: String(parsed.intent || "general"),
      text: String(
          parsed.text ||
          "I could not generate a useful response.",
      ),
      suggestions: Array.isArray(parsed.suggestions) ?
        parsed.suggestions
            .map((item) => String(item).trim())
            .filter(Boolean)
            .slice(0, 4) :
        [],
      model: result.model,
    };
  } catch (error) {
    const message = safeErrorMessage(error);

    if (isGeminiQuotaError(error)) {
      throw new HttpsError(
          "resource-exhausted",
          "AI Coach quota is temporarily exhausted. Please try again later.",
          message,
      );
    }

    throw error;
  }
}

function parseAiCoachJson(value) {
  const cleaned = String(value || "")
      .replace(/```json/gi, "")
      .replace(/```/g, "")
      .trim();

  const start = cleaned.indexOf("{");

  if (start === -1) {
    throw new Error(
        "AI Coach returned invalid JSON: no JSON object found.",
    );
  }

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < cleaned.length; index++) {
    const character = cleaned[index];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (character === "\\" && inString) {
      escaped = true;
      continue;
    }

    if (character === "\"") {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (character === "{") {
      depth++;
      continue;
    }

    if (character === "}") {
      depth--;

      if (depth === 0) {
        const jsonOnly = cleaned.slice(start, index + 1);

        try {
          return JSON.parse(jsonOnly);
        } catch (error) {
          throw new Error(
              "AI Coach returned invalid JSON: " +
              safeErrorMessage(error),
          );
        }
      }
    }
  }

  throw new Error(
      "AI Coach returned invalid JSON: incomplete JSON object.",
  );
}

function roundAiCoachBand(value) {
  const safe = Math.max(0, Math.min(9, Number(value || 0)));
  return Math.round(safe * 2) / 2;
}

function capitalizeAiCoachLabel(value) {
  const text = String(value || "").replace(/_/g, " ");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

// ============================================================================
// REAL DIAGNOSTIC EVALUATION MODULE
// ============================================================================

const DIAGNOSTIC_MIN_WRITING_WORDS = 80;
const DIAGNOSTIC_MAX_WRITING_CHARACTERS = 30000;
const DIAGNOSTIC_MAX_AUDIO_BYTES = 20 * 1024 * 1024;

exports.evaluateDiagnosticWriting = onCall(
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
      const testId =
        String(request.data?.testId || "").trim();
      const ieltsType =
        String(request.data?.ieltsType || "Academic").trim();
      const taskPrompt =
        String(request.data?.prompt || "").trim();
      const answer =
        String(request.data?.answer || "").trim();

      if (!testId) {
        throw new HttpsError(
            "invalid-argument",
            "Diagnostic test ID is required.",
        );
      }

      if (!taskPrompt) {
        throw new HttpsError(
            "invalid-argument",
            "Writing task prompt is required.",
        );
      }

      if (answer.length > DIAGNOSTIC_MAX_WRITING_CHARACTERS) {
        throw new HttpsError(
            "invalid-argument",
            "Writing answer is too long.",
        );
      }

      const wordCount = countWords(answer);

      if (wordCount < DIAGNOSTIC_MIN_WRITING_WORDS) {
        throw new HttpsError(
            "invalid-argument",
            "A complete writing response is required.",
        );
      }

      const userRef = db.collection("users").doc(uid);
      const testRef =
        db.collection("diagnostic_tests").doc(testId);

      const [userSnapshot, testSnapshot] = await Promise.all([
        userRef.get(),
        testRef.get(),
      ]);

      if (!testSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "Diagnostic test was not found.",
        );
      }

      const testData = testSnapshot.data() || {};

      if (String(testData.status || "") !== "published") {
        throw new HttpsError(
            "failed-precondition",
            "Diagnostic test is not published.",
        );
      }

      const storedWriting =
        testData.writing && typeof testData.writing === "object" ?
          testData.writing :
          {};

      const storedPrompt =
        String(storedWriting.prompt || "").trim();

      if (storedPrompt &&
          normalizeText(storedPrompt) !== normalizeText(taskPrompt)) {
        throw new HttpsError(
            "failed-precondition",
            "Writing task does not match the published diagnostic test.",
        );
      }

      const userData = userSnapshot.data() || {};
      const targetBand =
        normalizeBand(userData.targetBand || request.data?.targetBand || 7);

      const aiPrompt = buildDiagnosticWritingEvaluationPrompt({
        ieltsType,
        taskPrompt,
        answer,
        wordCount,
        targetBand,
      });

      try {
        const result =
          await callDiagnosticGeminiJson(aiPrompt, {
            temperature: 0.2,
            maxOutputTokens: 5000,
          });

        const evaluation =
          normalizeDiagnosticWritingEvaluation(
              result.parsed,
              wordCount,
          );

        const evaluationRef = userRef
            .collection("diagnostic_writing_evaluations")
            .doc();

        await evaluationRef.set({
          evaluationId: evaluationRef.id,
          testId,
          ieltsType,
          taskPrompt,
          answer,
          wordCount,
          ...evaluation,
          generatedModel: result.model,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {
          ...evaluation,
          evaluationId: evaluationRef.id,
          generatedModel: result.model,
        };
      } catch (error) {
        logger.error("Diagnostic writing evaluation failed.", {
          uid,
          testId,
          error: safeErrorMessage(error),
        });

        throw diagnosticHttpsError(
            error,
            "Writing evaluation is temporarily unavailable.",
        );
      }
    },
);

exports.evaluateDiagnosticSpeaking = onCall(
    {
      region: "us-central1",
      secrets: [geminiApiKey],
      timeoutSeconds: 180,
      memory: "1GiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "User must be signed in.",
        );
      }

      const uid = request.auth.uid;
      const testId =
        String(request.data?.testId || "").trim();
      const audioUrl =
        String(request.data?.audioUrl || "").trim();
      const prompts =
        normalizeDiagnosticSpeakingPrompts(request.data?.prompts);

      if (!testId) {
        throw new HttpsError(
            "invalid-argument",
            "Diagnostic test ID is required.",
        );
      }

      if (!audioUrl) {
        throw new HttpsError(
            "invalid-argument",
            "Speaking recording URL is required.",
        );
      }

      if (prompts.length === 0) {
        throw new HttpsError(
            "invalid-argument",
            "At least one speaking prompt is required.",
        );
      }

      assertAllowedDiagnosticAudioUrl(audioUrl);

      const userRef = db.collection("users").doc(uid);
      const testRef =
        db.collection("diagnostic_tests").doc(testId);

      const testSnapshot = await testRef.get();

      if (!testSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "Diagnostic test was not found.",
        );
      }

      const testData = testSnapshot.data() || {};

      if (String(testData.status || "") !== "published") {
        throw new HttpsError(
            "failed-precondition",
            "Diagnostic test is not published.",
        );
      }

      try {
        const audio = await downloadDiagnosticAudio(audioUrl);

        const prompt =
          buildDiagnosticSpeakingEvaluationPrompt(prompts);

        const result = await callDiagnosticGeminiJson(
            [
              {
                text: prompt,
              },
              {
                inlineData: {
                  mimeType: audio.mimeType,
                  data: audio.base64Data,
                },
              },
            ],
            {
              temperature: 0.15,
              maxOutputTokens: 6000,
            },
        );

        const evaluation =
          normalizeDiagnosticSpeakingEvaluation(result.parsed);

        const evaluationRef = userRef
            .collection("diagnostic_speaking_evaluations")
            .doc();

        await evaluationRef.set({
          evaluationId: evaluationRef.id,
          testId,
          prompts,
          audioUrl,
          audioMimeType: audio.mimeType,
          audioBytes: audio.byteLength,
          ...evaluation,
          generatedModel: result.model,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });

        return {
          ...evaluation,
          evaluationId: evaluationRef.id,
          generatedModel: result.model,
        };
      } catch (error) {
        logger.error("Diagnostic speaking evaluation failed.", {
          uid,
          testId,
          error: safeErrorMessage(error),
        });

        throw diagnosticHttpsError(
            error,
            "Speaking evaluation is temporarily unavailable.",
        );
      }
    },
);

function buildDiagnosticWritingEvaluationPrompt({
  ieltsType,
  taskPrompt,
  answer,
  wordCount,
  targetBand,
}) {
  return `
You are a strict but fair IELTS Writing examiner.

This is independent IELTS-style preparation content. Do not claim that the
result is an official IELTS score.

CANDIDATE SETTINGS
- IELTS type: ${ieltsType}
- Target band: ${targetBand}
- Submitted word count: ${wordCount}

WRITING TASK
${taskPrompt}

CANDIDATE ANSWER
${answer}

EVALUATION REQUIREMENTS
1. Evaluate Task Achievement or Task Response.
2. Evaluate Coherence and Cohesion.
3. Evaluate Lexical Resource.
4. Evaluate Grammatical Range and Accuracy.
5. Use IELTS half-band increments from 0.0 to 9.0.
6. Base every score on evidence in the candidate answer.
7. Penalize an incomplete response, weak development, missing overview,
   unclear progression, repetition, informal language, memorized language,
   grammar errors and inaccurate vocabulary when applicable.
8. Do not inflate the score because the answer is long.
9. Give concise, specific and actionable feedback.
10. Return valid JSON only.

Return this exact JSON structure:
{
  "overallBand": 6.5,
  "taskResponse": 6.5,
  "coherenceCohesion": 6.5,
  "lexicalResource": 6.0,
  "grammarAccuracy": 6.0,
  "summary": "A concise evidence-based evaluation.",
  "strengths": [
    "Specific strength"
  ],
  "improvements": [
    "Specific improvement"
  ],
  "grammarErrors": [
    {
      "original": "Incorrect sentence fragment",
      "correction": "Corrected sentence fragment",
      "explanation": "Brief explanation"
    }
  ],
  "repeatedVocabulary": [
    "word"
  ],
  "informalWords": [
    "word"
  ],
  "missingOverview": false,
  "weakParagraphs": [
    "Paragraph description"
  ],
  "actionPlan": [
    "Actionable next step"
  ]
}
`;
}

function buildDiagnosticSpeakingEvaluationPrompt(prompts) {
  return `
You are a strict but fair IELTS Speaking examiner.

Listen to the attached candidate recording and evaluate the response against
the supplied IELTS-style prompts.

PROMPTS
${JSON.stringify(prompts, null, 2)}

EVALUATION REQUIREMENTS
1. Produce an accurate transcript of intelligible speech.
2. Evaluate Fluency and Coherence.
3. Evaluate Lexical Resource.
4. Evaluate Grammatical Range and Accuracy.
5. Evaluate Pronunciation using the audio itself.
6. Use IELTS half-band increments from 0.0 to 9.0.
7. Consider speaking speed, pauses, fillers, repetition, answer relevance,
   vocabulary range, sentence variety, word stress and intonation.
8. Do not claim that this is an official IELTS score.
9. Do not invent words that cannot be heard.
10. Return valid JSON only.

Return this exact JSON structure:
{
  "overallBand": 6.5,
  "fluencyCoherence": 6.5,
  "lexicalResource": 6.0,
  "grammarAccuracy": 6.0,
  "pronunciation": 6.5,
  "transcript": "Complete transcript",
  "summary": "A concise evidence-based evaluation.",
  "speakingSpeedWpm": 115,
  "pauseCount": 8,
  "fillerCount": 5,
  "repetitionCount": 3,
  "answerRelevance": 7.0,
  "vocabularyRange": 6.0,
  "sentenceVariety": 6.0,
  "mispronouncedWords": [
    {
      "word": "example",
      "suggestion": "Pronunciation guidance"
    }
  ],
  "strengths": [
    "Specific strength"
  ],
  "improvements": [
    "Specific improvement"
  ]
}
`;
}

async function callDiagnosticGeminiJson(
    contents,
    {
      temperature,
      maxOutputTokens,
    },
) {
  const {GoogleGenAI} = await import("@google/genai");

  const ai = new GoogleGenAI({
    apiKey: geminiApiKey.value(),
  });

  const geminiResult = await callGeminiWithRetry(ai, {
    contents,
    config: {
      temperature,
      maxOutputTokens,
      responseMimeType: "application/json",
    },
  });

  const response = geminiResult.response;
  const responseText = String(response.text || "").trim();

  if (!responseText) {
    throw new Error(
        "Gemini returned an empty diagnostic evaluation.",
    );
  }

  return {
    parsed: parseDiagnosticJson(responseText),
    model: geminiResult.model,
  };
}

function parseDiagnosticJson(value) {
  const cleaned = String(value || "")
      .replace(/```json/gi, "")
      .replace(/```/g, "")
      .trim();

  const start = cleaned.indexOf("{");

  if (start === -1) {
    throw new Error(
        "Gemini returned invalid diagnostic JSON: no JSON object found.",
    );
  }

  let depth = 0;
  let inString = false;
  let escaped = false;

  for (let index = start; index < cleaned.length; index++) {
    const character = cleaned[index];

    if (escaped) {
      escaped = false;
      continue;
    }

    if (character === "\\") {
      if (inString) escaped = true;
      continue;
    }

    if (character === "\"") {
      inString = !inString;
      continue;
    }

    if (inString) continue;

    if (character === "{") depth++;

    if (character === "}") {
      depth--;

      if (depth === 0) {
        const jsonOnly = cleaned.slice(start, index + 1);

        try {
          return JSON.parse(jsonOnly);
        } catch (error) {
          throw new Error(
              "Gemini returned invalid diagnostic JSON: " +
              safeErrorMessage(error),
          );
        }
      }
    }
  }

  throw new Error(
      "Gemini returned invalid diagnostic JSON: incomplete JSON object.",
  );
}

function normalizeDiagnosticWritingEvaluation(
    data,
    wordCount,
) {
  const taskResponse =
    normalizeBand(data.taskResponse || data.taskAchievement);
  const coherenceCohesion =
    normalizeBand(data.coherenceCohesion);
  const lexicalResource =
    normalizeBand(data.lexicalResource);
  const grammarAccuracy =
    normalizeBand(
        data.grammarAccuracy ||
        data.grammaticalRangeAndAccuracy,
    );

  const calculatedOverall = normalizeBand(
      (
        taskResponse +
        coherenceCohesion +
        lexicalResource +
        grammarAccuracy
      ) / 4,
  );

  const returnedOverall = normalizeBand(data.overallBand);
  const overallBand = returnedOverall > 0 ?
    normalizeBand(
        (returnedOverall + calculatedOverall) / 2,
    ) :
    calculatedOverall;

  return {
    overallBand,
    taskResponse,
    coherenceCohesion,
    lexicalResource,
    grammarAccuracy,
    wordCount,
    summary: limitDiagnosticText(data.summary, 2500),
    strengths:
      normalizeDiagnosticStringList(data.strengths, 8),
    improvements:
      normalizeDiagnosticStringList(data.improvements, 8),
    grammarErrors:
      normalizeDiagnosticCorrectionList(data.grammarErrors, 20),
    repeatedVocabulary:
      normalizeDiagnosticStringList(
          data.repeatedVocabulary,
          20,
      ),
    informalWords:
      normalizeDiagnosticStringList(data.informalWords, 20),
    missingOverview: Boolean(data.missingOverview),
    weakParagraphs:
      normalizeDiagnosticStringList(data.weakParagraphs, 10),
    actionPlan:
      normalizeDiagnosticStringList(data.actionPlan, 10),
  };
}

function normalizeDiagnosticSpeakingEvaluation(data) {
  const fluencyCoherence =
    normalizeBand(data.fluencyCoherence);
  const lexicalResource =
    normalizeBand(data.lexicalResource);
  const grammarAccuracy =
    normalizeBand(
        data.grammarAccuracy ||
        data.grammaticalRangeAndAccuracy,
    );
  const pronunciation =
    normalizeBand(data.pronunciation);

  const calculatedOverall = normalizeBand(
      (
        fluencyCoherence +
        lexicalResource +
        grammarAccuracy +
        pronunciation
      ) / 4,
  );

  const returnedOverall = normalizeBand(data.overallBand);
  const overallBand = returnedOverall > 0 ?
    normalizeBand(
        (returnedOverall + calculatedOverall) / 2,
    ) :
    calculatedOverall;

  return {
    overallBand,
    fluencyCoherence,
    lexicalResource,
    grammarAccuracy,
    pronunciation,
    transcript:
      limitDiagnosticText(data.transcript, 20000),
    summary: limitDiagnosticText(data.summary, 2500),
    speakingSpeedWpm:
      clampNumber(data.speakingSpeedWpm, 0, 400, 0),
    pauseCount:
      clampNumber(data.pauseCount, 0, 10000, 0),
    fillerCount:
      clampNumber(data.fillerCount, 0, 10000, 0),
    repetitionCount:
      clampNumber(data.repetitionCount, 0, 10000, 0),
    answerRelevance:
      normalizeBand(data.answerRelevance),
    vocabularyRange:
      normalizeBand(data.vocabularyRange),
    sentenceVariety:
      normalizeBand(data.sentenceVariety),
    mispronouncedWords:
      normalizeDiagnosticPronunciationList(
          data.mispronouncedWords,
          30,
      ),
    strengths:
      normalizeDiagnosticStringList(data.strengths, 8),
    improvements:
      normalizeDiagnosticStringList(data.improvements, 8),
  };
}

function normalizeDiagnosticSpeakingPrompts(value) {
  if (!Array.isArray(value)) return [];

  return value
      .map((item) => {
        if (!item || typeof item !== "object") {
          return null;
        }

        const prompt =
          limitDiagnosticText(item.prompt, 2000);

        if (!prompt) return null;

        return {
          part: limitDiagnosticText(item.part, 100),
          prompt,
          duration: limitDiagnosticText(item.duration, 100),
        };
      })
      .filter(Boolean)
      .slice(0, 10);
}

function normalizeDiagnosticStringList(value, limit) {
  if (!Array.isArray(value)) return [];

  return value
      .map((item) => limitDiagnosticText(item, 1000))
      .filter(Boolean)
      .slice(0, limit);
}

function normalizeDiagnosticCorrectionList(value, limit) {
  if (!Array.isArray(value)) return [];

  return value
      .map((item) => {
        if (!item || typeof item !== "object") {
          return null;
        }

        const original =
          limitDiagnosticText(item.original, 1000);
        const correction =
          limitDiagnosticText(item.correction, 1000);
        const explanation =
          limitDiagnosticText(item.explanation, 1200);

        if (!original && !correction && !explanation) {
          return null;
        }

        return {
          original,
          correction,
          explanation,
        };
      })
      .filter(Boolean)
      .slice(0, limit);
}

function normalizeDiagnosticPronunciationList(value, limit) {
  if (!Array.isArray(value)) return [];

  return value
      .map((item) => {
        if (typeof item === "string") {
          return {
            word: limitDiagnosticText(item, 200),
            suggestion: "",
          };
        }

        if (!item || typeof item !== "object") {
          return null;
        }

        const word =
          limitDiagnosticText(item.word, 200);
        const suggestion =
          limitDiagnosticText(item.suggestion, 600);

        if (!word && !suggestion) return null;

        return {
          word,
          suggestion,
        };
      })
      .filter(Boolean)
      .slice(0, limit);
}

function limitDiagnosticText(value, maximumLength) {
  return String(value || "")
      .trim()
      .slice(0, maximumLength);
}

function assertAllowedDiagnosticAudioUrl(audioUrl) {
  let parsed;

  try {
    parsed = new URL(audioUrl);
  } catch (error) {
    throw new HttpsError(
        "invalid-argument",
        "Speaking audio URL is invalid.",
    );
  }

  if (parsed.protocol !== "https:") {
    throw new HttpsError(
        "invalid-argument",
        "Speaking audio URL must use HTTPS.",
    );
  }

  const hostname = parsed.hostname.toLowerCase();
  const allowed =
    hostname === "firebasestorage.googleapis.com" ||
    hostname === "storage.googleapis.com" ||
    hostname.endsWith(".storage.googleapis.com");

  if (!allowed) {
    throw new HttpsError(
        "permission-denied",
        "Speaking audio must be stored in Firebase Storage.",
    );
  }
}

async function downloadDiagnosticAudio(audioUrl) {
  const response = await fetch(audioUrl, {
    method: "GET",
    redirect: "follow",
    signal: AbortSignal.timeout(45000),
  });

  if (!response.ok) {
    throw new Error(
        `Unable to download speaking audio: HTTP ${response.status}.`,
    );
  }

  const contentLength =
    Number(response.headers.get("content-length") || 0);

  if (contentLength > DIAGNOSTIC_MAX_AUDIO_BYTES) {
    throw new HttpsError(
        "invalid-argument",
        "Speaking recording is larger than 20 MB.",
    );
  }

  const arrayBuffer = await response.arrayBuffer();

  if (arrayBuffer.byteLength === 0) {
    throw new Error("Speaking recording is empty.");
  }

  if (arrayBuffer.byteLength > DIAGNOSTIC_MAX_AUDIO_BYTES) {
    throw new HttpsError(
        "invalid-argument",
        "Speaking recording is larger than 20 MB.",
    );
  }

  const contentType =
    String(response.headers.get("content-type") || "")
        .split(";")[0]
        .trim()
        .toLowerCase();

  const allowedMimeTypes = new Set([
    "audio/mp4",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mpeg",
    "audio/mp3",
    "audio/wav",
    "audio/x-wav",
    "audio/webm",
    "audio/ogg",
    "application/octet-stream",
  ]);

  if (contentType && !allowedMimeTypes.has(contentType)) {
    throw new HttpsError(
        "invalid-argument",
        `Unsupported speaking audio type: ${contentType}.`,
    );
  }

  return {
    base64Data: Buffer.from(arrayBuffer).toString("base64"),
    byteLength: arrayBuffer.byteLength,
    mimeType: normalizeDiagnosticAudioMimeType(contentType),
  };
}

function normalizeDiagnosticAudioMimeType(value) {
  switch (String(value || "").toLowerCase()) {
    case "audio/m4a":
    case "audio/x-m4a":
      return "audio/mp4";
    case "audio/mp3":
      return "audio/mpeg";
    case "audio/x-wav":
      return "audio/wav";
    case "application/octet-stream":
    case "":
      return "audio/mp4";
    default:
      return String(value);
  }
}

function diagnosticHttpsError(error, fallbackMessage) {
  if (error instanceof HttpsError) {
    return error;
  }

  const message = safeErrorMessage(error);
  const lower = message.toLowerCase();

  if (lower.includes("quota") ||
      lower.includes("429") ||
      lower.includes("resource_exhausted")) {
    return new HttpsError(
        "resource-exhausted",
        "AI evaluation quota is temporarily exhausted.",
        message,
    );
  }

  if (lower.includes("timeout") ||
      lower.includes("etimedout") ||
      lower.includes("abort")) {
    return new HttpsError(
        "deadline-exceeded",
        "AI evaluation timed out. Please try again.",
        message,
    );
  }

  return new HttpsError(
      "internal",
      fallbackMessage,
      message,
  );
}

// ============================================================================
// DIAGNOSTIC AI GENERATION MODULE
// ============================================================================

exports.createDiagnosticGenerationJob = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Administrator must be signed in.",
        );
      }

      const data = normalizeDiagnosticGenerationRequest(
          request.data || {},
      );
      const testRef = db.collection("diagnostic_tests").doc();
      const jobRef = db
          .collection("diagnostic_generation_jobs")
          .doc();

      const batch = db.batch();
      batch.set(testRef, {
        title: data.title,
        description:
          "AI-generated four-skill IELTS diagnostic assessment.",
        status: "generating",
        ieltsType: data.ieltsType,
        totalDurationMinutes: data.durationMinutes,
        generationJobId: jobRef.id,
        generationProgress: 0,
        generationStep: "Queued for AI generation",
        generationError: "",
        generatedBy: "gemini",
        createdBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      batch.set(jobRef, {
        ...data,
        testId: testRef.id,
        requestedBy: request.auth.uid,
        status: "queued",
        progress: 0,
        currentStep: "Queued",
        error: "",
        attempt: 1,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      await batch.commit();

      return {
        success: true,
        jobId: jobRef.id,
        testId: testRef.id,
      };
    },
);

exports.retryDiagnosticGenerationJob = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Administrator must be signed in.",
        );
      }

      const jobId = String(request.data?.jobId || "").trim();
      if (!jobId) {
        throw new HttpsError(
            "invalid-argument",
            "Generation job ID is required.",
        );
      }

      const oldRef = db
          .collection("diagnostic_generation_jobs")
          .doc(jobId);
      const oldSnapshot = await oldRef.get();

      if (!oldSnapshot.exists) {
        throw new HttpsError(
            "not-found",
            "Diagnostic generation job was not found.",
        );
      }

      const oldJob = oldSnapshot.data() || {};
      const testId = String(oldJob.testId || "").trim();

      if (!testId) {
        throw new HttpsError(
            "failed-precondition",
            "Generation job has no diagnostic test ID.",
        );
      }

      const newRef = db
          .collection("diagnostic_generation_jobs")
          .doc();
      const testRef = db.collection("diagnostic_tests").doc(testId);
      const batch = db.batch();

      batch.set(newRef, {
        ...oldJob,
        status: "queued",
        progress: 0,
        currentStep: "Queued for retry",
        error: "",
        attempt: Number(oldJob.attempt || 1) + 1,
        retriedFrom: jobId,
        requestedBy: request.auth.uid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        completedAt: FieldValue.delete(),
      });
      batch.set(testRef, {
        status: "generating",
        generationJobId: newRef.id,
        generationProgress: 0,
        generationStep: "Queued for retry",
        generationError: "",
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      await batch.commit();

      return {
        success: true,
        jobId: newRef.id,
        testId,
      };
    },
);

exports.processDiagnosticGenerationJob = onDocumentCreated(
    {
      document: "diagnostic_generation_jobs/{jobId}",
      region: "us-central1",
      secrets: [geminiApiKey],
      retry: false,
      timeoutSeconds: 540,
      memory: "1GiB",
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.error("Diagnostic generation snapshot is missing.");
        return;
      }

      const jobRef = snapshot.ref;
      const job = snapshot.data() || {};
      const jobId = event.params.jobId;
      const testId = String(job.testId || "").trim();

      if (job.status !== "queued") {
        logger.info(
            "Ignoring diagnostic job because status is not queued.",
            {jobId, status: job.status},
        );
        return;
      }

      if (!testId) {
        await jobRef.set({
          status: "failed",
          progress: 0,
          currentStep: "Generation failed",
          error: "Diagnostic test ID is missing.",
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        return;
      }

      const testRef = db.collection("diagnostic_tests").doc(testId);

      try {
        await updateDiagnosticGenerationProgress(
            jobRef,
            testRef,
            8,
            "Designing IELTS test structure",
        );

        const generated = await generateDiagnosticJson(job);
        validateGeneratedDiagnostic(generated, job);

        await updateDiagnosticGenerationProgress(
            jobRef,
            testRef,
            60,
            "Generating Listening audio",
        );

        const audioData = await synthesizeDiagnosticListeningAudio({
          testId,
          script: String(generated.listening.script || ""),
        });

        await updateDiagnosticGenerationProgress(
            jobRef,
            testRef,
            86,
            "Validating generated content",
        );

        const finalDocument = buildDiagnosticDraft(
            job,
            generated,
            audioData,
        );

        const batch = db.batch();
        batch.set(testRef, finalDocument, {merge: true});
        batch.set(jobRef, {
          status: "completed",
          progress: 100,
          currentStep: "Ready for admin review",
          createdTestIds: [testId],
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        await batch.commit();

        logger.info("Diagnostic AI generation completed.", {
          jobId,
          testId,
          generatedModel: generated.generatedModel,
        });
      } catch (error) {
        const message = diagnosticSafeError(error);

        logger.error("Diagnostic AI generation failed.", {
          jobId,
          testId,
          error: message,
        });

        const batch = db.batch();
        batch.set(jobRef, {
          status: "failed",
          progress: 0,
          currentStep: "Generation failed",
          error: message,
          completedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        batch.set(testRef, {
          status: "draft",
          generationError: message,
          generationStep: "Generation failed",
          updatedAt: FieldValue.serverTimestamp(),
        }, {merge: true});
        await batch.commit();
      }
    },
);

async function generateDiagnosticJson(job) {
  const {GoogleGenAI} = await import("@google/genai");
  const ai = new GoogleGenAI({apiKey: geminiApiKey.value()});
  const prompt = buildDiagnosticGenerationPrompt(job);

  const geminiResult = await callGeminiWithRetry(ai, {
    contents: prompt,
    config: {
      temperature: 0.55,
      maxOutputTokens: 24000,
      responseMimeType: "application/json",
    },
  });

  const responseText = String(
      geminiResult.response.text || "",
  ).trim();

  if (!responseText) {
    throw new Error(
        "Gemini returned an empty diagnostic response.",
    );
  }

  return {
    ...parseDiagnosticGenerationJson(responseText),
    generatedModel: geminiResult.model,
  };
}

function buildDiagnosticGenerationPrompt(job) {
  return `
You are an expert IELTS assessment author.
Create one original, copyright-safe, high-quality IELTS-style diagnostic test.
Do not copy, reproduce, or closely paraphrase Cambridge, British Council,
IDP, or any published official IELTS paper.

TEST SETTINGS
- IELTS type: ${job.ieltsType}
- Difficulty: ${job.difficulty}
- Topic guidance: ${job.topic}
- Listening questions: ${job.listeningQuestionCount}
- Reading questions: ${job.readingQuestionCount}
- Writing task: ${job.writingTaskType}
- Speaking prompts: ${job.speakingPromptCount}
- Total duration: ${job.durationMinutes} minutes
- Unique generation seed: ${job.testId}-${job.attempt || 1}

STRICT QUALITY RULES
1. Use natural international or British English appropriate for IELTS.
2. Listening script and questions must match exactly.
3. Listening answers must occur in the script in question order.
4. Reading answers must be directly supported by the passage.
5. Use varied IELTS question types and unambiguous answer keys.
6. Every acceptedAnswers array must contain the correct answer and reasonable
   spelling or capitalization variants where relevant.
7. For multiple choice, acceptedAnswers should contain the option key such as
   A, B, C or D, and options must contain matching keys.
8. Writing prompt must be complete, realistic and appropriate for the selected
   IELTS type.
9. Speaking prompts should include Part 1, Part 2 and Part 3 when the requested
   prompt count permits.
10. Avoid sensitive, political, violent, sexual, discriminatory or medical
    content.
11. Return valid JSON only. Do not use markdown code fences.
12. For Academic Task 1, writing.visual is mandatory and must contain the
    complete data needed to display the visual in the mobile app.
13. writing.visual.type must be bar, line, pie, table, process, map or mixed.
14. For bar, line, pie and mixed, provide categories and numerical series.
    Every series must contain exactly one value for every category.
15. For table, provide tableColumns and tableRows.
16. For process, provide at least five processSteps.
17. For map, provide at least three mapPoints with x and y from 0 to 100.
18. For Task 2 and General Training letters, set visual.type to "none" and
    leave all visual arrays empty.
19. The writing prompt and visual data must describe exactly the same facts.

RETURN THIS EXACT STRUCTURE
{
  "title": "Original diagnostic title",
  "description": "Short description",
  "listening": {
    "title": "Listening scenario title",
    "script": "Full dialogue or monologue suitable for speech synthesis",
    "questions": [
      {
        "id": "l1",
        "type": "multiple_choice",
        "instruction": "Choose the correct answer.",
        "prompt": "Question text",
        "options": {
          "A": "Option A",
          "B": "Option B",
          "C": "Option C",
          "D": "Option D"
        },
        "acceptedAnswers": ["B"]
      }
    ]
  },
  "reading": {
    "passageTitle": "Original passage title",
    "passage": "A coherent original reading passage",
    "questions": [
      {
        "id": "r1",
        "type": "true_false_not_given",
        "instruction": "Choose True, False or Not Given.",
        "prompt": "Statement",
        "options": {
          "True": "True",
          "False": "False",
          "Not Given": "Not Given"
        },
        "acceptedAnswers": ["True"]
      }
    ]
  },
  "writing": {
    "taskType": "${job.writingTaskType}",
    "prompt": "Complete writing task prompt",
    "minimumWords": 150,
    "recommendedMinutes": 20,
    "visual": {
      "type": "bar",
      "title": "Clear chart title",
      "subtitle": "Optional date or context",
      "xAxisLabel": "Category",
      "yAxisLabel": "Percentage",
      "unit": "%",
      "categories": ["Country A", "Country B", "Country C"],
      "series": [
        {
          "name": "Series 1",
          "values": [45, 62, 78]
        },
        {
          "name": "Series 2",
          "values": [38, 55, 69]
        }
      ],
      "tableColumns": [],
      "tableRows": [],
      "processSteps": [],
      "mapPoints": [],
      "note": "Source: AI-generated IELTS practice data"
    }
  },
  "speaking": {
    "prompts": [
      {
        "part": "Part 1",
        "duration": "30–45 seconds",
        "prompt": "Speaking prompt"
      }
    ]
  }
}
`;
}

async function synthesizeDiagnosticListeningAudio({
  testId,
  script,
}) {
  const cleanScript = String(script || "").trim();

  if (!cleanScript) {
    throw new Error("Generated Listening script is empty.");
  }

  const chunks = splitDiagnosticTextForTts(cleanScript, 4300);
  const audioBuffers = [];

  for (let index = 0; index < chunks.length; index++) {
    const [response] = await retryOperation(
        () => ttsClient.synthesizeSpeech({
          input: {text: chunks[index]},
          voice: {
            languageCode: "en-GB",
            ssmlGender: "NEUTRAL",
          },
          audioConfig: {
            audioEncoding: "MP3",
            speakingRate: 0.92,
            pitch: 0,
          },
        }),
        {
          attempts: MAX_API_RETRIES,
          operationName:
            `Diagnostic TTS chunk ${index + 1}`,
        },
    );

    if (!response.audioContent) {
      throw new Error(
          `Cloud TTS returned empty audio for chunk ${index + 1}.`,
      );
    }

    audioBuffers.push(
        Buffer.isBuffer(response.audioContent) ?
          response.audioContent :
          Buffer.from(response.audioContent),
    );
  }

  const audioBuffer = Buffer.concat(audioBuffers);
  if (audioBuffer.length === 0) {
    throw new Error("Generated diagnostic audio is empty.");
  }

  const storagePath =
    `diagnostic_audio/${testId}/ai_listening.mp3`;
  const file = bucket.file(storagePath);

  await retryOperation(
      () => file.save(audioBuffer, {
        contentType: "audio/mpeg",
        resumable: false,
        metadata: {
          cacheControl: "public,max-age=31536000,immutable",
          metadata: {
            testId,
            generatedBy: "google-cloud-text-to-speech",
            chunkCount: String(chunks.length),
          },
        },
      }),
      {
        attempts: MAX_STORAGE_RETRIES,
        operationName: "Diagnostic audio upload",
      },
  );

  return {
    audioUrl: await getDownloadURL(file),
    audioStoragePath: storagePath,
    audioStatus: "ready",
    audioFormat: "mp3",
    audioProvider: "google-cloud-text-to-speech",
    audioChunkCount: chunks.length,
    audioDurationSeconds: estimateAudioDuration(cleanScript),
  };
}

function splitDiagnosticTextForTts(value, maximumBytes) {
  const paragraphs = String(value || "")
      .split(/\n+/)
      .map((item) => item.trim())
      .filter(Boolean);
  const chunks = [];
  let current = "";

  for (const paragraph of paragraphs) {
    const candidate = current ? `${current}\n${paragraph}` : paragraph;

    if (Buffer.byteLength(candidate, "utf8") <= maximumBytes) {
      current = candidate;
      continue;
    }

    if (current) {
      chunks.push(current);
      current = "";
    }

    const words = paragraph.split(/\s+/).filter(Boolean);
    let wordChunk = "";

    for (const word of words) {
      const wordCandidate = wordChunk ?
        `${wordChunk} ${word}` :
        word;

      if (Buffer.byteLength(wordCandidate, "utf8") <= maximumBytes) {
        wordChunk = wordCandidate;
      } else {
        if (wordChunk) chunks.push(wordChunk);
        wordChunk = word;
      }
    }

    if (wordChunk) current = wordChunk;
  }

  if (current) chunks.push(current);
  return chunks;
}

function buildDiagnosticDraft(job, generated, audioData) {
  return {
    title: String(generated.title || job.title).trim(),
    description: String(
        generated.description ||
        "AI-generated IELTS diagnostic assessment.",
    ).trim(),
    status: "draft",
    isPublished: false,
    ieltsType: job.ieltsType,
    totalDurationMinutes: Number(job.durationMinutes || 30),
    difficulty: job.difficulty,
    topic: job.topic,
    source: "ai",
    generatedBy: "gemini",
    generatedModel: generated.generatedModel || null,
    listening: {
      title: String(
          generated.listening.title || "Listening Recording",
      ).trim(),
      script: String(generated.listening.script || "").trim(),
      ...audioData,
      questions: normalizeDiagnosticQuestions(
          generated.listening.questions,
          "l",
      ),
    },
    reading: {
      passageTitle: String(
          generated.reading.passageTitle || "Reading Passage",
      ).trim(),
      passage: String(generated.reading.passage || "").trim(),
      questions: normalizeDiagnosticQuestions(
          generated.reading.questions,
          "r",
      ),
    },
    writing: {
      taskType: String(
          generated.writing.taskType || job.writingTaskType,
      ).trim(),
      prompt: String(generated.writing.prompt || "").trim(),
      minimumWords: diagnosticClamp(
          generated.writing.minimumWords,
          100,
          300,
          String(job.writingTaskType || "").includes("Task 2") ?
            250 :
            150,
      ),
      recommendedMinutes: diagnosticClamp(
          generated.writing.recommendedMinutes,
          15,
          45,
          String(job.writingTaskType || "").includes("Task 2") ?
            40 :
            20,
      ),
      visual: normalizeDiagnosticWritingVisual(
          generated.writing.visual,
          job.writingTaskType,
      ),
    },
    speaking: {
      prompts: normalizeDiagnosticSpeakingPrompts(
          generated.speaking.prompts,
      ),
    },
    generationProgress: 100,
    generationStep: "Ready for admin review",
    generationError: "",
    generatedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}


function normalizeDiagnosticWritingVisual(value, writingTaskType) {
  const isAcademicTask1 =
    String(writingTaskType || "").toLowerCase()
        .includes("academic task 1");

  if (!isAcademicTask1) {
    return {
      type: "none",
      title: "",
      subtitle: "",
      xAxisLabel: "",
      yAxisLabel: "",
      unit: "",
      categories: [],
      series: [],
      tableColumns: [],
      tableRows: [],
      processSteps: [],
      mapPoints: [],
      note: "",
    };
  }

  const visual =
    value && typeof value === "object" ? value : {};

  const supportedTypes = new Set([
    "bar",
    "line",
    "pie",
    "table",
    "process",
    "map",
    "mixed",
  ]);

  const type = supportedTypes.has(
      String(visual.type || "").toLowerCase(),
  ) ?
    String(visual.type).toLowerCase() :
    "bar";

  const categories = Array.isArray(visual.categories) ?
    visual.categories
        .map((item) => diagnosticLimit(item, 80))
        .filter(Boolean)
        .slice(0, 12) :
    [];

  const series = Array.isArray(visual.series) ?
    visual.series
        .map((item, index) => {
          if (!item || typeof item !== "object") return null;

          const values = Array.isArray(item.values) ?
            item.values
                .map((entry) => Number(entry))
                .filter(Number.isFinite)
                .slice(0, 12) :
            [];

          return {
            name: diagnosticLimit(
                item.name || `Series ${index + 1}`,
                80,
            ),
            values,
          };
        })
        .filter(Boolean)
        .slice(0, 4) :
    [];

  const tableColumns = Array.isArray(visual.tableColumns) ?
    visual.tableColumns
        .map((item) => diagnosticLimit(item, 80))
        .filter(Boolean)
        .slice(0, 8) :
    [];

  const tableRows = Array.isArray(visual.tableRows) ?
    visual.tableRows
        .filter(Array.isArray)
        .map((row) => row
            .map((item) => diagnosticLimit(item, 80))
            .slice(0, tableColumns.length || 8))
        .slice(0, 12) :
    [];

  const processSteps = Array.isArray(visual.processSteps) ?
    visual.processSteps
        .map((item) => diagnosticLimit(item, 240))
        .filter(Boolean)
        .slice(0, 12) :
    [];

  const mapPoints = Array.isArray(visual.mapPoints) ?
    visual.mapPoints
        .map((item) => {
          if (!item || typeof item !== "object") return null;

          return {
            label: diagnosticLimit(item.label, 80),
            x: diagnosticClamp(item.x, 0, 100, 50),
            y: diagnosticClamp(item.y, 0, 100, 50),
          };
        })
        .filter((item) => item && item.label)
        .slice(0, 12) :
    [];

  return {
    type,
    title: diagnosticLimit(visual.title, 180),
    subtitle: diagnosticLimit(visual.subtitle, 180),
    xAxisLabel: diagnosticLimit(visual.xAxisLabel, 80),
    yAxisLabel: diagnosticLimit(visual.yAxisLabel, 80),
    unit: diagnosticLimit(visual.unit, 20),
    categories,
    series,
    tableColumns,
    tableRows,
    processSteps,
    mapPoints,
    note: diagnosticLimit(
        visual.note || "Source: AI-generated IELTS practice data",
        180,
    ),
  };
}

function validateDiagnosticWritingVisual(generated, job) {
  const isAcademicTask1 =
    String(job.writingTaskType || "").toLowerCase()
        .includes("academic task 1");

  if (!isAcademicTask1) return;

  const visual = normalizeDiagnosticWritingVisual(
      generated.writing?.visual,
      job.writingTaskType,
  );

  if (visual.type === "table") {
    if (visual.tableColumns.length < 2 ||
        visual.tableRows.length < 2) {
      throw new Error(
          "Academic Task 1 table data is incomplete.",
      );
    }
    return;
  }

  if (visual.type === "process") {
    if (visual.processSteps.length < 5) {
      throw new Error(
          "Academic Task 1 process requires at least 5 steps.",
      );
    }
    return;
  }

  if (visual.type === "map") {
    if (visual.mapPoints.length < 3) {
      throw new Error(
          "Academic Task 1 map requires at least 3 labelled points.",
      );
    }
    return;
  }

  if (visual.categories.length < 3 ||
      visual.series.length < 1) {
    throw new Error(
        "Academic Task 1 chart data is incomplete.",
    );
  }

  for (const series of visual.series) {
    if (series.values.length !== visual.categories.length) {
      throw new Error(
          "Every Academic Task 1 series must contain one value " +
          "for each category.",
      );
    }
  }
}

function validateGeneratedDiagnostic(generated, job) {
  if (!generated || typeof generated !== "object") {
    throw new Error("Gemini returned an invalid diagnostic object.");
  }

  const listeningQuestions = generated.listening?.questions;
  const readingQuestions = generated.reading?.questions;
  const speakingPrompts = generated.speaking?.prompts;

  if (!generated.listening?.script ||
      !Array.isArray(listeningQuestions)) {
    throw new Error("Generated Listening section is incomplete.");
  }

  if (listeningQuestions.length !==
      Number(job.listeningQuestionCount || 10)) {
    throw new Error(
        `Expected ${job.listeningQuestionCount} Listening questions, ` +
        `received ${listeningQuestions.length}.`,
    );
  }

  if (!generated.reading?.passage ||
      !Array.isArray(readingQuestions)) {
    throw new Error("Generated Reading section is incomplete.");
  }

  if (readingQuestions.length !==
      Number(job.readingQuestionCount || 10)) {
    throw new Error(
        `Expected ${job.readingQuestionCount} Reading questions, ` +
        `received ${readingQuestions.length}.`,
    );
  }

  if (!generated.writing?.prompt) {
    throw new Error("Generated Writing task is missing.");
  }

  validateDiagnosticWritingVisual(generated, job);

  if (!Array.isArray(speakingPrompts) ||
      speakingPrompts.length !==
      Number(job.speakingPromptCount || 3)) {
    throw new Error(
        `Expected ${job.speakingPromptCount} Speaking prompts, ` +
        `received ${speakingPrompts?.length || 0}.`,
    );
  }

  validateDiagnosticQuestionSet(listeningQuestions, "Listening");
  validateDiagnosticQuestionSet(readingQuestions, "Reading");
}

function validateDiagnosticQuestionSet(questions, sectionName) {
  const seenIds = new Set();
  const seenPrompts = new Set();

  for (let index = 0; index < questions.length; index++) {
    const question = questions[index] || {};
    const id = String(question.id || "").trim();
    const prompt = String(question.prompt || "").trim();
    const answers = Array.isArray(question.acceptedAnswers) ?
      question.acceptedAnswers
          .map((item) => String(item || "").trim())
          .filter(Boolean) :
      [];

    if (!id) {
      throw new Error(
          `${sectionName} question ${index + 1} has no ID.`,
      );
    }
    if (seenIds.has(id)) {
      throw new Error(`${sectionName} contains duplicate question IDs.`);
    }
    seenIds.add(id);

    if (!prompt) {
      throw new Error(
          `${sectionName} question ${index + 1} has no prompt.`,
      );
    }

    const promptKey = normalizeText(prompt);
    if (seenPrompts.has(promptKey)) {
      throw new Error(`${sectionName} contains duplicate questions.`);
    }
    seenPrompts.add(promptKey);

    if (answers.length === 0) {
      throw new Error(
          `${sectionName} question ${index + 1} has no answer key.`,
      );
    }
  }
}

async function updateDiagnosticGenerationProgress(
    jobRef,
    testRef,
    progress,
    currentStep,
) {
  const batch = db.batch();
  batch.set(jobRef, {
    status: "generating",
    progress,
    currentStep,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  batch.set(testRef, {
    status: "generating",
    generationProgress: progress,
    generationStep: currentStep,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
  await batch.commit();
}

function normalizeDiagnosticGenerationRequest(data) {
  const ieltsType = String(
      data.ieltsType || "Academic",
  ).trim();

  if (!["Academic", "General Training"].includes(ieltsType)) {
    throw new HttpsError(
        "invalid-argument",
        "IELTS type must be Academic or General Training.",
    );
  }

  const writingTaskType = diagnosticLimit(
      data.writingTaskType ||
      (ieltsType === "Academic" ?
        "Academic Task 1" :
        "General Training Task 1"),
      80,
  );

  return {
    title: diagnosticLimit(
        data.title || `${ieltsType} Diagnostic Test`,
        120,
    ),
    ieltsType,
    difficulty: diagnosticLimit(
        data.difficulty || "Intermediate",
        40,
    ),
    topic: diagnosticLimit(
        data.topic || "General IELTS topics",
        500,
    ),
    listeningQuestionCount: diagnosticClamp(
        data.listeningQuestionCount,
        5,
        40,
        10,
    ),
    readingQuestionCount: diagnosticClamp(
        data.readingQuestionCount,
        5,
        40,
        10,
    ),
    writingTaskType,
    speakingPromptCount: diagnosticClamp(
        data.speakingPromptCount,
        1,
        8,
        3,
    ),
    durationMinutes: diagnosticClamp(
        data.durationMinutes,
        15,
        90,
        30,
    ),
  };
}

function normalizeDiagnosticQuestions(value, prefix) {
  if (!Array.isArray(value)) return [];

  return value.map((question, index) => {
    const rawOptions = question?.options;
    const options = {};

    if (rawOptions && typeof rawOptions === "object" &&
        !Array.isArray(rawOptions)) {
      for (const [key, option] of Object.entries(rawOptions)) {
        const cleanKey = diagnosticLimit(key, 50);
        const cleanOption = diagnosticLimit(option, 1000);
        if (cleanKey && cleanOption) options[cleanKey] = cleanOption;
      }
    }

    const acceptedAnswers = Array.isArray(question?.acceptedAnswers) ?
      question.acceptedAnswers
          .map((item) => diagnosticLimit(item, 500))
          .filter(Boolean) :
      [];

    return {
      id: diagnosticLimit(
          question?.id || `${prefix}${index + 1}`,
          80,
      ),
      type: diagnosticLimit(
          question?.type || "short_answer",
          80,
      ),
      instruction: diagnosticLimit(
          question?.instruction,
          1000,
      ),
      prompt: diagnosticLimit(question?.prompt, 3000),
      options,
      acceptedAnswers,
    };
  });
}



function parseDiagnosticGenerationJson(raw) {
  return parseDiagnosticJson(raw);
}

function diagnosticClamp(value, minimum, maximum, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) return fallback;
  return Math.min(maximum, Math.max(minimum, Math.round(number)));
}

function diagnosticLimit(value, maximumLength) {
  return String(value || "")
      .trim()
      .slice(0, maximumLength);
}

function diagnosticSafeError(error) {
  return String(
      error?.message || error || "Unknown diagnostic error.",
  ).slice(0, 3000);
}

// ============================================================================
// CERTIFICATE MODULE
// ============================================================================

const CERTIFICATE_VERIFY_BASE_URL =
  "https://ieltsaimaster.com/verify";

exports.issueAchievementCertificate = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 60,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Sign-in is required.",
        );
      }

      const uid = request.auth.uid;
      const achievementType = String(
          request.data?.achievementType || "",
      ).trim();
      const sourceId = String(
          request.data?.sourceId || request.data?.attemptId || "",
      ).trim();

      if (!achievementType || !sourceId) {
        throw new HttpsError(
            "invalid-argument",
            "achievementType and sourceId are required.",
        );
      }

      const payload = await buildVerifiedCertificatePayload({
        uid,
        achievementType,
        sourceId,
      });

      return createAchievementCertificateIfMissing({
        uid,
        achievementType,
        sourceId,
        payload,
      });
    },
);

exports.syncAchievementCertificates = onCall(
    {
      region: "us-central1",
      timeoutSeconds: 120,
      memory: "256MiB",
    },
    async (request) => {
      if (!request.auth) {
        throw new HttpsError(
            "unauthenticated",
            "Sign-in is required.",
        );
      }

      const uid = request.auth.uid;
      const userRef = db.collection("users").doc(uid);
      const userDoc = await userRef.get();
      const user = userDoc.data() || {};
      const issued = [];

      const currentBand = certificateNumber(
          user.currentBand ??
          user.estimatedBand ??
          user.overallBand,
      );
      const targetBand = resolveCertificateTargetBand(user);

      if (currentBand > 0 &&
          targetBand > 0 &&
          currentBand >= targetBand) {
        const sourceId =
          `band_${targetBand.toFixed(1).replace(".", "_")}`;

        issued.push(
            await createAchievementCertificateIfMissing({
              uid,
              achievementType: "target_band",
              sourceId,
              payload: {
                title:
                  `Target Band ${targetBand.toFixed(1)} Achievement`,
                certificateType: "Target Band Achievement",
                band: currentBand,
                sourceCollection: "users",
              },
            }),
        );
      }

      const streak = Math.max(
          certificateNumber(user.currentStreak),
          certificateNumber(user.streak),
      );

      for (const milestone of [7, 30, 100]) {
        if (streak < milestone) continue;

        issued.push(
            await createAchievementCertificateIfMissing({
              uid,
              achievementType: "study_streak",
              sourceId: `streak_${milestone}`,
              payload: {
                title: `${milestone}-Day Study Streak`,
                certificateType: "Study Streak Achievement",
                band: 0,
                sourceCollection: "users",
              },
            }),
        );
      }

      return {
        success: true,
        issued: issued.filter(
            (item) => Boolean(item?.certificateId),
        ),
      };
    },
);

async function buildVerifiedCertificatePayload({
  uid,
  achievementType,
  sourceId,
}) {
  const userRef = db.collection("users").doc(uid);

  if (achievementType === "diagnostic_completion") {
    const result = await findCertificateSourceDocument({
      parentRef: userRef,
      collections: [
        "diagnostic_results",
        "diagnosticResults",
      ],
      sourceId,
    });

    if (!result) {
      throw new HttpsError(
          "not-found",
          "Diagnostic result was not found.",
      );
    }

    const data = result.snapshot.data() || {};

    return {
      title: "IELTS Diagnostic Assessment Completion",
      certificateType: "Diagnostic Completion",
      band: certificateNumber(
          data.overallBand ??
          data.estimatedBand ??
          data.currentBand,
      ),
      sourceCollection: result.collection,
    };
  }

  if (achievementType === "full_mock_test") {
    const result = await findCertificateSourceDocument({
      parentRef: userRef,
      collections: [
        "mock_attempts",
        "mockAttempts",
      ],
      sourceId,
    });

    if (!result) {
      throw new HttpsError(
          "not-found",
          "Mock attempt was not found.",
      );
    }

    const data = result.snapshot.data() || {};
    const nestedResult =
      data.result && typeof data.result === "object" ?
        data.result :
        {};
    const status = String(data.status || "").toLowerCase();

    const completionStatuses = new Set([
      "completed",
      "evaluated",
      "ready",
      "submitted",
    ]);

    if (!completionStatuses.has(status) &&
        Object.keys(nestedResult).length === 0) {
      throw new HttpsError(
          "failed-precondition",
          "Full mock evaluation is not complete.",
      );
    }

    return {
      title: "Full IELTS Mock Test Completion",
      certificateType: "Mock Test Completion",
      band: certificateNumber(
          nestedResult.overallBand ??
          nestedResult.estimatedBand ??
          data.overallBand ??
          data.estimatedBand,
      ),
      sourceCollection: result.collection,
    };
  }

  throw new HttpsError(
      "invalid-argument",
      `Unsupported achievement type: ${achievementType}`,
  );
}

async function findCertificateSourceDocument({
  parentRef,
  collections,
  sourceId,
}) {
  for (const collection of collections) {
    const snapshot = await parentRef
        .collection(collection)
        .doc(sourceId)
        .get();

    if (snapshot.exists) {
      return {
        collection,
        snapshot,
      };
    }
  }

  return null;
}

async function createAchievementCertificateIfMissing({
  uid,
  achievementType,
  sourceId,
  payload,
}) {
  const userRef = db.collection("users").doc(uid);
  const certificateId =
    `${achievementType}_${sourceId}`
        .replace(/[^a-zA-Z0-9_-]/g, "_")
        .slice(0, 150);
  const certificateRef = userRef
      .collection("certificates")
      .doc(certificateId);

  const existing = await certificateRef.get();

  if (existing.exists) {
    const data = existing.data() || {};

    return {
      success: true,
      alreadyIssued: true,
      certificateId,
      verificationCode: String(
          data.verificationCode || "",
      ),
      verificationUrl: String(
          data.verificationUrl || "",
      ),
    };
  }

  for (let attempt = 0; attempt < 5; attempt++) {
    const verificationCode =
      generateCertificateVerificationCode();
    const verificationRef = db
        .collection("certificate_verifications")
        .doc(verificationCode);

    try {
      return await db.runTransaction(async (transaction) => {
        const [
          currentCertificate,
          userDoc,
          verificationDoc,
        ] = await Promise.all([
          transaction.get(certificateRef),
          transaction.get(userRef),
          transaction.get(verificationRef),
        ]);

        if (currentCertificate.exists) {
          const data = currentCertificate.data() || {};

          return {
            success: true,
            alreadyIssued: true,
            certificateId,
            verificationCode: String(
                data.verificationCode || "",
            ),
            verificationUrl: String(
                data.verificationUrl || "",
            ),
          };
        }

        if (verificationDoc.exists) {
          throw new Error(
              "certificate-verification-code-collision",
          );
        }

        const user = userDoc.data() || {};
        const verificationUrl =
          `${CERTIFICATE_VERIFY_BASE_URL}/${verificationCode}`;
        const issuedAt = FieldValue.serverTimestamp();

        const certificate = {
          certificateId,
          achievementType,
          sourceId,
          sourceCollection: String(
              payload.sourceCollection || "",
          ),
          title: String(payload.title || "").trim(),
          certificateType: String(
              payload.certificateType || "Course Completion",
          ).trim(),
          userId: uid,
          userName: String(
              user.fullName ??
              user.name ??
              user.displayName ??
              "IELTS Learner",
          ).trim(),
          userEmail: String(
              user.email || "",
          ).trim(),
          band: certificateNumber(payload.band),
          verificationCode,
          verificationUrl,
          issuer: "IELTS AI Master",
          status: "valid",
          disclaimer:
            "Certificate of Course Completion\n\n" +
            "This certificate confirms completion of training and " +
            "assessments within IELTS AI Master.\n\n" +
            "This is NOT an official IELTS score or an official " +
            "IELTS certificate.",
          issuedAt,
          updatedAt: issuedAt,
        };

        transaction.set(certificateRef, certificate);
        transaction.set(verificationRef, {
          ...certificate,
          certificatePath: certificateRef.path,
        });
        transaction.set(
            userRef,
            {
              certificateCount: FieldValue.increment(1),
              lastCertificateIssuedAt:
                FieldValue.serverTimestamp(),
              updatedAt: FieldValue.serverTimestamp(),
            },
            {merge: true},
        );

        return {
          success: true,
          alreadyIssued: false,
          certificateId,
          verificationCode,
          verificationUrl,
        };
      });
    } catch (error) {
      if (safeErrorMessage(error).includes(
          "certificate-verification-code-collision",
      )) {
        continue;
      }

      throw error;
    }
  }

  throw new HttpsError(
      "internal",
      "A unique certificate verification code could not be generated.",
  );
}

function generateCertificateVerificationCode() {
  const year = new Date().getUTCFullYear();
  const random = crypto
      .randomBytes(5)
      .toString("hex")
      .toUpperCase();

  return `IAM-${year}-${random}`;
}

function resolveCertificateTargetBand(user) {
  const targetBands =
    user.targetBands &&
    typeof user.targetBands === "object" ?
      user.targetBands :
      {};

  return certificateNumber(
      targetBands.overall ??
      user.targetBand ??
      0,
  );
}

function certificateNumber(value) {
  const parsed = Number(value ?? 0);
  return Number.isFinite(parsed) ? parsed : 0;
}