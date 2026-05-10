#!/usr/bin/env bash
set -euo pipefail

cd /workspace/aeki_appi

P10K_REPO_CONFIG="/workspace/aeki_appi/.devcontainer/p10k.zsh"
P10K_HOME_CONFIG="$HOME/.p10k.zsh"

# Keep prompt config persistent across rebuilds.
if [[ -s "${P10K_REPO_CONFIG}" ]]; then
  cp "${P10K_REPO_CONFIG}" "${P10K_HOME_CONFIG}"
elif [[ -s "${P10K_HOME_CONFIG}" ]]; then
  cp "${P10K_HOME_CONFIG}" "${P10K_REPO_CONFIG}"
fi

if [[ -f "$HOME/.zshrc" ]] \
  && ! grep -q '\[\[ ! -f ~/.p10k.zsh \]\] || source ~/.p10k.zsh' "$HOME/.zshrc"; then
  printf '\n[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh\n' >> "$HOME/.zshrc"
fi

find_android_sdk_root() {
  local candidates=(
    "${ANDROID_SDK_ROOT:-}"
    "${ANDROID_HOME:-}"
    "/opt/android-sdk"
    "/opt/android-sdk-linux"
    "/usr/local/android-sdk"
    "/usr/lib/android-sdk"
    "$HOME/Android/Sdk"
  )

  local path
  for path in "${candidates[@]}"; do
    if [[ -n "${path}" && -d "${path}" ]]; then
      printf '%s\n' "${path}"
      return 0
    fi
  done

  return 1
}

ANDROID_SDK_ROOT="$(find_android_sdk_root)"
export ANDROID_SDK_ROOT
export ANDROID_HOME="${ANDROID_SDK_ROOT}"
export PATH="/usr/lib/android-sdk/platform-tools:${ANDROID_SDK_ROOT}/platform-tools:${PATH}"

# Ubuntu package installs Chromium as chromium-browser; provide chromium alias
# so Flutter web tooling can discover it via CHROME_EXECUTABLE defaults.
if [[ -x /usr/bin/chromium-browser && ! -e /usr/bin/chromium ]]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn /usr/bin/chromium-browser /usr/bin/chromium || true
  else
    ln -sfn /usr/bin/chromium-browser /usr/bin/chromium || true
  fi
fi

# Some images install cmdline-tools under latest-2; normalize to latest
# to prevent sdkmanager warning spam.
if [[ ! -e "${ANDROID_SDK_ROOT}/cmdline-tools/latest" && -d "${ANDROID_SDK_ROOT}/cmdline-tools/latest-2" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo ln -sfn "${ANDROID_SDK_ROOT}/cmdline-tools/latest-2" "${ANDROID_SDK_ROOT}/cmdline-tools/latest" || true
  else
    ln -sfn "${ANDROID_SDK_ROOT}/cmdline-tools/latest-2" "${ANDROID_SDK_ROOT}/cmdline-tools/latest" || true
  fi
fi

find_sdkmanager() {
  local candidates=(
    "$(command -v sdkmanager || true)"
    "${ANDROID_SDK_ROOT}/cmdline-tools/latest/bin/sdkmanager"
    "${ANDROID_SDK_ROOT}/cmdline-tools/latest-2/bin/sdkmanager"
    "${ANDROID_SDK_ROOT}/tools/bin/sdkmanager"
  )

  local tool
  for tool in "${candidates[@]}"; do
    if [[ -n "${tool}" && -x "${tool}" ]]; then
      printf '%s\n' "${tool}"
      return 0
    fi
  done

  return 1
}

SDKMANAGER="$(find_sdkmanager)"

COMPILE_SDK="$(grep -Eo 'compileSdk\s*=\s*[0-9]+' android/app/build.gradle.kts | head -n1 | grep -Eo '[0-9]+')"
TARGET_SDK="$(grep -Eo 'targetSdk\s*=\s*[0-9]+' android/app/build.gradle.kts | head -n1 | grep -Eo '[0-9]+')"

if [[ -z "${COMPILE_SDK}" ]]; then
  echo "Unable to detect compileSdk from android/app/build.gradle.kts"
  exit 1
fi

if [[ -z "${TARGET_SDK}" ]]; then
  TARGET_SDK="${COMPILE_SDK}"
fi

echo "Using Android SDK at: ${ANDROID_SDK_ROOT}"
echo "Ensuring Android packages for compileSdk=${COMPILE_SDK}, targetSdk=${TARGET_SDK}"

PRIMARY_BUILD_TOOLS="${COMPILE_SDK}.0.0"

find_native_adb() {
  local candidates=(
    "/usr/lib/android-sdk/platform-tools/adb"
    "/usr/bin/adb"
  )

  local bin
  for bin in "${candidates[@]}"; do
    if [[ -x "${bin}" ]] && "${bin}" version >/dev/null 2>&1; then
      printf '%s\n' "${bin}"
      return 0
    fi
  done

  return 1
}

SYSTEM_ADB="$(find_native_adb || true)"

# sdkmanager may close stdin early after all licenses are accepted.
# With pipefail enabled, that can surface as exit 141 from `yes`.
set +o pipefail
yes | "${SDKMANAGER}" --licenses >/dev/null
set -o pipefail

# Normalize SDK layout if a previous run installed platform-tools into -2.
if [[ -d "${ANDROID_SDK_ROOT}/platform-tools-2" ]] && [[ ! -f "${ANDROID_SDK_ROOT}/platform-tools/source.properties" ]]; then
  if command -v sudo >/dev/null 2>&1; then
    sudo rm -rf "${ANDROID_SDK_ROOT}/platform-tools"
    sudo mv "${ANDROID_SDK_ROOT}/platform-tools-2" "${ANDROID_SDK_ROOT}/platform-tools"
  else
    rm -rf "${ANDROID_SDK_ROOT}/platform-tools"
    mv "${ANDROID_SDK_ROOT}/platform-tools-2" "${ANDROID_SDK_ROOT}/platform-tools"
  fi
fi

"${SDKMANAGER}" \
  "platform-tools" \
  "build-tools;${PRIMARY_BUILD_TOOLS}" \
  "platforms;android-${COMPILE_SDK}" \
  "platforms;android-${TARGET_SDK}" || {
    echo "Falling back to build-tools;35.0.0"
    "${SDKMANAGER}" \
      "build-tools;35.0.0" \
      "platforms;android-${COMPILE_SDK}" \
      "platforms;android-${TARGET_SDK}" || true
    echo "Warning: Unable to install one or more requested Android SDK packages."
    echo "You may need to adjust compileSdk/targetSdk or install packages manually with sdkmanager."
  }

# The Android SDK from upstream images may provide x86_64 adb, which does not
# run in an arm64 container. If that happens, wire SDK adb to the native one.
SDK_ADB="${ANDROID_SDK_ROOT}/platform-tools/adb"
if [[ -n "${SYSTEM_ADB}" ]]; then
  if [[ -d "${ANDROID_SDK_ROOT}/platform-tools" ]] && ([[ ! -x "${SDK_ADB}" ]] || ! "${SDK_ADB}" version >/dev/null 2>&1); then
    echo "Replacing incompatible SDK adb with native system adb at ${SYSTEM_ADB}"
    if command -v sudo >/dev/null 2>&1; then
      sudo ln -sfn "${SYSTEM_ADB}" "${SDK_ADB}"
    else
      ln -sfn "${SYSTEM_ADB}" "${SDK_ADB}"
    fi
  fi
fi

flutter --version
if ! flutter doctor -v; then
  echo "Warning: flutter doctor reported issues; continuing setup."
fi
flutter pub get
