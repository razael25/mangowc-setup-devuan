# Contributing

Butterforge is a one-person forge. Accounts can file issues and open pull
requests, but can't create repos or forks. That's deliberate: people curl-pipe
scripts off this domain, so nothing gets served under a name that isn't mine.

You do not need a fork to send a pull request.

## Bugs and ideas

Open an issue. Sign in with Codeberg or GitHub.

## Pull requests (no fork needed)

Butterforge supports AGit flow: push your branch straight to this repo under a
special ref and a pull request appears.

One-time setup:

1. Sign in at https://justaguy.dev with Codeberg or GitHub.
2. Add an SSH key at https://justaguy.dev/user/settings/keys

Then:

    git clone ssh://forgejo@justaguy.dev/drew/mangowc-setup.git
    cd mangowc-setup
    git switch -c my-change
    # make your change, commit it
    git push origin HEAD:refs/for/main -o topic=my-change -o title="Short description"

Forgejo replies with the pull request link. To update it after review, push
again with the same topic:

    git push origin HEAD:refs/for/main -o topic=my-change

Notes:

- `main` is the target branch. `topic` names the pull request: keep it the same
  across pushes, and use a different one for each separate change.
- This needs the git command line. Some GUI clients drop push options.

## Patch in an issue (fallback)

If the above isn't your thing:

    git format-patch origin/main --stdout > my-change.patch

Attach that to an issue. I apply it with `git am`, so your name stays on the
commit.

## Ground rules

- One change per pull request. Say what it does and why.
- Match the style of the file you're in. No drive-by reformatting.
- No paths that only exist on your machine.
- Target is Debian 13 / Butterbian. Test there.
