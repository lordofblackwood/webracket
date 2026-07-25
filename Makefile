SHELL := /bin/bash

RACKET ?= ../racket/racket/bin/racket
SMOKE_DIR := lib/web-easy/smoke
SINGLE_COMPILE ?= run-browser-parity-profile-compile.sh
SINGLE_PAGE ?= test-browser-parity-profile.html
SPLIT_RUNTIME_TOOL_COMPILED_ROOT ?= tmp/smoke-split-runtime-tool-compiled-root
SPLIT_RUNTIME_BROWSER_COMPILED_ROOT ?= tmp/smoke-split-runtime-browser-compiled-root

.PHONY: help goal1-fast smoke-ci smoke-headless-lite smoke-style smoke-theme smoke-theme-contracts smoke-theme-core smoke-theme-visual smoke-verify smoke-quick smoke-release smoke-one smoke-list smoke-commands smoke-compare-navbars smoke-compare-buttons smoke-compare-all smoke-solar-parity smoke-solar-sections smoke-solar-sections-gate smoke-split-runtime-readiness smoke-split-runtime-readiness-fast smoke-split-runtime-default smoke-split-runtime-default-fast smoke-split-runtime-provider-ffi smoke-split-runtime-browser smoke-split-runtime-browser-url smoke-split-runtime-browser-provider-runtime smoke-split-runtime-browser-provider-runtime-url smoke-split-runtime-prewarm smoke-split-runtime-warm-process smoke-split-runtime-provider-runtime smoke-split-runtime-provider-runtime-warm-process smoke-split-runtime-procedure-boundary smoke-split-runtime-examples smoke-split-runtime-examples-list smoke-split-runtime-examples-audit smoke-split-runtime-examples-fast smoke-split-runtime-examples-chunked smoke-split-runtime-examples-chunk-1 smoke-split-runtime-examples-chunk-2 smoke-split-runtime-examples-chunk-3 smoke-split-runtime-examples-chunk-4 smoke-split-ffi-mixed-cache-browser smoke-split-ffi-mixed-cache-browser-list smoke-split-ffi-mixed-cache-browser-fast smoke-split-ffi-mixed-cache-browser-broad smoke-split-ffi-mixed-cache-browser-browser-group smoke-split-ffi-mixed-cache-browser-test-dir-group smoke-split-ffi-mixed-cache-browser-chunked smoke-split-ffi-mixed-cache-browser-chunk-1 smoke-split-ffi-mixed-cache-browser-chunk-2 smoke-split-ffi-mixed-cache-browser-chunk-3 smoke-split-ffi-mixed-cache-browser-chunk-4 smoke-treelist-shape dom-headless measure-letrec-test-basics measure-split-runtime-warm-process measure-split-runtime-provider-runtime measure-split-runtime-provider-runtime-warm-process

