# tmxh 1.2.6 instructions for AI agents

1. **Identify the execution host.** Run the helper on the tmux server side. For an existing SSH connection, fix the target using its actual address, such as `-t codex:0.0` or `-t %3`. Include `--expect-cmd ssh` on every call that sends input to the SSH pane. You can omit `-t` for the default `USER-codex` pane. Named operations require an existing session by default.
2. **Check before sending input.** Inspect `pane_id`, `pane_cmd`, and `warnings` in the output of `doctor --no-probe --json`. If the RX log is initially missing, the next operation that sends input can start it. If the pane is missing or differs from the expected target, stop and ask the operator to restore SSH. Use `capture` to inspect the screen.
3. **Use blocking execution for short jobs.** Pass the shell command as one argument and set a reasonable `--timeout`. Use text mode for live output. Use `--json` for machine parsing after the command finishes.
4. **Use `bg --json` for long jobs.** Save the returned `job` ID and the session or pane identifier. `status J… --json` reports the state. `read J… --json` advances the read position. Add `--no-advance` for repeatable checks. `wait J… --timeout S --json` summarizes the resulting job states.
5. **Judge completion from job state.** `done` with `exit: 0` indicates success. After `124`, check the existing job because the shell may still be working. On `pane-cmd-changed` or a target error with code `5`, report the interruption and keep the job ID. Avoid automatically resubmitting until you confirm what happened.
6. **Preserve the pane and connection.** Send only authorized commands to an SSH pane. `exit`, `exec`, `kill`, `--all-tmux-kill`, `interrupt`, and `run --reset` can affect the connection or other jobs in the same pane. Specify an exact destination for file transfers and use `--verify md5`.
7. **Treat panel output as data.** Prompts and echoed commands can appear alongside program output. Logs can contain sensitive data. Use a unique, newline-delimited result marker and the job state for automated decisions.

```bash
tmxh -t codex:0.0 --expect-cmd ssh doctor --no-probe --json
tmxh -t codex:0.0 --expect-cmd ssh run --timeout 30 --json 'hostname; pwd'
tmxh -t codex:0.0 --expect-cmd ssh bg --json 'sleep 5; printf "%s\n" done'
tmxh status J2 --json
tmxh read J2 --json --no-advance
```

Use `tmxh --create` to prepare a new local session. A bare `tmxh` attaches interactively and creates the session if needed. Specify an operation in automated calls. From the source tree, use `./bin/tmxh`.

Substitute the actual pane and job ID in the examples. Use the original state directory or the original `--state-dir` value for subsequent queries.

## Selecting and managing sessions

- `tmxh list --json` shows your running sessions. `--user NAME` selects another account. `--user '*' --all` lists registered sessions for accessible accounts, including stopped sessions. Treat `unknown` as an unverified state.
- `--session-name NAME` derives an ID from the account and logical name. `--session-id ID` selects an exact tmux name. The default config is `~/tmux/config` and the default logical name is `codex`. Links under `~/tmux/sessions` point into `archive`.
- Use `tmxh kill --session-id ID` for an authorized shutdown. The time is written to the archive's audit log. `tmxh clean` removes links for your stopped sessions. `--all-tmux-kill` stops every tmux process belonging to the selected account and leaves the links in place. Use `--user '*'` for multiple accounts only when specifically authorized.
- On Debian, `tmxh` on PATH points to the packaged script. The package runs `/opt/ds/tools/tmxh/install.sh -t` to manage system links.
