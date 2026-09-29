# -------------------------------------------------------------
# 0. Omarchy & Environment Setup
# -------------------------------------------------------------
. "$HOME/.local/bin/env" 2>/dev/null || true

# Ensure 256-color terminal support (crucial for SSH/Mosh & autosuggestions)
if [ "$TERM" = "xterm" ] || [ "$TERM" = "vt100" ]; then
    export TERM="xterm-256color"
fi

# Ensure LS_COLORS is set for completion formatting
if [ -z "$LS_COLORS" ] && command -v dircolors &>/dev/null; then
    eval "$(dircolors -b 2>/dev/null)"
fi

# Source default Omarchy aliases if present
if [ -f ~/.local/share/omarchy/default/bash/aliases ]; then
    source ~/.local/share/omarchy/default/bash/aliases
fi

# Environment tools (Mise, Zoxide)
command -v mise &>/dev/null && eval "$(mise activate zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh --cmd cd)"

# -------------------------------------------------------------
# 1. History Configuration (Crucial for zsh-autosuggestions)
# -------------------------------------------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# History optimizations
setopt SHARE_HISTORY          # Share history across all active terminals
setopt HIST_IGNORE_ALL_DUPS   # Don't record duplicate commands
setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks from history
setopt HIST_IGNORE_SPACE      # Don't record commands starting with a space

# Prefix-aware history search with Up / Down arrow keys
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
[[ -n "${terminfo[kcuu1]}" ]] && bindkey -- "${terminfo[kcuu1]}" up-line-or-beginning-search
[[ -n "${terminfo[kcud1]}" ]] && bindkey -- "${terminfo[kcud1]}" down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# -------------------------------------------------------------
# 2. Advanced Tab Completions & Menu Selection
# -------------------------------------------------------------
mkdir -p ~/.zsh/cache
zmodload zsh/complist 2>/dev/null
autoload -Uz compinit
compinit -d ~/.zsh/zcompdump

zstyle ':completion:*' menu select                     # Arrow keys navigate the menu
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' # Case-insensitive matching
zstyle ':completion:*' list-colors '${(s.:.)LS_COLORS}' # Use terminal colors in menu
zstyle ':completion:*' group-name ''                    # Group completions by type
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f' # Labeled groups
zstyle ':completion:*' use-cache yes                   # Cache completions for speed
zstyle ':completion:*' cache-path ~/.zsh/cache

# -------------------------------------------------------------
# 3. Quality of Life Options
# -------------------------------------------------------------
setopt AUTO_CD                # Just type a directory name to CD into it
setopt CORRECT                # Spell check commands (suggests corrections)
setopt AUTO_PUSHD             # Push old directory onto stack on cd (enables cd -<Tab>)
setopt PUSHD_IGNORE_DUPS      # Do not store duplicates in the stack
setopt PUSHD_SILENT           # Do not print directory stack after pushd/popd

# Magic Sudo toggle (Double-tap Esc or Alt-s)
_toggle-sudo-widget() {
    if [[ -z $BUFFER ]]; then
        BUFFER="$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')"
    fi
    if [[ $BUFFER == sudo\ * ]]; then
        BUFFER="${BUFFER#sudo }"
        (( CURSOR >= 5 )) && (( CURSOR -= 5 ))
    else
        BUFFER="sudo $BUFFER"
        (( CURSOR += 5 ))
    fi
    [[ -n "$WIDGET" ]] && zle end-of-line
}
zle -N _toggle-sudo-widget
bindkey '\e\e' _toggle-sudo-widget
bindkey '^[s' _toggle-sudo-widget
bindkey '\es' _toggle-sudo-widget

# -------------------------------------------------------------
# 4. Prompt Configuration
# -------------------------------------------------------------
# Option A: Minimalist Prompt (Native Zsh)
autoload -Uz vcs_info
setopt prompt_subst
precmd() { vcs_info }

# Format Git branch info if inside a repository
zstyle ':vcs_info:git:*' formats 'on %F{magenta}%b%f '

# Clean prompt: current directory (blue), git status (magenta), clean arrow (yellow)
PROMPT='%F{blue}%~%f ${vcs_info_msg_0_}%F{yellow}❯%f '

# Option B: Starship Prompt (Uncomment below if you prefer Omarchy's Starship prompt)
# command -v starship &>/dev/null && eval "$(starship init zsh)"

# -------------------------------------------------------------
# 5. Source Plugins (System Pacman or Local Git)
# -------------------------------------------------------------
# FZF Integration & Interactive Previews
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh

if command -v fzf &>/dev/null; then
    export FZF_DEFAULT_OPTS="--height 50% --layout=reverse --border --inline-info"
    if command -v fd &>/dev/null; then
        export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fd --type d --strip-cwd-prefix --hidden --follow --exclude .git'
    fi
    if command -v bat &>/dev/null; then
        export FZF_CTRL_T_OPTS="--preview 'bat -n --color=always --line-range :300 {}' --preview-window=right:60%"
    fi
    if command -v eza &>/dev/null; then
        export FZF_ALT_C_OPTS="--preview 'eza --tree --color=always {} | head -200' --preview-window=right:60%"
    fi
fi

