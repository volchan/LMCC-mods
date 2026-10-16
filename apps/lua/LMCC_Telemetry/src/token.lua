-- Token of the LMCC stats site (its TELEMETRY_TOKEN), never committed: scripts/build.sh writes it
-- into the release zip from the TELEMETRY_TOKEN secret. Empty here, so a dev or local install
-- sends nothing. Not a secret: every driver's install and the public release zips hold it. It
-- marks the app's traffic and authenticates nobody: the site takes a batch only from a driver
-- on the server, from the address that first spoke for them.
return ''
