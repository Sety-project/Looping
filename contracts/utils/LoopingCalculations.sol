pragma solidity ^0.8.0;
import "hardhat/console.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ILooping} from "../interface/ILooping.sol";

library LoopingCalculations {
    using Math for uint256;

    function _depositCalculations(
        uint depositAmt, ILooping.Params memory params, ILooping.LoanMetrics memory loanMetrics
    )
        internal
        pure
        returns (uint flashLoanAmt, uint amountToSwap, uint minAmountsOut)
    {
        // compute how much we can flashloan
        // assume assetPrice/liabilityPrice is p from orcacle, but slippage to p*(1+slippage/10000)
        // there are also starting asset and liability A and L and we look for dL and dA.
        // ltv contraint: L+dL = ltv * (A+dA)
        // swap new deposit dE and flashLoan dF into dA, worth (dE+dF) / (1+slippage/10000)
        // flashLoan return from loan, so dF = dL
        // solve that...
        // console.log("depositAmt %d params.base %s asset %s", depositAmt, params.base, params.quote);
        // console.log("ltv %d params.slippage %d", params.ltv, params.slippage);
        // console.log("AAVE %s AAVE_ORACLE %s", AAVE, AAVE_ORACLE);

        uint big = 2 ** 96;
        flashLoanAmt = depositAmt.mulDiv(
            //availableBorrows + // should borrow the max, but need conversino etc...
            big.mulDiv(params.ltv, (10000 + params.slippage)),
            big - big.mulDiv(params.ltv, (10000 + params.slippage))
        );
        amountToSwap = depositAmt + flashLoanAmt;
        minAmountsOut = amountToSwap.mulDiv(
            loanMetrics.quotePrice * 10000,
            loanMetrics.basePrice * (10000 + params.slippage)
        );
        console.log(
            "_depositCalculations: flashLoanAmt %d amountToSwap %d minAmountsOut %d",
            flashLoanAmt,
            amountToSwap,
            minAmountsOut
        );
    }

    function _withdrawCalculations(
        uint sharesBps, ILooping.Params memory params, ILooping.LoanMetrics memory loanMetrics
    )
        internal
        pure
        returns (
            uint flashLoanAmt,
            uint amountToSwap,
            uint minAmountsOut
        )
    {
        /* for withdraw:
        - just scale the debt by the ratio of shares then repay that "flashLoanAmt"
        - can now withdraw flashLoanAmt/ltv worth of base asset
        - swap this into flashLoanAmt/ltv*liabilityPrice/assetPrice asset
        - apply slippage to that => flashLoanAmt*liabilityPrice/(ltv*assetPrice asset*(1+slippage/10000))
        */
        uint unsupplyAmt = loanMetrics.totalCollateral.mulDiv(sharesBps, 10000);
        amountToSwap = unsupplyAmt;
        minAmountsOut = amountToSwap.mulDiv(
            loanMetrics.basePrice * 10000,
            loanMetrics.quotePrice * (10000 + params.slippage)
        );

        uint amountToRepay =
            loanMetrics.totalDebt -
            loanMetrics.totalCollateral.mulDiv(
                loanMetrics.basePrice * (10000 - sharesBps),
                loanMetrics.quotePrice * 10000
            );
        flashLoanAmt = amountToRepay;
        
        console.log(
            "flashLoanAmt %d unsupplyAmt %d amountToSwap %d amountToRepay %d",
            flashLoanAmt,
            unsupplyAmt,
            amountToSwap
        );
    }

}
