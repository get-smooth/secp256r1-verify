// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

/**
 * TODO: JOHN
 *         - [ ] Better manage the pre-compile
 *         - [ ] Create Secp256r1Base using only internal functions
 *         - [ ] Create variants (standard, precomput, interleave, memhack)
 *         - [ ] Clean the libraries
 *         - [ ] NatSpec everything
 */

library Secp256r1 {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/
    // prime field modulus of the secp256r1 curve
    uint256 internal constant p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    // short weierstrass first coefficient
    uint256 internal constant a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    // short weierstrass second coefficient
    uint256 internal constant b = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    // the affine coordinates of the generating point on the curve
    uint256 internal constant gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    uint256 internal constant gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    // the order of the curve, i.e., the number of points on the curve
    uint256 internal constant n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    // -2 mod(p), used to accelerate inversion and doubling operations by avoiding negation
    uint256 internal constant MINUS_2 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD;
    // -2 mod(n), used to speed up inversion operations
    uint256 internal constant MINUS_2MODN = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63254F;
    // the representation of -1 in this field
    uint256 internal constant MINUS_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    /**
     * /* inversion mod n via a^(n-2), use of precompiled using little Fermat theorem
     */
    function nModInv(uint256 u) internal returns (uint256 result) {
        uint256[6] memory pointer;
        assembly {
            // Define length of base, exponent and modulus. 0x20 == 32 bytes
            mstore(pointer, 0x20)
            mstore(add(pointer, 0x20), 0x20)
            mstore(add(pointer, 0x40), 0x20)
            // Define variables base, exponent and modulus
            mstore(add(pointer, 0x60), u)
            mstore(add(pointer, 0x80), MINUS_2MODN)
            mstore(add(pointer, 0xa0), n)

            // Call the precompiled contract 0x05 = ModExp
            if iszero(call(not(0), 0x05, 0, pointer, 0xc0, pointer, 0x20)) { revert(0, 0) }
            result := mload(pointer)
        }
    }
    /**
     * /* @dev inversion mod nusing little Fermat theorem via a^(n-2), use of precompiled
     */

    function pModInv(uint256 u) internal returns (uint256 result) {
        uint256[6] memory pointer;
        assembly {
            // Define length of base, exponent and modulus. 0x20 == 32 bytes
            mstore(pointer, 0x20)
            mstore(add(pointer, 0x20), 0x20)
            mstore(add(pointer, 0x40), 0x20)
            // Define variables base, exponent and modulus
            mstore(add(pointer, 0x60), u)
            mstore(add(pointer, 0x80), MINUS_2)
            mstore(add(pointer, 0xa0), p)

            // Call the precompiled contract 0x05 = ModExp
            if iszero(call(not(0), 0x05, 0, pointer, 0xc0, pointer, 0x20)) { revert(0, 0) }
            result := mload(pointer)
        }
    }

    /**
     * /* @dev Convert from affine rep to XYZZ rep
     */
    function ecAff_SetZZ(uint256 x0, uint256 y0) internal pure returns (uint256[4] memory P) {
        unchecked {
            // ZZ
            P[2] = 1;
            // ZZZ
            P[3] = 1;
            P[0] = x0;
            P[1] = y0;
        }
    }

    /**
     * /* @dev Convert from XYZZ rep to affine rep
     */
    /*    https://hyperelliptic.org/EFD/g1p/auto-shortw-xyzz-3.html#addition-add-2008-s*/
    function ecZZ_SetAff(uint256 x, uint256 y, uint256 zz, uint256 zzz) internal returns (uint256 x1, uint256 y1) {
        // 1/zzz
        uint256 zzzInv = pModInv(zzz);

        // Y/zzz
        y1 = mulmod(y, zzzInv, p);

        // 1/z
        uint256 _b = mulmod(zz, zzzInv, p);

        // 1/zz
        zzzInv = mulmod(_b, _b, p);

        // X/zz
        x1 = mulmod(x, zzzInv, p);
    }

    /**
     * @dev Sutherland2008 add a ZZ point with a normalized point and greedy formulae
     * warning: assume that P1(x1,y1)!=P2(x2,y2), true in multiplication loop with prime order (cofactor 1)
     */
    function ecZZ_AddN(
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
        unchecked {
            if (y1 == 0) {
                return (x2, y2, 1, 1);
            }

            assembly {
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
        }

        return (P0, P1, P2, P3);
    }

    /**
     * @dev Check if a point in affine coordinates is on the curve (reject Neutral that is indeed on the curve).
     */
    function ecAff_isOnCurve(uint256 x, uint256 y) internal pure returns (bool) {
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
     * @dev Add two elliptic curve points in affine coordinates.
     */
    function ecAff_add(uint256 x0, uint256 y0, uint256 x1, uint256 y1) internal returns (uint256, uint256) {
        // check if the curve is the zero curve in affine rep
        if (y0 == 0) return (x1, y1);
        if (y1 == 0) return (x1, y1);

        uint256 zz0;
        uint256 zzz0;
        (x0, y0, zz0, zzz0) = ecZZ_AddN(x0, y0, 1, 1, x1, y1);

        return ecZZ_SetAff(x0, y0, zz0, zzz0);
    }

    /**
     * @dev Computation of uG+vQ using Strauss-Shamir's trick, G basepoint, Q public key
     */
    // uint256 Q1, //affine rep for input point Q
    function ecZZ_mulmuladd_S_asm(
        uint256 Q0,
        uint256 Q1, //affine rep for input point Q
        uint256 scalar_u,
        uint256 scalar_v
    )
        internal
        returns (uint256 X)
    {
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
            (H0, H1) = ecAff_add(gx, gy, Q0, Q1);

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

                                // W=UV
                                let TT1 := mulmod(T1, T2, p)
                                y2 := addmod(X, zz, p)
                                TT1 := addmod(X, sub(p, zz), p)
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

                mstore(add(T, 0x60), zz)
                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                mstore(add(T, 0x80), MINUS_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(call(not(0), 0x05, 0, T, 0xc0, T, 0x20)) { revert(0, 0) }

                // X/zz
                X := mulmod(X, mload(T), p)
            }
        }

        return X;
    }

    //8 dimensions Shamir's trick, using precomputations stored in Shamir8,  stored as Bytecode of an external
    //contract at given address dataPointer
    //(thx to Lakhdar https://github.com/Kelvyne for EVM storage explanations and tricks)
    // the external tool to generate tables from public key is in the /sage directory
    function ecZZ_mulmuladd_S8_extcode(
        uint256 scalar_u,
        uint256 scalar_v,
        address dataPointer
    )
        internal
        returns (uint256 X)
    {
        unchecked {
            // third and  coordinates of the point
            uint256 zz = 256;

            uint256[6] memory T;

            while (T[0] == 0) {
                zz = zz - 1;
                //TODO: TBD case of msb octobit is null
                T[0] = 64
                    * (
                        128 * ((scalar_v >> zz) & 1) + 64 * ((scalar_v >> (zz - 64)) & 1)
                            + 32 * ((scalar_v >> (zz - 128)) & 1) + 16 * ((scalar_v >> (zz - 192)) & 1)
                            + 8 * ((scalar_u >> zz) & 1) + 4 * ((scalar_u >> (zz - 64)) & 1)
                            + 2 * ((scalar_u >> (zz - 128)) & 1) + ((scalar_u >> (zz - 192)) & 1)
                    );
            }

            assembly {
                extcodecopy(dataPointer, T, mload(T), 64)
                let index := sub(zz, 1)
                X := mload(T)
                let Y := mload(add(T, 32))
                let zzz := 1
                zz := 1

                // loop over 1/4 of scalars thx to Shamir's trick over 8 points
                for { } gt(index, 191) { index := add(index, 191) } {
                    {
                        // U = 2*Y1, y free
                        let TT1 := mulmod(2, Y, p)
                        // V=U^2
                        let T2 := mulmod(TT1, TT1, p)
                        // S = X1*V
                        let T3 := mulmod(X, T2, p)
                        // W=UV
                        let T1 := mulmod(TT1, T2, p)
                        // M=3*(X1-ZZ1)*(X1+ZZ1)
                        let T4 := mulmod(3, mulmod(addmod(X, sub(p, zz), p), addmod(X, zz, p), p), p)
                        // zzz3=W*zzz1
                        zzz := mulmod(T1, zzz, p)
                        // zz3=V*ZZ1, V free
                        zz := mulmod(T2, zz, p)

                        // X3=M^2-2S
                        X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)

                        // -M(S-X3)=M(X3-S)
                        let T5 := mulmod(T4, addmod(X, sub(p, T3), p), p)

                        // -Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in
                        Y := addmod(mulmod(T1, Y, p), T5, p)
                    }

                    /* compute element to access in precomputed table */
                    {
                        let T4 := add(shl(13, and(shr(index, scalar_v), 1)), shl(9, and(shr(index, scalar_u), 1)))
                        let index2 := sub(index, 64)
                        let T3 :=
                            add(T4, add(shl(12, and(shr(index2, scalar_v), 1)), shl(8, and(shr(index2, scalar_u), 1))))
                        let index3 := sub(index2, 64)
                        let T2 :=
                            add(T3, add(shl(11, and(shr(index3, scalar_v), 1)), shl(7, and(shr(index3, scalar_u), 1))))
                        index := sub(index3, 64)
                        let T1 :=
                            add(T2, add(shl(10, and(shr(index, scalar_v), 1)), shl(6, and(shr(index, scalar_u), 1))))

                        //TODO: TBD check validity of formulae with (0,1) to remove conditional jump
                        if iszero(T1) {
                            Y := sub(p, Y)

                            continue
                        }
                        extcodecopy(dataPointer, T, T1, 64)
                    }

                    /* Access to precomputed table using extcodecopy hack */
                    {
                        if iszero(zz) {
                            X := mload(T)
                            Y := mload(add(T, 32))
                            zz := 1
                            zzz := 1

                            continue
                        }

                        let y2 := addmod(mulmod(mload(add(T, 32)), zzz, p), Y, p)
                        let T2 := addmod(mulmod(mload(T), zz, p), sub(p, X), p)

                        // special case ecAdd(P,P)=EcDbl
                        if eq(y2, 0) {
                            if eq(T2, 0) {
                                // U = 2*Y1, y free
                                let T1 := mulmod(MINUS_2, Y, p)
                                // V=U^2
                                T2 := mulmod(T1, T1, p)
                                // S = X1*V
                                let T3 := mulmod(X, T2, p)
                                // W=UV
                                let TT1 := mulmod(T1, T2, p)
                                y2 := addmod(X, zz, p)
                                TT1 := addmod(X, sub(p, zz), p)
                                //(X-ZZ)(X+ZZ)
                                y2 := mulmod(y2, TT1, p)
                                // M
                                let T4 := mulmod(3, y2, p)
                                // zzz3=W*zzz1
                                zzz := mulmod(TT1, zzz, p)
                                // zz3=V*ZZ1, V free
                                zz := mulmod(T2, zz, p)
                                // X3=M^2-2S
                                X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                                // M(S-X3)
                                T2 := mulmod(T4, addmod(T3, sub(p, X), p), p)
                                // Y3= M(S-X3)-W*Y1
                                Y := addmod(T2, mulmod(T1, Y, p), p)

                                continue
                            }
                        }

                        let T4 := mulmod(T2, T2, p)
                        let T1 := mulmod(T4, T2, p)
                        zz := mulmod(zz, T4, p)
                        // W=UV
                        zzz := mulmod(zzz, T1, p)
                        let zz1 := mulmod(X, T4, p)
                        X := addmod(addmod(mulmod(y2, y2, p), sub(p, T1), p), mulmod(MINUS_2, zz1, p), p)
                        Y := addmod(mulmod(addmod(zz1, sub(p, X), p), y2, p), mulmod(Y, T1, p), p)
                    }
                }
                mstore(add(T, 0x60), zz)

                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                mstore(add(T, 0x80), MINUS_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(call(not(0), 0x05, 0, T, 0xc0, T, 0x20)) { revert(0, 0) }

                zz := mload(T)
                // X/zz
                X := mulmod(X, zz, p)
            }
        }
    }

    //compute the wnaf reprensentation of a positive scalar
    function ecZZ_wnaf(uint256 scalar) public pure returns (bytes memory wnaf, uint256 length) {
        bytes memory temp = new bytes(300);
        uint8 ki;

        while (scalar > 0) {
            if (scalar & 1 == 1) {
                ki = uint8(scalar % 256);
                temp[length] = bytes1(ki);
                if (ki >= 128) {
                    scalar += 256;
                }
                scalar -= uint256(ki);
            }
            scalar = scalar / 2;
            length = length + 1;
        }

        return (temp, length);
    }

    // Taking scalars directly interleaved to avoid to perform it in contract
    function ecZZ_mulmuladd_interleaved(
        uint256 scalar_high,
        uint256 scalar_low,
        address dataPointer
    )
        internal
        returns (uint256 X)
    {
        unchecked {
            // third and  coordinates of the point
            uint256 zz;
            if ((scalar_high & scalar_low) == 0) {
                return 0;
            }
            uint256[6] memory T;
            // start index
            zz = 248;

            while (((scalar_high >> zz) & 0xff) == 0) {
                zz -= 8;
                if (zz == 0) {
                    // first test prevent infinite loop on (0,0) input
                    scalar_high = scalar_low;
                    zz = 248;
                }
            }
            T[0] = scalar_high >> zz;
            zz -= 8;
            if (zz == 0) {
                // first test prevent infinite loop on (0,0) input
                scalar_high = scalar_low;
                zz = 248;
            }

            assembly {
                extcodecopy(dataPointer, T, mload(T), 64)
                let index := zz
                X := mload(T)
                let Y := mload(add(T, 32))
                let zzz := 1
                zz := 1
                let highdone := 0

                // loop over 1/4 of scalars thx to Shamir's trick over 8 points
                for { } gt(index, 0) { index := sub(index, 8) } {
                    // inline Double
                    {
                        // U = 2*Y1, y free
                        let TT1 := mulmod(2, Y, p)
                        // V=U^2
                        let T2 := mulmod(TT1, TT1, p)
                        // S = X1*V
                        let T3 := mulmod(X, T2, p)
                        // W=UV
                        let T1 := mulmod(TT1, T2, p)
                        // M=3*(X1-ZZ1)*(X1+ZZ1)
                        let T4 := mulmod(3, mulmod(addmod(X, sub(p, zz), p), addmod(X, zz, p), p), p)
                        // zzz3=W*zzz1
                        zzz := mulmod(T1, zzz, p)
                        // zz3=V*ZZ1, V free
                        zz := mulmod(T2, zz, p)

                        // X3=M^2-2S
                        X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                        // -M(S-X3)=M(X3-S)
                        let T5 := mulmod(T4, addmod(X, sub(p, T3), p), p)

                        //-Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub inecAdd
                        Y := addmod(mulmod(T1, Y, p), T5, p)
                    }
                    /* compute element to access in precomputed table */
                    {
                        let T1 := and(shr(index, scalar_high), 0xff)
                        // TODO: TBD check validity of formulae with (0,1) to remove conditional jump
                        if iszero(T1) {
                            Y := sub(p, Y)

                            continue
                        }
                        extcodecopy(dataPointer, T, T1, 64)
                        if eq(8, index) {
                            if iszero(highdone) {
                                highdone := 1
                                scalar_high := scalar_low
                                index := 248
                            }
                        }
                    }

                    /* Access to precomputed table using extcodecopy hack */
                    {
                        // inlined EcZZ_AddN
                        if iszero(zz) {
                            X := mload(T)
                            Y := mload(add(T, 32))
                            zz := 1
                            zzz := 1

                            continue
                        }

                        let y2 := addmod(mulmod(mload(add(T, 32)), zzz, p), Y, p)
                        let T2 := addmod(mulmod(mload(T), zz, p), sub(p, X), p)

                        // special case ecAdd(P,P)=EcDbl
                        if eq(y2, 0) {
                            if eq(T2, 0) {
                                // U = 2*Y1, y free
                                let T1 := mulmod(MINUS_2, Y, p)
                                // V=U^2
                                T2 := mulmod(T1, T1, p)
                                // S = X1*V
                                let T3 := mulmod(X, T2, p)
                                // W=UV
                                let TT1 := mulmod(T1, T2, p)
                                y2 := addmod(X, zz, p)
                                TT1 := addmod(X, sub(p, zz), p)
                                // (X-ZZ)(X+ZZ)
                                y2 := mulmod(y2, TT1, p)
                                // M
                                let T4 := mulmod(3, y2, p)
                                // zzz3=W*zzz1
                                zzz := mulmod(TT1, zzz, p)
                                // zz3=V*ZZ1, V free
                                zz := mulmod(T2, zz, p)
                                // X3=M^2-2S
                                X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                                // M(S-X3)
                                T2 := mulmod(T4, addmod(T3, sub(p, X), p), p)
                                // Y3= M(S-X3)-W*Y1
                                Y := addmod(T2, mulmod(T1, Y, p), p)

                                continue
                            }
                        }

                        let T4 := mulmod(T2, T2, p)
                        let T1 := mulmod(T4, T2, p)
                        zz := mulmod(zz, T4, p)
                        // W=UV
                        zzz := mulmod(zzz, T1, p)
                        let zz1 := mulmod(X, T4, p)
                        X := addmod(addmod(mulmod(y2, y2, p), sub(p, T1), p), mulmod(MINUS_2, zz1, p), p)
                        Y := addmod(mulmod(addmod(zz1, sub(p, X), p), y2, p), mulmod(Y, T1, p), p)
                    }
                }

                mstore(add(T, 0x60), zz)

                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                mstore(add(T, 0x80), MINUS_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(call(not(0), 0x05, 0, T, 0xc0, T, 0x20)) { revert(0, 0) }

                zz := mload(T)
                X := mulmod(X, zz, p)
            }
        }
    }

    // improving the extcodecopy trick : append array at end of contract
    function ecZZ_mulmuladd_S8_hackmem(
        uint256 scalar_u,
        uint256 scalar_v,
        uint256 dataPointer
    )
        internal
        returns (uint256 X)
    {
        // third and  coordinates of the point
        uint256 zz = 256;
        uint256[6] memory T;

        unchecked {
            while (T[0] == 0) {
                zz = zz - 1;
                // TODO: TBD case of msb octobit is null
                T[0] = 64
                    * (
                        128 * ((scalar_v >> zz) & 1) + 64 * ((scalar_v >> (zz - 64)) & 1)
                            + 32 * ((scalar_v >> (zz - 128)) & 1) + 16 * ((scalar_v >> (zz - 192)) & 1)
                            + 8 * ((scalar_u >> zz) & 1) + 4 * ((scalar_u >> (zz - 64)) & 1)
                            + 2 * ((scalar_u >> (zz - 128)) & 1) + ((scalar_u >> (zz - 192)) & 1)
                    );
            }
            assembly {
                codecopy(T, add(mload(T), dataPointer), 64)
                X := mload(T)
                let Y := mload(add(T, 32))
                let zzz := 1
                zz := 1

                // loop over 1/4 of scalars thx to Shamir's trick over 8 points
                for { let index := 254 } gt(index, 191) { index := add(index, 191) } {
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
                    // X3=M^2-2S
                    X := addmod(mulmod(T4, T4, p), mulmod(MINUS_2, T3, p), p)
                    // -M(S-X3)=M(X3-S)
                    T2 := mulmod(T4, addmod(X, sub(p, T3), p), p)
                    // -Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in ecAdd
                    Y := addmod(mulmod(T1, Y, p), T2, p)

                    /* compute element to access in precomputed table */
                    T4 := add(shl(13, and(shr(index, scalar_v), 1)), shl(9, and(shr(index, scalar_u), 1)))
                    index := sub(index, 64)
                    T4 := add(T4, add(shl(12, and(shr(index, scalar_v), 1)), shl(8, and(shr(index, scalar_u), 1))))
                    index := sub(index, 64)
                    T4 := add(T4, add(shl(11, and(shr(index, scalar_v), 1)), shl(7, and(shr(index, scalar_u), 1))))
                    index := sub(index, 64)
                    T4 := add(T4, add(shl(10, and(shr(index, scalar_v), 1)), shl(6, and(shr(index, scalar_u), 1))))

                    // TODO: TBD check validity of formulae with (0,1) to remove conditional jump
                    if iszero(T4) {
                        Y := sub(p, Y)

                        continue
                    }
                    /* Access to precomputed table using extcodecopy hack */
                    {
                        codecopy(T, add(T4, dataPointer), 64)

                        // inlined EcZZ_AddN
                        let y2 := addmod(mulmod(mload(add(T, 32)), zzz, p), Y, p)
                        T2 := addmod(mulmod(mload(T), zz, p), sub(p, X), p)
                        T4 := mulmod(T2, T2, p)
                        T1 := mulmod(T4, T2, p)
                        // W=UV
                        T2 := mulmod(zz, T4, p)
                        //zz3=V*ZZ1
                        zzz := mulmod(zzz, T1, p)
                        let zz1 := mulmod(X, T4, p)
                        T4 := addmod(addmod(mulmod(y2, y2, p), sub(p, T1), p), mulmod(MINUS_2, zz1, p), p)
                        Y := addmod(mulmod(addmod(zz1, sub(p, T4), p), y2, p), mulmod(Y, T1, p), p)
                        zz := T2
                        X := T4
                    }
                }
                mstore(add(T, 0x60), zz)

                // Define length of base, exponent and modulus. 0x20 == 32 bytes
                mstore(T, 0x20)
                mstore(add(T, 0x20), 0x20)
                mstore(add(T, 0x40), 0x20)
                // Define variables base, exponent and modulus
                mstore(add(T, 0x80), MINUS_2)
                mstore(add(T, 0xa0), p)

                // Call the precompiled contract 0x05 = ModExp
                if iszero(call(not(0), 0x05, 0, T, 0xc0, T, 0x20)) { revert(0, 0) }

                zz := mload(T)
                // X/zz
                X := mulmod(X, zz, p)
            }
        }
    }

    /**
     * @dev ECDSA verification, given , signature, and public key.
     */
    function verify(bytes32 message, uint256[2] calldata rs, uint256[2] calldata Q) internal returns (bool) {
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0 || rs[1] >= n) {
            return false;
        }

        if (!ecAff_isOnCurve(Q[0], Q[1])) {
            return false;
        }

        uint256 sInv = nModInv(rs[1]);
        uint256 scalar_u = mulmod(uint256(message), sInv, n);
        uint256 scalar_v = mulmod(rs[0], sInv, n);
        uint256 x1 = ecZZ_mulmuladd_S_asm(Q[0], Q[1], scalar_u, scalar_v);

        assembly {
            x1 := addmod(x1, sub(n, calldataload(rs)), n)
        }

        return x1 == 0;
    }

    /**
     * @dev ECDSA verification using a precomputed table of multiples of P and Q stored in contract at address Shamir8
     */
    function verify(bytes32 message, uint256[2] calldata rs, address Shamir8) internal returns (bool) {
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0 || rs[1] >= n) {
            return false;
        }

        uint256 sInv = nModInv(rs[1]);

        // Shamir 8 dimensions
        uint256 X = ecZZ_mulmuladd_S8_extcode(mulmod(uint256(message), sInv, n), mulmod(rs[0], sInv, n), Shamir8);

        assembly {
            X := addmod(X, sub(n, calldataload(rs)), n)
        }

        return X == 0;
    }

    // interleaved
    function verify(uint256 scalar_u, uint256 scalar_v, uint256 scalar_r, address Shamir8) internal returns (bool) {
        // Shamir 8 dimensions
        uint256 X = ecZZ_mulmuladd_interleaved(scalar_u, scalar_v, Shamir8);

        assembly {
            X := addmod(X, sub(n, scalar_r), n)
        }

        return X == 0;
    }

    /**
     * @dev ECDSA verification using a precomputed table of multiples of P and Q appended at end of contract at address
     * endcontract
     *     generation of contract bytecode for precomputations is done using sagemath code
     *     (see sage directory, WebAuthn_precompute.sage)
     */
    function verify(bytes32 message, uint256[2] calldata rs, uint256 endcontract) internal returns (bool) {
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0) {
            return false;
        }

        uint256 sInv = nModInv(rs[1]);
        //Shamir 8 dimensions
        uint256 X = ecZZ_mulmuladd_S8_hackmem(mulmod(uint256(message), sInv, n), mulmod(rs[0], sInv, n), endcontract);

        assembly {
            X := addmod(X, sub(n, calldataload(rs)), n)
        }

        return X == 0;
    }
}
