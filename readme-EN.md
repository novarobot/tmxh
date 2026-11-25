# tmxh 1.2.6

`tmxh` is a Perl command-line helper for interactive tmux panes. It sends commands to the shell running in a pane, which can be behind an existing SSH connection.

## Quick start

Run it on the machine that can reach the tmux server. Use `./bin/tmxh` from the source directory. You need Linux, tmux, and Perl. The self-test also uses Bash and basic GNU utilities.

```bash
tmxh                  # Attach to USER-codex, creating it if needed.
tmxh --create         # Create or prepare the session without attaching.
```

Detach with **Ctrl+B**, then **D**. Run the following commands from your own terminal or a second terminal. For an existing `USER-codex` session, you can specify the operation directly.

```bash
tmxh run --timeout 30 'pwd; hostname'
tmxh bg 'sleep 5; printf "done\n"'
```

The `bg` command returns a job ID such as `J2`. Substitute the ID you receive in the following examples.

```bash
tmxh status J2
tmxh read J2
tmxh wait J2 --timeout 30
tmxh log rx -n 30
```

For an existing SSH connection, identify the pane before sending input. In this example, `codex:0.0` identifies the session, window, and pane.

```bash
tmxh -t codex:0.0 --expect-cmd ssh doctor --no-probe
tmxh -t codex:0.0 --expect-cmd ssh run --timeout 30 'hostname; pwd'
```

On a new pane, `doctor --no-probe` can report that logging has yet to start. Check the target and the `pane_cmd` field. The first `run` starts logging. If the connection drops, check which steps completed and restore the connection in the original pane.

## Detailed usage

### Targeting and logging

| Operation | Example |
| --- | --- |
| Select the active pane and start logging | `tmxh ensure` |
| Select a session by name | `tmxh -s work info` |
| Select a specific window and pane | `tmxh -t work:1.0 info` |
| Select a tmux pane ID | `tmxh -t %3 info` |
| Inspect a target without sending a shell command | `tmxh -t work:1.0 doctor --no-probe --json` |

The `-s`, `-w`, and `-p` options select the session, window index, and pane index separately. `-p %3` searches within the session, while `-t %3` searches the tmux server. The default target is the active pane in `USER-codex`. `--session-name work` derives the ID from the username and the logical name. `--session-id novarobot-work` selects an exact tmux name. By default, `run`, `bg`, `info`, and `ensure` use an existing session. Run `tmxh` to attach or `tmxh --create` to create a detached session. Add `--no-create` to make an attach fail when the session is missing. Use `--expect-cmd ssh` to verify the foreground command of an SSH target. `info` may start logging. `doctor --no-probe` inspects the pane without sending input.

### Commands and job state

| Command | Behavior |
| --- | --- |
| `run 'command'` | Waits for the shell's completion marker and streams terminal output by default. |
| `bg 'command'`, `run -n 'command'` | Submits the command and returns an ID. A pane's shell processes input in order. |
| `status [J2]` | Shows a job or lists the session's jobs. Options include `--running`, `--long`, `--limit N`, and `--json`. |
| `read J2` | Reads from the saved position. `--all` reads the full range, `--no-advance` leaves the position unchanged, and `--tail N` returns the last lines. `--raw` preserves the log bytes. |
| `wait J2`, `wait --all` | Waits for one job or for jobs currently recorded as running. `--no-print` suppresses the transcript. |
| `interrupt` | Sends Ctrl+C to the pane and records pending jobs as interrupted. The target program determines when it actually stops. `--clear` also sends Ctrl+U. |
| `clean-jobs --older 24` | Deletes metadata for completed jobs more than 24 hours old. `--all` selects all completed jobs. |

`run` and `wait` wait indefinitely by default. `--timeout S` limits the wait and `--idle S` limits how long to wait without output. The command may continue in the pane after the wait times out. A later `status` or `read` processes the completion marker. A successful `bg` result acknowledges submission. Check the job's `status` and `exit` fields for the command result.

Pass the shell text as one quoted argument. In the default mode, changes such as `cd` persist in the pane. `--subshell` and `--cwd DIR` run in a subshell. `--eval` evaluates shell text supplied through a here-document. Use `--env K=V` repeatedly to export variables before a command. Names start with a letter or underscore and may contain ASCII letters, digits, and underscores. Values are passed literally, including spaces and shell metacharacters. `run --output FILE` writes the collected output to a local file. `run --json` emits an object when the command completes, and `wait --json` summarizes the jobs. `wait --all --json` returns `{"jobs":[]}` when none are running. JSON output from `run`, `read`, and `capture` interprets transcripts as UTF-8. `read --raw` preserves bytes and represents them individually when combined with JSON. The `new_bytes` field still counts bytes.

The panel transcript may contain prompts, echoed commands, control characters, and helper markers. Interactive programs, password prompts, and shell commands launched in the background can affect how completion and output are interpreted. In the default mode, `exit` or `exec` can close or replace the pane's shell.

### Pane operations and file transfer