# fzf-tab (Replace default completion menu with interactive fzf)
if [ -f ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh ]; then
    source ~/.zsh/plugins/fzf-tab/fzf-tab.plugin.zsh
    zstyle ':completion:*:git-checkout:*' sort false
    zstyle ':completion:*:descriptions' format '[%d]'
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --tree --level=1 --color=always ${(Q)realpath}'
    zstyle ':fzf-tab:complete:*:*' fzf-preview 'bat -n --color=always --line-range :200 ${(Q)realpath} 2>/dev/null'
    zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,%cpu,%mem,command -w"
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-preview '[[ $group == "[process ID]" ]] && ps --pid=$word -o cmd --no-headers -w -w'
    zstyle ':fzf-tab:complete:(kill|ps):argument-rest' fzf-flags --preview-window=down:3:wrap
    zstyle ':fzf-tab:complete:systemctl-*:*' fzf-preview 'SYSTEMD_COLORS=1 systemctl status $word'
    zstyle ':fzf-tab:*' switch-group '<' '>'
fi

# zsh-autopair (Auto-close brackets and quotes)
if [ -f ~/.zsh/plugins/zsh-autopair/autopair.zsh ]; then
    source ~/.zsh/plugins/zsh-autopair/autopair.zsh
    autopair-init
fi

# zsh-autosuggestions (Check system path first, then user home path)
if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# zsh-syntax-highlighting (MUST BE SOURCED LAST)
if [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# -------------------------------------------------------------
# 6. Environment Variables & Tools
# -------------------------------------------------------------
export EDITOR="nvim" # Set to Neovim (installed); change to nano if installed

# Eza Aliases (Modern replacement for ls)
if command -v eza &>/dev/null; then
    alias ls='eza --icons=always --color=always --group-directories-first'
    alias ll='eza -lh --icons=always --color=always --group-directories-first'
    alias la='eza -a --icons=always --color=always --group-directories-first'
    alias lla='eza -lah --icons=always --color=always --group-directories-first'
    alias tree='eza --tree --icons=always'
fi

# Bat (Modern syntax-highlighted cat & colored man pages)
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
fi

# Modern CLI Tool Aliases
command -v lazygit &>/dev/null && alias lg="lazygit"
command -v lazydocker &>/dev/null && alias ld="lazydocker"
command -v dua &>/dev/null && alias du="dua i"
command -v rg &>/dev/null && alias rg="rg --smart-case"

# Interactive Ripgrep search with FZF and bat preview (Find In Files)
fif() {
    if ! command -v rg &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fif requires ripgrep and fzf" >&2
        return 1
    fi
    local query="${*:-}"
    local selected
    if [ -n "$query" ]; then
        selected=$(rg --column --line-number --no-heading --color=always --smart-case -H "$query" 2>/dev/null |
            fzf --ansi \
                --delimiter : \
                --nth 4.. \
                --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null' \
                --preview-window 'right:60%:+{2}-10' \
                --bind 'ctrl-/:toggle-preview' \
                --header "Results for '$query' | Enter: open | Ctrl-/: toggle preview")
    else
        local rg_cmd='rg --column --line-number --no-heading --color=always --smart-case -H {q}'
        selected=$(fzf --ansi --disabled \
            --bind "change:reload:$rg_cmd || true" \
            --delimiter : \
            --preview 'bat --style=numbers --color=always --highlight-line {2} {1} 2>/dev/null' \
            --preview-window 'right:60%:+{2}-10' \
            --bind 'ctrl-/:toggle-preview' \
            --header 'Type to search inside files | Enter: open | Ctrl-/: toggle preview')
    fi

    if [ -n "$selected" ]; then
        local file line
        file=$(echo "$selected" | cut -d: -f1 | sed 's/\x1b\[[0-9;]*m//g')
        line=$(echo "$selected" | cut -d: -f2 | sed 's/\x1b\[[0-9;]*m//g')
        ${EDITOR:-nvim} "+${line}" "$file"
    fi
}
alias rgf="fif"

# Interactive zoxide directory jump with eza tree preview
if command -v zoxide &>/dev/null; then
    alias z="cd"
    zz() {
        local dir
        dir=$(zoxide query -l | fzf --preview 'eza --tree --color=always {} 2>/dev/null | head -200' --preview-window=right:60% --header 'Jump to directory (Enter: cd)') && [ -n "$dir" ] && cd "$dir"
    }
    alias zd="zz"
fi

# Homebrew (Guarded in case it is installed later)
[ -f /home/linuxbrew/.linuxbrew/bin/brew ] && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv zsh)"

# Bun (standalone install fallback)
if [ -d "$HOME/.bun" ]; then
    export BUN_INSTALL="$HOME/.bun"
    export PATH="$BUN_INSTALL/bin:$PATH"
    [ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"
fi

# PATH additions
export PATH="$HOME/.local/bin:$PATH"

# Automatically start or attach to tmux (in Ghostty, SSH, Mosh, or any interactive terminal)
# if [ -z "$TMUX" ] && [ -n "$PS1" ] && [ -t 0 ] && command -v tmux &> /dev/null; then
#     tmux attach-session -t default 2>/dev/null || tmux new-session -s default
# fi
# Yazi shell wrapper to change directory on exit
function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	yazi "$@" --cwd-file="$tmp"
	if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
		builtin cd -- "$cwd"
	fi
	rm -f -- "$tmp"
}

alias n="nvim"

alias vi="nvim"

alias agyyolo='agy --dangerously-skip-permissions'

alias :q='exit'

# -------------------------------------------------------------
# 7. Workflow Productivity Functions
# -------------------------------------------------------------

# Universal archive extractor
extract() {
    if [ $# -eq 0 ]; then
        echo "Usage: extract <archive_file(s)>" >&2
        return 1
    fi
    for file in "$@"; do
        if [ ! -f "$file" ]; then
            echo "extract: '$file' is not a valid file" >&2
            continue
        fi
        case "${file:l}" in
            *.tar.bz2|*.tbz2)   tar xvjf "$file" ;;
            *.tar.gz|*.tgz)     tar xvzf "$file" ;;
            *.tar.xz|*.txz)     tar xvJf "$file" ;;
            *.tar.zst)          tar --zstd -xvf "$file" ;;
            *.tar)              tar xvf "$file" ;;
            *.bz2)              bunzip2 "$file" ;;
            *.rar)              if command -v unrar &>/dev/null; then unrar x "$file"; else 7z x "$file"; fi ;;
            *.gz)               gunzip "$file" ;;
            *.zip|*.jar|*.war)  unzip "$file" ;;
            *.7z)               7z x "$file" ;;
            *.zst)              zstd -d "$file" ;;
            *)                  echo "extract: unsupported format for '$file'" >&2 ;;
        esac
    done
}

