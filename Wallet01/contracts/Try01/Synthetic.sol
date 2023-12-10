// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract Syntheticsign{
    
    function merge(bytes memory signatures)public pure returns(bytes memory) {
        bytes memory a = abi.encodePacked(signatures);
        ;


    }
}