// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "../../lib/prb-test/src/PRBTest.sol";
import { StdUtils } from "../../lib/forge-std/src/StdUtils.sol";
import { p, a, n } from "../../src/utils/secp256r1.sol";
import "../../src/utils/secp256r1.sol" as curve;

contract ImplementationCurve {
    function nModInv(uint256 x) external returns (uint256) {
        return curve.nModInv(x);
    }

    function pModInv(uint256 x) external returns (uint256) {
        return curve.pModInv(x);
    }
}

/// @title `Secp256r1` test contract
/// @notice Tests designed to only focus arithmetic functions of the `Secp256r1` library that are based on the curve
contract Secp256r1Test is StdUtils, PRBTest {
    ImplementationCurve private implementation;

    constructor() {
        // deploy the implementation contract
        implementation = new ImplementationCurve();
    }

    /**
     * @notice Fuzz test for the `nModInv` function of the `Secp256r1` library. Generates a random value to invert
     * between 1 and n-1, and verifies that the inverse is correct by checking that the product of the value and its
     * inverse is equal to 1 mod n.
     */
    /// @param valueToInvert The value to invert.
    function testFuzz_InVmodn(uint256 valueToInvert) public {
        // bound the fuzzed value between 1 and n-1
        valueToInvert = bound(valueToInvert, 1, n - 1);

        uint256 invertedValue = implementation.nModInv(valueToInvert);
        uint256 product = mulmod(invertedValue, valueToInvert, n);
        assertEq(product, 1);
    }

    /**
     * @notice Fuzz test for the `pModInv` function of the `Secp256r1` library. Generates a random value to invert
     * between 1 and p-1, and verifies that the inverse is correct by checking that the product of the value and its
     * inverse is equal to 1 mod p.
     */
    /// @param valueToInvert The value to invert.
    function testFuzz_InVmodp(uint256 valueToInvert) public {
        // bound the fuzzed value between 1 and p-1
        valueToInvert = bound(valueToInvert, 1, p - 1);

        uint256 invertedValue = implementation.pModInv(valueToInvert);
        uint256 product = mulmod(invertedValue, valueToInvert, p);
        assertEq(product, 1);
    }
}
