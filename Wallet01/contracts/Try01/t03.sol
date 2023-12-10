// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./Manage.sol";

contract t003{
    // function add(address addr1, address addr2, uint256 num)public  {
    //     Manageowner(addr1).addOwnersAndThreshold(addr2,num);
    // }

    function add2(address addr1, bytes memory data)public  {
        bool success;
        (success,) = addr1.call(data);
    } 
}