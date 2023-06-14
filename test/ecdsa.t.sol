// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

import { Test } from "../lib/forge-std/src/Test.sol";
import { Secp256r1 } from "../src/secp256r1.sol";

/**
 * TODO:
 *         - [ ] Check the coverage (analyse branches etc...)
 *         - [ ] Clean the tests
 *         - [ ] Create tests for the base library
 *         - [ ] Create tests for the variant libraries
 *         - [ ] NatSpec everything
 */

/**
 * /* @dev Sutherland2008 doubling
 */
/* The "dbl-2008-s-1" doubling formulas */
function ecZZ_Dbl(
    uint256 x,
    uint256 y,
    uint256 zz,
    uint256 zzz
)
    pure
    returns (uint256 P0, uint256 P1, uint256 P2, uint256 P3)
{
    uint256 p = Secp256r1.p;
    uint256 MINUS_2 = Secp256r1.MINUS_2;

    unchecked {
        assembly {
            // U=2*Y1
            P0 := mulmod(2, y, p)

            // V=U^2
            P2 := mulmod(P0, P0, p)

            // S = X1*V
            P3 := mulmod(x, P2, p)

            // W=UV
            P1 := mulmod(P0, P2, p)

            // zz3=V*ZZ1
            P2 := mulmod(P2, zz, p)

            // M=3*(X1-ZZ1)*(X1+ZZ1)
            zz := mulmod(3, mulmod(addmod(x, sub(p, zz), p), addmod(x, zz, p), p), p)

            // X3=M^2-2S
            P0 := addmod(mulmod(zz, zz, p), mulmod(MINUS_2, P3, p), p)

            // M(S-X3)
            x := mulmod(zz, addmod(P3, sub(p, P0), p), p)

            // zzz3=W*zzz1
            P3 := mulmod(P1, zzz, p)

            // Y3= M(S-X3)-W*Y1
            P1 := addmod(x, sub(p, mulmod(P1, y, p)), p)
        }
    }

    return (P0, P1, P2, P3);
}

contract Secp256r1Standard {
    function verify(bytes32 message, uint256[2] calldata rs, uint256[2] calldata Q) external returns (bool) {
        return Secp256r1.verify(message, rs, Q);
    }
}

contract Secp256r1Precompute is Test {
    address public constant table = address(0xcaca);

    constructor(uint256 x, uint256 y) {
        // construct the command to run the nodejs script
        string[] memory inputs = new string[](4);
        inputs[0] = "npx";
        inputs[1] = "@0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation";
        inputs[2] = vm.toString(x);
        inputs[3] = vm.toString(y);

        // run the nodejs script and save in memory the precomputed points
        bytes memory precompute = vm.ffi(inputs);

        // set precompute data as the account code of <account>
        vm.etch(table, precompute);
    }

    function verify(bytes32 message, uint256[2] calldata rs, address Shamir8) external returns (bool) {
        return Secp256r1.verify(bytes32(message), rs, Shamir8);
    }
}

contract Secp256r1Interleaved {
    function verify(uint256 scalar_u, uint256 scalar_v, uint256 scalar_r, address Shamir8) external returns (bool) {
        return Secp256r1.verify(scalar_u, scalar_v, scalar_r, Shamir8);
    }
}

contract EcdsaTest is Test {
    function wychproof_keyload(bool expected)
        internal
        returns (uint256[2] memory pubKey, string memory deployData, uint256 numtests)
    {
        deployData = expected == true
            ? vm.readFile("test/fixtures/vec_valid.json")
            : vm.readFile("test/fixtures/vec_invalid.json");

        pubKey[0] = vm.parseJsonUint(deployData, ".keyx");
        pubKey[1] = vm.parseJsonUint(deployData, ".keyy");
        numtests = vm.parseJsonUint(deployData, ".NumberOfTests");
    }

    // load a single test vector
    function wychproof_vecload(
        string memory deployData,
        string memory snum
    )
        internal
        returns (uint256[2] memory rs, bytes32 message)
    {
        rs[0] = vm.parseJsonUint(deployData, string.concat(".sigx_", snum));
        rs[1] = vm.parseJsonUint(deployData, string.concat(".sigy_", snum));
        message = vm.parseJsonBytes32(deployData, string.concat(".msg_", snum));
    }

    function validateInvariantEcMulMulAdd(bool flag) internal {
        // load the wycheproof test vectors
        (uint256[2] memory pubKey, string memory vectors, uint256 numtests) = wychproof_keyload(flag);

        // deploy a contract with the standard implementation of the library
        Secp256r1Standard secp256standard = new Secp256r1Standard();
        // deploy a contract with the precomputation implementation of the library
        Secp256r1Precompute secp256precompute = new Secp256r1Precompute(pubKey[0], pubKey[1]);

        for (uint256 i = 1; i <= numtests; i++) {
            // get the test vector (message, signature)
            (uint256[2] memory rs, bytes32 message) = wychproof_vecload(vectors, vm.toString(i));

            // no precompute
            bool isStandardValid = secp256standard.verify(message, rs, pubKey);
            assertEq(isStandardValid, flag);

            // precompute
            bool isPrecomputeValid = secp256precompute.verify(bytes32(message), rs, secp256precompute.table());
            assertEq(isPrecomputeValid, flag);
        }
    }

    function test_Invariant_edge() public {
        // choose Q=2P, then verify duplication is ok
        uint256[4] memory Q;
        (Q[0], Q[1], Q[2], Q[3]) = ecZZ_Dbl(Secp256r1.gx, Secp256r1.gy, 1, 1);

        uint256[4] memory _4P;
        (_4P[0], _4P[1], _4P[2], _4P[3]) = ecZZ_Dbl(Q[0], Q[1], Q[2], Q[3]);

        uint256 _4P_res1;
        (_4P_res1,) = Secp256r1.ecZZ_SetAff(_4P[0], _4P[1], _4P[2], _4P[3]);

        uint256 _4P_res2 = Secp256r1.ecZZ_mulmuladd_S_asm(Secp256r1.gx, Secp256r1.gy, 4, 0);
        assertEq(_4P_res1, _4P_res2);

        uint256[2] memory nQ;
        (nQ[0], nQ[1]) = Secp256r1.ecZZ_SetAff(Q[0], Q[1], Q[2], Q[3]);
        uint256 _4P_res3 = Secp256r1.ecZZ_mulmuladd_S_asm(nQ[0], nQ[1], 2, 1);

        assertEq(_4P_res1, _4P_res3);
    }

    // test valid vectors, all assert shall be true
    function test_WychproofValidVectors() external {
        validateInvariantEcMulMulAdd(true);
    }

    // test invalid vectors, all assert shall be false
    function test_WychproofInvalidVectors() public {
        validateInvariantEcMulMulAdd(false);
    }
}