| Command | Purpose |
| --- | --- |
| `capture -S 100` | Takes a snapshot of the visible screen and scrollback. `-e` keeps terminal codes returned by tmux. |
| `send --enter 'echo test'` | Sends text followed by Enter. Omit the option to leave the command line open for editing. |
| `keys Enter` | Sends one or more tmux key names. |
| `tail --for 10` | Follows panel output for ten seconds. |
| `idle --for 2 --timeout 30` | Waits for two seconds of silence, up to thirty seconds. |
| `push ./local.sh /target/local.sh --verify md5` | Transfers a file to the pane's machine using Base64. With no destination, it uses the pane's working directory. |
| `attach` | Attaches to an existing session. `--create` allows the session to be created. |
| `kill` | Closes the selected registered session and its connections. |

`push` verifies the size by default. `--verify md5` checks the file contents and `--verify none` skips verification. The destination needs a working `base64 -d` command. The transfer can overwrite an existing file. The encoded content appears in the terminal transcript and TX log.

### Listing and managing sessions

```bash
tmxh list
tmxh list -all
tmxh list --user novarobot
tmxh list --user '*' --all
tmxh clean
tmxh clean --session-name work
tmxh clean --user '*'
tmxh kill
tmxh kill --session-id novarobot-work
tmxh kill --user '*' --session-name work
```

`list` shows the ID, account, last update, and status. The default view shows only your running sessions. `--all` and `-all` include registered sessions that have stopped. Use `--json` for machine-readable output. Account home directories come from `/etc/passwd`. Quote `'*'` to select all accounts. Managing other users requires administrator privileges. The lookup for other users uses the standard `/tmp/tmux-UID/default` socket. For your account, the helper uses the current tmux client's socket or the configured launcher.

On its own, `clean` removes links for your stopped sessions. Use a name or user filter to change which links are selected. `kill` defaults to your configured session, records the time in the archive's audit log, closes the session, and removes the link. `--all-tmux-kill` finds the selected user's tmux servers and clients in the Linux process list and terminates them immediately. Their session links remain in place. To select several accounts, use `tmxh --all-tmux-kill --user '*'`.

### Logs and configuration

The default data directory is `~/tmux`. Each start gets its own archive, such as `~/tmux/archive/novarobot-codex.20261125-131521`. The link `~/tmux/sessions/codex` points to its current archive. On a normal shutdown, the link is removed and the archive stays. Use a separate data directory for another tmux socket.

| File | Contents |
| --- | --- |
| `panes/<numeric-pane-id>-<PID>/rx.log` | Raw PTY output since logging began, including visible echoes of manual input. |
| `tx.log` | Text and key presses sent or prepared by the helper. |
| `audit.log` | Timestamped events such as `SUBMIT`, `DONE`, `SEND`, `KEYS`, and `KILL`. |
| `jobs/J2.json` | Command, status, target pane, and log offsets. |

`log audit`, `log tx`, and `log rx` show the end of the corresponding log. `--path` prints its path and `-f` follows it. To read another window's RX log, specify the same pane target. tmux passes through visible terminal output. Manually typed keystrokes with echo disabled do not appear in the TX log. The default rotation threshold for TX and audit is 20 MiB. RX logs stay in place because jobs reference byte offsets. Newly created files have restricted permissions. Existing state directories retain their permissions.

`~/tmux/config` and the file selected by `--config FILE` accept simple `key = value` lines.

```ini
session_name = codex
state_dir = ~/tmux
# Set expect_cmd = ssh for an existing SSH pane if appropriate.
timeout = 60
guard = 3
```

`TMUXH_SESSION`, `TMUXH_WINDOW`, `TMUXH_PANE`, `TMUXH_STATE_DIR`, and `TMUXH_CONFIG` provide defaults. `TMUXH_TMUX` selects the tmux binary or a compatible launcher. The config file overrides environment defaults, and command-line options override the config file. `default_session` and `tmux_dir` are aliases for `session_name` and `state_dir`. Relative data paths are resolved from the account's home directory. The `create` setting overrides the default creation behavior. `--quiet` reduces status messages and `--verbose` enables diagnostics. `--no-pipe` is suitable for operations such as taking a screenshot of the pane. Tracked execution requires an RX log.

### Debian package

Install `tmux-1.2.6.deb` with `sudo apt install ./tmux-1.2.6.deb`. The Debian package is named `tmxh` and depends on `tmux` and `perl`. The executable is installed in `/opt/ds/tools/tmxh/bin` and the documentation in `/opt/ds/tools/tmxh`. The post-install script delegates to `/opt/ds/tools/tmxh/install.sh -t`. That script creates `/opt/ds/bin/tmxh` and `/usr/bin/tmxh`. If `/opt/bin` already exists, it is included in the link chain.

`./make-deb.sh` writes `tmux-1.2.6.deb` to the current working directory. Run `./make-deb.sh --set-version VERSION` to update the current release version in the text sources without building. `debian/version` provides the package version. The package contains both `make-deb.sh` and the `debian/` files so you can build it again.

### Exit codes and self-test

The helper propagates the exit code of a completed command. Its own codes include `2` for usage or operation errors, `3` for a missing target or job, `4` for a tmux error, `5` for a changed or lost pane, `124` for a time limit, and `130` for an interruption. These can overlap with exit codes from shell commands. Use job status and diagnostic output to identify the cause.

```bash
perl -c bin/tmxh
podchecker bin/tmxh
./test-tmuxh.sh
```

The self-test uses a separate tmux socket and temporary directory. `KEEP=1` preserves test files. The test server is stopped in either case.

See also [AI agent guide](tmux-agent-EN.md) and [specification and technical reference](tmux-project-EN.md).
