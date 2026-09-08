# SSH preflight

## Actions

- Added a cow emoji to the README.
- Attempted noninteractive SSH to both laptops with strict host-key checks and host-key updates disabled.
- Inspected effective Windows SSH options, SSH filenames, and existing host-key records; checked the default WSL SSH setup.

## Outcome

- Both hostnames resolved from Windows.
- `bronco` rejected authentication; `yeti` failed host-key verification because the requested name had no trusted entry.
- No remote commands executed and no laptop settings were changed.
- Documented the access blockers in the architecture notes. Hardware specifications could not be verified.

## Pending

- Obtain an approved authentication method and verify the missing host-key trust before retrying.
- Collect hardware and OS facts, redact private identifiers, and document verified specifications.