# Copy path of current directory or specified file/folder to Wayland clipboard
copypath() {
    local target="${1:-$PWD}"
    local abs_path
    abs_path=$(realpath "$target" 2>/dev/null) || { echo "copypath: invalid path '$target'" >&2; return 1; }
    if command -v wl-copy &>/dev/null; then
        printf "%s" "$abs_path" | wl-copy
    elif command -v xclip &>/dev/null; then
        printf "%s" "$abs_path" | xclip -selection clipboard
    fi
    echo "Copied to clipboard: $abs_path"
}

# Copy contents of a file directly to Wayland clipboard
copyfile() {
    if [ -z "$1" ]; then
        echo "Usage: copyfile <filename>" >&2
        return 1
    fi
    if [ ! -f "$1" ]; then
        echo "copyfile: file not found: '$1'" >&2
        return 1
    fi
    if command -v wl-copy &>/dev/null; then
        wl-copy < "$1"
    elif command -v xclip &>/dev/null; then
        xclip -selection clipboard < "$1"
    fi
    echo "Copied contents of '$1' to clipboard ($(wc -c < "$1" | awk '{print $1}') bytes)"
}

# Interactive Process Killer (FZF + ps)
fkill() {
    if ! command -v fzf &>/dev/null; then
        echo "fkill requires fzf" >&2
        return 1
    fi
    local pid_output key pids
    pid_output=$(ps -u "$USER" -o pid,user,%cpu,%mem,stat,time,command | sed 1d | fzf --multi \
        --header="Enter: kill (SIGTERM) | Ctrl-X: force-kill (SIGKILL) | Tab: multi-select" \
        --preview="echo {}" \
        --preview-window="down:3:wrap" \
        --expect=ctrl-x)
    [ -z "$pid_output" ] && return

    key=$(echo "$pid_output" | head -n1)
    pids=$(echo "$pid_output" | tail -n +2 | awk '{print $1}')

    if [ -n "$pids" ]; then
        if [ "$key" = "ctrl-x" ]; then
            echo "$pids" | xargs -r kill -9 2>/dev/null && echo "Force-killed PID(s): $(echo $pids | tr '\n' ' ')"
        else
            echo "$pids" | xargs -r kill -15 2>/dev/null && echo "Terminated PID(s): $(echo $pids | tr '\n' ' ')"
        fi
    fi
}

# -------------------------------------------------------------
# 8. Global Pipe Aliases (Expand Anywhere in Pipeline)
# -------------------------------------------------------------
alias -g C='| wl-copy'
alias -g L='| bat --paging=always'
alias -g G='| rg'
alias -g J='| jq .'
alias -g H='| head'
alias -g T='| tail'
alias -g NE='2>/dev/null'
alias -g NUL='&>/dev/null &'

# -------------------------------------------------------------
# 9. Interactive Cheatsheet Explorer (ftldr)
# -------------------------------------------------------------
ftldr() {
    if ! command -v tldr &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "ftldr requires tldr and fzf" >&2
        return 1
    fi
    local cmd
    cmd=$(tldr -l 2>/dev/null | fzf \
        --preview='tldr -m {} 2>/dev/null | bat -l markdown --color=always -p 2>/dev/null' \
        --preview-window='right:65%:wrap' \
        --header='Search TLDR cheatsheets | Enter: open page | Ctrl-/: toggle preview' \
        --bind='ctrl-/:toggle-preview' \
        --query="${*:-}")
    if [ -n "$cmd" ]; then
        tldr -m "$cmd" | bat -l markdown -p
    fi
}

# -------------------------------------------------------------
# 10. Terminal Awareness: Ghostty Dynamic Titles & Long-Task Alerts
# -------------------------------------------------------------
zmodload zsh/datetime 2>/dev/null
autoload -Uz add-zsh-hook

# Dynamically update Ghostty tab/window titles
_update_title_preexec() {
    local cmd="${1%% *}"
    print -Pn "\e]0;${cmd} — %~\a"
}

_update_title_precmd() {
    print -Pn "\e]0;%~\a"
}

add-zsh-hook preexec _update_title_preexec
add-zsh-hook precmd _update_title_precmd

# Long-running command desktop notification (threshold: 10 seconds)
_notify_preexec() {
    _cmd_start_time=$EPOCHSECONDS
    _last_command="$1"
}

_notify_precmd() {
    local exit_code=$?
    if [[ -n $_cmd_start_time ]]; then
        local elapsed=$(( EPOCHSECONDS - _cmd_start_time ))
        unset _cmd_start_time

        if (( elapsed >= 10 )); then
            # Skip interactive TUIs where long time is expected
            local first_word="${${(z)_last_command}[1]}"
            case "$first_word" in
                nvim|vi|nano|man|less|more|top|htop|btop|tmux|ssh|yazi|lg|lazygit|ld|lazydocker|fzf|fif|rgf|fkill|ftldr|fport|fnote|fclip|fpaste|faudio|fserv|fpr|gcai|wsave|wrestore|explain|panel-health)
                    return
                    ;;
            esac

            local icon="dialog-information"
            local status_msg="completed in ${elapsed}s"
            if (( exit_code != 0 )); then
                icon="dialog-error"
                status_msg="failed (code $exit_code) after ${elapsed}s"
            fi

            notify-send -u normal -i "$icon" "Terminal Task" "$_last_command\n$status_msg" 2>/dev/null
        fi
    fi
}

