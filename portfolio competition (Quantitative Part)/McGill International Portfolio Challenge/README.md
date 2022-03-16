### This file includes competition docement and modeling work of our team- Venus Capital.
#### Our team is honored to be selected in top 25 in the globe for our brilliant asset allocation decision and pension fund strategy.



#### The portfolio model includes following features:

1. Adjustable Mean Variance Portfolio Model => Calculate Max sharp ratio, Max return, or Min Volatility, allocate weight/ 
	-  If no weight restriction on each asset, certain assets may weight to zero
	-  Give each assets' category weights (ex: Stocks 70%, Bonds 20%, REITS 10%)
	-  Give each asset minimum bar (ex: AAPL 1%)
	-  Combine 2 and 3

2. The Adjusted Top-Down portfolio model includes all possible combinatons for given range in each asset.(Ex: AAPL 3% ~ 5%)


3. Output :
	- Weight vector for the portfolio
	- Annual Return
	- Annual Volatility
	- Sharpe Ratio
	- Maximum drawdown

Future work:
	- Draw mean variance efficient frontier figure for better visualization
	- Try multiple asset allocation methods



#### The pension simulation model-cash flow includes following features:

1. Simulate pension fund cash flow movement by giving following variables:
	- Number of people join in each year
	- Each starting Salary when join the pension fund
	- Dynamic reserve contribution rate for different years
	
Future work:
	- Try add multiple joining years formula
