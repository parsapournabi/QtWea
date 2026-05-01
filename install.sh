#!/bin/bash
# Script to build and install the QtWea meta-package.
# Supports cross-platform builds (Linux, macOS, Windows) and custom CMake arguments.

# --- Strict Error Handling ---
# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error when substituting.
# Pipelines return the exit status of the last command to exit non-zero, or zero if all exit successfully.
set -euo pipefail

# --- Configuration Defaults ---
DEFAULT_INSTALL_PREFIX="" # Let CMake decide based on CMAKE_INSTALL_PREFIX default
DEFAULT_GENERATOR=""      # Let CMake decide based on the platform
BUILD_TYPE="Release"      # Default build type
PARALLEL_JOBS=""          # Let CMake decide or use system defaults

# --- Available Modules (adjust as needed) ---
AVAILABLE_MODULES=("WeaCore" "WeaQuick") # Example modules

# --- Helper Functions ---
show_help() {
    echo "Usage: $0 [options] [--cmake-arg <arg1>] [--cmake-arg <arg2>] ..."
    echo ""
    echo "Builds and installs the QtWea meta-package."
    echo ""
    echo "Options:"
    echo "  --modules <list>       Comma-separated list of modules to enable (e.g., WeaCore,WeaQuick). Default: all available."
    echo "  --install-dir <path>   Installation directory (overrides CMAKE_INSTALL_PREFIX)."
    echo "  --build-dir <path>     Directory for CMake build files. Default: build."
    echo "  --generator <name>     CMake generator to use (e.g., 'MinGW Makefiles', 'Ninja'). Default: determined by platform."
    echo "  --build-type <type>    CMake build type (e.g., Release, Debug, RelWithDebInfo). Default: Release."
    echo "  --parallel [jobs]      Enable parallel building. Optionally specify the number of jobs."
    echo "  --cmake-arg <arg>      Pass a custom argument to CMake (e.g., -DCMAKE_PREFIX_PATH=/path/to/libs)."
    echo "                         Can be used multiple times."
    echo "  --help                 Show this help message and exit."
    echo ""
    echo "Example:"
    echo "  $0 --modules WeaCore --install-dir ~/QtWea --cmake-arg \"-DCMAKE_PREFIX_PATH=/opt/Qt5\""
    echo "  $0 --parallel 8 --build-type Debug"
}

# --- Detect OS and Set Defaults ---
OS="$(uname -s)"
case "${OS}" in
    Linux*)     DEFAULT_GENERATOR="Unix Makefiles" ;;
    Darwin*)    DEFAULT_GENERATOR="Xcode" ;; # Or "Ninja" if available
    CYGWIN*|MINGW*|MSYS*) DEFAULT_GENERATOR="MinGW Makefiles" ;; # For Windows with MinGW
    *)          echo "Warning: Unsupported OS '${OS}'. Using default CMake generator." ;;
esac

# --- Argument Parsing ---
MODULES_TO_BUILD=()
INSTALL_PREFIX="${DEFAULT_INSTALL_PREFIX}" # Start with default, override if --install-dir is given
CMAKE_GENERATOR="${DEFAULT_GENERATOR}"
BUILD_DIR="build" # Default build directory
BUILD_TYPE_ARG="${BUILD_TYPE}" # Store the build type
EXTRA_CMAKE_ARGS=() # Array to hold extra arguments passed via --cmake-arg

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        --modules)
            shift
            IFS=',' read -r -a MODULES_TO_BUILD <<< "$2"
            ;;
        --install-dir)
            shift
            INSTALL_PREFIX="$2"
            ;;
        --build-dir)
            shift
            BUILD_DIR="$2"
            ;;
        --generator)
            shift
            CMAKE_GENERATOR="$2"
            ;;
        --build-type)
            shift
            BUILD_TYPE_ARG="$2"
            ;;
        --parallel)
            shift
            if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
                PARALLEL_JOBS="$1"
                shift
            else
                PARALLEL_JOBS="-j" # Use default parallel jobs
            fi
            ;;
        --cmake-arg)
            shift
            if [[ "$#" -eq 0 || "$1" == --* ]]; then
                echo "Error: --cmake-arg requires an argument (e.g., -DCMAKE_PREFIX_PATH=/path)." >&2
                show_help
                exit 1
            fi
            EXTRA_CMAKE_ARGS+=("$1") # Add the argument to our array
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        -h|--h)
            show_help
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            show_help
            exit 1
            ;;
    esac
