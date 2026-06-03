DUNE ?= dune

ifeq ($(shell uname -s),Darwin)
DUNE_ENV = PATH="/usr/bin:/bin:/usr/sbin:/sbin:$$PATH" SDKROOT="$$(xcrun --sdk macosx --show-sdk-path)"
else
DUNE_ENV =
endif

.PHONY: build build-macos test clean

build:
	$(DUNE_ENV) $(DUNE) build

build-macos: build

test:
	$(DUNE_ENV) $(DUNE) runtest

clean:
	$(DUNE) clean
