#!/bin/bash

set -euo pipefail

script_directory="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "${script_directory}/.." && pwd)"
output_directory="${OUTPUT_DIRECTORY:-${repository_root}/build/release}"
archive_path="${output_directory}/WeChatBuddy.xcarchive"
application_path="${archive_path}/Products/Applications/WeChatBuddy.app"
zip_path="${output_directory}/WeChatBuddy-local-unsigned.zip"

mkdir -p "${output_directory}"

xcodebuild \
    -project "${repository_root}/WeChatBuddy.xcodeproj" \
    -scheme WeChatBuddy \
    -configuration Release \
    -destination "generic/platform=macOS" \
    -archivePath "${archive_path}" \
    archive \
    ARCHS=arm64 \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGNING_ALLOWED=NO

test -d "${application_path}"

rm -f "${zip_path}"
ditto -c -k --keepParent "${application_path}" "${zip_path}"

echo "本机验收包已生成：${zip_path}"
echo "注意：该包未签名、未公证，不可作为公开发布包。"
