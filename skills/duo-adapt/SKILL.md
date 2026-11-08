---
name: duo-adapt
description: Adapt a Flutter app for tablets, foldables and iPhone Duo with the shared adaptive plan, without changing the phone layout. Use when the user asks to prepare or adapt a Flutter project for iPhone Duo, foldables or tablets, asks to continue that work, or runs /duo-adapt. Orchestrates the duo-planner, duo-executor and duo-reviewer agents from the main session.
---

# duo-adapt

Makes a Flutter app work well on tablets, foldables and iPhone Duo while the phone layout stays
exactly as it is. The decisions live once in the shared plan, the core code is tested once in
`templates/`, and three agents do the work in each project: the planner turns the shared plan into
tasks for this project, the executor carries them out one at a time, and the reviewer checks the
plan, the risky tasks, every phase and the final result. What one project teaches goes back into
the shared plan and the templates, so the next project starts further ahead.

Runs in the main session inside the target Flutter project. Subagents cannot start other
subagents, so this session is the only orchestrator.

Talk to the user in the language they write in, short and concrete. `duo-plan.md` is written in
the user's language; code, paths and identifiers stay in English.

## Files

- `references/plan.md` in this skill folder: the shared plan (decisions, facts, phases, execution rules, traps). Source of truth.
- `templates/`: tested core code (`lib/core/responsive`, `test/duo`), iOS UIScene reference files, a debug probe page.
- `scripts/check_sync.sh <project> [core dir] [test dir]`: compares a project's copy of the core layer with `templates/`.
- `scripts/test_templates.sh`: runs the template tests in a throwaway Flutter project.
- `duo-plan.md` at the project root: this project's plan, written by duo-planner, updated by duo-executor and this session.
- The agents `duo-planner`, `duo-executor` and `duo-reviewer`. Installed with the plugin they may be listed as `duo-adapt:duo-planner` and so on; installed by hand they live in `~/.claude/agents/` or the project's `.claude/agents/`.

