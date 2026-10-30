.PHONY: verify verify-source test build probe package

verify: verify-source test build

verify-source:
	python3 Scripts/check-repository.py
	@for script in Scripts/*.sh; do zsh -n "$$script" || exit $$?; done

test:
	Scripts/test.sh

build:
	Scripts/build-app.sh

probe:
	Scripts/probe.sh

package:
	Scripts/package.sh
