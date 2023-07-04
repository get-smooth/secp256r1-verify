// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { Test } from "../../lib/forge-std/src/Test.sol";
import { U256Modp, p, wrap } from "../../src/utils/U256Modp.sol";

contract U256ModpTest is Test {
    function test_addmd(uint256 x, uint256 y) public {
        x = bound(x, 0, type(uint256).max / 2);
        y = bound(y, 0, type(uint256).max / 2);

        uint256 expectedResult = addmod(x, y, p.uw());
        uint256 result = (U256Modp.wrap(x) + U256Modp.wrap(y)).uw();
        assertEq(expectedResult, result);
    }

    function test_mulmd(uint256 x, uint256 y) public {
        uint256 expectedResult = mulmod(x, y, p.uw());
        uint256 result = (U256Modp.wrap(x) * U256Modp.wrap(y)).uw();
        assertEq(expectedResult, result);
    }

    function test_sub(uint256 x, uint256 y) public {
        y = bound(y, 0, x);

        uint256 expectedResult = x - y;
        uint256 result = (U256Modp.wrap(x) - U256Modp.wrap(y)).uw();
        assertEq(expectedResult, result);
    }

    function test_inv(uint256 x) public {
        x = bound(x, 0, p.uw());

        uint256 expectedResult = p.uw() - x;
        uint256 result = U256Modp.wrap(x).inv().uw();
        assertEq(expectedResult, result);
    }

    function test_and(uint256 x, uint256 y) public {
        uint256 expectedResult = x & y;
        uint256 result = (U256Modp.wrap(x) & U256Modp.wrap(y)).uw();
        assertEq(expectedResult, result);
    }

    function test_lowerThan(uint256 x, uint256 y) public {
        bool expectedResult = x < y;
        bool result = U256Modp.wrap(x) < U256Modp.wrap(y);
        assertEq(expectedResult, result);
    }

    function test_greaterThan(uint256 x, uint256 y) public {
        bool expectedResult = x > y;
        bool result = U256Modp.wrap(x) > U256Modp.wrap(y);
        assertEq(expectedResult, result);
    }

    function test_lowerThanOrEqual(uint256 x, uint256 y) public {
        bool expectedResult = x <= y;
        bool result = U256Modp.wrap(x) <= U256Modp.wrap(y);
        assertEq(expectedResult, result);
    }

    function test_greaterThanOrEqual(uint256 x, uint256 y) public {
        bool expectedResult = x >= y;
        bool result = U256Modp.wrap(x) >= U256Modp.wrap(y);
        assertEq(expectedResult, result);
    }

    function test_equal(uint256 x, uint256 y) public {
        bool expectedResult = x == y;
        bool result = U256Modp.wrap(x) == U256Modp.wrap(y);
        assertEq(expectedResult, result);
    }

    function test_equalUint(uint256 x, uint256 y) public {
        bool expectedResult = x == y;
        bool result = U256Modp.wrap(x).eqUint(y);
        assertEq(expectedResult, result);
    }

    function test_isZero(uint256 x) public {
        bool expectedResult = x == 0;
        bool result = U256Modp.wrap(x).isZero();
        assertEq(expectedResult, result);
    }

    function test_shr(uint256 x, uint256 y) public {
        uint256 expectedResult = x >> y;
        uint256 result = (U256Modp.wrap(x).shr(U256Modp.wrap(y))).uw();
        assertEq(expectedResult, result);
    }

    function test_shl(uint256 x, uint256 y) public {
        uint256 expectedResult = x << y;
        uint256 result = (U256Modp.wrap(x).shl(U256Modp.wrap(y))).uw();
        assertEq(expectedResult, result);
    }

    function test_uw(uint256 x) public {
        U256Modp intermediary = U256Modp.wrap(x);
        uint256 result = intermediary.uw();
        assertEq(x, result);
    }

    function test_wrap(uint256 x) public {
        U256Modp intermediary = wrap(x);
        uint256 result = intermediary.uw();
        assertEq(x, result);
    }
}
