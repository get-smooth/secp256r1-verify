// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import { Secp256r1 } from "../src/Secp256r1.sol";

// library FreshCryptoLib without precomputations
contract Wrap_ecdsa_FCL {
    function wrap_ecdsa_core(bytes32 message, uint256[2] calldata rs, uint256[2] calldata Q) public returns (bool) {
        return Secp256r1.ecdsa_verify(message, rs, Q);
    }

    constructor() { }
}

// library FreshCryptoLib with precomputations
contract Wrap_ecdsa_precal {
    address precomputations;

    function wrap_ecdsa_core(bytes32 message, uint256[2] calldata rs) public returns (bool) {
        return Secp256r1.ecdsa_precomputed_verify(message, rs, precomputations);
    }

    constructor(address bytecode) {
        precomputations = bytecode;
    }
}

contract EcdsaTest is Test {
    //curve prime field modulus
    uint256 constant p = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF;
    //short weierstrass first coefficient
    uint256 constant a = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC;
    //short weierstrass second coefficient
    uint256 constant b = 0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B;
    //generating point affine coordinates
    uint256 constant gx = 0x6B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C296;
    uint256 constant gy = 0x4FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5;
    //curve order (number of points)
    uint256 constant n = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551;
    /* -2 mod p constant, used to speed up inversion and doubling (avoid negation)*/
    uint256 constant minus_2 = 0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFD;
    /* -2 mod n constant, used to speed up inversion*/
    uint256 constant minus_2modn = 0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC63254F;

    uint256 constant minus_1 = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;

    uint256 constant _prec_address = 0xcaca;

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Fuzz_InVmodn(uint256 i_u256_a) public {
        vm.assume(i_u256_a < Secp256r1.n);
        vm.assume(i_u256_a != 0);

        uint256 res = Secp256r1.FCL_nModInv(i_u256_a);

        assertEq(mulmod(res, i_u256_a, Secp256r1.n), 1);
    }

    function test_Fuzz_InVmodp(uint256 i_u256_a) public {
        vm.assume(i_u256_a < Secp256r1.p);
        vm.assume(i_u256_a != 0);

        uint256 res = Secp256r1.FCL_pModInv(i_u256_a);

        assertEq(mulmod(res, i_u256_a, Secp256r1.p), 1);
    }
    //ecAff_isOnCurve

    function test_Invariant_edge() public {
        //choose Q=2P, then verify duplication is ok
        uint256[4] memory Q;
        (Q[0], Q[1], Q[2], Q[3]) = Secp256r1.ecZZ_Dbl(gx, gy, 1, 1);
        uint256[4] memory _4P;
        (_4P[0], _4P[1], _4P[2], _4P[3]) = Secp256r1.ecZZ_Dbl(Q[0], Q[1], Q[2], Q[3]);
        uint256 _4P_res1;

        (_4P_res1,) = Secp256r1.ecZZ_SetAff(_4P[0], _4P[1], _4P[2], _4P[3]);

        uint256 _4P_res2 = Secp256r1.ecZZ_mulmuladd_S_asm(gx, gy, 4, 0);
        assertEq(_4P_res1, _4P_res2);

        uint256[2] memory nQ;
        (nQ[0], nQ[1]) = Secp256r1.ecZZ_SetAff(Q[0], Q[1], Q[2], Q[3]);
        uint256 _4P_res3 = Secp256r1.ecZZ_mulmuladd_S_asm(nQ[0], nQ[1], 2, 1);

        assertEq(_4P_res1, _4P_res3);
    }

    //testing Wychproof vectors
    function test_Invariant_ecZZ_mulmuladd_S_asm() public {
        string memory deployData;
        uint256[2] memory key;
        uint256 numtests;
        (key, deployData, numtests) = wychproof_keyload();

        bool res = Secp256r1.ecAff_isOnCurve(key[0], key[1]);
        assertEq(res, true);

        uint256[2] memory rs;
        string memory title;
        string memory snum = "1";

        for (uint256 i = 1; i <= numtests; i++) {
            snum = vm.toString(i);
            uint256 message;
            (rs, message, title) = wychproof_vecload(deployData, snum);

            vm.prank(vm.addr(5));
            Wrap_ecdsa_precal wrap2 = new Wrap_ecdsa_precal(address(uint160(_prec_address)));

            assertEq(res, true);
            res = wrap2.wrap_ecdsa_core(bytes32(message), rs);

            // ensure both implementations return the same result
            assertEq(res, true);
        }
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function wychproof_keyload() public returns (uint256[2] memory key, string memory deployData, uint256 numtests) {
        deployData = vm.readFile("test/wychproof/vec_valid.json");

        uint256 wx = vm.parseJsonUint(deployData, ".NumberOfTests");
        key[0] = vm.parseJsonUint(deployData, ".keyx");
        key[1] = vm.parseJsonUint(deployData, ".keyy");
        bool res = Secp256r1.ecAff_isOnCurve(key[0], key[1]);
        assertEq(res, true);

        bytes memory precompute = precompute_shamir_table(key[0], key[1]);
        verify_precompute(precompute);

        return (key, deployData, wx);
    }

    //load a single test vector
    function wychproof_vecload(
        string memory deployData,
        string memory snum
    )
        public
        returns (uint256[2] memory rs, uint256 message, string memory title)
    {
        title = string(vm.parseJson(deployData, string.concat(".test_", snum)));
        rs[0] = vm.parseJsonUint(deployData, string.concat(".sigx_", snum));
        rs[1] = vm.parseJsonUint(deployData, string.concat(".sigy_", snum));
        message = vm.parseJsonUint(deployData, string.concat(".msg_", snum));
    }

    /// @notice precumpute a shamir table of 256 points for a given pubKey
    /// @dev this function execute a JS package listed in the package.json file
    /// @param c0 the x coordinate of the public key
    /// @param c1 the y coordinate of the public key
    /// @return precompute the precomputed table as a bytes
    function precompute_shamir_table(uint256 c0, uint256 c1) private returns (bytes memory precompute) {
        // Precompute a 8 dimensional table for Shamir's trick from c0 and c1
        // and return the table as a bytes
        string[] memory inputs = new string[](4);
        inputs[0] = "npx";
        inputs[1] = "@0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation";
        inputs[2] = vm.toString(c0);
        inputs[3] = vm.toString(c1);
        precompute = vm.ffi(inputs);
    }

    function verify_precompute(bytes memory prec) private returns (bool) {
        // address of the precomputations bytecode contract
        address a_prec = address(uint160(_prec_address));
        // set the precomputed points as the bytecode of the contract
        vm.etch(a_prec, prec);

        //pointer to an elliptic point
        uint256[2] memory px;

        // check the precomputations are correct, all point are on curve P256
        for (uint256 i = 1; i < 256; i++) {
            uint256 offset = 64 * i;

            assembly {
                extcodecopy(a_prec, px, offset, 64)
            }

            assertEq(Secp256r1.ecAff_isOnCurve(px[0], px[1]), true);
        }

        return true;
    }
}
