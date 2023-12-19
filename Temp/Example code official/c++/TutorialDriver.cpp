/** @file TutorialDriver.cpp
* \brief Contains the main driver routine that runs each of the tutorials in sequence.
*/

/*! \mainpage Barra Optimizer C++ API Tutorials
*
* \section Introduction
* Barra Optimizer C++ API Tutorials include examples of C++ source code to help 
* developers to write C++ applications calling the Barra Optimizer.  Please 
* refer to the Barra Optimizer Users Guide and C++ API Reference Guide for more details.
*
* The main() driver routine is in TutorialDriver.cpp, that runs each of the 
* tutorials in sequence. All tutorials use the shared routines and data in 
* TutorialBase.cpp and TutorialData.cpp to set-up risk models, portfolios, 
* etc. TutorialApp.cpp contains specific code for each of the tutorials.
*
* \section Typical Steps in Using Barra Optimizer
* For most optimization problems, these are the typical steps in using the Barra Optimizer:
* - Initialize the interface through the CWorkSpace class.
* - Create a Risk Model and set up its factor covariance matrix.
* - Create an asset list and specify for each asset its factor exposure, specific risk covariance and other asset attributes.
* - Create portfolios, benchmarks and the trade universe, as applicable.
* - Create various constraints and penalties.
* - Create an optimization case and specify its utility function and various constraints.
* - Run optimization.
* - Analyze the return status and retrieve an optimal portfolio if successful.
*
* \section Contents
* - CTutorialApp.Tutorial_1a(): Minimizing Total Risk
* - CTutorialApp.Tutorial_1b(): Adding Expected Returns and Adjusting Risk Aversion
* - CTutorialApp.Tutorial_1c(): Adding a Benchmark to Minimize Active Risk
* - CTutorialApp.Tutorial_1d(): Roundlotting
* - CTutorialApp.Tutorial_1e(): Post Optimization Roundlotting
* - CTutorialApp.Tutorial_1f(): Retrieving Additional Statistics for Initial/Optimal Portfolio
* - CTutorialApp.Tutorial_1g(): Checking Optimization Problem/Output Portfolio Type
* - CTutorialApp.Tutorial_2a(): Composites and Linked Assets
* - CTutorialApp.Tutorial_2b(): Futures Contracts 
* - CTutorialApp.Tutorial_2c(): Cash Contributions, Cash Withdrawal, Invest All Cash
* - CTutorialApp.Tutorial_3a(): Asset Range Constraints/Penalty
* - CTutorialApp.Tutorial_3a2(): Relative Asset Range Constraints/Penalty
* - CTutorialApp.Tutorial_3b(): Factor Range Constraints
* - CTutorialApp.Tutorial_3c(): Beta Constraint
* - CTutorialApp.Tutorial_3c2(): Multiple Beta Constraints
* - CTutorialApp.Tutorial_3d(): User Attribute Constraints
* - CTutorialApp.Tutorial_3e(): Setting Relative Constraints
* - CTutorialApp.Tutorial_3f(): Setting Transaction Type
* - CTutorialApp.Tutorial_3g(): Crossover Option
* - CTutorialApp.Tutorial_3h(): Total Active Weight Constraint
* - CTutorialApp.Tutorial_3i(): Dollar Neutral Portfolio
* - CTutorialApp.Tutorial_3j(): Asset free range linear penalty
* - CTutorialApp.Tutorial_4a(): Maximum Number of Assets and estimated utility upper bound
* - CTutorialApp.Tutorial_4b(): Holding and Transaction Size Thresholds
* - CTutorialApp.Tutorial_4c(): Soft Turnover Constraint
* - CTutorialApp.Tutorial_4d(): Buy Side Turnover Constraint
* - CTutorialApp.Tutorial_4e(): Paring by Group Constraint
* - CTutorialApp.Tutorial_4f(): Net Turnover Limit by Group Constraint
* - CTutorialApp.Tutorial_4g(): Paring penalty
* - CTutorialApp.Tutorial_5a(): Linear Transaction Costs
* - CTutorialApp.Tutorial_5b(): Nonlinear Transaction Costs
* - CTutorialApp.Tutorial_5c(): Transaction Cost Constraints
* - CTutorialApp.Tutorial_5d(): Fixed Transaction Costs
* - CTutorialApp.Tutorial_5e(): Load Asset-Level Data From CSV File
* - CTutorialApp.Tutorial_5f(): Fixed Holding Costs
* - CTutorialApp.Tutorial_5g(): General Piecewise Linear Constraint
* - CTutorialApp.Tutorial_6a(): Setting Penalty
* - CTutorialApp.Tutorial_7a(): Risk Budgeting
* - CTutorialApp.Tutorial_7b(): Dual Benchmarks
* - CTutorialApp.Tutorial_7c(): Additive Definition
* - CTutorialApp.Tutorial_7d(): Risk By Asset
* - CTutorialApp.Tutorial_8a(): Long-Short Optimization
* - CTutorialApp.Tutorial_8b(): Short Costs as Single Attribute
* - CTutorialApp.Tutorial_8c(): Weighted Total Leverage Constraint Optimization
* - CTutorialApp.Tutorial_8d(): Long-side Turnover Constraint
* - CTutorialApp.Tutorial_9a(): Risk Target
* - CTutorialApp.Tutorial_9b(): Return Target
* - CTutorialApp.Tutorial_10a(): Tax-aware Optimization (using pre-v8.8 legacy APIs)
* - CTutorialApp.Tutorial_10b(): Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
* - CTutorialApp.Tutorial_10c(): Tax-aware Optimization (Using new APIs introduced in v8.8)
* - CTutorialApp.Tutorial_10d(): Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow
* - CTutorialApp.Tutorial_10e(): Loss Benefit
* - CTutorialApp.Tutorial_10f(): Total Loss/Gain Constraint
* - CTutorialApp.Tutorial_10g(): Wash Sales
* - CTutorialApp.Tutorial_11a(): Efficient Frontier
* - CTutorialApp.Tutorial_11b(): Utility-Factor Constraint Frontier
* - CTutorialApp.Tutorial_11c(): Utility-General Linear Constraint Frontier
* - CTutorialApp.Tutorial_12a(): Constraint Hierarchy
* - CTutorialApp.Tutorial_14a(): Shortfall Beta Constraint
* - CTutorialApp.Tutorial_15a(): Minimizing Total Risk from Both of Primary and Secondary Risk Models
* - CTutorialApp.Tutorial_15b(): Constrain Risk from Secondary Risk Model
* - CTutorialApp.Tutorial_15c(): Risk Parity Constraint
* - CTutorialApp.Tutorial_16a(): Additional Covariance Term
* - CTutorialApp.Tutorial_16b(): Additional Covariance Term
* - CTutorialApp.Tutorial_17a(): Five-Ten-Forty Rule
* - CTutorialApp.Tutorial_18(): Factor Block Structure
* - CTutorialApp.Tutorial_19(): Load Risk Model Data from Models Direct Files
* - CTutorialApp.Tutorial_19b(): Change numeraire with Models Direct risk model data
* - CTutorialApp.Tutorial_20(): Load Asset Exposures with CSV File
* - CTutorialApp.Tutorial_21(): Retrieve Constraint & Asset KKT Attribution Terms
* - CTutorialApp.Tutorial_22(): Multi-Period Optimization
* - CTutorialApp.Tutorial_23(): Portfolio Concentration Constraint
* - CTutorialApp.Tutorial_25a(): Multi-account optimization
* - CTutorialApp.Tutorial_25b(): Multi-account tax-aware optimization
* - CTutorialApp.Tutorial_25c(): Multi-account optimization with tax arbitrage
* - CTutorialApp.Tutorial_25d(): Multi-account optimization with tax harvesting
* - CTutorialApp.Tutorial_25e(): Multi-account optimization with account groups
* - CTutorialApp.Tutorial_26(): Issuer constraints
* - CTutorialApp.Tutorial_27a(): Expected Shortfall term
* - CTutorialApp.Tutorial_27b(): Expected Shortfall constraint
* - CTutorialApp.Tutorial_28a(): General ratio constraint
* - CTurorialApp.Tutorial_28b(): Group ratio constraint
* - CTurorialApp.Tutorial_29(): General quadratic constraint
*/

