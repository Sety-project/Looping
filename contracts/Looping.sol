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

// bytes32 constant BALANCER_POOL_ID =
//     bytes32(
//         uint256(
//             0x36bf227d6bac96e2ab1ebb5492ecec69c691943f000200000000000000000316
//         )
//     );

contract Looping is ILooping, OwnableERC4626 {
    using Math for uint256;

    Params private params;
    LoanMetrics private loanMetrics;
    address private immutable quoteaAToken;
    address private immutable baseVariableDebtToken;

    constructor(
        address quote,
        address base,
        uint256 ltv,
        uint256 slippage
    ) OwnableERC4626(quote) {
        params.quote = quote;
        params.base = base;
        params.ltv = ltv;
        params.slippage = slippage; // slippage includes fees
        params.interestRateMode = DataTypes.InterestRateMode.VARIABLE;
        IPool(AAVE).setUserEMode(0);
        quoteaAToken = (IPool(AAVE).getReserveData(base)).aTokenAddress;
        baseVariableDebtToken = (IPool(AAVE).getReserveData(quote)).variableDebtTokenAddress;
    }

    function setExecutionParams(
        uint16 ltv,
        uint16 slippage
    ) external onlyOwner {
        params.ltv = ltv;
        params.slippage = slippage;
    }

    function getParams() external view returns (ILooping.Params memory) {
        return params;
    }

    // make sure to call this before any external call
    function _cacheLoanInfo(bool checkNoCash) private {
        loanMetrics.basePrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(params.base);
        loanMetrics.quotePrice = IAaveOracle(AAVE_ORACLE).getAssetPrice(params.quote);
        loanMetrics.quoteBalance = IERC20(params.quote).balanceOf(address(this));
        loanMetrics.baseBalance = IERC20(params.base).balanceOf(address(this));
        if (checkNoCash) {
            require(
                loanMetrics.quoteBalance == 0 && loanMetrics.baseBalance == 0,
                "contract shouldn't hold cash at this point"
            );
        }
        loanMetrics.totalCollateral = IERC20(quoteaAToken).balanceOf(address(this));
        loanMetrics.totalDebt = IERC20(baseVariableDebtToken).balanceOf(address(this));

        emit PrintHoldings(
            loanMetrics.quoteBalance,
            loanMetrics.baseBalance,
            loanMetrics.totalCollateral,
            loanMetrics.totalDebt
        );
    }

    // this refreshes cache, so is not view
    function printHoldings(string memory text) external {
        _cacheLoanInfo(false);        
        string memory concatenated = string(
            abi.encodePacked(
                "quoteBalance ",
                Strings.toString(loanMetrics.quoteBalance),
                " baseBalance ",
                Strings.toString(loanMetrics.baseBalance),
                " totalCollateral ",
                Strings.toString(loanMetrics.totalCollateral),
                " totalDebt ",
                Strings.toString(loanMetrics.totalDebt)
            )
        );
        console.log("%s: %s", text, concatenated);
    }

    /* tricky and unsafe ! 
    super.totalAssets() was _asset.balanceOf(address(this)) but we do not hold on to quote in this contract:
    what we need is the net valuation
    BUT: we can't force a refresh upon calling it from outside since it overrides a view function...*/
    function totalAssets()
        public
        view
        override(IERC4626, ERC4626)
        returns (uint256)
    {
        assert(IERC20(params.base).balanceOf(address(this)) == 0); // we do not hold on to quote in this contract
        return
            loanMetrics.totalCollateral.mulDiv(
                loanMetrics.basePrice,
                loanMetrics.quotePrice
            )
            - loanMetrics.totalDebt
            + IERC20(params.quote).balanceOf(address(this));
        // + IERC20(params.base).balanceOf(address(this)).mulDiv(loanMetrics.basePrice, loanMetrics.quotePrice);
    }
    // but at least internal calls can force a refresh
    function refreshTotalAssets(bool checkNoCash) public returns (uint256) {
        _cacheLoanInfo(checkNoCash);
        return totalAssets();
    }

    // IREC4626.deposit cannot be used because of slippage -> we can't previewDeposit before _deposit.
    function deposit(
        uint256 assets,
        address receiver
    ) public override(IERC4626, ERC4626) returns (uint256 shares) {
        uint assetsBefore = refreshTotalAssets(true);
        mySafeTransferFrom(params.quote, receiver, address(this), assets);
        
        // well,  that assumes we start empty
        (
            uint flashLoanAmt,
            uint amountToSwap,
            uint minAmountsOut
        ) = LoopingCalculations._depositCalculations(assets, params, loanMetrics);

        // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(params.quote);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmt;
        bytes memory userData = abi.encode(
            Operation.Deposit,
            amountToSwap,
            minAmountsOut,
            type(uint256).min
        );

        IVault(BALANCER_FLASHLOAN).flashLoan(this, tokens, amounts, userData);

        // mint based on assets AFTER costs
        uint assetsAfter = refreshTotalAssets(true);

        shares = previewDeposit(assetsAfter - assetsBefore);
        _mint(receiver, shares);

        emit Deposit(receiver, receiver, assets, shares);
        console.log("Deposit: deposit %d assetDiff %d shares %d", assets, assetsAfter - assetsBefore, shares);
    }

    // IREC4626.withdraw cannot be used because of slippage -> we can't previewDeposit before _deposit.
    function withdraw(
        uint256 shares,
        address receiver,
        address owner
    ) public override(IERC4626, ERC4626) returns (uint256 assets) {
        console.log("assetsBefore ?");
        uint assetsBefore = refreshTotalAssets(true);
        console.log("assetsBefore $d", assetsBefore);
        uint sharesBps = shares.mulDiv(10000, totalSupply());
        (
            uint flashLoanAmt,
            uint amountToSwap,
            uint minAmountsOut
        ) = LoopingCalculations._withdrawCalculations(sharesBps, params, loanMetrics);

        // Flashloan will call receiveFlashLoan(), where the rest of the logic will be executed
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = IERC20(params.quote);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashLoanAmt;
        bytes memory userData = abi.encode(
            Operation.Deposit,
            amountToSwap,
            minAmountsOut
        );
        console.log("flashLoanAmt %d amountToSwap%d minAmountsOut %d", flashLoanAmt, amountToSwap , minAmountsOut);
        IVault(BALANCER_FLASHLOAN).flashLoan(this, tokens, amounts, userData);

        // sharesAfter = this.totalSupply().mulDiv(sharesBps, 10000);
        uint assetsAfter = refreshTotalAssets(true);
        console.log("assetsAfter %d", assetsAfter);
        uint shares = previewWithdraw(assetsAfter - assetsBefore);
        console.log("shares %d", shares);
        _burn(owner, shares);
        assets = assetsAfter - assetsBefore;
        mySafeTransferFrom(params.quote, address(this), receiver, assets);
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
            msg.sender == BALANCER_FLASHLOAN,
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

        // repay the flashloan
        // require(
        //     amounts[0] + feeAmounts[0] <= tokens[0].balanceOf(address(this)),
        //     "Looping: not enough funds to repay flashloan"
        // );
        bool success = tokens[0].transfer(
            msg.sender,
            amounts[0] + feeAmounts[0]
        );
        // this.printHoldings("after repay");
        // require(success, "Looping: failed to repay flashloan");
        // console.log("flashloan repaid");
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
                sqrtPriceLimitX96: uint160(
                    uint(2 << 96).mulDiv(
                        Math.sqrt(amountIn),
                        Math.sqrt(minAmountOut)
                    )
                )
            });
        // Execute the swap and return the amount of output token
        amountOut = uniswapRouter.exactInputSingle(swapParams);
    }

    function _leverage(
        uint flashLoanAmt,
        uint amountToSwap,
        uint minAmountsOut
    ) private {
        // swap params.quote for base
        uint256 amountCalculated = _swapExactInputSingle(
            params.quote,
            params.base,
            uniswap_fee,
            amountToSwap,
            minAmountsOut
        );
        // deposit base into AAVE
        if (IERC20(params.base).allowance(address(this), AAVE) < amountCalculated)
        {
            bool success = IERC20(params.base).approve(AAVE, amountCalculated);
            // require(success, "Looping: failed to approve stETH for AAVE");
        }
        // this.printHoldings("before supply");
        IPool(AAVE).supply(params.base, amountCalculated, address(this), 0);
        // DataTypes.ReserveData memory reserveData = IPool(AAVE).getReserveData(address(this));
        // this.printHoldings("after supply");
        // borrow asset from AAVE to repay flashloan
        IPool(AAVE).borrow(
            params.quote,
            flashLoanAmt,
            uint256(params.interestRateMode),
            0,
            address(this)
        );
        // this.printHoldings("after borrow");
    }

    function _deleverage(
        uint flashLoanAmt,
        uint amountToSwap,
        uint minAmountsOut
    ) private {
        // repay params.quote from AAVE
        uint amountToRepay = flashLoanAmt;
        if (IERC20(params.quote).allowance(address(this),AAVE) < amountToRepay) {
            bool success = IERC20(params.quote).approve(AAVE, amountToRepay);
            // require(success, "Looping: failed to approve stETH for AAVE");
        }
        IPool(AAVE).repay(
            params.quote,
            amountToRepay,
            uint256(params.interestRateMode),
            address(this)
        );
        
        // withdraw base from AAVE
        uint unsupplyAmt = amountToSwap;
        IPool(AAVE).withdraw(params.base, unsupplyAmt, address(this));

        // swap base for params.quote
        _swapExactInputSingle(
            params.base,
            params.quote,
            uniswap_fee,
            amountToSwap,
            minAmountsOut
        );
    }

    // not 100% sure about those....
    function mint(uint256 shares, address receiver) public override(IERC4626, ERC4626) returns (uint256) {
        uint256 assets = refreshTotalAssets(true).mulDiv(shares, super.totalSupply());
        return deposit(assets, receiver);
    }
    function redeem(uint256 shares, address receiver, address owner) public override(IERC4626, ERC4626) returns (uint256) {
        uint256 assets = refreshTotalAssets(true).mulDiv(shares, super.totalSupply());
        return withdraw(assets, receiver, owner);
    }
}
