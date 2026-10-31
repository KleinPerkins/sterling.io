.PHONY: verify verify-source test test-delivery build probe package test-shard

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

# Full make verify stays unfiltered. CI shard count lives in .github/test-shards.json.
test-shard:
	python3 Scripts/ci.py run --platform $(or $(PLATFORM),macos-26) --index $(or $(SHARD_INDEX),0) $(if $(SHARD_COUNT),--shards $(SHARD_COUNT),)
