FROM continuumio/miniconda3:latest

ARG TZ=America/Los_Angeles
ENV TZ="$TZ"

# Create researcher user (used in local Docker mode)
ARG USERNAME=researcher
RUN useradd -m -s /bin/bash $USERNAME && \
    mkdir -p /etc/sudoers.d

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    less git procps sudo man-db unzip gnupg2 gh \
    iptables ipset iproute2 dnsutils aggregate \
    jq nano vim curl wget ca-certificates \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# fzf
RUN git clone --depth 1 https://github.com/junegunn/fzf.git /opt/fzf && \
    /opt/fzf/install --bin && \
    ln -sf /opt/fzf/bin/fzf /usr/local/bin/fzf

# git-delta
ARG GIT_DELTA_VERSION=0.18.2
RUN ARCH=$(dpkg --print-architecture) && \
    wget -q "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
    rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Claude Code — install globally so it works for any user
RUN curl -fsSL https://claude.ai/install.sh | bash && \
    cp /root/.local/bin/claude /usr/local/bin/claude && \
    chmod 755 /usr/local/bin/claude

# Shell configuration — loaded for all users (root, researcher, or mapped HPC user)
COPY agent/profile.d/claude-hpc.sh /etc/profile.d/claude-hpc.sh

# Domain whitelist (single source of truth for iptables + Squid)
COPY shared/allowed-domains.conf /etc/claude-hpc/allowed-domains.conf

# Firewall + entrypoint
COPY agent/init-firewall.sh agent/entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/entrypoint.sh && \
    echo "$USERNAME ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/$USERNAME-firewall && \
    chmod 0440 /etc/sudoers.d/$USERNAME-firewall

# Workspace
RUN mkdir -p /workspace && chown $USERNAME:$USERNAME /workspace && chmod 755 /workspace
WORKDIR /workspace

# Persist Claude config across container restarts via workspace volume.
# Symlinks are created at shell start to support potentially missing ENTRYPOINT machinery.
RUN echo '[ -d /workspace ] && mkdir -p /workspace/._claude && ln -sfn /workspace/._claude "$HOME/.claude" && ln -sfn /workspace/._claude.json "$HOME/.claude.json"' \
    >> /home/$USERNAME/.bashrc

# Default to researcher for local Docker; podman-hpc overrides with --user root
USER $USERNAME

ENV SHELL=/bin/bash
ENV EDITOR=nano
ENV VISUAL=nano

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash", "--login"]