Pass absolute paths of these to every agent you start (resolve this skill's folder first). Give the
reviewer a scratch folder outside the project for HEAD exports and throwaway tests.

## Rules

- Never `git commit`, `push`, `reset`, `checkout`, `stash` or `rebase` unless the user asks in this conversation. At the end, commit and push only when the user says so.
- One writer at a time: never run two executors in parallel, and never run a reviewer while an executor is working. Reviewers are read-only and may run in parallel with each other.
- A task tagged `[needs-approval]` runs only after the user approves that task in chat.
- Never let an agent invent a decision the plan does not make: when one reports `BLOCKED`, bring the question to the user.
- Never skip a review, a verification step or a simulator check to save time or tokens. If a check cannot run, write why in `duo-plan.md` and in the final summary.
- This session edits project files directly only for: `duo-plan.md` bookkeeping, and a fix a reviewer gave as an exact change of a line or two. Record each one under its task as `- Fix (main session): <what> · <verification run>`. Everything else goes through the executor.
- Throwaway files (HEAD exports, reviewer tests) stay in the scratch folder. A throwaway test runs from there with `flutter test <scratch>/<name>_test.dart` at the project root; never copy one into the project.

## Steps

### 1. Preflight
- Confirm the working directory is a Flutter app (`pubspec.yaml` with `flutter:` SDK dependency) and a git repository. If not, stop and tell the user.
- Confirm the three agents are available. If one is missing, stop and tell the user to install it next to this skill.
- Note the branch and `git status`. If the tree has unrelated uncommitted changes, tell the user before starting (reviews rely on `git diff`).
- If the branch is the default branch, suggest a working branch (for example `feature/adaptive-duo`) and create it only if the user agrees.

### 2. Plan
- If `duo-plan.md` exists: read it and run `scripts/check_sync.sh` on the project's core path. If the templates changed since the project copied them, tell the user what differs and add a sync task (`P2.S1 ...`) before the next unchecked task. Report which phase and task come next, then continue from step 5 if the header says approved, or from step 3 if not.
- Otherwise start the **duo-planner** agent with: project root, skill folder, path of `references/plan.md`, path of `templates/`, and the language the user writes in (the planner writes `duo-plan.md` prose in it). Wait for it.

### 3. Plan review
- Start **duo-reviewer** with `mode: plan`.
- Findings: rerun the planner with them (or edit the plan yourself for a wording fix), then review again. After three rounds, show the user what is left.

### 4. Approval
Show the user a short summary from `duo-plan.md`: the project profile (stack, Flutter version, ScreenUtil, app chrome, payments, maps), the baseline, the phases with task counts, every `[needs-approval]` item, the `[orchestrator]` steps, the planner's open questions (with the sign-in question if there is one) and the plan review result. Stop and wait. Apply requested changes (edit the plan or rerun the planner with the feedback, then review again). When the user approves, write `Approved: <date>` in the plan header.

### 5. Execute
For each phase in order, for each unchecked task:
1. `[needs-approval]` and not approved: collect these, ask the user once per phase, skip the ones refused (mark `[skipped: <reason>]`).
2. Start **duo-executor** with: project root, `duo-plan.md` path, the task ID, skill folder. It runs on Opus.
3. Read its report. `DONE`: check that the task is ticked, its Result sits under the task itself, and the numbers are from this run. `BLOCKED`: ask the user, then rerun or adjust the task.
4. `[orchestrator]` steps it left: do them now with step 7's tools, or note them for the phase's simulator round.
5. `[risk:high]`: start **duo-reviewer** with `mode: task <id>` right away. Findings become fix tasks under that task (`P4.1.F1 ...`), run before the next task, then that task is reviewed again.
6. Tell the user in one line what finished.

### 6. Review after each phase
- Start two **duo-reviewer** agents in parallel with `mode: phase <id>`: one with `focus: rules`, one with `focus: tests`. Merge the findings and drop duplicates.
- Both `PASS`: move on. Findings: append them as fix tasks under the phase (`P4.F1 ...`) with the reviewer's file:line and fix, run them through step 5, then review again with both. Repeat until both pass; after three rounds that still fail, stop and show the user the remaining findings.
- Record every round in `duo-plan.md`: `- Review P4 round 1 (<date>): PASS` or the findings and the fix tasks they became.

### 7. Simulator checks (after P1, P4, P5 and P7, and the full P9)
- Do them yourself. If an iOS Simulator control tool is available (tap, swipe, rotate, screenshot), use it; otherwise use `xcrun simctl` (boot, install, launch, `openurl`, `io screenshot`) and ask the user only for what it cannot do. Folding, Book, Tabletop and Split View are set from Device Hub in Xcode: ask the user to set the pose, then check it.
- Build with the flavor and defines from `duo-plan.md`, and get past sign-in with the test account or the dev route.
- In every pose check: side column in outer portrait and inner landscape, bars at the top and bottom in inner portrait, nothing under the system column, selection and form state kept across fold and unfold, the phone layout unchanged on a regular iPhone. Use the Android foldable emulator too if one is installed.
- Record what you saw under the phase in `duo-plan.md`; every bug becomes a fix task. Measured values go to "Facts" or "Still to verify" in `references/plan.md`.

### 8. Final review
- Start two **duo-reviewer** agents in parallel with `mode: final` (`focus: rules` and `focus: tests`). Findings become fix tasks in a `## Final fixes` section, run through step 5, then the final review runs again. Same three-round limit.

### 9. Finish
Summarize for the user: what changed per phase; `flutter analyze` and `flutter test` (three runs: normal order and two random seeds) against the baseline; every task not done (`[skipped]`, blocked or waiting for the user) and why; what is still unverified; and the manual checklist that needs the user (goldens on their OS, real devices, P9 items). Do not commit or push unless the user asks; when they do, commit with a clear message and push the current branch.

## Updating the shared plan
When a project teaches something that applies to every app (a measured inset, a package choice, a template fix, a trap):
- Write it into the phase where it applies in `references/plan.md` as a general rule, or as a row in "Facts" or "Still to verify". No project names, no client details, no paths from one machine.
- After a template code change run `scripts/test_templates.sh`: `flutter analyze` must be clean and every test must pass in normal and random order. Then tell the user what changed and which projects now differ from the templates (`scripts/check_sync.sh`).
- Never change a decision in "Fixed decisions" without the user.
