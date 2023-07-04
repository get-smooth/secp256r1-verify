// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { ECDSA } from "./utils/ECDSA.sol";
import { n } from "./utils/constants.sol";
import { U256Modp, wrap as w, _1, _2, _3, gx, gy, MINUS_2, MINUS_1 } from "./utils/U256Modp.sol";
import { nModInv } from "./utils/modInv.sol";

//// @notice Computes a step
/// @param scalar_u Multiplie1r for basepoint G
/// @param scalar_v Multiplier for input point Q
/// @param index current index
/// @return Resulting step
function getStraussShamirStep(U256Modp scalar_u, U256Modp scalar_v, U256Modp index) pure returns (U256Modp) {
    return (scalar_v.shr(index) & _1).shl(_1) + (scalar_u.shr(index) & _1);
}

//// @notice Computes uG + vQ using Strauss-Shamir's trick on the secp256r1 elliptic curve, where G is the basepoint
///           and Q is the public key.
/// @param Q0 x-coordinate of the input point Q
/// @param Q1 y-coordinate of the input point Q
/// @param scalar_u Multiplie1r for basepoint G
/// @param scalar_v Multiplier for input point Q
/// @return X Resulting x-coordinate of the computed point
/// TODO: Reduce cyclomatic complexity (from 13 to 8)
function mulmuladd(U256Modp Q0, U256Modp Q1, U256Modp scalar_u, U256Modp scalar_v) returns (U256Modp X) {
    unchecked {
        U256Modp Y;
        U256Modp index = w(255);

        // if one of the scalars is zero, return zero
        if (scalar_u.isZero() && scalar_v.isZero()) return X; // 0

        // will not work if Q=P, obvious forbidden private key
        (U256Modp H0, U256Modp H1) = ECDSA.affAdd(gx, gy, Q0, Q1);

        // @audit possible infinity loop here?
        U256Modp T4 = getStraussShamirStep(scalar_u, scalar_v, index);
        while (T4.isZero()) {
            index = index - _1;
            T4 = getStraussShamirStep(scalar_u, scalar_v, index);
        }

        U256Modp zz = getStraussShamirStep(scalar_u, scalar_v, index);

        if (zz == _1) {
            X = gx;
            Y = gy;
        } else if (zz == _2) {
            X = Q0;
            Y = Q1;
        } else if (zz == _3) {
            X = H0;
            Y = H1;
        }

        index = index - _1;
        zz = _1;
        U256Modp zzz = _1;

        for (; MINUS_1 > index; index = index - _1) {
            // U = 2*Y1, y free
            U256Modp T1 = Y * _2;

            // V=U^2
            U256Modp T2 = T1 * T1;

            // S = X1*V
            U256Modp T3 = X * T2;

            // W=UV
            T1 = T1 * T2;

            // M=3*(X1-ZZ1)*(X1+ZZ1)
            T4 = _3 * ((X + zz.inv()) * (X + zz));

            // zzz3=W*zzz1
            zzz = T1 * zzz;

            // zz3=V*ZZ1, V free
            zz = T2 * zz;

            //X3=M^2-2S
            X = (T4 * T4) + (T3 * MINUS_2);

            // -M(S-X3)=M(X3-S)
            T2 = T4 * (X + T3.inv());

            // -Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd
            Y = (T1 * Y) + T2;

            // value of dibit
            T4 = getStraussShamirStep(scalar_u, scalar_v, index);
            {
                // if T4==0, stop the loop
                if (T4.isZero()) {
                    //restore the -Y inversion
                    Y = Y.inv();
                    continue;
                }

                if (T4 == _1) {
                    T1 = gx;
                    T2 = gy;
                } else if (T4 == _2) {
                    T1 = Q0;
                    T2 = Q1;
                } else if (T4 == _3) {
                    T1 = H0;
                    T2 = H1;
                }
                if (zz.isZero()) {
                    X = T1;
                    Y = T2;
                    zz = _1;
                    zzz = _1;
                    continue;
                }

                // R
                U256Modp y2 = (T2 * zzz) + Y;

                // P
                T2 = (T1 * zz) + X.inv();

                // special extremely rare case accumulator where EcAdd is replaced by EcDbl, no optimize needed
                // TODO: construct edge vector case
                if (y2.isZero() && T2.isZero()) {
                    // U = 2*Y1, y free
                    T1 = Y * MINUS_2;

                    // V=U^2
                    T2 = T1 * T1;

                    // S = X1*V
                    T3 = X * T2;

                    y2 = X + zz;
                    U256Modp TT1A = X + zz.inv();
                    // X-ZZ)(X+ZZ)
                    y2 = y2 * TT1A;
                    // M
                    T4 = _3 * y2;

                    // zzz3=W*zzz1
                    zzz = TT1A * zzz;
                    // zz3=V*ZZ1, V free
                    zz = T2 * zz;

                    // X3=M^2-2S
                    X = (T4 * T4) + (T3 * MINUS_2);
                    // M(S-X3)
                    T2 = T4 * (T3 + X.inv());
                    // Y3=M(S-X3)-W*Y1
                    Y = T2 + (T1 * Y);

                    continue;
                }

                // PP
                T4 = T2 * T2;
                // PPP, this one could be spared, but adding this register spare gas
                U256Modp TT1 = T4 * T2;
                zz = zz * T4;
                // zz3=V*ZZ1
                zzz = zzz * TT1;
                U256Modp TT2 = X * T4;
                T4 = ((y2 * y2) + TT1.inv()) + (MINUS_2 * TT2);
                Y = ((TT2 + T4.inv()) * y2) + (Y * TT1);
                X = T4;
            }
        }
        X = X * zz.pModInv();
    }
}

/// @title ECDSA256r1
/// @notice A library to verify ECDSA signatures made on the secp256r1 curve
/// @dev This is the easiest library to deal with but also the most expensive in terms of gas cost. Indeed, this library
///      must calculate multiple points on the curve in order to verify the signature. Use it kmowingly.
/// @custom:experimental This is an experimental library.
/// @custom:warning This code is NOT intended for use with non-prime order curves due to security considerations. The
///                 code is expressly optimized for curves with a=-3 and of prime order. Constants like -1, and -2
///                 should be replaced if this code is to be utilized for any curve other than sec256R1.
library ECDSA256r1 {
    /// @notice Verifies an ECDSA signature on the secp256r1 curve given the message, signature, and public key.
    ///         This function is the only one exposed by the library
    /// @param message The original message that was signed
    /// @param r uint256 The r value of the ECDSA signature.
    /// @param s uint256 The s value of the ECDSA signature.
    /// @param qx The x value of the public key used for the signature
    /// @param qy The y value of the public key used for the signature
    /// @return bool True if the signature is valid, false otherwise
    /// @dev Note the required interactions with the precompled contract can revert the transaction
    function verify(bytes32 message, uint256 r, uint256 s, uint256 qx, uint256 qy) external returns (bool) {
        // check the validity of the signature
        if (r == 0 || r >= n || s == 0 || s >= n) {
            return false;
        }

        // check the public key is on the curve
        if (!ECDSA.affIsOnCurve(w(qx), w(qy))) {
            return false;
        }

        // calculate the scalars used for the multiplication of the point
        uint256 sInv = nModInv(s);
        uint256 scalar_u = mulmod(uint256(message), sInv, n);
        uint256 scalar_v = mulmod(r, sInv, n);
        uint256 x1 = (mulmuladd(w(qx), w(qy), w(scalar_u), w(scalar_v))).uw();
        x1 = addmod(x1, n - r, n);
        return x1 == 0;
    }
}
