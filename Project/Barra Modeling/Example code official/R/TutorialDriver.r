## Tutorial drive script
#   processes command line arguments, runs all the tutorials
#
#   command line arguments: (refer to runtutorial.bat/sh)
#   Example:
#   >>TutorialDriver -d 2a 5c -c
#
# check if R6 is installed
if(!is.element('R6', installed.packages()[,1])){
	# prepare to install R6_2.2.1 that comes with the package
	if(.Platform$OS.type=='windows'){
		pkgSource = './R6_2.2.1.zip'
	} else if(.Platform$OS.type=='unix'){
		pkgSource = './R6_2.2.1.tar.gz'
	} else {
		cat('unknow OS\n')
		q()
	}
	pkgTarget = '.'
	r6Out = tryCatch(
		# Successful loading of R6, if R6_2.2.1 in the package is already installed before this run
		{library(R6, lib.loc=pkgTarget)},
		# Unsuccessful loading of R6 - first run of the tutorials
		error = function(err){
			message(err)
			message('\nInstalling R6...')
			withCallingHandlers(
				# install R6_2.2.1 (from the package) for the first time 			
				install.packages(pkgSource, lib=pkgTarget, repos=NULL),
				error = function(e) {
					message(e)
					message('\nR6 lib is needed to run R tutorials')
					message('Please refer to https://cran.r-project.org/web/packages/R6/index.html')
					q()
				}	
			)
			# loading of the installed R6
			library(R6, lib.loc=pkgTarget)
		},
		finally = {}		
	)
}else
	library(R6)

#import BARRAOPT
dyn.load(Sys.getenv("BARRAOPT_WRAP"))
source(Sys.getenv("BARRAOPT_WRAP_R"))

#import TutorialApp, TutorialData, TutorialBase
source("TutorialData.r")
source("TutorialBase.r")
source("TutorialApp.r")

## Read in simulation data
oData = TutorialData$new()	
    
## Construct an application object
app = TutorialApp$new(oData)
    
# parse command line arguments 
app$ParseCommandLine(commandArgs(trailingOnly=TRUE))

