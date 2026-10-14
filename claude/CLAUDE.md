# Coulton's workflow

- **One set of development servers per devcontainer**, running in the repository root
  checkout. Never start them anywhere else.
- **Work that doesn't need the development servers goes in a git worktree**, and a worktree
  is plain git: edit, commit, push. Don't install dependencies or start servers in one, so
  the devcontainer stays lean.
- **To test worktree code against the development servers**, switch the root checkout to that
  code, but only if the root isn't actively in use by other work. Put the root back afterwards.
- **Work that needs the development servers from the start** goes in the root checkout when
  it is free.
- **When the root is busy and more parallel work needs the development servers**, launch a
  remote devcontainer and run that session there. Name them `aws1`, `aws2`, `aws3`, taking
  the first free name.

When starting a task, say in one line where it will run and why.
