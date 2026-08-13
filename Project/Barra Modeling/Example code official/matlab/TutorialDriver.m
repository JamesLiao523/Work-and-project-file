%% Tutorial driver script
%   Initializes java interface, processes command line arguments, runs all
%   the tutorials
%
%   optimization java API installation: 
%   copy the corresponding librarypath.txt.(32/64) into the "prefdir" of
%   the matlab installed in you system
%
%   command line arguments: (refer to runtutorial.bat/sh)
%   argline = entire command line arguments stored as one string array 
%   Example:
%   >>argline = '-d 2a 5c -c';
%   >>TutorialDriver;
%
    %% Initialize java optimizer interface
    import com.barra.optimizer.*;
    COptJavaInterface.Init;

    %% Read in simulation data
    oData = TutorialData();	
    
    %% Construct an application object
    app = TutorialApp(oData);
    
    %% Process command line arguments 
    % check the existance of commandline arguments
    if exist('argline', 'var') == 0
        argline = '';
    end
    % parse command line arguments 
    argv = app.strsplit(argline);
    app.ParseCommandLine(argv);

    %% Run tutorials
    try
        app.Tutorial_1a();		% Minimize Total Risk
        app.Tutorial_1b();		% Maximize Return and Minimize Total Risk
        app.Tutorial_1c();		% Minimize Active Risk
        app.Tutorial_1d();		% Roundlotting
        app.Tutorial_1e();		% Post Optimization Roundlotting
        app.Tutorial_1f();		% Additional Statistics for Initial/Optimal Portfolio
        app.Tutorial_1g();		% Optimization Problem/Output Portfolio Type

        app.Tutorial_2a();		% Composite Asset
        app.Tutorial_2b();		% Futures Contracts
        app.Tutorial_2c();		% Cash contribution

        app.Tutorial_3a();		% Asset Range Constraints/Penalty
        app.Tutorial_3a2();		% Relative Asset Range Constraints/Penalty
        app.Tutorial_3b();		% Factor Range Constraints
        app.Tutorial_3c();		% Beta Constraint
        app.Tutorial_3c2();		% Multiple Beta Constraints
        app.Tutorial_3d();		% User Attribute Constraints
        app.Tutorial_3e();		% Relative Constraints
        app.Tutorial_3f();		% Transaction Type
        app.Tutorial_3g();		% Crossover Option
        app.Tutorial_3h();		% Total Active Weight Constraint
        app.Tutorial_3i();	    % Dollar Neutral Strategy
        app.Tutorial_3j();		% Asset Free Range Linear Penalty
        
        app.Tutorial_4a();		% Max # of assets and estimated utility upper bound
        app.Tutorial_4b();		% Min Holding Level and Transaction Size
        app.Tutorial_4c();		% Soft Turnover Constraint
        app.Tutorial_4d();		% Buy Side Turnover Constraint
        app.Tutorial_4e();		% Max # of assets by group
        app.Tutorial_4f();		% Net turnover limit by group
        app.Tutorial_4g();	    % Paring penalty
        
        app.Tutorial_5a();		% Piecewise Linear Transaction Costs
        app.Tutorial_5b();		% Nonlinear Transaction Costs
        app.Tutorial_5c();		% Transaction Cost Constraint
        app.Tutorial_5d();		% Fixed Transaction Costs
        app.Tutorial_5e();		% Asset-level Data incl. Fixed Transaction Costs - Loaded from CSV file
        app.Tutorial_5f();		% Fixed Holding Costs
        app.Tutorial_5g();		% General Piecewise Linear Constraint

        app.Tutorial_6a();		% Penalty

        app.Tutorial_7a();		% Risk Budgeting
        app.Tutorial_7b();		% Risk Budgeting - Dual Benchmark
		app.Tutorial_7c();		% Risk Budgeting - Addidive Definition
        app.Tutorial_7d();      % Risk Budgeting - By Asset

        app.Tutorial_8a();		% Long-Short Hedge Optimization
        app.Tutorial_8b();		% Short Costs as Single Attribute
        app.Tutorial_8c();      % Weighted Total Leverage Constraint
        app.Tutorial_8d();		% Turnover-by-side Constraint

        app.Tutorial_9a();		% Risk Target
        app.Tutorial_9b();		% Return Target

        app.Tutorial_10a();		% Tax-aware Optimization (using pre-v8.8 legacy APIs)
        app.Tutorial_10b();		% Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
        app.Tutorial_10c();		% Tax-aware Optimization (using new APIs introduced in v8.8)
        app.Tutorial_10d();		% Tax-aware Optimization (using new APIs introduced in v8.8) with cash outflow
        app.Tutorial_10e();		% Loss Benefit
        app.Tutorial_10f();		% Total Loss/Gain Constraint
        app.Tutorial_10g();		% Wash Sales

        app.Tutorial_11a();		% Efficient Frontier
        app.Tutorial_11b();		% Factor Constraint Frontier
        app.Tutorial_11c();		% General Linear Constraint Frontier
        app.Tutorial_11d();		% Utility-Leaverage Frontier

        app.Tutorial_12a();		% Constraint Hierarchy

        app.Tutorial_14a();		% Shortfall beta constraint

        app.Tutorial_15a();		% Minimize risk from 2 risk models 
        app.Tutorial_15b();		% Constrain risk from secondary risk model
        app.Tutorial_15c();     % Risk Parity Constraint

        app.Tutorial_16a();		% Additional Covariance term - WXFX'W
        app.Tutorial_16b();		% Additional Covariance term - XWFWX'

        app.Tutorial_17a();		% Five-Ten-Forty Rule

        app.Tutorial_18();      % Factor exposure block

        app.Tutorial_19();      % Load Models Direct risk model data
        app.Tutorial_19b();		% Change numeraire with Models Direct risk model data
        
        app.Tutorial_20();		% Load asset exposures with CSV file 

        app.Tutorial_21();      % Load case with wsp file, collect KKT terms

        app.Tutorial_22();		% Multi-period optimization

        app.Tutorial_23();		% Portfolio concentration constraint

        app.Tutorial_25a();      % Multi_account optimization
        app.Tutorial_25b();      % Multi_account tax-aware optimization
        app.Tutorial_25c();      % Multi_account optimization with tax arbitrage
        app.Tutorial_25d();      % Multi_account optimization with tax harvesting
        app.Tutorial_25e();      % Multi_account optimization with account groups
        
        app.Tutorial_26();      % Issuer constraints
    	
        app.Tutorial_27a();     % Expected Shortfall term
        app.Tutorial_27b();     % Expected Shortfall constraint

        app.Tutorial_28a();     % General ratio constraint
        app.Tutorial_28b();     % Group ratio constraint

        app.Tutorial_29();      % General quadratic constraint

    catch ME					% handle license error
        if strcmp(ME.identifier,'Optimizer:License')
            fprintf(ME.message);
            fprintf('\n');
        else
            rethrow(ME)
        end
    end
