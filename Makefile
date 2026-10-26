# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 GibblyGobbly

# Zue source -> LLVM IR -> native binary (clang).
#
#   make            build bin/zue from the seeds in bootstrap/ (needs clang 18)
#   make test       compile and run every test, compare with test/expected/
#   make verify-ir  run the tests and check every generated IR file with LLVM's verifier (opt)
#   make LLVM=22    use clang-22 and opt-22 (any target)
#   make fuzz       compare random expressions and programs with an independent model (needs python3)
#   make round-trip parse every Zue file, print it back with zue unparse, and compare the trees
#   make seed       refresh the seeds after changing compiler/ or compiler/runtime/
#   make clean      remove build output
#
# bootstrap/zuec.ll and bootstrap/zue_rt_native.ll are the LLVM IR of the compiler and the
# runtime, kept in the repository so the first compiler can be built with clang alone.

ifeq (,$(filter -j%,$(MAKEFLAGS)))
MAKEFLAGS += -j$(shell nproc)
endif

# The LLVM toolchain: "make LLVM=22" uses clang-22 and opt-22. By default clang and opt-18.
# Objects built by one version are not reused by another: run "make clean" when switching.
LLVM ?=
ifeq ($(LLVM),)
CLANG = clang
OPT = opt-18
else
CLANG = clang-$(LLVM)
OPT = opt-$(LLVM)
endif
export CC := $(CLANG)
export OPT
BINDIR = bin
OUT = C

LIBS = -lm -lpthread -ldl

SEED = bootstrap/zuec.ll
SEED_RT = bootstrap/zue_rt_native.ll
COMPILER_LU = $(wildcard compiler/*.zu)
RT_LU = $(sort $(wildcard compiler/runtime/*.zu))

all: $(BINDIR)/zue

# seeds -> seed compiler -> runtime and compiler IR of the current sources -> compiler ->
# IR again. The two compiler IR files must match.
$(BINDIR)/zue: $(SEED) $(SEED_RT) $(COMPILER_LU) $(RT_LU)
	@mkdir -p $(BINDIR) $(OUT)
	@$(CLANG) -O1 -w $(SEED) $(SEED_RT) $(LIBS) -o $(OUT)/zue_seed
	@$(OUT)/zue_seed --native $(RT_LU) -o $(OUT)/boot_rt.ll
	@$(OUT)/zue_seed compiler/zuec.zu $(OUT)/boot1.ll .
	@$(CLANG) -O1 -w $(OUT)/boot1.ll $(OUT)/boot_rt.ll $(LIBS) -o $(OUT)/zue_stage1
	@$(OUT)/zue_stage1 compiler/zuec.zu $(OUT)/boot2.ll .
	@cmp $(OUT)/boot1.ll $(OUT)/boot2.ll
	@cp $(OUT)/zue_stage1 $@
	@echo "[OK] built $@"
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

round-trip: $(BINDIR)/zue
	@tools/check_round_trip.sh

clean:
	rm -rf $(BINDIR) $(OUT)

.PHONY: all seed test verify-ir fuzz round-trip clean
