// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

import { PRBTest } from "../../lib/prb-test/src/PRBTest.sol";
import { StdUtils } from "../../lib/forge-std/src/StdUtils.sol";
import { ECDSA, p } from "../../src/utils/ECDSA.sol";

struct zzPoint {
    uint256 x;
    uint256 y;
    uint256 zz;
    uint256 zzz;
}

struct Point {
    uint256 x;
    uint256 y;
}

contract ImplementationECDSA {
    function zz2Aff(uint256 x, uint256 y, uint256 zz, uint256 zzz) external returns (uint256, uint256) {
        return ECDSA.zz2Aff(x, y, zz, zzz);
    }

    function zzAddN(
        uint256 x1,
        uint256 y1,
        uint256 zz1,
        uint256 zzz1,
        uint256 x2,
        uint256 y2
    )
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        return ECDSA.zzAddN(x1, y1, zz1, zzz1, x2, y2);
    }

    function zzDouble(
        uint256 x,
        uint256 y,
        uint256 zz,
        uint256 zzz
    )
        external
        pure
        returns (uint256, uint256, uint256, uint256)
    {
        return ECDSA.zzDouble(x, y, zz, zzz);
    }

    function affIsOnCurve(uint256 x, uint256 y) external pure returns (bool) {
        return ECDSA.affIsOnCurve(x, y);
    }

    function affAdd(uint256 x0, uint256 y0, uint256 x1, uint256 y1) external returns (uint256 x2, uint256 y2) {
        return ECDSA.affAdd(x0, y0, x1, y1);
    }
}

/// @title `Secp256r1` test contract
/// @notice Tests designed to only focus arithmetic functions of the `Secp256r1` library that are based on the curve
contract ECDSATest is StdUtils, PRBTest {
    ImplementationECDSA internal implementation;

    constructor() {
        // deploy the implementation contract
        implementation = new ImplementationECDSA();
    }

    // TODO: Fuzz the function
    function test_zz2AffZeroInputs() external {
        (uint256 x1, uint256 y1) = implementation.zz2Aff(0, 0, 0, 0);
        assertEq(x1, 0);
        assertEq(y1, 0);
    }

    // TODO: Test the assembly branch of the `zzAddN` function
    function test_zzAddNZero() external {
        zzPoint memory point1 = zzPoint(0x1, 0x00, 0x3, 0x4);
        Point memory point2 = Point(0x5, 0x6);

        (uint256 x, uint256 y, uint256 zz, uint256 zzz) =
            implementation.zzAddN(point1.x, point1.y, point1.zz, point1.zzz, point2.x, point2.y);

        assertEq(x, point2.x);
        assertEq(y, point2.y);
        assertEq(zz, 1);
        assertEq(zzz, 1);
    }

    // TODO: Test the assembly branch of the `zzDouble` function (for real)
    function test_zz2DoubleZeroInputs() external {
        (uint256 x, uint256 y, uint256 zz, uint256 zzz) = implementation.zzDouble(0, 0, 0, 0);
        assertEq(x, 0);
        assertEq(y, 0);
        assertEq(zz, 0);
        assertEq(zzz, 0);
    }

    // TODO: Test the unchecked branch of the `affIsOnCurve` function
    function test_affIsOnCurveInvalidPoints() external {
        // expect to fail because x == 0
        bool isOnCurve = implementation.affIsOnCurve(0, 2);
        assertFalse(isOnCurve);

        // expect to fail because x == p
        isOnCurve = implementation.affIsOnCurve(p, 2);
        assertFalse(isOnCurve);

        // expect to fail because y == 0
        isOnCurve = implementation.affIsOnCurve(2, 0);
        assertFalse(isOnCurve);

        // expect to fail because y == p
        isOnCurve = implementation.affIsOnCurve(2, p);
        assertFalse(isOnCurve);
    }

    // TODO: Test the else branch of the `affAdd` function
    function test_affAddZeroPoints() external {
        // test case where point0 is zero (y = 0)
        Point memory point0 = Point(0x5, 0x0);
        Point memory point1 = Point(0x5, 0x6);
        (uint256 x2, uint256 y2) = implementation.affAdd(point0.x, point0.y, point1.x, point1.y);
        assertEq(x2, point1.x);
        assertEq(y2, point1.y);

        // test case where point1 is zero (y = 0)
        point0 = Point(0x5, 0x2);
        point1 = Point(0x5, 0x0);
        (x2, y2) = implementation.affAdd(point0.x, point0.y, point1.x, point1.y);
        assertEq(x2, point1.x);
        assertEq(y2, point1.y);
    }

    // TODO: Test behaviour when the precompile 0x05 ev
}
