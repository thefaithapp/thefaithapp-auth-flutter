## Unreleased

- Allow explicit loopback API and hosted-auth origins for local SDK source builds
  while keeping production as the default and rejecting unsafe origin values.
- Link the official Flutter quickstart, hosted authentication guide, and example.

## 0.1.0

- Add TheFaithApp hosted member sign-in for Android and iOS.
- Generate and validate state plus S256 PKCE for every sign-in.
- Derive the default callback from the consuming application ID.
- Store member sessions with platform secure storage.
- Add an authorized HTTP client for protected `v1` endpoints.
- Add session restoration, local clearing, and server-side logout.
- Simplify setup so developers provide only the client API key.
- Stop displaying token fragments in the standalone sample.
- Publish the first public package release with pub.dev installation guidance.