add-zsh-hook preexec _notify_preexec
add-zsh-hook precmd _notify_precmd

# -------------------------------------------------------------
# 11. Micro-TUIs: fport, fnote, fclip, fpaste
# -------------------------------------------------------------

# Interactive Port & Socket Inspector and Process Killer
fport() {
    if ! command -v fzf &>/dev/null; then
        echo "fport requires fzf" >&2
        return 1
    fi
    local raw_ports
    raw_ports=$(ss -tulpn 2>/dev/null | awk 'NR>1 {
        proto = $1
        local_addr = $5
        n = split(local_addr, parts, ":")
        port = parts[n]
        proc_info = $7
        proc_name = "-"
        pid = "-"
        if (match(proc_info, /"([^"]+)"/, m)) proc_name = m[1]
        if (match(proc_info, /pid=([0-9]+)/, m)) pid = m[1]
        printf "%-6s  %-7s  %-18s  %-8s  %s\n", proto, port, proc_name, pid, local_addr
    }' | sort -u -k2,2n)

    if [[ -z "$raw_ports" ]]; then
        echo "No listening ports found."
        return 0
    fi

    local output key selected
    output=$(echo "$raw_ports" | fzf \
        --header="Enter: copy port | Ctrl-X: kill process | Ctrl-Y: copy PID | Ctrl-/: toggle preview" \
        --header-first \
        --expect=ctrl-x,ctrl-y \
        --preview='
            pid=$(echo {} | awk "{print \$4}")
            port=$(echo {} | awk "{print \$2}")
            if [[ "$pid" != "-" && -n "$pid" ]]; then
                echo "=== Process Info (PID: $pid) ==="
                ps -fp "$pid" 2>/dev/null || echo "Process $pid not found"
                echo "\n=== Command Line ==="
                cat /proc/$pid/cmdline 2>/dev/null | tr "\0" " " || true
                echo "\n\n=== Network Sockets ==="
                ss -tulpn "sport = :$port" 2>/dev/null
            else
                echo "=== Port :$port (System / root process) ==="
                ss -tulpn "sport = :$port" 2>/dev/null
            fi
        ' \
        --preview-window="right:60%:wrap" \
        --bind="ctrl-/:toggle-preview")

    [[ -z "$output" ]] && return

    key=$(echo "$output" | sed -n '1p')
    selected=$(echo "$output" | sed -n '2p')
    [[ -z "$selected" ]] && return

    local port pid proc_name
    port=$(echo "$selected" | awk '{print $2}')
    proc_name=$(echo "$selected" | awk '{print $3}')
    pid=$(echo "$selected" | awk '{print $4}')

    case "$key" in
        ctrl-x)
            if [[ "$pid" == "-" || -z "$pid" ]]; then
                echo "Cannot kill: PID not visible without root privileges (try: sudo ss -tulpn)." >&2
                return 1
            fi
            if kill -9 "$pid" 2>/dev/null; then
                echo "Killed process '$proc_name' (PID $pid) on port :$port."
            else
                echo "Failed to kill PID $pid (try: sudo kill -9 $pid)." >&2
            fi
            ;;
        ctrl-y)
            if [[ "$pid" != "-" && -n "$pid" ]]; then
                printf "%s" "$pid" | wl-copy
                echo "Copied PID $pid to clipboard."
            fi
            ;;
        *)
            printf "%s" "$port" | wl-copy
            echo "Copied port :$port to clipboard."
            ;;
    esac
}

# Instant Personal Notes & Scratchpad TUI
fnote() {
    local note_dir="${NOTE_DIR:-$HOME/Documents/notes}"
    mkdir -p "$note_dir"

    local output query key selected
    output=$( (cd "$note_dir" && (fd --type f --extension md . 2>/dev/null || find . -type f -name "*.md" | sed 's|^\./||')) | \
        fzf --print-query \
            --expect=ctrl-n,ctrl-y,ctrl-d \
            --header="Notes | Enter: open/create | Ctrl-N: new | Ctrl-Y: copy | Ctrl-D: delete" \
            --preview="bat --color=always -l markdown $note_dir/{} 2>/dev/null" \
            --preview-window="right:60%:wrap" \
            --query="${*:-}")

    [[ -z "$output" ]] && return

    query=$(echo "$output" | sed -n '1p')
    key=$(echo "$output" | sed -n '2p')
    selected=$(echo "$output" | sed -n '3p')

    # Create new note if Ctrl-N pressed, or if query entered without matching existing note
    if [[ "$key" == "ctrl-n" ]] || { [[ -z "$selected" ]] && [[ -n "$query" ]]; }; then
        local note_name="${query:-untitled}"
        [[ "$note_name" != *.md ]] && note_name="${note_name}.md"
        note_name=$(echo "$note_name" | tr ' ' '-')
        local note_path="$note_dir/$note_name"
        if [[ ! -f "$note_path" ]]; then
            local title
            title=$(basename "$note_name" .md | tr '-' ' ' | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')
            printf "# %s\n\n*Created: %s*\n\n" "$title" "$(date +'%Y-%m-%d %H:%M')" > "$note_path"
        fi
        ${EDITOR:-nvim} "$note_path"
        return
    fi

    [[ -z "$selected" ]] && return
    local note_path="$note_dir/$selected"

    case "$key" in
        ctrl-y)
            wl-copy < "$note_path" && echo "Copied '$selected' to clipboard."
            ;;
        ctrl-d)
            read -q "REPLY?Delete note '$selected'? (y/N) "
            echo
            if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                rm -f "$note_path" && echo "Deleted '$selected'."
            fi
            ;;
        *)
            ${EDITOR:-nvim} "$note_path"
            ;;
    esac
}