help:
	@echo "Available targets:"
	@echo "  help                  Show this help."
	@echo "  goal1-fast            Run the compact Goal 1 fast checks."
	@echo "  smoke-ci              Run local CI smoke entrypoint (preferred)."
	@echo "  smoke-headless-lite   Run contract+smoke+parity+guard without compile (preferred)."
	@echo "  smoke-style           Run style-hook contracts only (smoke+parity)."
	@echo "  smoke-theme           Run theme-only dashboard headless."
	@echo "  smoke-theme-contracts Run focused theme contracts lane (no solar visual diff)."
	@echo "  smoke-theme-core      Run focused theme-core lane (compile+contracts+solar polish)."
	@echo "  smoke-theme-visual    Run theme visual-diff lane headless."
	@echo "  smoke-verify          Run local headless verify preflight."
	@echo "  smoke-quick           Run smoke-verify + smoke-headless-lite."
	@echo "  smoke-release         Run smoke-commands + smoke-quick + smoke-ci + split-runtime readiness."
	@echo "  smoke-list            Print canonical smoke/headless commands."
	@echo "  smoke-commands        Regenerate smoke/COMMANDS.tsv."
	@echo "  smoke-one             Run one headless smoke page (set SINGLE_COMPILE, SINGLE_PAGE)."
	@echo "  smoke-compare-navbars Run Bootswatch-vs-solar2 navbar compare sweep."
	@echo "  smoke-compare-buttons Run Bootswatch-vs-solar2 button compare sweep."
	@echo "  smoke-compare-all     Run both compare sweeps."
	@echo "  smoke-solar-parity    Run full Solar2 parity sweep (accordion/navbar/forms/tables/list/progress)."
	@echo "  smoke-solar-sections  Run per-section Solar2 parity report (with RMSE per section)."
	@echo "  smoke-solar-sections-gate  Run quick per-section Solar2 RMSE threshold gate."
	@echo "  smoke-split-runtime-readiness  Run the focused split-runtime default-readiness gate."
	@echo "  smoke-split-runtime-readiness-fast  Run the compact split-runtime default-readiness gate."
	@echo "  smoke-split-runtime-default  Run default sidecar and explicit monolithic compile/run smoke."
	@echo "  smoke-split-runtime-default-fast  Run a compact default/split-FFI slice."
	@echo "  smoke-split-runtime-provider-ffi  Run provider-runtime split-FFI default-check cases."
	@echo "  smoke-split-runtime-browser  Run cached split-runtime browser sidecar smoke."
	@echo "  smoke-split-runtime-browser-url  Run cached split-runtime browser shared runtime URL smoke."
	@echo "  smoke-split-runtime-browser-provider-runtime  Run browser provider-runtime sidecar smoke."
	@echo "  smoke-split-runtime-browser-provider-runtime-url  Run browser provider-runtime shared URL smoke."
	@echo "  smoke-split-runtime-prewarm  Run representative cached split-runtime compile/run fixtures."
	@echo "  smoke-split-runtime-warm-process  Run cached split-runtime through a warm compiler process."
	@echo "  smoke-split-runtime-provider-runtime  Run Node provider-runtime cache-reference smoke."
	@echo "  smoke-split-runtime-provider-runtime-warm-process  Run provider-runtime through a warm compiler process."
	@echo "  smoke-split-runtime-procedure-boundary  Run tiny Wasm-GC procedure boundary smoke."
	@echo "  smoke-split-runtime-examples  Run all registered real-example split-runtime browser smoke."
	@echo "  smoke-split-runtime-examples-audit  Check example smoke manifest coverage."
	@echo "  smoke-split-runtime-examples-fast  Run two real examples under default split-runtime."
	@echo "  smoke-split-runtime-examples-chunked  Run all registered real examples in four chunks."
	@echo "  smoke-split-ffi-mixed-cache-browser  Run full split-FFI mixed-cache browser smoke."
	@echo "  smoke-split-ffi-mixed-cache-browser-fast  Run compact split-FFI browser smoke."
	@echo "  smoke-split-ffi-mixed-cache-browser-broad  Run browser+test-dir split-FFI browser chunks."
	@echo "  smoke-split-ffi-mixed-cache-browser-chunked  Run full split-FFI browser smoke in four chunks."
	@echo "  smoke-treelist-shape  Run the compiler-private treelist shape validation smoke."
	@echo "  dom-headless          Run the DOM browser wrapper suite."
	@echo "  measure-letrec-test-basics  Run test-letrec first, then compare letrec strategies on test-basics."
	@echo "  measure-split-runtime-warm-process  Benchmark warm-process split-runtime on a tiny fixture."
	@echo "  measure-split-runtime-provider-runtime  Benchmark provider-runtime split on MiniScheme."
	@echo "  measure-split-runtime-provider-runtime-warm-process  Benchmark warm-process provider-runtime split on MiniScheme."

smoke-ci:
	cd $(SMOKE_DIR) && ./headless.sh ci

smoke-headless-lite:
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./headless.sh contract
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./headless.sh smoke
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./headless.sh parity
	cd $(SMOKE_DIR) && ./headless.sh guard

smoke-style:
	cd $(SMOKE_DIR) && ./headless.sh style

smoke-theme:
	cd $(SMOKE_DIR) && ./headless.sh theme

smoke-theme-contracts:
	cd $(SMOKE_DIR) && ./check-theme-contract-helper.sh
	cd $(SMOKE_DIR) && ./run-browser-theme-showcase-compile.sh
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-external-css-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-core-link-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-starter-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-helper-api-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-contract-vars-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-theme-showcase-compile.sh test-browser-theme-showcase-contract.html

smoke-theme-core:
	cd $(SMOKE_DIR) && ./check-theme-contract-helper.sh
	cd $(SMOKE_DIR) && ./run-browser-theme-showcase-compile.sh
	cd $(SMOKE_DIR) && ./run-browser-solar-showcase-compile.sh
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-external-css-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-core-link-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-parity-all-compile.sh test-browser-theme-starter-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-single-headless.sh run-browser-theme-showcase-compile.sh test-browser-theme-showcase-contract.html
	cd $(SMOKE_DIR) && SMOKE_SKIP_COMPILE=1 ./check-solar-polish.sh

smoke-theme-visual:
	cd $(SMOKE_DIR) && ./headless.sh theme-visual