done

# --- Validate Modules ---
# If no modules were specified, default to all available
if [ ${#MODULES_TO_BUILD[@]} -eq 0 ]; then
    MODULES_TO_BUILD=("${AVAILABLE_MODULES[@]}")
fi

# Check if specified modules are valid
VALID_MODULES=()
for mod in "${MODULES_TO_BUILD[@]}"; do
    is_valid=0
    for avail_mod in "${AVAILABLE_MODULES[@]}"; do
        if [[ "$mod" == "$avail_mod" ]]; then
            VALID_MODULES+=("$mod")
            is_valid=1
            break
        fi
    done
    if [[ $is_valid -eq 0 ]]; then
        echo "Error: Unknown module '$mod'. Available modules are: ${AVAILABLE_MODULES[*]}" >&2
        exit 1
    fi
done
MODULES_TO_BUILD=("${VALID_MODULES[@]}") # Use only the validated modules

# --- Prepare CMake Arguments ---
CMAKE_ARGS=()

# Always set CMAKE_INSTALL_PREFIX if provided
if [[ -n "${INSTALL_PREFIX}" ]]; then
    CMAKE_ARGS+=("-DCMAKE_INSTALL_PREFIX=${INSTALL_PREFIX}")
fi

# Set the generator
CMAKE_ARGS+=("-G${CMAKE_GENERATOR}")

# Set the build type
CMAKE_ARGS+=("-DCMAKE_BUILD_TYPE=${BUILD_TYPE_ARG}")

# Add any extra CMake arguments provided by the user
CMAKE_ARGS+=("${EXTRA_CMAKE_ARGS[@]}")

# Add flags for enabling/disabling modules
echo "Configuring modules: ${MODULES_TO_BUILD[*]}"
for mod in "${AVAILABLE_MODULES[@]}"; do
    enable_flag="OFF"
    for build_mod in "${MODULES_TO_BUILD[@]}"; do
        if [[ "$mod" == "$build_mod" ]]; then
            enable_flag="ON"
            break
        fi
    done
    CMAKE_ARGS+=("-DENABLE_${mod}=${enable_flag}")
done

# --- Prepare Build Directory ---
if [[ ! -d "${BUILD_DIR}" ]]; then
    echo "Creating build directory: ${BUILD_DIR}"
    mkdir -p "${BUILD_DIR}"
fi
cd "${BUILD_DIR}"

# --- CMake Configure ---
echo "Running CMake configuration..."
echo "Source directory: $(pwd)/.." # CMakeLists.txt is expected in the parent directory
echo "CMake Arguments: ${CMAKE_ARGS[*]}"

# Use '..' to refer to the parent directory where the root CMakeLists.txt is located
cmake .. "${CMAKE_ARGS[@]}"

# --- CMake Build ---
echo "Building QtWea..."
BUILD_COMMAND="cmake --build ."
if [[ -n "${PARALLEL_JOBS}" ]]; then
    BUILD_COMMAND+=" --parallel ${PARALLEL_JOBS}"
fi
echo "Executing: ${BUILD_COMMAND}"
eval "${BUILD_COMMAND}" # Use eval to correctly handle parallel jobs argument

# --- CMake Install ---
echo "Installing QtWea..."
INSTALL_COMMAND="cmake --install ."
if [[ -n "${PARALLEL_JOBS}" ]]; then
    INSTALL_COMMAND+=" --parallel ${PARALLEL_JOBS}"
fi
echo "Executing: ${INSTALL_COMMAND}"
eval "${INSTALL_COMMAND}"

echo "QtWea build and installation complete."
cd .. # Go back to the original directory

exit 0