# Wayland Clipboard History Picker (Copies selection to clipboard)
fclip() {
    local hist_file="$HOME/.local/state/omarchy/clipboard-history.json"
    if [[ ! -f "$hist_file" ]] || ! command -v jq &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fclip: clipboard history not available" >&2
        return 1
    fi
    local selected
    selected=$(jq -r 'to_entries[] | select(.value.type=="text") | "\(.key)\t\(.value.text | split("\n")[0] | .[0:80])"' "$hist_file" | \
        fzf --delimiter='\t' \
            --with-nth=2 \
            --preview="jq -r --argjson idx {1} '.[$idx].text' $hist_file | bat --color=always --style=plain" \
            --preview-window="right:60%:wrap" \
            --header="Clipboard History | Enter: copy to clipboard | Ctrl-/: toggle preview" \
            --bind="ctrl-/:toggle-preview")
    [[ -z "$selected" ]] && return
    local idx
    idx=$(echo "$selected" | cut -f1)
    jq -r --argjson idx "$idx" '.[$idx].text' "$hist_file" | wl-copy
    echo "Copied selection to clipboard!"
}

# Wayland Clipboard Paste (Outputs selection directly or inserts into command line)
fpaste() {
    local hist_file="$HOME/.local/state/omarchy/clipboard-history.json"
    if [[ ! -f "$hist_file" ]] || ! command -v jq &>/dev/null || ! command -v fzf &>/dev/null; then
        echo "fpaste: clipboard history not available" >&2
        return 1
    fi
    local selected
    selected=$(jq -r 'to_entries[] | select(.value.type=="text") | "\(.key)\t\(.value.text | split("\n")[0] | .[0:80])"' "$hist_file" | \
        fzf --delimiter='\t' \
            --with-nth=2 \
            --preview="jq -r --argjson idx {1} '.[$idx].text' $hist_file | bat --color=always --style=plain" \
            --preview-window="right:60%:wrap" \
            --header="Paste from Clipboard | Enter: paste / output | Ctrl-/: toggle preview" \
            --bind="ctrl-/:toggle-preview")
    [[ -z "$selected" ]] && return
    local idx
    idx=$(echo "$selected" | cut -f1)
    jq -r --argjson idx "$idx" '.[$idx].text' "$hist_file"
}

# ZLE Widget: Press Alt-p to open clipboard picker and insert directly into current command buffer
_fpaste-widget() {
    local text
    text=$(fpaste)
    if [[ -n "$text" ]]; then
        LBUFFER+="$text"
    fi
    [[ -n "$WIDGET" ]] && zle reset-prompt
}
zle -N _fpaste-widget
bindkey '^[p' _fpaste-widget
bindkey '^X^P' _fpaste-widget

