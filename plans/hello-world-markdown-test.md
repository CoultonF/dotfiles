# Test Plan: Markdown File Contains `hello world`

## Context

Create a concise verification plan for confirming that a Markdown file includes the exact words `hello world`. The repository already contains several Markdown files and an existing root `PLAN.md`, so this plan uses a separate file under `plans/` to avoid overwriting the existing plan.

## Approach

Use a simple Markdown fixture or target file and verify that its text content contains `hello world`. The check should be case-sensitive unless the implementation requirements later specify otherwise.

## Files to modify

- `plans/hello-world-markdown-test.md` — planning artifact only.
- Target Markdown file to be chosen during implementation, if needed.

## Reuse

- Existing repository Markdown layout: root Markdown files such as `README.md`, `AGENTS.md`, and `PLAN.md` show that plain `.md` files are already used in this repo.

## Steps

- [ ] Identify or create the Markdown file that should contain `hello world`.
- [ ] Ensure the file has valid Markdown content with the exact phrase `hello world`.
- [ ] Verify the phrase appears in the file body, not only in metadata or tooling output.
- [ ] Confirm no unrelated files need to change.

## Verification

- [ ] Run a text search for `hello world` against the chosen Markdown file.
- [ ] Open the file and manually confirm the phrase appears exactly as expected.
- [ ] If this is part of an automated check, assert that the file path ends in `.md` and the file content includes `hello world`.
