/** @file TutorialDriver.cs
* \brief Contains the main driver routine that runs each of the tutorials in sequence.
*/

/*! \mainpage Barra Optimizer COM API Tutorials
*
* \section Introduction
* Barra Optimizer COM Tutorials include examples of C# source code to help developers
* to write .Net applications (C#, VB, etc) calling the Barra Optimizer COM API.
* Please refer to the Barra Optimizer Programmer's Guide for more details.
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
*/

namespace Tutorial_CS_Protobuf
{
    /// Contains the main driver routine that runs each of the tutorials in sequence.
    class TutorialDriver
    {
        /// Driver routine that runs each of the tutorials in sequence.
        public static void Main(string[] args)
        {
            TutorialApp app = new TutorialApp(new TutorialData());

            app.Tutorial_1a();		// Minimize Total Risk
            app.Tutorial_1b();		// Maximize Return and Minimize Total Risk
            app.Tutorial_1c();		// Minimize Active Risk
            app.Tutorial_1d();		// Roundlotting
            app.Tutorial_1e();		// Post Optimization Roundlotting

            app.Tutorial_2c();		// Cash contribution

            app.Tutorial_3a();		// Asset Bound Constraints
            app.Tutorial_3b();		// Asset Bound Relative Constraints
            app.Tutorial_3c();		// Factor Range Constraints
            app.Tutorial_3d();		// Beta Constraint
            app.Tutorial_3e();		// Constraint by Group
            app.Tutorial_3f();      // Relative Constraint by Group 
            app.Tutorial_3g();		// Transaction Type
            app.Tutorial_3h();		// Crossover Option

            app.Tutorial_4a();		// Max # of assets
            app.Tutorial_4b();		// Min Holding Level and Transaction Size
            app.Tutorial_4c();		// Soft Turnover Constraint

            app.Tutorial_5a();		// Piecewise Linear Transaction Costs
            app.Tutorial_5b();		// Nonlinear Transaction Costs
            app.Tutorial_5c();		// Transaction Cost Constraint
            app.Tutorial_5d();      // Fixed Transaction Costs
            app.Tutorial_5g();		// General Piecewise Linear Constraint

            app.Tutorial_6a();		// Penalty

            app.Tutorial_7a();		// Risk Budgeting
            app.Tutorial_7b();		// Risk Budgeting - Dual Benchmark
            app.Tutorial_7d();      // Risk Budgeting - By Asset

            app.Tutorial_8a();		// Long-Short Hedge Optimization
            app.Tutorial_8c();      // Weighted Total Leverage Constraint

            app.Tutorial_9a();		// Risk Target
            app.Tutorial_9b();		// Return Target

            app.Tutorial_10c();     // Tax-aware Optimization (using new APIs introduced in v8.8)
            app.Tutorial_10d();		// Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
            app.Tutorial_10e();		// Tax-aware Optimization with loss benefit
            app.Tutorial_10f();     // Total Gain/Loss Constraint
            app.Tutorial_10g();     // Wash Sales

            app.Tutorial_11a();		// Efficient Frontier

            app.Tutorial_12a();		// Constraint Priority

            app.Tutorial_14a();		// Shortfall beta constraint

            app.Tutorial_15a();		// Minimize risk from 2 risk models 
            app.Tutorial_15b();		// Constrain risk from secondary risk model
            app.Tutorial_15c();     // Risk Parity Constraint

            app.Tutorial_16a();		// Additional Covariance term - WXFX'W

            app.Tutorial_17a();		// Five-Ten-Forty Rule	

            app.Tutorial_18();      // Factor exposure block

            app.Tutorial_19();      // Load risk model data using Models Direct files

            app.Tutorial_28a();     // General ratio constraint
            app.Tutorial_28b();     // Group ratio constraint

            app.Tutorial_29();      // General quadratic constraint
        }
    }
}
