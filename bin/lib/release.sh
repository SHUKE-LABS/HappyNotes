# Release helpers for release tags and changelog generation.

# Matches the generated form (vX.Y.Z) and the legacy -beta suffix, so scanning
# history for "latest" keeps recognizing pre-existing -beta tags even though
# we only ever produce the bare form going forward.
release_tag_regex() {
    printf '^v([0-9]+)\\.([0-9]+)\\.([0-9]+)(-beta)?$'
}


release_version_regex() {
    printf '^([0-9]+)\\.([0-9]+)\\.([0-9]+)$'
}


release_tags_desc() {
    local tag="" regex=""
    regex="$(release_tag_regex)"

    while IFS= read -r tag; do
        [[ "${tag}" =~ ${regex} ]] || continue
        printf '%s\n' "${tag}"
    done < <(git tag --list 'v*' --sort=-version:refname)
}


release_latest_tag() {
    local tag=""

    while IFS= read -r tag; do
        [[ -n "${tag}" ]] || continue
        printf '%s\n' "${tag}"
        return 0
    done < <(release_tags_desc)
}


release_head_tag() {
    local tag="" regex=""
    regex="$(release_tag_regex)"

    while IFS= read -r tag; do
        [[ "${tag}" =~ ${regex} ]] || continue
        printf '%s\n' "${tag}"
        return 0
    done < <(git tag --points-at HEAD --list 'v*' --sort=-version:refname)
}


release_head_subject() {
    git log -1 --format=%s HEAD
}


release_commit_type_for_subject() {
    local subject="${1:-}" type="" regex='^([[:alpha:]]+)(\([^)]+\))?(!)?:[[:space:]]*.+$'

    if [[ "${subject}" =~ ${regex} ]]; then
        type="${BASH_REMATCH[1],,}"
        printf '%s\n' "${type}"
        return 0
    fi

    printf 'other\n'
}


release_bump_kind_for_subject() {
    local subject="${1:-}" type=""
    type="$(release_commit_type_for_subject "${subject}")"

    case "${type}" in
        feat)
            printf 'minor\n'
            ;;
        *)
            printf 'patch\n'
            ;;
    esac
}


release_next_tag() {
    local latest_tag="${1:-}" bump_kind="${2:-patch}" major=0 minor=0 patch=0 regex=""
    regex="$(release_tag_regex)"

    if [[ -n "${latest_tag}" ]]; then
        [[ "${latest_tag}" =~ ${regex} ]] || {
            printf "release_next_tag: invalid release tag '%s'\n" "${latest_tag}" >&2
            return 1
        }
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
    fi

    case "${bump_kind}" in
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            printf "release_next_tag: unsupported bump kind '%s'\n" "${bump_kind}" >&2
            return 1
            ;;
    esac

    printf 'v%s.%s.%s\n' "${major}" "${minor}" "${patch}"
}


