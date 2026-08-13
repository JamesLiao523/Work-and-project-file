/** @file TutorialDriver.cs
* \brief Contains the main driver routine that runs each of the tutorials in sequence.
*/

/*! \mainpage Barra Optimizer C# API Tutorials
*
* \section Introduction
* Barra Optimizer C# API Tutorials include examples of C# source code to help developers
* to write C# applications calling the Barra Optimizer C# API.
* Please refer to the Barra Optimizer Users Guide and C# API Reference Guide for more details.
*
* The main() driver routine is in TutorialDriver.cs, that runs each of the 
* tutorials in sequence. All tutorials use the shared routines and data in 
* TutorialBase.cs and TutorialData.cs to set-up risk models, portfolios, 
* etc. TutorialApp.cs contains specific code for each of the tutorials.
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
* - Tutorial_CS.TutorialApp.Tutorial_1a(): Minimizing Total Risk
* - Tutorial_CS.TutorialApp.Tutorial_1b(): Adding Expected Returns and Adjusting Risk Aversion
* - Tutorial_CS.TutorialApp.Tutorial_1c(): Adding a Benchmark to Minimize Active Risk
* - Tutorial_CS.TutorialApp.Tutorial_1d(): Roundlotting
* - Tutorial_CS.TutorialApp.Tutorial_1e(): Post Optimization Roundlotting
* - Tutorial_CS.TutorialApp.Tutorial_1f(): Retrieving Additional Statistics for Initial/Optimal Portfolio
* - Tutorial_CS.TutorialApp.Tutorial_1g(): Checking Optimization Problem/Output Portfolio Type
* - Tutorial_CS.TutorialApp.Tutorial_2a(): Composites and Linked Assets
* - Tutorial_CS.TutorialApp.Tutorial_2b(): Futures Contracts 
* - Tutorial_CS.TutorialApp.Tutorial_2c(): Cash Contributions, Cash Withdrawal, Invest All Cash
* - Tutorial_CS.TutorialApp.Tutorial_3a(): Asset Range Constraints/Penalty
* - Tutorial_CS.TutorialApp.Tutorial_3a2(): Relative Asset Range Constraints/Penalty
* - Tutorial_CS.TutorialApp.Tutorial_3b(): Factor Range Constraints
* - Tutorial_CS.TutorialApp.Tutorial_3c(): Beta Constraint
* - Tutorial_CS.TutorialApp.Tutorial_3c2(): Multiple Beta Constraints
* - Tutorial_CS.TutorialApp.Tutorial_3d(): User Attribute Constraints
* - Tutorial_CS.TutorialApp.Tutorial_3e(): Setting Relative Constraints
* - Tutorial_CS.TutorialApp.Tutorial_3f(): Setting Transaction Type
* - Tutorial_CS.TutorialApp.Tutorial_3g(): Crossover Option
* - Tutorial_CS.TutorialApp.Tutorial_3h(): Total Active Weight Constraint
* - Tutorial_CS.TutorialApp.Tutorial_3i(): Dollar Neutral Portfolio
* - Tutorial_CS.TutorialApp.Tutorial_3j(): Asset free range linear penalty
* - Tutorial_CS.TutorialApp.Tutorial_4a(): Maximum Number of Assets and estimated utility upper bound
* - Tutorial_CS.TutorialApp.Tutorial_4b(): Holding and Transaction Size Thresholds
* - Tutorial_CS.TutorialApp.Tutorial_4c(): Soft Turnover Constraint
* - Tutorial_CS.TutorialApp.Tutorial_4d(): Buy Side Turnover Constraint
* - Tutorial_CS.TutorialApp.Tutorial_4e(): Paring by Group Constraint
* - Tutorial_CS.TutorialApp.Tutorial_4f(): Net Turnover Limit by Group Constraint
* - Tutorial_CS.TutorialApp.Tutorial_4g(): Paring penalty
* - Tutorial_CS.TutorialApp.Tutorial_5a(): Linear Transaction Costs
* - Tutorial_CS.TutorialApp.Tutorial_5b(): Nonlinear Transaction Costs
* - Tutorial_CS.TutorialApp.Tutorial_5c(): Transaction Cost Constraints
* - Tutorial_CS.TutorialApp.Tutorial_5d(): Fixed Transaction Costs
* - Tutorial_CS.TutorialApp.Tutorial_5e(): Load Asset-Level Data From CSV File
* - Tutorial_CS.TutorialApp.Tutorial_5f(): Fixed Holding Costs
* - Tutorial_CS.TutorialApp.Tutorial_5g(): General Piecewise Linear Constraint
* - Tutorial_CS.TutorialApp.Tutorial_6a(): Setting Penalty
* - Tutorial_CS.TutorialApp.Tutorial_7a(): Risk Budgeting
* - Tutorial_CS.TutorialApp.Tutorial_7b(): Dual Benchmarks
* - Tutorial_CS.TutorialApp.Tutorial_7c(): Additive Risk Definition
* - Tutorial_CS.TutorialApp.Tutorial_7d(): Risk By Asset
* - Tutorial_CS.TutorialApp.Tutorial_8a(): Long-Short Optimization
* - Tutorial_CS.TutorialApp.Tutorial_8b(): Short Costs as Single Attribute
* - Tutorial_CS.TutorialApp.Tutorial_8c(): Weighted Total Leverage Constraint Optimization
* - Tutorial_CS.TutorialApp.Tutorial_8d(): Long-side Turnover Constraint
* - Tutorial_CS.TutorialApp.Tutorial_9a(): Risk Target
* - Tutorial_CS.TutorialApp.Tutorial_9b(): Return Target
* - Tutorial_CS.TutorialApp.Tutorial_10a(): Tax-aware Optimization (using pre-v8.8 legacy APIs)
* - Tutorial_CS.TutorialApp.Tutorial_10b(): Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
* - Tutorial_CS.TutorialApp.Tutorial_10c(): Tax-aware Optimization (Using new APIs introduced in v8.8)
* - Tutorial_CS.TutorialApp.Tutorial_10d(): Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow
* - Tutorial_CS.TutorialApp.Tutorial_10e(): Loss benefit
* - Tutorial_CS.TutorialApp.Tutorial_10f(): Total Loss/Gain Constraint
* - Tutorial_CS.TutorialApp.Tutorial_10g(): Wash Sales
* - Tutorial_CS.TutorialApp.Tutorial_11a(): Efficient Frontier
* - Tutorial_CS.TutorialApp.Tutorial_11b(): Utility-Factor Constraint Frontier
* - Tutorial_CS.TutorialApp.Tutorial_11c(): Utility-General Linear Constraint Frontier
* - Tutorial_CS.TutorialApp.Tutorial_11d(); Utility-leaverage Frontier
* - Tutorial_CS.TutorialApp.Tutorial_12a(): Constraint Hierarchy
* - Tutorial_CS.TutorialApp.Tutorial_14a(): Shortfall Beta Constraint
* - Tutorial_CS.TutorialApp.Tutorial_15a(): Minimizing Total Risk from Both of Primary and Secondary Risk Models
* - Tutorial_CS.TutorialApp.Tutorial_15b(): Constrain Risk from Secondary Risk Model
* - Tutorial_CS.TutorialApp.Tutorial_15c(): Risk Parity Constraint
* - Tutorial_CS.TutorialApp.Tutorial_16a(): Additional Covariance Term
* - Tutorial_CS.TutorialApp.Tutorial_16b(): Additional Covariance Term
* - Tutorial_CS.TutorialApp.Tutorial_17a(): Five-Ten-Forty Rule
* - Tutorial_CS.TutorialApp.Tutorial_18(): Factor Block Structure
* - Tutorial_CS.TutorialApp.Tutorial_19(): Load Risk Model Data from Models Direct Files
* - Tutorial_CS.TutorialApp.Tutorial_19b(): Change numeraire with Models Direct risk model data
* - Tutorial_CS.TutorialApp.Tutorial_20(): Load Asset Exposures with CSV File
* - Tutorial_CS.TutorialApp.Tutorial_21(): Retrieve Constraint & Asset KKT Attribution Terms
* - Tutorial_CS.TutorialApp.Tutorial_22(): Multi-Period Optimization
* - Tutorial_CS.TutorialApp.Tutorial_23(): Portfolio Concentration Constraint
* - Tutorial_CS.TutorialApp.Tutorial_25a(); Multi-account optimization
* - Tutorial_CS.TutorialApp.Tutorial_25b(): Multi-account tax-aware optimization
* - Tutorial_CS.TutorialApp.Tutorial_25c(): Multi-account optimization with tax arbitrage
* - Tutorial_CS.TutorialApp.Tutorial_25d(): Multi-account optimization with tax harvesting
* - Tutorial_CS.TutorialApp.Tutorial_25e(): Multi-account optimization with account groups
* - Tutorial_CS.TutorialApp.Tutorial_26(): Issuer constraints
* - Tutorial_CS.TutorialApp.Tutorial_27a(): Expected Shortfall term
* - Tutorial_CS.TutorialApp.Tutorial_27b(): Expected Shortfall constraint
* - Tutorial_CS.TutorialApp.Tutorial_28a(): General ratio constraint
* - Tutorial_CS.TutorialApp.Tutorial_28b(): Group ratio constraint
* - Tutorial_CS.TutorialApp.Tutorial_29(): General quadratic constraint
*/

