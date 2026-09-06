# Atuin — shell history search

[Atuin](https://atuin.sh/) replaces `Ctrl-R` with a sqlite-backed search TUI. Installed
on every profile (`packages/arch-terminal.txt` on Arch/WSL, `packages/Brewfile` on macOS),
configured by `dot_config/atuin/config.toml`, wired into zsh by `dot_zshrc.tmpl`.

**Local-only, deliberately.** No account, no sync, no network. Atuin's sync server is a
separate package (`atuin-server` on Arch) that is *not* installed; with `update_check =
false` and no login the client makes no network requests at all. History following the
laptop/desktop/WSL/mac boxes around is a possible next step, not something configured —
the recipe is at the bottom.

It does **not** overlap zoxide. zoxide ranks *directories* for `z`-jumping; Atuin searches
*commands*. Both stay.

## What is configured

| Setting | Why |
|---|---|
| `auto_sync = false`, `update_check = false` | Local-only; `update_check` otherwise pings `api.atuin.sh` hourly, and pacman/brew own updates here. |
| `keymap_mode = "auto"` | The TUI starts in whichever mode matches the zsh keymap that opened it — `Ctrl-R` from vicmd opens in vim-normal, from viins in vim-insert. |
| `keymap_cursor` | Bar cursor in insert, block in normal, so the mode is visible. |
| `enter_accept = false` | Enter puts the selected command on the prompt to edit; a second Enter runs it. No accidental execution of a half-remembered `rm`. |
| `--disable-up-arrow` (in `.zshrc`) | `↑` stays plain zsh history recall — muscle memory for "the thing I just ran". |
| `--disable-ai` (in `.zshrc`) | Atuin's `?` binding is a cloud feature; unusable without an account, and `?` stays a literal `?` at the prompt. |

Everything else is Atuin's default: `search_mode = "fuzzy"`, `style = "compact"`,
`inline_height = 40`, `show_preview = true`.

## Keeping secrets out of history

Two stores, two mechanisms, and one manual lever that covers both.

**The manual lever:** Oh My Zsh sets `hist_ignore_space`, so a command typed with a
**leading space** is recorded by neither zsh nor Atuin (Atuin's `history start` hook
honours it — verified, not assumed). Use it whenever a secret has to be typed inline.

**Atuin's DB** (`dot_config/atuin/config.toml`) — `secrets_filter = true` is on by
default but only knows AWS `AKIA…`, GitHub `ghp_…`, Slack `xox…` and PEM private-key
headers. It does *not* catch OpenAI/Anthropic `sk-proj-…`, Resend `re_…`, Context7
`ctx7sk-…`, or a `Password=` inside a connection string — all of which were sitting in
the DB when this was first checked. `history_filter` adds unanchored Rust regexes for
those shapes. `user-secrets set` is filtered by command name, since handing a secret to
something is the entire point of that call.

**`~/.zsh_history`** (`dot_zshrc.tmpl`) — Atuin's filters do not touch it, and Atuin
never removes what `atuin import auto` seeded from it. zsh's own `HISTORY_IGNORE` (an
extended-glob pattern, applied when zsh writes `HISTFILE`) mirrors the Atuin list.
**Keep the two lists in sync** when adding a pattern.

