# tmxh 1.2.6 specification and technical reference

## Specification

| Area | Requirement | Implementation |
| --- | --- | --- |
| Environment | Control an existing tmux pane, including one with an open SSH connection. | The helper connects to the tmux server. The pane's shell receives the commands as terminal input. The shell and connection retain their state in the pane. |
| Default | Find or create the `USER-codex` session. | `has-session` checks the exact name. A bare invocation attaches and starts a local shell if needed. `--create` starts it detached. Named operations require an existing session by default. |
| Targeting | Select a different session, window, or pane. | `-s`, `-w`, `-p`, or `-t` with a composite target or a server-side pane ID. Each job is tied to the actual pane and its starting process. |
| Blocking execution | Stream output, wait for completion, and propagate the exit code. | Start and completion markers in the RX log. Live output can include partial lines. Timeout, idle timeout, and pane loss have separate states. |
| Asynchronous execution | Return a job ID for later inspection. | Per-session `J<n>` IDs, JSON metadata, and the `status`, `read`, and `wait` commands. Each pane uses one shell input stream. |
| Logging | Trace helper input and visible pane output. | Separate audit, TX, and RX logs. `pipe-pane` captures PTY data after logging starts. Manually typed input appears in RX when the terminal echoes it. |
| Connection loss | Detect and report a dropped SSH connection or pane. | `--expect-cmd ssh` checks before sending input and periodically during a job. The helper leaves reconnection to the operator. |
| Operations | Provide transfer, diagnostics, documentation, and a self-test. | Base64-based `push`, `doctor`, built-in help and POD, bilingual Markdown documentation, and an isolated Bash self-test. |

## Execution model

`tmxh` is one executable Perl file and uses standard modules. It invokes tmux commands with argument lists. The pane's shell and the helper are separate processes. The terminal protocol assumes an interactive POSIX-like shell. Tests ran on Linux with Bash and tmux 3.3a.

1. `main` loads defaults and the configuration file, parses common options, and calls the command handler. With no command, the explicit `--create` option selects the `ensure` handler. Otherwise the bare invocation selects `attach`.
2. The sending command selects the pane, checks the foreground command if specified, and sets up logging. tmux continuously supplies the pane's RX stream.
3. A per-session submission lock protects ID allocation and the input belonging to each job. The pane receives the start marker, the command, and the completion marker with the exit code in that order.
4. For `run` and `wait`, the reader scans complete lines for markers and uses a separate byte offset to display output. For `status` and `read`, it updates the job using the data already available.
5. The pane and its RX filter can outlive the helper invocation. A later query determines whether a background job completed. A wait timeout returns control to the caller while the pane command may continue.

An example transcript with markers follows.

```text
TMUXH-BEG-J12
... terminal transcript ...
TMUXH-END-J12-7
```

The shell exit code is `7`. The raw transcript can contain prompts, command echoes, and markers. Marker matching accounts for line endings, some terminal control characters, and surrounding whitespace.

## State and file formats

| Path under the state root | Contents |
| --- | --- |
| `<archive>/counter` | The helper's incrementing counter. |
| `<archive>/submit.lock`, `pipe.lock` | Locks for job submission and logger startup. |
| `<archive>/jobs/J<n>.json` | Pane, PID, original and expected foreground commands, shell text, execution mode, status, times, exit code, and offsets. |
| `<archive>/meta.json` | The most recently prepared pane, its log, and the helper version. |
| `<archive>/rxfilter.pl` | The Perl filter written by the helper. |
| `<archive>/panes/<numeric-pane-id>-<PID>/rx.log` | Raw binary PTY data. `rx.log.pid` holds the filter PID. |
| `<archive>/tx.log`, `audit.log` | Timestamped activity. The helper rotates them to a `.1` copy at the size threshold. |

JSON files are updated by writing to a temporary file and renaming it. `start_offset` is the RX position before submission. `scan_offset` is where marker scanning resumes. `read_offset` is the incremental read position. `beg_offset` follows the start marker. `end_offset` follows the completion marker or records the last observed position after an interruption.

