SHELL := /bin/bash

.PHONY: help format lint test check build macos-artifact release-harness remindctl release-check docs-site clean

help:
	@printf "%s\n" \
		"make format    - swift format in-place" \
		"make lint      - Swift, shell, and workflow lint" \
		"make test      - sync version + swift test (coverage enabled)" \
		"make check     - lint + test + coverage gate" \
		"make build     - release build into bin/ (codesigned)" \
		"make macos-artifact - build credential-free universal local candidate" \
		"make release-harness - test release scripts with credential-free mocks" \
		"make release-check TAG=vX.Y.Z - validate release preflight" \
		"make remindctl - clean rebuild + run debug binary (ARGS=...)" \
		"make docs-site - build GitHub Pages docs into dist/docs-site" \
		"make clean     - swift package clean"

format:
	swift format --in-place --recursive Sources Tests

lint:
	swift format lint --recursive Sources Tests
	swiftlint --strict
	shellcheck -x scripts/*.sh
	actionlint .github/workflows/*.yml

test:
	scripts/generate-version.sh
	swift test --enable-code-coverage

check:
	$(MAKE) lint
	$(MAKE) test
	scripts/check-coverage.sh

build:
	scripts/generate-version.sh
	mkdir -p bin
	swift build -c release --product remindctl
	cp .build/release/remindctl bin/remindctl
	codesign --force --sign - --identifier com.steipete.remindctl bin/remindctl

macos-artifact:
	scripts/package-macos-candidate.sh

release-harness:
	scripts/test-release.sh

release-check:
	@if [ -z "$(TAG)" ]; then echo "Usage: make release-check TAG=vX.Y.Z" >&2; exit 1; fi
	scripts/check-release.sh "$(TAG)"

remindctl:
	scripts/generate-version.sh
	swift package clean
	swift build -c debug --product remindctl
	./.build/debug/remindctl $(ARGS)

docs-site:
	node scripts/build-docs-site.mjs

clean:
	swift package clean