release_version_is_greater_than_tag() {
    local candidate_version="${1:-}" latest_tag="${2:-}" version_regex="" tag_regex=""
    local candidate_major=0 candidate_minor=0 candidate_patch=0
    local latest_major=0 latest_minor=0 latest_patch=0 latest_suffix=""

    version_regex="$(release_version_regex)"
    [[ "${candidate_version}" =~ ${version_regex} ]] || {
        printf "release_version_is_greater_than_tag: invalid version '%s'\n" "${candidate_version}" >&2
        return 1
    }
    candidate_major="${BASH_REMATCH[1]}"
    candidate_minor="${BASH_REMATCH[2]}"
    candidate_patch="${BASH_REMATCH[3]}"

    [[ -z "${latest_tag}" ]] && return 0

    tag_regex="$(release_tag_regex)"
    [[ "${latest_tag}" =~ ${tag_regex} ]] || {
        printf "release_version_is_greater_than_tag: invalid latest tag '%s'\n" "${latest_tag}" >&2
        return 1
    }
    latest_major="${BASH_REMATCH[1]}"
    latest_minor="${BASH_REMATCH[2]}"
    latest_patch="${BASH_REMATCH[3]}"
    latest_suffix="${BASH_REMATCH[4]:-}"

    if (( 10#${candidate_major} > 10#${latest_major} )); then
        return 0
    fi
    if (( 10#${candidate_major} < 10#${latest_major} )); then
        return 1
    fi
    if (( 10#${candidate_minor} > 10#${latest_minor} )); then
        return 0
    fi
    if (( 10#${candidate_minor} < 10#${latest_minor} )); then
        return 1
    fi
    if (( 10#${candidate_patch} > 10#${latest_patch} )); then
        return 0
    fi
    if (( 10#${candidate_patch} < 10#${latest_patch} )); then
        return 1
    fi
    [[ "${latest_suffix}" == "-beta" ]]
}


release_previous_github_tag() {
    local current_tag="${1:-}" release_tags="${2:-}" candidate="" previous_tag=""
    local tag_regex=""

    tag_regex='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'
    [[ "${current_tag}" =~ ${tag_regex} ]] || {
        printf "release_previous_github_tag: invalid current tag '%s'\n" "${current_tag}" >&2
        return 1
    }

    while IFS= read -r candidate; do
        [[ "${candidate}" =~ ${tag_regex} ]] || continue
        [[ "${candidate}" == "${current_tag}" ]] && continue
        release_version_is_greater_than_tag "${current_tag#v}" "${candidate}" || continue

        if [[ -z "${previous_tag}" ]] || release_version_is_greater_than_tag "${candidate#v}" "${previous_tag}"; then
            previous_tag="${candidate}"
        fi
    done <<< "${release_tags}"

    printf '%s\n' "${previous_tag}"
}


release_mobile_changelog_sections() {
    local current_tag="${1:?current tag required}" previous_tag="${2:-}"
    local tag="" oldest_tag="" oldest_range=""
    local tag_regex='^v([0-9]+)\.([0-9]+)\.([0-9]+)$'

    if [[ -n "${previous_tag}" ]]; then
        release_mobile_changelog_range "${previous_tag}" "${current_tag}"
        return
    fi

    while IFS= read -r tag; do
        [[ "${tag}" =~ ${tag_regex} ]] || continue
        oldest_tag="${tag}"
        break
    done < <(git tag --list 'v*' --sort=version:refname)

    [[ -n "${oldest_tag}" ]] || {
        printf "release_mobile_changelog_sections: no v* tags found for '%s'\n" "${current_tag}" >&2
        return 1
    }

    oldest_range="${oldest_tag}"
    if git rev-parse --verify "${oldest_tag}^{commit}^" >/dev/null 2>&1; then
        oldest_range="${oldest_tag}^"
    fi
    release_mobile_changelog_range "${oldest_range}" "${current_tag}"
}


release_mobile_changelog_range() {
    local previous_tag="${1:?previous tag required}" current_tag="${2:?current tag required}"
    local release_date="" subject=""
    local -a features=() fixes=() refactors=() performance=() docs=() other_changes=()

    # Render the same sections as CHANGELOG.md from an exact tag range so a
    # grouped heading cannot leak commits outside either release boundary.
    release_date="$(git log -1 --format=%cs "${current_tag}^{commit}")"
    while IFS= read -r subject; do
        [[ -n "${subject}" ]] || continue
        [[ "${subject}" == *"[skip ci]"* ]] && continue
        case "$(release_changelog_bucket_for_subject "${subject}")" in
            Features)     features+=("${subject}") ;;
            Fixes)        fixes+=("${subject}") ;;
            Refactors)    refactors+=("${subject}") ;;
            Performance)  performance+=("${subject}") ;;
            Docs)         docs+=("${subject}") ;;
            *)            other_changes+=("${subject}") ;;
        esac
    done < <(git log --reverse --format=%s "${previous_tag}..${current_tag}")

    (( ${#features[@]} + ${#fixes[@]} + ${#refactors[@]} + ${#performance[@]} + ${#docs[@]} + ${#other_changes[@]} > 0 )) || return 0

    printf '## %s (%s)\n\n' "${current_tag}" "${release_date}"
    release_render_changelog_section "Features" "${features[@]}"
    release_render_changelog_section "Fixes" "${fixes[@]}"
    release_render_changelog_section "Refactors" "${refactors[@]}"
    release_render_changelog_section "Performance" "${performance[@]}"
    release_render_changelog_section "Docs" "${docs[@]}"
    release_render_changelog_section "Other Changes" "${other_changes[@]}"
}


release_mobile_release_body() {
    local current_tag="${1:?current tag required}" previous_tag="${2:-}" release_notes="${3:-}"

    release_mobile_changelog_sections "${current_tag}" "${previous_tag}"
    if [[ -n "${release_notes}" ]]; then
        printf '\n%s\n' "${release_notes}"
    fi
}


release_create_tag() {
    local current_tag="" latest_tag="" subject="" bump_kind="" next_tag=""

    current_tag="$(release_head_tag || true)"
    if [[ -n "${current_tag}" ]]; then
        printf '%s\n' "${current_tag}"
        return 0
    fi

    latest_tag="$(release_latest_tag || true)"
    subject="$(release_head_subject)"
    bump_kind="$(release_bump_kind_for_subject "${subject}")"
    next_tag="$(release_next_tag "${latest_tag}" "${bump_kind}")"

    git tag "${next_tag}" HEAD
    printf '%s\n' "${next_tag}"
}


release_create_tag_as() {
    local release_as="${1:-}" latest_tag="" next_tag=""
    local version_regex=""

    version_regex="$(release_version_regex)"
    [[ "${release_as}" =~ ${version_regex} ]] || {
        printf "release_create_tag_as: invalid release version '%s' (expected X.Y.Z)\n" "${release_as}" >&2
        return 1
    }

    latest_tag="$(release_latest_tag || true)"
    if ! release_version_is_greater_than_tag "${release_as}" "${latest_tag}"; then
        printf "release_create_tag_as: '%s' must be greater than latest release tag '%s'\n" \
            "${release_as}" "${latest_tag:-none}" >&2
        return 1
    fi

    next_tag="v${release_as}"
    git tag "${next_tag}" HEAD
    printf '%s\n' "${next_tag}"
}


release_changelog_bucket_for_subject() {
    local subject="${1:-}" type=""
    type="$(release_commit_type_for_subject "${subject}")"

    case "${type}" in
        feat) printf 'Features\n' ;;
        fix) printf 'Fixes\n' ;;
        refactor) printf 'Refactors\n' ;;
        perf) printf 'Performance\n' ;;
        docs) printf 'Docs\n' ;;
        *) printf 'Other Changes\n' ;;
    esac
}


release_render_changelog_section() {
    local title="${1:?section title required}" entry=""
    shift || true

    [[ $# -gt 0 ]] || return 0

    printf '### %s\n' "${title}"
    for entry in "$@"; do
        printf -- '- %s\n' "${entry}"
    done
    printf '\n'
}


# Render one day-group of tags.
# Args: previous_tag (may be empty) first_tag last_tag release_date
# Output goes to stdout; caller redirects to the temp file.
_release_flush_group() {
    local previous_tag="${1}" first_tag="${2}" last_tag="${3}" release_date="${4}"
    local log_range="" subject=""
    local -a features=() fixes=() refactors=() performance=() docs=() other_changes=()

    if [[ -n "${previous_tag}" ]]; then
        log_range="${previous_tag}..${first_tag}"
    elif [[ "${first_tag}" != "${last_tag}" ]]; then
        log_range="${last_tag}^..${first_tag}"
    else
        log_range="${first_tag}^!"
    fi

    while IFS= read -r subject; do
        [[ -n "${subject}" ]] || continue
        [[ "${subject}" == *"[skip ci]"* ]] && continue
        case "$(release_changelog_bucket_for_subject "${subject}")" in
            Features)     features+=("${subject}") ;;
            Fixes)        fixes+=("${subject}") ;;
            Refactors)    refactors+=("${subject}") ;;
            Performance)  performance+=("${subject}") ;;
            Docs)         docs+=("${subject}") ;;
            *)            other_changes+=("${subject}") ;;
        esac
    done < <(git log --reverse --format=%s "${log_range}")

    (( ${#features[@]} + ${#fixes[@]} + ${#refactors[@]} + ${#performance[@]} + ${#docs[@]} + ${#other_changes[@]} > 0 )) || return 0

    if [[ "${first_tag}" == "${last_tag}" ]]; then
        printf '## %s (%s)\n\n' "${first_tag}" "${release_date}"
    else
        printf '## %s \xe2\x80\xa6 %s (%s)\n\n' "${first_tag}" "${last_tag}" "${release_date}"
    fi

    release_render_changelog_section "Features" "${features[@]}"
    release_render_changelog_section "Fixes" "${fixes[@]}"
    release_render_changelog_section "Refactors" "${refactors[@]}"
    release_render_changelog_section "Performance" "${performance[@]}"
    release_render_changelog_section "Docs" "${docs[@]}"
    release_render_changelog_section "Other Changes" "${other_changes[@]}"
}


release_generate_changelog() {
    local output_path="${1:-CHANGELOG.md}" tmp_output="" write_stdout=0
    local -a tags=()

    if [[ "${output_path}" == "-" ]]; then
        write_stdout=1
        tmp_output="$(mktemp)"
    else
        mkdir -p "$(dirname -- "${output_path}")"
        tmp_output="${output_path}.tmp"
    fi

    mapfile -t tags < <(release_tags_desc)

    {
        printf '# Changelog\n\n'
        printf '_Generated from release tags with `bash bin/generate-changelog`._\n\n'

        if (( ${#tags[@]} == 0 )); then
            printf 'No release tags yet.\n'
        else
            local -a current_group=()
            local current_group_date="" tag="" tag_date=""

            for index in "${!tags[@]}"; do
                tag="${tags[${index}]}"
                tag_date="$(git log -1 --format=%cs "${tag}^{commit}")"

                if [[ "${tag_date}" == "${current_group_date}" ]]; then
                    current_group+=("${tag}")
                else
                    if (( ${#current_group[@]} > 0 )); then
                        _release_flush_group "${tag}" "${current_group[0]}" "${current_group[-1]}" "${current_group_date}"
                    fi
                    current_group=("${tag}")
                    current_group_date="${tag_date}"
                fi
            done

            if (( ${#current_group[@]} > 0 )); then
                _release_flush_group "" "${current_group[0]}" "${current_group[-1]}" "${current_group_date}"
            fi
        fi
    } > "${tmp_output}"

    if (( write_stdout == 1 )); then
        cat "${tmp_output}"
        rm -f "${tmp_output}"
        return 0
    fi

    mv "${tmp_output}" "${output_path}"
}
