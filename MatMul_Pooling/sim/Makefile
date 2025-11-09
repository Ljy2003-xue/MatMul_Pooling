# VCS commands
VCS = vcs
VCS_FLAGS = -full64 -sverilog +v2k -debug_access+all +define+FSDB +lint=all,noVCDE +vcs+lic+wait
SIMV = ./simv
URG = urg

# Source directories
SRC_DIR = ../src
TB_DIR = ../tb

# Source files
SOURCES = $(SRC_DIR)/matmul_top.v $(SRC_DIR)/mem_top.v $(TB_DIR)/tb_top.v
FILELIST = filelist.f

# Default target
all: compile run

# Compile using filelist
compile:
	$(VCS) $(VCS_FLAGS) -f $(FILELIST) -o $(SIMV) -l compile.log

# Compile individual files
compile_direct:
	$(VCS) $(VCS_FLAGS) $(SOURCES) -o $(SIMV) -l compile.log

# Run simulation
run:
	$(SIMV) -l simulation.log

# Run simulation with GUI (DVE)
run_gui:
	$(SIMV) -gui -l simulation.log

# Generate coverage report
coverage:
	$(URG) -dir simv.vdb -report coverage_report

# Clean generated files
clean:
	rm -rf simv simv.daidir csrc DVEfiles *.log *.vpd *.fsdb *.key *.vcd coverage_report

# Clean everything (including coverage data)
clean_all:
	rm -rf simv simv.daidir csrc DVEfiles *.log *.vpd *.fsdb *.key *.vcd coverage_report simv.vdb

# Display help
help:
	@echo "Available targets:"
	@echo "  all           - Compile and run simulation (default)"
	@echo "  compile       - Compile using filelist.f"
	@echo "  compile_direct - Compile by directly specifying files"
	@echo "  run           - Run simulation"
	@echo "  run_gui       - Run simulation with DVE GUI"
	@echo "  coverage      - Generate coverage report"
	@echo "  clean         - Remove generated files"
	@echo "  clean_all     - Remove all generated files including coverage data"
	@echo "  help          - Display this help message"

.PHONY: all compile compile_direct run run_gui coverage clean clean_all help
