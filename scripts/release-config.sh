#!/usr/bin/env bash
# shellcheck disable=SC2034 # Constants are consumed by scripts that source this file.

RELEASE_REPOSITORY="openclaw/remindctl"
RELEASE_DEFAULT_BRANCH="main"
RELEASE_ARTIFACT="remindctl-macos.zip"
RELEASE_CHECKSUMS="checksums.txt"
RELEASE_INVENTORY="release-inventory.json"
RELEASE_IDENTIFIER="com.steipete.remindctl"
RELEASE_TEAM_ID="FWJYW4S8P8"
RELEASE_SIGNING_IDENTITY="Developer ID Application: OpenClaw Foundation (FWJYW4S8P8)"
RELEASE_ARCHITECTURES="arm64 x86_64"
RELEASE_DESIGNATED_REQUIREMENT='identifier "com.steipete.remindctl" and anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = "FWJYW4S8P8"'
