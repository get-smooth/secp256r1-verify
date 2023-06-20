// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import "./secp256r1.sol" as Curve;
import { p, a, b, gx, gy, n, MINUS_2, MINUS_2MODN, MINUS_1, MODEXP_PRECOMPILE } from "./secp256r1.sol";

/**
 * @title ECDSA Library
 * @notice Library for handling Elliptic Curve Digital Signature Algorithm (ECDSA) operations on a compatible curve
 */
library ECDSA {
    using { Curve.pModInv, Curve.nModInv } for uint256;

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
    function zz2Aff(uint256 x, uint256 y, uint256 zz, uint256 zzz) internal returns (uint256 x1, uint256 y1) {
        // 1/zzz
        uint256 zzzInv = zzz.pModInv();

        // Y/zzz -- OUTPUT
        y1 = mulmod(y, zzzInv, p);

        // 1/z
        uint256 _b = mulmod(zz, zzzInv, p);

        // 1/zz
        zzzInv = mulmod(_b, _b, p);

        // X/zz -- OUTPUT
        x1 = mulmod(x, zzzInv, p);
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
        uint256 x1,
        uint256 y1,
        uint256 zz1,
        uint256 zzz1,
        uint256 x2,
        uint256 y2
    )
        internal
        pure
        returns (uint256 P0, uint256 P1, uint256 P2, uint256 P3)
    {
        if (y1 == 0) {
            return (x2, y2, 1, 1);
        }

        assembly ("memory-safe") {
            y1 := sub(p, y1)
            y2 := addmod(mulmod(y2, zzz1, p), y1, p)
            x2 := addmod(mulmod(x2, zz1, p), sub(p, x1), p)

            // PP = P^2
            P0 := mulmod(x2, x2, p)

            // PPP = P*PP
            P1 := mulmod(P0, x2, p)

            // ZZ3 = ZZ1*PP
            P2 := mulmod(zz1, P0, p)

            // ZZZ3 = ZZZ1*PPP
            P3 := mulmod(zzz1, P1, p)

            // Q = X1*PP
            zz1 := mulmod(x1, P0, p)

            // R^2-PPP-2*Q
            P0 := addmod(addmod(mulmod(y2, y2, p), sub(p, P1), p), mulmod(MINUS_2, zz1, p), p)

            // R*(Q-X3)
            P1 := addmod(mulmod(addmod(zz1, sub(p, P0), p), y2, p), mulmod(y1, P1, p), p)
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
        uint256 x,
        uint256 y,
        uint256 zz,
        uint256 zzz
    )
        internal
        pure
        returns (uint256 P0, uint256 P1, uint256 P2, uint256 P3)
    {
        assembly ("memory-safe") {
            // U=2*Y1
            P0 := mulmod(2, y, p)

            // V=U^2
            P2 := mulmod(P0, P0, p)

            // S = X1*V
            P3 := mulmod(x, P2, p)

            // W=UV
            P1 := mulmod(P0, P2, p)

            // zz3=V*ZZ1 -- OUTPUT
            P2 := mulmod(P2, zz, p)

            // M=3*(X1-ZZ1)*(X1+ZZ1)
            zz := mulmod(3, mulmod(addmod(x, sub(p, zz), p), addmod(x, zz, p), p), p)

            // X3=M^2-2S -- OUTPUT
            P0 := addmod(mulmod(zz, zz, p), mulmod(MINUS_2, P3, p), p)

            // M(S-X3)
            x := mulmod(zz, addmod(P3, sub(p, P0), p), p)

            // zzz3=W*zzz1 -- OUTPUT
            P3 := mulmod(P1, zzz, p)

            // Y3= M(S-X3)-W*Y1 -- OUTPUT
            P1 := addmod(x, sub(p, mulmod(P1, y, p)), p)
        }
    }

    /**
     * @notice Check if a point in affine coordinates is on the curve
     * @param x The X-coordinate of the point
     * @param y The Y-coordinate of the point
     * @return bool True if the point is on the curve, false otherwise
     */
    function affIsOnCurve(uint256 x, uint256 y) internal pure returns (bool) {
        if (0 == x || x == p || 0 == y || y == p) {
            return false;
        }

        unchecked {
            // y^2
            uint256 LHS = mulmod(y, y, p);

            // x^3+ax
            uint256 RHS = addmod(mulmod(mulmod(x, x, p), x, p), mulmod(x, a, p), p);

            // x^3 + a*x + b
            RHS = addmod(RHS, b, p);

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
    function affAdd(uint256 x0, uint256 y0, uint256 x1, uint256 y1) internal returns (uint256 x2, uint256 y2) {
        // check if the curve is the zero curve in affine rep
        if (y0 == 0 || y1 == 0) {
            (x2, y2) = (x1, y1);
        } else {
            uint256 zz0;
            uint256 zzz0;

            (x0, y0, zz0, zzz0) = zzAddN(x0, y0, 1, 1, x1, y1);
            (x2, y2) = zz2Aff(x0, y0, zz0, zzz0);
        }
    }
}
