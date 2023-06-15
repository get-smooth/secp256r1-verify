// SPDX-License-Identifier: APACHE-2.0
pragma solidity ^0.8.19;

import { PRBTest } from "../lib/prb-test/src/PRBTest.sol";
import { ECDSA, p, gx, gy, n } from "../src/utils/ECDSA.sol";
import { ECDSA256r1 } from "../src/ECDSA256r1.sol";

struct TestVectors {
    uint256[2] pubKey;
    uint256 numtests;
    string fixtures;
}

contract Ecdsa256r1Test is PRBTest {
    TestVectors private $validVectors;
    TestVectors private $invalidVectors;

    string private constant VALID_VECTOR_FILE_PATH = "test/fixtures/vec_valid.json";
    string private constant INVALID_VECTOR_FILE_PATH = "test/fixtures/vec_invalid.json";

    // This function is invoked once before all tests are run
    constructor() {
        // load the test vectores from the provided JSON files
        $validVectors = _loadFixtures(true);
        $invalidVectors = _loadFixtures(false);
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
        // all the content of the JSON file
        string memory fixtures =
            flag == true ? vm.readFile(VALID_VECTOR_FILE_PATH) : vm.readFile(INVALID_VECTOR_FILE_PATH);

        uint256[2] memory pubKey;
        pubKey[0] = vm.parseJsonUint(fixtures, ".keyx");
        pubKey[1] = vm.parseJsonUint(fixtures, ".keyy");
        uint256 numtests = vm.parseJsonUint(fixtures, ".NumberOfTests");

        return TestVectors(pubKey, numtests, fixtures);
    }

    /// @notice get the test vector n from the JSON string
    /// @param fixtures The JSON string containing the test vectors
    /// @param id The test vector number to get
    /// @return rs The signature (r, s) of the test vector
    /// @return message The message of the test vector
    function _getTestVector(
        string memory fixtures,
        string memory id
    )
        internal
        returns (uint256[2] memory rs, bytes32 message)
    {
        rs[0] = vm.parseJsonUint(fixtures, string.concat(".sigx_", id));
        rs[1] = vm.parseJsonUint(fixtures, string.concat(".sigy_", id));
        message = vm.parseJsonBytes32(fixtures, string.concat(".msg_", id));
    }

    /// @notice ensure the library returned the expected result for the test vectors
    /// @param flag `true` to load valid test vectors, `false` to load invalid test vectors
    function _validateInvariantEcMulMulAdd(bool flag) internal {
        // load the wycheproof test vectors
        TestVectors memory testVectors = flag == true ? $validVectors : $invalidVectors;

        for (uint256 i = 1; i <= testVectors.numtests; i++) {
            // get the test vector (message, signature)
            (uint256[2] memory rs, bytes32 message) = _getTestVector(testVectors.fixtures, vm.toString(i));
            // run the verification function with the test vector
            bool isStandardValid = ECDSA256r1.verify(message, rs, testVectors.pubKey);
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

        uint256 _4P_res2 = ECDSA256r1.mulmuladd(gx, gy, 4, 0);
        assertEq(_4P_res1, _4P_res2);

        uint256[2] memory nQ;
        (nQ[0], nQ[1]) = ECDSA.zz2Aff(Q[0], Q[1], Q[2], Q[3]);
        uint256 _4P_res3 = ECDSA256r1.mulmuladd(nQ[0], nQ[1], 2, 1);

        assertEq(_4P_res1, _4P_res3);
    }

    function test_MulMullAddMultipleBy0Fail(uint256 q0, uint256 q1) public {
        uint256 res = ECDSA256r1.mulmuladd(q0, q1, 0, 0);
        assertEq(res, 0);
    }

    // test valid vectors, all assert shall be true
    function test_VerifyValidVectorsCorrect() external {
        _validateInvariantEcMulMulAdd(true);
    }

    // test invalid vectors, all assert shall be false
    function test_VerifyInvalidVectorsIncorrect() public {
        _validateInvariantEcMulMulAdd(false);
    }

    // test invalid vectors, all assert shall be false
    function test_VerifySignatureValidity() public {
        // expect to fail because rs[0] == 0
        bool isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(0), uint256(1)], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because rs[1] == 0
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), uint256(0)], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because rs[0] > n
        isValid = ECDSA256r1.verify(bytes32("hello"), [n + 1, uint256(1)], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because rs[0] == n
        isValid = ECDSA256r1.verify(bytes32("hello"), [n, uint256(1)], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because rs[1] > n
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), n + 1], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because rs[1] == n
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), n], [uint256(1), uint256(1)]);
        assertFalse(isValid);

        // expect to fail because q[0] == 0 (affine coordinates not on the curve)
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), uint256(1)], [0, uint256(1)]);
        assertFalse(isValid);

        // expect to fail because q[1] == 0 (affine coordinates not on the curve)
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), uint256(1)], [uint256(1), 0]);
        assertFalse(isValid);

        // expect to fail because q[0] == p (affine coordinates not on the curve)
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), uint256(1)], [p, uint256(1)]);
        assertFalse(isValid);

        // expect to fail because q[1] == p (affine coordinates not on the curve)
        isValid = ECDSA256r1.verify(bytes32("hello"), [uint256(1), uint256(1)], [uint256(1), p]);
        assertFalse(isValid);
    }
}
