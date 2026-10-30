.PHONY: verify verify-source test test-delivery build probe package

verify: verify-source test test-delivery build

verify-source:
	python3 Scripts/check-repository.py
	@for script in Scripts/*.sh; do zsh -n "$$script" || exit $$?; done

test:
	Scripts/test.sh

test-delivery:
	python3 -m unittest discover -s Tests -p 'test_*.py' -v
	mkdir -p work/swift-script-cache
	xcrun swift -module-cache-path work/swift-script-cache Scripts/verify-update.swift --self-test

build:
	Scripts/build-app.sh

probe:
	Scripts/probe.sh

package:
	Scripts/package.sh
