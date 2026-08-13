/** @file TutorialDriver.java
* \brief Contains the main driver routine that runs each of the tutorials in sequence.
*/

/*! \mainpage Barra Optimizer JAVA API Tutorials
*
* \section Introduction
* Barra Optimizer JAVA Tutorials include examples of JAVA source code to help 
* developers to write JAVA applications calling the Barra Optimizer.  Please 
* refer to the Barra Optimizer Users Guide and JAVA API Reference Guide for more details.
*
* The main() driver routine is in TutorialDriver.java, that runs each of the 
* tutorials in sequence. All tutorials use the shared routines and data in 
* TutorialBase.java and TutorialData.java to set-up risk models, portfolios, 
* etc. TutorialApp.java contains specific code for each of the tutorials.
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
* \section Contents
* - TutorialApp.Tutorial_1a(): Minimizing Total Risk
* - TutorialApp.Tutorial_1b(): Adding Expected Returns and Adjusting Risk Aversion
* - TutorialApp.Tutorial_1c(): Adding a Benchmark to Minimize Active Risk
* - TutorialApp.Tutorial_1d(): Roundlotting
* - TutorialApp.Tutorial_1e(): Post Optimization Roundlotting
* - TutorialApp.Tutorial_1f(): Retrieving Additional Statistics for Initial/Optimal Portfolio
* - TutorialApp.Tutorial_1g(): Checking Optimization Problem/Output Portfolio Type
* - TutorialApp.Tutorial_2a(): Composites and Linked Assets
* - TutorialApp.Tutorial_2b(): Futures Contracts 
* - TutorialApp.Tutorial_2c(): Cash Contributions, Cash Withdrawal, Invest All Cash
* - TutorialApp.Tutorial_3a(): Asset Range Constraints/Penalty
* - TutorialApp.Tutorial_3a2(): Relative Asset Range Constraints/Penalty
* - TutorialApp.Tutorial_3b(): Factor Range Constraints
* - TutorialApp.Tutorial_3c(): Beta Constraint
* - TutorialApp.Tutorial_3c2(): Multiple Beta Constraints
* - TutorialApp.Tutorial_3d(): User Attribute Constraints
* - TutorialApp.Tutorial_3e(): Setting Relative Constraints
* - TutorialApp.Tutorial_3f(): Setting Transaction Type
* - TutorialApp.Tutorial_3g(): Crossover Option
* - TutorialApp.Tutorial_3h(): Total Active Weight Constraint
* - TutorialApp.Tutorial_3i(): Dollar Neutral Portfolio
* - TutorialApp.Tutorial_3j(): Asset free range linear penalty
* - TutorialApp.Tutorial_4a(): Maximum Number of Assets and estimated utility upper bound
* - TutorialApp.Tutorial_4b(): Holding and Transaction Size Thresholds
* - TutorialApp.Tutorial_4c(): Soft Turnover Constraint
* - TutorialApp.Tutorial_4d(): Buy Side Turnover Constraint
* - TutorialApp.Tutorial_4e(): Paring by Group Constraint
* - TutorialApp.Tutorial_4f(): Net Turnover Limit by Group Constraint
* - TutorialApp.Tutorial_4g(): Paring penalty
* - TutorialApp.Tutorial_5a(): Linear Transaction Costs
* - TutorialApp.Tutorial_5b(): Nonlinear Transaction Costs
* - TutorialApp.Tutorial_5c(): Transaction Cost Constraints
* - TutorialApp.Tutorial_5d(): Fixed Transaction Costs
* - TutorialApp.Tutorial_5e(): Load Asset-Level Data From CSV File
* - TutorialApp.Tutorial_5f(): Fixed Holding Costs
* - TutorialApp.Tutorial_5g(): General Piecewise Linear Constraint
* - TutorialApp.Tutorial_6a(): Setting Penalty
* - TutorialApp.Tutorial_7a(): Risk Budgeting
* - TutorialApp.Tutorial_7b(): Dual Benchmarks
* - TutorialApp.Tutorial_7c(): Additive Risk Defintion
* - TutorialApp.Tutorial_7d(): Risk By Asset
* - TutorialApp.Tutorial_8a(): Long-Short Optimization
* - TutorialApp.Tutorial_8b(): Short Costs as Single Attribute
* - TutorialApp.Tutorial_8c(): Weighted Total Leverage Constraint Optimization
* - TutorialApp.Tutorial_8d(): Long-side Turnover Constraint
* - TutorialApp.Tutorial_9a(): Risk Target
* - TutorialApp.Tutorial_9b(): Return Target
* - TutorialApp.Tutorial_10a(): Tax-aware Optimization (using pre-v8.8 legacy APIs)
* - TutorialApp.Tutorial_10b(): Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
* - TutorialApp.Tutorial_10c(): Tax-aware Optimization (Using new APIs introduced in v8.8)
* - TutorialApp.Tutorial_10d(): Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow
* - TutorialApp.Tutorial_10e(): Loss benefit
* - TutorialApp.Tutorial_10f(): Total Loss/Gain Constraint
* - TutorialApp.Tutorial_10g(): Wash Sales
* - TutorialApp.Tutorial_11a(): Efficient Frontier
* - TutorialApp.Tutorial_11b(): Utility-Factor Constraint Frontier
* - TutorialApp.Tutorial_11c(): Utility-General Linear Constraint Frontier
* - TutorialApp.Tutorial_11d(): Utility-Leaverage Frontier
* - TutorialApp.Tutorial_12a(): Constraint Hierarchy
* - TutorialApp.Tutorial_14a(): Shortfall Beta Constraint
* - TutorialApp.Tutorial_15a(): Minimizing Total Risk from Both of Primary and Secondary Risk Models
* - TutorialApp.Tutorial_15b(): Constrain Risk from Secondary Risk Model
* - TutorialApp.Tutorial_15c(): Risk Parity Constraint
* - TutorialApp.Tutorial_16a(): Additional Covariance Term
* - TutorialApp.Tutorial_16b(): Additional Covariance Term
* - TutorialApp.Tutorial_17a(): Five-Ten-Forty Rule
* - TutorialApp.Tutorial_18(): Factor Block Structure
* - TutorialApp.Tutorial_19(): Load Risk Model Data from Models Direct Files
* - TutorialApp.Tutorial_19b(): Change numeraire with Models Direct risk model data
* - TutorialApp.Tutorial_20(): Load Asset Exposures with CSV File
* - TutorialApp.Tutorial_21(): Retrieve Constraint & Asset KKT Attribution Terms
* - TutorialApp.Tutorial_22(): Multi-Period Optimization
* - TutorialApp.Tutorial_23(): Portfolio Concentration Constraint
* - TutorialApp.Tutorial_25a(): Multi-account optimization
* - TutorialApp.Tutorial_25b(): Multi-account tax-aware optimization
* - TutorialApp.Tutorial_25c(): Multi-account optimization with tax arbitrage
* - TutorialApp.Tutorial_25d(): Multi-account optimization with tax harvesting
* - TutorialApp.Tutorial_25e(): Multi-account optimization with account groups
* - TutorialApp.Tutorial_26(); Issuer constraints
* - TutorialApp.Tutorial_27a(): Expected Shortfall term
* - TutorialApp.Tutorial_27b(): Expected Shortfall constraint
* - TutorialApp.Tutorial_28a(): General ratio constraint
* - TurorialApp.Tutorial_28b(): Group ratio constraint
* - TutorialApp.Tutorial_29(): General quadratic constraint
*/

