// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import "./BaseScript.sol";
import { ECDSA256r1 } from "src/ECDSA256r1.sol";

contract LibraryWrapper {
    function verify(bytes32 message, uint256 r, uint256 s, uint256 qx, uint256 qy) external returns (bool) {
        return ECDSA256r1.verify(message, r, s, qx, qy);
    }
}

/// @notice This script deploys the ECDSA256r1 library
contract MyScript is BaseScript {
    function run() external broadcast returns (address addr) {
        // deploy the library contract and return the address
        addr = address(new LibraryWrapper());
    }
}

/*

    ℹ️ HOW TO USE THIS SCRIPT USING A LEDGER:
    forge script script/DeployEcdsa256r1.s.sol:MyScript --rpc-url <RPC_URL> --ledger --sender <ACCOUNT_ADDRESS> \
    [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT WITH AN ARBITRARY PRIVATE KEY (NOT RECOMMENDED):
    PRIVATE_KEY=<PRIVATE_KEY> forge script script/DeployEcdsa256r1.s.sol:MyScript --rpc-url <RPC_URL> [--broadcast]


    ℹ️ HOW TO USE THIS SCRIPT ON ANVIL IN DEFAULT MODE:
    forge script script/DeployEcdsa256r1.s.sol:MyScript --rpc-url http://127.0.0.1:8545 --broadcast --sender \
    0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --mnemonics "test test test test test test test test test test test junk"


    ℹ️ HOW TO CALL THE LIBRARY ONCE DEPLOYED:
    cast call <CONTRACT_ADDRESS> verify(bytes32,uint256,uint256,uint256,uint256)" <MESSAGE> <R> <S> <QX> <QY>

    example:
        cast call 0x5fbdb2315678afecb367f032d93f642f64180aa3 \
        "verify(bytes32,uint256,uint256,uint256,uint256)" \
        0xbb5a52f42f9c9261ed4361f59422a1e30036e7c32b270c8807a419feca605023 \
        19738613187745101558623338726804762177711919211234071563652772152683725073944 \
        34753961278895633991577816754222591531863837041401341770838584739693604822390 \
        18614955573315897657680976650685450080931919913269223958732452353593824192568 \
        90223116347859880166570198725387569567414254547569925327988539833150573990206

*/
