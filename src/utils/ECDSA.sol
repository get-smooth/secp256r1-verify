// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { U256Modp, p, a, b, gx, gy, MINUS_2, MINUS_2MODN, MINUS_1, _0, _1, _2, _3 } from "./U256Modp.sol";

/**
 * @title ECDSA Library
 * @notice Library for handling Elliptic Curve Digital Signature Algorithm (ECDSA) operations on a compatible curve
 */
library ECDSA {
    /**
     * @notice Convert from XYZZ coordinates to affine coordinates
     *
     *         Learn more about the XYZZ representation here:
     *         https://hyperelliptic.org/EFD/g1p/auto-shortw-xyzz-3.html#addition-add-2008-s*
     * @param x The X-coordinate of the point in XYZZ representation
     * @param y The Y-coordinate of the point in XYZZ representation
     * @param zz The ZZ value of the point in XYZZ representation
     * @param zzz The ZZZ value of the point in XYZZ representation
     * @return x1 The X-coordinate of the point in affine representation
     * @return y1 The Y-coordinate of the point in affine representation
     */
    function zz2Aff(U256Modp x, U256Modp y, U256Modp zz, U256Modp zzz) internal returns (U256Modp x1, U256Modp y1) {
        // 1/zzz
        U256Modp zzzInv = zzz.pModInv();

        // Y/zzz -- OUTPUT
        y1 = y * zzzInv;

        // 1/z
        U256Modp _b = zz * zzzInv;

        // 1/zz
        zzzInv = _b * _b;

        // X/zz -- OUTPUT
        x1 = x * zzzInv;
    }

    /**
     * @notice Adds a point in XYZZ coordinates to a point in affine coordinates
     * @param x1 The X-coordinate of the first point
     * @param y1 The Y-coordinate of the first point
     * @param zz1 The ZZ value of the first point
     * @param zzz1 The ZZZ value of the first point
     * @param x2 The X-coordinate of the second point
     * @param y2 The Y-coordinate of the second point
     * @return P0 The X-coordinate of the resulting point
     * @return P1 The Y-coordinate of the resulting point
     * @return P2 The ZZ value of the resulting point
     * @return P3 The ZZZ value of the resulting point
     */
    function zzAddN(
        U256Modp x1,
        U256Modp y1,
        U256Modp zz1,
        U256Modp zzz1,
        U256Modp x2,
        U256Modp y2
    )
        internal
        pure
        returns (U256Modp P0, U256Modp P1, U256Modp P2, U256Modp P3)
    {
        unchecked {
            if (y1.isZero()) {
                return (x2, y2, _1, _1);
            }

            y1 = y1.inv();

            y2 = y2 * zzz1 + y1;

            x2 = x2 * zz1 + x1.inv();

            // PP = P^2
            P0 = x2 * x2;

            // PPP = P*PP
            P1 = P0 * x2;

            // ZZ3 = ZZ1*PP
            P2 = zz1 * P0;

            // ZZZ3 = ZZZ1*PPP
            P3 = zzz1 * P1;

            // Q = X1*PP
            zz1 = x1 * P0;

            // R^2-PPP-2*Q
            P0 = (y2 * y2 + P1.inv()) + (zz1 * MINUS_2);

            // R*(Q-X3)
            P1 = (zz1 + P0.inv()) * y2 + (y1 * P1);
        }

        return (P0, P1, P2, P3);
    }

    /**
     * @notice Performs point doubling operation in XYZZ coordinates on an elliptic curve
     * @dev This implements the "dbl-2008-s-1" doubling formulas from Sutherland's 2008 paper
     * @param x The X-coordinate of the point
     * @param y The Y-coordinate of the point
     * @param zz The ZZ value of the point
     * @param zzz The ZZZ value of the point
     * @return P0 The X-coordinate of the resulting point after doubling
     * @return P1 The Y-coordinate of the resulting point after doubling
     * @return P2 The ZZ value of the resulting point after doubling
     * @return P3 The ZZZ value of the resulting point after doubling
     */
    function zzDouble(
        U256Modp x,
        U256Modp y,
        U256Modp zz,
        U256Modp zzz
    )
        internal
        pure
        returns (U256Modp P0, U256Modp P1, U256Modp P2, U256Modp P3)
    {
        unchecked {
            // U=2*Y1
            P0 = y * _2;

            // V=U^2
            P2 = P0 * P0;

            // S = X1*V
            P3 = x * P2;

            // W=UV
            P1 = P0 * P2;

            // zz3=V*ZZ1 -- OUTPUT
            P2 = P2 * zz;

            // M=3*(X1-ZZ1)*(X1+ZZ1)
            zz = _3 * ((x + zz.inv()) * (x + zz)); //?

            // X3=M^2-2S -- OUTPUT
            P0 = zz * zz + MINUS_2 * P3;

            // M(S-X3)
            x = zz * (P3 + P0.inv());

            // zzz3=W*zzz1 -- OUTPUT
            P3 = P1 * zzz;

            // Y3= M(S-X3)-W*Y1 -- OUTPUT
            P1 = x + (P1 * y).inv();
        }
    }

    /**
     * @notice Check if a point in affine coordinates is on the curve
     * @param x The X-coordinate of the point
     * @param y The Y-coordinate of the point
     * @return bool True if the point is on the curve, false otherwise
     */
    function affIsOnCurve(U256Modp x, U256Modp y) internal pure returns (bool) {
        if (_0 == x || x == p || _0 == y || y == p) {
            return false;
        }

        unchecked {
            // y^2
            U256Modp LHS = y * y;

            // x^3+ax
            U256Modp RHS = x * x * x + a * x;

            // x^3 + a*x + b
            RHS = RHS + b;

            return LHS == RHS;
        }
    }

    /**
     * @notice Add two points on the elliptic curve in affine coordinates
     * @param x0 The X-coordinate of the first point
     * @param y0 The Y-coordinate of the first point
     * @param x1 The X-coordinate of the second point
     * @param y1 The Y-coordinate of the second point
     * @return x2 The X-coordinate of the resulting point
     * @return y2 The Y-coordinate of the resulting point
     */
    function affAdd(U256Modp x0, U256Modp y0, U256Modp x1, U256Modp y1) internal returns (U256Modp x2, U256Modp y2) {
        // check if the curve is the zero curve in affine rep
        if (y0.isZero()) {
            (x2, y2) = (x1, y1);
        } else if (y1.isZero()) {
            (x2, y2) = (x0, y0);
        } else {
            U256Modp zz0;
            U256Modp zzz0;

            (x0, y0, zz0, zzz0) = zzAddN(x0, y0, _1, _1, x1, y1);
            (x2, y2) = zz2Aff(x0, y0, zz0, zzz0);
        }
    }
}
