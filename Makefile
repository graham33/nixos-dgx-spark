# Simple Makefile to compile CUDA debug program outside of Nix
# This assumes you have CUDA toolkit installed locally

NVCC = nvcc
TARGET = cuda-debug
SOURCE = cuda-debug.cu

# Hardcoded compute capabilities - adjust as needed
COMPUTE_CAPS = 120

# Generate CUBIN for specific architecture and PTX for forward compatibility
GENCODE_FLAGS = --generate-code arch=compute_$(COMPUTE_CAPS),code=sm_$(COMPUTE_CAPS) \
                --generate-code arch=compute_$(COMPUTE_CAPS),code=compute_$(COMPUTE_CAPS)

# Standard flags
CUDA_LIBS = -lcuda -lcudart
NVCC_FLAGS = -O2

all: $(TARGET)

$(TARGET): $(SOURCE)
	$(NVCC) $(NVCC_FLAGS) $(GENCODE_FLAGS) -o $(TARGET) $(SOURCE) $(CUDA_LIBS)
	@echo "Built $(TARGET) with compute capability $(COMPUTE_CAPS) (both CUBIN and PTX)"

clean:
	rm -f $(TARGET)

# Helper target to show what command will be run
show:
	@echo "$(NVCC) $(NVCC_FLAGS) $(GENCODE_FLAGS) -o $(TARGET) $(SOURCE) $(CUDA_LIBS)"

.PHONY: all clean show