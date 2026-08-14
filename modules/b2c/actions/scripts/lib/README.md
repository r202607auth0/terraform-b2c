Actions in Auth0 are single-file. The helper below is duplicated at the top of
each Action rather than shared, because Auth0 has no module resolution between
Actions. If you change the helper, change it everywhere - `npm run lint:actions`
in the repo root checks that the copies have not drifted.
