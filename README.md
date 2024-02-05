# Looping

1) deposit

Assume existing debt and collateral of ETH value `L` and `A`.
Denote `px = pxB / pxQ` the price of base/quote in USD using IAAVEOracle.getPrice. Quote is WETH.

Upon Deposit `assets` quote asset (WETH):
- super.deposit(assets)
- flashloan `flashLoanAmt`
- swap `amountToSwap = assets + flashLoanAmt` to base; swap returns `amountCalculated` base asset (WstETH)
- `amountCalculated > minAmountsOuts = (assets + flashLoanAmt) / px / ( 1 + slippage )`.
- lend `amountCalculated` and borrow `ltv * minAmountsOuts * px` (note: borrow a little less than lent so health increases a bit and dust accrues in aBase)
- refund `flashLoanAmt`
We need: `flashLoanAmt = ltv * minAmountsOuts * px = alpha * (assets + flashLoanAmt)`
So: `flashLoanAmt = assets * alpha / 1-alpha`, where `alpha =  ltv / ( 1 + slippage )`

Upon withdraw `shareBps` of the vault, we want to achieve: new totalCollateral  = totalCollateral * (1-shareBps/10000).
- flashloan quote `flashLoanAmt`
- repay quote `amountToRepay = flashLoanAmt`
TODOOOOOOOOOOOOO!!!!!!!
- un-supply base `withdrawAmt = totalCollateral / pxB * shareBps / 10000`. For this to be allowed we need `amountToRepay = max_ltv * withdrawAmt * px`. Please note this is `max_ltv` allowed by the vault, more efficient than `ltv` used. 
- swap `amountToSwap = withdrawAmt` to quote; swap returns `amountCalculated` base asset (WETH).
- `amountCalculated > minAmountsOuts = withdrawAmt * px / ( 1 + slippage )`.
- return `amountCalculated - amountToRepay` if positive (vault can get stuck from slippage cost if ltv is close to ltv).
