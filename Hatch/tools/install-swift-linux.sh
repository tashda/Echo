#!/usr/bin/env bash
# Installs the Swift 6.1 toolchain for Linux x86_64 in a restricted cloud container.
# download.swift.org is blocked there, but Docker Hub is reachable, so this unpacks the official
# `swift:6.1-noble` image layers by hand into /opt/swiftroot. After it runs:
#   export PATH=/opt/swiftroot/usr/bin:$PATH
# It only builds non-UI Swift (Foundation, SQLite). SwiftUI and AppKit exist on macOS only.
set -euo pipefail
ROOT=/opt/swiftroot; TMP=$(mktemp -d)
mkdir -p "$ROOT"
python3 - "$ROOT" "$TMP" <<'PY'
import json, subprocess, sys
root, tmp = sys.argv[1], sys.argv[2]
def sh(c): return subprocess.run(c, shell=True, capture_output=True, text=True)
tok = json.loads(sh('curl -s -m 30 "https://auth.docker.io/token?service=registry.docker.io&scope=repository:library/swift:pull"').stdout)['token']
H = f'-H "Authorization: Bearer {tok}"'
idx = json.loads(sh(f'curl -s -m 30 {H} -H "Accept: application/vnd.oci.image.index.v1+json" https://registry-1.docker.io/v2/library/swift/manifests/6.1-noble').stdout)
dg = [m['digest'] for m in idx['manifests'] if m.get('platform', {}).get('architecture') == 'amd64' and m['platform'].get('os') == 'linux'][0]
man = json.loads(sh(f'curl -s -m 30 {H} -H "Accept: application/vnd.oci.image.manifest.v1+json" https://registry-1.docker.io/v2/library/swift/manifests/{dg}').stdout)
for i, l in enumerate(man['layers']):
    f = f'{tmp}/layer{i}.tgz'
    r = sh(f'curl -s -L -m 900 {H} -o {f} -w "%{{http_code}}" https://registry-1.docker.io/v2/library/swift/blobs/{l["digest"]}')
    if r.stdout.strip() != '200': sys.exit('layer download failed')
    sh(f'tar -xzf {f} -C {root} --exclude="dev/*"; rm -f {f}')
PY
apt-get update -qq
apt-get install -y -qq binutils gcc libc6-dev libcurl4-openssl-dev libedit2 libgcc-13-dev libpython3-dev \
  libsqlite3-dev libstdc++-13-dev libxml2-dev libncurses-dev pkg-config tzdata zlib1g-dev unzip git
echo "Swift installed. Run: export PATH=$ROOT/usr/bin:\$PATH"
