/// The versions of the documents the sign-up screen puts in front of a new
/// customer: the Customer Terms (CUST-01) and the Privacy Policy (PRIV-01).
/// Sent with the sign-up so the server records exactly what was agreed to.
///
/// Keep in step with the website (src/features/legal/assent.ts), which shows
/// the same documents; change it whenever either document's version changes.
const customerTermsVersion = 'CUST-01 0.2 draft; PRIV-01 1.2';