smoke-verify:
	cd $(SMOKE_DIR) && ./headless.sh verify

smoke-quick: smoke-verify smoke-headless-lite

smoke-release: smoke-commands smoke-quick smoke-ci smoke-split-runtime-readiness

smoke-list:
	@echo "Canonical headless modes:"
	@cd $(SMOKE_DIR) && ./headless.sh list
	@echo "Direct style script:"
	@echo "./check-style-headless.sh"
	@echo "DOM browser suite:"
	@echo "make dom-headless"
	@echo
	@echo "Canonical Make targets:"
	@echo "smoke-ci"
	@echo "smoke-headless-lite"
	@echo "smoke-style"
	@echo "smoke-theme"
	@echo "smoke-theme-contracts"
	@echo "smoke-theme-core"
	@echo "smoke-theme-visual"
	@echo "smoke-verify"
	@echo "smoke-quick"
	@echo "smoke-release"
	@echo "smoke-commands"
	@echo "smoke-one"
	@echo "smoke-compare-navbars"
	@echo "smoke-compare-buttons"
	@echo "smoke-compare-all"
	@echo "smoke-solar-parity"
	@echo "smoke-solar-sections"
	@echo "smoke-solar-sections-gate"
	@echo "smoke-split-runtime-readiness"
	@echo "smoke-split-runtime-readiness-fast"
	@echo "smoke-split-runtime-default"
	@echo "smoke-split-runtime-default-fast"
	@echo "smoke-split-runtime-provider-ffi"
	@echo "smoke-split-runtime-browser"
	@echo "smoke-split-runtime-browser-url"
	@echo "smoke-split-runtime-browser-provider-runtime"
	@echo "smoke-split-runtime-browser-provider-runtime-url"
	@echo "smoke-split-runtime-prewarm"
	@echo "smoke-split-runtime-warm-process"
	@echo "smoke-split-runtime-provider-runtime"
	@echo "smoke-split-runtime-provider-runtime-warm-process"
	@echo "smoke-split-runtime-procedure-boundary"
	@echo "smoke-split-runtime-examples"
	@echo "smoke-split-runtime-examples-list"
	@echo "smoke-split-runtime-examples-audit"
	@echo "smoke-split-runtime-examples-fast"
	@echo "smoke-split-runtime-examples-chunked"
	@echo "smoke-split-ffi-mixed-cache-browser"
	@echo "smoke-split-ffi-mixed-cache-browser-list"
	@echo "smoke-split-ffi-mixed-cache-browser-fast"
	@echo "smoke-split-ffi-mixed-cache-browser-broad"
	@echo "smoke-split-ffi-mixed-cache-browser-chunked"
	@echo "smoke-treelist-shape"
	@echo "dom-headless"

goal1-fast:
	$(RACKET) webify/test-primitive-shapes.rkt
	$(RACKET) webify/test-webracket-set.rkt
	$(RACKET) webify/test-goal1-dashboard.rkt
	$(RACKET) webify/test-stdlib-surface-report.rkt
	$(RACKET) webify/test-webracket-base-fast.rkt

smoke-commands:
	cd $(SMOKE_DIR) && ./gen-commands.sh

smoke-one:
	cd $(SMOKE_DIR) && ./headless.sh single $(SINGLE_COMPILE) $(SINGLE_PAGE)

smoke-compare-navbars:
	cd $(SMOKE_DIR) && for v in primary dark light subtle; do node ./compare-navbars.cjs $$v; done

smoke-compare-buttons:
	cd $(SMOKE_DIR) && for r in solid disabled outline sizes; do node ./compare-buttons.cjs $$r; done

smoke-compare-all: smoke-compare-buttons smoke-compare-navbars

smoke-solar-parity:
	cd $(SMOKE_DIR) && ./check-solar-parity-sweep.sh

smoke-solar-sections:
	cd $(SMOKE_DIR) && ./check-solar-section-parity.sh

smoke-solar-sections-gate:
	cd $(SMOKE_DIR) && SOLAR_SECTIONS_GATE_ONLY=1 ./check-solar-section-parity.sh

