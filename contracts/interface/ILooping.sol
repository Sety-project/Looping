// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@balancer-labs/v2-interfaces/contracts/solidity-utils/openzeppelin/IERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {DataTypes} from "@aave/core-v3/contracts/protocol/libraries/types/DataTypes.sol";
import {IFlashLoanRecipient} from "@balancer-labs/v2-interfaces/contracts/vault/IFlashLoanRecipient.sol";

interface ILooping is IERC4626, IFlashLoanRecipient {
    function setExecutionParams(uint16 ltv, uint16 slippage) external;

    struct Params {
        address quote;
        address base;
        uint ltv;
        uint slippage;
        DataTypes.InterestRateMode interestRateMode;
    }
    struct LoanMetrics {
        uint quoteBalance;
        uint baseBalance;
        uint basePrice;
        uint quotePrice;
        uint totalCollateral;
        uint totalDebt;
        uint availableBorrowsBase;
    }
    enum Operation {
        Deposit,
        Withdraw
    }

    error FunctionNotImplemented(string text);

    function getParams() external view returns (ILooping.Params memory);

    function receiveFlashLoan(
        IERC20[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
}
