// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import {ILooping} from "./interface/ILooping.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {OwnableERC4626} from "./OwnableERC4626.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";

import {IVault} from "@balancer-labs/v2-interfaces/contracts/vault/IVault.sol";
import {IAsset} from "@balancer-labs/v2-interfaces/contracts/vault/IAsset.sol";
import {IAaveOracle} from "@aave/core-v3/contracts/interfaces/IAaveOracle.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {LoopingCalculations} from "./utils/LoopingCalculations.sol";

import "hardhat/console.sol";

address constant BALANCER_FLASHLOAN = address(
    0xBA12222222228d8Ba445958a75a0704d566BF2C8
);
address constant AAVE = address(0x794a61358D6845594F94dc1DB02A252b5b4814aD);
address constant AAVE_ORACLE = address(
    0xb56c2F0B653B2e0b10C9b928C8580Ac5Df02C7C7
);
uint24 constant uniswap_fee = 100; // 1bp
address constant UNISWAP_SWAP = address(
    0xE592427A0AEce92De3Edee1F18E0157C05861564
);
ISwapRouter constant uniswapRouter = ISwapRouter(UNISWAP_SWAP);

contract Looping is ILooping, OwnableERC4626 {
    using Math for uint256;

    Params private _params;
    address private immutable _quoteaAToken;
    address private immutable _baseVariableDebtToken;

    constructor(
        address quote,
        address base,
        uint256 ltv,
        uint256 slippage
    ) OwnableERC4626(quote) {
        _params.quote = quote;
        _params.base = base;
        _params.ltv = ltv;
        _params.slippage = slippage; // slippage includes fees
        _params.interestRateMode = DataTypes.InterestRateMode.VARIABLE;
        IPool(AAVE).setUserEMode(0);
        _quoteaAToken = (IPool(AAVE).getReserveData(base)).aTokenAddress;
        _baseVariableDebtToken = (IPool(AAVE).getReserveData(quote)).variableDebtTokenAddress;
    }

    function setExecutionParams(
        uint16 ltv,
        uint16 slippage
    ) external onlyOwner {
        _params.ltv = ltv;
        _params.slippage = slippage;
    }

    function getParams() external view returns (ILooping.Params memory) {
        return _params;
    }
    
    /* tricky ! 
    super.totalAssets() was _asset.balanceOf(address(this)) but we do not hold on to quote in this contract:
    what we need is the net valuation*/
    function _calculateTotalAssets(LoanMetrics memory loanMetrics) internal view returns (uint256) {
        assert(IERC20(_params.base).balanceOf(address(this)) == 0); // we do not hold on to quote in this contract
        return
            loanMetrics.totalCollateral.mulDiv(
                loanMetrics.basePrice,
                loanMetrics.quotePrice
            )
            - loanMetrics.totalDebt
            + IERC20(_params.quote).balanceOf(address(this))
            + IERC20(_params.base).balanceOf(address(this)).mulDiv(loanMetrics.basePrice, loanMetrics.quotePrice);
    }
    function _calculateLoanMetrics() private view returns (LoanMetrics memory loanMetrics){
        loanMetrics.basePrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(_params.base);
        loanMetrics.quotePrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(_params.quote);
        loanMetrics.quoteBalance = IERC20(_params.quote).balanceOf(address(this));
        loanMetrics.baseBalance = IERC20(_params.base).balanceOf(address(this));
        loanMetrics.totalCollateral = IERC20(_quoteaAToken).balanceOf(address(this));
        loanMetrics.totalDebt = IERC20(_baseVariableDebtToken).balanceOf(address(this));
    }

    // IREC4626.deposit cannot be used because of slippage -> we can't previewDeposit before _deposit.
    function deposit(
        uint256 assets,
        address receiver
    ) public override(IERC4626, ERC4626) returns (uint256 shares) {
        LoanMetrics memory loanMetricsBefore = _calculateLoanMetrics();
        uint assetsBefore = _calculateTotalAssets(loanMetricsBefore);
        mySafeTransferFrom(_params.quote, receiver, address(this), assets);
        
        {
            (
                uint flashLoanAmt,
                uint amountToSwap,
                uint minAmountsOut
            ) = LoopingCalculations._depositCalculations(assets, _params, loanMetricsBefore);

            // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
            IERC20[] memory tokens = new IERC20[](1);
            tokens[0] = IERC20(_params.quote);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = flashLoanAmt;
            bytes memory userData = abi.encode(
                Operation.Deposit,
                amountToSwap,
                minAmountsOut,
                type(uint256).min
            );

            IVault(BALANCER_FLASHLOAN).flashLoan(this, tokens, amounts, userData);
        }

        // mint based on assets AFTER costs; cannot use previewDeposit because of slippage
        LoanMetrics memory loanMetrics = _calculateLoanMetrics();
        uint assetsAfter = _calculateTotalAssets(loanMetrics);
        shares = (assetsAfter - assetsBefore).mulDiv(totalSupply() + 10 ** _decimalsOffset(), assetsBefore + 1, Math.Rounding.Floor);
        
        _mint(receiver, shares);

        emit Deposit(_msgSender(), receiver, assets, shares);
    }

    // IREC4626.withdraw cannot be used because of slippage -> we can't previewDeposit before _deposit.
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override(IERC4626, ERC4626) returns (uint256 assets) {     
        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }
        // apply logic
        {
            LoanMetrics memory loanMetricsBefore = _calculateLoanMetrics();
            uint sharesBps = shares.mulDiv(10000, totalSupply());
            (
                uint flashLoanAmt,
                uint amountToSwap,
                uint minAmountsOut
            ) = LoopingCalculations._withdrawCalculations(sharesBps, _params, loanMetricsBefore);

            // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
            IERC20[] memory tokens = new IERC20[](1);
            tokens[0] = IERC20(_params.quote);
            uint256[] memory amounts = new uint256[](1);
            amounts[0] = flashLoanAmt;
            bytes memory userData = abi.encode(
                Operation.Withdraw,
                amountToSwap,
                minAmountsOut
            );
            IVault(BALANCER_FLASHLOAN).flashLoan(this, tokens, amounts, userData);
        }

        // burns shares and transfers quote
        assets = IERC20(_params.quote).balanceOf(address(this));
        _withdraw(_msgSender(), receiver, owner, assets, shares);
    }

    /* Implement the IFlashLoanRecipient interface
    when BALANCER_FLASHLOAN.flashloan is called, it will callback receiveFlashLoan.
    This is what will call the swap and the borrow.
    No need to repay explicitly, it will be done automatically by the flashloan contract.
    */
    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external {
        require(
            _msgSender() == BALANCER_FLASHLOAN,
            "Looping: only Balancer can call this function"
        );
        (
            Operation operation,
            uint amountToSwap,
            uint minAmountsOut
        ) = abi.decode(userData, (Operation, uint256, uint256));
        if (operation == Operation.Deposit) {
            _leverage(amounts[0], amountToSwap, minAmountsOut);
        }
        else {
            _deleverage(amounts[0], amountToSwap, minAmountsOut);
        }

        // repay flashloan
        bool success = tokens[0].transfer(
            _msgSender(),
            amounts[0] + feeAmounts[0]
        );
    }

    function _swapExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 poolFee,
        uint256 amountIn,
        uint256 minAmountOut
    ) private returns (uint256 amountOut) {
        // Approve the router to spend the input token
        if (IERC20(tokenIn).allowance(address(this), UNISWAP_SWAP) < amountIn) {
            bool success = IERC20(tokenIn).approve(UNISWAP_SWAP, amountIn + 1);
            require(success, "Looping: failed to approve tokenIn");
        }

        // Set the swap parameters
        ISwapRouter.ExactInputSingleParams memory swapParams = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: poolFee,
                recipient: address(this), // send the output to the caller
                deadline: block.timestamp + 6000, // use current block timestamp as deadline
                amountIn: amountIn,
                amountOutMinimum: minAmountOut, // accept any amount of output token
                sqrtPriceLimitX96: 0 //uint160(
                //     uint(2 << 96).mulDiv(
                //         Math.sqrt(amountIn),
                //         Math.sqrt(minAmountOut)
                //     )
                // )
            });
        // Execute the swap and return the amount of output token
        amountOut = uniswapRouter.exactInputSingle(swapParams);
    }

    function _leverage(
        uint flashLoanAmt,
        uint amountToSwap,
        uint minAmountsOut
    ) private {
        // swap _params.quote for base
        uint256 amountCalculated = _swapExactInputSingle(
            _params.quote,
            _params.base,
            uniswap_fee,
            amountToSwap,
            minAmountsOut
        );
        // deposit base into AAVE
        if (IERC20(_params.base).allowance(address(this), AAVE) < amountCalculated)
        {
            bool success = IERC20(_params.base).approve(AAVE, amountCalculated);
            require(success, "Looping: failed to approve stETH for AAVE");
        }
        IPool(AAVE).supply(_params.base, amountCalculated, address(this), 0);

        IPool(AAVE).borrow(
            _params.quote,
            flashLoanAmt,
            uint256(_params.interestRateMode),
            0,
            address(this)
        );
    }

    function _deleverage(
        uint flashLoanAmt,
        uint amountToSwap,
        uint minAmountsOut
    ) private {
        // repay _params.quote from AAVE
        uint amountToRepay = flashLoanAmt;
        if (IERC20(_params.quote).allowance(address(this),AAVE) < amountToRepay) {
            bool success = IERC20(_params.quote).approve(AAVE, amountToRepay);
            require(success, "Looping: failed to approve WETH for AAVE");
        }
        IPool(AAVE).repay(
            _params.quote,
            amountToRepay,
            uint256(_params.interestRateMode),
            address(this)
        );
        
        // withdraw base from AAVE
        uint unsupplyAmt = amountToSwap;
        IPool(AAVE).withdraw(_params.base, unsupplyAmt, address(this));

        // swap base for _params.quote
        _swapExactInputSingle(
            _params.base,
            _params.quote,
            uniswap_fee,
            amountToSwap,
            minAmountsOut
        );
    }

    // don't use those for now because preview painful to implement
    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256) {
        revert FunctionNotImplemented("mint");
    }
    function withdraw(uint256 assets, address receiver, address owner) public override(IERC4626, ERC4626) returns (uint256) {
        revert FunctionNotImplemented("withdraw");
    }
    // blocking this will block all the other functions we don't want to implement
    function totalAssets() public view override(IERC4626, ERC4626) returns (uint256) {
        revert FunctionNotImplemented("totalAssets");
    }
}