smoke-split-runtime-browser:
	mkdir -p $(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 540 --rss-limit-mb 1800 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-browser.rkt --isolate-compiled-root

smoke-split-runtime-readiness:
	$(MAKE) smoke-split-runtime-default
	$(MAKE) smoke-split-runtime-browser-url
	$(MAKE) smoke-split-runtime-browser-provider-runtime-url
	$(MAKE) smoke-split-runtime-provider-runtime
	$(MAKE) smoke-split-ffi-mixed-cache-browser-fast
	$(MAKE) smoke-split-runtime-examples-fast

smoke-split-runtime-readiness-fast:
	$(MAKE) smoke-split-runtime-default-fast
	$(MAKE) smoke-split-runtime-provider-ffi
	$(MAKE) smoke-split-runtime-browser-url
	$(MAKE) smoke-split-ffi-mixed-cache-browser-fast
	$(MAKE) smoke-split-runtime-examples-fast

smoke-split-runtime-default:
	python3 tools/run-guarded.py --timeout-sec 900 --rss-limit-mb 4500 -- racket -S pkgs tools/check-split-runtime-default.rkt --jobs 4

smoke-split-runtime-default-fast:
	python3 tools/run-guarded.py --timeout-sec 360 --rss-limit-mb 3000 -- racket -S pkgs tools/check-split-runtime-default.rkt --jobs 4 --only default-sidecar-test-trivial --only explicit-monolithic-test-trivial --only default-split-ffi-standard-ffi-demand --only invalid-explicit-split-ffi-without-split

smoke-split-runtime-provider-ffi:
	python3 tools/run-guarded.py --timeout-sec 420 --rss-limit-mb 4500 -- racket -S pkgs tools/check-split-runtime-default.rkt --jobs 4 --only provider-runtime-explicit-split-ffi-clean-provider-test-module-read-demand --only provider-runtime-provider-ffi-with-split-ffi-provider-runtime-provider-ffi-demand --only provider-runtime-local-provider-ffi-with-split-ffi-provider-ffi-demand

smoke-split-runtime-browser-url:
	mkdir -p $(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 540 --rss-limit-mb 1800 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-browser.rkt --shared-runtime-url --isolate-compiled-root

smoke-split-runtime-browser-provider-runtime:
	mkdir -p $(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 540 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-browser.rkt --source test/test-module-read-demand.rkt --split-runtime-provider-runtime --isolate-compiled-root

smoke-split-runtime-browser-provider-runtime-url:
	mkdir -p $(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 540 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_BROWSER_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-browser.rkt --source test/test-module-read-demand.rkt --shared-runtime-url --split-runtime-provider-runtime --isolate-compiled-root

smoke-split-runtime-prewarm:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 600 --rss-limit-mb 4000 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-prewarm.rkt --source test/test-lambda-variadic.rkt --extra-source test/test-values-errors.rkt --suite --jobs 4 --no-expect --reject '#f'

smoke-split-runtime-warm-process:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 300 --rss-limit-mb 2500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-prewarm.rkt --source test/test-trivial.rkt --in-process --no-sidecar-check

smoke-split-runtime-provider-runtime:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 900 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-prewarm.rkt --source test/test-module-read-demand.rkt --extra-source examples/minischeme/repro-local-mini-42.rkt --split-runtime-provider-runtime --precompile-compiler --isolate-compiled-root

smoke-split-runtime-provider-runtime-warm-process:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 480 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/check-split-runtime-prewarm.rkt --source test/test-module-read-demand.rkt --extra-source examples/minischeme/repro-local-mini-42.rkt --split-runtime-provider-runtime --in-process --no-sidecar-check

smoke-split-runtime-procedure-boundary:
	python3 tools/run-guarded.py --timeout-sec 60 --rss-limit-mb 1000 -- racket -S pkgs tools/check-split-runtime-procedure-boundary.rkt

smoke-split-runtime-examples:
	bash tools/check-split-runtime-examples.sh

smoke-split-runtime-examples-list:
	bash tools/check-split-runtime-examples.sh --list-cases

smoke-split-runtime-examples-audit:
	bash tools/check-split-runtime-examples.sh --audit-coverage

smoke-split-runtime-examples-fast:
	bash tools/check-split-runtime-examples.sh --only examples-hello-world-dom --only webeasy-hello-world

smoke-split-runtime-examples-chunked:
	$(MAKE) -j4 smoke-split-runtime-examples-chunk-1 smoke-split-runtime-examples-chunk-2 smoke-split-runtime-examples-chunk-3 smoke-split-runtime-examples-chunk-4

smoke-split-runtime-examples-chunk-1:
	bash tools/check-split-runtime-examples.sh --chunk 1/4

smoke-split-runtime-examples-chunk-2:
	bash tools/check-split-runtime-examples.sh --chunk 2/4

smoke-split-runtime-examples-chunk-3:
	bash tools/check-split-runtime-examples.sh --chunk 3/4

smoke-split-runtime-examples-chunk-4:
	bash tools/check-split-runtime-examples.sh --chunk 4/4

smoke-treelist-shape:
	racket tools/check-treelist-shape-smoke.rkt

dom-headless:
	cd test && ./run-dom-headless.sh

smoke-split-ffi-mixed-cache-browser:
	bash test/run-split-ffi-mixed-cache-headless.sh

smoke-split-ffi-mixed-cache-browser-list:
	bash test/run-split-ffi-mixed-cache-headless.sh --list-cases

smoke-split-ffi-mixed-cache-browser-fast:
	bash test/run-split-ffi-mixed-cache-headless.sh --only test-js-math-ffi --only test-dom-window-document

smoke-split-ffi-mixed-cache-browser-broad:
	$(MAKE) smoke-split-ffi-mixed-cache-browser-browser-group
	$(MAKE) smoke-split-ffi-mixed-cache-browser-test-dir-group

smoke-split-ffi-mixed-cache-browser-browser-group:
	$(MAKE) -j4 smoke-split-ffi-mixed-cache-browser-browser-group-chunk-1 smoke-split-ffi-mixed-cache-browser-browser-group-chunk-2 smoke-split-ffi-mixed-cache-browser-browser-group-chunk-3 smoke-split-ffi-mixed-cache-browser-browser-group-chunk-4

smoke-split-ffi-mixed-cache-browser-browser-group-chunk-1:
	bash test/run-split-ffi-mixed-cache-headless.sh --group browser --chunk 1/4

smoke-split-ffi-mixed-cache-browser-browser-group-chunk-2:
	bash test/run-split-ffi-mixed-cache-headless.sh --group browser --chunk 2/4

smoke-split-ffi-mixed-cache-browser-browser-group-chunk-3:
	bash test/run-split-ffi-mixed-cache-headless.sh --group browser --chunk 3/4

smoke-split-ffi-mixed-cache-browser-browser-group-chunk-4:
	bash test/run-split-ffi-mixed-cache-headless.sh --group browser --chunk 4/4

smoke-split-ffi-mixed-cache-browser-test-dir-group:
	$(MAKE) -j4 smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-1 smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-2 smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-3 smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-4

smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-1:
	bash test/run-split-ffi-mixed-cache-headless.sh --group test-dir --chunk 1/4

smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-2:
	bash test/run-split-ffi-mixed-cache-headless.sh --group test-dir --chunk 2/4

smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-3:
	bash test/run-split-ffi-mixed-cache-headless.sh --group test-dir --chunk 3/4

smoke-split-ffi-mixed-cache-browser-test-dir-group-chunk-4:
	bash test/run-split-ffi-mixed-cache-headless.sh --group test-dir --chunk 4/4

smoke-split-ffi-mixed-cache-browser-chunked:
	$(MAKE) -j4 smoke-split-ffi-mixed-cache-browser-chunk-1 smoke-split-ffi-mixed-cache-browser-chunk-2 smoke-split-ffi-mixed-cache-browser-chunk-3 smoke-split-ffi-mixed-cache-browser-chunk-4

smoke-split-ffi-mixed-cache-browser-chunk-1:
	bash test/run-split-ffi-mixed-cache-headless.sh --chunk 1/4

smoke-split-ffi-mixed-cache-browser-chunk-2:
	bash test/run-split-ffi-mixed-cache-headless.sh --chunk 2/4

smoke-split-ffi-mixed-cache-browser-chunk-3:
	bash test/run-split-ffi-mixed-cache-headless.sh --chunk 3/4

smoke-split-ffi-mixed-cache-browser-chunk-4:
	bash test/run-split-ffi-mixed-cache-headless.sh --chunk 4/4

measure-letrec-test-basics:
	racket tools/measure-letrec-test-basics.rkt

measure-split-runtime-warm-process:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 360 --rss-limit-mb 2500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/measure-split-runtime.rkt --prewarm-runtime-first --include-cache-reference --in-process

measure-split-runtime-provider-runtime:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 720 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/measure-split-runtime.rkt --source examples/minischeme/repro-local-mini-42.rkt --split-runtime-provider-runtime --prewarm-runtime-first --include-cache-reference

measure-split-runtime-provider-runtime-warm-process:
	mkdir -p $(SPLIT_RUNTIME_TOOL_COMPILED_ROOT)
	python3 tools/run-guarded.py --timeout-sec 720 --rss-limit-mb 3500 -- /usr/bin/env PLTCOMPILEDROOTS=$(SPLIT_RUNTIME_TOOL_COMPILED_ROOT) racket -S pkgs tools/measure-split-runtime.rkt --source examples/minischeme/repro-local-mini-42.rkt --split-runtime-provider-runtime --prewarm-runtime-first --include-cache-reference --in-process