Jobs from version `1.0` can lack `pane_pid`. For those jobs the helper reads the legacy shared `<session>/rx.log` file. Version 1.2.6 keeps the session's state tree in a timestamped archive. New jobs use per-pane logs in the active archive. If the pane already has a `pipe-pane` connection, the helper can take over only its own identifiable connection. A different logger causes an error.

| Job state | Meaning |
| --- | --- |
| `running` | Submitted with no completion marker yet. This includes queued jobs. |
| `done` | The completion marker was found. `exit` contains the shell exit code. |
| `timeout`, `idle` | A wait or idle limit was reached. A later completion marker can change the state to `done`. |
| `interrupted` | The helper sent an interrupt to the pane. |
| `pane-cmd-changed` | The pane closed, its monitored process changed, or the expected foreground command disappeared. |

## Functions

### Entry points and configuration

| Function | Responsibility |
| --- | --- |
| `main` | Load configuration, parse common options, select a command, and return an exit code. |
| `cfg_defaults`, `load_config_file` | Load defaults, environment settings, and file configuration. |
| `common_opts`, `set_target` | Define common Getopt options and split the target address. |
| `usage_text`, `cmd_help`, `cmd_version` | Display built-in help and version information. |

### tmux, state directories, and logs

| Function | Responsibility |
| --- | --- |
| `tmux`, `tmux_alive`, `tmux_ver` | Run the tmux client, check availability, and get the version. |
| `session_exists`, `pane_format`, `list_panes`, `resolve_pane` | Check the exact session, read pane metadata, and resolve the target. |
| `pane_current_command_of`, `last_screen_line`, `warn_if_unexpected` | Inspect the foreground process and prompt and report anomalies. |
| `check_input_pane`, `ensure_all`, `save_meta` | Validate the destination, prepare the environment, and save pane metadata. |
| `init_paths`, `init_state`, `panel_rx_path`, `job_rx_path` | Resolve state paths and logs for panes and existing jobs. |
| `filter_source`, `pipe_pid_alive`, `ensure_pipe`, `stop_pipe` | Provide the filter, identify the logger, and start or stop it. |
| `log_append`, `log_audit`, `log_tx`, `rotate_small_logs` | Write locked logs, format audit and TX data, and rotate at the size threshold. |
| `send_text`, `send_keys` | Send and log chunks of text or tmux key presses. |
| `read_records`, `read_range` | Read complete records or arbitrary byte ranges. |

### Job tracking

| Function | Responsibility |
| --- | --- |
| `next_job_id`, `job_file`, `save_job`, `load_job` | Allocate IDs, construct paths, and save or load JSON state. |
| `job_num`, `all_jobs`, `running_jobs` | Sort numerically, enumerate jobs, and select running jobs. |
| `build_job_text`, `send_job` | Assemble shell input and markers and submit logged jobs. |
| `marker_beg`, `marker_exit` | Recognize the start marker and parse the completion exit code. |
| `check_job_panel`, `job_exit_code` | Detect pane or process changes and select an exit code. |
| `wait_job`, `reap_job`, `reap_all` | Wait, display live output, or refresh job state. |
| `run_blocking`, `probe_shell` | Run a command internally, collect output, and probe shell communication. |
| `job_output`, `job_dur`, `job_line` | Get stored output, calculate duration, and format a status line. |

### Command handlers and utilities

| Function | Responsibility |
| --- | --- |
| `cmd_ensure`, `cmd_info`, `cmd_doctor` | Prepare the environment, summarize state, and diagnose the target. |
| `cmd_run`, `cmd_status`, `cmd_read`, `cmd_wait` | Run, inspect, read, and wait for jobs. `bg` and `jobs` are related aliases. |
| `cmd_tail`, `cmd_idle`, `cmd_capture` | Follow RX, wait for silence, or capture the screen. |
| `cmd_send`, `cmd_keys`, `cmd_interrupt`, `cmd_push` | Send raw text, send keystrokes, interrupt, or transfer a file with Base64. |
| `cmd_log`, `cmd_clean_jobs`, `cmd_clean`, `cmd_kill`, `cmd_attach` | Manage logs, delete completed job metadata, remove registry links, stop sessions, or attach. `cmd_attach` calls `attach-session` outside tmux and `switch-client` inside a tmux client. |
| `ts`, `ts_fmt`, `fmt_dur`, `err`, `dbg`, `fail` | Format timestamps and durations, issue diagnostics, and exit on errors. |
| `slurp`, `spew`, `fsize` | Read a file, write by renaming, and obtain a file size. |
| `sq`, `trim`, `oneline`, `deansi`, `strip_ts`, `clean_line` | Quote shell strings, format lines, and handle control sequences and legacy timestamps. |

