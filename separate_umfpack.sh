#!/usr/bin/env bash

# =================================================================================================
# Notes
# =================================================================================================
#
# Developed by JohnDN90 (February 27, 2025)
#
# This script splits SuiteSparse's umfpack.h header file into separate header files similar to the
# style used in older versions of SuiteSparse (e.g. 5.13.0). The original umfpack.h file is 
# unmodified.
#
# This script is intended to be called by "install_scikits-umfpack.sh" which implements a 
# workaround to make scikit-umfpack (9ba622ac) compatible with newer versions of SuiteSparse.
#
# Configuration used in development and testing:
#     OS:               macOS 14.7.4
#     Architecture:     AArch64
#     Compilers:        Apple Clang 16.0.0
#     Shell:            GNU bash 3.2.57(1)-release
#     SuiteSparse:      7.9.0
#
# The first argument should be "/path/to/umfpack.h" and the second argument should be the directory
# to which the newly generated header files are output. The output directory must be different 
# than the directory where "umfpack.h" is stored.


# Variables
INPUT="${1}"
OUTDIR="${2}"

# Error Chceking
if [[ "$(basename "${INPUT}")" != "umfpack.h" ]]; then
  echo "ERROR: Input file must be umfpack.h. Exiting..."
  exit 2
fi

if [ -z "${OUTDIR}" ]; then
  echo "ERROR: Output directory must be specified as second argument."
  exit 3
fi

if [[ "$(basename "${INPUT}")" == "${OUTDIR}" ]]; then
  echo "ERROR: Output directory must be different than the directory which contains umfpack.h"
  exit 4
fi


# Function to extract user-callable functions to a separate header file
extract_to_file() {
  STARTSTR="// umfpack_${1}"

  INFILE="${INPUT}"
  OUTFILE="${OUTDIR}/umfpack_${1// /_}.h"

  echo ""
  echo "${STARTSTR}"
  echo "${INPUT}"
  echo "${OUTFILE}"
  echo ""

  # Check if the input file exists.
  if [ ! -f "${INFILE}" ]; then
    echo "Error: Input file 'umfpack.h' not found." >&2
    exit 1
  fi

  # Copy the segment of code to a new include file
  echo "//------------------------------------------------------------------------------" > "${OUTFILE}"
  awk -v STARTSTR2="${STARTSTR}" \
       -v DELIMITER1="//------------------------------------------------------------------------------" \
       -v DELIMITER2="//==============================================================================" '

    BEGIN {
      start_copying=0
      delimiter_count=0
    }

    index($0, STARTSTR2) == 1 {
      start_copying=1
    }

    start_copying == 1 {
      if ($0 == DELIMITER1) {
        delimiter_count++
        if (delimiter_count == 2) {
          exit
        }
      } else if ($0 == DELIMITER2) {
        exit
      }
      print $0
    }' "${INFILE}" | cat >> "${OUTFILE}"


  # Check if the output file was created successfully.
  if [ ! -f "${OUTFILE}" ]; then
    echo "Error: Failed to create output file '${OUTFILE}'." >&2
    exit 1
  fi

  echo "Successfully extracted lines to '${OUTFILE}'."
}


# Backup the original umfpack.h file just in case
cp "${INPUT}" "${INPUT}.original"

OUTPUTS=(
version symbolic numeric solve free_symbolic free_numeric defaults qsymbolic
paru wsolve triplet_to_col col_to_triplet transpose scale get_lunz get_numeric
get_symbolic save_numeric load_numeric copy_numeric serialize_numeric_size 
serialize_numeric deserialize_numeric save_symbolic load_symbolic copy_symbolic
serialize_symbolic_size serialize_symbolic deserialize_symbolic get_determinant
report_status report_info report_control report_matrix report_triplet 
report_vector report_symbolic report_numeric report_perm timer 
"tic and umfpack_toc" 
)

# Extract the user-callable routines to separate header files, like older versions of SuiteSparse
for name in "${OUTPUTS[@]}"; do
  extract_to_file "${name}"
done

# Truncate some extra lines that inadvertently get copied to the end of umfpack_tic_and_umfpack_toc.h
mv "${OUTDIR}/umfpack_tic_and_umfpack_toc.h" "${OUTDIR}/umfpack_tic_and_umfpack_toc.h.bak"
head -n 40 "${OUTDIR}/umfpack_tic_and_umfpack_toc.h.bak" > "${OUTDIR}/umfpack_tic_and_umfpack_toc.h"

# Modify umfpack.h to look like older versions of SuiteSparse
TEMP="${OUTDIR}/umfpack.h"
rm -f "${TEMP}"

while IFS= read -r line; do
  if [ "$line" = "//==============================================================================" ]; then
    break
  fi
  printf "%s\n" "$line" >> "${TEMP}"
done < "${INPUT}.original"
echo "" >> "${TEMP}"
echo '#ifdef __cplusplus' >> "${TEMP}"
echo 'extern "C" {' >> "${TEMP}"
echo '#endif' >> "${TEMP}"
echo "" >> "${TEMP}"
for name in "${OUTPUTS[@]}"; do
  echo "#include \"umfpack_${name// /_}.h\"" >> "${TEMP}"
done
echo "" >> "${TEMP}"
echo "#ifdef __cplusplus" >> "${TEMP}"
echo "}" >> "${TEMP}"
echo "#endif" >> "${TEMP}"
echo "" >> "${TEMP}"
echo "#endif /* UMFPACK_H */"  >> "${TEMP}"
echo "" >> "${TEMP}"
