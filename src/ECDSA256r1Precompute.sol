// SPDX-License-Identifier: APACHE-2.0
pragma solidity >=0.8.19 <0.9.0;

import { Curve, p, n, MINUS_2, MODEXP_PRECOMPILE } from "./utils/ECDSA.sol";

/// @title ECDSA256r1Precompute
/// @notice This library is for ECDSA verification using a precomputed shamir table of 256 points. The Shamir's
///         Secret Sharing scheme is used in 8 dimensions. The precomputed table must be stored in an external contract
///         upstream.
/// @dev    This library is way more gas efficient than the ECDSA256r1 library, but it requires a precomputed table of
///         multiples of P and Q. How does it works? Everytime you want to verify a signature you first need to compute
///         256 points on the curve from the public key then pushing those points as the bytecode of a new contract. The
///         address of this contract is then passed to the verify function of this library in order to read the
///         precomputed table. The reading process uses the `extcodecopy` opcode to read the bytecode of the provided
///         contract (the precomputed points) in an efficient way.
///
///         More info on the `extcodecopy` opcode: https://www.evm.codes/#3c
///         How to generate the precomputed table: github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation
/// @custom:experimental This is an experimental library.
library ECDSA256r1Precompute {
    using { Curve.nModInv } for uint256;

    /// @notice Executes Shamir's trick over 8 dimensions, using precomputations stored as bytecode of an external
    ///         contract at the given precomputedTable address
    /// @param scalar_u The first scalar for the Shamir's trick computation.
    /// @param scalar_v The second scalar for the Shamir's trick computation.
    /// @param precomputedTable The address of the external contract containing the precomputations for Shamir's trick.
    /// @return X Resulting x-coordinate of the computed point
    /// @dev The external tool to generate tables from the public key is listed in the documentation of the contract
    function mulmuladd(uint256 scalar_u, uint256 scalar_v, address precomputedTable) internal returns (uint256 X) {
        // third and  coordinates of the point
        uint256 zz = 256;
        uint256[6] memory T;

        unchecked {
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
        }

        assembly {
            extcodecopy(precomputedTable, T, mload(T), 64)
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
                    let T1 := add(T2, add(shl(10, and(shr(index, scalar_v), 1)), shl(6, and(shr(index, scalar_u), 1))))

                    //TODO: TBD check validity of formulae with (0,1) to remove conditional jump
                    if iszero(T1) {
                        Y := sub(p, Y)

                        continue
                    }
                    extcodecopy(precomputedTable, T, T1, 64)
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

            zz := mload(T)
            // X/zz
            X := mulmod(X, zz, p)
        }
    }

    /// @notice Verifies an ECDSA signature using a precomputed table of multiples of P and Q stored in an external
    ///         contract
    /// @param message The message to verify
    /// @param rs tuple [r, s] representing the ECDSA signature
    /// @param precomputedTable The address of the external contract containing the precomputations for Shamir's trick.
    ///        It is expected the contract store the precomputations as its bytecode. The contract is not supposed
    ///        to be functional.
    /// @return True if the signature is valid, false otherwise.
    /// @dev Note the required interactions with the precompled contract can revert the transaction
    function verify(bytes32 message, uint256[2] calldata rs, address precomputedTable) external returns (bool) {
        // check the validity of the signature
        if (rs[0] == 0 || rs[0] >= n || rs[1] == 0 || rs[1] >= n) {
            return false;
        }

        // perform the Shamir's trick in order to calculate the x coordinate of the point
        uint256 sInv = rs[1].nModInv();
        uint256 X = mulmuladd(mulmod(uint256(message), sInv, n), mulmod(rs[0], sInv, n), precomputedTable);

        assembly {
            X := addmod(X, sub(n, calldataload(rs)), n)
        }

        return X == 0;
    }
}
