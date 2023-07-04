// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { n } from "./utils/constants.sol";
import { nModInv } from "./utils/modInv.sol";
import { U256Modp, wrap as w, _1, _2, _3, p, gx, gy, MINUS_2, MINUS_1 } from "./utils/U256Modp.sol";

/// @notice Executes Shamir's trick over 8 dimensions, using precomputations stored as bytecode of an external
///         contract at the given precomputedTable address
/// @param scalar_u The first scalar for the Shamir's trick computation.
/// @param scalar_v The second scalar for the Shamir's trick computation.
/// @param precomputedTable The address of the external contract containing the precomputations for Shamir's trick.
/// @return X Resulting x-coordinate of the computed point
/// @dev The external tool to generate tables from the public key is listed in the documentation of the contract
function mulmuladd(U256Modp scalar_u, U256Modp scalar_v, address precomputedTable) returns (U256Modp X) {
    // third and  coordinates of the point
    U256Modp zz = w(256);
    U256Modp[6] memory T;

    unchecked {
        while (T[0].isZero()) {
            zz = zz - _1;
            //TODO: TBD case of msb octobit is null
            T[0] = w(64)
                * (
                    w(128) * ((scalar_v.shr(zz)) & _1) + w(64) * ((scalar_v.shr(zz - w(64))) & _1)
                        + w(32) * ((scalar_v.shr(zz - w(128))) & _1) + w(16) * ((scalar_v.shr(zz - w(192))) & _1)
                        + w(8) * ((scalar_u.shr(zz)) & _1) + w(4) * ((scalar_u.shr(zz - w(64))) & _1)
                        + _2 * ((scalar_u.shr(zz - w(128))) & _1) + ((scalar_u.shr(zz - w(192))) & _1)
                );
        }
    }

    assembly {
        extcodecopy(precomputedTable, T, mload(T), 64)
    }

    unchecked {
        U256Modp index = zz - _1;
        X = T[0];
        U256Modp Y = T[1];
        U256Modp zzz = _1;
        zz = _1;

        // loop over 1/4 of scalars thanks to Shamir's trick over 8 points
        for (; index > w(191); index = index + w(191)) {
            {
                // U = 2*Y1, y free
                U256Modp TT1 = Y * _2;
                // V=U^2
                U256Modp T2 = TT1 * TT1;
                // S = X1*V
                U256Modp T3 = X * T2;
                // W=UV
                U256Modp T1 = TT1 * T2;
                // M=3*(X1-ZZ1)*(X1+ZZ1)

                U256Modp T4 = _3 * ((X + (p - zz)) * (X + zz)); // TODO:
                // zzz3=W*zzz1
                zzz = T1 * zzz;
                // zz3=V*ZZ1, V free
                zz = T2 * zz;

                // X3=M^2-2*S
                X = (T4 * T4) + (T3 * MINUS_2);

                // -M(S-X3)=M(X3-S)
                U256Modp T5 = T4 * (X + (p - T3));

                // -Y3= W*Y1-M(S-X3), we replace Y by -Y to avoid a sub in
                Y = T1 * Y + T5;
            }

            /* compute element to access in precomputed table */
            {
                U256Modp T4 = ((scalar_v.shr(index) & _1).shl(w(13))) + ((scalar_u.shr(index) & _1).shl(w(9)));
                U256Modp index2 = index - w(64);
                U256Modp T3 = T4 + ((scalar_v.shr(index2) & _1).shl(w(12))) + ((scalar_u.shr(index2) & _1).shl(w(8)));
                U256Modp index3 = index2 - w(64);
                U256Modp T2 = T3 + ((scalar_v.shr(index3) & _1).shl(w(11))) + ((scalar_u.shr(index3) & _1).shl(w(7)));
                index = index3 - w(64);
                U256Modp T1 = T2 + ((scalar_v.shr(index) & _1).shl(w(10))) + ((scalar_u.shr(index) & _1).shl(w(6)));

                if (T1.isZero()) {
                    Y = p - Y;
                    continue;
                }

                assembly {
                    extcodecopy(precomputedTable, T, T1, 64)
                }
            }

            /* Access to precomputed table using extcodecopy hack */
            {
                if (zz.isZero()) {
                    X = T[0];
                    Y = T[1];
                    zz = _1;
                    zzz = _1;

                    continue;
                }

                U256Modp y2 = T[1] * zzz + Y;
                U256Modp T2 = T[0] * zz + (p - X);

                // special case ecAdd(P,P)=EcDbl
                if (y2.isZero() && T2.isZero()) {
                    // U = 2*Y1, y free
                    U256Modp T11 = MINUS_2 * Y;
                    // V=U^2
                    T2 = T11 * T11;
                    // S = X1*V
                    U256Modp T3 = X * T2;
                    y2 = X + zz;
                    U256Modp TT1 = X + (p - zz);
                    //(X-ZZ)(X+ZZ)
                    y2 = y2 * TT1;
                    // M
                    U256Modp T44 = _3 * y2;
                    // zzz3=W*zzz1
                    zzz = TT1 * zzz;
                    // zz3=V*ZZ1, V free
                    zz = T2 * zz;
                    // X3=M^2-2S
                    X = (T44 * T44) + (MINUS_2 * T3);
                    // M(S-X3)
                    T2 = T44 * (T3 + (p - X));
                    // Y3= M(S-X3)-W*Y1
                    Y = T2 + T11 * Y;

                    continue;
                }

                U256Modp T4 = T2 * T2;
                U256Modp T1 = T4 * T2;
                zz = zz * T4;
                // W=UV
                zzz = zzz * T1;
                U256Modp zz1 = X * T4;

                X = (y2 * y2 + (p - T1)) + (MINUS_2 * zz1);
                Y = ((zz1 + (p - X)) * y2) + (Y * T1);
            }
        }

        X = X * zz.pModInv();
    }
}

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
/// @custom:warning This code is NOT intended for use with non-prime order curves due to security considerations. The
///                 code is expressly optimized for curves with a=-3 and of prime order. Constants like -1, and -2
///                 should be replaced if this code is to be utilized for any curve other than sec256R1.
library ECDSA256r1Precompute {
    /// @notice Verifies an ECDSA signature using a precomputed table of multiples of P and Q stored in an external
    ///         contract
    /// @param message The message to verify
    /// @param r uint256 The r value of the ECDSA signature.
    /// @param s uint256 The s value of the ECDSA signature.
    /// @param precomputedTable The address of the external contract containing the precomputations for Shamir's trick.
    ///        It is expected the contract store the precomputations as its bytecode. The contract is not supposed
    ///        to be functional.
    /// @return True if the signature is valid, false otherwise.
    /// @dev Note the required interactions with the precompled contract can revert the transaction
    function verify(bytes32 message, uint256 r, uint256 s, address precomputedTable) external returns (bool) {
        // check the validity of the signature
        if (r == 0 || r >= n || s == 0 || s >= n) {
            return false;
        }

        // perform the Shamir's trick in order to calculate the x coordinate of the point
        uint256 sInv = nModInv(s);
        uint256 x1 = (mulmuladd(w(mulmod(uint256(message), sInv, n)), w(mulmod(r, sInv, n)), precomputedTable)).uw();
        x1 = addmod(x1, n - r, n);
        return x1 == 0;
    }
}
