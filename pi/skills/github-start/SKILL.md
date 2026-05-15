---
name: github-start
description: Create a GitHub user story and start work on it by creating and checking out the matching development branch. Use this skill whenever the user says “GitHub start”, “start a GitHub issue”, “create a user story and branch”, “start work on a feature/story”, or asks to turn a feature/issue description into a GitHub issue plus local branch. This skill should proactively prompt for the issue/feature description, use a provided parent issue ID when present, search open Feature issues with label:"📍 Feature" -status:Done when no parent is provided, then create the GitHub issue, link it to the IJACK Roadmap and selected parent, create a four-digit issue-number-prefixed branch, and check it out.
---

# GitHub Start

Use this skill to turn a feature or issue description into a GitHub user story and a local development branch.

The intended workflow mirrors `scripts/github-issue.sh user-story`, but perform the work directly with `gh`, `git`, and GraphQL commands instead of calling the shell script.

## Inputs to collect

If any required input is missing, ask the user before creating anything:

1. **Issue/feature description** — required. This can be a rough feature request, bug description, or user story.
2. **Parent issue ID** — optional. Accept `1234`, `#1234`, or a GitHub issue URL. If provided, link the new user story as a sub-issue of the parent. If not provided, search for likely parent features using `label:"📍 Feature" -status:Done` and ask the user to choose one or confirm no parent.
3. **Title** — derive a concise title from the description when obvious; otherwise ask the user to confirm or provide one.

Use defaults unless the user asks otherwise:

- Label: `🏌️ User Story`
- Assignee: `@me`
- IJACK Roadmap project: `ijack-technologies` Project #12
- Status: `backlog`
- Story points: `3`
- Priority: `low`
- Branch base: current branch unless the user asks to start from a different base

## Before creating anything

1. Verify `gh` is authenticated:
   ```bash
   gh auth status
   ```
2. Verify the current directory is a git repository:
   ```bash
   git rev-parse --show-toplevel
   ```
3. Check current changes:
   ```bash
   git status --short
   ```
   If there are uncommitted changes, explain that they will carry across branches unless committed/stashed. Ask before switching branches if the working tree state could surprise the user.
4. Resolve the parent feature:
   - If a parent issue was provided, normalize it to just the number and verify it exists:
     ```bash
     gh issue view <parent-number> --json number,title,labels,url
     ```
   - If no parent was provided, search for active feature issues:
     ```bash
     gh issue list --search 'label:"📍 Feature" -status:Done' --state open --limit 10 --json number,title,url,labels
     ```
     Show the matching feature issues to the user and ask them to choose a parent issue number or confirm that this story should have no parent. Prefer matches whose title/body semantically aligns with the requested work, but do not guess silently.
   - If the selected parent lacks the `📍 Feature` label, warn the user but continue if they confirm.

## Create the user story

Build a Markdown issue body using this shape:

```markdown
**Parent Feature:** #<parent-number>

## User Story
<one-sentence user story, if derivable>

## Details
<the user's original description, cleaned up into clear acceptance-oriented notes when helpful>

```

If the user confirms no parent after the feature search, omit the `Parent Feature` line.

Create the issue:

```bash
gh issue create \
  --title "<title>" \
  --body-file <temp-body-file> \
  --label "🏌️ User Story" \
  --assignee "@me"
```

Capture the issue URL and issue number from the command output. Do not proceed to branch creation if issue creation fails.

## Add to IJACK Roadmap Project #12

Use these project constants from `scripts/github-issue.sh`:

- Owner: `ijack-technologies`
- Project number: `12`
- Project ID: `PVT_kwDODGeA9M4BCOFY`
- Started field: `PVTF_lADODGeA9M4BCOFYzg0fxWM`
- Story points field: `PVTSSF_lADODGeA9M4BCOFYzg0gHRU`
- Priority field: `PVTSSF_lADODGeA9M4BCOFYzg04jjg`
- Status field: `PVTSSF_lADODGeA9M4BCOFYzg0ftEw`

Option IDs:

- Story points `3`: `d67f489f`
- Priority `low`: `b04f73f7`
- Status `backlog`: `f75ad846`

Add and update the project item:

```bash
ITEM_ID=$(gh project item-add 12 --owner "ijack-technologies" --url "<issue-url>" --format json | jq -r '.id')
TODAY=$(date +%Y-%m-%d)
gh project item-edit --id "$ITEM_ID" --project-id "PVT_kwDODGeA9M4BCOFY" --field-id "PVTF_lADODGeA9M4BCOFYzg0fxWM" --date "$TODAY"
gh project item-edit --id "$ITEM_ID" --project-id "PVT_kwDODGeA9M4BCOFY" --field-id "PVTSSF_lADODGeA9M4BCOFYzg0gHRU" --single-select-option-id "d67f489f"
gh project item-edit --id "$ITEM_ID" --project-id "PVT_kwDODGeA9M4BCOFY" --field-id "PVTSSF_lADODGeA9M4BCOFYzg04jjg" --single-select-option-id "b04f73f7"
gh project item-edit --id "$ITEM_ID" --project-id "PVT_kwDODGeA9M4BCOFY" --field-id "PVTSSF_lADODGeA9M4BCOFYzg0ftEw" --single-select-option-id "f75ad846"
```

If project updates fail because of permissions, keep the created issue and report the project-field failure clearly.

## Link to parent issue when selected

Use GitHub's native sub-issue relationship. First get the current repo name:

```bash
REPO_NAME=$(gh repo view --json name -q '.name')
```

Fetch node IDs and call `addSubIssue`:

```bash
gh api graphql \
  -f query='query($owner: String!, $repo: String!, $parent: Int!, $child: Int!) { repository(owner: $owner, name: $repo) { parent: issue(number: $parent) { id } child: issue(number: $child) { id } } }' \
  -f owner="ijack-technologies" \
  -f repo="$REPO_NAME" \
  -F parent="<parent-number>" \
  -F child="<issue-number>"

gh api graphql \
  -f query='mutation($parentId: ID!, $childId: ID!) { addSubIssue(input: {issueId: $parentId, subIssueId: $childId}) { issue { number } subIssue { number } } }' \
  -f parentId="<parent-node-id>" \
  -f childId="<child-node-id>"
```

If the sub-issue link fails, report it and include the issue URL so the user can link it manually.

## Create and check out the development branch

Branch naming convention:

```text
<four-digit-issue-number>-<github-style-title-slug>
```

Examples:

- Issue `1234`, title `Add Quote Preview` → `1234-add-quote-preview`
- Issue `87`, title `Fix Admin Login Redirect` → `0087-fix-admin-login-redirect`

Slug rules:

1. Lowercase the title.
2. Replace non-alphanumeric runs with `-`.
3. Trim leading/trailing hyphens.
4. Keep it short enough to remain readable; usually 6–10 words.

Create and check out the branch:

```bash
git switch -c "<branch-name>"
```

Do not push unless the user explicitly asks. Workspace rules prohibit pushing to remote without an explicit request.

## Final response

Keep the final response concise and include:

- Created issue number and URL
- Parent link status, if applicable
- Project Roadmap status
- Checked-out branch name
- Any warnings, such as uncommitted changes carried onto the branch

Example:

```text
Created GitHub user story #1234: <url>
Linked parent: #1200
Added to IJACK Roadmap: backlog, 3 points, low priority
Checked out branch: 1234-add-quote-preview
```
