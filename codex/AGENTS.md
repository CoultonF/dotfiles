# PR merges after a rebase

Do not wait for checks to run again after a rebase. When merging a PR is
authorized, every required check passed on the head before the rebase, and the
rebase likely had no impact (PR commits unchanged, incoming base commits do not
touch the PR's files or what it depends on, no check has failed since), merge
right away with `gh pr merge --admin`. If the base commits overlap the PR, or
you are unsure, wait for green. The `babysit-pr` skill has the full rule.
