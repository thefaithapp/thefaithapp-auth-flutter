## 0.1.0

- Add TheFaithApp hosted member sign-in for Android and iOS.
- Generate and validate state plus S256 PKCE for every sign-in.
- Derive the default callback from the consuming application ID.
- Store member sessions with platform secure storage.
- Add an authorized HTTP client for protected `v1` endpoints.
- Add session restoration, local clearing, and server-side logout.
- Require only the client API key and lock API and hosted-auth traffic to the
  production TheFaithApp origins.
- Keep test dependency injection internal to the package and stop displaying
  token fragments in the standalone sample.