## Run tutorials
out = tryCatch({

    app$Tutorial_1a()	    # Minimize Total Risk
    app$Tutorial_1b()	    # Maximize Return and Minimize Total Risk
    app$Tutorial_1c()	    # Minimize Active Risk
    app$Tutorial_1d()	    # Roundlotting
    app$Tutorial_1e()	    # Post Optimization Roundlotting
    app$Tutorial_1f()	    # Additional Statistics for Initial/Optimal Portfolio
    app$Tutorial_1g()	    # Optimization Problem/Output Portfolio Type

	app$Tutorial_2a()	    # Composite Asset
    app$Tutorial_2b()	    # Futures Contracts
    app$Tutorial_2c()	    # Cash contribution
	
    app$Tutorial_3a()	    # Asset Range Constraints/Penalty
    app$Tutorial_3a2()	    # Relative Asset Range Constraints/Penalty
    app$Tutorial_3b()	    # Factor Range Constraints	
    app$Tutorial_3c()	    # Beta Constraint
    app$Tutorial_3c2()	    # Multiple Beta Constraints	
	app$Tutorial_3d()	    # User Attribute Constraints
    app$Tutorial_3e()	    # Relative Constraints	
    app$Tutorial_3f()	    # Transaction Type
    app$Tutorial_3g()	    # Crossover Option	
    app$Tutorial_3h()	    # Total Active Weight Constraint
    app$Tutorial_3i()	    # Dollar Neutral Strategy
    app$Tutorial_3j()       # Asset Free Range Linear Penalty
	
    app$Tutorial_4a()	    # Max # of assets and estimated utility upper bound
    app$Tutorial_4b()	    # Min Holding Level and Transaction Size	
	app$Tutorial_4c()	    # Soft Turnover Constraint
    app$Tutorial_4d()	    # Buy Side Turnover Constraint	
    app$Tutorial_4e()	    # Max # of assets by group
    app$Tutorial_4f()	    # Net turnover limit by group   
    app$Tutorial_4g()	    # Paring penalty	
	
	app$Tutorial_5a()	    # Piecewise Linear Transaction Costs
    app$Tutorial_5b()	    # Nonlinear Transaction Costs
    app$Tutorial_5c()	    # Transaction Cost Constraint
    app$Tutorial_5d()	    # Fixed Transaction Costs	
	app$Tutorial_5e()	    # Asset-level Data incl. Fixed Transaction Costs - Loaded from CSV file
    app$Tutorial_5f()	    # Fixed Holding Costs	
    app$Tutorial_5g()	    # General Piecewise Linear Constraint
	
	app$Tutorial_6a()	    # Penalty

    app$Tutorial_7a()	    # Risk Budgeting
    app$Tutorial_7b()	    # Risk Budgeting - Dual Benchmark	
	app$Tutorial_7c()	    # Risk Budgeting - Additive Definition	
    app$Tutorial_7d()       # Risk Budgeting - By Asset
	
    app$Tutorial_8a()	    # Long-Short Hedge Optimization 
    app$Tutorial_8b()	    # Short Costs as Single Attribute
	app$Tutorial_8c()       # Weighted Total Leverage Constraint
    app$Tutorial_8d()	    # Turnover-by-side Constraint

    app$Tutorial_9a()	    # Risk Target
    app$Tutorial_9b()	    # Return Target	
	
    app$Tutorial_10a()	    # Tax-aware Optimization (using pre-v8.8 legacy APIs)
    app$Tutorial_10b()	    # Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
    app$Tutorial_10c()      # Tax-aware Optimization (using new APIs introduced in v8.8)
    app$Tutorial_10d()      # Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
    app$Tutorial_10e()      # Tax-aware Optimization with loss benefit
    app$Tutorial_10f()      # Total Loss/Gain Constraint
    app$Tutorial_10g()      # Wash Sales

    app$Tutorial_11a()      # Efficient Frontier
    app$Tutorial_11b()	    # Factor Constraint Frontier
    app$Tutorial_11c()	    # General Linear Constraint Frontier
    app$Tutorial_11d()	    # Utility-Leaverage Frontier
	
    app$Tutorial_12a()	    # Constraint Hierarchy

    app$Tutorial_14a()	    # Shortfall beta constraint	
	
    app$Tutorial_15a()	    # Minimize risk from 2 risk models 
    app$Tutorial_15b()	    # Constrain risk from secondary risk model
    app$Tutorial_15c()      # Risk Parity Constraint
	
    app$Tutorial_16a()      # Additional Covariance term - WXFX'W
    app$Tutorial_16b()	    # Additional Covariance term - XWFWX'	
	
    app$Tutorial_17a()	    # Five-Ten-Forty Rule

    app$Tutorial_18()       # Factor exposure block
	
    app$Tutorial_19()       # Load Models Direct risk model data
    app$Tutorial_19b()	    # Change numeraire with Models Direct risk model data	

    app$Tutorial_20()	    # Load asset exposures with CSV file

    app$Tutorial_21()       # Load case with .wsp file, collect KKT terms
   
	app$Tutorial_22()       # Multi-period optimization

    app$Tutorial_23()	    # Portfolio concentration constraint

    app$Tutorial_25a()		# Multi_account optimization
    app$Tutorial_25b()		# Multi_account tax-aware optimization
    app$Tutorial_25c()		# Multi_account optimization with tax arbitrage
    app$Tutorial_25d()		# Multi_account optimization with tax harvesting
    app$Tutorial_25e()		# Multi_account optimization with account groups
    
    app$Tutorial_26()      	# Issuer constraints

    app$Tutorial_27a()      # Expected Shortfall term
    app$Tutorial_27b()      # Expected Shortfall constraint

    app$Tutorial_28a()      # General ratio constraint
    app$Tutorial_28b()      # Group ratio constraint

    app$Tutorial_29()       # General quadratic constraint

    }, 
	error = function(err){
		message('error in running tutorials:')
		message(err)
	},
	warning = function(cond){
		message('warning in running tutorials:')
		message(cond)
	}, 
	finally = {
	}
)