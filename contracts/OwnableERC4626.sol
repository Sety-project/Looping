// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/* this was needed to make the contract compile, 
because both balancer and openzepppelin ERC4626 uses IERC20, 
but from different locations.
*/
abstract contract OwnableERC4626 is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    address internal immutable _base;
    constructor(address quote, address base) 
    ERC4626(IERC20(quote))
    Ownable(msg.sender)
    {
        _base = base;
    }
}
