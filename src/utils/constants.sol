// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

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
