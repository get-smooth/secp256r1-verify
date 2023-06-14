// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

/**
 * TODO:
 *         - [ ] Fix forge-std imports
 */
import { Test } from "../lib/forge-std/src/Test.sol";
import { Secp256r1 } from "../src/secp256r1.sol";

/// @title `Secp256r1` test contract
/// @notice Tests designed to only focus arithmetic functions of the `Secp256r1` library that are based on the curve
contract ArithmeticTest is Test {
    /**
     * @notice Fuzz test for the `nModInv` function of the `Secp256r1` library. Generates a random value to invert
     * between 1 and n-1, and verifies that the inverse is correct by checking that the product of the value and its
     * inverse is equal to 1 mod n.
     */
    /// @param valueToInvert The value to invert.
    function test_Fuzz_InVmodn(uint256 valueToInvert) public {
        // bound the fuzzed value between 1 and n-1
        valueToInvert = bound(valueToInvert, 1, Secp256r1.n - 1);

        uint256 invertedValue = Secp256r1.nModInv(valueToInvert);
        uint256 product = mulmod(invertedValue, valueToInvert, Secp256r1.n);
        assertEq(product, 1);
    }

    /**
     * @notice Fuzz test for the `pModInv` function of the `Secp256r1` library. Generates a random value to invert
     * between 1 and p-1, and verifies that the inverse is correct by checking that the product of the value and its
     * inverse is equal to 1 mod p.
     */
    /// @param valueToInvert The value to invert.
    function test_Fuzz_InVmodp(uint256 valueToInvert) public {
        // bound the fuzzed value between 1 and p-1
        valueToInvert = bound(valueToInvert, 1, Secp256r1.p - 1);

        uint256 invertedValue = Secp256r1.pModInv(valueToInvert);
        uint256 product = mulmod(invertedValue, valueToInvert, Secp256r1.p);
        assertEq(product, 1);
    }
}