# -------------------------------------------------------------
# 12. Micro-TUI: faudio — Interactive PipeWire Per-App Sink Switcher
# -------------------------------------------------------------
# Route any running audio stream to any output device interactively.
# Usage: faudio
# Dependencies: wpctl (wireplumber) or pactl (pipewire-pulse), fzf
faudio() {
    if ! command -v wpctl &>/dev/null && ! command -v pactl &>/dev/null; then
        echo "faudio: requires wpctl (wireplumber) or pactl (pipewire-pulse)" >&2
        return 1
    fi
    if ! command -v fzf &>/dev/null; then
        echo "faudio: requires fzf" >&2
        return 1
    fi

    # Parse active sink inputs (streams): extract ID and application name
    local streams
    streams=$(wpctl status 2>/dev/null | awk '
        /Sink inputs:/{found=1; next}
        found && /^[[:space:]]*$/{found=0}
        found && /[0-9]+\./{match($0,/[0-9]+\./,m); id=substr(m[0],1,length(m[0])-1); rest=$0; sub(/.*[0-9]+\. /,"",rest); sub(/ \[.*/,"",rest); if(id!="") printf "%s\t%s\n",id,rest}
    ')

    if [[ -z "$streams" ]]; then
        echo "faudio: no active audio streams found (play some audio first)"
        return 0
    fi

    # Pick a stream via fzf
    local selected_stream
    selected_stream=$(echo "$streams" | column -t -s $'\t' | \
        fzf --header="faudio | Select audio stream to re-route | Ctrl-R: restart audio" \
            --bind="ctrl-r:execute-silent(systemctl --user restart wireplumber pipewire pipewire-pulse 2>/dev/null)" \
            --prompt="Stream > " \
            --height=40% --layout=reverse --border)
    [[ -z "$selected_stream" ]] && return

    local stream_id
    stream_id=$(echo "$selected_stream" | awk '{print $1}')

    # Parse available sinks (output devices)
    local sinks
    sinks=$(wpctl status 2>/dev/null | awk '
        /Sinks:/{found=1; next}
        found && /^[[:space:]]*$/{found=0}
        found && /[0-9]+\./{match($0,/[0-9]+\./,m); id=substr(m[0],1,length(m[0])-1); rest=$0; sub(/.*[0-9]+\. /,"",rest); sub(/ \[.*/,"",rest); if(id!="") printf "%s\t%s\n",id,rest}
    ')

    if [[ -z "$sinks" ]]; then
        echo "faudio: no output sinks available" >&2
        return 1
    fi

    # Pick a target sink
    local selected_sink
    selected_sink=$(echo "$sinks" | column -t -s $'\t' | \
        fzf --header="faudio | Select output device for stream $stream_id" \
            --prompt="Sink > " \
            --height=40% --layout=reverse --border)
    [[ -z "$selected_sink" ]] && return

    local sink_id
    sink_id=$(echo "$selected_sink" | awk '{print $1}')

    # Route stream → sink (wpctl preferred, pactl fallback)
    if wpctl move-sink-input "$stream_id" "$sink_id" 2>/dev/null; then
        echo "faudio: ✓ routed stream $stream_id → sink $sink_id"
    elif pactl move-sink-input "$stream_id" "$sink_id" 2>/dev/null; then
        echo "faudio: ✓ routed stream $stream_id → sink $sink_id (via pactl)"
    else
        echo "faudio: failed to route stream $stream_id → sink $sink_id" >&2
        return 1
    fi
}

# -------------------------------------------------------------
# 13. Micro-TUI: fserv — Systemd Service Manager TUI
# -------------------------------------------------------------
# Manage systemd user (or system) services interactively.
# Usage: fserv [--system]
# Keybinds: Enter: action menu | Ctrl-L: view logs | Ctrl-X: stop | Ctrl-/: preview
# Dependencies: systemctl, fzf; optional: gum, bat
fserv() {
    local scope="--user"
    local ctl_prefix=""
    local jctl_prefix=""
    if [[ "${1:-}" == "--system" ]]; then
        scope="--system"
        # Escalate for system mode: try sudo -n then run0
        if sudo -n true 2>/dev/null; then
            ctl_prefix="sudo -n"
            jctl_prefix="sudo -n"
        elif command -v run0 &>/dev/null; then
            ctl_prefix="run0"
            jctl_prefix="run0"
        fi
    fi

    if ! command -v fzf &>/dev/null; then
        echo "fserv: requires fzf" >&2
        return 1
    fi

    # Action picker — uses gum if available, else select builtin
    _fserv_pick_action() {
        if command -v gum &>/dev/null; then
            gum choose start stop restart enable disable status logs
        else
            local choice
            echo "Action:"
            select choice in start stop restart enable disable status logs; do
                [[ -n "$choice" ]] && echo "$choice" && break
            done
        fi
    }

    # Preview command for fzf
    local preview_cmd="SYSTEMD_COLORS=1 ${ctl_prefix} systemctl ${scope} status {} 2>&1 | head -40"

    local selected
    selected=$(${ctl_prefix} systemctl ${scope} list-units --type=service --all --no-legend 2>/dev/null | \
        awk '{print $1}' | grep -v '^$' | sort -u | \
        fzf --prompt="Service > " \
            --header="fserv | Enter: action | Ctrl-L: logs | Ctrl-X: stop | Ctrl-/: preview" \
            --header-first \
            --preview="$preview_cmd" \
            --preview-window="right:55%:wrap" \
            --bind="ctrl-/:toggle-preview" \
            --bind="ctrl-l:execute(${jctl_prefix} journalctl ${scope} -u {} -n 80 --no-pager 2>/dev/null | \${PAGER:-less})+abort" \
            --bind="ctrl-x:execute(echo 'Stopping {}...' && ${ctl_prefix} systemctl ${scope} stop {} 2>&1 | head -5)" \
            --height=60% --layout=reverse --border)

    [[ -z "$selected" ]] && return

    local action
    action=$(_fserv_pick_action)
    [[ -z "$action" ]] && return

    case "$action" in
        start)   ${ctl_prefix} systemctl ${scope} start   "$selected" ;;
        stop)    ${ctl_prefix} systemctl ${scope} stop    "$selected" ;;
        restart) ${ctl_prefix} systemctl ${scope} restart "$selected" ;;
        enable)  ${ctl_prefix} systemctl ${scope} enable --now "$selected" ;;
        disable) ${ctl_prefix} systemctl ${scope} disable --now "$selected" ;;
        status)  SYSTEMD_COLORS=1 ${ctl_prefix} systemctl ${scope} status "$selected" ;;
        logs)    ${jctl_prefix} journalctl ${scope} -u "$selected" -n 200 --no-pager | \
                     ${PAGER:-bat -l syslog --paging=never 2>/dev/null || less} ;;
    esac
}

# -------------------------------------------------------------
# 14. AI Workflow: explain — Shell Error Diagnostician (Alt+E)
# -------------------------------------------------------------
# After a command fails, press Alt+E to get an AI explanation + fix.
# Works with agy (Antigravity CLI); falls back to tldr/man hints.
# Dependencies: agy (optional), fzf
explain() {
    local cmd="${_last_command:-}"
    local code="${_last_exit_code:-0}"

    if [[ -z "$cmd" ]]; then
        echo "explain: no recent failed command tracked" >&2
        return 1
    fi

    printf '\n\033[1;33m🔍 Diagnosing:\033[0m \033[1m%s\033[0m (exit %s)\n\n' "$cmd" "$code"

    local first_word="${cmd%% *}"

    if command -v agy &>/dev/null; then
        local prompt="A shell command failed. Explain what went wrong in 2-3 sentences and provide the exact corrected command.

Command: $cmd
Exit code: $code

Be concise. Show the corrected command on its own line prefixed with \"Fix: \"."
        echo "$prompt" | agy chat --model flash --no-interactive 2>/dev/null || \
            echo "explain: agy call failed; try: tldr $first_word"
    else
        printf 'No AI diagnostician configured.\nTry:\n'
        printf '  • tldr %s\n' "$first_word"
        printf '  • man %s\n' "$first_word"
        printf '  • %s --help 2>&1 | head -30\n' "$first_word"
    fi
}

