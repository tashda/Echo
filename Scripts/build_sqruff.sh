#!/bin/bash
# Builds or downloads a universal sqruff binary and stages it in the app bundle.
# Cache location: ${PROJECT_DIR}/BuildTools/sqruff
set -euo pipefail

if [[ -d "${HOME}/.cargo/bin" ]]; then
  export PATH="${HOME}/.cargo/bin:${PATH}"
fi

if ! command -v rustup >/dev/null 2>&1; then
  echo "[sqruff] rustup is required to build sqruff from source" >&2
  exit 1
fi

SQRUFF_VERSION="0.13.0"
CACHE_ROOT="${DERIVED_DATA_DIR:-${TMPDIR}}/sqruff-cache"
CACHE_DIR="${CACHE_ROOT}/${SQRUFF_VERSION}"
UNIVERSAL_BINARY="${CACHE_DIR}/sqruff-universal"

mkdir -p "${CACHE_DIR}"

# Helper to download prebuilt release if available
fetch_release() {
  local url="https://github.com/quarylabs/sqruff/releases/download/v${SQRUFF_VERSION}/sqruff-v${SQRUFF_VERSION}-x86_64-apple-darwin.tar.gz"
  local archive="${CACHE_DIR}/sqruff-x86_64.tar.gz"
  if curl --fail --location --output "${archive}" "${url}" 2>/dev/null; then
    tar -xf "${archive}" -C "${CACHE_DIR}" sqruff
    mv "${CACHE_DIR}/sqruff" "${CACHE_DIR}/sqruff-x86_64"
    rm "${archive}"
    return 0
  fi
  return 1
}

if [[ ! -f "${UNIVERSAL_BINARY}" ]]; then
  echo "[sqruff] building universal binary v${SQRUFF_VERSION}"
  rm -f "${CACHE_DIR}/sqruff-aarch64" "${CACHE_DIR}/sqruff-x86_64"

  if ! fetch_release; then
    echo "[sqruff] downloading source…"
    SRC_DIR="${CACHE_DIR}/src"
    if [[ -d "${SRC_DIR}" ]]; then
      git -C "${SRC_DIR}" fetch --depth=1 origin "v${SQRUFF_VERSION}"
      git -C "${SRC_DIR}" checkout "v${SQRUFF_VERSION}"
    else
      git clone --depth=1 --branch "v${SQRUFF_VERSION}" https://github.com/quarylabs/sqruff "${SRC_DIR}"
    fi

    TOOLCHAIN=""
    if [[ -f "${SRC_DIR}/rust-toolchain.toml" ]]; then
      TOOLCHAIN=$(awk -F '"' '/^channel[[:space:]]*=/{print $2; exit}' "${SRC_DIR}/rust-toolchain.toml")
    elif [[ -f "${SRC_DIR}/rust-toolchain" ]]; then
      TOOLCHAIN=$(sed -n '1p' "${SRC_DIR}/rust-toolchain")
    fi

    if [[ -z "${TOOLCHAIN}" ]]; then
      TOOLCHAIN="stable"
    fi

    echo "[sqruff] using Rust toolchain ${TOOLCHAIN}"
    rustup toolchain install "${TOOLCHAIN}" >/dev/null
    rustup target add --toolchain "${TOOLCHAIN}" aarch64-apple-darwin x86_64-apple-darwin >/dev/null

    cargo "+${TOOLCHAIN}" build --release --target aarch64-apple-darwin --manifest-path "${SRC_DIR}/Cargo.toml"
    cargo "+${TOOLCHAIN}" build --release --target x86_64-apple-darwin --manifest-path "${SRC_DIR}/Cargo.toml"

    cp "${SRC_DIR}/target/aarch64-apple-darwin/release/sqruff" "${CACHE_DIR}/sqruff-aarch64"
    cp "${SRC_DIR}/target/x86_64-apple-darwin/release/sqruff" "${CACHE_DIR}/sqruff-x86_64"
  fi

  if [[ ! -f "${CACHE_DIR}/sqruff-aarch64" ]]; then
    echo "[sqruff] missing arm64 build" >&2
    exit 1
  fi
  if [[ ! -f "${CACHE_DIR}/sqruff-x86_64" ]]; then
    echo "[sqruff] missing x86_64 build" >&2
    exit 1
  fi

  lipo -create "${CACHE_DIR}/sqruff-aarch64" "${CACHE_DIR}/sqruff-x86_64" -output "${UNIVERSAL_BINARY}"
  chmod +x "${UNIVERSAL_BINARY}"
fi

OUTPUT_DEST="${SCRIPT_OUTPUT_FILE_0:-}"
if [[ -z "${OUTPUT_DEST}" && -n "${BUILT_PRODUCTS_DIR:-}" && -n "${UNLOCALIZED_RESOURCES_FOLDER_PATH:-}" ]]; then
  OUTPUT_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/sqruff"
fi

if [[ -n "${OUTPUT_DEST}" ]]; then
  DEST_PATH="${OUTPUT_DEST}"
else
  PROJECT_ROOT="${PROJECT_DIR:-${PWD}}"
  DEST_PATH="${PROJECT_ROOT}/BuildTools/sqruff/sqruff"
  echo "[sqruff] no bundle staging variables provided; defaulting to ${DEST_PATH}"
fi

mkdir -p "$(dirname "${DEST_PATH}")"
cp "${UNIVERSAL_BINARY}" "${DEST_PATH}"
chmod +x "${DEST_PATH}"

CONFIG_SOURCE="${PROJECT_DIR:-${PWD}}/BuildTools/sqruff/.sqruff"
if [[ -f "${CONFIG_SOURCE}" ]]; then
  DEST_CONFIG="$(dirname "${DEST_PATH}")/.sqruff"
  if [[ "${CONFIG_SOURCE}" != "${DEST_CONFIG}" ]]; then
    cp "${CONFIG_SOURCE}" "${DEST_CONFIG}"
  fi
fi

echo "[sqruff] staged formatter at ${DEST_PATH}"
