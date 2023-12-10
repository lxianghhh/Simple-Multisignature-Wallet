// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

contract te{
    function sendeth(address to, uint256 value)public payable {
        bool success;
        (success,) = to.call{value: value}("");
    }
}