namespace Tutorial_CS
{
    /// Contains the main driver routine that runs each of the tutorials in sequence.
    class TutorialDriver
    {
        /// Driver routine that runs each of the tutorials in sequence.
        public static void Main(string[] args)
        {
            TutorialApp app = new TutorialApp(new TutorialData());
            app.ParseCommandLine(args);

            try
            {
                app.Tutorial_1a();	// Minimize Total Risk

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
                app.Tutorial_7c();      // Risk Budgeting - Additive Definition
                app.Tutorial_7d();		// Risk Budgeting - By Asset

                app.Tutorial_8a();		// Long-Short Hedge Optimization
                app.Tutorial_8b();		// Short Costs as Single Attribute
                app.Tutorial_8c();      // Weighted Total Leverage Constraint
                app.Tutorial_8d();		// Turnover-by-side Constraint

                app.Tutorial_9a();		// Risk Target
                app.Tutorial_9b();		// Return Target

                app.Tutorial_10a();		// Tax-aware Optimization (using pre-v8.8 legacy APIs)
                app.Tutorial_10b();		// Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
                app.Tutorial_10c();     // Tax-aware Optimization (using new APIs introduced in v8.8)
                app.Tutorial_10d();		// Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
                app.Tutorial_10e();		// Loss benefit
                app.Tutorial_10f();     // Total Loss/Gain Constraint
                app.Tutorial_10g();     // Wash Sales

                app.Tutorial_11a();		// Efficient Frontier
                app.Tutorial_11b();		// Factor Constraint Frontier
                app.Tutorial_11c();		// General Linear Constraint Frontier
                app.Tutorial_11d();     // Utility-leaverage Frontier

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

                app.Tutorial_21();		// Load case with wsp file, collect KKT terms

                app.Tutorial_22();		// Multi-period optimization

                app.Tutorial_23();		// Portfolio concentration constraint

                app.Tutorial_25a();     // Multi_account optimization
                app.Tutorial_25b();     // Multi-account tax-aware optimization
                app.Tutorial_25c();     // Multi-account optimization with tax arbitrage
                app.Tutorial_25d();		// Multi-account optimization with tax harvesting
                app.Tutorial_25e();		// Multi-account optimization with account groups

                app.Tutorial_26();      // Issuer constraints

                app.Tutorial_27a();     // Expected Shortfall term
                app.Tutorial_27b();		// Expected Shortfall constraint

                app.Tutorial_28a();		// General ratio constraint
                app.Tutorial_28b();		// Group ratio constraint

                app.Tutorial_29();      // General quadratic constraint
            }
            catch (System.InvalidOperationException e){ // handle license error
                System.Console.WriteLine(e.Message);
            }
        }
    }
}
