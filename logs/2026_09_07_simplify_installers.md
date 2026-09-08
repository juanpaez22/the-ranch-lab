# Simplify initial installers

- Replaced the generalized role wrapper with separate minimal server and agent scripts at the owner's request.
- Kept the shared version pin, configuration templates, private token input/storage, and a guard against overwriting existing configuration.
- Moved readiness checks and post-install verification into the runbook; scripts assume the correct target and repository-root working directory.
- Removed the superseded wrapper from Git. Prior temporary staging bundles remain historical and should not be used.
- Installation remains pending; this change does not run either installer.
- Both replacement scripts passed `bash -n` on both laptops and were staged in new temporary bundles. Repository whitespace checks passed.