The keyword patterns stop at the `=` or `:` and match anything after it. Requiring a
value character instead looked tighter but leaked twice: it missed `ADMIN_PW="…"`
(the value starts with a quote) and every continuation line of a multi-line
`docker run -e … \`. The keyword must sit immediately before the separator, so
`kubectl get secrets` and `ssh -o StrictHostKeyChecking=no` still get recorded, while
`grep -r password= .` does not — a false positive costs one history entry.

Short forms (`ADMIN_PW=`) need a non-alpha boundary in front or `StartupWMClass=`
matches; `pwd` on its own is safe, it takes a `=` or `:` to trigger.

### Two zsh glob traps

Both cost a leaked entry before being caught, so verify any new pattern by hand:

```zsh
[[ "S3__SecretKey=abc" == ${~HISTORY_IGNORE} ]] && echo DROP || echo keep
```

1. `(#i)` must sit **outside** the alternation. Placed inside one branch it does not
   reach the others — `ADMIN_PW=` silently survived a pattern that looked correct.
2. `(#i)` does not apply to a **repeated or counted** class: neither `[a-z0-9_]#` nor
   `[a-z0-9](#c8,)` matches uppercase under it. Spell those `[a-zA-Z0-9]`.

### Purging what is already stored

Both filters apply to *new* commands only.

```bash
atuin history prune --dry-run   # list what would go
atuin history prune             # delete it
sqlite3 ~/.local/share/atuin/history.db 'vacuum;'   # deleted rows leave the file

# ~/.zsh_history has no equivalent. Do NOT line-wise grep it: entries start with
# `: <ts>:<dur>;` and a multi-line command's continuation lines carry the secret,
# so a grep -v leaves half a `docker run` behind. Group by entry, match the whole
# entry, and back the file up first.
```

Deleting the record is the cheap half. **Anything that reached either store must be
rotated** — the DB is readable by anything running as your user, it lands in backups,
and it would be uploaded if sync were ever turned on.

### The real fix

Never type the value. `$(op read op://vault/item/field)`, an `.envrc`, or
`$(sid <name>)`-style lookups keep the secret out of the command line entirely — those
lines are safe to keep in history and are the ones worth recalling anyway.

`dot_config/atuin/config.toml` is a plain tracked file, not a template (no cross-platform
difference) and not a `create_` entry: Atuin only writes a default config when none
exists, and never rewrites ours.

`run_once_after_36-atuin.sh.tmpl` seeds the sqlite DB from the existing plain histfile
(`atuin import auto`) on first apply. It is `run_once` precisely because a second import
would duplicate every entry, and non-fatal on failure so a fresh box with no histfile
doesn't abort the whole `chezmoi apply`.

## The zsh-vi-mode trap

**This is the thing that will cost an hour if `Ctrl-R` ever stops working.**

`zsh-vi-mode` does not initialize when it is sourced. Its default `ZVM_INIT_MODE` appends
`zvm_init` to `precmd_functions` (`zsh-vi-mode.zsh:4035-4038`), so it runs at the *first
prompt* — after `.zshrc` has finished — and rebinds every keymap from scratch. Anything
bound inline in `.zshrc`, Atuin's `^R` widget included, is silently overwritten. The
symptom is not an error: `Ctrl-R` just falls back to bare zsh behaviour.

The fix is the plugin's documented hook. It pre-declares `zvm_after_init_commands` as a
global array (`zsh-vi-mode.zsh:373-387`) and evals each element after its own init
(`zvm_exec_commands`, line 3949), so the binding lands last:

```zsh
if command -v atuin >/dev/null; then
  if (( ${+zvm_after_init_commands} )); then
    zvm_after_init_commands+=('eval "$(atuin init zsh --disable-up-arrow --disable-ai)"')
  else
    eval "$(atuin init zsh --disable-up-arrow --disable-ai)"
  fi
fi
```

The `else` branch matters on a machine where `run_once_after_31-zsh-plugins.sh.tmpl`
hasn't cloned `zsh-vi-mode` yet — without it the append would land in an array nothing
ever evaluates and `Ctrl-R` would do nothing.

This applies to **any** keybinding added to `.zshrc` later (fzf key-bindings, …), not
just Atuin.

Check the binding at an interactive prompt — never from a startup script, since it only
lands after the first `precmd`:

```bash
bindkey | rg atuin      # want: "^R" atuin-search
```

## Using it

`Ctrl-R` opens the search. Vim keys work because `keymap_mode = "auto"` carries the zsh
keymap in:

| Key | Does |
|---|---|
| `j` / `k` | Move down / up the results (vim-normal) |
| `i` | Enter insert mode and type a query |
| `Esc` | Back to normal mode (`Esc` again exits the TUI) |
| `Ctrl-R` | Cycle filter mode — host / session / directory / global |
| `Ctrl-S` | Cycle search mode — fuzzy / prefix / fulltext / skim |
| `Enter` | Put the command on the prompt (does **not** run it) |
| `Tab` | Same, explicitly edit-without-running |

Useful outside the TUI:

```bash
atuin stats                 # top commands, totals — also proves the import ran
atuin search --limit 20 git # non-interactive search
atuin history list          # raw dump
```

## Turning sync on later

Not configured; this is the recipe if history-across-machines becomes worth it. Self-host
rather than using `api.atuin.sh` — the desktop (`dev = true`) is already an always-on box
on the tailnet.

1. **Server** — on the dev box, install `atuin-server` and `postgresql` (Arch `extra`;
   they're separate packages from the client). Create the DB and role, then configure
   `~/.config/atuin/server.toml` with the connection string and an open registration
   window just long enough to register.
2. **Bind to the tailnet only.** Set the server's `host` to the box's `tailscale0`
   address, not `0.0.0.0` — the tailnet is the perimeter, exactly like sshd.
3. **Firewall.** `run_once_after_28-firewall.sh.tmpl` allows *port 22* on `tailscale0`,
   not the whole interface (allowing the interface wholesale would expose every listener
   on the box to the tailnet). So a sync port needs its own rule added there, in the same
   shape:
   ```bash
   sudo ufw allow in on tailscale0 to any port 8888 proto tcp comment 'atuin sync'
   ```
4. **Clients** — point them at the box via the existing `devHost` data var rather than a
   hardcoded hostname. That means converting `dot_config/atuin/config.toml` to a template
   (`chezmoi chattr +template`) and reading it with `dig`, matching the repo rule:
   ```gotemplate
   {{ if dig "devHost" "" . }}sync_address = "http://{{ dig "devHost" "" . }}:8888"{{ end }}
   ```
   Skip the block when `devHost` equals `.chezmoi.hostname`, like `private_dot_ssh/config.tmpl`
   does — the server box shouldn't sync to itself over the network.
5. `atuin register` / `atuin login`, then flip `auto_sync = true` (and set `sync_frequency`).

**`~/.local/share/atuin/key` is a secret.** It's the encryption key for the synced
history; without it a new machine can log in and see nothing decryptable, and anyone with
it can read everything. Store it in 1Password and bootstrap it via
`dot_config/private_environment.tmpl`'s `onepasswordRead` pattern (or copy it by hand). Never
commit it, and never let it land in this repo unencrypted.
