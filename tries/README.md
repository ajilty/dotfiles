# tries

This folder holds short-lived experiment directories created by the `try` shell function, with an option to promote them into real git repositories using `keep`.

## `try`

Creates or navigates to a directory under `~/tries`.

Usage:

- `try` (no args): creates a timestamped directory named `try-YYYYMMDD-HHMMSS` and `cd`s into it.
- `try <name>`: creates or navigates to `~/tries/<name>` and `cd`s into it.

Behavior details:

- Ensures `~/tries` exists.
- If the target directory already exists, it just changes into it.

## `keep`

Promotes a `~/tries/*` directory into a real git repository under `~/gits`.

Usage:

- Run `keep` from inside a `~/tries/*` directory.

Behavior details:

- Requires you to be inside `~/tries/*` or it will error.
- Uses `gh api user` to determine your GitHub username for the default destination.
- Prompts for a target path (defaults to `~/gits/github.com/<username>/<current_dir>`).
- Initializes a git repo and makes an initial commit if one does not exist.
- Moves the directory to the target path and `cd`s into it.
