# Agent workflow

Standing rules for any session working an IronLion issue. Issues hold only
what is specific to their task; everything here applies to all of them.

## Roles

- **The orchestrator** is one session working with the project owner. It turns
  decisions into `ready-for-agent` issues, starts one session per issue, checks
  each PR against its issue's acceptance criteria, and tells the session when it
  may merge.
- **An issue session** works exactly one issue, from branch to merged PR. It
  doesn't start other work, comment on other issues, or take up a sibling's
  ticket.

## Picking up an issue

- Only `ready-for-agent` issues with no open blockers are started. Check with
  `gh api repos/softwaremojo/iron_lion_uuid/issues/<n> --jq .issue_dependencies_summary.blocked_by`;
  it should be `0`.
- Decisions written into an issue, or into its tracking issue, are settled. If
  the issue turns out to be wrong or ambiguous, don't guess: stop and say what
  needs deciding.

## Branch and PR

- Fetch first, then branch from `origin/main`: `git fetch origin`. Don't build on another
  session's branch.
- Open the PR against `main`, with `Closes #<n>` in the body. In the body, list
  each acceptance criterion and how you met it.
- PRs are squash-merged: the PR title becomes the commit subject on `main` and
  the PR body its message. Write them as a good commit message, and edit them
  when the change does; branch commit messages don't reach `main`.
- Keep the change to what the issue asks. `README.md` and `CLAUDE.md` are shared
  by every PR, so keep edits there small and local. When they conflict on
  rebase, keep both sides' meaning.

## Testing

- Use your own Postgres database, so parallel sessions don't share one:

  ```bash
  /opt/homebrew/opt/postgresql@17/bin/createdb iron_lion_test_<n>
  IRON_LION_TEST_DATABASE_URL=postgres:///iron_lion_test_<n> bundle exec rake
  /opt/homebrew/opt/postgresql@17/bin/dropdb iron_lion_test_<n>   # when done
  ```

- `bundle exec rake` (RSpec and RuboCop) must pass. Report whether the
  `:postgres` and `:active_record` examples ran or were skipped.
- Anything the suite can't reach (the Railtie, the generator), check by hand in
  a throwaway Rails app outside the repo, and say in the PR what you checked.

## Merging

- **CI must be green.** The workflow runs `bundle exec rake` against Postgres on
  every PR, and again on each merge-queue group.
- **The orchestrator must have confirmed the acceptance criteria.** Once it
  has, the session queues its own PR with `gh pr merge <n> --squash --auto`.
  The merge queue merges it once `test` passes and GitHub deletes the branch.
  If the queue drops the PR (a failure against newer `main`), fix it and queue
  it again.
- Until then, open the PR, report, and stop.

## Reporting

End with the PR URL, the acceptance criteria and how each was met, what was
verified by hand, and anything left undone. Once the PR is merged, the session
is finished.
