// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import "./constants.sol" as Curve;
import { pModInv as pModInvUint256 } from "./modInv.sol";

// Curve constants converted to U256Modp
U256Modp constant p = U256Modp.wrap(Curve.p);
U256Modp constant a = U256Modp.wrap(Curve.a);
U256Modp constant b = U256Modp.wrap(Curve.b);
U256Modp constant gx = U256Modp.wrap(Curve.gx);
U256Modp constant gy = U256Modp.wrap(Curve.gy);

// Useful Constants converted to U256Modp
U256Modp constant MINUS_2 = U256Modp.wrap(Curve.MINUS_2);
U256Modp constant MINUS_2MODN = U256Modp.wrap(Curve.MINUS_2MODN);
U256Modp constant MINUS_1 = U256Modp.wrap(Curve.MINUS_1);
U256Modp constant _0 = U256Modp.wrap(0);
U256Modp constant _1 = U256Modp.wrap(1);
U256Modp constant _2 = U256Modp.wrap(2);
U256Modp constant _3 = U256Modp.wrap(3);

// arithmetic
function addmd(U256Modp x, U256Modp y) pure returns (U256Modp z) {
    z = U256Modp.wrap(addmod(U256Modp.unwrap(x), U256Modp.unwrap(y), Curve.p));
}

function mulmd(U256Modp x, U256Modp y) pure returns (U256Modp z) {
    z = U256Modp.wrap(mulmod(U256Modp.unwrap(x), U256Modp.unwrap(y), Curve.p));
}

/// @dev The logic of this function run inside the unchecked block
function sub(U256Modp x, U256Modp y) pure returns (U256Modp z) {
    unchecked {
        z = U256Modp.wrap(U256Modp.unwrap(x) - U256Modp.unwrap(y));
    }
}

/// @notice invert U256Modp value
/// @dev The logic of this function run inside the unchecked block
function inv(U256Modp self) pure returns (U256Modp z) {
    unchecked {
        z = U256Modp.wrap(Curve.p - U256Modp.unwrap(self));
    }
}

function and(U256Modp x, U256Modp y) pure returns (U256Modp z) {
    z = U256Modp.wrap(U256Modp.unwrap(x) & U256Modp.unwrap(y));
}

function lowerThan(U256Modp x, U256Modp y) pure returns (bool result) {
    result = U256Modp.unwrap(x) < U256Modp.unwrap(y);
}

function greaterThan(U256Modp x, U256Modp y) pure returns (bool result) {
    result = U256Modp.unwrap(x) > U256Modp.unwrap(y);
}

function lowerThanOrEqual(U256Modp x, U256Modp y) pure returns (bool result) {
    result = U256Modp.unwrap(x) <= U256Modp.unwrap(y);
}

function greaterThanOrEqual(U256Modp x, U256Modp y) pure returns (bool result) {
    result = U256Modp.unwrap(x) >= U256Modp.unwrap(y);
}

function equal(U256Modp x, U256Modp y) pure returns (bool result) {
    result = U256Modp.unwrap(x) == U256Modp.unwrap(y);
}

/// @notice compare U256Modp with uint256
function eqUint(U256Modp self, uint256 y) pure returns (bool result) {
    result = U256Modp.unwrap(self) == y;
}

function isZero(U256Modp self) pure returns (bool result) {
    result = U256Modp.unwrap(self) == 0;
}

function shr(U256Modp self, U256Modp shift) pure returns (U256Modp z) {
    z = U256Modp.wrap(U256Modp.unwrap(self) >> U256Modp.unwrap(shift));
}

function shl(U256Modp self, U256Modp shift) pure returns (U256Modp z) {
    z = U256Modp.wrap(U256Modp.unwrap(self) << U256Modp.unwrap(shift));
}

/// @notice unwrap U256Modp to uint256
function uw(U256Modp self) pure returns (uint256 value) {
    value = U256Modp.unwrap(self);
}

/// @notice U256Modp wrapper around pModInv
function pModInv(U256Modp self) returns (U256Modp result) {
    result = U256Modp.wrap(pModInvUint256(U256Modp.unwrap(self)));
}

// native types override
function wrap(uint256 self) pure returns (U256Modp wrapped) {
    wrapped = U256Modp.wrap(self);
}

type U256Modp is uint256;

using {
    addmd as +,
    mulmd as *,
    sub as -,
    equal as ==,
    and as &,
    greaterThan as >,
    lowerThan as <,
    lowerThanOrEqual as <=,
    greaterThanOrEqual as >=,
    inv,
    pModInv,
    isZero,
    // UDO cannot be defined for >> or <<
    shr,
    shl,
    uw,
    eqUint
} for U256Modp global;