# ZLE widget: Alt+E invokes the error diagnostician
_explain-widget() {
    # Capture exit code before any ZLE processing changes it
    _last_exit_code=$?
    explain
    zle reset-prompt
}
zle -N _explain-widget
bindkey '^[e' _explain-widget

# Track last exit code in precmd for explain (complements _notify_precmd)
_track_exit_precmd() {
    _last_exit_code=$?
}
add-zsh-hook precmd _track_exit_precmd

# -------------------------------------------------------------
# 15. AI Workflow: gcai — AI Semantic Git Commit Generator
# -------------------------------------------------------------
# Generates a Conventional Commits message from staged diff via agy.
# Usage: gcai [--amend]
# Dependencies: git, fzf, agy (preferred) or gum
gcai() {
    local amend_flag=""
    [[ "${1:-}" == "--amend" ]] && amend_flag="--amend"

    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo "gcai: not a git repository" >&2
        return 1
    fi

    local diff_stat
    diff_stat=$(git diff --cached --stat 2>/dev/null)
    if [[ -z "$diff_stat" ]]; then
        echo "gcai: nothing staged — run 'git add <files>' first" >&2
        return 1
    fi

    printf '📋 Staged changes:\n%s\n\n' "$diff_stat"

    # Cap diff at 300 lines to stay within token budget
    local diff_content
    diff_content=$(git diff --cached 2>/dev/null | head -300)

    local ai_prompt="Generate a single Conventional Commits message for the following git diff.
Format: <type>(<scope>): <description>
Types: feat|fix|docs|style|refactor|test|chore|ci|perf
Rules: imperative mood, max 72 chars, no period at end, no markdown, no backticks.
Return ONLY the commit message line — no explanation, no code block.

Diff:
$diff_content"

    local generated_msg=""

    if command -v agy &>/dev/null; then
        generated_msg=$(echo "$ai_prompt" | \
            agy chat --model flash --no-interactive 2>/dev/null | \
            grep -m1 -E '^(feat|fix|docs|style|refactor|test|chore|ci|perf)(\(.+\))?:' | \
            head -1 | tr -d '\r`')
    elif command -v ollama &>/dev/null; then
        generated_msg=$(echo "$ai_prompt" | ollama run llama3.2:3b 2>/dev/null | \
            grep -m1 -E '^(feat|fix|docs|style|refactor|test|chore|ci|perf)(\(.+\))?:' | \
            head -1 | tr -d '\r`')
    fi

    # Fallback: prompt user manually
    if [[ -z "$generated_msg" ]]; then
        echo "gcai: AI unavailable or no Conventional Commit found — enter message manually:"
        if command -v gum &>/dev/null; then
            generated_msg=$(gum input --placeholder "feat(scope): description")
        else
            read -r "generated_msg?Commit message: "
        fi
    fi

    [[ -z "$generated_msg" ]] && { echo "gcai: aborted (empty message)"; return 1; }

    # Review in fzf — user can type to edit inline
    local final_msg
    final_msg=$(printf '%s' "$generated_msg" | \
        fzf --print-query \
            --header="Review | Enter: commit as-is | Type to edit | Ctrl-C: abort" \
            --height=10 --layout=reverse --border \
            --query="$generated_msg" | tail -1)

    [[ -z "$final_msg" ]] && { echo "gcai: commit aborted"; return 1; }

    git commit $amend_flag -m "$final_msg" && printf '\n✓ Committed: %s\n' "$final_msg"
}

# -------------------------------------------------------------
# 16. Micro-TUI: fpr — Interactive Git Branch & PR Manager
# -------------------------------------------------------------
# List branches with log preview; checkout, merge, delete, push+PR, rebase.
# Usage: fpr
# Keybinds: Enter: checkout | Ctrl-M: merge | Ctrl-D: delete | Ctrl-P: push+PR | Ctrl-R: rebase
# Dependencies: git, fzf; optional: gh (GitHub CLI)
fpr() {
    if ! git rev-parse --git-dir &>/dev/null 2>&1; then
        echo "fpr: not a git repository" >&2
        return 1
    fi

    local all_branches
    all_branches=$(git branch -a \
        --format='%(refname:short)|%(ahead-behind:HEAD)|%(subject)' 2>/dev/null | \
        awk -F'|' '{
            name=$1; diverge=$2; desc=substr($3,1,50)
            printf "%-42s  %-12s  %s\n", name, diverge, desc
        }')

    if [[ -z "$all_branches" ]]; then
        echo "fpr: no branches found"
        return 0
    fi

    local output key selected
    output=$(echo "$all_branches" | \
        fzf --header="fpr | Enter: checkout | Ctrl-M: merge | Ctrl-D: delete | Ctrl-P: push+PR | Ctrl-R: rebase" \
            --header-first \
            --expect=ctrl-m,ctrl-d,ctrl-p,ctrl-r \
            --preview='git log --oneline --graph --color --decorate -15 {1} 2>/dev/null' \
            --preview-window="right:55%:wrap" \
            --bind="ctrl-/:toggle-preview" \
            --height=60% --layout=reverse --border)

    [[ -z "$output" ]] && return

    key=$(echo "$output" | head -1)
    selected=$(echo "$output" | tail -1 | awk '{print $1}')
    [[ -z "$selected" ]] && return

    # Strip remote prefix for local branch name
    local local_branch="${selected#remotes/*/}"
    local_branch="${local_branch#origin/}"

    case "$key" in
        ctrl-m)
            git merge "$selected" && echo "fpr: ✓ merged $selected into $(git branch --show-current)" ;;
        ctrl-d)
            git branch -d "$local_branch" 2>/dev/null || git branch -D "$local_branch"
            echo "fpr: ✓ deleted branch $local_branch" ;;
        ctrl-p)
            local current_branch; current_branch=$(git branch --show-current)
            git push -u origin "$current_branch" 2>&1
            if command -v gh &>/dev/null; then
                gh pr create --web 2>/dev/null
            else
                local remote_url; remote_url=$(git remote get-url origin 2>/dev/null)
                local pr_url=""
                if echo "$remote_url" | grep -q "github.com"; then
                    local repo; repo=$(echo "$remote_url" | sed 's|.*github.com[:/]||;s|\.git$||')
                    pr_url="https://github.com/$repo/compare/${current_branch}?expand=1"
                elif echo "$remote_url" | grep -q "gitlab.com"; then
                    local repo; repo=$(echo "$remote_url" | sed 's|.*gitlab.com[:/]||;s|\.git$||')
                    pr_url="https://gitlab.com/$repo/-/merge_requests/new?merge_request[source_branch]=${current_branch}"
                fi
                [[ -n "$pr_url" ]] && xdg-open "$pr_url" 2>/dev/null && echo "fpr: ✓ opened PR URL"
            fi ;;
        ctrl-r)
            git rebase "$selected" && echo "fpr: ✓ rebased onto $selected" ;;
        *)
            git checkout "$local_branch" 2>/dev/null || \
                git checkout -b "$local_branch" --track "$selected" 2>/dev/null
            echo "fpr: ✓ switched to $local_branch" ;;
    esac
}

