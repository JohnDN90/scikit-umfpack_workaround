#!/usr/bin/env bash

# =================================================================================================
# Notes
# =================================================================================================
#
# Developed by JohnDN90 (February 27, 2025)
#
# This script modifies scikit-umfpack to be compatible with newer versions of SuiteSparse. This 
# should be considered a messy workaround rather than an actual fix. It should hopefully at least
# give hints to the modifications that need to be made in scikit-umfpack itself for a permanent
# fix.
#
# Configuration used in development and testing:
#     OS:               macOS 14.7.4
#     Architecture:     AArch64
#     Compilers:        Apple Clang 16.0.0
#     Shell:            GNU bash 3.2.57(1)-release
#     Python:           3.12.9
#     pip:              24.3.1
#     Numpy:            2.2.3
#     SuiteSparse:      7.9.0
#     scikit-umfpack:   9ba622ac90350e621e84e78ed03a23d1d47807bd (November 8, 2024)
#
# The modifications this script performs are summarized as follows:
#   1) Separate SuiteSparse's umfpack.h into separate header files like in older versions (5.13.0)
#      a) These new header files are store in a temporary directory
#      b) The original umfpack.h file is unmodified
#      c) This is performed by the "separate_umfpack.sh" script
#   2) Modify pyproject.toml
#      a) Add swig as a build dependency
#      b) Change "numpy<2.0.0" to "numpy"
#      c) This is performed by the the patch file
#   3) Modify scikits/umfpack/umfpack.i
#      a) Removed "#if UMFPACK_MAIN_VERSION < 6" statements so that newly separated headers 
#         (Step 1) are included
#      b) Updated types to account for removal of "SuiteSparse_Long" type in newer SuiteSparse
#      c) This is performed by the the patch file
#   4) Modify scikits/umfpack/umfpack.py
#      a) Fixed bug in UmfpackContext.lu function which caused 64-bit indices of matrix to be 
#         converted to 32-bit
#      b) This is performed by the the patch file
#
# Running "pytest --pyargs scikits.umfpack" results in "21 passed, 9 skipped, 102 warnings"


# =================================================================================================
# User Configuration
# =================================================================================================

SCIKITUMFPACK_URL='https://github.com/scikit-umfpack/scikit-umfpack/archive/9ba622ac90350e621e84e78ed03a23d1d47807bd.tar.gz'

# SuiteSparse UMFPACK Info
# ------------------------
UMFPACK_LIB_DIR="${HOME}/Programs/AppleClangToolchain/SuiteSparse/7.9.0/Apple/lib"
UMFPACK_INCLUDE_DIR="${HOME}/Programs/AppleClangToolchain/SuiteSparse/7.9.0/Apple/include/suitesparse"


# =================================================================================================
# Download scikit-umfpack
# =================================================================================================
cd "${HOME}/Downloads"
curl -L -o scikit-umfpack.tar.gz "${SCIKITUMFPACK_URL}"
mkdir scikit-umfpack
tar xvf scikit-umfpack.tar.gz -C scikit-umfpack --strip-components 1
cd scikit-umfpack
SCIKITUMFPACK_DIR="${PWD}"


# =================================================================================================
# scikits-umfpack Build Modifications
# =================================================================================================

# Separate the umfpack.h header file into separate header files like older versions of SuiteSparse
# ------------------------------------------------------------------------------------------------
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
TMPDIR=$(dirname "$(mktemp -u)")
rm -rf "${TMPDIR}/umfpack_includes"
mkdir -p "${TMPDIR}/umfpack_includes"
cp "${UMFPACK_INCLUDE_DIR}/SuiteSparse_config.h" "${TMPDIR}/umfpack_includes/SuiteSparse_config.h"
cp "${UMFPACK_INCLUDE_DIR}/amd.h" "${TMPDIR}/umfpack_includes/amd.h"
"${SCRIPT_DIR}"/separate_umfpack.sh "${UMFPACK_INCLUDE_DIR}/umfpack.h" "${TMPDIR}/umfpack_includes"

# Apply some changes via patch
# ----------------------------
cd "${SCIKITUMFPACK_DIR}"/..
patch -s -p0 < "${SCRIPT_DIR}"/scikits-umfpack.patch


# =================================================================================================
# Build scikits-umfpack
# =================================================================================================

# Define configuration
# --------------------
echo "[properties]" > "${SCIKITUMFPACK_DIR}/nativefile.ini"
echo "umfpack-libdir = '${UMFPACK_LIB_DIR}'" >> "${SCIKITUMFPACK_DIR}/nativefile.ini"
echo "umfpack-includedir = '${TMPDIR}/umfpack_includes'" >> "${SCIKITUMFPACK_DIR}/nativefile.ini"

# Build using pip
# ---------------
cd "${SCIKITUMFPACK_DIR}" && \
pip install . -Csetup-args=--native-file="$PWD"/nativefile.ini \
    --trusted-host pypi.org --trusted-host files.pythonhosted.org --trusted-host pypi.python.org meson-python


# =================================================================================================
# Tests
# =================================================================================================
cd "${HOME}"

# Test that we can import scikits.umfpack
# ---------------------------------------
python -c "import scikits.umfpack as um" && \
echo "Python was able to import scikits.umfpack successfully."

# Run the built in tests if pytest is installed
# ---------------------------------------------
if pytest --version 2>&1 >/dev/null; then
    pytest --pyargs scikits.umfpack
fi

# Run a custom test script
# ------------------------
python "${SCRIPT_DIR}/test.py" && echo "Test script exited without error."


# =================================================================================================
# Cleanup
# =================================================================================================
rm -rf "${TMPDIR}/umfpack_includes"
