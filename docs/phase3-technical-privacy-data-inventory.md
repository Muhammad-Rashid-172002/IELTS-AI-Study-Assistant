# IELTS AI Master technical privacy and data inventory

Status: engineering inventory for Phase 3. This is not legal advice and does
not determine regulatory or store-policy classifications.

## Data handled by the product

| Area | Data | Primary location/processors | Current purpose |
|---|---|---|---|
| Authentication | Firebase UID, email, display name, provider, verification state | Firebase Authentication | Account access and email verification |
| Learner profile | Name, phone, country, language, education, IELTS track, exam date, target band, preferences, profile image URL | `users/{uid}`, Firebase Storage | Personalization and account profile |
| Objective assessment | Questions shown, answers, correctness, time used, section results and estimated practice bands | User Firestore subcollections and mock attempts | Practice scoring and progress |
| Writing | Full response text, task prompt/type, word count, timing, AI criterion feedback and corrections | `writing_submissions`, user result documents, Gemini through Functions | Educational Writing feedback |
| Speaking | Audio, audio path/metadata, prompts, transcript, criterion feedback | Storage, `speaking_submissions`, user result documents, Gemini through Functions | Educational Speaking feedback |
| Diagnostic and mock | Four-skill answers, evaluation references, score metadata, scoring/conversion versions | User subcollections and server jobs | Diagnostic and mock assessment reports |
| Learning activity | Study plans, lesson progress, saved tests/words, SRS vocabulary, streak/activity dates | User Firestore subcollections | Learning continuity and personalization |
| AI Coach | Learner messages, generated responses, derived progress profile | User Firestore subcollections, Gemini through Functions | Personalized educational assistance |
| Subscription | Product ID, purchase token and hash, entitlement/status/expiry, request and audit data | Protected Firestore data, Google Play Developer API | Purchase verification and access control |
| Credentials | Name, credential status/type, estimated practice bands for eligible mock reports, issue/revocation dates | User certificates, public verification projection, audit collections | Credential display and fraud prevention |
| Security and operations | Hashed callable identifiers; certificate verification rate key derived from IP and user agent; job errors and admin audit data | Firestore and Functions logs | Abuse prevention, troubleshooting and audit |
| Local/offline | Downloaded content, queued work, progress and metadata | Hive/application storage on the device | Offline operation and retry |

Firebase client API keys and app IDs are public application identifiers, not
server secrets. The Gemini and SMTP credentials are Functions Secret Manager
dependencies and must never be placed in Flutter or web bundles.

## Account deletion implementation

`deleteLearnerAccount` is the authoritative deletion operation. It requires an
authenticated user, explicit confirmation and an authentication time no older
than ten minutes. It then:

1. Creates a server-only deletion lock so existing clients cannot add new data.
2. Disables the Auth user and revokes refresh tokens.
3. Recursively deletes the entire `users/{uid}` tree, including nested answer
   collections and protected billing documents.
4. Deletes top-level Writing, Speaking, mock-evaluation and subscription
   records that reference the UID through supported legacy aliases, plus
   historical failed-login security events matching the normalized Auth email.
5. Deletes the user's certificate verification projections and lifecycle audit
   entries associated with those certificates.
6. Deletes profile images and Speaking/Diagnostic audio prefixes.
7. Deletes known per-user callable rate-limit records.
8. Deletes the Firebase Authentication user.
9. Clears local Hive data after server confirmation.

A deletion lock containing the UID is retained for up to 24 hours to prevent a
still-valid cached token from recreating data. A 90-day operational audit keeps
only a one-way subject hash, completion state and deletion counts. Firestore TTL
must be enabled on the two `expiresAt` fields before production rollout.

The public certificate verification rate limit is derived from network/device
request information and cannot reliably be attributed to one account. Gemini
provider-side retention is governed by the actual Google Cloud/GenAI contract
and project configuration; the application cannot independently erase provider
logs through the current API.

Separate administrative security/audit records can contain a target UID or
email. They are not silently rewritten by account deletion because the required
retention and access policy has not been approved. The operator must define and
document a retention/redaction schedule before claiming complete erasure of all
operational records.

## Privacy-policy statements requiring evidence or correction

The linked policy must not state the following as product facts without current,
documented evidence. These are technical discrepancies, not legal conclusions.

- “End-to-end encryption” for essays or audio. Firebase and server Functions can
  read the content in order to process it; encryption in transit/at rest is not
  end-to-end encryption.
- “Instant” or complete erasure without explaining the short security lock,
  deletion audit, provider retention, backups and failure/retry behavior.
- Complete JSON/PDF/ZIP export including recordings. The current export is not
  a complete portable archive of all Firestore, Storage, billing and audit data.
- Firebase Analytics, Crashlytics, Sentry or Firebase Cloud Messaging collection
  unless those SDKs and production configurations are actually added and used.
- Biometric unlock, MFA or automated age verification; these are not established
  by the current mobile implementation.
- Product-level ISO 27001/SOC 2 certification based only on a vendor's
  certifications.
- Guaranteed daily backups, zero loss or a specific uptime unless production
  backup/PITR and service commitments are documented.
- Gemini 1.5 or a guaranteed no-training/retention mode when the Functions model
  allowlist and the actual commercial data-use configuration differ.
- A single operating company/DPO identity until the KorvenzaTech, Nexora and
  “IELTS AI Master Technologies Ltd.” references are reconciled.
- Official IELTS scoring, certification, examiner status, endorsement or
  affiliation. Scores and mock reports are educational estimates.

## Store disclosure review list

Google Play Data Safety and Apple Privacy labels should be reviewed for personal
information, user IDs, profile photos, voice/audio, essays and other user content,
app activity/progress, purchase history, security identifiers, and processing by
Firebase/Google Cloud/Gemini. Whether a processor is classified as “sharing” must
be decided from the applicable store definitions and contracts.

The published Privacy Policy, Terms, in-app consent versions, account-deletion
web URL, retention schedule and AI-provider terms require product/legal review
before release.
