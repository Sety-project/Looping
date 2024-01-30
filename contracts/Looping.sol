pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
// import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
// import "lib/forge-std/src/console.sol";

abstract contract Looping is ERC4626, Ownable , IFlashLoanRecipient {
    address private constant BALANCER_FLASHLOAN = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address private constant WETH = address(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
    address private constant WSTETH = address(0x5979D7b546E38E414F7E9822514be443A4800529);
    address private constant AAVE = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    address private constant AAVE_ORACLE = address(0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7);
    address private constant BALANCER_SWAP = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    uint16 private max_ltv; // in bps
    uint16 private slippage; // in bps

    constructor(IERC20 _asset) 
    ERC4626(_asset)
    Ownable(msg.sender)
    {
        IPool(AAVE).setUserEMode(2);
        max_ltv = 9000;
        slippage = 50;
    }

    function setExecutionParams(uint16 _max_ltv, uint16 _slippage) external onlyOwner {
        max_ltv = _max_ltv;
        slippage = _slippage;
    }

    function calculateAmounts(uint depositAmt) private view returns (uint flashLoanAmt, uint minAmt) {
        // compute how much we can flashloan
        // assume assetPrice/liabilityPrice is p from orcacle, but slippage to p*(1+slippage/10000)
        // there are also starting asset and liability A and L and we look for dL and dA.
        // ltv contraint: L+dL = max_ltv * (A+dA)
        // swap new deposit dE and flashLoan dF into dA, worth (dE+dF) / (1+slippage/10000)
        // flashLoan return from loan, so dF = dL
        // solve that...
        uint assetPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(WSTETH);
        uint liabilityPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(WETH);
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE).getUserAccountData(address(this));
        uint availableBorrows =  availableBorrowsBase / liabilityPrice;

        flashLoanAmt = (availableBorrows + depositAmt * max_ltv/(1+slippage/10000)) / (1-max_ltv/(1+slippage/10000));
        minAmt = (depositAmt + flashLoanAmt)/assetPrice/(1+slippage/10000);
    } 

    function deposit(uint256 assets, address receiver) public override returns (uint256 shares) {
        require(assets > 0, "Looping: assets must be greater than 0");
        shares = super.deposit(assets, receiver);
        
        // well,  that assumes we start empty
        (uint flashLoanAmt, uint minAmt) = calculateAmounts(assets);

        // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(WETH);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmt;
        bytes memory userData = abi.encodePacked(flashLoanAmt, minAmt);
        
        IVault(BALANCER_FLASHLOAN).flashLoan(IFlashLoanRecipient(this), tokens, amounts, userData);
    }

    // Implement the IFlashLoanRecipient interface
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        // swap WETH for stETH
        uint256 amountToSwap = IERC20(WETH).balanceOf(address(this));
        {
            bool success = IERC20(WETH).approve(BALANCER_SWAP, amountToSwap);
            require(success, "Looping: failed to approve WETH for ONEINCH");
        }
        
        (uint flashLoanAmt, uint minAmt) = abi.decode(userData, (uint256, uint256));
        {
            IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
                poolId:"0x36bf227d6bac96e2ab1ebb5492ecec69c691943f000200000000000000000316",
                kind:0,
                assetIn:WETH,
                assetOut:WSTETH,
                amount: amountToSwap,
                userData:"0x"});

            IVault.FundManagement memory funds = IVault.FundManagement({
                sender:address(this),
                fromInternalBalance:false,
                recipient:address(this),
                toInternalBalance:false});
            uint limit = minAmt;
            uint deadline = block.timestamp+60; // 1 minute
            uint256 amountCalculated = IVault(BALANCER_SWAP).swap(
                singleSwap,
                funds,
                limit,
                deadline
            );
        }

        // deposit stETH to AAVE
        {
            bool success = IERC20(WSTETH).approve(AAVE, IERC20(WSTETH).balanceOf(address(this)));
            require(success, "Looping: failed to approve stETH for AAVE");
        }
        IPool(AAVE).supply(WSTETH, IERC20(WSTETH).balanceOf(address(this)), address(this), 0);

        // borrow WETH from AAVE
        IPool(AAVE).borrow(WETH, flashLoanAmt, 2, 0, address(this));
    }
}