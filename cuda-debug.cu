#include <cuda_runtime.h>
#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>

void checkCudaError(cudaError_t error, const char* operation) {
    if (error != cudaSuccess) {
        printf("ERROR: %s failed: %s (code %d)\n", operation, cudaGetErrorString(error), error);
    } else {
        printf("SUCCESS: %s\n", operation);
    }
}

void checkCuError(CUresult result, const char* operation) {
    if (result != CUDA_SUCCESS) {
        const char* errorStr;
        cuGetErrorString(result, &errorStr);
        printf("ERROR: %s failed: %s (code %d)\n", operation, errorStr, result);
    } else {
        printf("SUCCESS: %s\n", operation);
    }
}

int main() {
    printf("=== CUDA Initialization Debug ===\n");

    // Check what we can see before trying to init
    printf("0. Pre-initialization checks...\n");
    printf("   Checking if CUDA runtime can be loaded...\n");

    // Try runtime API first (doesn't require driver init)
    int runtimeVersion;
    cudaError_t error = cudaRuntimeGetVersion(&runtimeVersion);
    checkCudaError(error, "cudaRuntimeGetVersion");
    if (error == cudaSuccess) {
        printf("   CUDA Runtime version: %d.%d\n", runtimeVersion / 1000, (runtimeVersion % 100) / 10);
    }

    // Check if CUDA Driver API is available
    printf("\n1. Initializing CUDA Driver API...\n");
    CUresult cuResult = cuInit(0);
    checkCuError(cuResult, "cuInit(0)");
    if (cuResult != CUDA_SUCCESS) {
        printf("   cuInit failed - trying to continue with Runtime API only...\n");

        // Try runtime API device count without driver init
        printf("\n1b. Trying Runtime API without driver init...\n");
        int deviceCount;
        error = cudaGetDeviceCount(&deviceCount);
        checkCudaError(error, "cudaGetDeviceCount (runtime only)");
        printf("Device count from runtime: %d\n", deviceCount);

        // Check what compute capabilities this binary was compiled for
        printf("\n1c. Checking compiled compute capabilities...\n");
        #if defined(__CUDA_ARCH_LIST__)
            // Create an array from the __CUDA_ARCH_LIST__ macro
            int archs[] = {__CUDA_ARCH_LIST__};
            int numArchs = sizeof(archs) / sizeof(archs[0]);

            printf("This binary was compiled for %d compute capabilities:\n", numArchs);
            for (int i = 0; i < numArchs; i++) {
                int major = archs[i] / 100;
                int minor = (archs[i] % 100) / 10;
                printf("  %d.%d (arch=%d)\n", major, minor, archs[i]);
            }
        #else
            printf("(no __CUDA_ARCH_LIST__ defined)\n");
        #endif

        // Try to get device properties using driver API even though init failed
        printf("\n1d. Attempting to get device info via driver API...\n");
        int driverDeviceCount;
        CUresult countResult = cuDeviceGetCount(&driverDeviceCount);
        if (countResult == CUDA_SUCCESS) {
            printf("Driver API device count: %d\n", driverDeviceCount);
            if (driverDeviceCount > 0) {
                CUdevice device;
                CUresult deviceResult = cuDeviceGet(&device, 0);
                if (deviceResult == CUDA_SUCCESS) {
                    int major, minor;
                    cuDeviceGetAttribute(&major, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MAJOR, device);
                    cuDeviceGetAttribute(&minor, CU_DEVICE_ATTRIBUTE_COMPUTE_CAPABILITY_MINOR, device);
                    printf("Device 0 compute capability: %d.%d\n", major, minor);
                }
            }
        } else {
            const char* errorStr;
            cuGetErrorString(countResult, &errorStr);
            printf("cuDeviceGetCount also failed: %s\n", errorStr);
        }

        return 1;
    }

    // Check device count first
    printf("\n2. Checking device count...\n");
    int deviceCount;
    error = cudaGetDeviceCount(&deviceCount);
    checkCudaError(error, "cudaGetDeviceCount");
    printf("Device count: %d\n", deviceCount);

    if (deviceCount == 0) {
        printf("No CUDA devices found!\n");
        return 1;
    }

    // Try to get properties of first device
    printf("\n3. Checking first device properties...\n");
    cudaDeviceProp prop;
    error = cudaGetDeviceProperties(&prop, 0);
    checkCudaError(error, "cudaGetDeviceProperties(0)");
    if (error == cudaSuccess) {
        printf("Device 0: %s (Compute %d.%d)\n", prop.name, prop.major, prop.minor);
    }

    // Try to set device
    printf("\n4. Setting device 0...\n");
    error = cudaSetDevice(0);
    checkCudaError(error, "cudaSetDevice(0)");

    // Try to query memory
    printf("\n5. Querying memory info...\n");
    size_t free, total;
    error = cudaMemGetInfo(&free, &total);
    checkCudaError(error, "cudaMemGetInfo");

    // Try a simple memory allocation
    printf("\n6. Testing memory allocation...\n");
    void* ptr;
    error = cudaMalloc(&ptr, 1024);
    checkCudaError(error, "cudaMalloc(1KB)");
    if (error == cudaSuccess) {
        error = cudaFree(ptr);
        checkCudaError(error, "cudaFree");
    }

    // Check for any accumulated errors
    printf("\n7. Final error check...\n");
    error = cudaGetLastError();
    checkCudaError(error, "cudaGetLastError");

    printf("\n=== Debug Complete ===\n");
    return 0;
}