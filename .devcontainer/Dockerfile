# Flutter dev container for AekiAppi
#
# Cirrus Labs Flutter images are being sunset, so this image is fully
# self-contained: Ubuntu base + Flutter SDK + Android cmdline-tools.

FROM ubuntu:24.04

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=${USER_UID}

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV FLUTTER_ROOT=/opt/flutter-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk-linux
ENV ANDROID_HOME=/opt/android-sdk-linux
ENV PATH=${FLUTTER_ROOT}/bin:${FLUTTER_ROOT}/bin/cache/dart-sdk/bin:${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin:${ANDROID_SDK_ROOT}/platform-tools:${PATH}

# Install system dependencies and create non-root user with sudo access.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        sudo \
        ca-certificates \
        curl \
        git \
        unzip \
        xz-utils \
        zip \
        file \
        locales \
        adb \
        openjdk-17-jdk \
        chromium \
        clang \
        cmake \
        ninja-build \
        libgtk-3-dev \
        pkg-config \
        mesa-utils \
        zsh \
        neofetch \
        fonts-powerline \
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
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Install Android command-line tools (sdkmanager).
RUN mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools" \
    && curl -fsSL https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -o /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d /tmp \
    && mkdir -p "${ANDROID_SDK_ROOT}/cmdline-tools/latest" \
    && mv /tmp/cmdline-tools/* "${ANDROID_SDK_ROOT}/cmdline-tools/latest/" \
    && rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip

# Install a clean official Flutter SDK.
RUN rm -rf "${FLUTTER_ROOT}" \
    && git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "${FLUTTER_ROOT}"

# Make Flutter/Android SDKs writable by the non-root user.
RUN for dir in /sdks/flutter /home/flutter /opt/flutter /opt/android-sdk-linux /opt/android-sdk "${FLUTTER_ROOT}"; do \
    [ -d "$dir" ] && chown -R "${USERNAME}:$(id -gn "${USERNAME}")" "$dir" || true; \
    done

USER ${USERNAME}

# Install Oh My Zsh with Powerlevel10k theme and useful plugins.
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
            "${HOME}/.oh-my-zsh/custom/plugins/fzf-tab" \
        && cp "${HOME}/.oh-my-zsh/custom/themes/powerlevel10k/config/p10k-rainbow.zsh" "${HOME}/.p10k.zsh"

# Configure shell defaults.
RUN sed -i \
        -e 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' \
        -e 's|^plugins=.*|plugins=(sudo git docker flutter zsh-autosuggestions zsh-syntax-highlighting zsh-completions)|' \
        "${HOME}/.zshrc" \
    && grep -q '\[\[ ! -f ~/.p10k.zsh \]\] || source ~/.p10k.zsh' "${HOME}/.zshrc" \
       || printf '\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n' >> "${HOME}/.zshrc" \
    && printf '\n# Show system info on new shell\nneofetch\n' >> "${HOME}/.zshrc" \
    && sudo chsh -s /usr/bin/zsh "${USERNAME}"

# Enable desktop/web and pre-warm Flutter artifacts.
RUN flutter config --enable-web --enable-linux-desktop
RUN flutter precache --android --web --linux
