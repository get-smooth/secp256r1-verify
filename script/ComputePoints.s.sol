// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19 <0.9.0;

import { Script } from "./BaseScript.sol";
import { ECDSA256r1 } from "src/ECDSA256r1.sol";

/// @notice This script compute the points for ECDSA256r1 verification using the npm package
/// @dev The goal of this script is for composability. We want to allow people that install this project as dep'
///      to be able to use the computed points without having to install the associated npm package.
///      If you are contributing on this project, you should know you can use the npm package directly or
///      use the make command exposed for this purpose `c0=xxx c1=xxx make compute`
contract MyScript is Script {
    function run() external returns (bytes memory points) {
        uint256 c0 = vm.envUint("c0");
        uint256 c1 = vm.envUint("c1");

        // Compute a 8 dimensional table for Shamir's trick from c0 and c1
        // and return the table as a bytes
        string[] memory inputs = new string[](4);
        inputs[0] = "npx";
        inputs[1] = "@0x90d2b2b7fb7599eebb6e7a32980857d8/secp256r1-computation";
        inputs[2] = vm.toString(c0);
        inputs[3] = vm.toString(c1);
        points = vm.ffi(inputs);
    }
}

/*
    ℹ️ HOW TO USE THIS SCRIPT:
    c0=<C0> c1=<C1> forge script script/ComputePoints.s.sol:MyScript

    example:
    c0=18614955573315897657680976650685450080931919913269223958732452353593824192568 \
    c1=9022311634785988016657019872538756956741425454756992532798853983315057399020 \
    forge script script/ComputePoints.s.sol:MyScript
*/
