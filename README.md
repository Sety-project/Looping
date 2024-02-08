# Looping

This is a mulitasset ERC4626 supporting lend and borrow. A leverage strat is executed / unwound upon deposit / withdraw. This is WIP and still exploitable, coverage about 50%, and ERC4626 compatibility is only partially satisfied...

## deposit

Assume existing debt and collateral of ETH value `L` and `A`.
Denote `px = pxB / pxQ` the price of base/quote in USD using IAAVEOracle.getPrice. Quote is WETH.

Upon Deposit `assets` quote asset (WETH):
- flashloan `flashLoanAmt`
- swap `amountToSwap = assets + flashLoanAmt` to base; swap returns `amountCalculated` base asset (WstETH)
- `amountCalculated > minAmountsOuts = (assets + flashLoanAmt) / px / ( 1 + slippage )`.
- lend `amountCalculated` and borrow `ltv * minAmountsOuts * px` (note: borrow a little less than lent so health increases a bit and dust accrues in aBase)
- refund `flashLoanAmt`
- do not call super.deposit, but _mint the right amount based on refreshed LoanInfo.
We need: `flashLoanAmt = ltv * minAmountsOuts * px = alpha * (assets + flashLoanAmt)`
So: `flashLoanAmt = assets * alpha / 1-alpha`, where `alpha =  ltv / ( 1 + slippage )`

### balances trajectory (0 slippage):
step        quote                   base                   dQuote               aBase
deposit     `assets`                0                       0                   0
flashLoan   `amountToSwap`
swap        0                       `minAmountsOut`      0                   0
lend        0                       0                       0                   `minAmountsOut`
borrow      `flashLoanAmt`          0                       `flashLoanAmt`      `minAmountsOut`
replayFlash 0                       0                       `flashLoanAmt`      `minAmountsOut`

## withdraw

Upon withdraw `shareBps` of the vault, we want to achieve: new totalCollateral  = totalCollateral * (1-shareBps/10000).
- flashloan quote `flashLoanAmt`
- repay quote `amountToRepay = flashLoanAmt`
- un-supply base `withdrawAmt = totalCollateral * shareBps / 10000`. For this to be allowed we need `new debt = max_ltv * new collateral`, which solves to `flashLoanAmt = max(0, totalDebt - max_ltv * (totalCollateral-withdrawAmt))`. Please note this is `max_ltv` allowed by the vault, more efficient than `ltv` used.
- swap `amountToSwap = withdrawAmt` to quote; swap returns `amountCalculated` base asset (WETH).
- `amountCalculated > minAmountsOuts = withdrawAmt * px / ( 1 + slippage )`.
- repay flashloan
- refresh loanInfo and return quote balance.
- do not call super.deposit, but _burn the right amount based on refreshed LoanInfo.

### balances trajectory (for sharesBps = 10000, 0 slippage). amountToSwap = totalCollateral * shareBps:
step        quote                   base                   dQuote               aBase
start       0                       0                       0                   0
flashLoan   `flashLoanAmt`          0                       0                   0
repay       0                       0                       `-flashLoanAmt`     0
un-supply   0                       `amountToSwap`          0                   `-amountToSwap`
swap        `minAmountsOuts`        0                       0                   0
replayFlash `minAmountsOuts-flashLoanAmt`0                       0                   0
