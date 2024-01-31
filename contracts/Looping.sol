pragma solidity ^0.8.20;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {OwnableERC4626} from "./OwnableERC4626.sol";
import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
// import {AaveOracle} from "@aave/core-v3/contracts/misc/AaveOracle.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
// import "lib/forge-std/src/console.sol";
import "hardhat/console.sol";

contract Looping is OwnableERC4626 , IFlashLoanRecipient {
    using Math for uint256;

    address private constant BALANCER_FLASHLOAN = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    address private constant AAVE = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
    address private constant AAVE_ORACLE = address(0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7);
    address private constant BALANCER_SWAP = address(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    bytes32 private constant BALANCER_POOL_ID = bytes32(uint256(0x36bf227d6bac96e2ab1ebb5492ecec69c691943f000200000000000000000316));
    
    address private immutable _base;
    uint256 private _max_ltv; // in bps
    uint256 private _slippage; // in bps
    DataTypes.InterestRateMode private immutable _interestRateMode;

    enum Operation {Deposit, Withdraw}

    constructor(address quote, address base, uint256 max_ltv, uint256 slippage)
    OwnableERC4626(quote) payable
    {
        _base = base;
        _max_ltv = max_ltv;
        _slippage = slippage;
        _interestRateMode = DataTypes.InterestRateMode.VARIABLE;
    }
    
    function setExecutionParams(uint16 max_ltv, uint16 slippage) external onlyOwner {
        IPool(AAVE).setUserEMode(2);
        _max_ltv = max_ltv;
        _slippage = slippage;
    }

    function depositCalculations(uint depositAmt) private view returns (uint flashLoanAmt, uint minAmountsOut) {
        // compute how much we can flashloan
        // assume assetPrice/liabilityPrice is p from orcacle, but slippage to p*(1+slippage/10000)
        // there are also starting asset and liability A and L and we look for dL and dA.
        // ltv contraint: L+dL = max_ltv * (A+dA)
        // swap new deposit dE and flashLoan dF into dA, worth (dE+dF) / (1+slippage/10000)
        // flashLoan return from loan, so dF = dL
        // solve that...
        uint assetPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(_base);
        uint liabilityPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(this.asset());
        (, , uint256 availableBorrowsBase, , , ) = IPool(AAVE).getUserAccountData(address(this));
        uint availableBorrows =  availableBorrowsBase / liabilityPrice;

        flashLoanAmt = (availableBorrows + depositAmt.mulDiv(_max_ltv,(1+_slippage/10000))) / (1-_max_ltv/(1+_slippage/10000));
        minAmountsOut = (depositAmt + flashLoanAmt).mulDiv(liabilityPrice, assetPrice*(1+_slippage/10000));
    } 

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        super._deposit(caller, receiver, assets, shares);
        
        // well,  that assumes we start empty
        (uint flashLoanAmt, uint minAmountsOut) = depositCalculations(assets);

        // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(this.asset());
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmt;
        bytes memory userData = abi.encodePacked(Operation.Deposit, minAmountsOut, type(uint256).min);
        
        IVault(BALANCER_FLASHLOAN).flashLoan(IFlashLoanRecipient(this), tokens, amounts, userData);
    }

    function withdrawCalculations(uint sharesAmt) private view returns (uint flashLoanAmt, uint minAmountsOut, uint withdrawAmt) {
        /* for withdraw:
        - just scale the debt by the ratio of shares then repay that "flashLoanAmt"
        - can now withdraw flashLoanAmt/max_ltv worth of base asset
        - swap this into flashLoanAmt/max_ltv*liabilityPrice/assetPrice asset
        - apply slippage to that => flashLoanAmt*liabilityPrice/(max_ltv*assetPrice asset*(1+slippage/10000))
        */
        uint assetPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(_base);
        uint liabilityPrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(this.asset());
        (uint256 totalCollateralBase, uint256 totalDebtBase, , , , ) = IPool(AAVE).getUserAccountData(address(this));
        
        flashLoanAmt = totalDebtBase.mulDiv(sharesAmt, totalSupply());
        minAmountsOut = flashLoanAmt.mulDiv(liabilityPrice, _max_ltv*assetPrice*(1+_slippage/10000));
    }

    function _withdraw(
        address caller,
        address receiver,
        address owner,
        uint256 assets,
        uint256 shares
    ) internal override {
        (uint flashLoanAmt, uint minAmountsOut, uint withdrawAmt) = withdrawCalculations(shares);

        // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(_base);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmt;
        bytes memory userData = abi.encodePacked(Operation.Withdraw, minAmountsOut, withdrawAmt);
        
        IVault(BALANCER_FLASHLOAN).flashLoan(IFlashLoanRecipient(this), tokens, amounts, userData);

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    // Implement the IFlashLoanRecipient interface
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        (Operation operation, uint minAmountsOut, uint withdrawAmt) = abi.decode(userData, (Operation, uint256, uint256));

        if (operation == Operation.Deposit) {
            _leverage(amounts[0], minAmountsOut);
        } else if (operation == Operation.Withdraw) {
            _deleverage(amounts[0], withdrawAmt, minAmountsOut);
        } else {
            revert("Looping: unknown operation");
        }
    }

    function _leverage(uint flashLoanAmt, uint minAmountsOut) private {
        // swap this.asset() for base
        uint256 amountToSwap = IERC20(this.asset()).balanceOf(address(this));
        if (IERC20(this.asset()).allowance(address(this), BALANCER_SWAP) < amountToSwap)
        {
            bool success = IERC20(this.asset()).approve(BALANCER_SWAP, amountToSwap);
            require(success, "Looping: failed to approve this.asset() for ONEINCH");
        }
        
        {
            IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
                poolId: BALANCER_POOL_ID,
                kind: IVault.SwapKind.GIVEN_IN,
                assetIn: IAsset(this.asset()),
                assetOut: IAsset(_base),
                amount: amountToSwap,
                userData: "0x"
            });

            IVault.FundManagement memory funds = IVault.FundManagement({
                sender:address(this),
                fromInternalBalance:false,
                recipient:payable(address(this)),
                toInternalBalance:false});
            uint limit = minAmountsOut;
            uint deadline = block.timestamp+60; // 1 minute
            uint256 amountCalculated = IVault(BALANCER_SWAP).swap(
                singleSwap,
                funds,
                limit,
                deadline
            );
        }

        // deposit base to AAVE
        {
            bool success = IERC20(_base).approve(AAVE, IERC20(_base).balanceOf(address(this)));
            require(success, "Looping: failed to approve stETH for AAVE");
        }
        IPool(AAVE).supply(_base, IERC20(_base).balanceOf(address(this)), address(this), 0);

        // borrow asset from AAVE to repay flashloan
        IPool(AAVE).borrow(this.asset(), flashLoanAmt, uint256(_interestRateMode), 0, address(this));
    }

    function _deleverage(uint flashLoanAmt, uint lendAmt, uint minAmountsOut) private {
        // repay this.asset() from AAVE
        IPool(AAVE).repay(this.asset(), flashLoanAmt, uint256(_interestRateMode), address(this));

        // withdraw base from AAVE
        IPool(AAVE).withdraw(_base, lendAmt, address(this));
        
        // swap base for this.asset()
        uint256 amountToSwap = IERC20(_base).balanceOf(address(this));
        if (IERC20(_base).allowance(address(this), BALANCER_SWAP) < amountToSwap)
        {
            bool success = IERC20(_base).approve(BALANCER_SWAP, amountToSwap);
            require(success, "Looping: failed to approve _base for ONEINCH");
        }
        
        {
            IVault.SingleSwap memory singleSwap = IVault.SingleSwap({
                poolId: BALANCER_POOL_ID,
                kind: IVault.SwapKind.GIVEN_IN,
                assetOut: IAsset(this.asset()),
                assetIn: IAsset(_base),
                amount: amountToSwap,
                userData: "0x"
            });

            IVault.FundManagement memory funds = IVault.FundManagement({
                sender:address(this),
                fromInternalBalance:false,
                recipient:payable(address(this)),
                toInternalBalance:false});
            uint limit = minAmountsOut;
            uint deadline = block.timestamp+60; // 1 minute
            uint256 amountCalculated = IVault(BALANCER_SWAP).swap(
                singleSwap,
                funds,
                limit,
                deadline
            );
        }
    }
}