import com.barra.optimizer.*;

/// Contains the main driver routine that runs each of the tutorials in sequence.
public class TutorialDriver 
{
	/// Driver routine that runs each of the tutorials in sequence.
    public static void main(String[] args)
    {
        COptJavaInterface.Init();		// Load the Barra Optimizer native C++ library
		
		TutorialApp app = new TutorialApp(new TutorialData());
		app.ParseCommandLine(args);

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
			app.Tutorial_8c();      // Weighted Total Leverage Constraint
			app.Tutorial_8d();		// Turnover-by-side Constraint
			
			app.Tutorial_9a();		// Risk Target
			app.Tutorial_9b();		// Return Target

			app.Tutorial_10a();		// Tax-aware Optimization (using pre-v8.8 legacy APIs)
			app.Tutorial_10b();		// Capital Gain Arbitrage (using pre-v8.8 legacy APIs) (using pre-v8.8 legacy APIs)
			app.Tutorial_10c();		// Tax-aware Optimization (using new APIs introduced in v8.8)
			app.Tutorial_10d();		// Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
			app.Tutorial_10e();		// Loss benefit
			app.Tutorial_10f();		// Total Loss/Gain Constraint
			app.Tutorial_10g();		// Wash Sales

			app.Tutorial_11a();		// Efficient Frontier
			app.Tutorial_11b();		// Factor Constraint Frontier
			app.Tutorial_11c();		// General Linear Constraint Frontier
			app.Tutorial_11d();		// Utility-Leaverage Frontier
						
			app.Tutorial_12a();		// Constraint Hierarchy

			app.Tutorial_14a();		// Shortfall beta constraint
		
			app.Tutorial_15a();		// Minimize risk from 2 risk models 
			app.Tutorial_15b();		// Constrain risk from secondary risk model
			app.Tutorial_15c();     // Risk Parity Constraint

			app.Tutorial_16a();		// Additional Covariance term - WXFX'W
			app.Tutorial_16b();		// Additional Covariance term - XWFWX'

			app.Tutorial_17a();		// Five-Ten-Forty Rule

			app.Tutorial_18();      // Factor exposure block

			app.Tutorial_19();      // Load Models Direct risk model data
			app.Tutorial_19b();		// Change numeraire with Models Direct risk model data
	        
			app.Tutorial_20();		// Load asset exposures with CSV file 
			
			app.Tutorial_21();		// Collect KKT terms

			app.Tutorial_22();		// Multi-period optimization

			app.Tutorial_23();		// Portfolio concentration constraint

			app.Tutorial_25a();     // Multi_account optimization
			app.Tutorial_25b();     // Multi-account tax-aware optimization
			app.Tutorial_25c();     // Multi-account optimization with tax arbitrage
			app.Tutorial_25d();		// Multi-account optimization with tax harvesting
			app.Tutorial_25e();		// Multi-account optimization with account groupss
			
			app.Tutorial_26();      // Issuer constraints
				
			app.Tutorial_27a();     // Expected Shortfall term
			app.Tutorial_27b();		// Expected Shortfall constraint

			app.Tutorial_28a();		// General ratio constraint
			app.Tutorial_28b();		// Group ratio constraint

			app.Tutorial_29();		// General quadratic constraint
			
		}catch (Exception e){		// handle license error
            System.err.println(e);
        }		
	}
}
