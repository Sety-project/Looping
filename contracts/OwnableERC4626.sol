// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* this was needed to make the contract compile, 
because both balancer and openzepppelin ERC4626 uses IERC20, 
but from different locations.
*/
abstract contract OwnableERC4626 is ERC4626, Ownable {
    using SafeERC20 for IERC20;
    
    constructor(address quote)
    ERC4626(IERC20(quote))
    ERC20("vToken", "vToken")
    Ownable(msg.sender)
    payable
    {
    }

    function mySafeTransferFrom(address token, address from, address to, uint value) internal
    {
        SafeERC20.safeTransferFrom(IERC20(token), from, to, value);
    }
}
