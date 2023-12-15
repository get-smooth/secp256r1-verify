// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "../../lib/prb-test/src/PRBTest.sol";
import { ECDSA, p, gx, gy, n } from "../../src/utils/ECDSA.sol";
import { ECDSA256r1 } from "../../src/ECDSA256r1.sol";
import { stdJson } from "../../lib/forge-std/src/StdJson.sol";

contract ImplementationECDSA256r1 {
    function verify(bytes32 message, uint256 r, uint256 s, uint256 qx, uint256 qy) external returns (bool) {
        return ECDSA256r1.verify(message, r, s, qx, qy);
    }

    function mulmuladd(uint256 q0, uint256 q1, uint256 n0, uint256 n1) external returns (uint256) {
        return ECDSA256r1.mulmuladd(q0, q1, n0, n1);
    }
}

contract Ecdsa256r1Test is PRBTest {
    using stdJson for string;

    // describe one test vector
    struct Vector {
        bytes32 hash;
        bytes32 r;
        bytes32 s;
        bytes32 x;
        bytes32 y;
    }

    struct TestVectors {
        // number of tests
        uint256 numtests;
        // JSON string containing the test vectors
        string fixtures;
    }

    TestVectors private $validFixtures;
    TestVectors private $invalidFixtures;
    ImplementationECDSA256r1 private implementation;

    string private constant VALID_VECTOR_FILE_PATH = "test/fixtures/vectors.valid.json";
    string private constant INVALID_VECTOR_FILE_PATH = "test/fixtures/vectors.invalid.json";

    // This function is invoked once before all tests are run
    constructor() {
        // load the test vectores from the provided JSON files
        $validFixtures = _loadFixtures(true);
        $invalidFixtures = _loadFixtures(false);

        // deploy the implementation contract
        implementation = new ImplementationECDSA256r1();
    }

    /*//////////////////////////////////////////////////////////////
                                 UTILS
    //////////////////////////////////////////////////////////////*/

    /// @notice load the test vectors
    /// @dev fixtures generated using wycheproof. This function uses the `readFile` cheatcode.
    ///      It can only read files from the paths defined in the foundry.toml file
    /// @param flag `true` to load valid test vectors, `false` to load invalid test vectors
    /// @return testvectors The test vectors
    function _loadFixtures(bool flag) internal returns (TestVectors memory testvectors) {
        // load the correct list of test vectors from the JSON files
        testvectors.fixtures =
            flag == true ? vm.readFile(VALID_VECTOR_FILE_PATH) : vm.readFile(INVALID_VECTOR_FILE_PATH);

        // get the number of test vectors
        testvectors.numtests = vm.parseJsonUint(testvectors.fixtures, "$.nbOfVectors");
    }

    /// @notice get the test vector n from the JSON string
    /// @param fixtures The JSON string containing the test vectors
    /// @param id The test vector number to get
    /// @return x uint256 public key x coordinate
    /// @return y uint256 public key y coordinate
    /// @return r uint256 The r value of the ECDSA signature.
    /// @return s uint256 The s value of the ECDSA signature.
    /// @return message The message of the test vector
    function _getTestVector(
        string memory fixtures,
        string memory id
    )
        internal
        pure
        returns (uint256 x, uint256 y, uint256 r, uint256 s, bytes32 message)
    {
        // load the JSON vector object in raw format
        bytes memory parsedDeployData = fixtures.parseRaw(string.concat("$.vectors[", id, "]"));
        // decode the JSON vector object into a Vector struct
        Vector memory vector = abi.decode(parsedDeployData, (Vector));

        // return the test vector formatted as expected
        x = uint256(vector.x);
        y = uint256(vector.y);
        r = uint256(vector.r);
        s = uint256(vector.s);
        message = vector.hash;
    }

    /// @notice ensure the library returned the expected result for the test vectors
    /// @param flag `true` to load valid test vectors, `false` to load invalid test vectors
    function _validateInvariantEcMulMulAdd(bool flag) internal {
        // load the wycheproof test vectors
        TestVectors memory testVectors = flag == true ? $validFixtures : $invalidFixtures;

        for (uint256 i = 0; i < testVectors.numtests; i++) {
            (uint256 x, uint256 y, uint256 r, uint256 s, bytes32 message) =
                _getTestVector(testVectors.fixtures, vm.toString(i));

            // run the verification function with the test vector
            bool isStandardValid = implementation.verify(message, r, s, x, y);

            // ensure the result is the expected one
            assertEq(isStandardValid, flag);
        }
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/
    function test_InvariantEdge() public {
        // choose Q=2P, then verify duplication is ok
        uint256[4] memory Q;
        (Q[0], Q[1], Q[2], Q[3]) = ECDSA.zzDouble(gx, gy, 1, 1);

        uint256[4] memory _4P;
        (_4P[0], _4P[1], _4P[2], _4P[3]) = ECDSA.zzDouble(Q[0], Q[1], Q[2], Q[3]);

        uint256 _4P_res1;
        (_4P_res1,) = ECDSA.zz2Aff(_4P[0], _4P[1], _4P[2], _4P[3]);

        uint256 _4P_res2 = implementation.mulmuladd(gx, gy, 4, 0);
        assertEq(_4P_res1, _4P_res2);

        uint256[2] memory nQ;
        (nQ[0], nQ[1]) = ECDSA.zz2Aff(Q[0], Q[1], Q[2], Q[3]);
        uint256 _4P_res3 = implementation.mulmuladd(nQ[0], nQ[1], 2, 1);

        assertEq(_4P_res1, _4P_res3);

        // edge case from nlordell
        (uint256 niordellX, uint256 niordellY, uint256 niordellU, uint256 niordellV) = (
            0xe2534a3532d08fbba02dde659ee62bd0031fe2db785596ef509302446b030852, //x
            0x1f0ea8a4b39cc339e62011a02579d289b103693d0cf11ffaa3bd3dc0e7b12739, //y
            0xd13800358b760290af0671ee67368e9702a7145d1b9a0024b0b61ffe7bce9214, //u
            0x344e000d62dd80a42bc19c7b99cda3a5c0a9c51746e680092c2d87ff9ef3af6f //v
        );
        assertEq(
            0xcfcfa95b195904fd97b548d9e3cd2e023e06b4f10a87c645c7d4f74a0e206bad,
            implementation.mulmuladd(niordellX, niordellY, niordellU, niordellV)
        );

        // edge case for Shamir
        (uint256 shamirK, uint256 shamirX,) = (
            0xffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc63254f, //k
            0x7CF27B188D034F7E8A52380304B51AC3C08969E277F21B35A60B48FC47669978, // x
            0xF888AAEE24712FC0D6C26539608BCF244582521AC3167DD661FB4862DD878C2E // y
        );
        assertEq(shamirX, implementation.mulmuladd(0, 0, shamirK, 0));
    }

    function test_MulMullAddMultipleBy0Fail_ReportSkip(uint256 q0, uint256 q1) public {
        uint256 res = implementation.mulmuladd(q0, q1, 0, 0);
        assertEq(res, 0);
    }

    // test valid vectors, all assert shall be true
    function test_VerifyValidVectorsCorrect() external {
        _validateInvariantEcMulMulAdd(true);
    }

    // test invalid vectors, all assert shall be false
    function test_VerifyInvalidVectorsIncorrect_ReportSkip() public {
        _validateInvariantEcMulMulAdd(false);
    }

    // test invalid vectors, all assert shall be false
    function test_VerifySignatureValidity_ReportSkip() public {
        // expect to fail because rs[0] == 0
        bool isValid = implementation.verify(bytes32("hello"), uint256(0), uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[1] == 0
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(0), uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[0] > n
        isValid = implementation.verify(bytes32("hello"), n + 1, uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[0] == n
        isValid = implementation.verify(bytes32("hello"), n, uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[1] > n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n + 1, uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[1] == n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n, uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because q[0] == 0 (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), 0, uint256(1));
        assertFalse(isValid);

        // expect to fail because q[1] == 0 (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), uint256(1), 0);
        assertFalse(isValid);

        // expect to fail because q[0] == p (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), p, uint256(1));
        assertFalse(isValid);

        // expect to fail because q[1] == p (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), uint256(1), p);
        assertFalse(isValid);
    }
}
