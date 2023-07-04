// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { PRBTest } from "../lib/prb-test/src/PRBTest.sol";
import { StdUtils } from "../lib/forge-std/src/StdUtils.sol";
import { ECDSA } from "../src/utils/ECDSA.sol";
import { ECDSA256r1Precompute, mulmuladd as _mulmuladd } from "../src/ECDSA256r1Precompute.sol";
import { U256Modp, wrap as w } from "../src/utils/U256Modp.sol";
import { n } from "../src/utils/constants.sol";

struct TestVectors {
    // public key
    uint256 qx;
    uint256 qy;
    // number of tests
    uint256 numtests;
    // JSON string containing the test vectors
    string fixtures;
}

contract ImplementationECDSA256r1Precompute {
    function verify(bytes32 message, uint256 r, uint256 s, address precomputedTable) external returns (bool) {
        return ECDSA256r1Precompute.verify(message, r, s, precomputedTable);
    }

    function mulmuladd(U256Modp scalar_u, U256Modp scalar_v, address precomputedTable) external returns (U256Modp) {
        return _mulmuladd(scalar_u, scalar_v, precomputedTable);
    }
}

/// @title Test suite for the ECDSA256r1Precompute library
/// @notice This contract tests all aspects of ECDSA256r1Precompute library functionality
/// @dev Uses PRBTest for testing, StdUtils for the bound utility function
contract Ecdsa256r1PrecomputTest is StdUtils, PRBTest {
    TestVectors private validVectors;
    TestVectors private invalidVectors;
    address private precomputeAddress;
    ImplementationECDSA256r1Precompute private implementation;

    string private constant VALID_VECTOR_FILE_PATH = "test/fixtures/vec_valid.json";
    string private constant INVALID_VECTOR_FILE_PATH = "test/fixtures/vec_invalid.json";

    /// @notice Load the test vectors once
    constructor() {
        // load the test vectors from the provided JSON files
        validVectors = _loadFixtures(true);
        invalidVectors = _loadFixtures(false);
    }

    /// @notice set the precomputeAddress before each test case and deploy the implem
    function setUp() public {
        // deploy the implementation contract
        implementation = new ImplementationECDSA256r1Precompute();

        // set the address where the the precomputed table will live
        // TODO: fuzz this value
        precomputeAddress = vm.addr(42);
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

    // @notice precumpute a shamir table of 256 points for a given pubKey
    /// @dev this function execute a JS package listed in the package.json file
    /// @param c0 the x coordinate of the public key
    /// @param c1 the y coordinate of the public key
    /// @return precompute the precomputed table as a bytes
    function _precomputeShamirTable(uint256 c0, uint256 c1) private returns (bytes memory precompute) {
        // Precompute a 8 dimensional table for Shamir's trick from c0 and c1
        // and return the table as a bytes
        string[] memory inputs = new string[](4);
        inputs[0] = "npx";
        inputs[1] = "@0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation";
        inputs[2] = vm.toString(c0);
        inputs[3] = vm.toString(c1);
        precompute = vm.ffi(inputs);
    }

    /// @notice Modifier for generating the precomputed table and storing it in the precompiled contract
    /// @dev Uses `_precomputeShamirTable` function to generate the precomputed table
    modifier _preparePrecomputeTable() {
        // generate the precomputed table
        bytes memory precompute = _precomputeShamirTable(validVectors.qx, validVectors.qy);

        // set the precomputed points as the bytecode of the target contract
        vm.etch(precomputeAddress, precompute);

        // run the test
        _;

        // unset the bytecode of the target contract
        vm.etch(precomputeAddress, hex"00");
    }

    /*//////////////////////////////////////////////////////////////
                                 TESTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Test function for verifying the precomputation storing process
    function test_VerifyPrecomputation() external _preparePrecomputeTable {
        // pointer to an elliptic point
        uint256[2] memory px;
        // address of the precompiled contract
        address target = precomputeAddress;

        // check the precomputations are correct
        for (uint256 i = 1; i < 256; i++) {
            uint256 offset = 64 * i;

            assembly {
                extcodecopy(target, px, offset, 64)
            }

            assertTrue(ECDSA.affIsOnCurve(U256Modp.wrap(px[0]), U256Modp.wrap(px[1])));
        }
    }

    /// @notice Test function for verifying valid vectors
    /// @dev Ensures that all the valid test vectors are working correctly
    function test_VerifyValidVectorsCorrect() external _preparePrecomputeTable {
        // load the wycheproof test vectors
        TestVectors memory testVectors = validVectors;

        for (uint256 i = 1; i <= testVectors.numtests; i++) {
            // get the test vector (message, signature)
            (uint256 r, uint256 s, bytes32 message) = _getTestVector(testVectors.fixtures, vm.toString(i));
            // run the verification function with the test vector
            bool isValid = implementation.verify(message, r, s, precomputeAddress);
            // ensure the result is the expected one
            assertTrue(isValid);
        }
    }

    /// @notice Test function for verifying invalid vectors
    /// @dev Ensures that all the invalid test vectors are not working
    function test_VerifyInvalidVectorsIncorrect() external _preparePrecomputeTable {
        // load the wycheproof test vectors
        TestVectors memory testVectors = invalidVectors;

        for (uint256 i = 1; i <= testVectors.numtests; i++) {
            // get the test vector (message, signature)
            (uint256 r, uint256 s, bytes32 message) = _getTestVector(testVectors.fixtures, vm.toString(i));
            // run the verification function with the test vector
            bool isValid = implementation.verify(message, r, s, precomputeAddress);
            // ensure the result is the expected one
            assertFalse(isValid);
        }
    }

    /// @notice Test function for verifying incorrect signatures
    /// @dev Ensures that incorrect signatures are not valid
    function test_VerifyIncorrectSignatureFail() external _preparePrecomputeTable {
        // expect to fail because rs[0] == 0
        bool isValid = implementation.verify(bytes32("hello"), uint256(0), uint256(1), precomputeAddress);
        assertFalse(isValid);

        // expect to fail because rs[1] == 0
        isValid = implementation.verify(bytes32("hello"), uint256(1), uint256(0), precomputeAddress);
        assertFalse(isValid);

        // expect to fail because rs[0] > n
        isValid = implementation.verify(bytes32("hello"), n + 1, uint256(1), precomputeAddress);
        assertFalse(isValid);

        // expect to fail because rs[0] == n
        isValid = implementation.verify(bytes32("hello"), n, uint256(1), precomputeAddress);
        assertFalse(isValid);

        // expect to fail because rs[1] > n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n + 1, precomputeAddress);
        assertFalse(isValid);

        // expect to fail because rs[1] == n
        isValid = implementation.verify(bytes32("hello"), uint256(1), n, precomputeAddress);
        assertFalse(isValid);
    }

    /// @notice Test function for verifying incorrect addresses
    /// @dev Ensures that incorrect addresses fail verification (0x00 + precompile addresses + some extra empty ones)
    function test_VerifyIncorectAddressesFail() external _preparePrecomputeTable {
        // get a valid test vector (message, signature)
        (uint256 r, uint256 s, bytes32 message) = _getTestVector(validVectors.fixtures, "1");

        for (uint160 addr = 0; addr <= 20; addr++) {
            // run the verification function with the correct test vector BUT an invalid address
            bool isValid = implementation.verify(message, r, s, address(addr));
            assertFalse(isValid);
        }
    }
}
