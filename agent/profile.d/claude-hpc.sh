# Claude HPC shell configuration
# Loaded via /etc/profile.d/ for all users

# Colorful prompt — red for root, green for others
if [ "$(id -u)" -eq 0 ]; then
    PS1='\[\e[01;31m\]claude-hpc\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\] \[\e[90m\]$(date +%H:%M:%S)\[\e[00m\] # '
else
    PS1='\[\e[01;32m\]\u@claude-hpc\[\e[00m\]:\[\e[01;34m\]\w\[\e[00m\] \[\e[90m\]$(date +%H:%M:%S)\[\e[00m\] $ '
fi

# Color support
if [ -x /usr/bin/dircolors ]; then
    eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

# fzf key bindings and completion
[ -f /opt/fzf/shell/key-bindings.bash ] && source /opt/fzf/shell/key-bindings.bash
[ -f /opt/fzf/shell/completion.bash ] && source /opt/fzf/shell/completion.bash