#include "TutorialApp.h"
#include <iostream>

/// Runs each of the tutorials in sequence.
// command line specifies the tutorial ID for which the user wishes to dump workspace data
int main(int argc, char* argv[])
{
	// The oData object contains risk model data, per asset data, etc
	CTutorialData oData;		

	CTutorialApp app(&oData);
	app.ParseCommandLine(argc, argv); 

	try {
		app.Tutorial_1a();		// Minimize Total Risk
		app.Tutorial_1b();		// Maximize Return and Minimize Total Risk
		app.Tutorial_1c();		// Minimize Active Risk
		app.Tutorial_1d();		// Roundlotting
		app.Tutorial_1e();		// Post Optimization Roundlotting
		app.Tutorial_1f();		// Additional Statistics for Initial/Optimal Portfolio
		app.Tutorial_1g();		// Optimization Problem/Output Portfolio Type

		app.Tutorial_2a();		// Composite Asset
		app.Tutorial_2b();		// Futures Contracts
		app.Tutorial_2c();		// Cash contribution

		app.Tutorial_3a();		// Asset Range Constraints/Penalty
		app.Tutorial_3a2();		// Relative Asset Range Constraints/Penalty
		app.Tutorial_3b();		// Factor Range Constraints
		app.Tutorial_3c();		// Beta Constraint
		app.Tutorial_3c2();		// Multiple Beta Constraints
		app.Tutorial_3d();		// User Attribute Constraints
		app.Tutorial_3e();		// Relative Constraints
		app.Tutorial_3f();		// Transaction Type
		app.Tutorial_3g();		// Crossover Option
		app.Tutorial_3h();		// Total Active Weight Constraint
		app.Tutorial_3i();		// Dollar Neutral Strategy
		app.Tutorial_3j();		// Asset Free Range Linear Penalty

		app.Tutorial_4a();		// Max # of assets and estimated utility upper bound
		app.Tutorial_4b();		// Min Holding Level and Transaction Size
		app.Tutorial_4c();		// Soft Turnover Constraint
		app.Tutorial_4d();		// Buy Side Turnover Constraint
		app.Tutorial_4e();		// Max # of assets by group
		app.Tutorial_4f();		// Net turnover limit by group
		app.Tutorial_4g();		// Paring penalty

		app.Tutorial_5a();		// Piecewise Linear Transaction Costs
		app.Tutorial_5b();		// Nonlinear Transaction Costs
		app.Tutorial_5c();		// Transaction Cost Constraint
		app.Tutorial_5d();		// Fixed Transaction Costs
		app.Tutorial_5e();		// Asset-level Data incl. Fixed Transaction Costs - Loaded from CSV file
		app.Tutorial_5f();		// Fixed Holding Costs
		app.Tutorial_5g();		// General Piecewise Linear Constraint

		app.Tutorial_6a();		// Penalty

		app.Tutorial_7a();		// Risk Budgeting
		app.Tutorial_7b();		// Risk Budgeting - Dual Benchmark
		app.Tutorial_7c();		// Risk Budgeting - Additive Definition
		app.Tutorial_7d();		// Risk Budgeting - By Asset

		app.Tutorial_8a();		// Long-Short Hedge Optimization
		app.Tutorial_8b();		// Short Costs as Single Attribute
		app.Tutorial_8c();		// Weighted Total Leverage Constraint
		app.Tutorial_8d();		// Turnover-by-side Constraint

		app.Tutorial_9a();		// Risk Target
		app.Tutorial_9b();		// Return Target

		app.Tutorial_10a();		// Tax-aware Optimization (using pre-v8.8 legacy APIs)
		app.Tutorial_10b();		// Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
		app.Tutorial_10c();		// Tax-aware Optimization (using new APIs introduced in v8.8)
		app.Tutorial_10d();		// Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
		app.Tutorial_10e();		// Loss Benefit
		app.Tutorial_10f();		// Total Loss/Gain Constraint
		app.Tutorial_10g();		// Wash Sales

		app.Tutorial_11a();		// Efficient Frontier
		app.Tutorial_11b();		// Factor Constraint Frontier
		app.Tutorial_11c();		// General Linear Constraint Frontier
		app.Tutorial_11d();		// Hedge Constraint Frontier

		app.Tutorial_12a();		// Constraint Hierarchy

		app.Tutorial_14a();		// Shortfall beta constraint

		app.Tutorial_15a();		// Minimize risk from 2 risk models 
		app.Tutorial_15b();		// Constrain risk from secondary risk model
		app.Tutorial_15c();		// Risk parity constraint

		app.Tutorial_16a();		// Additional Covariance term - WXFX'W
		app.Tutorial_16b();		// Additional Covariance term - XWFWX'

		app.Tutorial_17a();		// Five-Ten-Forty Rule

		app.Tutorial_18();		// Factor block structure

		app.Tutorial_19();		// Load risk model data using Models Direct files
		app.Tutorial_19b();		// Change numeraire with Models Direct risk model data

		app.Tutorial_20();		// Load asset exposures with CSV file

		app.Tutorial_21();		// Load case data using with a wsp file, retrieve KKT

		app.Tutorial_22();		// Multi-period optimization

		app.Tutorial_23();		// Portfolio concentration constraint

		app.Tutorial_25a();		// Multi-account optimization
		app.Tutorial_25b();		// Multi-account tax-aware optimization
		app.Tutorial_25c();		// Multi-account optimization with tax arbitrage
		app.Tutorial_25d();		// Multi-account optimization with tax harvesting
		app.Tutorial_25e();		// Multi-account optimization with account groups

		app.Tutorial_26();		// Issuer Constraints

		app.Tutorial_27a();		// Expected Shortfall term
		app.Tutorial_27b();		// Expected Shortfall constraint

		app.Tutorial_28a();		// General ratio constraint
		app.Tutorial_28b();		// Group ratio constraint

		app.Tutorial_29();		// General quadratic constraint
	}
	catch(EStatusCode){			// handle license error
		std::cerr<<"Optimizer license error"<<endl;
	}
}
