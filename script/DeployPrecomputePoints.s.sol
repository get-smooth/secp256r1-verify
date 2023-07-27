// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "./BaseScript.sol";

error FailedToDeployPrecompiled();

/// @notice This script deploys the precomputed points on-chain
contract MyScript is BaseScript {
    //---------------------------------------------------------------------------------------------------------------//
    // Opcode  | Opcode + Arguments  | Description  | Stack View                                                     //
    //---------------------------------------------------------------------------------------------------------------//
    // 0x60    |  0x600B             | PUSH1 11     | codeOffset                                                     //
    // 0x59    |  0x59               | MSIZE        | 0 codeOffset                                                   //
    // 0x81    |  0x81               | DUP2         | codeOffset 0 codeOffset                                        //
    // 0x38    |  0x38               | CODESIZE     | codeSize codeOffset 0 codeOffset                               //
    // 0x03    |  0x03               | SUB          | (codeSize - codeOffset) 0 codeOffset                           //
    // 0x80    |  0x80               | DUP          | (codeSize - codeOffset) (codeSize - codeOffset) 0 codeOffset   //
    // 0x92    |  0x92               | SWAP3        | codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset)   //
    // 0x59    |  0x59               | MSIZE        | 0 codeOffset (codeSize - codeOffset) 0 (codeSize - codeOffset) //
    // 0x39    |  0x39               | CODECOPY     | 0 (codeSize - codeOffset)                                      //
    // 0xf3    |  0xf3               | RETURN       |                                                                //
    //---------------------------------------------------------------------------------------------------------------//
    bytes private constant CONSTRUCTION_CODE = hex"600B5981380380925939F3";

    function run() external broadcast returns (address precompiledAddress) {
        // Precompiled points calculated off-chain. See the `@0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation`
        // npm package
        bytes memory precomputedPoints = vm.envBytes("PRECOMPUTED_POINTS");

        // append the construction code to the precomputed points and deploy the creation code
        bytes memory creationCode = abi.encodePacked(
            CONSTRUCTION_CODE, // Returns all code in the contract except for the first 11 (0B in hex) bytes.
            precomputedPoints // The runtime code. Capped at the code size limit.
        );

        uint256 precomputedCode;
        assembly ("memory-safe") {
            // Deploy a new contract with the generated creation code.
            precompiledAddress := create(0, add(creationCode, 32), mload(creationCode))
            precomputedCode := extcodesize(precompiledAddress)
        }

        // Check that the precompiled contract was deployed correctly
        if (precomputedCode == 0) revert FailedToDeployPrecompiled();
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    PRECOMPUTED_POINTS=<VALUE> forge script script/DeployPrecomputePoints.s.sol:MyScript --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRECOMPUTED_POINTS=<VALUE> PRIVATE_KEY=<PRIVATE_KEY> forge script script/DeployPrecomputePoints.s.sol:MyScript \
    --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    PRECOMPUTED_POINTS=<VALUE> forge script script/DeployPrecomputePoints.s.sol:MyScript --rpc-url \
    http://127.0.0.1:8545 --broadcast --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --mnemonics "test test test test test test test test test test test junk"


    ℹ️ HOW TO CHECK THE DEPLOYED CODE:
    cast code <CONTRACT_ADDRESS> --rpc-url <RPC_URL>

*/
