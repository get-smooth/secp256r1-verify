// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { p, n, MINUS_2 } from "./utils/constants.sol";
import { pModInv, nModInv } from "./utils/modInv.sol";

/// @notice Executes Shamir's trick over 8 dimensions, using precomputations stored in the bytecode of the contract
/// that uses this library.
/// @param scalar_u The first scalar for the Shamir's trick computation.
/// @param scalar_v The second scalar for the Shamir's trick computation.
/// @param precomputedOffset The **offset** where the precomputed points starts in the bytecode
/// @return X Resulting x-coordinate of the computed point
/// @dev The external tool to generate tables from the public key is listed in the documentation of the contract
function mulmuladd(uint256 scalar_u, uint256 scalar_v, uint256 precomputedOffset) returns (uint256 X) {
    // third coordinates of the point
    uint256 zz = 256;
    uint256[6] memory T;

    unchecked {
        while (T[0] == 0) {
            zz = zz - 1;
            // TODO: TBD case of msb octobit is null
            // TODO: SOLHINT reduce line length
            /* solhint-disable max-line-length */
            T[0] = 64
                * (
                    128 * ((scalar_v >> zz) & 1) + 64 * ((scalar_v >> (zz - 64)) & 1) + 32 * ((scalar_v >> (zz - 128)) & 1)
                        + 16 * ((scalar_v >> (zz - 192)) & 1) + 8 * ((scalar_u >> zz) & 1) + 4 * ((scalar_u >> (zz - 64)) & 1)
                        + 2 * ((scalar_u >> (zz - 128)) & 1) + ((scalar_u >> (zz - 192)) & 1)
                );
            /* solhint-enable max-line-length  */
        }
    }
    assembly {
        codecopy(T, add(mload(T), precomputedOffset), 64)
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
            /* Access to precomputed table using codecopy hack */
            {
                codecopy(T, add(T4, precomputedOffset), 64)

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
    }

    X = X * pModInv(zz);
}

/// @title ECDSA256r1PrecomputeInternal
/// @notice This library is for ECDSA verification using a precomputed table of multiples of P and Q. The Shamir's
///         Secret Sharing scheme is used in 8 dimensions. The precomputed table must be stored **in** the bytecode of
///         the contract calling the verify function of this library (using delegatecall as it's automatically done in
///         Solidity).
/// @dev    This library is more gas efficient than the ECDSA256r1Precompute library (and way more than the ECDSA256r1),
///         but it requires the precomputed table of multiples of P and Q to be stored **in** the functional bytecode of
///         the contract that consumes this library. How does it works? For each public key you want to verify, you must
///         precompute the associated 256 points and inject it in the bytecode of the smart account after the
///         compilation of the contract. One way to do so is to initialise a constant in the contract of the
///         precomputation size for 256 points. This constant will be initialized with an easily recognizable value, so
///         that after compiling the contract, you can manually replace the placeholder value with the precompute
///         points. Now, you need to calculate the offset where the precomputed points will be stored in the bytecode
///         in order to pass it to the verify function. The verify function will use the opcode `codecopy` (not
///         `extcodecopy`) as it's done in the ECDSA256r1Precompute library to read the precomputed points.
///         This trick is more heavy in term of workflow off-chain but it's the more gas efficient on-chain solution we
///         found so far (`codecopy` is 33x cheaper than `extcodecopy`). This library is not recommended for everyone,
///         if you are looking for an in-between, the library ECDSA256r1Precompute is probably what you are looking for.
///
///         More info on the `extcodecopy` opcode: https://www.evm.codes/#3c
///         How to generate the precomputed table: github.com/0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation
/// @custom:experimental This is an **untested** and experimental library!!!!!
/// @custom:warning This code is NOT intended for use with non-prime order curves due to security considerations. The
///                 code is expressly optimized for curves with a=-3 and of prime order. Constants like -1, and -2
///                 should be replaced if this code is to be utilized for any curve other than sec256R1.
library ECDSA256r1PrecomputeInternal {
    /// @notice Verifies an ECDSA signature using a precomputed table of multiples of P and Q stored in the bytecode of
    ///         the contrat that uses this library
    /// @param message The message that was signed.
    /// @param r uint256 The r value of the ECDSA signature.
    /// @param s uint256 The s value of the ECDSA signature.
    /// @param precomputedOffset The **offset** where the precomputed points starts in the bytecode
    /// @return True if the signature is valid, false otherwise.
    /// @dev Note the required interactions with the precompled contract can revert the transaction
    function verify(bytes32 message, uint256 r, uint256 s, uint256 precomputedOffset) external returns (bool) {
        // check the validity of the signature
        if (r == 0 || r >= n || s == 0 || s >= n) {
            return false;
        }

        // preform the Shamir's trick in order to calculate the x coordinate of the point
        uint256 sInv = nModInv(s);
        uint256 x1 = mulmuladd(mulmod(uint256(message), sInv, n), mulmod(r, sInv, n), precomputedOffset);
        x1 = addmod(x1, n - r, n);
        return x1 == 0;
    }
}
