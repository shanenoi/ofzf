DUNE ?= dune

.PHONY: build build-macos test clean

build:
	$(DUNE) build

build-macos:
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		PATH="/usr/bin:/bin:/usr/sbin:/sbin:$$PATH" \
		SDKROOT="$$(xcrun --sdk macosx --show-sdk-path)" \
		$(DUNE) build; \
	else \
		$(DUNE) build; \
	fi

test:
	$(DUNE) runtest

clean:
	$(DUNE) clean
