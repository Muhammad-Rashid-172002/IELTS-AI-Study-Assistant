# Certificate verification origins

The backend parameter `CERTIFICATE_VERIFICATION_ORIGIN` is the single
canonical origin used for newly issued QR codes and stored verification URLs.
Its release value should be:

`https://ieltsaimaster.com/verify`

Existing records and printed QR codes must continue to resolve. Keep these
legacy origins active and configure permanent path-preserving redirects to the
canonical origin only after the destination is verified:

- `https://ielts-ai-study-assistant.web.app/verify/{code}`
- `https://ielts-ai-study-assistant.web.app/{code}`
- Any previously printed `verificationUrl` stored on a certificate document

Redirects must preserve the complete verification code and any `?code=` query
parameter. Do not rewrite or regenerate historical QR codes. The student app
uses each certificate's stored `verificationUrl` first and falls back to the
legacy Firebase Hosting origin only for historical documents without a URL.

Recommended release order:

1. Bind the custom domain to Firebase Hosting and verify TLS.
2. Set `CERTIFICATE_VERIFICATION_ORIGIN` for Functions.
3. Deploy the verification portal and Functions.
4. Test both path and query-string verification on every legacy domain.
5. Add path-preserving redirects while retaining old-domain hosting.
