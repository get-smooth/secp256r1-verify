// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "../../lib/prb-test/src/PRBTest.sol";
import { StdUtils } from "../../lib/forge-std/src/StdUtils.sol";
import { ECDSA } from "../../src/utils/ECDSA.sol";
import {
    U256Modp,
    p,
    a,
    b,
    gx,
    gy,
    MINUS_2,
    MINUS_2MODN,
    MINUS_1,
    wrap as w,
    _0,
    _1,
    _2,
    _3
} from "../../src/utils/U256Modp.sol";

struct zzPoint {
    U256Modp x;
    U256Modp y;
    U256Modp zz;
    U256Modp zzz;
}

struct Point {
    U256Modp x;
    U256Modp y;
}

contract ImplementationECDSA {
    function zz2Aff(U256Modp x, U256Modp y, U256Modp zz, U256Modp zzz) external returns (U256Modp, U256Modp) {
        return ECDSA.zz2Aff(x, y, zz, zzz);
    }

    function zzAddN(
        U256Modp x1,
        U256Modp y1,
        U256Modp zz1,
        U256Modp zzz1,
        U256Modp x2,
        U256Modp y2
    )
        external
        pure
        returns (U256Modp, U256Modp, U256Modp, U256Modp)
    {
        return ECDSA.zzAddN(x1, y1, zz1, zzz1, x2, y2);
    }

    function zzDouble(
        U256Modp x,
        U256Modp y,
        U256Modp zz,
        U256Modp zzz
    )
        external
        pure
        returns (U256Modp, U256Modp, U256Modp, U256Modp)
    {
        return ECDSA.zzDouble(x, y, zz, zzz);
    }

    function affIsOnCurve(U256Modp x, U256Modp y) external pure returns (bool) {
        return ECDSA.affIsOnCurve(x, y);
    }

    function affAdd(U256Modp x0, U256Modp y0, U256Modp x1, U256Modp y1) external returns (U256Modp x2, U256Modp y2) {
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
        (U256Modp x1, U256Modp y1) = implementation.zz2Aff(_0, _0, _0, _0);
        assertTrue(x1.isZero());
        assertTrue(y1.isZero());
    }

    // TODO: Test the assembly branch of the `zzAddN` function
    function test_zzAddNZero() external {
        zzPoint memory point1 = zzPoint(w(0x1), _0, w(0x3), w(0x4));
        Point memory point2 = Point(w(0x5), w(0x6));

        (U256Modp x, U256Modp y, U256Modp zz, U256Modp zzz) =
            implementation.zzAddN(point1.x, point1.y, point1.zz, point1.zzz, point2.x, point2.y);

        assertEq(x.uw(), point2.x.uw());
        assertEq(y.uw(), point2.y.uw());
        assertEq(zz.uw(), 1);
        assertEq(zzz.uw(), 1);
    }

    // TODO: Test the assembly branch of the `zzDouble` function (for real)
    function test_zz2DoubleZeroInputs() external {
        (U256Modp x, U256Modp y, U256Modp zz, U256Modp zzz) = implementation.zzDouble(_0, _0, _0, _0);
        assertTrue(x.isZero());
        assertTrue(y.isZero());
        assertTrue(zz.isZero());
        assertTrue(zzz.isZero());
    }

    // TODO: Test the unchecked branch of the `affIsOnCurve` function
    function test_affIsOnCurveInvalidPoints() external {
        // expect to fail because x == 0
        bool isOnCurve = implementation.affIsOnCurve(_0, _2);
        assertFalse(isOnCurve);

        // expect to fail because x == p
        isOnCurve = implementation.affIsOnCurve(p, _2);
        assertFalse(isOnCurve);

        // expect to fail because y == 0
        isOnCurve = implementation.affIsOnCurve(_2, _0);
        assertFalse(isOnCurve);

        // expect to fail because y == p
        isOnCurve = implementation.affIsOnCurve(_2, p);
        assertFalse(isOnCurve);
    }

    // TODO: Test the else branch of the `affAdd` function
    function test_affAddZeroPoints() external {
        // test case where point0 is zero (y = 0)
        Point memory point0 = Point(w(5), _0);
        Point memory point1 = Point(w(5), w(6));
        (U256Modp x2, U256Modp y2) = implementation.affAdd(point0.x, point0.y, point1.x, point1.y);
        assertEq(x2.uw(), point1.x.uw());
        assertEq(y2.uw(), point1.y.uw());

        // test case where point1 is zero (y = 0)
        point0 = Point(w(5), _2);
        point1 = Point(w(5), _0);
        (x2, y2) = implementation.affAdd(point0.x, point0.y, point1.x, point1.y);
        assertEq(x2.uw(), point0.x.uw());
        assertEq(y2.uw(), point0.y.uw());
    }

    // TODO: Test behaviour when the precompile 0x05 ev
}
