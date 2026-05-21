# Test Plan: Plannotator Markdown Review

This is a small test plan to verify that Plannotator/plan-mode markdown handling works in the devcontainer.

## Goals

- [ ] Confirm Pi can create a markdown plan file in the repository.
- [ ] Confirm the devcontainer environment has Plannotator configured for remote access.
- [ ] Confirm the planned exposed port is `19432`.
- [ ] Review the existing tracked change in `devcontainer/post-install.sh` before committing.

## Notes

Current tracked changed file reported by the user:

- `devcontainer/post-install.sh`

Expected Plannotator environment:

```sh
PLANNOTATOR_REMOTE=1
PLANNOTATOR_PORT=19432
```

## Review Checklist

- [ ] Open this file in nvim.
- [ ] Verify the plan content renders correctly as markdown.
- [ ] Approve or request changes before implementation.
