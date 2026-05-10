# Flutter dev container for AekiAppi
#
# Based on the official Cirrus Labs Flutter image which ships with:
#   - Flutter SDK (stable channel)
#   - Dart SDK
#   - Android SDK + command-line tools
#   - Git, curl, unzip and other common utilities
#
# A non-root "vscode" user is added so the VS Code Dev Container extension can
# set up the workspace safely.

FROM ghcr.io/cirruslabs/flutter:stable

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

# Create a non-root user and grant passwordless sudo so flutter doctor
# can install additional components without prompting.
RUN apt-get update \
    && apt-get install -y --no-install-recommends sudo \
    && if ! getent group "${USER_GID}" >/dev/null; then groupadd --gid "${USER_GID}" "${USERNAME}"; fi \
    && if ! id -u "${USERNAME}" >/dev/null 2>&1; then \
        if getent passwd "${USER_UID}" >/dev/null; then \
            useradd --gid "${USER_GID}" -m "${USERNAME}"; \
        else \
            useradd --uid "${USER_UID}" --gid "${USER_GID}" -m "${USERNAME}"; \
        fi; \
    fi \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/"${USERNAME}" \
    && chmod 0440 /etc/sudoers.d/"${USERNAME}" \
    && rm -rf /var/lib/apt/lists/*

# Install Linux desktop build dependencies, zsh shell tooling, and utilities.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        adb \
        openjdk-17-jdk \
        chromium \
        clang \
        cmake \
        ninja-build \
        libgtk-3-dev \
        pkg-config \
        zsh \
        neofetch \
        fonts-powerline \
    && rm -rf /var/lib/apt/lists/*

# Make the Flutter SDK and Android SDK writable by the new user.
RUN for dir in /sdks/flutter /home/flutter /opt/flutter /opt/android-sdk-linux /opt/android-sdk; do \
    [ -d "$dir" ] && chown -R "${USERNAME}:$(id -gn "${USERNAME}")" "$dir" || true; \
    done

USER ${USERNAME}

# Install Oh My Zsh with Powerlevel10k theme and popular plugins.
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
           "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
           "${HOME}/.oh-my-zsh/custom/plugins/zsh-autosuggestions" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
           "${HOME}/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting" \
    && git clone --depth=1 https://github.com/zsh-users/zsh-completions \
           "${HOME}/.oh-my-zsh/custom/plugins/zsh-completions" \
    && git clone --depth=1 https://github.com/Aloxaf/fzf-tab \
           "${HOME}/.oh-my-zsh/custom/plugins/fzf-tab"

# Configure .zshrc: set theme, plugins, and show neofetch on login.
RUN sed -i \
        -e 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' \
        -e 's|^plugins=.*|plugins=(sudo git docker flutter zsh-autosuggestions zsh-syntax-highlighting zsh-completions)|' \
        "${HOME}/.zshrc" \
    && printf '\n# Show system info on new shell\nneofetch\n' >> "${HOME}/.zshrc" \
    && sudo chsh -s /usr/bin/zsh "${USERNAME}"

# Enable Web and Linux platforms, then pre-warm the Flutter tool. Avoid
# `--universal` to prevent downloading artifacts for extra architectures.
RUN flutter config --enable-web --enable-linux-desktop
RUN flutter precache --android --web --linux
