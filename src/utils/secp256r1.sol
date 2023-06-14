// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

/*//////////////////////////////////////////////////////////////
                        CURVE PARAMETERS
//////////////////////////////////////////////////////////////*/

// prime field modulus of the secp256r1 curve
uint256 constant p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
// short weierstrass first coefficient
uint256 constant a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
// short weierstrass second coefficient
uint256 constant b = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
// the affine coordinates of the generating point on the curve
uint256 constant gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
uint256 constant gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
// the order of the curve, i.e., the number of points on the curve
uint256 constant n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;

/*//////////////////////////////////////////////////////////////
                            CONSTANTS
//////////////////////////////////////////////////////////////*/

// -2 mod(p), used to accelerate inversion and doubling operations by avoiding negation
uint256 constant MINUS_2 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD;
// -2 mod(n), used to speed up inversion operations
uint256 constant MINUS_2MODN = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63254F;
// the representation of -1 in this field
uint256 constant MINUS_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
// address of the ModExp precompiled contract (Arbitrary-precision exponentiation under modulo)
address constant MODEXP_PRECOMPILE = 0x0000000000000000000000000000000000000005;

/*//////////////////////////////////////////////////////////////
                            FUNCTIONS
//////////////////////////////////////////////////////////////*/

/// @notice Calculate the modular inverse of a given integer, which is the inverse of this integer modulo n.
/// @dev Uses the ModExp precompiled contract at address 0x05 for fast computation using little Fermat theorem
/// @param self The integer of which to find the modular inverse
/// @return result The modular inverse of the input integer. If the modular inverse doesn't exist, it revert the tx
function nModInv(uint256 self) returns (uint256 result) {
    assembly ("memory-safe") {
        // load the free memory pointer value
        let pointer := mload(0x40)

        // Define length of base (Bsize)
        mstore(pointer, 0x20)
        // Define the exponent size (Esize)
        mstore(add(pointer, 0x20), 0x20)
        // Define the modulus size (Msize)
        mstore(add(pointer, 0x40), 0x20)
        // Define variables base (B)
        mstore(add(pointer, 0x60), self)
        // Define the exponent (E)
        mstore(add(pointer, 0x80), MINUS_2MODN)
        // We save the point of the last argument, it will be override by the result
        // of the precompile call in order to avoid paying for the memory expansion properly
        let _result := add(pointer, 0xa0)
        // Define the modulus (M)
        mstore(_result, n)

        // Call the precompiled ModExp (0x05) https://www.evm.codes/precompiled#0x05
        if iszero(
            call(
                not(0), // amount of gas to send
                MODEXP_PRECOMPILE, // target
                0x00, // value in wei
                pointer, // argsOffset
                0xc0, // argsSize (6 * 32 bytes)
                _result, // retOffset (we override M to avoid paying for the memory expansion)
                0x20 // retSize (32 bytes)
            )
        ) { revert(0, 0) }

        // we return the value in the last memory word created by the function
        result := mload(_result)
    }
}

/// @notice Calculate the modular inverse of a given integer, which is the inverse of this integer modulo p.
/// @dev Uses the ModExp precompiled contract at address 0x05 for fast computation using little Fermat theorem
/// @param self The integer of which to find the modular inverse
/// @return result The modular inverse of the input integer. If the modular inverse doesn't exist, it revert the tx
function pModInv(uint256 self) returns (uint256 result) {
    assembly ("memory-safe") {
        // load the free memory pointer value
        let pointer := mload(0x40)

        // Define length of base (Bsize)
        mstore(pointer, 0x20)
        // Define the exponent size (Esize)
        mstore(add(pointer, 0x20), 0x20)
        // Define the modulus size (Msize)
        mstore(add(pointer, 0x40), 0x20)
        // Define variables base (B)
        mstore(add(pointer, 0x60), self)
        // Define the exponent (E)
        mstore(add(pointer, 0x80), MINUS_2)
        // We save the point of the last argument, it will be override by the result
        // of the precompile call in order to avoid paying for the memory expansion properly
        let _result := add(pointer, 0xa0)
        // Define the modulus (M)
        mstore(_result, p)

        // Call the precompiled ModExp (0x05) https://www.evm.codes/precompiled#0x05
        if iszero(
            call(
                not(0), // amount of gas to send
                MODEXP_PRECOMPILE, // target
                0x00, // value in wei
                pointer, // argsOffset
                0xc0, // argsSize (6 * 32 bytes)
                _result, // retOffset (we override M to avoid paying for the memory expansion)
                0x20 // retSize (32 bytes)
            )
        ) { revert(0, 0) }

        // we return the value in the last memory word created by the function
        result := mload(_result)
    }
}
