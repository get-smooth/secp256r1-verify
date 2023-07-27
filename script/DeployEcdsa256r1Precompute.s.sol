// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { BaseScript } from "./BaseScript.sol";
import { ECDSA256r1Precompute } from "src/ECDSA256r1Precompute.sol";

contract LibraryWrapper {
    function verify(bytes32 message, uint256 r, uint256 s, address precomputedTable) external returns (bool) {
        return ECDSA256r1Precompute.verify(message, r, s, precomputedTable);
    }
}

/// @notice This script deploys the ECDSA256r1Precompute library
/// @dev The private key of the deployer is used to sign the transaction.
///      Favor using an hardware wallet instead of passing the private key as an environment variable
contract MyScript is BaseScript {
    function run() external broadcast returns (address addr) {
        // deploy the library contract and push the address in the stack
        addr = address(new LibraryWrapper());
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script script/DeployEcdsa256r1Precompute.s.sol:MyScript --rpc-url <RPC_URL> --ledger \
    --sender <ACCOUNT_ADDRESS> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script script/DeployEcdsa256r1Precompute.s.sol:MyScript \
    --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script script/DeployEcdsa256r1Precompute.s.sol:MyScript --rpc-url http://127.0.0.1:8545 --broadcast \
    --sender  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
    --mnemonics "test test test test test test test test test test test junk"


    ℹ️ HOW TO CALL THE LIBRARY ONCE DEPLOYED:
    cast call <CONTRACT_ADDRESS> verify(bytes32,uint256,uint256,address)" <MESSAGE> <R> <S> <PRECOMPILE_ADDRESS>

    example:
        cast call 0x2924909a71195b5d15de8c14ad676be369bfcbc3 \
        "verify(bytes32,uint256,uint256,address)" \
        0xbb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca605023 \
        19738613187745101558623338726804762177711919211234071563652772152683725073944 \
        34753961278895633991577816754222591531863837041401341770838584739693604822390 \
        0x5a0b3ddeb4deb241f7c2ee92ac5705d4d96a9cf3

    Note: Use the `script/PrecomputePoints.s.sol` script, the npm script or the make command to
    generate the precomputed points then deploy them using the `script/DeployPrecomputePoints.s.sol`
    forge script to get the address of the contrat to pass as the last argument of the verify function.

*/
