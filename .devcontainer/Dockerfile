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

# Install Linux desktop build dependencies for Flutter desktop development.
# These are needed for the `flutter build linux --release` target.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        clang \
        cmake \
        ninja-build \
        libgtk-3-dev \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Make the Flutter SDK writable by the new user (path may vary by image version).
RUN for dir in /sdks/flutter /home/flutter /opt/flutter; do \
    [ -d "$dir" ] && chown -R "${USERNAME}:$(id -gn "${USERNAME}")" "$dir" || true; \
    done

USER ${USERNAME}

# Enable Web and Linux platforms, then pre-warm the Flutter tool so the first
# `flutter` command inside the container is fast.
RUN flutter config --enable-web --enable-linux-desktop
RUN flutter precache --android --universal --web --linux
