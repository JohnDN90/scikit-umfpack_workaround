Developed by JohnDN90 (February 27, 2025)

This script modifies [scikit-umfpack](https://github.com/scikit-umfpack/scikit-umfpack) to be
compatible with newer versions of SuiteSparse.

This should be considered a messy workaround for the issues discussed in issue [#98](https://github.com/scikit-umfpack/scikit-umfpack/issues/98)
of scikit-umfpack/scikit-umfpack rather than an actual fix. It should hopefully at least give hints
to the modifications that need to be made in scikit-umfpack itself for a permanent fix.

Configuration used in development and testing:
- OS:               macOS 14.7.4
- Architecture:     AArch64
- Compilers:        Apple Clang 16.0.0
- Shell:            GNU bash 3.2.57(1)-release
- Python:           3.12.9
- pip:              24.3.1
- Numpy:            2.2.3
- SuiteSparse:      [7.9.0](https://github.com/DrTimothyAldenDavis/SuiteSparse/tree/v7.9.0)
- scikit-umfpack:   [9ba622ac90350e621e84e78ed03a23d1d47807bd](https://github.com/scikit-umfpack/scikit-umfpack/tree/9ba622ac90350e621e84e78ed03a23d1d47807bd) (November 8, 2024)

The modifications this script performs are summarized as follows:
1) Separate SuiteSparse's umfpack.h into separate header files like in older versions ([5.13.0](https://github.com/DrTimothyAldenDavis/SuiteSparse/tree/v5.13.0))
    - These new header files are stored in a temporary directory
    - The original umfpack.h file is unmodified
    - This is performed by the [separate_umfpack.sh](./separate_umfpack.sh) script
2) Modify [pyproject.toml](https://github.com/scikit-umfpack/scikit-umfpack/blob/9ba622ac90350e621e84e78ed03a23d1d47807bd/pyproject.toml)
    - Add swig as a build dependency
    - Change `numpy<2.0.0` to `numpy`
    - This is performed by the the patch file
3) Modify [scikits/umfpack/umfpack.i](https://github.com/scikit-umfpack/scikit-umfpack/blob/9ba622ac90350e621e84e78ed03a23d1d47807bd/scikits/umfpack/umfpack.i)
    - Removed `#if UMFPACK_MAIN_VERSION < 6` statements so that newly separated headers (Step 1) are included
    - Updated types to account for removal of "SuiteSparse_Long" type in newer SuiteSparse
    - This is performed by the the patch file
4) Modify [scikits/umfpack/umfpack.py](https://github.com/scikit-umfpack/scikit-umfpack/blob/9ba622ac90350e621e84e78ed03a23d1d47807bd/scikits/umfpack/umfpack.py)
    - Fixed bug in [UmfpackContext.lu](https://github.com/scikit-umfpack/scikit-umfpack/blob/9ba622ac90350e621e84e78ed03a23d1d47807bd/scikits/umfpack/umfpack.py#L849C9-L849C12) function which caused 64-bit indices of matrix to be converted to 32-bit
    - This is performed by the the patch file

Running `pytest --pyargs scikits.umfpack` results in "21 passed, 9 skipped, 102 warnings"
