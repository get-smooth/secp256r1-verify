// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "../lib/prb-test/src/PRBTest.sol";
import { ECDSA } from "../src/utils/ECDSA.sol";
import { p, gx, gy, _0, _1, _2 } from "../src/utils/U256Modp.sol";
import { n } from "../src/utils/constants.sol";
import { ECDSA256r1, mulmuladd as _mulmuladd } from "../src/ECDSA256r1.sol";
import { U256Modp } from "../src/utils/U256Modp.sol";

contract ImplementationECDSA256r1 {
    function verify(bytes32 message, uint256 r, uint256 s, uint256 qx, uint256 qy) external returns (bool) {
        return ECDSA256r1.verify(message, r, s, qx, qy);
    }

    function mulmuladd(U256Modp Q0, U256Modp Q1, U256Modp scalar_u, U256Modp scalar_v) external returns (U256Modp X) {
        return _mulmuladd(Q0, Q1, scalar_u, scalar_v);
    }
}

struct TestVectors {
    // public key
    uint256 qx;
    uint256 qy;
    // number of tests
    uint256 numtests;
    // JSON string containing the test vectors
    string fixtures;
}

contract Ecdsa256r1Test is PRBTest {
    TestVectors private validVectors;
    TestVectors private invalidVectors;
    ImplementationECDSA256r1 private implementation;

    string private constant VALID_VECTOR_FILE_PATH = "test/fixtures/vec_valid.json";
    string private constant INVALID_VECTOR_FILE_PATH = "test/fixtures/vec_invalid.json";

    // This function is invoked once before all tests are run
    constructor() {
        // load the test vectores from the provided JSON files
        validVectors = _loadFixtures(true);
        invalidVectors = _loadFixtures(false);
    }

    function setUp() public {
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
        // all the content of the JSON file
        testvectors.fixtures =
            flag == true ? vm.readFile(VALID_VECTOR_FILE_PATH) : vm.readFile(INVALID_VECTOR_FILE_PATH);

        testvectors.qx = vm.parseJsonUint(testvectors.fixtures, ".keyx");
        testvectors.qy = vm.parseJsonUint(testvectors.fixtures, ".keyy");
        testvectors.numtests = vm.parseJsonUint(testvectors.fixtures, ".NumberOfTests");
    }

    /// @notice get the test vector n from the JSON string
    /// @param fixtures The JSON string containing the test vectors
    /// @param id The test vector number to get
    /// @return r uint256 The r value of the ECDSA signature.
    /// @return s uint256 The s value of the ECDSA signature.
    /// @return message The message of the test vector
    function _getTestVector(
        string memory fixtures,
        string memory id
    )
        internal
        returns (uint256 r, uint256 s, bytes32 message)
    {
        r = vm.parseJsonUint(fixtures, string.concat(".sigx_", id));
        s = vm.parseJsonUint(fixtures, string.concat(".sigy_", id));
        message = vm.parseJsonBytes32(fixtures, string.concat(".msg_", id));
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/
    function test_InvariantEdge() public {
        // choose Q=2P, then verify duplication is ok
        U256Modp[4] memory Q;
        (Q[0], Q[1], Q[2], Q[3]) = ECDSA.zzDouble(gx, gy, _1, _1);

        U256Modp[4] memory _4P;
        (_4P[0], _4P[1], _4P[2], _4P[3]) = ECDSA.zzDouble(Q[0], Q[1], Q[2], Q[3]);

        (U256Modp _4P_res1,) = ECDSA.zz2Aff(_4P[0], _4P[1], _4P[2], _4P[3]);

        U256Modp _4P_res2 = implementation.mulmuladd(gx, gy, U256Modp.wrap(4), _0);
        assertEq(_4P_res1.uw(), _4P_res2.uw());

        (U256Modp nQ0, U256Modp nQ1) = ECDSA.zz2Aff(Q[0], Q[1], Q[2], Q[3]);
        U256Modp _4P_res3 = implementation.mulmuladd(nQ0, nQ1, _2, _1);
        assertEq(_4P_res1.uw(), _4P_res3.uw());
    }

    function test_MulMullAddMultipleBy0Fail(uint256 q0, uint256 q1) public {
        U256Modp res = implementation.mulmuladd(U256Modp.wrap(q0), U256Modp.wrap(q1), _0, _0);
        assertEq(res.uw(), 0);
    }

    /// @notice ensure all valid vectors pass
    function test_VerifyValidVectorsCorrect() external {
        TestVectors memory testVectors = validVectors;

        for (uint256 i = 1; i <= testVectors.numtests; i++) {
            // get the test vector (message, signature)
            (uint256 r, uint256 s, bytes32 message) = _getTestVector(testVectors.fixtures, vm.toString(i));
            // run the verification function with the test vector
            bool isStandardValid = implementation.verify(message, r, s, testVectors.qx, testVectors.qy);
            // ensure the result is the expected one
            assertTrue(isStandardValid);
        }
    }

    /// @notice ensure all invalid vectors fail
    function test_VerifyInvalidVectorsIncorrect() public {
        TestVectors memory testVectors = invalidVectors;

        for (uint256 i = 1; i <= testVectors.numtests; i++) {
            // get the test vector (message, signature)
            (uint256 r, uint256 s, bytes32 message) = _getTestVector(testVectors.fixtures, vm.toString(i));
            // run the verification function with the test vector
            bool isValid = implementation.verify(message, r, s, testVectors.qx, testVectors.qy);
            // ensure the result is the expected one
            assertFalse(isValid);
        }
    }

    // TODO: REDUNDANT?
    /// @notice Test function for verifying incorrect signatures
    /// @dev Ensures that incorrect signatures are not valid
    function test_VerifyIncorrectSignatureFail() public {
        // expect to fail because rs[0] == 0
        bool isValid = implementation.verify(bytes32("hello"), uint256(0), uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // expect to fail because rs[1] == 0
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(0), uint256(1), uint256(1));
        assertFalse(isValid);

        // // expect to fail because rs[0] > n
        isValid = implementation.verify(bytes32("hello"), n + 1, uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // // expect to fail because rs[0] == n
        isValid = implementation.verify(bytes32("hello"), n, uint256(1), uint256(1), uint256(1));
        assertFalse(isValid);

        // // expect to fail because rs[1] > n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n + 1, uint256(1), uint256(1));
        assertFalse(isValid);

        // // expect to fail because rs[1] == n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n, uint256(1), uint256(1));
        assertFalse(isValid);

        // // expect to fail because q[0] == 0 (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), 0, uint256(1));
        assertFalse(isValid);

        // // expect to fail because q[1] == 0 (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), uint256(1), 0);
        assertFalse(isValid);

        // // expect to fail because q[0] == p (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), p.uw(), uint256(1));
        assertFalse(isValid);

        // // expect to fail because q[1] == p (affine coordinates not on the curve)
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(1), uint256(1), p.uw());
        assertFalse(isValid);
    }
}
