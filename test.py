import numpy as np
import scipy.sparse.linalg
import scikits.umfpack as um

# Setup
# -----
n = 50
A = scipy.sparse.rand(n, n, density = 0.25**2)
A = A.T.dot(A) + 0.001 * scipy.sparse.eye(n)
x_exact = scipy.sparse.rand(n, 1, density = 1.0).toarray()
x2_exact = scipy.sparse.rand(n, 1, density = 1.0).toarray()
xs_exact = scipy.sparse.rand(n, 1, density=0.25)
b = A.dot(x_exact)
b2 = A.dot(x2_exact)
bs = A.dot(xs_exact)
C = A + np.pi * A * 1j
tol = 10 * (np.finfo(np.float64).eps**0.8)

xc_exact = np.random.uniform(-1, 1, (n, 1)) + np.random.uniform(-1, 1, (n, 1)) * 1j
bc = C.dot(xc_exact)

Al = A.copy()
Al.indices = Al.indices.astype(np.int64)
Al.indptr = Al.indptr.astype(np.int64)

Cl = C.copy()
Cl.indices = Cl.indices.astype(np.int64)
Cl.indptr = Cl.indptr.astype(np.int64)


# Easy-to-use UMFPACK interface
# -----------------------------
x = um.spsolve(A, b)
assert abs(x - x_exact.ravel()).max() < tol, "FAIL: spsolve(A, b) gave wrong result."

LU = um.splu(A)

lu = um.UmfpackLU(A)
x2 = lu.solve(b2).ravel()
assert abs(x2 - x2_exact.ravel()).max() < tol, "FAIL: lu.solve(b) gave wrong result."
xs = lu.solve_sparse(bs)
assert abs(xs - xs_exact).max() < tol, "FAIL: lu.solve_sparse(b) gave wrong result."

lu.shape
lu.L
lu.U
lu.R
lu.perm_c
lu.perm_r
lu.nnz


# Low-level UMFPACK interface
# ---------------------------
def testLowLevel(family, A, b, x_exact):
	umfpack = um.UmfpackContext(family)
	umfpack.control[um.UMFPACK_PRL] = 4 # Let's be more verbose.
	umfpack.control[um.UMFPACK_PRL] = 3 # Change print level back
	umfpack.report_control()
	umfpack.symbolic(A)
	umfpack.report_symbolic()
	umfpack.numeric(A)
	umfpack.report_numeric()
	x = umfpack.solve(um.UMFPACK_A, A, b.ravel(), autoTranspose=True)
	assert abs(x - x_exact.ravel()).max() < tol, "FAIL: umfpack.solve(...) gave wrong result. %.16g" % (abs(x - x_exact.ravel()).max())
	x = umfpack.linsolve(um.UMFPACK_A, A, b.ravel(), autoTranspose=True)
	assert abs(x - x_exact.ravel()).max() < tol, "FAIL: umfpack.linsolve(...) gave wrong result. %.16g" % (abs(x - x_exact.ravel()).max())
	x = umfpack(um.UMFPACK_A, A, b.ravel(), autoTranspose=True)
	assert abs(x - x_exact.ravel()).max() < tol, "FAIL: umfpack.__call__(...) gave wrong result. %.16g" % (abs(x - x_exact.ravel()).max())
	umfpack.report_info()
	L, U, P, Q, R, do_recip = umfpack.lu(A)
	umfpack.free_numeric()
	umfpack.free_symbolic()
	umfpack.free()

# Test with sparse matrices stored as CSR
testLowLevel("di", A, b, x_exact)
testLowLevel("dl", Al, b, x_exact)
testLowLevel("zi", C, bc, xc_exact)
testLowLevel("zl", Cl, bc, xc_exact)


# Test with sparse matrices stored as CSC
def convert_to_csc(A):
	if isinstance(A, scipy.sparse.coo_matrix):
		if (A.row.dtype == np.int64) or (A.col.dtype == np.int64):
			ind64 = True
		else:
			ind64 = False
	else:
		if (A.indices.dtype == np.int64) or (A.indptr.dtype == np.int64):
			ind64 = True
		else:
			ind64 = False
	A = A.tocsc()
	if ind64:
	    A.indices = A.indices.astype(np.int64)
	    A.indptr = A.indptr.astype(np.int64)
	return A

testLowLevel("di", convert_to_csc(A), b, x_exact)
testLowLevel("dl", convert_to_csc(Al), b, x_exact)
testLowLevel("zi", convert_to_csc(C), bc, xc_exact)
testLowLevel("zl", convert_to_csc(Cl), bc, xc_exact)

print("\nMade it to the end of the test script.")