## Session registry and lifecycle

By default, the helper reads `tmux/config` from the account's home directory. `session_name` or `default_session` sets the logical name, which defaults to `codex`. `state_dir` or `tmux_dir` sets the data root, which defaults to `~/tmux`. The helper constructs `USER-NAME` from the logical name. `--session-id` selects an exact ID. Accounts and their home directories come from `/etc/passwd`.

`register_session` creates an `ID.YYYYMMDD-HHMMSS` directory under `archive` and publishes the short `sessions/NAME` link by renaming it. The tmux session option `@tmxh_archive` connects the running instance to its archive. `.register.lock` coordinates archive creation and link updates. On closure, the tmux `session-closed` hook verifies the link's expected target before deleting it. This preserves the new reference if a same-name session has already restarted.

`list` combines live tmux sessions and the on-disk registry. It shows your running sessions by default. `-all` is equivalent to `--all` and includes stopped sessions and registrations whose state cannot be verified. `--user '*'` examines every accessible local account. The table reports ID, account, last update, and state. The JSON `updated` field uses Unix time.

`clean` removes a session link only after confirming the session has stopped. `kill` writes a timestamped `KILL` audit entry, closes the session in tmux, and removes its link. `--all-tmux-kill` uses Linux `/proc` to inspect the process owner, name, and executable before sending `SIGKILL`. It bypasses the on-disk registry and tmux shutdown hooks. Links remain available for a later `clean`.

| Function | Responsibility |
| --- | --- |
| `accounts`, `selected_accounts`, `account_config`, `home_path` | Discover and select accounts and resolve configuration and home-relative paths. |
| `valid_session`, `session_label`, `session_id_alive` | Validate names, derive link names, and check an exact tmux target. |
| `registered_archive`, `last_archive`, `register_session` | Find the active or prior archive and register new archives. |
| `close_hook`, `remove_archive_link` | Register the tmux shutdown hook and remove the expected link under a lock. |
| `account_tmux`, `live_sessions`, `session_rows` | Query tmux by account, collect running sessions, and combine their state. |
| `cmd_list_sessions`, `manage_sessions`, `run_as_account` | Emit table or JSON, perform targeted cleanup or shutdown, and run other accounts' operations with their privileges. |
| `cmd_all_tmux_kill` | Identify and terminate processes without consulting the on-disk registry. |

## Debian installation and build

The package architecture is `all` and the runtime dependencies are `tmux` and `perl`. The post-install script invokes `/opt/ds/tools/tmxh/install.sh -t`. The installer validates the paths and sets up the link chain. Without `/opt/bin`, `/usr/bin/tmxh` points to `/opt/ds/bin/tmxh`. On removal, `prerm` calls the same script in `-r` mode. Shared directories and user archives remain intact.

`make-deb.sh` uses `debian/control`, `debian/postinst`, `debian/prerm`, and `debian/version`. The package contains the executable, installer, self-test, both documentation languages, and its own build sources. `--set-version VERSION` updates the current release in the text source files. Building is a separate step.

## Verification and operating limits

`test-tmuxh.sh` starts tmux on a separate socket in a dedicated working directory. It checks blocking and asynchronous execution, exit codes, environment values, UTF-8 JSON, an empty wait result, diagnostics, and file transfer.

Pane validation and tmux input submission are separate operations. If the connection drops, remote execution may be uncertain. Keep the job ID and logs. Manual interaction, concurrent readers, or interactive programs in the same pane can share shell input or the read cursor. File transfers send content and commands through the terminal. Set log storage and access rules for the operating environment.
