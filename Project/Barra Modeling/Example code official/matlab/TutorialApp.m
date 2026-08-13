%% Tutorial Application Class
%     
%     All the tutorials functions are placed under TutorialApp.

%%
classdef TutorialApp < TutorialBase
    % stores tutorial IDs whose workspace to be dumped
    properties( SetAccess='protected' )
        m_DumpTID = containers.Map; 
    end
      
    methods
        % constructor with simulation data as the argument
        function self = TutorialApp(data)
            self@TutorialBase(data);
        end
            
        %% Tutorial_1a: Minimizing Total Risk
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % for minimizing Total Risk.
        %
        function Tutorial_1a(self)            
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('1a', 'Minimize Total Risk');

            % Create a case selfect
            % null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1a', self.m_InitPf, [], 100000, 0.0);
            % set up prime risk model
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            util = self.m_Case.InitUtility();
            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();

            % Get the slack information for default balance constraint.
            output = self.m_Solver.GetPortfolioOutput();
            slackInfo = output.GetSlackInfo4BalanceCon();

            % Get the KKT term of the balance constraint.
            impact = slackInfo.GetKKTTerm(true);
            self.PrintAttributeSet(impact, 'Balance constraint KKT term');
        end

        %% Tutorial_1b: Adding Expected Returns and Adjusting Risk Aversion 
        %
        % The previous examples maximized mean-variance utility, but did not 
        % incorporate alpha (expected returns), so the optimizer was minimizing
        % risk.  When we add returns to the objective function, the optimizer 
        % will look for global maximum utility, trading off return and risk. The
        % common factor and specific risk aversion coefficients control how much
        % disutility that risk generates (in other words, the trade off between 
        % risk and return). 
        %
        % The example Tutorial_1b is to show how to set expected return for each 
        % asset and change the risk aversion coefficients for the common factors 
        % and specific risk:
        %
        function Tutorial_1b(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; 
            % Set up alpha            
            self.InitializeAlpha('1b', 'Maximize Return and Minimize Total Risk', true);

            % Create a case selfect
            % no trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1b', self.m_InitPf, [], 100000, 0.0);
            
            % Set primary risk model
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % set risk aversions for CF and SP & benchmark
            self.m_Case.InitUtility();
            
            % Statement below is optional. 
            % change risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            % util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end
        
        %% Tutorial_1c: Adding a Benchmark to Minimize Active Risk
        % 
        % This sample code illustrates how to use the Barra Optimizer for 
        % minimizing Active Risk by applying a Benchmark to the utility.  
        % With this source code, we extended Tutorial_1a to include a benchmark 
        % and change the objective function in the optimizer to minimize tracking
        % error.  This is a typical workflow for an indexer (tracking a benchmark
        % while minimizing transaction costs).
        %
        function Tutorial_1c(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha           
            self.Initialize( '1c', 'Minimize Active Risk' );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1c', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            %
            util = self.m_Case.InitUtility();
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_1d: Roundlotting
        % 
        % Barra Optimizer returns an optimal portfolio as a set of relative 
        % weights (floating point numbers, which result in fractional shares
        % when converted to share holdings using the portfolio value). 
        %
        % The optimizer supports the use of roundlots when solving the 
        % optimization problem to generate a more realistic trade list. This
        % requires prices and round lot sizes for the trade universe and the
        % base value of the the portfolio.  The roundlot constraint may result in 
        % infeasible solutions so the user can either relax the constraints or
        % round lot the optimization result in the client application (though 
        % this may result in a "less optimal" portfolio).
        %
        % Note that enforcing the roundlot constraint ensures that the trades are roundlotted, 
        % but the final optimal weights may not be in round lots. 
        % 
        % This sample code Tutorial_1d is modified from Tutorial_1b to illustrate 
        % how to set-up roundlotting:
        %
        function Tutorial_1d(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; 
            % Set up alpha            
            self.InitializeAlpha('1d', 'Roundlotting', true);

            % Set round lot info
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi( self.m_Data.m_ID(i), 'CASH')
                    asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                    if ~isempty(asset)
                        % Round lot requires the price of each asset
                        asset.SetPrice(self.m_Data.m_Price(i));
                        % Set lot size to 20
                        asset.SetRoundLotSize(20);
                    end
                end
            end

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1d', self.m_InitPf, [], 10000000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Enable Roundlotting; do not allow odd lot clostout 
            self.m_Case.InitConstraints().EnableRoundLotting(false); 

            self.m_Case.InitUtility();
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_1e: Post Optimization Roundlotting
        % 
        % The sample code shows how to retrieve the roundlotted portfolio
        % post optimization. The resulting portfolio may not satisfy some of 
        % your optimization settings, such as asset bounds, maximum turnover 
        % and transaction costs, paring constraints, and factor-level 
        % constraints, etc. Post-optimization roundlotting may fail if 
        % roundlotting a trade would result in a change of sign of the asset 
        % position.
        %
        % The trade list is shown in this sample to illustrate the roundlotted
        % positions.
        %
        %
        function Tutorial_1e(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; 
            % Set up alpha            
            self.InitializeAlpha( '1e', 'Post optimization roundlotting', true );
            % Add cash
            self.m_InitPf.AddAsset('CASH', 1.0);

            % Set round lot info
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i), 'CASH')
                    asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                    if ~isempty(asset) 
                        % Round lot requires the price of each asset
                        asset.SetPrice(self.m_Data.m_Price(i));
                        % Set lot size to 1000
                        asset.SetRoundLotSize(1000);
                    end
                end
            end

            % Create a case object with trade universe
            portfolioBaseValue = 10000000;
            self.m_Case = self.m_WS.CreateCase('Case 1e', self.m_InitPf, self.m_TradeUniverse, portfolioBaseValue);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            %
            util = self.m_Case.InitUtility();
            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();

            % Retrieve trade list info from the optimal portfolio; 
            self.OutputTradeList(true);

            % Retrieve trade list info from the roundlotted portfolio
            self.OutputTradeList(false);
        end

        %% Tutorial_1f: Additional Statistics for Initial/Optimal Portfolio
        % 
        % The sample code shows how to retrieve the statistics for the 
        % initial and optimal portfolio. The available statistics are
        % return, common factor/specific risk, short rebate, and 
        % information ratio. The statistics can be retrieved for any
        % given portfolio as well.
        %
        %
        function Tutorial_1f(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize( '1f', 'Additional Statistics for Initial/Optimal Portfolio' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1f', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set Alpha
            self.SetAlpha();
            
            %
            util = self.m_Case.InitUtility();
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();

            % Output initial portfolio
            fprintf('Initial portfolio statistics:\n');
            fprintf('Return = %.4f\n', self.m_Solver.Evaluate(EEvalType.eRETURN) );
			factorRisk = self.m_Solver.Evaluate(EEvalType.eFACTOR_RISK);
			specificRisk = self.m_Solver.Evaluate(EEvalType.eSPECIFIC_RISK);
            fprintf('Common factor risk = %.4f\n', factorRisk );
            fprintf('Specific risk = %.4f\n', specificRisk );
			fprintf('Active risk = %.4f\n', sqrt(factorRisk*factorRisk + specificRisk*specificRisk) );
            fprintf('Short rebate = %.4f\n', self.m_Solver.Evaluate(EEvalType.eSHORT_REBATE) );
            fprintf('Information ratio = %.4f\n', self.m_Solver.Evaluate(EEvalType.eINFO_RATIO) );
            fprintf('\n'); 

            % Output optimal portfolio
            portfolio = self.m_Solver.GetPortfolioOutput().GetPortfolio();
            fprintf('Optimal portfolio statistics:\n');
            fprintf('Return = %.4f\n', self.m_Solver.Evaluate(EEvalType.eRETURN, portfolio) );
			factorRisk = self.m_Solver.Evaluate(EEvalType.eFACTOR_RISK, portfolio);
			specificRisk = self.m_Solver.Evaluate(EEvalType.eSPECIFIC_RISK, portfolio);
            fprintf('Common factor risk = %.4f\n', factorRisk);
            fprintf('Specific risk = %.4f\n',  specificRisk);
			fprintf('Active risk = %.4f\n', sqrt(factorRisk*factorRisk + specificRisk*specificRisk) );
            fprintf('Short rebate = %.4f\n', self.m_Solver.Evaluate(EEvalType.eSHORT_REBATE, portfolio) );
            fprintf('Information ratio = %.4f\n', self.m_Solver.Evaluate(EEvalType.eINFO_RATIO, portfolio) );
            fprintf('\n');
        end

        %% Tutorial_1g: Optimization Problem/Output Portfolio Type
        % 
        % The sample code shows how to tell if the optimization
        % problem is convex, and if the output portfolio is heuristic
        % or optimal.
        %
        %
        function Tutorial_1g(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize( '1g', 'Optimization Problem/Output Portfolio Type' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 1g', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            %
            util = self.m_Case.InitUtility();
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Set constraints
            constraints = self.m_Case.InitConstraints();
            % Set max # of assets to be 6
            paring = constraints.InitParingConstraints(); 
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMax(6);

            % Retrieve info
            if self.m_Case.IsConvex()
                convex = 'Yes';
            else 
                convex = 'No';
            end
            fprintf('Is type of optimization problem convex: %s\n', convex);

            % Retrieve paring constraints
            fprintf('max number of assets is: %d\n\n', ...
                paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_ASSETS).GetMax() );

            % Run optimization
            self.RunOptimize();

            % Retrieve optimization output
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output) 
                if output.IsHeuristic()
                    opt = 'heuristic';
                else
                    opt = 'optimal';
                end
                fprintf('The output portfolio is %s\n', opt);
                softBoundSlackIDs = output.GetSoftBoundSlackIDs();
                if softBoundSlackIDs.GetCount() > 0
                    fprintf('Soft bound violation found\n');
                end 
            end
        end
        
        %% Tutorial_2a: Composites and Linked Assets
        %
        % Composite assets are themselves portfolios.  Examples of composite assets 
        % include ETFs, Mutual Funds, or manager portfolios (funds of funds).  The 
        % risk exposure of the composite can be aggregated from its constituents. 
        % Unlike regular assets, the composite may have non-zero specific covariance
        % with other assets in the initial portfolio. This is due to the fact that 
        % the composite may also contain these assets.
        %
        % Linked assets share some underlying fundamentals and have non-zero specific 
        % covariance between them. In order to compute portfolio risk when composites/linked 
        % assets are part of the investment universe or included in the benchmark, we need to
        % link the composite portfolio with the composite asset, which will allow optimizer
        % to compute specific covariance between the composite assets/linked assets and the
        % other assets. 
        %
        % The Tutorial_2a sample code illustrates how to set up a composite asset and add it
        % to the trade universe: 
        %
        function Tutorial_2a(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('2a', 'Composite Asset');

            % Create a portfolio to represent the composite
            % add its constituents to the portfolio
            % in this example, all assets and equal weighted 
            pComposite = self.m_WS.CreatePortfolio('Composite');
            for i=1:self.m_Data.m_AssetNum
                pComposite.AddAsset(self.m_Data.m_ID(i), 1.0/self.m_Data.m_AssetNum);  
            end
            % Create a composite asset COMP1
            pAsset = self.m_WS.CreateAsset('COMP1', EAssetType.eCOMPOSITE);
            % Link the composite portfolio to the asset
            pAsset.SetCompositePort(pComposite);

            % add the composite to the trading universe
            self.m_TradeUniverse = self.m_WS.GetPortfolio('Trade Universe');	
            self.m_TradeUniverse.AddAsset('COMP1');

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 2a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            self.m_Case.InitUtility();
            
            % Run Optimization
            self.RunOptimize();
        end

        %% Tutorial_2b: Futures Contracts 
        %
        % Futures contracts, such as equity index futures, are settled daily and have
        % no market value.  However, they are risky assets that can be used to hedge 
        % portfolio risk (by selling the Futures contract) or increase risk.  Equity 
        % Futures can be used to gain equity market exposure with excess portfolio
        % cash, until the portfolio manager has decided which stocks to buy.
        %
        % Futures can be included in an optimization problem by indicating which assets 
        % in the list are futures and linking the composite portfolio to the futures asset.  
        % Since Futures do not have market value, they have no weight in the portfolio (where 
        % portfolio weight is defined as position market value/total portfolio market
        % value).  However, Futures do have an effective weight based on the contract
        % specifications (e.g.,  [$250 x S&P500 Index x Number of Contracts]/Portfolio 
        % Market Value). 
        %
        % Futures do not have currency risk, since they are settled daily and the 
        % replicating portfolio of cash and stock index in any currency has zero market
        % value. Since Futures do not have market value, they behave differently from 
        % regular assets in the optimizer.  Equity Futures contracts have the same 
        % factor exposures as the underlying spot index. 
        %
        % Tutorial_2b treats the newly created composite as a futures contract, which 
        % hedges portfolio risk.  
        %
        function Tutorial_2b(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('2b', 'Futures Contracts');

            % Create a portfolio to represent the composite
            % add its constituents to the portfolio
            % in this example, all assets and equal weighted 
            pComposite = self.m_WS.CreatePortfolio('Composite');
            for i=1:self.m_Data.m_AssetNum
                pComposite.AddAsset(self.m_Data.m_ID(i), 1.0/self.m_Data.m_AssetNum);  
            end
            % Create a composite asset COMP1 as FUTURES
            pAsset = self.m_WS.CreateAsset('COMP1', EAssetType.eCOMPOSITE_FUTURES);
            % Link the composite portfolio the asset
            pAsset.SetCompositePort(pComposite);

            % add the composite to the trading universe
            self.m_TradeUniverse = self.m_WS.GetPortfolio('Trade Universe');	
            self.m_TradeUniverse.AddAsset('COMP1');

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 2b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            self.m_Case.InitUtility();
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_2c: Cash Contributions, Cash Withdrawal, Invest All Cash
        %
        % Investment managers tend to have cash balances that increase prior to the next
        % portfolio rebalancing. These cash balances come from corporate actions (such as
        % dividends or spin-offs) as well as investor contributions.  Managers often want
        % to maintain a certain cash balance (in terms of portfolio weight) for market
        % timing or other reasons (e.g., anticipated redemptions that avoid liquidating
        % stocks, which in turn helps avoid transaction costs and potential taxes). 
        %
        % There are a couple of ways to model cash in the optimization problem:
        % - Add a cash or currency asset into the initial portfolio.
        % - Specify a cash contribution when initializing the CCase object.
        %
        % There should be only one cash asset in the initial portfolio. The currency asset
        % may be specified more than once and is used to model different currency holdings.
        % It is treated differently than a regular asset in determining the non-linear
        % transaction cost.
        %
        % To control the final cash position, a manager can manage the cash withdrawal 
        % level in the optimal portfolio by setting an asset range constraint in the cash
        % asset. Please refer to Tutorial_3a on how to set the asset range. To invest all
        % cash, it is simply set the lower bound and upper bound of the cash asset to 0.
        %
        % In Tutorial_2c example, we demonstrate how to add a 20% cash contribution to 
        % the initial portfolio:
        %
        function Tutorial_2c(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('2c', 'Cash contribution');

            % Create a case object. Set initial portfolio
            % 20% cash contribution
            self.m_Case = self.m_WS.CreateCase('Case 2c', self.m_InitPf, [], 100000, 0.2);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            self.m_Case.InitUtility();
            
            % Run optimization
            self.RunOptimize();
        end
        
    	%% Tutorial_3a: Asset Range Constraints/Penalty
        %
        % Asset range constraint is to limit the weight of some asset in the optimal portfolio.
        % You can set the upper and lower bound of the range. The default is from -OPT_INF to +OPT_INF.
        %
        % By setting the range of the assets, you can implement various transaction strategies. 
        % For instance, you can disallow selling an asset by setting the lower bound of the 
        % constraint to the initial weight.
        %
        % In Tutorial_3a, we want to limit the maximum weight of any asset in the optimal 
        % portfolio to be 30%. An asset-level penalty is set for USA11I1.
        %
        function Tutorial_3a(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('3a', 'Asset Range Constraints');

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set linear constraints
            linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            for j=1:self.m_Data.m_AssetNum
                info = linear.SetAssetRange(self.m_Data.m_ID(j));
                info.SetLowerBound(0.0);
                info.SetUpperBound(0.3);
                % Set asset penalty
                if strcmp(self.m_Data.m_ID(j),'USA11I1')  
                    % Set target to be 0.1; min = 0.0 and max = 0.3
                    info.SetPenalty(0.1, 0.0, 0.3);
                end
            end

            self.m_Case.InitUtility();

            % constraint retrieval
            self.PrintLowerAndUpperBounds(linear);
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_3a2: Relative Asset Range Constraints/Penalty
        %
        % Relative asset range constraint is to limit the weight of some asset in the optimal portfolio
        % relative to a reference portfolio. For example, you can set relative weight of +5% and -5%
        % relative to the benchmark weight.
        %
        % For asset penalty, the target, lower, and upper values are in absolute weights. For benchmark relative
        % penalty, you will need to shift the values by the benchmark weight.
        %
        % In Tutorial_3a2, we want to limit the weight of any asset except USA11I1 in the optimal 
        % portfolio to be +5% and -5% relative to the benchmark portfolio. 
        %
        % An asset-level penalty of +3% and -3% relative to benchmark weight is set for USA11I1 as absolute weights.
        %
        function Tutorial_3a2(self)
            import com.barra.optimizer.*;
	        self.Initialize( '3a2', 'Relative Asset Range Constraints' );
         
	        % Create a case object. Set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 3a2', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
	        self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

	        linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            for j=1:self.m_Data.m_AssetNum
 		        info = linear.SetAssetRange(self.m_Data.m_ID(j));
                if strcmp(self.m_Data.m_ID(j),'USA11I1')
			        % Set asset penalty, since benchmark weight is 0.169809
			        % min = 0.169809 - 0.03 = 0.139809
			        % max = 0.169809 + 0.03 = 0.199809
			        info.SetPenalty(0.169809, 0.139809, 0.199809);
                else 
			        % Set relative asset range constraint
                    info.SetLowerBound(-0.05, ERelativeMode.ePLUS);
                    info.SetUpperBound(0.05, ERelativeMode.ePLUS);
			        info.SetReference(self.m_BMPortfolio);
                end
            end

	        self.m_Case.InitUtility();

	        self.RunOptimize();
        end

        %% Tutorial_3b: Factor Range Constraints
        %
        % In this example, the initial portfolio exposure to Factor_1A is 0.0781, and 
        % we want to reduce the exposure to Factor_1A to 0.01.
        %
        function Tutorial_3b(self)
            fprintf('======== Running Tutorial 3b ========\n');
            fprintf('Factor Range Constraints\n');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % Create initial portfolio etc
            self.SetupPortfolios();

            pRiskModel = self.m_WS.GetRiskModel('GEM');
            % show existing exposure to FACTOR_1A
            exposure = pRiskModel.ComputePortExposure(self.m_InitPf, 'Factor_1A');
            fprintf('Initial portfolio exposure to Factor_1A = %.4f\n', exposure);

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(pRiskModel);

            % Set a linear constraint - factor range
            linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            info = linear.SetFactorRange('Factor_1A');
            info.SetLowerBound(0.00);
            info.SetUpperBound(0.01);

            self.m_Case.InitUtility();
            
            % Run optimization
            self.RunOptimize();

            % Retrieve optimization output
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                slackInfo = output.GetSlackInfo('Factor_1A');
                if ~isempty(slackInfo) 
                    fprintf('Optimal portfolio exposure to Factor_1A = %.4f\n', ...
                        slackInfo.GetSlackValue());

                    %Get the KKT term of the factor range constraint.
                    impact = slackInfo.GetKKTTerm(true);
                    self.PrintAttributeSet(impact, 'factor constraint KKT term');
                end
            end
        end

        %% Tutorial_3c: Beta Constraint
        %
        % The optimal portfolio in Tutorial_1c without any constraints has a Beta of .7181
        % to the benchmark, so we specify a range 0.9 to 1.0 for the Beta in this example 
        % to constrain the result.
        % 
        % This self-documenting sample code illustrates how to use the Barra Optimizer to 
        % restrict market exposure with a beta constraint. 
        %
        function Tutorial_3c(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('3c', 'Beta Constraint');

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3c', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set the beta constriant
            linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            info = linear.SetBetaConstraint();
            info.SetLowerBound(0.90);
            info.SetUpperBound(1.0);

            %
            util = self.m_Case.InitUtility();
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();

            % Get the slack information for beta constraint.
            output = self.m_Solver.GetPortfolioOutput();
            slackInfo = output.GetSlackInfo(info.GetID());

            % Get the KKT term of the balance constraint.
            impact = slackInfo.GetKKTTerm(true);
            self.PrintAttributeSet(impact, 'Beta constraint KKT term');
        end
        
        %% Tutorial_3c2: Multiple Beta Constraints
        %
        % A beta constraint relative to the benchmark portfolio in utility can be set by
        % calling SetBetaConstraint() which we limit to 0.9 in this case. To set the additional 
        % beta constraints, first compute asset betas for the universe, then pass the betas as 
        % coefficients for the general linear constraint. You can call CRiskModel::ComputePortBeta() 
        % to verify the optimal portfolio's beta to the different benchmarks.
        % 
        % This self-documenting sample code illustrates how to use the Barra Optimizer to 
        % restrict market exposure with multiple beta constraints. 
        %
        function Tutorial_3c2(self)
	        self.Initialize( '3c2', 'Multiple Beta Constraints' );
         
	        % Create a case object, set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 3c2', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);

	        rm = self.m_WS.GetRiskModel('GEM');
	        self.m_Case.SetPrimaryRiskModel(rm);

	        % Set the beta constraint relative to the benchmark in utility (m_pBMPortfolio)
	        linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
	        info = linear.SetBetaConstraint();
	        info.SetLowerBound(0.9);
	        info.SetUpperBound(0.9);

	        % Set the beta constraint relative to a second benchmark (self.m_pBM2Portfolio)
            assetBetaSet = rm.ComputePortAssetBeta(self.m_TradeUniverse, self.m_BM2Portfolio);
	        info2 = linear.AddGeneralConstraint(assetBetaSet);
	        info2.SetLowerBound(1.1);
	        info2.SetUpperBound(1.1);

	        util = self.m_Case.InitUtility();

	        % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

	        self.RunOptimize();

	        output = self.m_Solver.GetPortfolioOutput();
            beta = rm.ComputePortBeta(output.GetPortfolio(), self.m_BMPortfolio);
	        fprintf('Optimal portfolio''s beta relative to benchmark in utility = %.4f\n', beta);
            beta2 = rm.ComputePortBeta(output.GetPortfolio(), self.m_BM2Portfolio);
	        fprintf('Optimal portfolio''s beta relative to second benchmark = %.4f\n', beta2);
        end
        
        %% Tutorial_3d: User Attribute Constraints
        %
        % You can associate additional user attributes to each asset and constraint the 
        % optimal portfolio's exposure to these attributes. For instance, you can assign
        % Country, Currency, GICS Sector attribute for each asset and limit your bets on
        % their exposures. The group name and its attributes can be arbitrary and you
        % can use it to model a variety of custom attributes.
        %
        % This self-documenting sample code illustrates how to use the Barra Optimizer 
        % to restrict allocation of assets and total risk in a specific GICS sector, 
        % in this case, Information Technology.  
        %
        function Tutorial_3d(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('3d', 'User Attribute Constraints');

            % Set up group attribute
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    % Set GICS Sector attribute
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3d', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            constraints = self.m_Case.InitConstraints();
            % Set a constraint to GICS_SECTOR - Information Technology
            linear = constraints.InitLinearConstraints(); 
            info = linear.AddGroupConstraint('GICS_SECTOR', 'Information Technology');

            % Limit the exposure to 20%
            info.SetLowerBound(0.0);
            info.SetUpperBound(0.2);
            
            % Set the total risk constraint by group for GICS_SECTOR - Information Technology
            riskConstraint = constraints.InitRiskConstraints();
            risk = riskConstraint.AddTotalConstraintByGroup('GICS_SECTOR', 'Information Technology', []);
            risk.SetUpperBound(0.1);           

            self.m_Case.InitUtility();

            % constraint retrieval
            self.PrintLowerAndUpperBounds(linear); 

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_3e: Setting Relative Constraints
        %
        % In relative constraints, you can specify a positive or negative constant to
        % be added or multiplied to the reference portfolio's exposure to a factor, 
        % such as risk index, or industry.  The reference portfolio may be your 
        % benchmark, market portfolio, initial portfolio or any arbitrary portfolio.
        % This constant determines the range for the exposure to that factor in the 
        % optimal portfolios.  
        %
        % In the Tutorial_3e example, we want to set the factor exposure to Factor_1A
        % to be within +/- 0.10 of the reference portfolio and a maximum of 50% of
        % exposures to GICS Sector Information Technology relative to the reference
        % portfolio. 
        %
        function Tutorial_3e(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('3e', 'Relative Constraints');

            % Set up group attribute
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    % Set GICS Sector attribute
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3e', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set a constraint to GICS_SECTOR - Information Technology
            linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            info1 = linear.AddGroupConstraint('GICS_SECTOR', 'Information Technology');

            % limit the exposure to 50% of the reference portfolio
            info1.SetReference(self.m_BMPortfolio);
            info1.SetLowerBound(0.0, ERelativeMode.eMULTIPLE);
            info1.SetUpperBound(0.5, ERelativeMode.eMULTIPLE);

            info2 = linear.SetFactorRange('Factor_1A');

            % limit the Factor_1A exposure to +/- 0.01 of the reference portfolio
            info2.SetReference(self.m_BMPortfolio);
            info2.SetLowerBound(-0.01, ERelativeMode.ePLUS);
            info2.SetUpperBound(0.01, ERelativeMode.ePLUS);

            self.m_Case.InitUtility();

            % Constraint retrieval
            self.PrintLowerAndUpperBounds(linear);
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_3f: Setting Transaction Type
        %
        % There are a number of transaction types that you can specify in the
        % CLinearConstraints object: Allow All, Buy None, Sell None, Short None, Buy
        % from Universe, Sell None and Buy from Universe, Buy/Short from Universe, 
        % Disallow Buy/Short, Disallow Sell/Short Cover, Buy/Short from Universe and
        % No Sell/Short Cover. 
        %
        % They are basically different transaction strategies in the optimization 
        % problem, and these strategies can be replicated using Asset Range 
        % Constraints.  The transaction type is a more convenient way to set up these
        % strategies.  You can refer to the Reference Guide for the details of each
        % strategy. See Section of ETranxType.
        %
        % The Tutorial_3f sample code shows how to buy from a universe without selling 
        % any existing positions:
        %
        function Tutorial_3f(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('3f', 'Transaction Type');

            % Create a case object. Set initial portfolio and trade universe
            % Contribute 30% cash for buying additional securities
            self.m_Case = self.m_WS.CreateCase('Case 3f', self.m_InitPf, self.m_TradeUniverse, 100000, 0.3);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set Transaction Type to Sell None/Buy From Universe
            linear = self.m_Case.InitConstraints().InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSELL_NONE_BUY_FROM_UNIV);

            self.m_Case.InitUtility();
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_3g: Crossover Option
        %
        % A crossover trade makes an asset change from long position to short position, 
        % or vice versa. The following sample shows how to disable the crossover option.
        % If crossover option is disabled, an asset is not allowed to change position 
        % from long to short or from short to long. Crossover is enabled by default.
        %
        %
        function Tutorial_3g(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha( '3g', 'Crossover Option' , true);
            % Add cash
            self.m_InitPf.AddAsset('CASH', 1);

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3g', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set linear constraints
            constraints = self.m_Case.InitConstraints();
            linear = constraints.InitLinearConstraints();
            % Set transaction type
            linear.SetTransactionType(ETranxType.eBUY_SHORT_FROM_UNIV);
            % Disable crossover
            linear.EnableCrossovers(false);
            % Set an asset range
            info = linear.SetAssetRange('USA11I1');
            info.SetLowerBound(-1.0);
            info.SetUpperBound(1.0);

            self.m_Case.InitUtility();
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_3h: Total Active Weight Constraint
        %
        % You can set a constraint on the total absolute value of active weights on the optimal portfolio or for a group
        % of assets. To set total active weight by group, you will need to first set the asset
        % group attribute, then set the constraint by calling AddTotalActiveWeightConstraintByGroup().
        %
        % Tutorial_3h illustrates how to constrain the sum of active weights in the optimal portfolio to less than 1%.
        % The reference portfolio used to calculate active weights is the m_pBMPortfolio object.
        %
        function Tutorial_3h(self)
            import com.barra.optimizer.*;
	        self.InitializeAlpha( '3h', 'Total Active Weight Constraint' , true);

	        % Create a case object. Set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 3h', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
	        self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

	        constraints = self.m_Case.InitConstraints();
	        info = constraints.SetTotalActiveWeightConstraint();
	        info.SetLowerBound(0);
	        info.SetUpperBound(0.01);
	        info.SetReference(self.m_BMPortfolio);
        	
	        self.m_Case.InitUtility();

	        self.RunOptimize();

	        sumActiveWeight = 0.0 ;
	        output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
		        optimalPort = output.GetPortfolio();
		        idSet = optimalPort.GetAssetIDSet();
			    assetID = idSet.GetFirst();
                for i=1:idSet.GetCount()
			        benchWeight = self.m_BMPortfolio.GetAssetWeight(assetID);
			        if benchWeight ~= barraopt.getOPT_NAN()
				        sumActiveWeight = sumActiveWeight + abs(benchWeight - optimalPort.GetAssetWeight(assetID));
                    end
                    assetID = idSet.GetNext();
                end
            end
            fprintf('Total active weight = %.4f\n', sumActiveWeight);
        end

        %% Tutorial_3i: Long-Short Optimization: Dollar Neutral Strategy
        %
        % Long-Short strategies are common among portfolio managers. One particular use case is the dollar-neutral 
        % strategy, in which the long and short sides are equally invested such that the net portfolio value is 0. 
        % The optimal portfolio is said to be dollar neutral.
        %
        % This tutorial demonstrates how dollar-neutral portfolio managers can set up their optimization problem
        % if the cash asset is not managed by them. Barra Open Optimizer provides the flexibility to disable the 
        % balance constraint and allow the cash asset to be optional.
        %
        % Since the portfolio balance constraint is enabled by default,  you need to  first disable the constraint by
        % calling EnablePortfolioBalanceConstraint(false). Then, add a general linear constraint to replace the 
        % Balance Constraint.
        % In this case, the general linear constraint would be the sum of all non-cash holdings = 0.
        %
        % Tutorial_3i illustrates how to set up the dollar-neutral strategy by replacing the balance constraint with 
        % a customized general linear constraint. 
        %
        function Tutorial_3i(self)
            self.InitializeAlpha( '3i', 'Dollar Neutral Strategy', true);

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3i', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            constraints = self.m_Case.InitConstraints();
            linear = constraints.InitLinearConstraints();
            % Disable the default portfolio balance constraint
            linear.EnablePortfolioBalanceConstraint(false);
            % Set equal weights
            coeffs = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmp(self.m_Data.m_ID(i),'CASH')
                    coeffs.Set( self.m_Data.m_ID(i), 1.0 );
                end
            end
            info = linear.AddGeneralConstraint(coeffs);
            % Set the upper & lower bounds of the general linear constraint
            info.SetLowerBound(0);
            info.SetUpperBound(0);

            self.m_Case.InitUtility();

            self.RunOptimize();

            sumWeight = 0.0;
            pOutput = self.m_Solver.GetPortfolioOutput();
            if ~isempty(pOutput)
                optimalPort = pOutput.GetPortfolio();
                idSet = optimalPort.GetAssetIDSet();
                assetID = idSet.GetFirst();
                for i=1:idSet.GetCount()
                    if ~strcmp(assetID,'CASH')
                        sumWeight = sumWeight + optimalPort.GetAssetWeight(assetID);
                    end
                    assetID = idSet.GetNext();
                end
                fprintf('Sum of all weights = %.4f\n', sumWeight );
            end
        end
        
        %% Tutorial_3j: Asset free range linear penalty
        %
        % Asset penalty functions are used to tilt portfolios toward user-specified targets on asset weights. Free range linear penalty is one type of
        % penalty function that allows user to specify an upper and lower bound of the target, where the penalty will be zero if the slack variable
        % falls within the free range. User can also specify the penalty rate for each side should the slack variable falls outside of the free range.
        %
        % Tutorial_3j illustrates how to set free range linear penalty that penalizes the objective function when a non-cash asset weight is outside -10% to 10%.
        % 
        function Tutorial_3j(self)
            self.Initialize( '3j', 'Asset Free Range Linear Penalty' );
 
            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 3j', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            linear = self.m_Case.InitConstraints().InitLinearConstraints();
            for j=1:self.m_Data.m_AssetNum
                % Set asset free range penalty
                if ~strcmp(self.m_Data.m_ID(j),'CASH')
                    info = linear.SetAssetRange(self.m_Data.m_ID(j));
                    % Set free range to -0.1 to 0.1, with downside slope = -0.01, upside slope = 0.01
                    info.SetFreeRangeLinearPenalty(-0.01, 0.01, -0.10, 0.10);
                end
            end
            self.m_Case.InitUtility();
            self.RunOptimize()
        end
        
        %% Tutorial_4a: Maximum Number of Assets and estimated utility upper bound
        %
        % To set a maximum number of assets in the optimal portfolio, you can set the
        % limit with the CParingConstraints class. For long-short optimizations, the 
        % limit applies to both the long side and the short side. This constraint is 
        % not available for Risk Target or Expected Return Target portfolio optimizations.
        %
        % Tutorial_4a illustrates how to replicate a benchmark portfolio (minimize the 
        % tracking error) with less number of assets. In this case, we set the maximum 
        % number of assets to be 6.
        % This tutorial also illustrates how to estimate utility upperbound. 
        function Tutorial_4a(self)
            import com.barra.optimizer.*;
            fprintf('======== Running Tutorial 4a ========\n');
            fprintf('Max # of assets and estimated utility upper bound\n');
            self.SetupDumpFile ('4a');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % Create an initial holding portfolio 
            % initial portfolio with cash only
            % replicate the benchmark risk with max # of assets
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');
            self.m_InitPf.AddAsset('CASH', 1.0);

            self.m_TradeUniverse = self.m_WS.CreatePortfolio('Trade Universe');	
            self.m_BMPortfolio = self.m_WS.CreatePortfolio('Benchmark');	
            for i=1:self.m_Data.m_AssetNum
                if ~strcmp(self.m_Data.m_ID(i),'CASH')
                        self.m_TradeUniverse.AddAsset(self.m_Data.m_ID(i));
                        self.m_BMPortfolio.AddAsset(self.m_Data.m_ID(i), 0.1);
                end
            end

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 4a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            constraints = self.m_Case.InitConstraints();

            % Invest all cash
            linear = constraints.InitLinearConstraints(); 
            info = linear.SetAssetRange('CASH');
            info.SetLowerBound(0.0);
            info.SetUpperBound(0.0);

            % Set max # of assets to be 6
            paring = constraints.InitParingConstraints(); 
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMax(6);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization and report utility upperbound
            self.RunOptimizeReportUtilUB();
        end

        %% Tutorial_4b: Holding and Transaction Size Thresholds
        %
        % The minimum holding level is measured as a percentage, expressed in decimals,
        % of the base value (in this example, 0.04 is 4%).  This feature ensures 
        % that the optimizer will not recommend trades too small to be meaningful in 
        % your analysis.
        %
        % Minimum transaction size is measured as a percentage of the base value
        % (in this example, 0.02 is 2%). 
        %
        function Tutorial_4b(self)
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('4b', 'Min Holding Level and Transaction Size');

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 4b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set constraints
            constraints = self.m_Case.InitConstraints();
            % Set minimum holding threshold; both for long and short positions
            % in this example 4%
            paring = constraints.InitParingConstraints(); 
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_LONG, 0.04);
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_SHORT, 0.04);
            paring.EnableGrandfatherRule();	        % Enable grandfather rule
            
            % Set minimum trade size; both for long side and short side,
            % in this example 2%
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_LONG, 0.02);
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_SHORT, 0.02);

            self.m_Case.InitUtility();
            
            % Run optimzation
            self.RunOptimize();
        end

        %% Tutorial_4c: Soft Turnover Constraint
        %
        % Maximum turnover is specified in percentage, expressed in decimals, (in this
        % example, 0.2 is 20.00%). This considers all transactions, including buys, 
        % sells, and short sells.  Covered buys are measured as a percentage of initial
        % portfolio value adjusted for any cash infusions or withdrawals you have 
        % specified.  If you select Use Base Value, turnover is measured as a 
        % percentage of the Base Value.  
        %
        function Tutorial_4c(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('4c', 'Soft Turnover Constraint');

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 4c', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set constraints
            constraints = self.m_Case.InitConstraints();
            % Set turnover constraint
            turnover = constraints.InitTurnoverConstraints(); 
            info = turnover.SetNetConstraint();
            info.SetSoft(true);
            info.SetUpperBound(0.2);

            self.m_Case.InitUtility();
            % Run optimization
            self.RunOptimize();
        end
	
        %% Tutorial_4d: Buy Side Turnover Constraint
        %
        % The following tutorial limits the maximum turnover for the buy side.
        %
        %
        function Tutorial_4d(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('4d', 'Limit Buy Side Turnover Constraint');

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 4d', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set constraints
            constraints = self.m_Case.InitConstraints();
            % Set buy side turnover constraint
            turnover = constraints.InitTurnoverConstraints();
            info = turnover.SetBuySideConstraint();
            info.SetUpperBound(0.1);

            self.m_Case.InitUtility();
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_4e: Paring by Group
        %
        % To set paring constraint by group, you will need to first set the asset
        % group attribute, then set the limit with the CParingConstraints class. 
        %
        % Tutorial_4e illustrates how to set a maximum number of assets for GICS_SECTOR/
        % Information Technology to one asset. It also sets a holding threshold constraint for
        % the asset in GICS_SECTOR/Information Technology to be at least 0.2.
        %
        function Tutorial_4e(self)
            import com.barra.optimizer.*;
            self.Initialize( '4e', 'Paring by group' );

            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
			        asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

	        % Create a case object. Set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 4e', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
	        self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

	        constraints = self.m_Case.InitConstraints();

	        % Set max # of asset in GICS Sector/Information Technology to 1
	        paring = constraints.InitParingConstraints();
            range = paring.AddAssetTradeParingByGroup(EAssetTradeParingType.eNUM_ASSETS, 'GICS_SECTOR', 'Information Technology');
	        range.SetMax(1);

	        % Set minimum holding threshold for GICS Sector/Information Technology to 0.2
            paring.AddLevelParingByGroup(ELevelParingType.eMIN_HOLDING_LONG, 'GICS_SECTOR', 'Information Technology', 0.2);

	        util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

	        self.RunOptimize();
        end
 
        %% Tutorial_4f: Net turnover limit by group
        %
        % To set turnover constraint by group, you will need to first set the asset
        % group attribute, then set the limit with the CTurnoverConstraints class. 
        %
        % Tutorial_4f illustrates how to limit turnover to 10% for assets having the Information Technology attribute
        % in the GICS_SECTOR group, while limiting overall portfolio turnover to 30%.
        %
        function Tutorial_4f(self)
	        self.Initialize( '4f', 'Net turnover by group' );

	        % Set up group attribute
	        for i=1:self.m_Data.m_AssetNum
		        asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
		        if ~isempty(asset)
			        % Set GICS Sector attribute
			        asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end
         
	        % Create a case object. Set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 4f', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
	        self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));


	        % Set the net turnover by group for GICS_SECTOR - Information Technology
	        toCons = self.m_Case.InitConstraints().InitTurnoverConstraints();
	        infoGroup = toCons.AddNetConstraintByGroup('GICS_SECTOR', 'Information Technology');
	        infoGroup.SetUpperBound(0.03);

	        % Set the overall portfolio turnover
	        info = toCons.SetNetConstraint();
	        info.SetUpperBound(0.3);

            self.m_Case.InitUtility();

	        self.RunOptimize();
        end
        
        %% Tutorial_4g: Paring penalty
        % 
        % Paring penalty is used to tell the optimizer make a tradeoff between "violating a paring constraint" 
        % and "getting a better utility".  Violation of of the paring constraints would generate disutilty at the 
        % rate specified by the user.
        %
        % Tutorial_4g illustrates how to set paring penalty
        %
        function Tutorial_4g(self)
            import com.barra.optimizer.*;
            self.Initialize( '4g', 'Paring penalty' );

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 4g', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            constraints = self.m_Case.InitConstraints();

            paring = constraints.InitParingConstraints(); 
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_TRADES).SetMax(2);		% Set maximum number of trades
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMin(5);		% Set minimum number of assets

            % Set paring penalty. Violation of the "max# trades=2" constraint would generate 0.005 disutility per extra trade.
            paring.SetPenaltyPerExtraTrade(0.005);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            self.RunOptimize();
        end
   
        %% Tutorial_5a: Piecewise Linear Transaction Costs
        %
        % A simple way to model transactions costs is a flat-fee-per-share (the 
        % commission component) plus the percentage that accounts for trade 
        % volume (e.g., the bid spread for small, illiquid stocks).  These can be set
        % as default market values and then overridden at the asset level by 
        % associating transactions costs with individual securities.  This 
        % unfortunately does not capture the non-linear cost of market impact
        % (trade size related to trading volume).
        %
        % The piecewise linear transactions cost penalty are set in the CAsset class,
        % as shown in this simple example using 2 cents per share and 20 basis
        % points for the first 10,000 dollar buy cost. For more than 10,000 dollar or
        % short selling, the cost is 2 cents per share and 30 basis points.
        %
        % In this example, the 2 cent per share transaction commission is translated
        % into a relative weight via the share's price. The simple-linear market impact
        % cost of 20 basis points is already in relative-weight terms.  
        %
        % In the case of Asset 1 (USA11I1), its share price is 23.99 USD, so the $.02 
        % per share cost becomes .02/23.99= .000833681, and added to the 20 basis 
        % points cost .002 + .000833681= .002833681. 
        %
        % The short sell cost is higher at 30 basis points, so that becomes 
        % 0.003 +  .00833681= .003833681, in terms of relative weight. 
        %
        % The breakpoints and slopes can be used to specify a piecewise linear cost 
        % function that can account for increasing market impact based on trade size
        % (approximating a curve by piecewise linear segments).  In this simple 
        % example, the four (4) breakpoints have a center at the initial weight of 
        % the asset in the portfolio, with leftmost breakpoint at negative infinity
        % and the rightmost breakpoint at positive infinity. The breakpoints on the
        % X-axis represent relative portfolio weights, while the Y-axis slopes 
        % represent the relative cost of trading that asset. 
        %
        % If you have a high-value portfolio to manage, and a number of smallcap stocks
        % with very high alphas, the optimizer may suggest that you execute a trade 
        % larger than the average daily trading volume for that stock, and therefore
        % have a very large market impact.  Specifying piecewise linear transactions 
        % cost penalties can trim back these suggested trade sizes to more realistic 
        % levels.
        %
        function Tutorial_5a(self)
            fprintf('======== Running Tutorial 5a ========\n');
            fprintf('Piecewise Linear Transaction Costs\n');
            self.SetupDumpFile ('5a');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % Create an initial holding portfolio with the hard coded data
            % portfolio with no Cash
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');
            self.m_InitPf.AddAsset('USA11I1', 0.3);
            self.m_InitPf.AddAsset('USA13Y1', 0.7);

            % Set the transaction cost
            asset = self.m_WS.GetAsset('USA11I1');
            if ~isempty(asset)
                % the price is 23.99

                % the 1st 10,000, 
				% the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.002833681, 10000.0);

                % from 10,000 to +OPT_INF, 
				% the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.003833681);

				% Sell cost is 30 basis + $0.02 per share =  0.003 + 0.02/23.99
                asset.AddPWLinearSellCost(0.003833681);
            end

            asset = self.m_WS.GetAsset('USA13Y1');
            if ~isempty(asset)
                % the price is 34.19

				% the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
                asset.AddPWLinearBuyCost(0.00287745);

				% Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
                asset.AddPWLinearSellCost(0.00387745);
            end

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 5a', self.m_InitPf, [], 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Set transcaction cost term
            util = self.m_Case.InitUtility();
            util.SetTranxCostTerm(1.0);

            % Run Optimization
            self.RunOptimize();
        end

        %% Tutorial_5b: Nonlinear Transaction Costs
        %
        % Tutorial_5b illustrates how to set up the coefficient c, p and q for 
        % nonlinear transaction costs
        %
        function Tutorial_5b(self)
        
            fprintf('======== Running Tutorial 5b ========\n');
            fprintf('Nonlinear Transaction Costs\n');
            self.SetupDumpFile ('5b');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % Create an initial holding portfolio with the hard coded data
            % portfolio with no Cash
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');
            self.m_InitPf.AddAsset('USA11I1', 0.3);
            self.m_InitPf.AddAsset('USA13Y1', 0.7);

            % Asset nonlinear transaction cost
            % c = 0.00005, p = 1.1, and q = 0.01
            self.m_WS.GetAsset('USA11I1').SetNonLinearTranxCost(0.00005, 1.1, 0.01);

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 5b', self.m_InitPf, [], 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set nonlinear transaction cost
            % c = 0.00001, p = 1.1, and q = 0.01
            self.m_Case.SetNonLinearTranxCost(0.00001, 1.1, 0.01);

            % Set transaction cost term
            util = self.m_Case.InitUtility();
            util.SetTranxCostTerm(1.0);
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_5c: Transaction Cost Constraints
        %
        % You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
        %
        function Tutorial_5c(self)
            fprintf('======== Running Tutorial 5c ========\n');
            fprintf('Transaction Cost Constraint\n');
            self.SetupDumpFile ('5c');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % Create an initial portfolio with no Cash
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');
            self.m_InitPf.AddAsset('USA11I1', 0.3);
            self.m_InitPf.AddAsset('USA13Y1', 0.7);

            % Set the transaction cost
            asset = self.m_WS.GetAsset('USA11I1');
            if ~isempty(asset)
                % the price is 23.99

                % the 1st 10,000, 
				% the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.002833681, 10000.0);

                % from 10,000 to +OPT_INF, 
				% the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.003833681);

				% Sell cost is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearSellCost(0.003833681);
            end

            asset = self.m_WS.GetAsset('USA13Y1');
            if ~isempty(asset)
                % the price is 34.19

                % the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
                asset.AddPWLinearBuyCost(0.00287745);

                % Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
                asset.AddPWLinearSellCost(0.00387745);
            end

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 5c', self.m_InitPf, [], 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set transaction cost constraint
            constraints = self.m_Case.InitConstraints();

            info = constraints.SetTransactionCostConstraint();
            info.SetUpperBound(0.0005);

            % Set transaction cost term
            util = self.m_Case.InitUtility();
            util.SetTranxCostTerm(1.0);

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_5d: Fixed Transaction Costs
        %
        % Tutorial_5d illustrates how to set up fixed transaction costs
        %
        function Tutorial_5d(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha( '5d', 'Fixed Transaction Costs', true );

            % Set fixed transaction costs for non-cash assets
            for i=1:self.m_Data.m_AssetNum 
                if ~strcmpi(self.m_Data.m_ID(i),'CASH') 
                    asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                    if ~isempty(asset) 
                        asset.SetFixedBuyCost( 0.02 );
                        asset.SetFixedSellCost( 0.03 );
                    end
                end
            end

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 5d', self.m_InitPf, [], 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set utility
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(10.0);		% default value of the multiplier is 1.
            util.SetTranxCostTerm(1.0);
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_5e: load asset-level data, including fixed transaction costs from csv file
        %
        % Tutorial_5e illustrates how to set up  asset-level data including fixed transaction costs and group association from csv file
        %
        function Tutorial_5e(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set alpha
            self.InitializeAlpha( '5e', 'Asset-Level Data incl. Fixed Transaction Costs', true );

            % Set fixed transaction costs for non-cash assets
            % load asset-level group name & attributes 
            status = self.m_WS.LoadAssetData(strcat(self.m_Data.m_Datapath, 'asset_data.csv'));
            if status.GetStatusCode() ~= EStatusCode.eOK 
                fprintf('Error loading transaction cost data: %s\n', char(status.GetMessage()));
                fprintf('%s\n', char(status.GetAdditionalInfo()));
            end

            % Create a case object. Set initial portfolio & trade universe
            self.m_Case = self.m_WS.CreateCase('Case 5e', self.m_InitPf, self.m_TradeUniverse, 100000.0, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            constraints = self.m_Case.InitConstraints();

            % Set a linear constraint to GICS_SECTOR - Information Technology
            linear = constraints.InitLinearConstraints();
            info = linear.AddGroupConstraint('GICS_SECTOR', 'Information Technology');
            % limit the exposure to between 10%-50%
            info.SetLowerBound(0.1);
            info.SetUpperBound(0.5);

            % Set a hedge constraint to GICS_SECTOR - Information Technology
            hedgeConstr = constraints.InitHedgeConstraints();
            wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint('GICS_SECTOR', 'Information Technology');
            wtlGrpConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetSoft(true);

            % Set max # of asset in GICS Sector/Information Technology to 1
            paring = constraints.InitParingConstraints();
            range = paring.AddAssetTradeParingByGroup(EAssetTradeParingType.eNUM_ASSETS, 'GICS_SECTOR', 'Information Technology');
            range.SetMax(1);
            % Set minimum holding threshold for GICS Sector/Information Technology to 0.2
            paring.AddLevelParingByGroup(ELevelParingType.eMIN_HOLDING_LONG, 'GICS_SECTOR', 'Information Technology', 0.2);

            % Set the net turnover by group for GICS_SECTOR - Information Technology
            toCons = constraints.InitTurnoverConstraints();
            infoGroup = toCons.AddNetConstraintByGroup('GICS_SECTOR', 'Information Technology');
            infoGroup.SetUpperBound(0.03); 
            
            % Set utility
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(10.0);		% default value of the multiplier is 1.
            util.SetTranxCostTerm(1.0);
            
            % Run optimization
            self.RunOptimize();
        end
        
        %% Tutorial_5f: Fixed Holding Costs
        %
        % Tutorial_5f illustrates how to set up fixed holding costs
        %
        function Tutorial_5f(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.InitializeAlpha( '5f', 'Fixed Holding Costs', true );

            % Set fixed transaction costs for non-cash assets
            for i=1:self.m_Data.m_AssetNum 
                if ~strcmpi(self.m_Data.m_ID(i),'CASH') 
                    asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                    if ~isempty(asset) 
                        asset.SetUpSideFixedHoldingCost(0.02);
                        asset.SetDownSideFixedHoldingCost(0.03);
                    end
                end
            end

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 5f', self.m_InitPf, [], 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set utility - alpha term
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(10.0);		% default value of the multiplier is 1.
			util.SetFixedHoldingCostTerm(1.5); % default value of the multiplier is 1.

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_5g: General Piecewise Linear Constraint
        %
        % Tutorial_5g illustrates how to set up general piecewise linear Constraints
        %
        function Tutorial_5g(self)
	    self.InitializeAlpha( '5g', 'General Piecewise Linear Constraint', true );

	    % Create a case object. Set initial portfolio
	    self.m_Case = self.m_WS.CreateCase('Case 5g', self.m_InitPf, [], 100000, 0.0);
	    self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

	    util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

	    constraints = self.m_Case.InitConstraints();
	    generalPWLICon = constraints.AddGeneralPWLinearConstraint();
    
            generalPWLICon.SetStartingPoint( self.m_Data.m_ID(1), self.m_Data.m_BMWeight(1) );
            generalPWLICon.AddDownSideSlope( self.m_Data.m_ID(1), -0.01, 0.05 );
            generalPWLICon.AddDownSideSlope( self.m_Data.m_ID(1), -0.03 );
            generalPWLICon.AddUpSideSlope( self.m_Data.m_ID(1), 0.02, 0.04 );
            generalPWLICon.AddUpSideSlope( self.m_Data.m_ID(1), 0.03 );

	    conInfo = generalPWLICon.SetConstraint();
	    conInfo.SetLowerBound(0);
	    conInfo.SetUpperBound(0.25);

	    self.RunOptimize();
        end

        %% Tutorial_6a: Penalty
        %
        % Penalties, like constraints, let you customize optimization by tilting 
        % toward certain portfolio characteristics.
        % 
        % This self-documenting sample code illustrates how to use the Barra Optimizer
        % to set up a penalty function that helps restrict market exposure.
        %
        function Tutorial_6a(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc; no alpha
            self.Initialize('6a', 'Penalty');

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 6a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set linear constraints
            linear = self.m_Case.InitConstraints().InitLinearConstraints(); 
            info = linear.SetBetaConstraint();
            info.SetLowerBound(-1 * barraopt.getOPT_INF());
            info.SetUpperBound(barraopt.getOPT_INF());

            % Set target to be 0.95
            % min = 0.80 and max = 1.2
            info.SetPenalty(0.95, 0.80, 1.2);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_7a: Risk Budgeting
        %
        % In the following example, we will constrain the amount of risk coming
        % from common factor risk.  
        %
        %
        function Tutorial_7a(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set alpha
            self.InitializeAlpha( '7a', 'Risk Budgeting', true );

            % Create a case object, set initial portfolio and trade universe
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case = self.m_WS.CreateCase('Case 7a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(riskModel);

            self.m_Case.InitUtility();

            % Run optimization
            self.RunOptimize();

            pfOut = self.m_Solver.GetPortfolioOutput();
            if ~isempty(pfOut) 
                fprintf( 'Specific Risk(%%) = %.4f\n', pfOut.GetSpecificRisk() );
                fprintf( 'Factor Risk(%%) = %.4f\n', pfOut.GetFactorRisk() );

                riskConstraint = self.m_Case.InitConstraints().InitRiskConstraints();

                fprintf( '\nAdd a risk constraint: FactorRisk<=12%%' );
                % add a risk constraint
                info = riskConstraint.AddPLFactorConstraint();
                info.SetUpperBound(0.12);

                fid = self.m_WS.CreateIDSet();
				% add four factors
				fid.Add('Factor_1B');
				fid.Add('Factor_1C');
				fid.Add('Factor_1D');
				fid.Add('Factor_1E');
				
				fprintf( '\nAdd a risk constraint: Factor_1B-1E<=1.9%%\n\n' );
                % constraint Factor_1B-1E <=1.9%%
                info2 = riskConstraint.AddFactorConstraint([], fid);
                info2.SetUpperBound(0.019);
                
                % rerun optimization usingthe existing solver without recreating a new solver
                self.RunOptimizeReuseSolver();     

                pfOut2 = self.m_Solver.GetPortfolioOutput();
                if ~isempty(pfOut2)
                    fprintf( 'Specific Risk(%%) = %.4f\n', pfOut2.GetSpecificRisk() );
                    fprintf( 'Factor Risk(%%) = %.4f\n', pfOut2.GetFactorRisk() );
                end                
            end
        end

        %% Tutorial_7b: Dual Benchmarks
        %
        % Asset managers often administer separate accounts against one model 
        % portfolio.  For example, an asset manager with 300 separate institutional 
        % accounts for the same product, such as Large Cap Growth, will typically 
        % rebalance the model portfolio on a periodic basis (e.g., monthly).  The model
        % becomes the target portfolio that all 300 accounts should match perfectly, in
        % the absence of any unique constraints (e.g., no tobacco stocks).  The asset
        % manager will report performance to his or her institutional clients using the
        % appropriate external benchmark (e.g., Russell 1000 Growth, or S&P 500 Growth).
        % The model portfolio is effectively an internal benchmark. 
        %
        % The dual benchmark feature in the Barra Optimizer enables portfolio managers
        % to maximize utility using one benchmark, while constraining active risk 
        % against a different benchmark.  The optimal portfolio is the one that 
        % maximizes utility subject to the active risk constraint on the secondary
        % benchmark.
        %
        % Tutorial_7b is modified from Tutoral_1c, which minimizes the active risk 
        % relative to the benchmark portfolio. In this example, we set a risk 
        % constraint relative to the model portfolio with an active risk upper bound of
        % 300 basis points.
        %
        % This self-documenting sample code illustrates how to perform risk-constrained
        % optimization with dual benchmarks: 
        %
        function Tutorial_7b(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc, no alpha   
            self.Initialize('7b', 'Risk Budgeting - Dual Benchmark');

            % Create a case object, set initial portfolio and trade universe
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case = self.m_WS.CreateCase('Case 7b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(riskModel);

            % add a risk constraint
            riskConstraint = self.m_Case.InitConstraints().InitRiskConstraints();

            info = riskConstraint.AddPLTotalConstraint(true, self.m_BM2Portfolio);
            info.SetID('RiskConstraint');
            info.SetUpperBound(0.16);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();

            % Retrieve slack info
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                slackInfo = output.GetSlackInfo('RiskConstraint');
                if ~isempty(slackInfo)
                    fprintf('Risk Constraint Slack = %.4f\n', slackInfo.GetSlackValue());
                    fprintf('\n');
                end
            end
        end

		%% Tutorial_7c Risk Budgeting using additive definition
        %
        % In the following example, we will constrain the amount of risk coming from
        % subsets of assets/factors using additive risk definition
        %
        %
        function Tutorial_7c(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set alpha
            self.InitializeAlpha( '7c', 'Additive Risk Definition', true );

            % Create a case object, set initial portfolio and trade universe
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case = self.m_WS.CreateCase('Case 7c', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(riskModel);

            self.m_Case.InitUtility();

            % Run optimization
            self.RunOptimize();

            pfOut = self.m_Solver.GetPortfolioOutput();
            if ~isempty(pfOut) 
                fprintf( 'Specific Risk(%%) = %.4f\n', pfOut.GetSpecificRisk() );
                fprintf( 'Factor Risk(%%) = %.4f\n', pfOut.GetFactorRisk() );

				% subset of assets
		        aid = self.m_WS.CreateIDSet();
		        aid.Add('USA13Y1');
		        aid.Add('USA1TY1');

                % subset of factors (7|8|9*)
                fid = self.m_WS.CreateIDSet();
				for i=49:self.m_Data.m_FactorNum 
					fid.Add(self.m_Data.m_Factor(i));               
				end

		        fprintf('Risk from USA13Y1 & 1TY1 = %.4f\n', self.m_Solver.EvaluateRisk(pfOut.GetPortfolio(), ERiskType.eTOTALRISK, [], aid, [], true, true));
                fprintf('Risk from Factor_7|8|9* = %.4f\n', self.m_Solver.EvaluateRisk(pfOut.GetPortfolio(), ERiskType.eFACTORRISK, [], [], fid, true, true));

				riskConstraint = self.m_Case.InitConstraints().InitRiskConstraints();
									
				fprintf('\nAdd a risk constraint(additive def): from USA13Y1 & 1TY1 <=1%%');
                % add a risk constraint
 		        info = riskConstraint.AddTotalConstraint( aid, [], true, [], false, false, false, true);
		        info.SetUpperBound(0.01);
				
				fprintf('\nAdd a risk constraint(additive def): from Factor_7|8|9* <=1.9%%\n\n' );
		        info2 = riskConstraint.AddFactorConstraint( [], fid, true, [], false, false, false, true);
		        info2.SetUpperBound(0.019);
				                
                % rerun optimization usingthe existing solver without recreating a new solver
                self.RunOptimizeReuseSolver();     

                pfOut2 = self.m_Solver.GetPortfolioOutput();
                if ~isempty(pfOut2)
                    fprintf( 'Specific Risk(%%) = %.4f\n', pfOut2.GetSpecificRisk() );
                    fprintf( 'Factor Risk(%%) = %.4f\n', pfOut2.GetFactorRisk() );
			        fprintf( 'Risk from USA13Y1 & 1TY1 = %.4f\n', self.m_Solver.EvaluateRisk(pfOut2.GetPortfolio(), ERiskType.eTOTALRISK, [], aid, [], true, true));
                    fprintf( 'Risk from Factor_7|8|9* = %.4f\n\n', self.m_Solver.EvaluateRisk(pfOut2.GetPortfolio(), ERiskType.eFACTORRISK, [], [], fid, true, true));

			        ids = pfOut2.GetSlackInfoIDs();
					id = ids.GetFirst();
			        for i = 1:ids.GetCount()
				        fprintf('Risk Constraint Slack of %s = %.4f\n', char(id), pfOut2.GetSlackInfo(id).GetSlackValue());
                        id=ids.GetNext();
                    end
                    fprintf('\n');
                end                
            end
        end

        %% Tutorial_7d: Risk Budgeting by asset
        %
        % In the following example, we will constrain the amount of risk coming from
        % individual assets using additive risk definition.
        %
        function Tutorial_7d(self)
            % access to optimizer's namespace
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set alpha
            self.InitializeAlpha( '7d', 'Risk Budgeting By Asset', true );

            % Create a case object, set initial portfolio and trade universe
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case = self.m_WS.CreateCase('Case 7d', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(riskModel);

            % Add a risk constraint by asset (additive def): risk from USA11I1 and from 13Y1 to be between 3% and 5% 
            riskConstraint = self.m_Case.InitConstraints().InitRiskConstraints();
            pid = self.m_WS.CreateIDSet();
            pid.Add('USA11I1');
            pid.Add('USA13Y1');
            info = riskConstraint.AddRiskConstraintByAsset(pid, true, [], false, false, false, true);
            info.SetLowerBound(0.03);
            info.SetUpperBound(0.05);

            self.m_Case.InitUtility();

            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);

            % Print asset risks in the initial portfolio
            fprintf('Initial Portfolio:\n');
            self.PrintRisksByAsset(self.m_InitPf);
            fprintf('\n');

            self.RunOptimizeReuseSolver();
        
            pfOut = self.m_Solver.GetPortfolioOutput();
            if ~isempty(pfOut)
                % Print asset risks in the optimal portfolio
                self.PrintRisksByAsset(pfOut.GetPortfolio());
                fprintf('\n');

			    ids = pfOut.GetSlackInfoIDs();
				id = ids.GetFirst();
			    for i = 1:ids.GetCount()
				    fprintf('Risk Constraint Slack of %s = %.4f\n', char(id), pfOut.GetSlackInfo(id).GetSlackValue());
                    id=ids.GetNext();
                end
                fprintf('\n');
            end
        end

        %% Tutorial_8a: Long-Short Optimization
        %
        % Long/Short portfolios can be described as consisting of cash, a set of long
        % positions, and a set of short positions. Long-Short portfolios can provide 
        % more "alpha" since a manager is not restricted to positive-alpha stocks 
        % (assuming the manager's ability to identify overvalued and undervalued stocks).
        % Market-neutral portfolios are a special case of long/short strategy, because
        % they are constructed to remove systematic market risk (with a beta of zero to
        % the market portfolio, and no common-factor risk).  Since market-neutral
        % portfolios have no market risk, managers measure their performance against a 
        % cash benchmark.
        %
        % In Long-Short (Hedge) Optimization, you start with setting the default asset
        % minimum bound to -100% (thus allowing short sales).  You can then enter 
        % constraints to the long side and the short side of the portfolio.
        %
        % In example Tutorial_8a, we begin with a portfolio of $10mm cash and let the
        % optimizer determine optimal leverage based on expected returns we provide 
        % (i.e. maximize utility) to perform  a 130/30 strategy (long positions can be
        % up to 130% of the portfolio base value and short positions can be up to 30%). 
        %
        function Tutorial_8a(self)
       
            fprintf('======== Running Tutorial 8a ========\n');
            fprintf('Long-Short Hedge Optimization\n');
            self.SetupDumpFile ('8a');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();

            % initial portolio, trade universe, & Alpha
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');	
            self.m_TradeUniverse = self.m_WS.CreatePortfolio('Trade Universe');
            self.SetAlpha();

            % add assets
            for  i = 1:self.m_Data.m_AssetNum
                if ~strcmp( self.m_Data.m_ID(i), 'CASH')
                    self.m_TradeUniverse.AddAsset(self.m_Data.m_ID(i));
                else
                    self.m_InitPf.AddAsset(self.m_Data.m_ID(i), 1.0);
                end
            end

            % Create a case object with 10M cash portfolio
            self.m_Case = self.m_WS.CreateCase('Case 8a', self.m_InitPf, self.m_TradeUniverse, 10000000.0, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set asset ranges
            constraints = self.m_Case.InitConstraints();
            linear = constraints.InitLinearConstraints(); 
            for j=1:self.m_Data.m_AssetNum            
                info = linear.SetAssetRange(self.m_Data.m_ID(j));
                if ~strcmp( self.m_Data.m_ID(j), 'CASH' )
                    info.SetLowerBound(-1.0);
                    info.SetUpperBound(1.0);
                else
                    info.SetLowerBound(-0.3);
                    info.SetUpperBound(0.3);
                end
            end
            
            % Set hedge constraints
            hedgeConstr = constraints.InitHedgeConstraints();
            % set long-side leverage range
            longInfo = hedgeConstr.SetLongSideLeverageRange();
            longInfo.SetLowerBound(1.0);
            longInfo.SetUpperBound(1.3);
            % set short-side leverage range
            shortInfo = hedgeConstr.SetShortSideLeverageRange();
            shortInfo.SetLowerBound(-0.3);
            shortInfo.SetUpperBound(0.0);

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_8b: Short Costs as Single Attribute
        %
        % Short cost/rebate rate of asset i is defined as below:
        % ShortCost_i = CostOfLeverage + HardToBorrowPenalty_i - InterestRateOnProceed_i
        % 
        % Starting Optimizer 1.3, user can specify short cost via a single API as shown
        % below.
        %
        %
        function Tutorial_8b(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha( '8b', 'Short Costs as Single Attribute' , true);
            % Add cash
            self.m_InitPf.AddAsset('CASH', 1);

            % Create a case object. Set initial portfolio
            self.m_Case = self.m_WS.CreateCase('Case 8b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set asset ranges
            constraints = self.m_Case.InitConstraints();

            linear = constraints.InitLinearConstraints();
            for j=1:self.m_Data.m_AssetNum
                info = linear.SetAssetRange(self.m_Data.m_ID(j));
                if ~strcmpi( self.m_Data.m_ID(j), 'CASH')
                    info.SetLowerBound(-1.0);
                    info.SetUpperBound(1.0);
                else
                    info.SetLowerBound(-0.3);
                    info.SetUpperBound(0.3);
                end
            end

            % Set a short leverage range
            hedgeConstr = constraints.InitHedgeConstraints();
            shortInfo = hedgeConstr.SetShortSideLeverageRange();
            shortInfo.SetLowerBound(-0.3);
            shortInfo.SetUpperBound(0.0);

            % Set the net short cost
            asset = self.m_WS.GetAsset('USA11I1');
            if ~isempty(asset) 
                % ShortCost = CostOfLeverage + HardToBorrowPenalty - InterestRateOnProceed
                % where CostOfLeverage=50 basis, HardToBorrowPenalty=10 basis, InterestRateOnProceed=20 basis
                asset.SetNetShortCost(0.004);
            end

            % Set utility function
            util = self.m_Case.InitUtility();
            
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_8c: Weighted Total Leverage Constraint
        %
        % The following example shows how to setup weighted total leverage constraint,
        % total leverage group constraint, and total leverage factor constraint.
        %
        %
        function Tutorial_8c(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            %
            fprintf('======== Running Tutorial 8c ========\n');
            fprintf('Weighted Total Leverage Constraint Optimization\n');
            self.SetupDumpFile ('8c');

            % Create WorkSpace and setup Risk Model data
            self.SetupRiskModel();
            % Initial portforlio, trade universe & Alpha
            self.m_InitPf = self.m_WS.CreatePortfolio('Initial Portfolio');
            self.m_TradeUniverse = self.m_WS.CreatePortfolio('Trade Universe');
            self.SetAlpha();

            % 
            for i = 1:self.m_Data.m_AssetNum
                if strcmpi( self.m_Data.m_ID(i), 'CASH')
                    self.m_InitPf.AddAsset(self.m_Data.m_ID(i), 1.0);
                else
                    self.m_TradeUniverse.AddAsset(self.m_Data.m_ID(i));
                end
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

            % Create a case object with 10M cash portfolio
            self.m_Case = self.m_WS.CreateCase('Case 8c', self.m_InitPf, self.m_TradeUniverse, 10000000.0, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set asset ranges
            constraints = self.m_Case.InitConstraints();
            linear = constraints.InitLinearConstraints();
            for j=1:self.m_Data.m_AssetNum
                info = linear.SetAssetRange(self.m_Data.m_ID(j));
                if ~strcmpi( self.m_Data.m_ID(j), 'CASH')
                    info.SetLowerBound(-1.0);
                    info.SetUpperBound(1.0);
                else
                    info.SetLowerBound(-0.3);
                    info.SetUpperBound(0.3);
                end
            end

            % Add hedge constraints
            % long & short side coefficients
            longSideCoeffs = self.m_WS.CreateAttributeSet();
            shortSideCoeffs = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i), 'CASH') 
                    longSideCoeffs.Set( self.m_Data.m_ID(i), 1.0 );
                    shortSideCoeffs.Set( self.m_Data.m_ID(i), 1.0 );
                end
            end
            % add a total leverage factor constraint
            hedgeConstr = constraints.InitHedgeConstraints();
            wtlFacConsInfo = hedgeConstr.AddTotalLeverageFactorConstraint('Factor_1A');
            wtlFacConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlFacConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
            wtlFacConsInfo.SetPenalty(0.95, 0.80, 1.2);
            wtlFacConsInfo.SetSoft(true);
            % add a weighted total leverage constraint
            wtlConsInfo = hedgeConstr.AddWeightedTotalLeverageConstraint(longSideCoeffs, shortSideCoeffs);
            wtlConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
            wtlConsInfo.SetPenalty(0.95, 0.80, 1.2);
            wtlConsInfo.SetSoft(true);
            % add a total leverage group constraint
            wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint('GICS_SECTOR', 'Information Technology');
            wtlGrpConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetPenalty(0.95, 0.80, 1.2);
            wtlGrpConsInfo.SetSoft(true);

            %
            util = self.m_Case.InitUtility();
            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Constraint retrieval
            self.PrintLowerAndUpperBounds(linear);
            self.PrintLowerAndUpperBounds(hedgeConstr);
            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_8d: Long-side Turnover Constraint
        %
        % The following case illustrates the use of turnover by side constraint, which needs to
        % be used in conjunction with long-short optimization. The maximum turnover on the long side
        % is 20%, with total value on the long side equal to total value on the short side.
        % 
        %
        function Tutorial_8d(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc, no alpha
            self.Initialize( '8d', 'Long-side Turnover Constraint' );
            % Add cash
            self.m_InitPf.AddAsset('CASH');

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 8d', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set constraints
            constraints = self.m_Case.InitConstraints();

            % Set soft turnover constraint
            turnover = constraints.InitTurnoverConstraints(); 
            info = turnover.SetLongSideConstraint();
            info.SetUpperBound(0.2);

            % Set hedge constraint
            hedge = constraints.InitHedgeConstraints();
            hedgeInfo = hedge.SetShortLongLeverageRatioRange();
            hedgeInfo.SetLowerBound(1.0);
            hedgeInfo.SetUpperBound(1.0);

            % Set utility function
            self.m_Case.InitUtility();

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_9a: Risk Target
        %
        % The following example uses the same two-asset portfolio and ten-asset 
        % benchmark/trade universe.  There are asset alphas specified for each stock.
        %
        % The optimized portfolio will represent the optimal tradeoff between a target
        % level of risk and the maximum level of return available.  In this example, we
        % selected a target risk of 14% (tracking error, in this case, since a 
        % benchmark is assigned).  
        %
        function Tutorial_9a(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha('9a', 'Risk Target', true);

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 9a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set risk target
            self.m_Case.SetRiskTarget(0.14);

            %
            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_9b: Return Target
        %
        % Similar to Tutoral_9a, we define a return target of 1% in Tutorial_9b:
        %
        function Tutorial_9b(self)
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha('9b', 'Return Target', true);

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 9b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set return target
            self.m_Case.SetReturnTarget(0.01);

            %
            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end

        %% Tutorial_10a: Tax-aware Optimization (using pre-v8.8 legacy APIs)
        %
        % Suppose an individual investor desires to rebalance a portfolio to be "more
        % like the benchmark," but also wants to avoid having any net tax liability 
        % doing so.  In Tutorial_10a, we are rebalancing without alphas, and assume 
        % the portfolio has no realized capital gains so far this year.  The trading
        % rule is FIFO.
        %
        function Tutorial_10a(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc, no alpha
            self.Initialize('10a', 'Tax-aware Optimization (using pre-v8.8 legacy APIs)');

            % Set prices
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetPrice( self.m_Data.m_Price(i) );
                end
            end
            
            % Add tax lots
            assetValue = zeros(self.m_Data.m_AssetNum,1);
            pfValue = 0.0;
            for j=1:self.m_Data.m_Taxlots
                iAccount = self.m_Data.m_Account(j);
                if iAccount == 1
                    iAsset = self.m_Data.m_Indices(j);
                    self.m_InitPf.AddTaxLot( ...
                        self.m_Data.m_ID(iAsset),... 
                        self.m_Data.m_Age(j), self.m_Data.m_CostBasis(j),... 
                        self.m_Data.m_Shares(j), false);
                    lotValue = self.m_Data.m_Price(iAsset)*self.m_Data.m_Shares(j);
                    assetValue(iAsset) = assetValue(iAsset) + lotValue;
                    pfValue = pfValue + lotValue;
                end
            end

            % Reset asset initial weights that are calculated from tax lot information
            for i=1:self.m_Data.m_AssetNum
                self.m_InitPf.AddAsset(self.m_Data.m_ID(i), assetValue(i)/pfValue);
            end

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 10a', self.m_InitPf, ...
                self.m_TradeUniverse, pfValue, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Set tax rates
            tax = self.m_Case.InitTax();
            tax.EnableTwoRate(); % default is 365
            tax.SetTaxRate(0.243, 0.423); %long term and short term rates

            % not allow wash sale
            tax.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

            % first in, first out
            tax.SetSellingOrderRule(ESellingOrderRule.eFIFO);

            %
            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimize
            self.RunOptimize();

            % output
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                taxOut = output.GetTaxOutput();
                if ~isempty(taxOut)
                    fprintf('Tax Info:\n');
                    fprintf('Long Term Gain  = %.2f\n', taxOut.GetLongTermGain());
                    fprintf('Long Term Loss  = %.2f\n', taxOut.GetLongTermLoss());
                    fprintf('Long Term Tax   = %.2f\n', taxOut.GetLongTermTax());
                    fprintf('Short Term Gain = %.2f\n', taxOut.GetShortTermGain());
                    fprintf('Short Term Loss = %.2f\n', taxOut.GetShortTermLoss());
                    fprintf('Short Term Tax  = %.2f\n', taxOut.GetShortTermTax());
                    fprintf('Total Tax       = %.2f\n', taxOut.GetTotalTax());
                    fprintf('\n');
                    
                    portfolio = output.GetPortfolio();
                    idSet = portfolio.GetAssetIDSet();
                    fprintf( 'TaxlotID          Shares:\n' );
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
                        sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                        oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
                            shares = sharesInTaxlot.GetValue( lotID );
                            if shares~=0.
                                fprintf( '%s %8d\n', char(lotID), shares );
                            end
                            lotID = oLotIDs.GetNext();
                        end
                        assetID = idSet.GetNext();
                    end
                    fprintf('\n');				                    
                end
            end
        end

        %% Tutorial_10b: Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
        %
        % Portfolio managers focusing on tax impact during rebalancing want to harvest
        % losses and avoid gains to decrease tax cost rather than have gains net out
        % the losses. Other managers want to target gains to generate cash flow for
        % their clients. Still other managers want long -term gains and short-term 
        % losses. One can implement a tax loss harvesting strategy by setting the 
        % bounds appropriately.
        % 
        % Tutorial_10b illustrates how to constraint short term gain to 0 and long term
        % loss to 110.
        %
        function Tutorial_10b(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc, no alpha
            self.Initialize('10b', 'Capital Gain Arbitrage (using pre-v8.8 legacy APIs)');

            % set prices
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetPrice( self.m_Data.m_Price(i) );
                end
            end

            % add tax lots
            for j=1:self.m_Data.m_Taxlots
                iAccount = self.m_Data.m_Account(j);
                if iAccount == 1
                    self.m_InitPf.AddTaxLot(self.m_Data.m_ID( self.m_Data.m_Indices(j)),... 
                        self.m_Data.m_Age(j), self.m_Data.m_CostBasis(j),... 
                        self.m_Data.m_Shares(j), false);
                end
            end
            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 10b', self.m_InitPf, ... 
                self.m_TradeUniverse, 4279.4, 0.0);

            % primary risk model
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % tax rates
            tax = self.m_Case.InitTax();
            tax.EnableTwoRate(); % default is 365
            tax.SetTaxRate(0.243, 0.423); %long term and short term rates

            % not allow wash sale
            tax.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

            % first in, first out
            tax.SetSellingOrderRule(ESellingOrderRule.eFIFO);

            % set tax constraints
            constraints = self.m_Case.InitConstraints();
            taxConstr = constraints.InitTaxConstraints();
            % short gain arbitrage range
            shortConstr = taxConstr.SetShortGainArbitrageRange();
            shortConstr.SetLowerBound(0.0);
            shortConstr.SetUpperBound(0.0);
            % long loss arbitrage range   
            longConstr = taxConstr.SetLongLossArbitrageRange();
            longConstr.SetLowerBound(0.0);
            longConstr.SetUpperBound(110.0);

            % 
            self.m_Case.InitUtility();

            % Run optimization    
            self.RunOptimize();

            % Handle additional output information
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                taxOut = output.GetTaxOutput();
                if ~isempty(taxOut)
                    fprintf('Tax Info:\n');
                    fprintf('Long Term Gain  = %.2f\n', taxOut.GetLongTermGain());
                    fprintf('Long Term Loss  = %.2f\n', taxOut.GetLongTermLoss());
                    fprintf('Long Term Tax   = %.2f\n', taxOut.GetLongTermTax());
                    fprintf('Short Term Gain = %.2f\n', taxOut.GetShortTermGain());
                    fprintf('Short Term Loss = %.2f\n', taxOut.GetShortTermLoss());
                    fprintf('Short Term Tax  = %.2f\n', taxOut.GetShortTermTax());
                    fprintf('Total Tax       = %.2f\n', taxOut.GetTotalTax());
                    fprintf('\n');
                end
            end
        end

        %% Tutorial_10c: Tax-aware Optimization (Using new APIs introduced in v8.8)
        %
        % Suppose an individual investor desires to rebalance a portfolio to be “more
        % like the benchmark,” but also wants to minimize net tax liability. 
        % In Tutorial_10c, we are rebalancing without alphas, and assume 
        % the portfolio has no realized capital gains so far this year.  The trading
        % rule is FIFO. This tutorial illustrates how to set up a group-level tax 
        % arbitrage constraint.
        %
		function Tutorial_10c(self)
            import com.barra.optimizer.*;

			self.Initialize( '10c', 'Tax-aware Optimization (Using new APIs introduced in v8.8)' );

			for i=1:self.m_Data.m_AssetNum
				asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
					asset.SetPrice(self.m_Data.m_Price(i));
				end
			end
		
			% Set up group attribute
            for i=1:self.m_Data.m_AssetNum
				% Set GICS Sector attribute
				asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
					asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
				end
			end

			% Add tax lots into the portfolio, compute asset values and portfolio value
			assetValue(1:self.m_Data.m_AssetNum) = 0;
			pfValue = 0;
			for j=1:self.m_Data.m_Taxlots
                iAccount = self.m_Data.m_Account(j);
                if iAccount == 1
                    iAsset = self.m_Data.m_Indices(j);
                    self.m_InitPf.AddTaxLot(self.m_Data.m_ID(iAsset), self.m_Data.m_Age(j),...
                        				    self.m_Data.m_CostBasis(j), self.m_Data.m_Shares(j), false);

                    lotValue = self.m_Data.m_Price(iAsset)*self.m_Data.m_Shares(j);
                    assetValue(iAsset) = assetValue(iAsset) + lotValue;
                    pfValue = pfValue + lotValue;
                end
			end
	
			% Reset asset initial weights based on tax lot information
			for i=1:self.m_Data.m_AssetNum
				self.m_InitPf.AddAsset( self.m_Data.m_ID(i), assetValue(i)/pfValue );
			end

			% Create a case object
			self.m_Case = self.m_WS.CreateCase('Case 10c', self.m_InitPf, self.m_TradeUniverse, pfValue, 0.0);

			self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

			% Initialize a CNewTax object
			oTax = self.m_Case.InitNewTax();

			% Add a tax rule that covers all assets
			taxRule = oTax.AddTaxRule( '*', '*' );
			taxRule.EnableTwoRate();
			taxRule.SetTaxRate(0.243, 0.423);
			taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

			% Set selling order rule as first in/first out for all assets
			oTax.SetSellingOrderRule('*', '*', ESellingOrderRule.eFIFO);
	
			% Specify long-only
			oCons = self.m_Case.InitConstraints();
			linearCon = oCons.InitLinearConstraints(); 
			for i=1:self.m_Data.m_AssetNum
				info = linearCon.SetAssetRange(self.m_Data.m_ID(i));
				info.SetLowerBound(0.0);
			end

			% Set a group level tax arbitrage constraint
			oTaxCons = oCons.InitNewTaxConstraints();
			lgRange = oTaxCons.SetTaxArbitrageRange( 'GICS_SECTOR', 'Information Technology',...
													ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
			lgRange.SetUpperBound( 250. );

			util = self.m_Case.InitUtility();
			util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

			self.RunOptimize();

			output = self.m_Solver.GetPortfolioOutput();
			if ~isempty(output) 
				taxOut = output.GetNewTaxOutput();
				if ~isempty(taxOut)
					lgg = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
					lgl = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
					sgg = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
					sgl = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );

					fprintf('Tax info for group GICS_SECTOR/Information Technology:\n');
					fprintf('Long Term Gain  = %.4f\n', lgg);
					fprintf('Long Term Loss  = %.4f\n', lgl);
					fprintf('Short Term Gain = %.4f\n', sgg);
					fprintf('Short Term Loss = %.4f\n', sgl);

					ltax = taxOut.GetLongTermTax( '*', '*' );
					stax = taxOut.GetShortTermTax('*', '*');
					lgg_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
					lgl_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
			
					fprintf( '\nTax info for the tax rule group(all assets):\n' );
					fprintf('Long Term Gain = %.4f\n', lgg_all);
					fprintf('Long Term Loss = %.4f\n', lgl_all);
					fprintf('Long Term Tax  = %.4f\n', ltax);
					fprintf('Short Term Tax = %.4f\n', stax);

					fprintf('\nTotal Tax(for all tax rule groups) = %.4f\n', taxOut.GetTotalTax());

					portfolio = output.GetPortfolio();
					idSet = portfolio.GetAssetIDSet();
					fprintf( '\nTaxlotID          Shares:\n' );
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
						sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

						oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
							shares = sharesInTaxlot.GetValue( lotID );
							if shares~=0
								fprintf( '%s %.4f\n', char(lotID), shares );
							end
                            lotID = oLotIDs.GetNext();
						end
                        assetID = idSet.GetNext();
					end

					newShares = taxOut.GetNewShares();
					fprintf( '\n' );
					self.PrintAttributeSet(newShares, 'New Shares:');
					fprintf( '\n' );
				end
			end
        end

        %% Tutorial_10d: Tax-aware Optimization (Using new APIs introduced in v8.8)
        %
        % This tutorial illustrates how to set up a tax-aware optimization case with cash outflow.
        %
		function Tutorial_10d(self)
            import com.barra.optimizer.*;

			self.Initialize( '10d', 'Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow' );

			for i=1:self.m_Data.m_AssetNum
				asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
					asset.SetPrice(self.m_Data.m_Price(i));
				end
			end
		
			% Set up group attribute
            for i=1:self.m_Data.m_AssetNum
				% Set GICS Sector attribute
				asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
					asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
				end
			end

			% Add tax lots into the portfolio, compute asset values and portfolio value
			assetValue(1:self.m_Data.m_AssetNum) = 0;
			pfValue = 0;
			for j=1:self.m_Data.m_Taxlots
                iAccount = self.m_Data.m_Account(j);
                if iAccount == 1
                    iAsset = self.m_Data.m_Indices(j);
                    self.m_InitPf.AddTaxLot(self.m_Data.m_ID(iAsset), self.m_Data.m_Age(j),...
                        				    self.m_Data.m_CostBasis(j), self.m_Data.m_Shares(j), false);

                    lotValue = self.m_Data.m_Price(iAsset)*self.m_Data.m_Shares(j);
                    assetValue(iAsset) = assetValue(iAsset) + lotValue;
                    pfValue = pfValue + lotValue;
                end
			end

			% Cash outflow 5% of the base value
			CFW = -0.05;

			% Set base value so that the final optimal weight will sum up to 100%
			BV = pfValue / (1 - CFW);
	
			% Reset asset initial weights based on tax lot information
			for i=1:self.m_Data.m_AssetNum
				self.m_InitPf.AddAsset( self.m_Data.m_ID(i), assetValue(i)/BV );
			end

			% Create a case object
			self.m_Case = self.m_WS.CreateCase('Case 10d', self.m_InitPf, self.m_TradeUniverse, BV, CFW);

			self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

			% Initialize a CNewTax object
			oTax = self.m_Case.InitNewTax();

			% Add a tax rule that covers all assets
			taxRule = oTax.AddTaxRule( '*', '*' );
			taxRule.EnableTwoRate();
			taxRule.SetTaxRate(0.243, 0.423);
			taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

			% Set selling order rule as first in/first out for all assets
			oTax.SetSellingOrderRule('*', '*', ESellingOrderRule.eFIFO);
	
			% Specify long-only
			oCons = self.m_Case.InitConstraints();
			linearCon = oCons.InitLinearConstraints(); 
			for i=1:self.m_Data.m_AssetNum
				info = linearCon.SetAssetRange(self.m_Data.m_ID(i));
				info.SetLowerBound(0.0);
			end

			% Set a group level tax arbitrage constraint
			oTaxCons = oCons.InitNewTaxConstraints();
			lgRange = oTaxCons.SetTaxArbitrageRange( 'GICS_SECTOR', 'Information Technology',...
													ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
			lgRange.SetUpperBound( 250. );

			util = self.m_Case.InitUtility();
			util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

			self.RunOptimize();

			output = self.m_Solver.GetPortfolioOutput();
			if ~isempty(output) 
				taxOut = output.GetNewTaxOutput();
				if ~isempty(taxOut)
					lgg = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
					lgl = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
					sgg = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
					sgl = taxOut.GetCapitalGain( 'GICS_SECTOR', 'Information Technology', ...
														ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );

					fprintf('Tax info for group GICS_SECTOR/Information Technology:\n');
					fprintf('Long Term Gain  = %.4f\n', lgg);
					fprintf('Long Term Loss  = %.4f\n', lgl);
					fprintf('Short Term Gain = %.4f\n', sgg);
					fprintf('Short Term Loss = %.4f\n', sgl);

					ltax = taxOut.GetLongTermTax( '*', '*' );
					stax = taxOut.GetShortTermTax('*', '*');
					lgg_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
					lgl_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
			
					fprintf( '\nTax info for the tax rule group(all assets):\n' );
					fprintf('Long Term Gain = %.4f\n', lgg_all);
					fprintf('Long Term Loss = %.4f\n', lgl_all);
					fprintf('Long Term Tax  = %.4f\n', ltax);
					fprintf('Short Term Tax = %.4f\n', stax);

					fprintf('\nTotal Tax(for all tax rule groups) = %.4f\n', taxOut.GetTotalTax());

					portfolio = output.GetPortfolio();
					idSet = portfolio.GetAssetIDSet();
					fprintf( '\nTaxlotID          Shares:\n' );
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
						sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

						oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
							shares = sharesInTaxlot.GetValue( lotID );
							if shares~=0
								fprintf( '%s %.4f\n', char(lotID), shares );
							end
                            lotID = oLotIDs.GetNext();
						end
                        assetID = idSet.GetNext();
					end

					newShares = taxOut.GetNewShares();
					fprintf( '\n' );
					self.PrintAttributeSet(newShares, 'New Shares:');
					fprintf( '\n' );
				end
			end
        end

        %% Tax-aware Optimization with loss benefit
        %
        % This tutorial illustrates how to set up a tax-aware optimization case with
        % a loss benefit term in the utility.
        %
        function Tutorial_10e(self)
            import com.barra.optimizer.*;

            self.InitializeTaxAware( '10e', 'Tax-aware Optimization with loss benefit', false, true );

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 10e', self.m_InitPf, self.m_TradeUniverse, self.m_PfValue(1), 0.0);

            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Disable shorting
            linear = self.m_Case.InitConstraints().InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);

            % Initialize a CNewTax object
            oTax = self.m_Case.InitNewTax();

            % Add a tax rule that covers all assets
            taxRule  = oTax.AddTaxRule( '*', '*' );
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);	% not allow wash sale

            % Set selling order rule as first in/first out for all assets
            oTax.SetSellingOrderRule('*', '*', ESellingOrderRule.eFIFO);	% first in, first out

            util = self.m_Case.InitUtility();
            util.SetLossBenefitTerm(1.0);

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                taxOut = output.GetNewTaxOutput();
                if ~isempty(taxOut)
                    ltax = taxOut.GetLongTermTax( '*', '*' );
                    stax = taxOut.GetShortTermTax('*', '*');
                    lgg = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
                    lgl = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
                    sgg = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
                    sgl = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );
                    lb = taxOut.GetTotalLossBenefit();
                    tax = taxOut.GetTotalTax();

                    fprintf('Tax info:\n');
                    fprintf('Long Term Gain  = %.4f\n', lgg );
                    fprintf('Long Term Loss  = %.4f\n', lgl );
                    fprintf('Short Term Gain = %.4f\n', sgg );
                    fprintf('Short Term Loss = %.4f\n', sgl );
                    fprintf('Long Term Tax   = %.4f\n', ltax );
                    fprintf('Short Term Tax  = %.4f\n', stax );
                    fprintf('Loss Benefit    = %.4f\n', lb );
                    fprintf('Total Tax       = %.4f\n\n', tax);

                    portfolio = output.GetPortfolio();
                    idSet = portfolio.GetAssetIDSet();
                    fprintf( 'TaxlotID          Shares:\n' );
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
                        sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                        oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
                            shares = sharesInTaxlot.GetValue( lotID );
                            if shares~=0
                                fprintf( '%s  %.4f\n', char(lotID), shares );
                            end
                            lotID = oLotIDs.GetNext();
                        end
                        assetID = idSet.GetNext();
                    end

                    newShares = taxOut.GetNewShares();
                    fprintf( '\n' );
                    self.PrintAttributeSet(newShares, 'New Shares:');
                    fprintf( '\n' );
                end
            end
        end


        %% Tutorial_10f: Tax-aware Optimization with total loss and gain constraints.
        %
        % This tutorial illustrates how to set up a tax-aware optimization case with
        % bounds on total gain and loss.
        %
        function Tutorial_10f(self)
            import com.barra.optimizer.*;

            self.InitializeTaxAware('10f', 'Tax-aware Optimization with total loss/gain constraints', false, true);

            % Set up GICS Sector attribute
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 10f', self.m_InitPf, self.m_TradeUniverse, self.m_PfValue(1), 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Disable shorting and cash
            oCons = self.m_Case.InitConstraints();
            linear = oCons.InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);
            linear.SetAssetTradeSize('CASH', 0);

            % Initialize a CNewTax object and set tax parameters
            oTax = self.m_Case.InitNewTax();
            taxRule = oTax.AddTaxRule('*', '*');
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            oTax.SetSellingOrderRule('*', '*', ESellingOrderRule.eFIFO);

            % Set a group level tax arbitrage constraint on total loss
            oTaxCons = oCons.InitNewTaxConstraints();
            info = oTaxCons.SetTotalTaxArbitrageRange('GICS_SECTOR', 'Financials', ECapitalGainType.eCAPITAL_LOSS);
            info.SetUpperBound(100.);

            % Set a group level tax arbitrage constraint on total gain
            info2 = oTaxCons.SetTotalTaxArbitrageRange('GICS_SECTOR', 'Information Technology', ECapitalGainType.eCAPITAL_GAIN);
            info2.SetLowerBound(250.);

            util = self.m_Case.InitUtility();

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                taxOut = output.GetNewTaxOutput();
                if ~isempty(taxOut)
                    tgg = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Financials', ECapitalGainType.eCAPITAL_GAIN);
                    tgl = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Financials', ECapitalGainType.eCAPITAL_LOSS);
                    tgn = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Financials', ECapitalGainType.eCAPITAL_NET);
                    fprintf('Tax info (Financials):\n');
                    fprintf('Total Gain  = %.4f\n', tgg);
                    fprintf('Total Loss  = %.4f\n', tgl);
                    fprintf('Total Net   = %.4f\n\n', tgn);

                    tgg = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', ECapitalGainType.eCAPITAL_GAIN);
                    tgl = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', ECapitalGainType.eCAPITAL_LOSS);
                    tgn = taxOut.GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', ECapitalGainType.eCAPITAL_NET);
                    fprintf('Tax info (Information Technology):\n');
                    fprintf('Total Gain  = %.4f\n', tgg);
                    fprintf('Total Loss  = %.4f\n', tgl);
                    fprintf('Total Net   = %.4f\n\n', tgn);

                    portfolio = output.GetPortfolio();
                    idSet = portfolio.GetAssetIDSet();
                    fprintf( 'TaxlotID          Shares:\n' );
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
                        sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                        oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
                            shares = sharesInTaxlot.GetValue( lotID );
                            if shares~=0
                                fprintf( '%s  %.4f\n', char(lotID), shares );
                            end
                            lotID = oLotIDs.GetNext();
                        end
                        assetID = idSet.GetNext();
                    end

                    newShares = taxOut.GetNewShares();
                    fprintf( '\n' );
                    self.PrintAttributeSet(newShares, 'New Shares:');
                    fprintf( '\n' );
                end
            end
        end

        %% Tutorial_10g: Tax-aware Optimization with wash sales in the input.
        %
        % This tutorial illustrates how to specify wash sales, set the wash sale rule,
        % and access wash sale details from the output.
        %
        function Tutorial_10g(self)
            import com.barra.optimizer.*;

            self.InitializeTaxAware('10g', 'Tax-aware Optimization with wash sales', false, true);

            % Add an extra lot whose age is within the wash sale period
            self.m_InitPf.AddTaxLot('USA11I1', 12, 21.44, 20.0);

            % Recalculate asset weight from tax lot data
            self.UpdatePortfolioWeights();

            % Add wash sale records
            self.m_InitPf.AddWashSaleRec('USA2ND1', 20, 12.54, 10.0, false);
            self.m_InitPf.AddWashSaleRec('USA3351', 35, 2.42, 25.0, false);
            self.m_InitPf.AddWashSaleRec('USA39K1', 12, 9.98, 25.0, false);

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 10g', self.m_InitPf, self.m_TradeUniverse, self.m_PfValue(1), 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Disable shorting and cash
            oCons = self.m_Case.InitConstraints();
            linear = oCons.InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);
            linear.SetAssetTradeSize('CASH', 0);

            % Initialize a CNewTax object and set tax parameters
            oTax = self.m_Case.InitNewTax();
            taxRule = oTax.AddTaxRule('*', '*');
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            taxRule.SetWashSaleRule(EWashSaleRule.eTRADEOFF, 40);
            oTax.SetSellingOrderRule('*', '*', ESellingOrderRule.eFIFO);

            util = self.m_Case.InitUtility();

            self.RunOptimize();

            % Retrieving tax related information from the output
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                taxOut = output.GetNewTaxOutput();
                if ~isempty(taxOut)
                    portfolio = output.GetPortfolio();
                    idSet = portfolio.GetAssetIDSet();

                    % Shares in tax lots
                    fprintf('TaxlotID          Shares:\n');
                    assetID = idSet.GetFirst();
                    while ~strcmp(char(assetID), '')
                        sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                        oLotIDs = sharesInTaxlot.GetKeySet();
                        lotID = oLotIDs.GetFirst();
                        while ~strcmp(char(lotID), '')
                            shares = sharesInTaxlot.GetValue( lotID );
                            if shares~=0
                                fprintf( '%s  %.4f\n', char(lotID), shares );
                            end
                            lotID = oLotIDs.GetNext();
                        end
                        assetID = idSet.GetNext();
                    end

                    % New shares
                    newShares = taxOut.GetNewShares();
                    fprintf( '\n' );
                    self.PrintAttributeSet(newShares, 'New Shares:');
                    fprintf( '\n' );

                    % Disqualified shares
                    disqShares = taxOut.GetDisqualifiedShares();
                    self.PrintAttributeSet(disqShares, 'Disqualified Shares:');
                    fprintf( '\n' );

                    % Wash sale details
                    fprintf('Wash Sale Details:\n');
                    fprintf('%-20s%12s%10s%10s%12s%20s\n', 'TaxLotID', 'AdjustedAge', 'CostBasis', 'Shares', 'SoldShares', 'DisallowedLotID');
                    assetIDs = self.m_Case.GetAssetIDs();
					assetID = assetIDs.GetFirst();
                    while ~strcmp(assetID, '')
                        wsDetail = taxOut.GetWashSaleDetail(assetID);
                        if (~isempty(wsDetail))
                            for i=0:wsDetail.GetCount()-1
                                lotID = char(wsDetail.GetLotID(i));
                                disallowedLotID = char(wsDetail.GetDisallowedLotID(i));
                                age = wsDetail.GetAdjustedAge(i);
                                costBasis = wsDetail.GetAdjustedCostBasis(i);
                                shares = wsDetail.GetShares(i);
                                soldShares = wsDetail.GetSoldShares(i);
                                fprintf('%-20s%12d%10.4f%10.4f%12.4f%20s\n', lotID, age, costBasis, shares, soldShares, disallowedLotID);
                            end
                        end
						assetID = assetIDs.GetNext();
                    end
                    fprintf( '\n' );
                end
            end
        end

        %% Tutorial_11a: Efficient Frontier
        %
        % In the following Risk-Reward Efficient Frontier problem, we have chosen the
        % return constraint, specifying a lower bound of 0% turnover, upper bound of 
        % 10% return and ten points.  
        %
        function Tutorial_11a(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            % Set up workspace, risk model data, inital portfolio, etc.
            % Create WorkSpace and set up Risk Model data, 
            % Create initial portfolio, etc,
            % Set Alpha
            self.InitializeAlpha('11a', 'Efficient Frontier', true);

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 11a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % set frontier
            frontier = self.m_Case.InitFrontier(EFrontierType.eRISK_RETURN);

            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.0, 0.1);

            %
            self.m_Case.InitUtility();

            % 
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            
            % opsdata info could be very helpful in debugging 
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            fprintf( '\nNon-Interactive approach...\n' );

            oStatus = self.m_Solver.Optimize();

            if oStatus.GetStatusCode() ~= EStatusCode.eOK
                %show error message
                err = oStatus.GetMessage();
                fprintf('Optimization error: %s\n', char(err));
            end
            fprintf( '%s\n', char(oStatus.GetMessage()) );
            fprintf( '%s\n', char(self.m_Solver.GetLogMessage()) );

            frontierOutput = self.m_Solver.GetFrontierOutput();
            for i=0:frontierOutput.GetNumDataPoints()-1
                dataPoint = frontierOutput.GetFrontierDataPoint(i);

                fprintf('Risk(%%) = %.3f \tReturn(%%) = %.3f\n',... 
                    dataPoint.GetRisk(), dataPoint.GetReturn());
            end
            fprintf('\n');
            
        end

        %% Tutorial_11b: Utility-Factor Constraint Frontier
        %
        % In the following Utility-Factor Constraint Frontier problem, we illustrate the effect of varying
        % factor bound on the optimal portfolio's utility, specifying a lower bound of 0% and 
        % upper bound of 7% exposure to Factor_1A, and 10 data points.
        %
        function Tutorial_11b(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.InitializeAlpha('11b', 'Factor Constraint Frontier', true);

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 11b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Create a factor constraint for Factor_1A for the frontier
            linear = self.m_Case.InitConstraints().InitLinearConstraints();
            factorCons = linear.SetFactorRange('Factor_1A');

            % Vary exposure to Factor_1A between 0% and 7% with 10 data points
            frontier = self.m_Case.InitFrontier(EFrontierType.eUTILITY_FACTOR);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.0, 0.07);
            frontier.SetFrontierConstraintID(factorCons.GetID());

            self.m_Case.InitUtility();

            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            % opsdata info could be very helpful in debugging 
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();
            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));

            frontierOutput = self.m_Solver.GetFrontierOutput();

            for i = 0:frontierOutput.GetNumDataPoints()-1
                dataPoint = frontierOutput.GetFrontierDataPoint(i);

                fprintf('Utility = %.6f\tRisk(%%) = %.3f\tReturn(%%) = %.3f\n',...
                    dataPoint.GetUtility(), ...
                    dataPoint.GetRisk(), ...
                    dataPoint.GetReturn());

                fprintf('Optimal portfolio exposure to Factor_1A = %.4f\n', dataPoint.GetConstraintSlack());
            end
            fprintf('\n');
        end

        %% Tutorial_11c: Utility-General Linear Constraint Frontier
        %
        % In the following Utility-General Linear Constraint Frontier problem, we illustrate the effect of varying
        % sector exposure on the optimal portfolio's utility, specifying a lower bound of 10% and 
        % upper bound of 20% exposure to Information Technology sector, and 10 data points.
        %
        function Tutorial_11c(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.InitializeAlpha('11c', 'General Linear Constraint Frontier', true);

            for i = 1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset )
                    % Set GICS Sector attribute
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
                end
            end

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 11c', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set a constraint to GICS_SECTOR - Information Technology
            linearCon = self.m_Case.InitConstraints().InitLinearConstraints(); 
            groupCons = linearCon.AddGroupConstraint('GICS_SECTOR', 'Information Technology');

            frontier = self.m_Case.InitFrontier(EFrontierType.eUTILITY_GENERAL_LINEAR);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.1, 0.2);
            frontier.SetFrontierConstraintID(groupCons.GetID());

            self.m_Case.InitUtility();

            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            % opsdata info could be very helpful in debugging 
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();
            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));

            frontierOutput = self.m_Solver.GetFrontierOutput();

            for i=0:frontierOutput.GetNumDataPoints()-1
                dataPoint = frontierOutput.GetFrontierDataPoint(i);

                fprintf('Utility = %.6f\tRisk(%%) = %.3f\tReturn(%%) = %.3f\n', ...
                    dataPoint.GetUtility(), ...
                    dataPoint.GetRisk(), ...
                    dataPoint.GetReturn());
                fprintf('Optimal portfolio exposure to Information Technology = %.4f\n',...
                    dataPoint.GetConstraintSlack());
            end
            fprintf('\n');
        end
        %% Tutorial 11d: Utility-Leaverage Frontier
        %
        % In the following Utility-Leverage Frontier problem, we illustrate the effect of varying
        % total leverage range, specifying a lower bound of 30% and upper bound of 70%, and 10 data points.
        %       
        function Tutorial_11d(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.InitializeAlpha('11d', 'Utility-Leaverage Frontier', true);

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 11d', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set hedge settings
            self.m_TradeUniverse.AddAsset('CASH');		% Cash is required for L/S optimization            
            hedgeCons = self.m_Case.InitConstraints().InitHedgeConstraints(); 
            info = hedgeCons.SetTotalLeverageRange();
            
            % Vary total leverage range between 30% and 70% with 10 data points
            frontier = self.m_Case.InitFrontier(EFrontierType.eUTILITY_HEDGE);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.3, 0.7);
            frontier.SetFrontierConstraintID(info.GetID());

            self.m_Case.InitUtility();

            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            % opsdata info could be very helpful in debugging 
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();
            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));

            frontierOutput = self.m_Solver.GetFrontierOutput();
            if ~isempty(frontierOutput)
                for i=0:frontierOutput.GetNumDataPoints()-1
                    dataPoint = frontierOutput.GetFrontierDataPoint(i);
                    fprintf('Utility = %.6f   Total leverage = %.3f\n', ...
                        dataPoint.GetUtility(), dataPoint.GetConstraintSlack());
                end
            else
                fprintf('Invalid frontier\n');
            end
            fprintf('\n');
        end
        
        %% Tutorial_12a: Constraint hierarchy
        %
        % This tutorial illustrates how to set up constraint hierarchy
        %
        function Tutorial_12a(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.InitializeAlpha( '12a', 'Constraint Hierarchy', true );

            % Create a case object. Set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 12a', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            constraints = self.m_Case.InitConstraints();

            % Set minimum holding threshold; both for long and short positions
            % in this example 10%
            paring = constraints.InitParingConstraints(); 
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_LONG, 0.1);
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_SHORT, 0.1);

            % Set minimum trade size; both for long and short positions
            % in this example 20%
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_LONG, 0.2);
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_SHORT, 0.2);

            % Set Min # assets to 5, excluding cash and futures
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMin(5);

            % Set Max # trades to 3 
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_TRADES).SetMax(3);

            % Set hedge settings
            self.m_TradeUniverse.AddAsset( 'CASH' );		% Cash is required for L/S optimization 
            hedgeConstr = constraints.InitHedgeConstraints();
            conInfo1 = hedgeConstr.SetLongSideLeverageRange();
            conInfo1.SetLowerBound(1.0);
            conInfo1.SetUpperBound(1.1);
            conInfo2 = hedgeConstr.SetShortSideLeverageRange();
            conInfo2.SetLowerBound(-0.3);
            conInfo2.SetUpperBound(-0.3);
            conInfo3 = hedgeConstr.SetTotalLeverageRange();
            conInfo3.SetLowerBound(1.5);
            conInfo3.SetUpperBound(1.5);

            % Set constraint hierarchy
            hier = constraints.InitConstraintHierarchy();
            hier.AddConstraintPriority(ECategory.eASSET_PARING, ERelaxOrder.eFIRST);
            hier.AddConstraintPriority(ECategory.eHEDGE, ERelaxOrder.eSECOND);

            self.m_Case.InitUtility();
            %
            % constraint retrieval
            %
            % upper & lower bounds
            self.PrintLowerAndUpperBounds(hedgeConstr);
            % paring constraint
            self.PrintParingConstraints(paring);
            % constraint hierachy
            self.PrintConstraintPriority(hier); 

            self.RunOptimize();
        end

        %% Tutorial_14a: Shortfall Beta Constraint
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % for setting up shortfall beta constraint.  The shortfall beta data are 
        % read from a file that is an output file of BxR example.
        %
        function Tutorial_14a(self)
        
            self.InitializeAlpha( '14a', 'Shortfall Beta Constraint', true );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 14a', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            self.m_Case.SetRiskTarget(0.05);

            % Read shortfall beta from a file
            self.m_Data.ReadShortfallBeta();

            attributeSet = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i), 'CASH')
                    attributeSet.Set( self.m_Data.m_ID(i), self.m_Data.m_Shortfall_Beta(i) );
                end
            end

            linearCon = self.m_Case.InitConstraints().InitLinearConstraints(); 

            % Add coefficients with shortfall beta data read from file
            oShortfallBetaInfo = linearCon.AddGeneralConstraint(attributeSet);

            % Set lower/upper bounds for shortfall beta
            oShortfallBetaInfo.SetID('ShortfallBetaCon');
            oShortfallBetaInfo.SetLowerBound(0.9);
            oShortfallBetaInfo.SetUpperBound(0.9);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % constraint retrieval
            self.PrintLowerAndUpperBounds(linearCon);
            self.PrintAttributeSet(linearCon.GetCoefficients('ShortfallBetaCon'), 'The Coefficients are:');

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                slackInfo = output.GetSlackInfo('ShortfallBetaCon');
                if ~isempty(slackInfo)
                    fprintf('Shortfall Beta Con Slack = %.4f\n\n', slackInfo.GetSlackValue());
                end
            end
        end

        %% Tutorial_15a: Minimizing Total Risk from both of primary and secondary risk models
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % for minimizing Total Risk from both of primary and secondary risk models
        % and set a constraint for a factor in the secondary risk model.
        %
        function Tutorial_15a(self)
            
            % Create WorkSpace and setup Risk Model data,
            % Create initial portfolio, etc; no alpha
            self.Initialize( '15a', 'Minimize Total Risk from 2 Models' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 15a', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Setup Secondary Risk Model 
            self.SetupRiskModel2();
            riskModel2 = self.m_WS.GetRiskModel('MODEL2');
            self.m_Case.SetSecondaryRiskModel(riskModel2);
            
            % Set secondary factor range
            linearConstraint = self.m_Case.InitConstraints().InitLinearConstraints();
            info = linearConstraint.SetFactorRange('Factor2_2', false);
            info.SetLowerBound(0.00);
            info.SetUpperBound(0.40);

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            % for primary risk model; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            % for secondary risk model; No benchmark
            util.SetSecondaryRiskTerm([], 0.0075, 0.0075);

            self.RunOptimize();
        end

        %% Tutorial_15b: Constrain risk from secondary risk model
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % for constraining risk from secondary risk model
        %
        function Tutorial_15b(self)
            self.Initialize( '15b', 'Risk Budgeting - Dual Risk Model' );

            % Create a case object, set initial portfolio and trade universe
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case = self.m_WS.CreateCase('Case 15b', self.m_InitPf, self.m_TradeUniverse, 100000, 0.0);
            self.m_Case.SetPrimaryRiskModel(riskModel);

            % Setup Secondary Risk Model 
            self.SetupRiskModel2();
            riskModel2 = self.m_WS.GetRiskModel('MODEL2');
            self.m_Case.SetSecondaryRiskModel(riskModel2);

            riskConstraint = self.m_Case.InitConstraints().InitRiskConstraints();

            % Set total risk from the secondary risk model 
            info = riskConstraint.AddPLTotalConstraint(false, self.m_BM2Portfolio);
            info.SetID( 'RiskConstraint' );
            info.SetUpperBound(0.1);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output) 
                slackInfo = output.GetSlackInfo('RiskConstraint');
                if ~isempty(slackInfo)
                    fprintf('Risk Constraint Slack = %.4f\n', slackInfo.GetSlackValue());
                end
            end
        end

        %% Tutorial_15c: Risk Parity Constraint
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % to set risk parity constraint.
        %
        function Tutorial_15c(self)
		    % access to optimizer's namespace            
            import com.barra.optimizer.*;

            % Create WorkSpace and setup Risk Model data,
            % Create initial portfolio, etc; no alpha
            self.Initialize( '15c', 'Risk parity constraint' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 15c', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

			% Create set of asset IDs to be included
			ids = self.m_WS.CreateIDSet();
			for i=1:self.m_Data.m_AssetNum
				if ~strcmpi(self.m_Data.m_ID(i), 'USA11I1')
					ids.Add(self.m_Data.m_ID(i));
				end
			end

			% Set case as long only and set risk parity constraint
			constraints = self.m_Case.InitConstraints();
			linConstraint = constraints.InitLinearConstraints();
			linConstraint.SetTransactionType(ETranxType.eSHORT_NONE);
			riskConstraint = constraints.InitRiskConstraints();
			riskConstraint.SetRiskParity(ERiskParityType.eASSET_RISK_PARITY, ids, true, [], false);

            self.RunOptimize();
        end

        %% Tutorial_16a: Additional covariance term
        %
        % This self-documenting sample code illustrates how to specify the
        % additional covariance term that is added to the objective function.
        % 
        %
        function Tutorial_16a(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.Initialize( '16a', 'Additional covariance term - WXFX''W' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 16a', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Setup Secondary Risk Model 
            self.SetupRiskModel2();
            riskModel2 = self.m_WS.GetRiskModel('MODEL2');
            self.m_Case.SetSecondaryRiskModel(riskModel2);

            % Setup weight matrix
            attributeSet = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i), 'CASH')
                    attributeSet.Set( self.m_Data.m_ID(i), 1 );
                end
            end

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Sets the covariance term type = WXFXW with a benchmark and weight matrix, 
            % using secondary risk model
            util.AddCovarianceTerm(0.0075, ECovTermType.eWXFXW, self.m_BMPortfolio, attributeSet, false);

            self.RunOptimize();

        end

        %% Tutorial_16b: Additional covariance term
        %
        % This self-documenting sample code illustrates how to specify the
        % additional covariance term that is added to the objective function.
        % 
        %
        function Tutorial_16b(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.Initialize( '16b', 'Additional covariance term - XWFWX''' );

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 16b', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Setup weight matrix
            attributeSet = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_FactorNum
                attributeSet.Set( self.m_Data.m_Factor(i), 1 );
            end

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Sets the covariance term type = XWFWX and the weight matrix
            % using primary risk model
            util.AddCovarianceTerm(0.0075, ECovTermType.eXWFWX, [], attributeSet); 

            self.RunOptimize();

        end

        %% Tutorial_17a: Five-Ten-Forty Rule
        %
        % This self-documenting sample code illustrates how to apply the 5/10/40 rule
        % 
        %
        function Tutorial_17a(self)
            self.Initialize( '17a', 'Five-Ten-Forty Rule' );

            % Create a case object and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 17a', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set issuer for each asset
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetIssuer(self.m_Data.m_Issuer(i));
                end
            end

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            constraints = self.m_Case.InitConstraints();

            fiveTenFortyRule = constraints.Init5_10_40Rule();
            fiveTenFortyRule.SetRule(5, 10, 40);

            self.RunOptimize();
        end

        %% Tutorial_18: Adding factor block
        %
        % This self-documenting sample code illustrates how to set up the factor block structure
        % in a risk model.
        %
        %
        function Tutorial_18(self)
            self.Initialize( '18', 'Factor exposure block' );

            % Create a case object and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 18', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            riskModel = self.m_WS.GetRiskModel('GEM');
            factorGroupA = self.m_WS.CreateIDSet();
            factorGroupA.Add('Factor_1A');
            factorGroupA.Add('Factor_2A');
            factorGroupA.Add('Factor_3A');
            factorGroupA.Add('Factor_4A');
            factorGroupA.Add('Factor_5A');
            factorGroupA.Add('Factor_6A');
            factorGroupA.Add('Factor_7A');
            factorGroupA.Add('Factor_8A');
            factorGroupA.Add('Factor_9A');
            riskModel.AddFactorBlock('A', factorGroupA);

            factorGroupB = self.m_WS.CreateIDSet();
            factorGroupB.Add('Factor_1B');
            factorGroupB.Add('Factor_2B');
            factorGroupB.Add('Factor_3B');
            factorGroupB.Add('Factor_4B');
            factorGroupB.Add('Factor_5B');
            factorGroupB.Add('Factor_6B');
            factorGroupB.Add('Factor_7B');
            factorGroupB.Add('Factor_8B');
            factorGroupB.Add('Factor_9B');
            riskModel.AddFactorBlock('B', factorGroupB);

            util = self.m_Case.InitUtility();

        	% Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            self.RunOptimize();
        end

        %% Tutorial_19: Load Models Direct risk model data
        %
        % This self-documenting sample code illustrates how to load Models Direct data into USE4L risk model.
        %
        function Tutorial_19(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            self.Initialize( '19', 'Load risk model using Models Direct files' );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 19', self.m_InitPf, self.m_TradeUniverse, 100000);

            % Specify the set of assets to load exposures and specific risk for
            idSet = self.m_WS.CreateIDSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i),'CASH')
                    idSet.Add(self.m_Data.m_ID(i));
                end
            end

            % Create the risk model with the Barra model name
            rm = self.m_WS.CreateRiskModel('USE4L');

            % Load Models Direct data given location of the files, anaylsis date, and asset set
            status = rm.LoadModelsDirectData(self.m_Data.m_Datapath, 20130501, idSet);
            if status ~= ERiskModelStatus.eSUCCESS
                fprintf('Failed to load risk model data using Models Direct files\n');
                return;
            end
            
            self.m_Case.SetPrimaryRiskModel(rm);

            linear = self.m_Case.InitConstraints().InitLinearConstraints();
            info = linear.SetFactorRange('USE4L_SIZE');
            info.SetLowerBound(0.02);
            info.SetUpperBound(0.05);

            util = self.m_Case.InitUtility();
            
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            self.RunOptimize();

            pfOut = self.m_Solver.GetPortfolioOutput();
            if ~isempty(pfOut)
                slackInfo = pfOut.GetSlackInfo( 'USE4L_SIZE' );
                if ~isempty(slackInfo)
                    fprintf('Optimal portfolio exposure to USE4L_SIZE = %.4f\n', slackInfo.GetSlackValue());
                end
            end
        end
    
        %% Tutorial_19b: Change numeraire with Models Direct risk model data
        %
        % This self-documenting sample code illustrates how to change numeraire with Models Direct data
        %
        function Tutorial_19b(self)
           % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
	        self.InitializeAlpha( '19b', 'Change numeraire with risk model loaded from Models Direct data', true );

	        % Create a case object, set initial portfolio and trade universe
	        self.m_Case = self.m_WS.CreateCase('Case 19b', self.m_InitPf, self.m_TradeUniverse, 100000);

	        % Specify the set of assets to load exposures and specific risk for
	        idSet = self.m_WS.CreateIDSet();
            for i=1:self.m_Data.m_AssetNum
                if ~strcmpi(self.m_Data.m_ID(i),'CASH')
                    idSet.Add(self.m_Data.m_ID(i));
                end
            end
	        % Create the risk model with the Barra model name
	        pRM = self.m_WS.CreateRiskModel('GEM3L');

	        % Load Models Direct data given location of the files, anaylsis date, and asset set
	        rmStatus = pRM.LoadModelsDirectData(self.m_Data.m_Datapath, 20131231, idSet);
            if rmStatus ~= ERiskModelStatus.eSUCCESS
                fprintf('Failed to load risk model data using Models Direct files');
                return;
            end 

	        % Change numeraire to GEM3L_JPNC
	        numStatus = pRM.SetNumeraire('GEM3L_JPNC');
            if numStatus.GetStatusCode() ~= EStatusCode.eOK
                fprintf(numStatus.GetMessage());
                fprintf(numStatus.GetAdditionalInfo());
                return;
            end

	        self.m_Case.SetPrimaryRiskModel(pRM);

	        util = self.m_Case.InitUtility();
	        % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

	        self.RunOptimize();
        end
        
        %% Tutorial_20: Loading asset exposures with CSV file
        %
        % This self-documenting sample code illustrates how to use Barra Optimizer
        % to load asset exposures with CSV file.
        %
        function Tutorial_20(self)
            % access to optimizer's namespace            
            import com.barra.optimizer.*;
            
            fprintf('======== Running Tutorial 20 ========\n' );
            fprintf('Minimize Total Risk\n' );
            self.SetupDumpFile ('20');

            % Create a workspace and setup risk model data without asset exposures
            self.SetupRiskModelExposureOption(false);

            % Load asset exposures from asset_exposures.csv
            rm = self.m_WS.GetRiskModel('GEM');
            status = rm.LoadAssetExposures( strcat(self.m_Data.m_Datapath,'asset_exposures.csv') );
            if status.GetStatusCode() ~= EStatusCode.eOK
                fprintf('Error loading asset exposures data: %s\n', char(status.GetMessage()) );
                fprintf('%s\n', char(status.GetAdditionalInfo()) );
            end

            % Create initial portfolio etc
            self.SetupPortfolios();

            % Create a case object, null trade universe
            self.m_Case = self.m_WS.CreateCase('Case 20', self.m_InitPf, [], 100000);
            self.m_Case.SetPrimaryRiskModel(rm);

            util = self.m_Case.InitUtility();

            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            self.RunOptimize();
        end
        
        %% Tutorial_21: Retrieve constraint & asset KKT attribution terms
        %
        % This sample code illustrates how to use Barra Optimizer
        % to retrieve KKT terms of constraint and asset attributions 
        %
        function Tutorial_21(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            fprintf('======== Running Tutorial 21 ========\n');
            fprintf('Retrieve KKT terms of constraint & asset attributions\n');
            self.SetupDumpFile ('21');

            %Create a CWorkSpace instance; Release the existing one.
            if  ~isempty(self.m_WS)
                self.m_WS.Release();
            end
            filepath = strcat(self.m_Data.m_Datapath, '21.wsp');
            self.m_WS = CWorkSpace.DeSerialize(filepath);
            self.m_Solver = self.m_WS.GetSolver(self.m_WS.GetSolverIDs().GetFirst());

            self.RunOptimizeReuseSolver();

            self.CollectKKT(1.0);
        end
        
        %% Tutorial_22: Multi-period optimization
        %
        % The sample code illustrates how to set up a multi-period optimization for 2 periods.
        %
        function Tutorial_22(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.Initialize( '22', 'Multi-period optimization' );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 22', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set alphas, utility, constraints for period 1
            self.m_WS.SwitchPeriod(1);
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                asset.SetAlpha(self.m_Data.m_Alpha(i));
            end
            
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(1.0);
            
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Set constraints
            linearConstraint = self.m_Case.InitConstraints().InitLinearConstraints();
            range1 = linearConstraint.SetAssetRange('USA11I1');
            range1.SetLowerBound(0.1);

	
            % Set alphas, utility, constraints for period 2
            self.m_WS.SwitchPeriod(2);
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                asset.SetAlpha(self.m_Data.m_Alpha(self.m_Data.m_AssetNum+1-i));
            end
            % Set utility term
            util.SetAlphaTerm(1.5);

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Set constraints
            range = linearConstraint.SetAssetRange('USA13Y1');
            range.SetLowerBound(0.2);

            % Set cross-period constraint
            turnoverConstraint = self.m_Case.GetConstraints().InitTurnoverConstraints().SetCrossPeriodNetConstraint();
            turnoverConstraint.SetUpperBound(0.5);
	
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);

            % Add periods for multi-period optimization
            self.m_Solver.AddPeriod(1);
            self.m_Solver.AddPeriod(2);

            % Dump wsp file
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();

            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));
	
            if oStatus.GetStatusCode() == EStatusCode.eOK  
                output = self.m_Solver.GetMultiPeriodOutput();
                if ~isempty(output) 
                    % Retrieve cross-period output
                    crossPeriodOutput = output.GetCrossPeriodOutput();
                    fprintf('Period      = Cross-period\n');
                    fprintf('Return(%%)   = %.4f\n', crossPeriodOutput.GetReturn());
                    fprintf('Utility     = %.4f\n',  crossPeriodOutput.GetUtility());
                    fprintf('Turnover(%%) = %.4f\n\n', crossPeriodOutput.GetTurnover());

                    % Retrieve output for each period
                    for i=1:output.GetNumPeriods()
                        periodOutput = output.GetPeriodOutput(i-1);
                        fprintf('Period      = %d\n', periodOutput.GetPeriodID());
                        fprintf('Risk(%%)     = %.4f\n', periodOutput.GetRisk());
                        fprintf('Return(%%)   = %.4f\n', periodOutput.GetReturn());
                        fprintf('Utility     = %.4f\n',  periodOutput.GetUtility());
                        fprintf('Turnover(%%) = %.4f\n', periodOutput.GetTurnover());
                        fprintf('Beta        = %.4f\n\n', periodOutput.GetBeta());
                    end
                end
            end
        end
        
        %% Tutorial_23: Portfolio concentration constraint
        %
        % The sample code illustrates how to run an optimization with a portfolio concentration constraint that limits
        % the total weight of 5 largest positions to no more than 70% of the portfolio.
        %
        function Tutorial_23(self)
            import com.barra.optimizer.*;
            self.InitializeAlpha( '23', 'Portfolio concentration constraint', true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 23', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set portfolio concentration constraint
            portConcenCons = self.m_Case.InitConstraints().SetPortConcentrationConstraint();
            portConcenCons.SetNumTopHoldings(5);
            portConcenCons.SetUpperBound(0.7);

            % Exclude asset USA11I1 from portfolio concentration constraint
            excludedAssets = self.m_WS.CreateIDSet();
            excludedAssets.Add('USA11I1');
            portConcenCons.SetExcludedAssets(excludedAssets);

            util = self.m_Case.InitUtility();

            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);

            % Run optimization and display results
            self.RunOptimize();
            fprintf('Portfolio conentration=%.4f\n', self.m_Solver.Evaluate(EEvalType.ePORTFOLIO_CONCENTRATION, self.m_Solver.GetPortfolioOutput().GetPortfolio()));

        end
        
        %% Tutorial_25a: Multi-account optimization
        %
        % The sample code illustrates how to set up a multi-account optimization for 2 accounts.
        %
        function Tutorial_25a(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.InitializeAlpha( '25a', 'Multi-account optimization', true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 25a', [], self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set utility, constraints for account 1
            self.m_WS.SwitchAccount(1);
            % Set initial portfolio and base value     
            self.m_Case.SetPortBaseValue(1.0e+5);
            self.m_Case.SetInitialPort(self.m_InitPfs(1));         
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(1.0);
            % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            % Set constraints
            linearConstraint = self.m_Case.InitConstraints().InitLinearConstraints();
            range1 = linearConstraint.SetAssetRange('USA11I1');
            range1.SetLowerBound(0.1);

            % Set utility, constraints for account 2
            self.m_WS.SwitchAccount(2);
            % Set up a different universe for account 2
            tradeUniverse2 = self.m_WS.CreatePortfolio('Trade Universe 2');
            for i=1:self.m_Data.m_AssetNum-3
                tradeUniverse2.AddAsset(self.m_Data.m_ID(i));
            end
            self.m_Case.SetTradeUniverse(tradeUniverse2);
            % Set initial portfolio and base value
            self.m_Case.SetInitialPort(self.m_InitPfs(2));
            self.m_Case.SetPortBaseValue(3.0e+5);
            % Set utility term
            util.SetAlphaTerm(1.5);
 	        % Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Set constraints
            range = linearConstraint.SetAssetRange('USA13Y1');
            range.SetLowerBound(0.2);
  
            % Set constraints for all accounts and/or cross-account
            self.m_WS.SwitchAccount(barraopt.getALL_ACCOUNT());
            % Set joint market impact transaction cost
            util.SetJointMarketImpactTerm(0.5);
            % Set the piecewise linear transaction cost
            asset = self.m_WS.GetAsset('USA11I1');
            if ~isempty(asset)     
                asset.AddPWLinearBuyCost(0.002833681, 1000.0);
                asset.AddPWLinearBuyCost(0.003833681);
                asset.AddPWLinearSellCost(0.003833681);
            end
            asset = self.m_WS.GetAsset('USA13Y1');
            if ~isempty(asset)  
                asset.AddPWLinearBuyCost(0.00287745);
                asset.AddPWLinearSellCost(0.00387745);
            end
            asset = self.m_WS.GetAsset('USA1LI1');
            if ~isempty(asset) 
                asset.AddPWLinearBuyCost(0.00227745);
                asset.AddPWLinearSellCost(0.00327745);
            end
            
            % Set cross-account turnover constraint
            turnoverConstraint = self.m_Case.GetConstraints().InitCrossAccountConstraints().SetNetTurnoverConstraint();
            % cross-account constraint is specified in actual $ amount as opposed to percentage amount
            % the portfolio base value is the aggregate of base values of all accounts'                                       
            turnoverConstraint.SetUpperBound(0.5*(1.0e5 + 3.0e5));
	
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);

            % Add accounts for multi-account optimization
            self.m_Solver.AddAccount(1);
            self.m_Solver.AddAccount(2);

            % Dump wsp file
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();

            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));
	
            if oStatus.GetStatusCode() == EStatusCode.eOK  
                output = self.m_Solver.GetMultiAccountOutput();
                if ~isempty(output) 
                    % Retrieve cross-account output
                    crossAccountOutput = output.GetCrossAccountOutput();
                    fprintf('Account     = Cross-account\n');
                    fprintf('Return(%%)   = %.4f\n', crossAccountOutput.GetReturn());
                    fprintf('Utility     = %.4f\n',  crossAccountOutput.GetUtility());
                    fprintf('Turnover(%%) = %.4f\n', crossAccountOutput.GetTurnover());
                    fprintf('Joint Market Impact Buy Cost($) = %.4f\n', output.GetJointMarketImpactBuyCost());
                    fprintf('Joint Market Impact Sell Cost($) = %.4f\n\n', output.GetJointMarketImpactSellCost());
                    % Retrieve output for each account
                    for i=1:output.GetNumAccounts()
                        accountOutput = output.GetAccountOutput(i-1);
                        fprintf('Account     = %d\n', accountOutput.GetAccountID());
                        fprintf('Risk(%%)     = %.4f\n', accountOutput.GetRisk());
                        fprintf('Return(%%)   = %.4f\n', accountOutput.GetReturn());
                        fprintf('Utility     = %.4f\n',  accountOutput.GetUtility());
                        fprintf('Turnover(%%) = %.4f\n', accountOutput.GetTurnover());
                        fprintf('Beta        = %.4f\n\n', accountOutput.GetBeta());
                    end
                end
            end
        end

        %% Tutorial_25b: Multi-account tax-aware optimization with 2 accounts
        %
        % The example code illustrates how to set up a multi-account tax-aware
        % optimization for 2 accounts with cross-account tax bound
        % and an account-level tax bound.
        function Tutorial_25b(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.InitializeTaxAware( '25b', 'Multi-account tax-aware optimization', true, true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 25b', [], self.m_TradeUniverse, 0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Use CMAOTax for tax settings
            tax = self.m_Case.InitMAOTax();
            tax.SetTaxUnit(ETaxUnit.eDOLLAR);
            % Set cross-account tax limit to $40
            cons = self.m_Case.InitConstraints();
            cons.InitCrossAccountConstraints().SetTaxLimit().SetUpperBound(40);

            %
            % Account 1
            %
            self.m_WS.SwitchAccount(1);
            % Set initial portfolio and base value     
            self.m_Case.SetInitialPort(self.m_InitPfs(1));         
            self.m_Case.SetPortBaseValue(self.m_PfValue(1));
            % Narrow the trade universe
            tradeUniverse = self.m_WS.CreatePortfolio('Trade Universe 1');
            for i=1:3
                tradeUniverse.AddAsset(self.m_Data.m_ID(i));
            end
            self.m_Case.SetTradeUniverse(tradeUniverse);
            % Tax rules
            taxRule1 = tax.AddTaxRule();
            taxRule1.EnableTwoRate();
            taxRule1.SetTaxRate(0.243, 0.423);
            tax.SetTaxRule('*','*',taxRule1);
            % Set selling order rule as first in/first out for all assets
            tax.SetSellingOrderRule('*','*',ESellingOrderRule.eFIFO);
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetAlphaTerm(1.0);
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            % Specify long-only
            linearConstraint = cons.InitLinearConstraints();
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            % Tax constraints
            taxCon = cons.InitNewTaxConstraints();
            taxCon.SetTaxLotTradingRule('USA13Y1_TaxLot_0', ETaxLotTradingRule.eSELL_LOT);
            taxCon.SetTaxLimit().SetUpperBound(25);

            %
            % Account 2
            %
            self.m_WS.SwitchAccount(2);
            self.m_Case.SetInitialPort(self.m_InitPfs(2));
            self.m_Case.SetPortBaseValue(self.m_PfValue(2));
            % Tax rules
            taxRule2 = tax.AddTaxRule();
            taxRule2.EnableTwoRate();
            taxRule2.SetTaxRate(0.1, 0.2);
            tax.SetTaxRule('*','*',taxRule2);
            % Set utility term
            util.SetAlphaTerm(1.5);
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Specify long-only
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            linearConstraint.SetAssetRange('USA13Y1').SetUpperBound(0.2);

            % Add accounts for multi-account optimization
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            self.m_Solver.AddAccount(1);
            self.m_Solver.AddAccount(2);

            % Run optimization
            self.RunOptimizeReuseSolver();

        end
        
        %% Tutorial_25c: Multi-account tax-aware optimization with tax arbitrage
        %
        function Tutorial_25c(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.InitializeTaxAware( '25c', 'Multi-account optimization with tax arbitrage', true, true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 25c', [], self.m_TradeUniverse, 0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Use CMAOTax for tax settings
            tax = self.m_Case.InitMAOTax();
            tax.SetTaxUnit(ETaxUnit.eDOLLAR);
            % Set cross-account tax limit to $40
            cons = self.m_Case.InitConstraints();

            %
            % Account 1
            %
            self.m_WS.SwitchAccount(1);
            % Set initial portfolio and base value     
            self.m_Case.SetInitialPort(self.m_InitPfs(1));         
            self.m_Case.SetPortBaseValue(self.m_PfValue(1));
            % Tax rules
            taxRule1 = tax.AddTaxRule();
            taxRule1.EnableTwoRate();
            taxRule1.SetTaxRate(0.243, 0.423);
            tax.SetTaxRule('*','*',taxRule1);
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            % Specify long-only
            linearConstraint = cons.InitLinearConstraints();
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            % Specify minimum $50 long-term capital net gain
            taxCon = cons.InitNewTaxConstraints();
            taxCon.SetTaxArbitrageRange('*','*',ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_NET).SetLowerBound(50);

            %
            % Account 2
            %
            self.m_WS.SwitchAccount(2);
            self.m_Case.SetInitialPort(self.m_InitPfs(2));
            self.m_Case.SetPortBaseValue(self.m_PfValue(2));
            % Tax rules
            taxRule2 = tax.AddTaxRule();
            taxRule2.EnableTwoRate();
            taxRule2.SetTaxRate(0.1, 0.2);
            tax.SetTaxRule('*','*',taxRule2);
            % Set utility term
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Specify long-only
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            % Minimum $100 short-term capital gain
            taxCon.SetTaxArbitrageRange('*','*',ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN).SetLowerBound(100);

            % Add accounts for multi-account optimization
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            self.m_Solver.AddAccount(1);
            self.m_Solver.AddAccount(2);

            % Run optimization
            self.RunOptimizeReuseSolver();
        end
        
        %% Tutorial_25d: Multi-account tax-aware optimization with tax harvesting
        %
        function Tutorial_25d(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.InitializeTaxAware( '25d', 'Multi-account optimization with tax harvesting', true, true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 25d', [], self.m_TradeUniverse, 0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Use CMAOTax for tax settings
            tax = self.m_Case.InitMAOTax();
            tax.SetTaxUnit(ETaxUnit.eDOLLAR);
            % Set cross-account tax limit to $40
            cons = self.m_Case.InitConstraints();

            %
            % Account 1
            %
            self.m_WS.SwitchAccount(1);
            % Set initial portfolio and base value     
            self.m_Case.SetInitialPort(self.m_InitPfs(1));         
            self.m_Case.SetPortBaseValue(self.m_PfValue(1));
            % Tax rules
            taxRule1 = tax.AddTaxRule();
            taxRule1.EnableTwoRate();
            taxRule1.SetTaxRate(0.243, 0.423);
            tax.SetTaxRule('*','*',taxRule1);
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            % Specify long-only
            linearConstraint = cons.InitLinearConstraints();
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            % Target $50 long-term capital net gain
            tax.SetTaxHarvesting('*','*',ETaxCategory.eLONG_TERM, 50, 0.1);

            %
            % Account 2
            %
            self.m_WS.SwitchAccount(2);
            self.m_Case.SetInitialPort(self.m_InitPfs(2));
            self.m_Case.SetPortBaseValue(self.m_PfValue(2));
            % Tax rules
            taxRule2 = tax.AddTaxRule();
            taxRule2.EnableTwoRate();
            taxRule2.SetTaxRate(0.1, 0.2);
            tax.SetTaxRule('*','*',taxRule2);
            % Set utility term
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Specify long-only
            for i=1:self.m_Data.m_AssetNum
                linearConstraint.SetAssetRange(self.m_Data.m_ID(i)).SetLowerBound(0);
            end
            % Target $100 short-term capital gain
            tax.SetTaxHarvesting('*','*',ETaxCategory.eSHORT_TERM, 100, 0.1);

            % Add accounts for multi-account optimization
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            self.m_Solver.AddAccount(1);
            self.m_Solver.AddAccount(2);

            % Run optimization
            self.RunOptimizeReuseSolver();
        end

        %% Tutorial_25e: Multi-account tax-aware optimization with account groups
        %
        function Tutorial_25e(self)
            % access to optimizer's namespace  
            import com.barra.optimizer.*;
            
            self.InitializeTaxAware( '25e', 'Multi-account optimization with account groups', true, true );

            % Create a case object, set initial portfolio and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 25e', [], self.m_TradeUniverse, 0);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));
            
            % Use CMAOTax for tax settings
            tax = self.m_Case.InitMAOTax();
            tax.SetTaxUnit(ETaxUnit.eDOLLAR);
 
            cons = self.m_Case.InitConstraints();
            taxCons = cons.InitNewTaxConstraints();
            linearCons = cons.InitLinearConstraints();

            %
            % Account 1
            %
            self.m_WS.SwitchAccount(1);
            % Set tax lots, initial portfolio and base value for account 1    
            self.m_Case.SetInitialPort(self.m_InitPfs(1));         
            self.m_Case.SetPortBaseValue(self.m_PfValue(1));
            % Set tax rules
            taxRule1 = tax.AddTaxRule();
            taxRule1.EnableTwoRate();
            taxRule1.SetTaxRate(0.243, 0.423);
            tax.SetTaxRule('*','*',taxRule1);
            % Set utility term
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm(self.m_BMPortfolio, 0.0075, 0.0075);
            % Specify long-only
            linearCons.SetTransactionType(ETranxType.eSHORT_NONE);
            % Set tax limit to 30$
            info = taxCons.SetTaxLimit();
            info.SetUpperBound(30);

            %
            % Account 2
            %
            self.m_WS.SwitchAccount(2);
            self.m_Case.SetInitialPort(self.m_InitPfs(2));
            self.m_Case.SetPortBaseValue(self.m_PfValue(2));
            % Set utility term
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Long only
            linearCons.SetTransactionType(ETranxType.eSHORT_NONE);

            %
            % Account 3
            %
            self.m_WS.SwitchAccount(3);
            self.m_Case.SetInitialPort(self.m_InitPfs(3));
            self.m_Case.SetPortBaseValue(self.m_PfValue(3));
            % Set utility term
            util.SetPrimaryRiskTerm(self.m_BM2Portfolio, 0.0075, 0.0075);
            % Long only
            linearCons.SetTransactionType(ETranxType.eSHORT_NONE);

            %
            % Account Group 1
            %
            self.m_WS.SwitchAccountGroup(1);
            taxRule2 = tax.AddTaxRule();
            taxRule2.EnableTwoRate();
            taxRule2.SetTaxRate(0.1, 0.2);
            tax.SetTaxRule('*','*',taxRule2);
            % Joint tax limit for the group is set on the CCrossAccountConstraint object
            crossAcctCons = cons.InitCrossAccountConstraints();
            crossAcctCons.SetTaxLimit().SetUpperBound(200);

            % Add accounts for multi-account optimization
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            self.m_Solver.AddAccount(1);    % account 1 is stand alone
            self.m_Solver.AddAccount(2, 1); % account 2 and 3 are in account group 1
            self.m_Solver.AddAccount(3, 1);

            % Run optimization
            self.RunOptimizeReuseSolver();

        end

        %% Tutorial_26: Issuer Constraint
        %
        % This self-documenting sample code illustrates how to set up the 
        % optimization with issuer constraints
        %
        function Tutorial_26(self)
            import com.barra.optimizer.*;
            self.Initialize('26', 'Issuer Constraint');

            % Create a case object and trade universe
            self.m_Case = self.m_WS.CreateCase('Case 26', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

           % Set issuer for each asset
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetIssuer(self.m_Data.m_Issuer(i));
                end
            end
            
            util = self.m_Case.InitUtility();
            
            % Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
            % No benchmark
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);
            
            constraints = self.m_Case.InitConstraints();
	        issuerCons = constraints.InitIssuerConstraints();
	        % add a global issuer constraint
            infoGlobal = issuerCons.AddHoldingConstraint(EIssuerConstraintType.eISSUER_NET);
	        infoGlobal.SetLowerBound(0.01);
	        % add an individual issuer constraint
            infoInd = issuerCons.AddHoldingConstraint(EIssuerConstraintType.eISSUER_NET, '4');
	        infoInd.SetUpperBound(0.3);           

            % Run optimization
            self.RunOptimize();
        end 

        %% Tutorial_27a: Expected Shortfall Term
        %
        % This sample code illustrates how to add and expected shortfall
        % term to the utility.
        %
        function Tutorial_27a(self)
            import com.barra.optimizer.*;
            self.Initialize('27a', 'Expected Shortfall Term');

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 27a', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set expected shortfall data
            shortfall = self.m_Case.InitExpectedShortfall();
            shortfall.SetConfidenceLevel(0.90);
            attrSet = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_AssetNum
                attrSet.Set(self.m_Data.m_ID(i), self.m_Data.m_Alpha(i));
            end
            shortfall.SetTargetMeanReturns(attrSet);
            for i=1:self.m_Data.m_ScenarioNum
                for j=1:self.m_Data.m_AssetNum
                    attrSet.Set(self.m_Data.m_ID(j), self.m_Data.m_ScenarioData(i,j));
                end
                shortfall.AddScenarioReturns(attrSet);
            end
            
            % Set utility terms
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);
            util.SetExpectedShortfallTerm(1.0);

            % Run optimization
            self.RunOptimize();
        end 

        %% Tutorial_27a: Expected Shortfall Constraint
        %
        % This sample code illustrates how to set up an expected shortfall
        % constraint.
        %
        function Tutorial_27b(self)
            import com.barra.optimizer.*;
            self.Initialize('27b', 'Expected Shortfall Constraint');

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 27b', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Set expected shortfall data
            shortfall = self.m_Case.InitExpectedShortfall();
            shortfall.SetConfidenceLevel(0.90);
            shortfall.SetTargetMeanReturns([]); % use scenario returns
            attrSet = self.m_WS.CreateAttributeSet();
            for i=1:self.m_Data.m_ScenarioNum
                for j=1:self.m_Data.m_AssetNum
                    attrSet.Set(self.m_Data.m_ID(j), self.m_Data.m_ScenarioData(i,j));
                end
                shortfall.AddScenarioReturns(attrSet);
            end
            
            % Set expected shortfall constraint
            linCons = self.m_Case.InitConstraints().InitLinearConstraints();
            info = linCons.SetExpectedShortfallConstraint();
            info.SetUpperBound(0.30);
            
            % Set utility terms
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            % Run optimization
            self.RunOptimize();
        end 

        %% Tutorial_28a: General Ratio Constraint
        %
        % This example illustrates how to setup a ratio constraint specifying
        % the coefficients.
        %
        function Tutorial_28a(self)
            import com.barra.optimizer.*;
            self.Initialize('28a', 'General Ratio Constraint');

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 28a', self.m_InitPf, self.m_TradeUniverse, 100000);
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case.SetPrimaryRiskModel(riskModel);

            % Set a constraint on the weighted average of specific variances of the first three assets
            ratioCons = self.m_Case.InitConstraints().InitRatioConstraints();
            numeratorCoeffs = self.m_WS.CreateAttributeSet();
            for i=2:4
                id = self.m_Data.m_ID(i);
                numeratorCoeffs.Set(id, riskModel.GetSpecificVar(id, id));
            end
            % the denominator defaults to the sum of weights of the assets of the numerator
            info = ratioCons.AddGeneralConstraint(numeratorCoeffs);
            info.SetLowerBound(0.05);
            info.SetUpperBound(0.1);

            % Set utility terms
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if (~isempty(output))
                slackInfo = output.GetSlackInfo(info.GetID());
                fprintf('Ratio       = %.4f\n\n', slackInfo.GetSlackValue());
            end
        end

        %% Tutorial_28b: Group Ratio Constraint
        %
        % This example illustrates how to setup a ratio constraint using asset attributes.
        %
        function Tutorial_28b(self)
            import com.barra.optimizer.*;
            self.Initialize('28b', 'Group Ratio Constraint');

            % Set up GICS_SECTOR group attribute
            for i=1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if (~isempty(asset))
                    asset.SetGroupAttribute('GICS_SECTOR', self.m_Data.m_GICS_Sector(i));
				end
            end

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 28b', self.m_InitPf, self.m_TradeUniverse, 100000);
            self.m_Case.SetPrimaryRiskModel(self.m_WS.GetRiskModel('GEM'));

            % Initialize ratio constraints
            ratioCons = self.m_Case.InitConstraints().InitRatioConstraints();

            % Weight of 'Financials' assets can be at most half of 'Information Technology' assets
            info = ratioCons.AddGroupConstraint('GICS_SECTOR','Financials', 'GICS_SECTOR', 'Information Technology');
            info.SetUpperBound(0.5);

            % Ratio of 'Information Technology' to 'Minerals' should not differ from the benchmark more than +-10%
            info2 = ratioCons.AddGroupConstraint('GICS_SECTOR', 'Minerals', 'GICS_SECTOR', 'Information Technology');
            info2.SetReference(self.m_BMPortfolio);
            info2.SetLowerBound(-0.1, ERelativeMode.ePLUS);
            info2.SetUpperBound(0.1, ERelativeMode.ePLUS);

            % Set utility terms
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            self.RunOptimize();

            output = self.m_Solver.GetPortfolioOutput();
            if (~isempty(output))
                slackInfo = output.GetSlackInfo(info.GetID());
                fprintf('Financials / IT = %.4f\n', slackInfo.GetSlackValue());
                slackInfo = output.GetSlackInfo(info2.GetID());
                fprintf('Minerals / IT   = %.4f\n\n', slackInfo.GetSlackValue());
            end
        end


        %% Tutorial 29: General Quadratic Constraint
        %
        % This example illustrates how to setup a general quadratic constraint.
        %
        function Tutorial_29(self)
            self.Initialize('29', 'General Quadratic Constraint');

            % Create a case object
            self.m_Case = self.m_WS.CreateCase('Case 29', self.m_InitPf, self.m_TradeUniverse, 100000);
            riskModel = self.m_WS.GetRiskModel('GEM');
            self.m_Case.SetPrimaryRiskModel(riskModel);

            % Initialize quadratic constraints
            quadraticCons = self.m_Case.InitConstraints().InitQuadraticConstraints();

            % Create the Q matrix and set some elements
            Q_mat = self.m_WS.CreateSymmetricMatrix(3);

            Q_mat.SetElement(self.m_Data.m_ID(2), self.m_Data.m_ID(2), 0.92473646);
            Q_mat.SetElement(self.m_Data.m_ID(3), self.m_Data.m_ID(3), 0.60338704);
            Q_mat.SetElement(self.m_Data.m_ID(3), self.m_Data.m_ID(4), 0.38904854);
            Q_mat.SetElement(self.m_Data.m_ID(4), self.m_Data.m_ID(4), 0.63569677);

            % The Q matrix must be positive semidefinite
            is_positive_semidefinite = Q_mat.IsPositiveSemidefinite();

            % Create the q vector and set some elements
            q_vect = self.m_WS.CreateAttributeSet();
            for i=2:6
                q_vect.Set(self.m_Data.m_ID(i), 0.1);
            end

            % Add the constraint and set an upper bound
            info = quadraticCons.AddConstraint(Q_mat, q_vect, []);
            info.SetUpperBound(0.1);

            % Set utility terms
            util = self.m_Case.InitUtility();
            util.SetPrimaryRiskTerm([], 0.0075, 0.0075);

            self.RunOptimize();
        end

        function ParseCommandLine(self, argv)
            dump = false;
            for i=1:length(argv) 
                if strcmp( argv(i), '-d') 
                    dump = true;
                    self.DumpAll(true);
                elseif ~isempty(strfind(char(argv(i)),'-'))
                    dump=false;
                    if strcmp(argv(i), '-c')
                        self.SetCompatibleMode(true);
                    end
                elseif dump 
                    self.m_DumpTID(char(argv(i))) = 1;
                end
            end
            if( self.m_DumpTID.Count>0 )
                self.DumpAll(false);
            end    
        end        
        
    end
        
    methods( Access='protected' )
        function ret = dumpWorkspace(self, tid)
            ret = self.m_DumpTID.isKey(tid);
        end
        
        function SetupDumpFile(self, tutorialID)
            self.SetupDumpFileBase(tutorialID, self.dumpWorkspace(tutorialID));
        end

        function InitializeTaxAware(self, tutorialID, description, setAlpha, isTaxAware)
            self.InitializeBase(tutorialID, description, self.dumpWorkspace(tutorialID), setAlpha, isTaxAware);
        end
        
        function InitializeAlpha(self, tutorialID, description, setAlpha)
            self.InitializeTaxAware(tutorialID, description, setAlpha, false);
        end        

        function Initialize(self, tutorialID, description)
            self.InitializeAlpha(tutorialID, description, false);
        end
    end
    
    methods ( Static )
        %% Print Upper & Lower Bound of Linear Constraints
        %
        % This self-documenting sample code illustrates how to retrieve linear constraints
        % one can apply the same methods to hedge constraints, turnover constraints & risk constraints
        %
        function PrintLowerAndUpperBounds(cons)
            ids = cons.GetConstraintIDSet();
            cid = ids.GetFirst();
            while ~strcmp(char(cid), '')
                info = cons.GetConstraintInfo(cid);
                fprintf('constraint ID: %s\n', char(info.GetID()));
                fprintf('lower bound: %.2f, upper bound: %.2f\n', info.GetLowerBound(), info.GetUpperBound());
                cid = ids.GetNext();
            end
        end

        %% Print Some Paring Constraints
        %
        % This self-documenting sample code illustrates how to retrieve paring constraints
        %
        function PrintParingConstraints(paring)
            % access to optimizer namespace
            import com.barra.optimizer.*;
            %tailored for tutorial 12a
            if( paring.ExistsAssetTradeParingType(EAssetTradeParingType.eNUM_ASSETS) )
                fprintf('Minimum number of assets is: %d\n', ...  
                    paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_ASSETS).GetMin());
            end
            if( paring.ExistsAssetTradeParingType(EAssetTradeParingType.eNUM_TRADES) )
                fprintf('Maximum number of trades is: %d\n', ... 
                    paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_TRADES).GetMax());
            end
            
            lps = [ ELevelParingType.eMIN_HOLDING_LONG; ...
                ELevelParingType.eMIN_HOLDING_SHORT; ...
                ELevelParingType.eMIN_TRANX_LONG; ...
                ELevelParingType.eMIN_TRANX_SHORT; ...
                ELevelParingType.eMIN_TRANX_BUY; ...
                ELevelParingType.eMIN_TRANX_SELL];


            msg = cellstr([ 'Min holding (long) threshold is:      '; ...
                            'Min holding (short) threshold is:     '; ...
                            'Min transaction (long) threshold is:  '; ...
                            'Min transaction (short) threshold is: '; ... 
                            'Min transaction (buy) threshold is:   '; ...
                            'Min transaction (sell) threshold is:  ']); 

            for i=1:6
                if paring.ExistsLevelParingType(lps(i)) 
                        fprintf('%s %.2f\n', char(msg(i)), paring.GetThreshold(lps(i)));
                end
            end
            fprintf('\n');
        end

        %% Print Constraint Priority
        %
        % This self-documenting sample code illustrates how to retrieve constraint hierachy
        %
        function PrintConstraintPriority(hier)
            % access to optimizer namespace
            import com.barra.optimizer.*;
            cate = [ ...   
                ECategory.eLINEAR; ...
                ECategory.eFACTOR; ...
                ECategory.eTURNOVER; ...
                ECategory.eTRANSACTIONCOST; ...
                ECategory.eHEDGE; ...
                ECategory.ePARING; ...
                ECategory.eASSET_PARING; ...
                ECategory.eHOLDING_LEVEL_PARING; ...
                ECategory.eTRANXSIZE_LEVEL_PARING; ...
                ECategory.eTRADE_PARING; ...
                ECategory.eRISK; ...
                ECategory.eROUNDLOTTING ... 
            ]; 

            cate_string = cellstr([
                'eLINEAR                '; ...
                'eFACTOR                '; ...
                'eTURNOVER              '; ...
                'eTRANSACTIONCOST       '; ...
                'eHEDGE                 '; ...
                'ePARING                '; ...
                'eASSET_PARING          '; ...
                'eHOLDING_LEVEL_PARING  '; ...
                'eTRANXSIZE_LEVEL_PARING'; ...
                'eTRADE_PARING          '; ...
                'eRISK                  '; ...
                'eROUNDLOTTING          ' ...
            ]);

            for i = 1:12
                if hier.ExistsCategoryPriority(cate(i))
                    order = hier.GetPriorityForConstraintCategory(cate(i));
                    if order==ERelaxOrder.eFIRST
                        fprintf('The category priority for %s is the first\n', char(cate_string(i)) );
                    elseif order==ERelaxOrder.eSECOND
                        fprintf('The category priority for %s is the second\n', char(cate_string(i)));
                    elseif order==ERelaxOrder.eLAST
                        fprintf('The category priority for %s is the last\n,', char(cate_string(i)));
                    end
                end
            end
            fprintf('\n');
        end
        
        function terms = strsplit(s, delimiter)
        %% STRSPLIT Splits a string into multiple terms
        %
        %   terms = strsplit(s)
        %       splits the string s into multiple terms that are separated by
        %       white spaces (white spaces also include tab and newline).
        %
        %       The extracted terms are returned in form of a cell array of
        %       strings.
        %
        %   terms = strsplit(s, delimiter)
        %       splits the string s into multiple terms that are separated by
        %       the specified delimiter. 
        %   
        %   Remarks
        %   -------
        %       - Note that the spaces surrounding the delimiter are considered
        %         part of the delimiter, and thus removed from the extracted
        %         terms.
        %
        %       - If there are two consecutive non-whitespace delimiters, it is
        %         regarded that there is an empty-string term between them.         
        %
        %   Examples
        %   --------
        %       % extract the words delimited by white spaces
        %       ts = strsplit('I am using MATLAB');
        %       ts <- {'I', 'am', 'using', 'MATLAB'}
        %
        %       % split operands delimited by '+'
        %       ts = strsplit('1+2+3+4', '+');
        %       ts <- {'1', '2', '3', '4'}
        %
        %       % It still works if there are spaces surrounding the delimiter
        %       ts = strsplit('1 + 2 + 3 + 4', '+');
        %       ts <- {'1', '2', '3', '4'}
        %
        %       % Consecutive delimiters results in empty terms
        %       ts = strsplit('C,Java, C++ ,, Python, MATLAB', ',');
        %       ts <- {'C', 'Java', 'C++', '', 'Python', 'MATLAB'}
        %
        %       % When no delimiter is presented, the entire string is considered
        %       % as a single term
        %       ts = strsplit('YouAndMe');
        %       ts <- {'YouAndMe'}
        %

        %   History
        %   -------
        %       - Created by Dahua Lin, on Oct 9, 2008
        %

        % parse and verify input arguments

            assert(ischar(s) && ndims(s) == 2 && size(s,1) <= 1, ...
                'strsplit:invalidarg', ...
                'The first input argument should be a char string.');

            if nargin < 2
                by_space = true;
            else
                d = delimiter;
                assert(ischar(d) && ndims(d) == 2 && size(d,1) == 1 && ~isempty(d), ...
                    'strsplit:invalidarg', ...
                    'The delimiter should be a non-empty char string.');

                d = strtrim(d);
                by_space = isempty(d);
            end

            % main

            s = strtrim(s);

            if by_space
                w = isspace(s);            
                if any(w)
                    % decide the positions of terms        
                    dw = diff(w);
                    sp = [1, find(dw == -1) + 1];     % start positions of terms
                    ep = [find(dw == 1), length(s)];  % end positions of terms

                    % extract the terms        
                    nt = numel(sp);
                    terms = cell(1, nt);
                    for i = 1 : nt
                        terms{i} = s(sp(i):ep(i));
                    end                
                else
                    terms = {s};
                end

            else    
                p = strfind(s, d);
                if ~isempty(p)        
                    % extract the terms        
                    nt = numel(p) + 1;
                    terms = cell(1, nt);
                    sp = 1;
                    dl = length(delimiter);
                    for i = 1 : nt-1
                        terms{i} = strtrim(s(sp:p(i)-1));
                        sp = p(i) + dl;
                    end         
                    terms{nt} = strtrim(s(sp:end));
                else
                    terms = {s};
                end        
            end
        end
        
    end
end

