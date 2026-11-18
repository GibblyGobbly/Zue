# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly

# Zue source -> LLVM IR -> native binary (LLVM's opt, llc and ld.lld, through compiler/llvm_build.sh).
#
#   make            build bin/zue from the seeds in bootstrap/ (needs LLVM 22: llvm-22 and lld-22)
#   make test       compile and run every test, compare with test/expected/, run the native checks and
#                   tools/check_thread_pointer.sh
#   make verify-ir  run the tests and check every generated IR file with LLVM's verifier (opt)
#   make LLVM=23    use another LLVM version (opt-23, llc-23, ld.lld-23; any target)
#   make verify-debug  build the examples with zue build -g and check the line tables
#   make codes-check   check that the error code files are generated, every example gets its code, and every recorded error has one
#   make fuzz       compare random expressions and programs with an independent model (needs python3)
#   make round-trip parse every Zue file, print it back with zue unparse, and compare the trees
#   make seed       refresh the seeds after changing compiler/ or compiler/runtime/
#   make clean      remove build output
#
# bootstrap/zuec.ll and bootstrap/zue_rt_native.ll are the LLVM IR of the compiler and the
# runtime, kept in the repository so the first compiler can be built with LLVM's tools alone.

ifeq (,$(filter -j%,$(MAKEFLAGS)))
MAKEFLAGS += -j$(shell nproc)
endif

# The LLVM version comes from compiler/llvm_build.sh unless "make LLVM=N" picks one; the runtime
# object records the version that made it and is rebuilt for another.
ifneq ($(LLVM),)
export LLVM
endif
BUILD = compiler/llvm_build.sh
OPT = $(shell $(BUILD) --which opt)
BINDIR = bin
OUT = C

SEED = bootstrap/zuec.ll
SEED_RT = bootstrap/zue_rt_native.ll
COMPILER_LU = $(wildcard compiler/*.zu)
RT_LU = $(sort $(wildcard compiler/runtime/*.zu))

all: $(BINDIR)/zue

# seeds -> seed compiler -> runtime and compiler IR of the current sources -> compiler ->
# IR again. The two compiler IR files must match.
$(BINDIR)/zue: $(SEED) $(SEED_RT) $(COMPILER_LU) $(RT_LU)
	@mkdir -p $(BINDIR) $(OUT)
	@echo "[1/6] seed compiler: linking the committed IR ($(SEED), $(SEED_RT))"
	@echo "      $(BUILD) -O1 -o $(OUT)/zue_seed $(SEED) $(SEED_RT)"
	@$(BUILD) -O1 -o $(OUT)/zue_seed $(SEED) $(SEED_RT)
	@echo "[2/6] runtime: the seed compiles compiler/runtime/*.zu to $(OUT)/boot_rt.ll"
	@echo "      $(OUT)/zue_seed --native compiler/runtime/*.zu -o $(OUT)/boot_rt.ll"
	@$(OUT)/zue_seed --native $(RT_LU) -o $(OUT)/boot_rt.ll
	@echo "[3/6] stage 1: the seed compiles compiler/zuec.zu to $(OUT)/boot1.ll"
	@echo "      $(OUT)/zue_seed compiler/zuec.zu $(OUT)/boot1.ll ."
	@$(OUT)/zue_seed compiler/zuec.zu $(OUT)/boot1.ll .
	@echo "[4/6] stage 1: linking $(OUT)/zue_stage1, the compiler built from today's sources"
	@echo "      $(BUILD) -O1 -o $(OUT)/zue_stage1 $(OUT)/boot1.ll $(OUT)/boot_rt.ll"
	@$(BUILD) -O1 -o $(OUT)/zue_stage1 $(OUT)/boot1.ll $(OUT)/boot_rt.ll
	@echo "[5/6] stage 2: stage 1 compiles compiler/zuec.zu again, to $(OUT)/boot2.ll"
	@echo "      $(OUT)/zue_stage1 compiler/zuec.zu $(OUT)/boot2.ll ."
	@$(OUT)/zue_stage1 compiler/zuec.zu $(OUT)/boot2.ll .
	@echo "[6/6] check: stage 1 and stage 2 output must be identical"
	@echo "      cmp $(OUT)/boot1.ll $(OUT)/boot2.ll"
	@cmp $(OUT)/boot1.ll $(OUT)/boot2.ll || { echo "[FAIL] bootstrap: stage 1 and stage 2 differ; run tools/bootstrap_until_stable.sh, then make"; exit 1; }
	@cp $(OUT)/zue_stage1 $@
	@echo "[OK] bootstrap successful: the compiler builds itself and gives the same output; installed $@"
	@cmp -s $(SEED) $(OUT)/boot1.ll || echo "[WARN] the compiler seed is older than compiler/*.zu; run make seed"
	@cmp -s $(SEED_RT) $(OUT)/boot_rt.ll || echo "[WARN] the runtime seed is older than compiler/runtime/*.zu; run make seed"

# Rewrites the seeds from the current sources. Commit them with the change that needs them.
seed: $(BINDIR)/zue
	@cp $(OUT)/boot1.ll $(SEED)
	@cp $(OUT)/boot_rt.ll $(SEED_RT)
	@echo "[OK] wrote $(SEED) and $(SEED_RT)"

test: $(BINDIR)/zue
	@compiler/run_tests.sh
	@sh test/native/run.sh
	@tools/check_thread_pointer.sh

codes-check: $(BINDIR)/zue
	@python3 tools/gen_error_codes.py --check
	@python3 tools/check_error_examples.py
	@python3 tools/check_recorded_codes.py

verify-debug: $(BINDIR)/zue
	@tools/check_debug_info.sh

verify-ir: $(BINDIR)/zue
	@VERIFY_IR=1 compiler/run_tests.sh
	@for f in examples/*.zu; do \
	    $(BINDIR)/zue emit $$f -o $(OUT)/verify.ll > /dev/null && $(OPT) -passes=verify -disable-output $(OUT)/verify.ll \
	        && echo "[PASS] $$f (IR verifier)" || { echo "[FAIL] $$f (IR verifier)"; exit 1; }; \
	done

fuzz: $(BINDIR)/zue
	@python3 tools/fuzz_expressions.py --programs 30 --per-program 100
	@python3 tools/fuzz_programs.py --programs 40
	@python3 tools/fuzz_annotations.py --count 60
	@python3 tools/fuzz_syntax_errors.py --rounds 300

round-trip: $(BINDIR)/zue
	@tools/check_round_trip.sh

clean:
	rm -rf $(BINDIR) $(OUT)

.PHONY: all seed test verify-ir verify-debug codes-check fuzz round-trip clean
