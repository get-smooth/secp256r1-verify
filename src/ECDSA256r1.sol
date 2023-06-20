// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { ECDSA, Curve, p, gx, gy, n, MINUS_2, MINUS_1, MODEXP_PRECOMPILE } from "./utils/ECDSA.sol";

/// @title ECDSA256r1
/// @notice A library to verify ECDSA signatures made on the secp256r1 curve
/// @dev This is the easiest library to deal with but also the most expensive in terms of gas cost. Indeed, this library
///      must calculate multiple points on the curve in order to verify the signature. Use it kmowingly.
/// @custom:experimental This is an experimental library.
/// @custom:warning This code is NOT intended for use with non-prime order curves due to security considerations. The
///                 code is expressly optimized for curves with a=-3 and of prime order. Constants like -1, and -2
///                 should be replaced if this code is to be utilized for any curve other than sec256R1.
library ECDSA256r1 {
    using { Curve.nModInv } for uint256;

    //// @notice Computes uG + vQ using Strauss-Shamir's trick on the secp256r1 elliptic curve, where G is the basepoint
    ///           and Q is the public key.
    /// @param Q0 x-coordinate of the input point Q
    /// @param Q1 y-coordinate of the input point Q
    /// @param scalar_u Multiplier for basepoint G
    /// @param scalar_v Multiplier for input point Q
    /// @return X Resulting x-coordinate of the computed point
    function mulmuladd(uint256 Q0, uint256 Q1, uint256 scalar_u, uint256 scalar_v) internal returns (uint256 X) {
        uint256 zz;
        uint256 zzz;
        uint256 Y;
        uint256 index = 255;
        uint256[6] memory T;
        uint256 H0;
        uint256 H1;

        unchecked {
            if (scalar_u == 0 && scalar_v == 0) return 0;

            // will not work if Q=P, obvious forbidden private key
            (H0, H1) = ECDSA.affAdd(gx, gy, Q0, Q1);

            assembly {
                for { let T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1)) } eq(T4, 0) {
                    index := sub(index, 1)
                    T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))
                } { }
                zz := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                if eq(zz, 1) {
                    X := gx
                    Y := gy
                }
                if eq(zz, 2) {
                    X := Q0
                    Y := Q1
                }
                if eq(zz, 3) {
                    X := H0
                    Y := H1
                }

                index := sub(index, 1)
                zz := 1
                zzz := 1

                // inlined EcZZ_Dbl
                for { } gt(MINUS_1, index) { index := sub(index, 1) } {
                    // U = 2*Y1, y free
                    let T1 := mulmod(2, Y, p)
                    // V=U^2
                    let T2 := mulmod(T1, T1, p)
                    // S = X1*V
                    let T3 := mulmod(X, T2, p)
                    // W=UV
                    T1 := mulmod(T1, T2, p)
                    // M=3*(X1-ZZ1)*(X1+ZZ1)
                    let T4 := mulmod(3, mulmod(addmod(X, sub(p, zz), p), addmod(X, zz, p), p), p)
                    // zzz3=W*zzz1
                    zzz := mulmod(T1, zzz, p)
                    // zz3=V*ZZ1, V free
                    zz := mulmod(T2, zz, p)
                    //X3=M^2-2S
                    X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                    // -M(S-X3)=M(X3-S)
                    T2 := mulmod(T4, addmod(X, sub(p, T3), p), p)
                    // -Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd
                    Y := addmod(mulmod(T1, Y, p), T2, p)

                    {
                        //value of dibit
                        T4 := add(shl(1, and(shr(index, scalar_v), 1)), and(shr(index, scalar_u), 1))

                        // loop until T4 != 0
                        if iszero(T4) {
                            //restore the -Y inversion
                            Y := sub(p, Y)
                            continue
                        }

                        if eq(T4, 1) {
                            T1 := gx
                            T2 := gy
                        }
                        if eq(T4, 2) {
                            T1 := Q0
                            T2 := Q1
                        }
                        if eq(T4, 3) {
                            T1 := H0
                            T2 := H1
                        }
                        if eq(zz, 0) {
                            X := T1
                            Y := T2
                            zz := 1
                            zzz := 1
                            continue
                        }
                        // inlined EcZZ_AddN
                        // R
                        let y2 := addmod(mulmod(T2, zzz, p), Y, p)
                        // P
                        T2 := addmod(mulmod(T1, zz, p), sub(p, X), p)

                        // special extremely rare case accumulator where EcAdd is replaced by EcDbl, no optimize needed
                        // TODO: construct edge vector case
                        if eq(y2, 0) {
                            if eq(T2, 0) {
                                // U = 2*Y1, y free
                                T1 := mulmod(MINUS_2, Y, p)
                                // V=U^2
                                T2 := mulmod(T1, T1, p)
                                // S = X1*V
                                T3 := mulmod(X, T2, p)

                                y2 := addmod(X, zz, p)
                                let TT1 := addmod(X, sub(p, zz), p)
                                // X-ZZ)(X+ZZ)
                                y2 := mulmod(y2, TT1, p)
                                // M
                                T4 := mulmod(3, y2, p)

                                // zzz3=W*zzz1
                                zzz := mulmod(TT1, zzz, p)
                                // zz3=V*ZZ1, V free
                                zz := mulmod(T2, zz, p)

                                // X3=M^2-2S
                                X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                                // M(S-X3)
                                T2 := mulmod(T4, addmod(T3, sub(p, X), p), p)
                                // Y3=M(S-X3)-W*Y1
                                Y := addmod(T2, mulmod(T1, Y, p), p)

                                continue
                            }
                        }

                        // PP
                        T4 := mulmod(T2, T2, p)
                        // PPP, this one could be spared, but adding this register spare gas
                        let TT1 := mulmod(T4, T2, p)
                        zz := mulmod(zz, T4, p)
                        // zz3=V*ZZ1
                        zzz := mulmod(zzz, TT1, p)
                        let TT2 := mulmod(X, T4, p)
                        T4 := addmod(addmod(mulmod(y2, y2, p), sub(p, TT1), p), mulmod(MINUS_2, TT2, p), p)
                        Y := addmod(mulmod(addmod(TT2, sub(p, T4), p), y2, p), mulmod(Y, TT1, p), p)

                        X := T4
                    }
                }

                // TODO: JOHN -- Internal this one ?
                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(add(T, 0x60), zz)
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                // Define variables base, exponent and modulus
                mstore(add(T, 0x40), 0x20)
                mstore(add(T, 0x80), MINUS_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract ModExp (0x05)
                if iszero(call(not(0), MODEXP_PRECOMPILE, 0, T, 0xc0, T, 0x20)) { revert(0, 0) }

                // X/zz
                X := mulmod(X, mload(T), p)
            }
        }

        return X;
    }

    /// @notice Verifies an ECDSA signature on the secp256r1 curve given the message, signature, and public key.
    ///         This function is the only one exposed by the library
    /// @param message The original message that was signed
    /// @param rs uint256[2] The r and s values of the ECDSA signature.
    /// @param Q The public key used for the signature, in the format [Qx, Qy]
    /// @return bool True if the signature is valid, false otherwise
    /// @dev Note the required interactions with the precompled contract can revert the transaction
    function verify(bytes32 message, uint256[2] calldata rs, uint256[2] calldata Q) external returns (bool) {
        // check the validity of the signature
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0 || rs[1] >= n) {
            return false;
        }

        // check the public key is on the curve
        if (!ECDSA.affIsOnCurve(Q[0], Q[1])) {
            return false;
        }

        // calculate the scalars used for the multiplication of the point
        uint256 sInv = rs[1].nModInv();
        uint256 scalar_u = mulmod(uint256(message), sInv, n);
        uint256 scalar_v = mulmod(rs[0], sInv, n);

        uint256 x1 = mulmuladd(Q[0], Q[1], scalar_u, scalar_v);

        assembly {
            x1 := addmod(x1, sub(n, calldataload(rs)), n)
        }

        return x1 == 0;
    }
}