# -------------------------------------------------------------
# 17. Workspace Session Snapshot & Restore (wsave / wrestore)
# -------------------------------------------------------------
# Snapshot current Hyprland window layout; restore it later.
# Usage: wsave [name]   wsave default
#        wrestore [name]
# Dependencies: hyprctl, jq
# Launcher config: ~/.config/omarchy/session-launchers.json
wsave() {
    local name="${1:-default}"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/sessions"
    mkdir -p "$state_dir"

    if ! command -v hyprctl &>/dev/null; then
        echo "wsave: hyprctl required (run inside a Hyprland session)" >&2
        return 1
    fi
    if ! command -v jq &>/dev/null; then
        echo "wsave: jq required" >&2
        return 1
    fi

    local outfile="$state_dir/${name}.json"
    hyprctl clients -j 2>/dev/null | \
        jq '[.[] | {class, title: (.title | .[0:60]), workspace: .workspace.name, at, size}]' \
        > "$outfile"

    local count; count=$(jq 'length' "$outfile" 2>/dev/null || echo 0)
    echo "wsave: ✓ saved $count windows to $outfile"
}

wrestore() {
    local name="${1:-default}"
    local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/sessions"
    local session_file="$state_dir/${name}.json"
    local launchers_file="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/session-launchers.json"

    if [[ ! -f "$session_file" ]]; then
        echo "wrestore: session '$name' not found (run wsave first)" >&2
        return 1
    fi
    if ! command -v hyprctl &>/dev/null; then
        echo "wrestore: hyprctl required" >&2; return 1
    fi
    if ! command -v jq &>/dev/null; then
        echo "wrestore: jq required" >&2; return 1
    fi

    local count=0
    while IFS= read -r entry; do
        local class ws launch_cmd
        class=$(echo "$entry" | jq -r '.class')
        ws=$(echo "$entry" | jq -r '.workspace')

        # Look up a custom launch command for this window class
        if [[ -f "$launchers_file" ]]; then
            launch_cmd=$(jq -r --arg c "$class" '.[$c] // empty' "$launchers_file" 2>/dev/null)
        fi
        [[ -z "$launch_cmd" ]] && launch_cmd="$class"

        hyprctl dispatch exec "[workspace $ws silent] $launch_cmd" 2>/dev/null && (( count++ )) || true
        sleep 0.3
    done < <(jq -c '.[]' "$session_file" 2>/dev/null)

    echo "wrestore: ✓ launched $count windows from session '$name'"
}

# -------------------------------------------------------------
# 18. Hardware: panel-health — OLED Pixel Burn-in Risk Reporter
# -------------------------------------------------------------
# Reports how long the current workspace has been static (burn-in risk).
# Usage: panel-health
# Requires hyprd daemon (Feature 2) to be running for workspace log.
panel-health() {
    local log="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/workspace.log"

    if [[ ! -f "$log" ]]; then
        echo "panel-health: no workspace log found"
        echo "  → Start the hyprd daemon: systemctl --user start hyprd" >&2
        return 1
    fi

    local last_entry last_ts last_ws switches
    last_entry=$(tail -1 "$log" 2>/dev/null)
    last_ts=$(echo "$last_entry" | awk '{print $1}')
    last_ws=$(echo "$last_entry" | awk '{print $3}')
    switches=$(wc -l < "$log" 2>/dev/null || echo 0)

    local now; now=$(date +%s)
    local age=$(( now - ${last_ts:-now} ))
    local age_min=$(( age / 60 ))
    local age_sec=$(( age % 60 ))

    local risk="Low 🟢"
    (( age > 3600 ))  && risk="Medium 🟡 — Consider switching workspace"
    (( age > 7200 ))  && risk="High 🔴 — Switch workspace or take a break"

    printf '\n📺 Panel Health Report\n'
    printf '  Current workspace : %s\n' "${last_ws:-unknown}"
    printf '  Static for        : %dm %ds\n' "$age_min" "$age_sec"
    printf '  Workspace switches: %s (session total)\n' "$switches"
    printf '  Burn-in risk      : %s\n\n' "$risk"
}
