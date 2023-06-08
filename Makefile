.PHONY: check
check:
	tl check teal/*.tl teal/**/*.tl

.PHONY: build
build: tlconfig.lua
	tl build
