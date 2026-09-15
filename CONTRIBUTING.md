# Contributing

Pull requests welcome, no fork needed. Full instructions:
https://justaguy.dev/drew/.profile/src/branch/main/CONTRIBUTING.md

Quick version (sign in with Codeberg or GitHub, add an SSH key, then):

    git clone ssh://forgejo@justaguy.dev/drew/mangowc-setup.git
    cd mangowc-setup
    git switch -c my-change
    # make your change, commit it
    git push origin HEAD:refs/for/main -o topic=my-change -o title="Short description"

Push again with the same topic to update the pull request.

Or attach a `git format-patch` file to an issue.
