#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${ROOT}/bin/lib/release.sh"

workdir="$(mktemp -d)"
trap 'rm -rf -- "$workdir"' EXIT

git -C "$workdir" init -q --initial-branch=master
git -C "$workdir" config user.email release-test@example.com
git -C "$workdir" config user.name release-test

commit() {
    printf '%s\n' "$1" > "${workdir}/message"
    git -C "${workdir}" add message
    git -C "${workdir}" commit -qm "$1"
}

commit 'chore: initial release'
git -C "${workdir}" tag v0.5.0
commit 'feat: add the next release'

automatic_tag="$(cd "${workdir}" && release_create_tag)"
[[ "${automatic_tag}" == 'v0.6.0' ]]
[[ "$(git -C "${workdir}" tag --points-at HEAD)" == 'v0.6.0' ]]
release_version_is_greater_than_tag 2.0.0 v2.0.0-beta

explicit_tag="$(cd "${workdir}" && "${ROOT}/bin/tag-release" --release-as 2.0.0)"
[[ "${explicit_tag}" == 'v2.0.0' ]]
[[ "$(git -C "${workdir}" tag --points-at HEAD | sort)" == $'v0.6.0\nv2.0.0' ]]

before_tags="$(git -C "${workdir}" tag --list)"
if (cd "${workdir}" && release_create_tag_as 2.0.0); then
    echo 'equal release version was accepted' >&2
    exit 1
fi
if (cd "${workdir}" && release_create_tag_as 1.9.9); then
    echo 'lower release version was accepted' >&2
    exit 1
fi
after_tags="$(git -C "${workdir}" tag --list)"
[[ "${before_tags}" == "${after_tags}" ]]

printf 'release helper tests passed\n'
