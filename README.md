# IELTS AI Master

IELTS AI Master is a managed IELTS-style learning ecosystem built around four
connected products:

- A Flutter learner app for diagnostic assessment, personalized study,
  vocabulary, skill practice, full mock tests, AI feedback, progress, and
  achievement certificates.
- A responsive Flutter web operations panel for learners, content, AI
  generation jobs, assessments, subscriptions, and platform analytics.
- A mobile-first certificate verification portal for QR and certificate-code
  verification.
- Firebase services for content generation, structured evaluation, audio,
  subscription validation, certificates, and security-sensitive operations.

Generated practice is original IELTS-style material. It is not official IELTS
content, and AI band estimates are not official examiner scores.

## Repository structure

| Area | Location | Purpose |
| --- | --- | --- |
| Learner app | `lib/` | Mobile learning and assessment experience |
| Admin panel | `ielts_ai_master_admin/lib/` | EdTech operations and content management |
| Cloud services | `ielts_ai_master_admin/functions/` | Generation, evaluation, certificates, subscriptions |
| Verification portal | `certificate_verification_web/lib/` | Public credential verification |
| Database rules | `ielts_ai_master_admin/firestore.rules` | Firestore authorization boundary |
| File rules | `ielts_ai_master_admin/storage.rules` | Recording and content asset access |

## Product capabilities

### Learner experience

- Academic and General Training pathways
- Four-skill diagnostic assessment
- Listening, Reading, Writing, and Speaking practice
- Full mock tests with timing, autosave, progress, and results
- Structured Writing and Speaking AI evaluation
- Topic- and level-based vocabulary learning
- Personalized study plans and progress intelligence
- Offline queueing for supported practice flows
- Secure achievement certificates with QR verification

### Operations platform

- Live learner activity, registrations, IELTS-track mix, band estimates, skill
  attempts, mock completions, diagnostics, and certificates
- Searchable, filterable, sortable, paginated learner directory
- Learner detail views with goals, exam dates, activity, practice, and
  credentials
- Permission-checked account suspension/reactivation with confirmation and an
  immutable server-written audit event
- Listening, Reading, Writing, Speaking, Vocabulary, Mock Test, and Diagnostic
  management
- Draft/review/publish/archive content workflows where supported
- AI generation queues, validation results, previews, and operational status
- Subscription request operations

### Certificate verification

- Certificate ID and QR lookup
- Responsive verified, invalid, loading, and error states
- Minimal public identity and credential disclosure
- Server-side code validation and per-client abuse limiting
- Downloadable/printable verification reports
- No direct public Firestore access to registry documents

## Content lifecycle

AI-generated content follows a controlled lifecycle:

1. Generate original IELTS-style practice.
2. Normalize the model response into the product schema.
3. Validate counts, structure, answerability, word limits, and quality.
4. Save valid output as a draft.
5. Preview and review it in the admin panel.
6. Approve and publish it for learners.
7. Archive content when it should no longer be served.

Generation services reject invalid output and retry within bounded limits.
Publishing remains an administrative decision.

## Security model

- Administrator access is resolved from trusted custom claims or the protected
  `admins/{uid}` record.
- Learners cannot grant themselves admin, premium, certificate, or account
  status fields.
- Public certificate lookup calls a Cloud Function that returns an allow-listed
  projection; email addresses, user IDs, source paths, and internal metadata are
  never returned.
- Certificate codes use high-entropy random values and a strict public format.
- Verification requests are rate-limited using a one-way client hash.
- Account access changes update Firebase Authentication on the server and write
  an admin audit event.
- Generated listening/speaking audio and learner recordings are governed by
  dedicated Storage rules.

Deploy Firestore and Storage rules before treating the apps as production
ready. Review the rules against any additional collections introduced after
this version.

## Local setup

Install Flutter, Node.js 22, and the Firebase CLI. Then resolve each Flutter
package and the Cloud Functions package:

```sh
flutter pub get
cd ielts_ai_master_admin && flutter pub get
cd functions && npm ci
cd ../../certificate_verification_web && flutter pub get
```

Cloud Functions require configured Firebase secrets for the enabled AI and
email services. Never commit service-account credentials or API keys.

## Quality checks

```sh
flutter analyze
flutter test

cd ielts_ai_master_admin
flutter analyze
flutter build web
cd functions && npm run lint

cd ../../certificate_verification_web
flutter analyze
flutter build web
```

## Open-house demonstration

A clear five-minute product walkthrough is:

1. Open the admin dashboard and explain the live learner and platform metrics.
2. Open Learners, search for a learner, filter by IELTS track, and show the
   detailed goal and practice record.
3. Open an IELTS content module and show draft, validation, preview, and publish
   controls.
4. Open AI Jobs and explain generation, validation, failure, and review states.
5. Show Writing and Speaking evaluations as structured, criterion-level band
   estimates with evidence and improvement actions.
6. Open Mock Tests and Diagnostics to connect assessment with personalization.
7. Open Certificates, scan a QR code in the verification portal, and explain
   minimal public disclosure and server-side verification.

The narrative is: assessment → personalization → practice → exam simulation →
AI evaluation → progress intelligence → managed content → credential
verification.
