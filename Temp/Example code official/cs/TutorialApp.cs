/** @file TutorialApp.cs
* \brief Contains definations of the TutorialApp class with specific code for
* each of tutorials.
*/

using System;
using System.Collections.Generic;

namespace Tutorial_CS
{
    
    class CSharpCallBack : CCallBack
    {
        public override bool OnDataPoint(CDataPoint oDataPt)
	    {
            Console.WriteLine("Risk(%) = {0:0.000} \tReturn(%) = {1:0.000}",
                oDataPt.GetRisk(), oDataPt.GetReturn());
		    return false;
	    }

        public override bool OnMessage(CMessage oMessage)
	    {
            Console.WriteLine("Message: "+oMessage.GetMessage());
		    return false;
	    }
    }
    
    /**\brief Contains specific code for each of the tutorials
    */
    class TutorialApp : TutorialBase
    {
        protected HashSet<String> m_DumpTID; 

        public TutorialApp(TutorialData data)
            : base(data)
        {
            m_DumpTID = new HashSet<String>();
        }

        /// Initialize the optimization
        public void Initialize(String tutorialID, String description)
        {
    	    Initialize(tutorialID, description, dumpWorkspace(tutorialID), false, false);  
        }
       
        /// Initialize the optimization
        public void Initialize(String tutorialID, String description, bool setAlpha)
        {
    	    Initialize(tutorialID, description, dumpWorkspace(tutorialID), setAlpha, false);
        }

        public void Initialize(String tutorialID, String description, bool setAlpha, bool isTaxAware)
        {
            Initialize(tutorialID, description, dumpWorkspace(tutorialID), setAlpha, isTaxAware);
        }

        /// <summary>
        ///  Setup dump file 
        /// </summary>
        /// <param name="tutorialID"></param>
        public void SetupDumpFile(String tutorialID)
        {
            SetupDumpFile(tutorialID, dumpWorkspace(tutorialID));
        }

        /** \brief Minimizing Total Risk
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for minimizing Total Risk.
        */
        public void Tutorial_1a()
        {
            // Create WorkSpace and setup Risk Model data,
            // Create initial portfolio, etc; no alpha
            Initialize("1a", "Minimize Total Risk");

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 1a", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            // no benchmark

            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();

	        //Get the slack information for default balance constraint.
	        CPortfolioOutput output = m_Solver.GetPortfolioOutput();
	        CSlackInfo slackInfo = output.GetSlackInfo4BalanceCon();
            
            //Get the KKT term of the balance constraint.
	        CAttributeSet impact = slackInfo.GetKKTTerm(true);
            PrintAttributeSet(impact, "Balance constraint KKT term");
        }

        /** \brief Adding Expected Returns and Adjusting Risk Aversion 
        *
        * The previous examples maximized mean-variance utility, but did not 
        * incorporate alpha (expected returns), so the optimizer was minimizing
        * risk.  When we add returns to the objective function, the optimizer 
        * will look for global maximum utility, trading off return and risk. The
        * common factor and specific risk aversion coefficients control how much
        * disutility that risk generates (in other words, the trade off between 
        * risk and return). 
        *
        * The example Tutorial_1b is to show how to set expected return for each 
        * asset and change the risk aversion coefficients for the common factors 
        * and specific risk:
        */
        public void Tutorial_1b()
        {
            Initialize("1b", "Maximize Return and Minimize Total Risk", true);

            // Create a case object, no trade universe
            m_Case = m_WS.CreateCase("Case 1b", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Statement below is optional. 
            // change risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
            // No benchmark
            // util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

            RunOptimize();
        }

        /**\brief Adding a Benchmark to Minimize Active Risk
        * 
        * This sample code illustrates how to use the Barra Optimizer for 
        * minimizing Active Risk by applying a Benchmark to the utility.  
        * With this source code, we extended Tutorial_1a to include a benchmark 
        * and change the objective function in the optimizer to minimize tracking
        * error.  This is a typical workflow for an indexer (tracking a benchmark
        * while minimizing transaction costs).
        */
        public void Tutorial_1c()
        {
            Initialize("1c", "Minimize Active Risk");

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 1c", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();
        }

        /**\brief Roundlotting
       * 
       * Barra Optimizer returns an optimal portfolio as a set of relative 
       * weights (floating point numbers, which result in fractional shares
       * when converted to share holdings using the portfolio value). 
       *
       * The optimizer supports the use of roundlots when solving the 
       * optimization problem to generate a more realistic trade list. This
       * requires prices and round lot sizes for the trade universe and the
       * portfolio’s base value.  The roundlot constraint may result in 
       * infeasible solutions so the user can either relax the constraints or
       * round lot the optimization result in the client application (though 
       * this may result in a less “optimal” portfolio).
       *
	   * Note that enforcing the roundlot constraint ensures that the trades are roundlotted, 
       * but the final optimal weights may not be in round lots. 
       * 
       * This sample code Tutorial_1d is modified from Tutorial_1b to illustrate 
       * how to set-up roundlotting:
       */
        public void Tutorial_1d()
        {
            Initialize("1d", "Roundlotting", true);

            // Set round lot info
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) == 0) //case-insensitive comparison
                    continue;

                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                {
                    // Round lot requires the price of each asset
                    asset.SetPrice(m_Data.m_Price[i]);

                    // Set lot size to 20
                    asset.SetRoundLotSize(20);
                }
            }

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 1d", m_InitPf, null, 10000000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Enable Roundlotting; do not allow odd lot clostout 
            m_Case.InitConstraints().EnableRoundLotting(false, false);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Post Optimization Roundlotting
        * 
        * The sample code shows how to retrieve the roundlotted portfolio
        * post optimization. The resulting portfolio may not satisfy some of 
        * your optimization settings, such as asset bounds, maximum turnover 
        * and transaction costs, paring constraints, and factor-level 
        * constraints, etc. Post-optimization roundlotting may fail if 
        * roundlotting a trade would result in a change of sign of the asset 
        * position.
        *
        * The trade list is shown in this sample to illustrate the roundlotted
        * positions.
        *
        */
        public void Tutorial_1e()
	    {
		    Initialize( "1e", "Post optimization roundlotting", true );
		    m_InitPf.AddAsset("CASH", 1.0);
    		
		    // Set round lot info
		    for(int i=0; i<m_Data.m_AssetNum; i++) 
		    {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) == 0) //case-insensitive comparison
				    continue;

			    CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
			    if (asset != null) 
			    {
				    // Round lot requires the price of each asset
				    asset.SetPrice(m_Data.m_Price[i]);

				    // Set lot size to 1000
				    asset.SetRoundLotSize(1000);
			    }
		    }

		    // Create a case object with trade universe
		    double portfolioBaseValue = 10000000;
		    m_Case = m_WS.CreateCase("Case 1e", m_InitPf, m_TradeUniverse, portfolioBaseValue, 0.0);
		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
		    util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);
    		
		    RunOptimize();

            OutputTradeList(true);

            OutputTradeList(false);
	    }

        /**\brief Additional Statistics for Initial/Optimal Portfolio
        * 
        * The sample code shows how to retrieve the statistics for the 
        * initial and optimal portfolio. The available statistics are
        * return, common factor/specific risk, short rebate, and 
        * information ratio. The statistics can be retrieved for any
        * given portfolio as well.
        *
        */
        public void Tutorial_1f()
	    {
		    Initialize( "1f", "Additional Statistics for Initial/Optimal Portfolio" );

		    // Create a case object, null trade universe
		    m_Case = m_WS.CreateCase("Case 1f", m_InitPf, null, 100000, 0.0);
		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

		    SetAlpha();

		    CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
		    util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
    		
		    RunOptimize();
    		
		    Console.WriteLine("Initial portfolio statistics:");
		    Console.WriteLine("Return = {0:0.0000}", m_Solver.Evaluate(EEvalType.eRETURN, null) );
            double factorRisk = m_Solver.Evaluate(EEvalType.eFACTOR_RISK, null);
            double specificRisk = m_Solver.Evaluate(EEvalType.eSPECIFIC_RISK, null);
            Console.WriteLine("Common factor risk = {0:0.0000}", factorRisk );
            Console.WriteLine("Specific risk = {0:0.0000}", specificRisk );
            Console.WriteLine("Active risk = {0:0.0000}", Math.Sqrt(factorRisk*factorRisk+specificRisk*specificRisk));
            Console.WriteLine("Short rebate = {0:0.0000}", m_Solver.Evaluate(EEvalType.eSHORT_REBATE, null) );
            Console.WriteLine("Information ratio = {0:0.0000}", m_Solver.Evaluate(EEvalType.eINFO_RATIO, null) );
		    Console.WriteLine(); 

		    CPortfolio portfolio = m_Solver.GetPortfolioOutput().GetPortfolio();
		    Console.WriteLine("Optimal portfolio statistics:");
            Console.WriteLine("Return = {0:0.0000}", m_Solver.Evaluate(EEvalType.eRETURN, portfolio) );
            factorRisk = m_Solver.Evaluate(EEvalType.eFACTOR_RISK, portfolio);
            specificRisk = m_Solver.Evaluate(EEvalType.eSPECIFIC_RISK, portfolio);
            Console.WriteLine("Common factor risk = {0:0.0000}", factorRisk);
            Console.WriteLine("Specific risk = {0:0.0000}",  specificRisk);
            Console.WriteLine("Active risk = {0:0.0000}", Math.Sqrt(factorRisk * factorRisk + specificRisk * specificRisk));
            Console.WriteLine("Short rebate = {0:0.0000}", m_Solver.Evaluate(EEvalType.eSHORT_REBATE, portfolio) );
            Console.WriteLine("Information ratio = {0:0.0000}", m_Solver.Evaluate(EEvalType.eINFO_RATIO, portfolio) );
		    Console.WriteLine();
	    }

        /**\brief Optimization Problem/Output Portfolio Type
        * 
        * The sample code shows how to tell if the optimization
        * problem is convex, and if the output portfolio is heuristic
        * or optimal.
        *
        */
        public void Tutorial_1g()
	    {
		    Initialize( "1g", "Optimization Problem/Output Portfolio Type" );

		    // Create a case object, null trade universe
		    m_Case = m_WS.CreateCase("Case 1g", m_InitPf, null, 100000, 0.0);
		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
    		
		    CConstraints constraints = m_Case.InitConstraints();

		    // Set max # of assets to be 6
		    CParingConstraints paring = constraints.InitParingConstraints(); 
		    paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMax(6);

		    Console.WriteLine("Is type of optimization problem convex: " + (m_Case.IsConvex() ? "Yes" : "No"));

            //retrieve paring constraints
            Console.WriteLine("max number of assets is: {0:D}\n", 
                paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_ASSETS).GetMax());

		    RunOptimize();

		    CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		    if ( output != null ) 
		    {
			    Console.WriteLine("The output portfolio is " + (output.IsHeuristic() ? "heuristic" : "optimal"));
			    CIDSet softBoundSlackIDs = output.GetSoftBoundSlackIDs();
			    if (softBoundSlackIDs.GetCount() > 0)
				    Console.WriteLine("Soft bound violation found");
		    }
	    }

        /**\brief Composites and Linked Assets
        *
        * Composite assets are themselves portfolios.  Examples of composite assets 
        * include ETFs, Mutual Funds, or manager portfolios (funds of funds).  The 
        * risk exposure of the composite can be aggregated from its constituents. 
        * Unlike regular assets, the composite may have non-zero specific covariance
        * with other assets in the initial portfolio. This is due to the fact that 
        * the composite may also contain these assets.
        *
        * Linked assets share some underlying fundamentals and have non-zero specific 
        * covariance between them. In order to compute portfolio risk when composites/linked 
        * assets are part of the investment universe or included in the benchmark, we need to
	    * link the composite portfolio with the composite asset, which will allow optimizer
        * to compute specific covariance between the composite assets/linked assets and the
        * other assets. 
        *
        * The Tutorial_2a sample code illustrates how to set up a composite asset and add it
        * to the trade universe: 
        */
        public void Tutorial_2a()
        {
            Initialize("2a", "Composite Asset");

            // Create a portfolio to represent the composite
            // add its constituents to the portfolio
            // in this example, all assets and equal weighted 
            CPortfolio pComposite = m_WS.CreatePortfolio("Composite");
            for (int i = 0; i < m_Data.m_AssetNum; i++)
                pComposite.AddAsset(m_Data.m_ID[i], 1.0 / m_Data.m_AssetNum);

            // Create a composite asset COMP1
            CAsset pAsset = m_WS.CreateAsset("COMP1", EAssetType.eCOMPOSITE);
            // Link the composite portfolio to the asset
            pAsset.SetCompositePort(pComposite);      

            // add the composite to the trading universe
            m_TradeUniverse = m_WS.GetPortfolio("Trade Universe");
            m_TradeUniverse.AddAsset("COMP1", 0.0);

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 2a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Futures Contracts 
       *
       * Futures contracts, such as equity index futures, are settled daily and have
       * no market value.  However, they are risky assets that can be used to hedge 
       * portfolio risk (by selling the Futures contract) or increase risk.  Equity 
       * Futures can be used to gain equity market exposure with excess portfolio
       * cash, until the portfolio manager has decided which stocks to buy.
       *
       * Futures can be included in an optimization problem by indicating which assets 
       * in the list are futures and linking the composite portfolio to the futures asset.  
       * Since Futures do not have market value, they have no weight in the portfolio (where 
       * portfolio weight is defined as position market value/total portfolio market
       * value).  However, Futures do have an effective weight based on the contract
       * specifications (e.g.,  [$250 x S&P500 Index x Number of Contracts]/Portfolio 
       * Market Value). 
       *
       * Futures do not have currency risk, since they are settled daily and the 
       * replicating portfolio of cash and stock index in any currency has zero market
       * value. Since Futures do not have market value, they behave differently from 
       * regular assets in the optimizer.  Equity Futures contracts have the same 
       * factor exposures as the underlying spot index. 
       *
       * Tutorial_2b treats the newly created composite as a futures contract, which 
       * hedges portfolio risk.  
       */
        public void Tutorial_2b()
        {
            Initialize("2b", "Futures Contracts");

            // Create a portfolio to represent the composite
            // add its constituents to the portfolio
            // in this example, all assets and equal weighted 
            CPortfolio pComposite = m_WS.CreatePortfolio("Composite");
            for (int i = 0; i < m_Data.m_AssetNum; i++)
                pComposite.AddAsset(m_Data.m_ID[i], 1.0 / m_Data.m_AssetNum);

            // Create a composite asset COMP1 as FUTURES
            CAsset pAsset = m_WS.CreateAsset("COMP1", EAssetType.eCOMPOSITE_FUTURES);
            // Link the composite portfolio the asset
            pAsset.SetCompositePort(pComposite);

            // add the composite to the trading universe
            m_TradeUniverse = m_WS.GetPortfolio("Trade Universe");
            m_TradeUniverse.AddAsset("COMP1", 0.0);

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 2b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Cash Contributions, Cash Withdrawal, Invest All Cash
        *
        * Investment managers tend to have cash balances that increase prior to the next
        * portfolio rebalancing. These cash balances come from corporate actions (such as
        * dividends or spin-offs) as well as investor contributions.  Managers often want
        * to maintain a certain cash balance (in terms of portfolio weight) for market
        * timing or other reasons (e.g., anticipated redemptions that avoid liquidating
        * stocks, which in turn helps avoid transaction costs and potential taxes). 
        *
        * There are a couple of ways to model cash in the optimization problem:
        * - Add a cash or currency asset into the initial portfolio.
        * - Specify a cash contribution when initializing the CCase object.
        *
        * There should be only one cash asset in the initial portfolio. The currency asset
        * may be specified more than once and is used to model different currency holdings.
        * It is treated differently than a regular asset in determining the non-linear
        * transaction cost.
        *
        * To control the final cash position, a manager can manage the cash withdrawal 
        * level in the optimal portfolio by setting an asset range constraint in the cash
        * asset. Please refer to Tutorial_3a on how to set the asset range. To invest all
        * cash, it is simply set the lower bound and upper bound of the cash object to 0.
        *
        * In Tutorial_2c example, we demonstrate how to add a 20% cash contribution to 
        * the initial portfolio:
        */
        public void Tutorial_2c()
        {
            Initialize("2c", "Cash contribution");

            // Create a case object. Set initial portfolio
            // 20% cash contribution
            m_Case = m_WS.CreateCase("Case 2c", m_InitPf, null, 100000, 0.2);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Asset Range Constraints/Penalty
        *
        * Asset range constraint is to limit the weight of some asset in the optimal portfolio.
        * You can set the upper and lower bound of the range. The default is from -OPT_INF to +OPT_INF.
        *
        * By setting the range of the assets, you can implement various transaction strategies. 
        * For instance, you can disallow selling an asset by setting the lower bound of the 
        * constraint to the initial weight.
        *
        * In Tutorial_3a, we want to limit the maximum weight of any asset in the optimal 
        * portfolio to be 30%. An asset-level penalty is set for USA11I1.
        */
        public void Tutorial_3a()
        {
            Initialize("3a", "Asset Range Constraints");

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            for (int j = 0; j < m_Data.m_AssetNum; j++)
            {
                CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);
                info.SetLowerBound(0.0, ERelativeMode.eABSOLUTE);
                info.SetUpperBound(0.3, ERelativeMode.eABSOLUTE);

                // Set asset penalty
     		    if ( m_Data.m_ID[j].Equals("USA11I1") ) {
			        // Set target to be 0.1; min = 0.0 and max = 0.3
 			        info.SetPenalty(0.1, 0.0, 0.3);
 		        }
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            //constraint retrieval
            PrintLowerAndUpperBounds(ref linear);

            RunOptimize();
        }

        /**\brief Relative Asset Range Constraints/Penalty
        *
        * Relative asset range constraint is to limit the weight of some asset in the optimal portfolio
        * relative to a reference portfolio. For example, you can set relative weight of +5% and -5%
        * relative to the benchmark weight.
        *
        * For asset penalty, the target, lower, and upper values are in absolute weights. For benchmark relative
        * penalty, you will need to shift the values by the benchmark weight.
        *
        * In Tutorial_3a2, we want to limit the weight of any asset except USA11I1 in the optimal 
        * portfolio to be +5% and -5% relative to the benchmark portfolio. 
        *
        * An asset-level penalty of +3% and -3% relative to benchmark weight is set for USA11I1 as absolute weights.
        */
        public void Tutorial_3a2()
        {
	        Initialize( "3a2", "Relative Asset Range Constraints" );
         
	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 3a2", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints(); 
	        for(int j=0; j<m_Data.m_AssetNum; j++) {
 		        CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);

		        if (m_Data.m_ID[j].Equals("USA11I1")) {
			        // Set asset penalty, since benchmark weight is 0.169809
			        // min = 0.169809 - 0.03 = 0.139809
			        // max = 0.169809 + 0.03 = 0.199809
			        info.SetPenalty(0.169809, 0.139809, 0.199809);
		        }
		        else {
			        // Set relative asset range constraint
                    info.SetLowerBound(-0.05, ERelativeMode.ePLUS);
                    info.SetUpperBound(0.05, ERelativeMode.ePLUS);
			        info.SetReference(m_BMPortfolio);
		        }
	        }

	        CUtility util = m_Case.InitUtility();

	        RunOptimize();
        }

        /**\brief Factor Range Constraints
       *
       * In this example, the initial portfolio exposure to Factor_1A is 0.0781, and 
       * we want to reduce the exposure to Factor_1A to 0.01.
       */
        public void Tutorial_3b()
        {
            Initialize("3b", "Factor Range Constraints");

            CRiskModel pRiskModel = m_WS.GetRiskModel("GEM");

            // show existing exposure to FACTOR_1A
            double exposure = pRiskModel.ComputePortExposure(m_InitPf, "Factor_1A");
            Console.WriteLine("Initial portfolio exposure to Factor_1A = {0:0.0000} ", exposure);

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(pRiskModel);

            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linear.SetFactorRange("Factor_1A");
            info.SetLowerBound(0.00, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(0.01, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null)
            {
                CSlackInfo slackInfo = output.GetSlackInfo("Factor_1A");

                if (slackInfo != null)
                {
                    Console.WriteLine("Optimal portfolio exposure to Factor_1A = {0:0.0000}",
                                      slackInfo.GetSlackValue());

                    //Get the KKT term of the factor range constraint.
                    CAttributeSet impact = slackInfo.GetKKTTerm(true);
                    PrintAttributeSet(impact, "factor constraint KKT term");
                }
            }
        }

        /**\brief Beta Constraint
        *
        * The optimal portfolio in Tutorial_1c without any constraints has a Beta of .7181
        * to the benchmark, so we specify a range 0.9 to 1.0 for the Beta in this example 
        * to constrain the result.
        * 
        * This self-documenting sample code illustrates how to use the Barra Optimizer to 
        * restrict market exposure with a beta constraint. 
        */
        public void Tutorial_3c()
        {
            Initialize("3c", "Beta Constraint");

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3c", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linear.SetBetaConstraint();
            info.SetLowerBound(0.90, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(1.0, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();

	        //Get the slack information for beta constraint.
	        String constraintID = info.GetID();
	        CPortfolioOutput output = m_Solver.GetPortfolioOutput();
	        CSlackInfo slackInfo = output.GetSlackInfo(constraintID);

            //Get the KKT term of the beta constraint.
	        CAttributeSet impact = slackInfo.GetKKTTerm(true);
            PrintAttributeSet(impact, "Beta constraint KKT term");
        }

        /**\brief Multiple Beta Constraints
        *
        * A beta constraint relative to the benchmark portfolio in utility can be set by
        * calling SetBetaConstraint() which we limit to 0.9 in this case. To set the additional 
        * beta constraints, first compute asset betas for the universe, then pass the betas as 
        * coefficients for the general linear constraint. You can call CRiskModel::ComputePortBeta() 
        * to verify the optimal portfolio's beta to the different benchmarks.
        * 
        * This self-documenting sample code illustrates how to use the Barra Optimizer to 
        * restrict market exposure with multiple beta constraints. 
        */
        public void Tutorial_3c2()
        {
	        Initialize( "3c2", "Multiple Beta Constraints" );
         
	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 3c2", m_InitPf, m_TradeUniverse, 100000, 0.0);

	        CRiskModel rm = m_WS.GetRiskModel("GEM");
	        m_Case.SetPrimaryRiskModel(rm);

	        // Set the beta constraint relative to the benchmark in utility (m_pBMPortfolio)
	        CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints(); 
	        CConstraintInfo info = linear.SetBetaConstraint();
	        info.SetLowerBound(0.9);
	        info.SetUpperBound(0.9);

	        // Set the beta constraint relative to a second benchmark (m_pBM2Portfolio)
            CAttributeSet assetBetaSet = rm.ComputePortAssetBeta(m_TradeUniverse, m_ModelPortfolio);
	        CConstraintInfo info2 = linear.AddGeneralConstraint(assetBetaSet);
	        info2.SetLowerBound(1.1);
	        info2.SetUpperBound(1.1);

	        CUtility util = m_Case.InitUtility();

	        // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        RunOptimize();

	        CPortfolioOutput output = m_Solver.GetPortfolioOutput();
	        double beta = rm.ComputePortBeta(output.GetPortfolio(), m_BMPortfolio);
	        Console.WriteLine("Optimal portfolio's beta relative to benchmark in utility = {0:0.0000}", beta);
            double beta2 = rm.ComputePortBeta(output.GetPortfolio(), m_ModelPortfolio);
	        Console.WriteLine("Optimal portfolio's beta relative to second benchmark = {0:0.0000}", beta2);
        }

        /**\brief User Attribute Constraints
        *
        * You can associate additional user attributes to each asset and constraint the 
        * optimal portfolio’s exposure to these attributes. For instance, you can assign
        * Country, Currency, GICS Sector attribute for each asset and limit your bets on
        * their exposures. The group name and its attributes can be arbitrary and you
        * can use it to model a variety of custom attributes.
        *
        * This self-documenting sample code illustrates how to use the Barra Optimizer 
        * to restrict allocation of assets and total risk in a specific GICS sector, 
        * in this case, Information Technology.  
        */
        public void Tutorial_3d()
        {
            Initialize("3d", "User Attribute Constraints");

            // Set up group attribute
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    // Set GICS Sector attribute
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i], 1.0);
            }

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3d", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();
            // Set a constraint to GICS_SECTOR - Information Technology
            CLinearConstraints linear = constraints.InitLinearConstraints();
            CConstraintInfo info = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");

            // limit the exposure to 20%
            info.SetLowerBound(0.0, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(0.2, ERelativeMode.eABSOLUTE);

            // Set the total risk constraint by group for GICS_SECTOR - Information Technology
            CRiskConstraints riskConstraint = constraints.InitRiskConstraints();
            CConstraintInfo risk = riskConstraint.AddTotalConstraintByGroup("GICS_SECTOR", "Information Technology", null);
            risk.SetUpperBound(0.1);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            //constraint retrieval
            PrintLowerAndUpperBounds(ref linear);

            RunOptimize();
        }

        /**\brief Setting Relative Constraints
        *
        * In relative constraints, you can specify a positive or negative constant to
        * be added or multiplied to the reference portfolio's exposure to a factor, 
        * such as risk index, or industry.  The reference portfolio may be your 
        * benchmark, market portfolio, initial portfolio or any arbitrary portfolio.
        * This constant determines the range for the exposure to that factor in the 
        * optimal portfolios.  
        *
        * In the Tutorial_3e example, we want to set the factor exposure to Factor_1A
        * to be within +/- 0.10 of the reference portfolio and a maximum of 50% of
        * exposures to GICS Sector “Information Technology” relative to the reference
        * portfolio. 
        */
        public void Tutorial_3e()
        {
            Initialize("3e", "Relative Constraints");

            // Set up group attribute
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    // Set GICS Sector attribute
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i], 1.0);
            }

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3e", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set a constraint to GICS_SECTOR - Information Technology
            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info1 = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");

            // limit the exposure to 50% of the reference portfolio
            info1.SetReference(m_BMPortfolio);
            info1.SetLowerBound(0.0, ERelativeMode.eMULTIPLE);
            info1.SetUpperBound(0.5, ERelativeMode.eMULTIPLE);

            CConstraintInfo info2 = linear.SetFactorRange("Factor_1A");

            // limit the Factor_1A exposure to +/- 0.01 of the reference portfolio
            info2.SetReference(m_BMPortfolio);
            info2.SetLowerBound(-0.01, ERelativeMode.ePLUS);
            info2.SetUpperBound(0.01, ERelativeMode.ePLUS);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            //constraint retrieval
            PrintLowerAndUpperBounds(ref linear);

            RunOptimize();
        }

        /**\brief Setting Transaction Type
        *
        * There are a number of transaction types that you can specify in the
        * CLinearConstraints object: Allow All, Buy None, Sell None, Short None, Buy
        * from Universe, Sell None and Buy from Universe, Buy/Short from Universe, 
        * Disallow Buy/Short, Disallow Sell/Short Cover, Buy/Short from Universe and
        * No Sell/Short Cover. 
        *
        * They are basically different transaction strategies in the optimization 
        * problem, and these strategies can be replicated using Asset Range 
        * Constraints.  The transaction type is a more convenient way to set up these
        * strategies.  You can refer to the Reference Guide for the details of each
        * strategy. See Section of ETranxType.
        *
        * The Tutorial_3f sample code shows how to buy from a universe without selling 
        * any existing positions:
        */
        public void Tutorial_3f()
        {
            Initialize("3f", "Transaction Type");

            // Create a case object. Set initial portfolio and trade universe
            // Contribute 30% cash for buying additional securities
            m_Case = m_WS.CreateCase("Case 3f", m_InitPf, m_TradeUniverse, 100000, 0.3);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set Transaction Type to Sell None/Buy From Universe
            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSELL_NONE_BUY_FROM_UNIV);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Crossover Option
        *
        * A crossover trade makes an asset change from long position to short position, 
        * or vice versa. The following sample shows how to disable the crossover option.
        * If crossover option is disabled, an asset is not allowed to change position 
        * from long to short or from short to long. Crossover is enabled by default.
        *
        */
        public void Tutorial_3g()
        {
            Initialize("3g", "Crossover Option", true);
            m_InitPf.AddAsset("CASH", 1);

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 3g", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            CLinearConstraints linear = constraints.InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eBUY_SHORT_FROM_UNIV);

            // Disable crossover
            linear.EnableCrossovers(false);

            CConstraintInfo info = linear.SetAssetRange("USA11I1");
            info.SetLowerBound(-1.0, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(1.0, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Total Active Weight Constraint
        *
        * You can set a constraint on the total absolute value of active weights on the optimal portfolio or for a group
        * of assets. To set total active weight by group, you will need to first set the asset
        * group attribute, then set the constraint by calling AddTotalActiveWeightConstraintByGroup().
        *
        * Tutorial_3h illustrates how to constrain the sum of active weights in the optimal portfolio to less than 1%.
        * The reference portfolio used to calculate active weights is the m_pBMPortfolio object.
        */
        public void Tutorial_3h()
        {
	        Initialize( "3h", "Total Active Weight Constraint" , true);

	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 3h", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CConstraints constraints = m_Case.InitConstraints();
            CConstraintInfo info = constraints.SetTotalActiveWeightConstraint();
	        info.SetLowerBound(0);
	        info.SetUpperBound(0.01);
	        info.SetReference(m_BMPortfolio);
        	
	        CUtility util = m_Case.InitUtility();

	        RunOptimize();

	        double sumActiveWeight=0;
	        CPortfolioOutput output = m_Solver.GetPortfolioOutput();
	        if (output!=null) {
		        CPortfolio optimalPort = output.GetPortfolio();
		        CIDSet idSet = optimalPort.GetAssetIDSet();
			    String assetID = idSet.GetFirst();
			    for (int i = 0; i < idSet.GetCount(); i++, assetID = idSet.GetNext()){
			        double benchWeight = m_BMPortfolio.GetAssetWeight(assetID);
			        if (benchWeight != barraopt.OPT_NAN) {
				        sumActiveWeight += Math.Abs(benchWeight - optimalPort.GetAssetWeight(assetID));
			        }
		        }
	        }
            Console.WriteLine("Total active weight = {0:0.0000}", sumActiveWeight);
        }

        /**\brief Long-Short Optimization: Dollar Neutral Strategy
        *
        * Long-Short strategies are common among portfolio managers. One particular use case is the dollar-neutral 
        * strategy, in which the long and short sides are equally invested such that the net portfolio value is 0. 
        * The optimal portfolio is said to be dollar neutral.
        *
        * This tutorial demonstrates how dollar-neutral portfolio managers can set up their optimization problem 
        * if the cash asset is not managed by them. Barra Open Optimizer provides the flexibility to disable the 
        * balance constraint and allow the cash asset to be optional.
        *
        * Since the portfolio balance constraint is enabled by default,  you need to  first disable the constraint by
        * calling EnablePortfolioBalanceConstraint(false). Then, add a general linear constraint to replace the 
        * Balance Constraint.
        * In this case, the general linear constraint would be the sum of all non-cash holdings = 0.
        *
        * Tutorial_3i illustrates how to set up the dollar-neutral strategy by replacing the balance constraint with 
        * a customized general linear constraint. 
        */
        public void Tutorial_3i()
        {
	        Initialize( "3i", "Dollar Neutral Strategy", true);

	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 3i", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CConstraints constraints = m_Case.InitConstraints();
	        CLinearConstraints linear = constraints.InitLinearConstraints();
	        //  Disable the default portfolio balance constraint
	        linear.EnablePortfolioBalanceConstraint(false);
	        // Set equal weights
	        CAttributeSet coeffs = m_WS.CreateAttributeSet();
	        for(int i=0; i<m_Data.m_AssetNum; i++) {
                if (m_Data.m_ID[i].Equals("CASH"))
			        continue;
		        coeffs.Set( m_Data.m_ID[i], 1.0 );
	        }
	        CConstraintInfo info = linear.AddGeneralConstraint(coeffs);
	        // Set the upper & lower bounds of the general linear constraint 
	        info.SetLowerBound(0);
	        info.SetUpperBound(0);
	
	        CUtility util = m_Case.InitUtility();

	        RunOptimize();

	        double sumWeight=0;
	        CPortfolioOutput pOutput = m_Solver.GetPortfolioOutput();
	        if (pOutput!=null) {
		        CPortfolio optimalPort = pOutput.GetPortfolio();
		        CIDSet idSet = optimalPort.GetAssetIDSet();
                String assetID = idSet.GetFirst();
			    for (int i = 0; i < idSet.GetCount(); i++, assetID = idSet.GetNext())
			        if(!assetID.Equals("CASH"))
				        sumWeight += optimalPort.GetAssetWeight(assetID);
	        }
	        Console.WriteLine("Sum of all weights = {0:0.0000}", sumWeight);
        }

        /**\brief Asset free range linear penalty
        *
        * Asset penalty functions are used to tilt portfolios toward user-specified targets on asset weights. Free range linear penalty is one type of
        * penalty function that allows user to specify an upper and lower bound of the target, where the penalty will be zero if the slack variable
        * falls within the free range. User can also specify the penalty rate for each side should the slack variable falls outside of the free range.
        *
        * Tutorial_3j illustrates how to set free range linear penalty that penalizes the objective function when a non-cash asset weight is outside -10% to 10%.
        * 
        */
        public void Tutorial_3j()
        {
	        Initialize( "3j", "Asset Free Range Linear Penalty" );
 
	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 3j", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints(); 
	        for(int j=0; j<m_Data.m_AssetNum; j++) {
		        // Set asset free range penalty
		        if (!m_Data.m_ID[j].Equals("CASH")) {
                    CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);
                    // Set free range to -0.1 to 0.1, with downside slope = -0.01, upside slope = 0.01
			        info.SetFreeRangeLinearPenalty(-0.01, 0.01, -0.10, 0.10);
		        }
	        }

	        CUtility util = m_Case.InitUtility();

	        RunOptimize();
        }

        /**\brief Maximum Number of Assets
        *
        * To set a maximum number of assets in the optimal portfolio, you can set the
        * limit with the CParingConstraints class. For long-short optimizations, the 
        * limit applies to both the long side and the short side. This constraint is 
        * not available for Risk Target or Expected Return Target portfolio optimizations.
        *
        * Tutorial_4a illustrates how to replicate a benchmark portfolio (minimize the 
        * tracking error) with less number of assets. In this case, we set the maximum 
        * number of assets to be 6.
        * This tutorial also illustrates how to estimate utility upperbound. 
        */
        public void Tutorial_4a()
        {
            Console.WriteLine("======== Running Tutorial 4a ========");
            Console.WriteLine("Max # of assets and estimated utility upper bound");
            SetupDumpFile ("4a");

            // Create WorkSpace and setup Risk Model data
            SetupRiskModel();

            // Create an initial holding portfolio 
            // initial portfolio with cash only
            // replicate the benchmark risk with max # of assets
            m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");
            m_InitPf.AddAsset("CASH", 1.0);

            m_TradeUniverse = m_WS.CreatePortfolio("Trade Universe");
            m_BMPortfolio = m_WS.CreatePortfolio("Benchmark");
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!m_Data.m_ID[i].Equals("CASH"))
                {
                    m_TradeUniverse.AddAsset(m_Data.m_ID[i], 0.0);
                    m_BMPortfolio.AddAsset(m_Data.m_ID[i], 0.1);
                }
            }

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 4a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Invest all cash
            CLinearConstraints linear = constraints.InitLinearConstraints();
            CConstraintInfo info = linear.SetAssetRange("CASH");
            info.SetLowerBound(0.0, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(0.0, ERelativeMode.eABSOLUTE);

            // Set max # of assets to be 6
            CParingConstraints paring = constraints.InitParingConstraints();
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMax(6);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimizeReportUtilUB();
        }

        /**\brief Holding and Transaction Size Thresholds
        *
        * The minimum holding level is measured as a percentage, expressed in decimals,
        * of the base value (in this example, 0.04 is 4%).  This feature ensures
        * that the optimizer will not recommend trades too small to be meaningful in 
        * your analysis.
        *
        * Minimum transaction size is measured as a percentage of the base value
        * (in this example, 0.02 is 2%). 
        */
        public void Tutorial_4b()
        {
            Initialize("4b", "Min Holding Level and Transaction Size");

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 4b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set minimum holding threshold; both for long and short positions
            // in this example 4%
            CParingConstraints paring = constraints.InitParingConstraints();
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_LONG, 0.04);
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_SHORT, 0.04);
            paring.EnableGrandfatherRule();					// Enable grandfather rule

            // Set minimum trade size; both for long side and short side,
            // in this example 2%
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_LONG, 0.02);
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_SHORT, 0.02);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Soft Turnover Constraint
        *
        * Maximum turnover is specified in percentage, expressed in decimals, (in this
        * example, 0.2 is 20.00%). This considers all transactions, including buys, 
        * sells, and short sells.  Covered buys are measured as a percentage of initial
        * portfolio value adjusted for any cash infusions or withdrawals you have 
        * specified.  If you select Use Base Value, turnover is measured as a 
        * percentage of the Base Value.  
        */
        public void Tutorial_4c()
        {
            Initialize("4c", "Soft Turnover Constraint");

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 4c", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set soft turnover constraint
            CTurnoverConstraints turnover = constraints.InitTurnoverConstraints(false);
            CConstraintInfo info = turnover.SetNetConstraint();
            info.SetSoft(true);
            info.SetUpperBound(0.2, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Buy Side Turnover Constraint
        *
        * The following tutorial limits the maximum turnover for the buy side.
        *
        */
        public void Tutorial_4d()
        {
            Initialize("4d", "Limit Buy Side Turnover Constraint");

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 4d", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set buy side turnover constraint
            CTurnoverConstraints turnover = constraints.InitTurnoverConstraints(false);
            CConstraintInfo info = turnover.SetBuySideConstraint();
            info.SetUpperBound(0.1, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Paring by Group
        *
        * To set paring constraint by group, you will need to first set the asset
        * group attribute, then set the limit with the CParingConstraints class. 
        *
        * Tutorial_4e illustrates how to set a maximum number of assets for GICS_SECTOR/
        * Information Technology to one asset. It also sets a holding threshold constraint for
        * the asset in GICS_SECTOR/Information Technology to be at least 0.2.
        */
        public void Tutorial_4e()
        {
	        Initialize( "4e", "Paring by group" );

	        for( int i = 0; i<m_Data.m_AssetNum; i++)
	        {
		        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
		        if (asset!=null)
			        asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
	        }

	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 4e", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CConstraints constraints = m_Case.InitConstraints();

	        // Set max # of asset in GICS Sector/Information Technology to 1
	        CParingConstraints paring = constraints.InitParingConstraints();
            CParingRange range = paring.AddAssetTradeParingByGroup(EAssetTradeParingType.eNUM_ASSETS, "GICS_SECTOR", "Information Technology");
	        range.SetMax(1);

	        // Set minimum holding threshold for GICS Sector/Information Technology to 0.2
            paring.AddLevelParingByGroup(ELevelParingType.eMIN_HOLDING_LONG, "GICS_SECTOR", "Information Technology", 0.2);

	        CUtility util = m_Case.InitUtility();

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        RunOptimize();
        }

        /**\brief Net turnover limit by group
        *
        * To set turnover constraint by group, you will need to first set the asset
        * group attribute, then set the limit with the CTurnoverConstraints class. 
        *
        * Tutorial_4f illustrates how to limit turnover to 10% for assets having the Information Technology attribute
        * in the GICS_SECTOR group, while limiting overall portfolio turnover to 30%.
        */
        public void Tutorial_4f()
        {
	        Initialize( "4f", "Net turnover by group" );

	        // Set up group attribute
	        for(int i=0; i<m_Data.m_AssetNum; i++)
	        {
		        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
		        if (asset!=null)
			        // Set GICS Sector attribute
			        asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
	        }
         
	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 4f", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));


	        // Set the net turnover by group for GICS_SECTOR - Information Technology
	        CTurnoverConstraints toCons = m_Case.InitConstraints().InitTurnoverConstraints();
	        CConstraintInfo infoGroup = toCons.AddNetConstraintByGroup("GICS_SECTOR", "Information Technology");
	        infoGroup.SetUpperBound(0.03);

	        // Set the overall portfolio turnover
	        CConstraintInfo info = toCons.SetNetConstraint();
	        info.SetUpperBound(0.3);

	        CUtility util = m_Case.InitUtility();

	        RunOptimize();
        }

        /**\brief Paring penalty
        * 
        * Paring penalty is used to tell the optimizer make a tradeoff between "violating a paring constraint" 
        * and "getting a better utility".  Violation of of the paring constraints would generate disutilty at the 
        * rate specified by the user.
        *
        * Tutorial_4g illustrates how to set paring penalty
        */
        public void Tutorial_4g()
        {
	        Initialize( "4g", "Paring penalty" );

	        // Create a case object. Set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 4g", m_InitPf, m_TradeUniverse, 100000, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CConstraints constraints = m_Case.InitConstraints();

	        CParingConstraints paring = constraints.InitParingConstraints(); 
	        paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_TRADES).SetMax(2);		// Set maximum number of trades
	        paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMin(5);		// Set minimum number of assets

	        // Set paring penalty. Violation of the "max# trades=2" constraint would generate 0.005 disutility per extra trade.
	        paring.SetPenaltyPerExtraTrade(0.005);

	        CUtility util = m_Case.InitUtility();

	        // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
	        RunOptimize();
        }


        /**\brief Piecewise Linear Transaction Costs
        *
        * A simple way to model transactions costs is a flat-fee-per-share (the 
        * commission component) plus the percentage that accounts for trade 
        * volume (e.g., the bid spread for small, illiquid stocks).  These can be set
        * as default market values and then overridden at the asset level by 
        * associating transactions costs with individual securities.  This 
        * unfortunately does not capture the non-linear cost of market impact
        * (trade size related to trading volume).
        *
        * The piecewise linear transactions cost penalty are set in the CAsset class,
        * as shown in this simple example using 2 cents per share and 20 basis
        * points for the first 10,000 dollar buy cost. For more than 10,000 dollar or
        * short selling, the cost is 2 cents per share and 30 basis points.
        *
        * In this example, the 2 cent per share transaction commission is translated
        * into a relative weight via the share’s price. The simple-linear market impact
        * cost of 20 basis points is already in relative-weight terms.  
        *
        * In the case of Asset 1 (USA11I1), its share price is 23.99 USD, so the $.02 
        * per share cost becomes .02/23.99= .000833681, and added to the 20 basis 
        * points cost .002 + .000833681= .002833681. 
        *
        * The short sell cost is higher at 30 basis points, so that becomes 
        * 0.003 +  .00833681= .003833681, in terms of relative weight. 
        *
        * The breakpoints and slopes can be used to specify a piecewise linear cost 
        * function that can account for increasing market impact based on trade size
        * (approximating a curve by piecewise linear segments).  In this simple 
        * example, the four (4) breakpoints have a center at the initial weight of 
        * the asset in the portfolio, with leftmost breakpoint at negative infinity
        * and the rightmost breakpoint at positive infinity. The breakpoints on the
        * X-axis represent relative portfolio weights, while the Y-axis slopes 
        * represent the relative cost of trading that asset. 
        *
        * If you have a high-value portfolio to manage, and a number of smallcap stocks
        * with very high alphas, the optimizer may suggest that you execute a trade 
        * larger than the average daily trading volume for that stock, and therefore
        * have a very large market impact.  Specifying piecewise linear transactions 
        * cost penalties can trim back these suggested trade sizes to more realistic 
        * levels.
        */
        public void Tutorial_5a()
        {
            Console.WriteLine("======== Running Tutorial 5a ========");
            Console.WriteLine("Piecewise Linear Transaction Costs");
            SetupDumpFile("5a");

            // Create WorkSpace and setup Risk Model data
            SetupRiskModel();

            // Create an initial holding portfolio with the hard coded data
            // portfolio with no Cash
            m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");
            m_InitPf.AddAsset("USA11I1", 0.3);
            m_InitPf.AddAsset("USA13Y1", 0.7);

            // Set the transaction cost
            CAsset asset = m_WS.GetAsset("USA11I1");
            if (asset != null)
            {
                // the price is 23.99

                // the 1st 10,000, 
                // the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.002833681, 10000.0);

                // from 10,000 to +OPT_INF, 
                // the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.003833681, barraopt.OPT_INF);

                // Sell cost is 30 basis + $0.02 per share =  0.003 + 0.02/23.99
                asset.AddPWLinearSellCost(0.003833681, barraopt.OPT_INF);
            }

            asset = m_WS.GetAsset("USA13Y1");
            if (asset != null)
            {
                // the price is 34.19

                // the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
                asset.AddPWLinearBuyCost(0.00287745, barraopt.OPT_INF);

                // Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
                asset.AddPWLinearSellCost(0.00387745, barraopt.OPT_INF);
            }

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 5a", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            util.SetTranxCostTerm(1.0);

            RunOptimize();
        }

        /**\brief Nonlinear Transaction Costs
        *
        * Tutorial_5b illustrates how to set up the coefficient c, p and q for 
        * nonlinear transaction costs
        */
        public void Tutorial_5b()
        {
            Console.WriteLine("======== Running Tutorial 5b ========");
            Console.WriteLine("Nonlinear Transaction Costs");
            SetupDumpFile ("5b");

            // Create WorkSpace and setup Risk Model data
            SetupRiskModel();

            // Create an initial holding portfolio with the hard coded data
            // portfolio with no Cash
            m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");
            m_InitPf.AddAsset("USA11I1", 0.3);
            m_InitPf.AddAsset("USA13Y1", 0.7);

            // Asset nonlinear transaction cost
            // c = 0.00005, p = 1.1, and q = 0.01
            m_WS.GetAsset("USA11I1").SetNonLinearTranxCost(0.00005, 1.1, 0.01);

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 5b", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // c = 0.00001, p = 1.1, and q = 0.01
            m_Case.SetNonLinearTranxCost(0.00001, 1.1, 0.01);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            util.SetTranxCostTerm(1.0);

            RunOptimize();
        }

        /**\brief Transaction Cost Constraints
        *
        * You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
        */
        public void Tutorial_5c()
        {
            Console.WriteLine("======== Running Tutorial 5c ========");
            Console.WriteLine("Transaction Cost Constraint");
            SetupDumpFile("5c");

            // Create WorkSpace and setup Risk Model data
            SetupRiskModel();

            // Create an initial portfolio with no Cash
            m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");
            m_InitPf.AddAsset("USA11I1", 0.3);
            m_InitPf.AddAsset("USA13Y1", 0.7);

            // Set the transaction cost
            CAsset asset = m_WS.GetAsset("USA11I1");
            if (asset != null)
            {
                // the price is 23.99

                // the 1st 10,000, 
                // the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.002833681, 10000.0);

                // from 10,000 to +OPT_INF, 
                // the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearBuyCost(0.003833681, barraopt.OPT_INF);

                // Sell cost is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
                asset.AddPWLinearSellCost(0.003833681, barraopt.OPT_INF);
            }

            asset = m_WS.GetAsset("USA13Y1");
            if (asset != null)
            {
                // the price is 34.19

                // the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
                asset.AddPWLinearBuyCost(0.00287745, barraopt.OPT_INF);

                // Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
                asset.AddPWLinearSellCost(0.00387745, barraopt.OPT_INF);
            }

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 5c", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            CConstraintInfo info = constraints.SetTransactionCostConstraint();
            info.SetUpperBound(0.0005, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            util.SetTranxCostTerm(1.0);

            RunOptimize();
        }

        /**\brief Fixed Transaction Costs
        *
        * Tutorial_5d illustrates how to set up fixed transaction costs
        */
        public void Tutorial_5d()
        {
            Initialize("5d", "Fixed Transaction Costs", true);

            // Set fixed transaction costs for non-cash assets
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) != 0)
                {
                    CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                    if (asset != null)
                    {
                        asset.SetFixedBuyCost(0.02);
                        asset.SetFixedSellCost(0.03);
                    }
                }
            }

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 5d", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
            util.SetTranxCostTerm(1.0);

            RunOptimize();
        }

        /**\brief load asset-level data, including fixed transaction costs from csv file
        *
        * Tutorial_5e illustrates how to set up asset-level data including fixed transaction costs and group association from csv file
        */
        public void Tutorial_5e()
	    {
            Initialize("5e", "Asset-Level Data incl. Fixed Transaction Costs", true);

		    // Set fixed transaction costs for non-cash assets
            // load asset-level group name & attributes 
            CStatus status = m_WS.LoadAssetData(m_Data.m_Datapath + "asset_data.csv");
		    if (status.GetStatusCode() != EStatusCode.eOK) {
			     Console.WriteLine("Error loading transaction cost data: " + status.GetMessage());
                 Console.WriteLine(status.GetAdditionalInfo());
		    }

            // Create a case object. Set initial portfolio  & trade univers
            m_Case = m_WS.CreateCase("Case 5e", m_InitPf, m_TradeUniverse, 100000.0, 0.0);
		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set a linear constraint to GICS_SECTOR - Information Technology
            CLinearConstraints linear = constraints.InitLinearConstraints();
            CConstraintInfo info = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");
            // limit the exposure to between 10%-50%
            info.SetLowerBound(0.1);
            info.SetUpperBound(0.5);

            // Set a hedge constraint to GICS_SECTOR - Information Technology
            CHedgeConstraints hedgeConstr = constraints.InitHedgeConstraints();
            CConstraintInfo wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint("GICS_SECTOR", "Information Technology");
            wtlGrpConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetSoft(true);

            // Set max # of asset in GICS Sector/Information Technology to 1
            CParingConstraints paring = constraints.InitParingConstraints();
            CParingRange range = paring.AddAssetTradeParingByGroup(EAssetTradeParingType.eNUM_ASSETS, "GICS_SECTOR", "Information Technology");
            range.SetMax(1);
            // Set minimum holding threshold for GICS Sector/Information Technology to 0.2
            paring.AddLevelParingByGroup(ELevelParingType.eMIN_HOLDING_LONG, "GICS_SECTOR", "Information Technology", 0.2);

            // Set the net turnover by group for GICS_SECTOR - Information Technology
            CTurnoverConstraints toCons = constraints.InitTurnoverConstraints();
            CConstraintInfo infoGroup = toCons.AddNetConstraintByGroup("GICS_SECTOR", "Information Technology");
            infoGroup.SetUpperBound(0.03); 
            
            CUtility util = m_Case.InitUtility();
		    util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
		    util.SetTranxCostTerm(1.0);
    		
		    RunOptimize();
	    }

         /**\brief Fixed Holding Costs
         *
         * Tutorial_5f illustrates how to set up fixed holding costs
         */
         public void Tutorial_5f()
         {
 	        Initialize( "5f", "Fixed Holding Costs", true );
         
 	        // Set fixed transaction costs for non-cash assets
 	        for( int i = 0; i<m_Data.m_AssetNum; i++) {
 		        if( !m_Data.m_ID[i].Equals("CASH") ) {
 			        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
 			        if ( asset!= null ) {
 				        asset.SetUpSideFixedHoldingCost(0.02);
 				        asset.SetDownSideFixedHoldingCost(0.03);
 			        }
 		        }
 	        }
         
 	        // Create a case object. Set initial portfolio
 	        m_Case = m_WS.CreateCase("Case 5f", m_InitPf, null, 100000, 0.0);
 	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));
         
 	        CUtility util = m_Case.InitUtility();
 	        util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
            util.SetFixedHoldingCostTerm(1.5); // default value of the multiplier is 1.
    
 	        RunOptimize();
         }

        /**\brief General Piecewise Linear Constraint
	    *
     	* Tutorial_5g illustrates how to set up general piecewise linear Constraints
     	*/
        public void Tutorial_5g()
        {
            Initialize("5g", "General Piecewise Linear Constraint", true);

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 5g", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            CConstraints constraints = m_Case.InitConstraints();
            CGeneralPWLinearConstraint generalPWLICon = constraints.AddGeneralPWLinearConstraint();

            generalPWLICon.SetStartingPoint(m_Data.m_ID[0], m_Data.m_BMWeight[0]);
            generalPWLICon.AddDownSideSlope(m_Data.m_ID[0], -0.01, 0.05);
            generalPWLICon.AddDownSideSlope(m_Data.m_ID[0], -0.03);
            generalPWLICon.AddUpSideSlope(m_Data.m_ID[0], 0.02, 0.04);
            generalPWLICon.AddUpSideSlope(m_Data.m_ID[0], 0.03);

            CConstraintInfo conInfo = generalPWLICon.SetConstraint();
            conInfo.SetLowerBound(0);
            conInfo.SetUpperBound(0.25);

            RunOptimize();
        }

        /**\brief Penalty
        *
        * Penalties, like constraints, let you customize optimization by tilting 
        * toward certain portfolio characteristics.
        * 
        * This self-documenting sample code illustrates how to use the Barra Optimizer
        * to set up a penalty function that helps restrict market exposure.
        */
        public void Tutorial_6a()
        {
            Initialize("6a", "Penalty");

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 6a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linear.SetBetaConstraint();
            info.SetLowerBound(-1 * barraopt.OPT_INF, ERelativeMode.eABSOLUTE);
            info.SetUpperBound(barraopt.OPT_INF, ERelativeMode.eABSOLUTE);

            // Set target to be 0.95
            // min = 0.80 and max = 1.2
            info.SetPenalty(0.95, 0.80, 1.2, true, 1.0);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();
        }

        /**\brief Risk Budgeting
        *
        * In the following example, we will constrain the amount of risk coming
        * from common factor risk.  
        *
        */
        public void Tutorial_7a()
        {
            Initialize("7a", "Risk Budgeting", true);

            // Create a case object, set initial portfolio and trade universe
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case = m_WS.CreateCase("Case 7a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(riskModel);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();

	        CPortfolioOutput pfOut = m_Solver.GetPortfolioOutput();
	        if ( pfOut != null ) {
                Console.WriteLine("Specific Risk(%) = {0:0.0000}", pfOut.GetSpecificRisk());
                Console.WriteLine("Factor Risk(%) = {0:0.0000}", pfOut.GetFactorRisk());

		        CRiskConstraints riskConstraint = m_Case.InitConstraints().InitRiskConstraints();

                Console.WriteLine("\nAdd a risk constraint: FactorRisk<=12%");
                CConstraintInfo info = riskConstraint.AddPLFactorConstraint();
                info.SetUpperBound(0.12, ERelativeMode.eABSOLUTE);

                CIDSet fid = m_WS.CreateIDSet();
                //add four factors
                fid.Add("Factor_1B");
                fid.Add("Factor_1C");
                fid.Add("Factor_1D");
                fid.Add("Factor_1E");

                Console.WriteLine("Add a risk constraint: Factor_1B-1E<=1.9%\n");
                CConstraintInfo info2 = riskConstraint.AddFactorConstraint(null, fid);
                info2.SetUpperBound(0.019);

			    RunOptimize(true);     // use the existing solver without recreating a new solver

			    CPortfolioOutput pfOut2 = m_Solver.GetPortfolioOutput();
			    if (pfOut2 != null)
			    {
                    Console.WriteLine("Specific Risk(%) = {0:0.0000}", pfOut2.GetSpecificRisk());
                    Console.WriteLine("Factor Risk(%) = {0:0.0000}", pfOut2.GetFactorRisk());
			    }
		    }
        }

        /**\brief Dual Benchmarks
        *
        * Asset managers often administer separate accounts against one model 
        * portfolio.  For example, an asset manager with 300 separate institutional 
        * accounts for the same product, such as Large Cap Growth, will typically 
        * rebalance the model portfolio on a periodic basis (e.g., monthly).  The model
        * becomes the target portfolio that all 300 accounts should match perfectly, in
        * the absence of any unique constraints (e.g., no tobacco stocks).  The asset
        * manager will report performance to his or her institutional clients using the
        * appropriate external benchmark (e.g., Russell 1000 Growth, or S&P 500 Growth).
        * The model portfolio is effectively an internal benchmark. 
        *
        * The dual benchmark feature in the Barra Optimizer enables portfolio managers
        * to maximize utility using one benchmark, while constraining active risk 
        * against a different benchmark.  The optimal portfolio is the one that 
        * maximizes utility subject to the active risk constraint on the secondary
        * benchmark.
        *
        * Tutorial_7b is modified from Tutoral_1c, which minimizes the active risk 
        * relative to the benchmark portfolio. In this example, we set a risk 
        * constraint relative to the model portfolio with an active risk upper bound of
        * 300 basis points. 
        *
        * This self-documenting sample code illustrates how to perform risk-constrained
        * optimization with dual benchmarks: 
        */
        public void Tutorial_7b()
        {
            Initialize("7b", "Risk Budgeting - Dual Benchmark");

            // Create a case object, set initial portfolio and trade universe
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case = m_WS.CreateCase("Case 7b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(riskModel);

            CRiskConstraints riskConstraint = m_Case.InitConstraints().InitRiskConstraints();

            CConstraintInfo info = riskConstraint.AddPLTotalConstraint(true, m_ModelPortfolio);
            info.SetID("RiskConstraint");
            info.SetUpperBound(0.16, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null)
            {
                CSlackInfo slackInfo = output.GetSlackInfo("RiskConstraint");

                if (slackInfo != null)
                    Console.WriteLine("Risk Constraint Slack = {0:0.0000}",
                                      slackInfo.GetSlackValue());
                    Console.WriteLine();
            }
        }

        /**\brief Risk Budgeting using additive definition
        *
        * In the following example, we will constrain the amount of risk coming from
        * subsets of assets/factors using additive risk definition
        *
        */
        public void Tutorial_7c()
        {
            Initialize("7c", "Additive Risk Definition", true);

            // Create a case object, set initial portfolio and trade universe
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case = m_WS.CreateCase("Case 7c", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(riskModel);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();

	        CPortfolioOutput pfOut = m_Solver.GetPortfolioOutput();
	        if ( pfOut != null ) {
                Console.WriteLine("Specific Risk(%) = {0:0.0000}", pfOut.GetSpecificRisk());
                Console.WriteLine("Factor Risk(%) = {0:0.0000}", pfOut.GetFactorRisk());

                // subset of assets
		        CIDSet aid = m_WS.CreateIDSet();
		        aid.Add("USA13Y1");
		        aid.Add("USA1TY1");

                // subset of factors (7|8|9*)
                CIDSet fid = m_WS.CreateIDSet();
                for (int i = 48; i < m_Data.m_FactorNum; i++)
                    fid.Add(m_Data.m_Factor[i]);

		        Console.WriteLine("Risk from USA13Y1 & 1TY1 = {0:0.0000}", 
                    m_Solver.EvaluateRisk(pfOut.GetPortfolio(), ERiskType.eTOTALRISK, null, aid, null, true, true));
                Console.WriteLine("Risk from Factor_7|8|9* = {0:0.0000}\n", 
                    m_Solver.EvaluateRisk(pfOut.GetPortfolio(), ERiskType.eFACTORRISK, null, null, fid, true, true));

			    CRiskConstraints riskConstraint = m_Case.InitConstraints().InitRiskConstraints();
                Console.WriteLine("Add a risk constraint(additive def): from USA13Y1 & 1TY1 <=1%");
		        CConstraintInfo info = riskConstraint.AddTotalConstraint( aid, null, true, null, false, false, false, true);
		        info.SetUpperBound(0.01);

                Console.WriteLine("Add a risk constraint(additive def): from Factor_7|8|9* <=1.9%\n");
		        CConstraintInfo info2 = riskConstraint.AddFactorConstraint( null, fid, true, null, false, false, false, true);
		        info2.SetUpperBound(0.019);

			    RunOptimize(true);     // use the existing solver without recreating a new solver

			    CPortfolioOutput pfOut2 = m_Solver.GetPortfolioOutput();
			    if (pfOut2 != null)
			    {
                    Console.WriteLine("Specific Risk(%) = {0:0.0000}", pfOut2.GetSpecificRisk());
                    Console.WriteLine("Factor Risk(%) = {0:0.0000}", pfOut2.GetFactorRisk());
			        Console.WriteLine("Risk from USA13Y1 & 1TY1 = {0:0.0000}", 
                        m_Solver.EvaluateRisk(pfOut2.GetPortfolio(), ERiskType.eTOTALRISK, null, aid, null, true, true));
                    Console.WriteLine("Risk from Factor_7|8|9* = {0:0.0000}\n", 
                        m_Solver.EvaluateRisk(pfOut2.GetPortfolio(), ERiskType.eFACTORRISK, null, null, fid, true, true));

			        CIDSet ids = pfOut2.GetSlackInfoIDs();
                    String id=ids.GetFirst();
                    for(int i = 0; i < ids.GetCount(); i++, id = ids.GetNext())
				        Console.WriteLine("Risk Constraint Slack of {0} = {1:0.0000}", id, pfOut2.GetSlackInfo(id).GetSlackValue());
			    }
		    }
        }

        /**\brief Risk Budgeting by asset
        *
        * In the following example, we will constrain the amount of risk coming from
        * individual assets using additive risk definition.
        */
        public void Tutorial_7d()
        {
            Initialize("7d", "Risk Budgeting By Asset", true);

            // Create a case object, set initial portfolio and trade universe
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case = m_WS.CreateCase("Case 7d", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(riskModel);

            // Add a risk constraint by asset (additive def): risk from USA11I1 and from 13Y1 to be between 3% and 5% 
            CRiskConstraints riskConstraint = m_Case.InitConstraints().InitRiskConstraints();
            CIDSet pid = m_WS.CreateIDSet();
            pid.Add("USA11I1");
            pid.Add("USA13Y1");
            CConstraintInfo info = riskConstraint.AddRiskConstraintByAsset(pid, true, null, false, false, false, true);
            info.SetLowerBound(0.03);
            info.SetUpperBound(0.05);

            CUtility util = m_Case.InitUtility();

            m_Solver = m_WS.CreateSolver(m_Case);

            // Print asset risks in the initial portfolio
            Console.WriteLine("Initial Portfolio:");
            PrintRisksByAsset(m_InitPf);
            Console.WriteLine("");

            RunOptimize(true);

            CPortfolioOutput pfOut = m_Solver.GetPortfolioOutput();
            if (pfOut != null)
            {
                // Print asset risks in the optimal portfolio
                PrintRisksByAsset(pfOut.GetPortfolio());
                Console.WriteLine("");

                CIDSet ids = pfOut.GetSlackInfoIDs();
                for (String id = ids.GetFirst(); id != ""; id = ids.GetNext())
                    Console.WriteLine("Risk Constraint Slack of {0} = {1:0.0000}", id, pfOut.GetSlackInfo(id).GetSlackValue());
                Console.WriteLine("");
            }
        }

        /**\brief Long-Short Optimization
        *
        * Long/Short portfolios can be described as consisting of cash, a set of long
        * positions, and a set of short positions. Long-Short portfolios can provide 
        * more “alpha” since a manager is not restricted to positive-alpha stocks 
        * (assuming the manager’s ability to identify overvalued and undervalued stocks).
        * Market-neutral portfolios are a special case of long/short strategy, because
        * they are constructed to remove systematic market risk (with a beta of zero to
        * the market portfolio, and no common-factor risk).  Since market-neutral
        * portfolios have no market risk, managers measure their performance against a 
        * cash benchmark.
        *
        * In Long-Short (Hedge) Optimization, you start with setting the default asset
        * minimum bound to -100% (thus allowing short sales).  You can then enter 
        * constraints to the long side and the short side of the portfolio.
        *
        * In example Tutorial_8a, we begin with a portfolio of $10mm cash and let the
        * optimizer determine optimal leverage based on expected returns we provide 
        * (i.e. maximize utility) to perform  a 130/30 strategy (long positions can be
        * up to 130% of the portfolio base value and short positions can be up to 30%). 
        */
        public void Tutorial_8a()
        {
            Console.WriteLine("======== Running Tutorial 8a ========");
            Console.WriteLine("Long-Short Hedge Optimization");
            SetupDumpFile ("8a");

            // Create WorkSpace and setup Risk Model data
            SetupRiskModel();

            m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");
            m_TradeUniverse = m_WS.CreatePortfolio("Trade Universe");
            SetAlpha();

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!m_Data.m_ID[i].Equals("CASH"))
                    m_TradeUniverse.AddAsset(m_Data.m_ID[i], 0.0);
                else
                    m_InitPf.AddAsset(m_Data.m_ID[i], 1.0);
            }

            // Create a case object with 10M cash portfolio
            m_Case = m_WS.CreateCase("Case 8a", m_InitPf, m_TradeUniverse, 10000000.0, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();
            CLinearConstraints linear = constraints.InitLinearConstraints();
            for (int j = 0; j < m_Data.m_AssetNum; j++)
            {
                CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);
                if (!m_Data.m_ID[j].Equals("CASH"))
                {
                    info.SetLowerBound(-1.0, ERelativeMode.eABSOLUTE);
                    info.SetUpperBound(1.0, ERelativeMode.eABSOLUTE);
                }
                else
                {
                    info.SetLowerBound(-0.3, ERelativeMode.eABSOLUTE);
                    info.SetUpperBound(0.3, ERelativeMode.eABSOLUTE);
                }
            }

            CHedgeConstraints hedgeConstr = constraints.InitHedgeConstraints();
            CConstraintInfo longInfo = hedgeConstr.SetLongSideLeverageRange(false);
            longInfo.SetLowerBound(1.0, ERelativeMode.eABSOLUTE);
            longInfo.SetUpperBound(1.3, ERelativeMode.eABSOLUTE);

            CConstraintInfo shortInfo = hedgeConstr.SetShortSideLeverageRange(false);
            shortInfo.SetLowerBound(-0.3, ERelativeMode.eABSOLUTE);
            shortInfo.SetUpperBound(0.0, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);
            
            RunOptimize();
        }

        /**\brief Short Costs as Single Attribute
        *
        * Short cost/rebate rate of asset i is defined as below:
        * ShortCost_i = CostOfLeverage + HardToBorrowPenalty_i – InterestRateOnProceed_i
        * 
        * Starting Optimizer 1.3, user can specify short cost via a single API as shown
        * below.
        *
        */
        public void Tutorial_8b()
        {
            Initialize("8b", "Short Costs as Single Attribute", true);
            m_InitPf.AddAsset("CASH", 1);

            // Create a case object. Set initial portfolio
            m_Case = m_WS.CreateCase("Case 8b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            CLinearConstraints linear = constraints.InitLinearConstraints();
            for (int j = 0; j < m_Data.m_AssetNum; j++)
            {
                CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);
                if (string.Compare(m_Data.m_ID[j], "CASH", true) != 0)
                {
                    info.SetLowerBound(-1.0, ERelativeMode.eABSOLUTE);
                    info.SetUpperBound(1.0, ERelativeMode.eABSOLUTE);
                }
                else
                {
                    info.SetLowerBound(-0.3, ERelativeMode.eABSOLUTE);
                    info.SetUpperBound(0.3, ERelativeMode.eABSOLUTE);
                }
            }

            CHedgeConstraints hedgeConstr = constraints.InitHedgeConstraints();
            CConstraintInfo shortInfo = hedgeConstr.SetShortSideLeverageRange(false);
            shortInfo.SetLowerBound(-0.3, ERelativeMode.eABSOLUTE);
            shortInfo.SetUpperBound(0.0, ERelativeMode.eABSOLUTE);

            // Set the net short cost
            CAsset asset = m_WS.GetAsset("USA11I1");
            if (asset != null)
            {
                // ShortCost = CostOfLeverage + HardToBorrowPenalty – InterestRateOnProceed
                // where CostOfLeverage=50 basis, HardToBorrowPenalty=10 basis, InterestRateOnProceed=20 basis
                asset.SetNetShortCost(0.004);
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();
        }

        /**\brief Weighted Total Leverage Constraint
        *
        * The following example shows how to setup weighted total leverage constraint,
        * total leverage group constraint, and total leverage factor constraint.
        *
        */
        public void Tutorial_8c()
        {
	        Console.WriteLine("======== Running Tutorial 8c ========");
            Console.WriteLine("Weighted Total Leverage Constraint Optimization");
            SetupDumpFile ("8c");

	        // Create WorkSpace and setup Risk Model data
	        SetupRiskModel();

	        m_InitPf = m_WS.CreatePortfolio("Initial Portfolio");	
	        m_TradeUniverse = m_WS.CreatePortfolio("Trade Universe");	
 	        SetAlpha();

	        for( int i = 0; i<m_Data.m_AssetNum; i++)
	        {
		        if (!m_Data.m_ID[i].Equals("CASH"))
			        m_TradeUniverse.AddAsset(m_Data.m_ID[i]);
		        else
			        m_InitPf.AddAsset(m_Data.m_ID[i], 1.0);
        		
		        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
		        if (asset != null)
			        asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
	        }

	        // Create a case object with 10M cash portfolio
	        m_Case = m_WS.CreateCase("Case 8c", m_InitPf, m_TradeUniverse, 10000000.0, 0.0);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        CConstraints constraints = m_Case.InitConstraints();
	        CLinearConstraints linear = constraints.InitLinearConstraints(); 
	        for (int j=0; j<m_Data.m_AssetNum; j++)
	        {
	 	        CConstraintInfo info = linear.SetAssetRange(m_Data.m_ID[j]);
                if (!m_Data.m_ID[j].Equals("CASH"))
		        {
			        info.SetLowerBound(-1.0);
			        info.SetUpperBound(1.0);
		        }
		        else
		        {
			        info.SetLowerBound(-0.3);
			        info.SetUpperBound(0.3);
		        }
	        }

	        CAttributeSet longSideCoeffs = m_WS.CreateAttributeSet();
	        CAttributeSet shortSideCoeffs = m_WS.CreateAttributeSet();
	        for (int i=0; i<m_Data.m_AssetNum; i++) {
		        if (m_Data.m_ID[i].Equals("CASH"))
			        continue;

		        longSideCoeffs.Set( m_Data.m_ID[i], 1.0 );
		        shortSideCoeffs.Set( m_Data.m_ID[i], 1.0 );
	        }

	        CHedgeConstraints hedgeConstr = constraints.InitHedgeConstraints();
	        CConstraintInfo wtlFacConsInfo = hedgeConstr.AddTotalLeverageFactorConstraint("Factor_1A");
	        wtlFacConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlFacConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
	        wtlFacConsInfo.SetPenalty(0.95, 0.80, 1.2);
	        wtlFacConsInfo.SetSoft(true);

	        CConstraintInfo wtlConsInfo = hedgeConstr.AddWeightedTotalLeverageConstraint(longSideCoeffs, shortSideCoeffs);
            wtlConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
	        wtlConsInfo.SetPenalty(0.95, 0.80, 1.2);
	        wtlConsInfo.SetSoft(true);

	        CConstraintInfo wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint("GICS_SECTOR", "Information Technology");
            wtlGrpConsInfo.SetLowerBound(1.0, ERelativeMode.ePLUS);
            wtlGrpConsInfo.SetUpperBound(1.3, ERelativeMode.ePLUS);
	        wtlGrpConsInfo.SetPenalty(0.95, 0.80, 1.2);
	        wtlGrpConsInfo.SetSoft(true);

	        CUtility util = m_Case.InitUtility();

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
	        util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            //constraint retrieval
  	        PrintLowerAndUpperBounds(ref linear);
  	        PrintLowerAndUpperBounds(ref hedgeConstr);

	        RunOptimize();

        }

        /**\brief Long-side Turnover Constraint
        *
        * The following case illustrates the use of turnover by side constraint, which needs to
        * be used in conjunction with long-short optimization. The maximum turnover on the long side
        * is 20%, with total value on the long side equal to total value on the short side.
        * 
        */
        public void Tutorial_8d()
        {
            Initialize("8d", "Long-side Turnover Constraint");
            m_InitPf.AddAsset("CASH");

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 8d", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set soft turnover constraint
            CTurnoverConstraints turnover = constraints.InitTurnoverConstraints();
            CConstraintInfo info = turnover.SetLongSideConstraint();
            info.SetUpperBound(0.2);

            // Set hedge constraint
            CHedgeConstraints hedge = constraints.InitHedgeConstraints();
            CConstraintInfo hedgeInfo = hedge.SetShortLongLeverageRatioRange();
            hedgeInfo.SetLowerBound(1.0);
            hedgeInfo.SetUpperBound(1.0);

            CUtility util = m_Case.InitUtility();

            RunOptimize();
        }

        /**\brief Risk Target
        *
        * The following example uses the same two-asset portfolio and ten-asset 
        * benchmark/trade universe.  There are asset alphas specified for each stock.
        *
        * The optimized portfolio will represent the optimal tradeoff between a target
        * level of risk and the maximum level of return available.  In this example, we
        * selected a target risk of 14% (tracking error, in this case, since a 
        * benchmark is assigned).  
        */
        public void Tutorial_9a()
        {
            Initialize("9a", "Risk Target", true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 9a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set risk target
            m_Case.SetRiskTarget(0.14);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();
        }

        /**\brief Return Target
        *
        * Similar to Tutoral_9a, we define a return target of 1% in Tutorial_9b:
        */
        public void Tutorial_9b()
        {
            Initialize("9b", "Return Target", true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 9b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set return target
            m_Case.SetReturnTarget(0.01);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();
        }

        /**\brief brief Tax-aware Optimization (using pre-v8.8 legacy APIs)
        *
        * Suppose an individual investor desires to rebalance a portfolio to be “more
        * like the benchmark,” but also wants to avoid having any net tax liability 
        * doing so.  In Tutorial_10a, we are rebalancing without alphas, and assume 
        * the portfolio has no realized capital gains so far this year.  The trading
        * rule is FIFO.
        */
        public void Tutorial_10a()
        {
            Initialize("10a", "Tax-aware Optimization (using pre-v8.8 legacy APIs)");

	    double[] assetValue = new double[m_Data.m_AssetNum];
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);

                if (asset != null)
                    asset.SetPrice(m_Data.m_Price[i]);

		assetValue[i] = 0;
            }

	    double pfValue = 0;
            for (int j = 0; j < m_Data.m_Taxlots; j++) {
                int iAccount = m_Data.m_Account[j];
                if (iAccount == 0)
                {
                    int iAsset = m_Data.m_Indices[j];
                    m_InitPf.AddTaxLot(m_Data.m_ID[iAsset],
                                m_Data.m_Age[j], m_Data.m_CostBasis[j],
                                m_Data.m_Shares[j], false);
                    double lotValue = m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
                    assetValue[iAsset] += lotValue;
                    pfValue += lotValue;
                }
            }

            // Reset asset initial weights that are calculated from tax lot information
            for(int i=0; i<m_Data.m_AssetNum; i++)
                m_InitPf.AddAsset(m_Data.m_ID[i], assetValue[i]/pfValue);

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10a", m_InitPf, m_TradeUniverse, pfValue, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CTax tax = m_Case.InitTax();
            tax.EnableTwoRate(365);
            tax.SetTaxRate(0.243, 0.423); //long term and short term rates

            // not allow wash sale
            tax.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

            // first in, first out
            tax.SetSellingOrderRule(ESellingOrderRule.eFIFO);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
            
            RunOptimize();

            // Handle additional tax output information
            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output == null)
                return;

            CTaxOutput taxOut = output.GetTaxOutput();
            if (taxOut == null)
                return;

            Console.WriteLine("Tax Info:");
            Console.WriteLine("Long Term Gain  = {0:0.00}", taxOut.GetLongTermGain());
            Console.WriteLine("Long Term Loss  = {0:0.00}", taxOut.GetLongTermLoss());
            Console.WriteLine("Long Term Tax   = {0:0.00}", taxOut.GetLongTermTax());
            Console.WriteLine("Short Term Gain = {0:0.00}", taxOut.GetShortTermGain());
            Console.WriteLine("Short Term Loss = {0:0.00}", taxOut.GetShortTermLoss());
            Console.WriteLine("Short Term Tax  = {0:0.00}", taxOut.GetShortTermTax());
            Console.WriteLine("Total Tax       = {0:0.00}", taxOut.GetTotalTax());
			Console.WriteLine();
		   
			CPortfolio portfolio = output.GetPortfolio();
			CIDSet idSet = portfolio.GetAssetIDSet();
			Console.WriteLine( "TaxlotID          Shares:" );
			String assetID=idSet.GetFirst();
			for ( int i=0; i<idSet.GetCount(); i++, assetID = idSet.GetNext()) {
				CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
				CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
				String lotID = oLotIDs.GetFirst();
				for ( int j=0; j<oLotIDs.GetCount(); j++, lotID = oLotIDs.GetNext() ) {
					int shares = (int)sharesInTaxlot.GetValue( lotID );
					if ( shares!=0 ) 
						Console.WriteLine( "{0} {1:D8}", lotID, shares );
				}
			}	
            Console.WriteLine();
        }

        /**\brief Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
        *
        * Portfolio managers focusing on tax impact during rebalancing want to harvest
        * losses and avoid gains to decrease tax cost rather than have gains net out
        * the losses. Other managers want to target gains to generate cash flow for
        * their clients. Still other managers want long -term gains and short-term 
        * losses. One can implement a tax loss harvesting strategy by setting the 
        * bounds appropriately.
        * 
        * Tutorial_10b illustrates how to constraint short term gain to 0 and long term
        * loss to 110.
        */
        public void Tutorial_10b()
        {
            Initialize("10b", "Capital Gain Arbitrage (using pre-v8.8 legacy APIs)");

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);

                if (asset != null)
                    asset.SetPrice(m_Data.m_Price[i]);
            }

            for (int j = 0; j < m_Data.m_Taxlots; j++)
            {
                int iAccount = m_Data.m_Account[j];
                if (iAccount == 0)
                    m_InitPf.AddTaxLot(m_Data.m_ID[m_Data.m_Indices[j]],
                                m_Data.m_Age[j], m_Data.m_CostBasis[j],
                                m_Data.m_Shares[j], false);
            }

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10b", m_InitPf, m_TradeUniverse, 4279.4,
                            0.0);

            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CTax tax = m_Case.InitTax();
            tax.EnableTwoRate(365);
            tax.SetTaxRate(0.243, 0.423); //long term and short term rates

            // not allow wash sale
            tax.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);

            // first in, first out
            tax.SetSellingOrderRule(ESellingOrderRule.eFIFO);

            CConstraints constraints = m_Case.InitConstraints();
            CTaxConstraints taxConstr = constraints.InitTaxConstraints();

            CConstraintInfo shortConstr = taxConstr.SetShortGainArbitrageRange();
            shortConstr.SetLowerBound(0.0, ERelativeMode.eABSOLUTE);
            shortConstr.SetUpperBound(0.0, ERelativeMode.eABSOLUTE);

            CConstraintInfo longConstr = taxConstr.SetLongLossArbitrageRange();
            longConstr.SetLowerBound(0.0, ERelativeMode.eABSOLUTE);
            longConstr.SetUpperBound(110.0, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            RunOptimize();

            // Handle additional output information
            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output == null)
                return;

            CTaxOutput taxOut = output.GetTaxOutput();
            if (taxOut != null)
            {
                Console.WriteLine("Tax Info:");
                Console.WriteLine("Long Term Gain  = {0:0.00}", taxOut.GetLongTermGain());
                Console.WriteLine("Long Term Loss  = {0:0.00}", taxOut.GetLongTermLoss());
                Console.WriteLine("Long Term Tax   = {0:0.00}", taxOut.GetLongTermTax());
                Console.WriteLine("Short Term Gain = {0:0.00}", taxOut.GetShortTermGain());
                Console.WriteLine("Short Term Loss = {0:0.00}", taxOut.GetShortTermLoss());
                Console.WriteLine("Short Term Tax  = {0:0.00}", taxOut.GetShortTermTax());
                Console.WriteLine("Total Tax       = {0:0.00}", taxOut.GetTotalTax());
                Console.WriteLine();
            }
        }

        /**\brief Tax-aware Optimization (Using new APIs introduced in v8.8)
        *
        * Suppose an individual investor desires to rebalance a portfolio to be “more
        * like the benchmark,” but also wants to minimize net tax liability. 
        * In Tutorial_10c, we are rebalancing without alphas, and assume 
        * the portfolio has no realized capital gains so far this year.  The trading
        * rule is FIFO. This tutorial illustrates how to set up a group-level tax 
        * arbitrage constraint.
        */
        public void Tutorial_10c()
	    {
		    Initialize( "10c", "Tax-aware Optimization (Using new APIs introduced in v8.8)" );

		    double[] assetValue = new double[m_Data.m_AssetNum];
		    for (int i=0; i<m_Data.m_AssetNum; i++) {
			    CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
			    if (asset != null)
				    asset.SetPrice( m_Data.m_Price[i] );

			    assetValue[i] = 0;
		    }

		    // Set up group attribute
		    for(int i=0; i<m_Data.m_AssetNum; i++) {
			    // Set GICS Sector attribute
			    CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
			    if (asset != null)
				    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
		    }

		    // Add tax lots into the portfolio, compute asset values and portfolio value
		    double pfValue = 0.0;
		    for (int j=0; j<m_Data.m_Taxlots; j++) {
                int iAccount = m_Data.m_Account[j];
                if (iAccount == 0)
                {
                    int iAsset = m_Data.m_Indices[j];
                    m_InitPf.AddTaxLot(m_Data.m_ID[iAsset], m_Data.m_Age[j],
                                         m_Data.m_CostBasis[j], m_Data.m_Shares[j], false);

                    double lotValue = m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
                    assetValue[iAsset] += lotValue;
                    pfValue += lotValue;
                }
		    }
	
		    // Reset asset initial weights based on tax lot information
		    for(int i=0; i<m_Data.m_AssetNum; i++)
			    m_InitPf.AddAsset( m_Data.m_ID[i], assetValue[i]/pfValue );

		    // Create a case object
		    m_Case = m_WS.CreateCase("Case 10c", m_InitPf, m_TradeUniverse, pfValue, 0.0);

		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

		    // Initialize a CNewTax object
		    CNewTax oTax = m_Case.InitNewTax();

		    // Add a tax rule that covers all assets
		    CTaxRule taxRule  = oTax.AddTaxRule( "*", "*" );
		    taxRule.EnableTwoRate();
		    taxRule.SetTaxRate(0.243, 0.423);
		    taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);	// not allow wash sale

		    // Set selling order rule as first in/first out for all assets
		    oTax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);	// first in, first out
	
		    // Specify long-only
		    CConstraints oCons = m_Case.InitConstraints();
		    CLinearConstraints linearCon = oCons.InitLinearConstraints(); 
		    for(int i=0; i<m_Data.m_AssetNum; i++) {
			    CConstraintInfo info = linearCon.SetAssetRange(m_Data.m_ID[i]);
			    info.SetLowerBound(0.0);
		    }

		    // Set a group level tax arbitrage constraint
		    CNewTaxConstraints oTaxCons = oCons.InitNewTaxConstraints();
		    CConstraintInfo lgRange = oTaxCons.SetTaxArbitrageRange( "GICS_SECTOR", "Information Technology", 
												    ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
		    lgRange.SetUpperBound( 250.0 );

		    CUtility util = m_Case.InitUtility();
		    util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

		    RunOptimize();

		    CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		    if ( output != null ) { 
			    CNewTaxOutput taxOut = output.GetNewTaxOutput();
			    if (taxOut != null) {
				    double lgg = taxOut.GetCapitalGain( "GICS_SECTOR", "Information Technology", 
													    ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
				    double lgl = taxOut.GetCapitalGain( "GICS_SECTOR", "Information Technology", 
													    ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
				    double sgg = taxOut.GetCapitalGain( "GICS_SECTOR", "Information Technology", 
													    ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
				    double sgl = taxOut.GetCapitalGain( "GICS_SECTOR", "Information Technology", 
													    ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );

				    Console.WriteLine( "Tax info for group GICS_SECTOR/Information Technology:" );
                    Console.WriteLine("Long Term Gain  = {0:0.0000}", lgg);
                    Console.WriteLine("Long Term Loss  = {0:0.0000}", lgl);
                    Console.WriteLine("Short Term Gain = {0:0.0000}", sgg);
                    Console.WriteLine("Short Term Loss = {0:0.0000}", sgl);

				    double ltax = taxOut.GetLongTermTax( "*", "*" );
				    double stax = taxOut.GetShortTermTax("*", "*");
				    double lgg_all = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
				    double lgl_all = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
			
				    Console.WriteLine( "\nTax info for the tax rule group(all assets):" );
				    Console.WriteLine("Long Term Gain = {0:0.0000}", lgg_all);
				    Console.WriteLine("Long Term Loss = {0:0.0000}", lgl_all);
				    Console.WriteLine("Long Term Tax  = {0:0.0000}", ltax);
				    Console.WriteLine("Short Term Tax = {0:0.0000}", stax);

				    Console.WriteLine("\nTotal Tax(for all tax rule groups) = {0:0.0000}", taxOut.GetTotalTax());

				    CPortfolio portfolio = output.GetPortfolio();
				    CIDSet idSet = portfolio.GetAssetIDSet();
				    Console.WriteLine( "\nTaxlotID          Shares:" );
                    for (String assetID = idSet.GetFirst(); !String.IsNullOrEmpty(assetID); assetID = idSet.GetNext())
                    {
					    CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

					    CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
					    for ( String lotID = oLotIDs.GetFirst(); !String.IsNullOrEmpty(lotID); lotID = oLotIDs.GetNext() ) {
						    double shares = sharesInTaxlot.GetValue( lotID );

						    if ( shares!=0 ) 
        						Console.WriteLine( "{0} {1:0.0000}", lotID, shares );
					    }
				    }

				    CAttributeSet newShares = taxOut.GetNewShares();
				    PrintAttributeSet(newShares, "\nNew Shares:");
				    Console.WriteLine( "\n" );
			    }
		    }
	    }


        /**\brief Tax-aware Optimization (Using new APIs introduced in v8.8)
        *
        * This tutorial illustrates how to set up a tax-aware optimization case with cash outflow.
        */
        public void Tutorial_10d()
        {
            Initialize("10d", "Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow");

            double[] assetValue = new double[m_Data.m_AssetNum];
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetPrice(m_Data.m_Price[i]);

                assetValue[i] = 0;
            }

            // Set up group attribute
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                // Set GICS Sector attribute
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
            }

            // Add tax lots into the portfolio, compute asset values and portfolio value
            double pfValue = 0.0;
            for (int j = 0; j < m_Data.m_Taxlots; j++)
            {
                int iAccount = m_Data.m_Account[j];
                if (iAccount == 0)
                {
                    int iAsset = m_Data.m_Indices[j];
                    m_InitPf.AddTaxLot(m_Data.m_ID[iAsset], m_Data.m_Age[j],
                        m_Data.m_CostBasis[j], m_Data.m_Shares[j], false);

                    double lotValue = m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
                    assetValue[iAsset] += lotValue;
                    pfValue += lotValue;
                }
            }

            // Cash outflow 5% of the base value
            double CFW = -0.05;

            // Set base value so that the final optimal weight will sum up to 100%
            double BV = pfValue / (1 - CFW);

            // Reset asset initial weights based on tax lot information
            for (int i = 0; i < m_Data.m_AssetNum; i++)
                m_InitPf.AddAsset(m_Data.m_ID[i], assetValue[i] / BV);

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10d", m_InitPf, m_TradeUniverse, BV, CFW);

            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Initialize a CNewTax object
            CNewTax oTax = m_Case.InitNewTax();

            // Add a tax rule that covers all assets
            CTaxRule taxRule = oTax.AddTaxRule("*", "*");
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);   // not allow wash sale

            // Set selling order rule as first in/first out for all assets
            oTax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);  // first in, first out

            // Specify long-only
            CConstraints oCons = m_Case.InitConstraints();
            CLinearConstraints linearCon = oCons.InitLinearConstraints();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CConstraintInfo info = linearCon.SetAssetRange(m_Data.m_ID[i]);
                info.SetLowerBound(0.0);
            }

            // Set a group level tax arbitrage constraint
            CNewTaxConstraints oTaxCons = oCons.InitNewTaxConstraints();
            CConstraintInfo lgRange = oTaxCons.SetTaxArbitrageRange("GICS_SECTOR", "Information Technology", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN);
            lgRange.SetUpperBound(250.0);

            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null)
            {
                CNewTaxOutput taxOut = output.GetNewTaxOutput();
                if (taxOut != null)
                {
                    double lgg = taxOut.GetCapitalGain("GICS_SECTOR", "Information Technology", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN);
                    double lgl = taxOut.GetCapitalGain("GICS_SECTOR", "Information Technology", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS);
                    double sgg = taxOut.GetCapitalGain("GICS_SECTOR", "Information Technology", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN);
                    double sgl = taxOut.GetCapitalGain("GICS_SECTOR", "Information Technology", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS);

                    Console.WriteLine("Tax info for group GICS_SECTOR/Information Technology:");
                    Console.WriteLine("Long Term Gain  = {0:0.0000}", lgg);
                    Console.WriteLine("Long Term Loss  = {0:0.0000}", lgl);
                    Console.WriteLine("Short Term Gain = {0:0.0000}", sgg);
                    Console.WriteLine("Short Term Loss = {0:0.0000}", sgl);

                    double ltax = taxOut.GetLongTermTax("*", "*");
                    double stax = taxOut.GetShortTermTax("*", "*");
                    double lgg_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN);
                    double lgl_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS);

                    Console.WriteLine("\nTax info for the tax rule group(all assets):");
                    Console.WriteLine("Long Term Gain = {0:0.0000}", lgg_all);
                    Console.WriteLine("Long Term Loss = {0:0.0000}", lgl_all);
                    Console.WriteLine("Long Term Tax  = {0:0.0000}", ltax);
                    Console.WriteLine("Short Term Tax = {0:0.0000}", stax);

                    Console.WriteLine("\nTotal Tax(for all tax rule groups) = {0:0.0000}\n", taxOut.GetTotalTax());

                    CPortfolio portfolio = output.GetPortfolio();
                    CIDSet idSet = portfolio.GetAssetIDSet();
                    Console.WriteLine("TaxlotID          Shares:");
                    for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext())
                    {
                        CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

                        CIDSet lotIDs = sharesInTaxlot.GetKeySet();
                        for (String lotID = lotIDs.GetFirst(); !String.IsNullOrEmpty(lotID); lotID = lotIDs.GetNext())
                        {
                            double shares = sharesInTaxlot.GetValue(lotID);

                            if (shares != 0)
                                Console.WriteLine("{0}  {1:0.0000}", lotID, shares);
                        }
                    }

                    CAttributeSet newShares = taxOut.GetNewShares();
                    PrintAttributeSet(newShares, "\nNew Shares:");
                    Console.WriteLine("");
                }
            }
        }

        /**\brief Tax-aware Optimization with loss benefit
        *
        * This tutorial illustrates how to set up a tax-aware optimization case with
        * a loss benefit term in the utility.
        */
        public void Tutorial_10e()
        {
            Initialize( "10e", "Tax-aware Optimization with loss benefit", false, true );

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10e", m_InitPf, m_TradeUniverse, m_PfValue[0], 0.0);

            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Disable shorting
            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);

            // Initialize a CNewTax object
            CNewTax oTax = m_Case.InitNewTax();

            // Add a tax rule that covers all assets
            CTaxRule taxRule  = oTax.AddTaxRule( "*", "*" );
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            taxRule.SetWashSaleRule(EWashSaleRule.eDISALLOWED, 30);    // not allow wash sale

            // Set selling order rule as first in/first out for all assets
            oTax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);    // first in, first out

            CUtility util = m_Case.InitUtility();
            util.SetLossBenefitTerm(1.0);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null) {
                CNewTaxOutput taxOut = output.GetNewTaxOutput();
                if (taxOut != null) {
                    double ltax = taxOut.GetLongTermTax( "*", "*" );
                    double stax = taxOut.GetShortTermTax("*", "*");
                    double lgg = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
                    double lgl = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
                    double sgg = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
                    double sgl = taxOut.GetCapitalGain( "*", "*", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );
                    double lb = taxOut.GetTotalLossBenefit();
                    double tax = taxOut.GetTotalTax();

                    Console.WriteLine("Tax info:");
                    Console.WriteLine("Long Term Gain  = {0:0.0000}", lgg );
                    Console.WriteLine("Long Term Loss  = {0:0.0000}", lgl );
                    Console.WriteLine("Short Term Gain = {0:0.0000}", sgg );
                    Console.WriteLine("Short Term Loss = {0:0.0000}", sgl );
                    Console.WriteLine("Long Term Tax   = {0:0.0000}", ltax );
                    Console.WriteLine("Short Term Tax  = {0:0.0000}", stax );
                    Console.WriteLine("Loss Benefit    = {0:0.0000}", lb );
                    Console.WriteLine("Total Tax       = {0:0.0000}\n", tax);

                    CPortfolio portfolio = output.GetPortfolio();
                    CIDSet idSet = portfolio.GetAssetIDSet();
                    Console.WriteLine( "TaxlotID          Shares:\n" );
                    for ( String assetID=idSet.GetFirst(); !String.IsNullOrEmpty(assetID); assetID = idSet.GetNext() ) {
                        CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

                        CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
                        for ( String lotID = oLotIDs.GetFirst(); !String.IsNullOrEmpty(lotID); lotID = oLotIDs.GetNext() ) {
                            double shares = sharesInTaxlot.GetValue( lotID );

                            if ( shares!=0 )
                                Console.WriteLine("{0}  {1:0.0000}", lotID, shares);
                        }
                    }

                    CAttributeSet newShares = taxOut.GetNewShares();
                    PrintAttributeSet(newShares, "\nNew Shares:");
                    Console.WriteLine("");
                }
            }
        }

        /**\brief Tax-aware Optimization with total loss and gain constraints.
        *
        * This tutorial illustrates how to set up a tax-aware optimization case with
        * bounds on total gain and loss.
        */
        public void Tutorial_10f()
        {
            Initialize("10f", "Tax-aware Optimization with total loss/gain constraints", false, true);

            // Set up GICS Sector attribute
            for (int i = 0; i < m_Data.m_AssetNum; i++) {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
            }

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10f", m_InitPf, m_TradeUniverse, m_PfValue[0], 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Disable shorting and cash
            CConstraints oCons = m_Case.InitConstraints();
            CLinearConstraints linear = oCons.InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);
            linear.SetAssetTradeSize("CASH", 0);

            // Initialize a CNewTax object and set tax parameters
            CNewTax oTax = m_Case.InitNewTax();
            CTaxRule taxRule = oTax.AddTaxRule("*", "*");
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            oTax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);

            // Set a group level tax arbitrage constraint on total loss
            CNewTaxConstraints oTaxCons = oCons.InitNewTaxConstraints();
            CConstraintInfo info = oTaxCons.SetTotalTaxArbitrageRange("GICS_SECTOR", "Financials", ECapitalGainType.eCAPITAL_LOSS);
            info.SetUpperBound(100.0);

            // Set a group level tax arbitrage constraint on total gain
            CConstraintInfo info2 = oTaxCons.SetTotalTaxArbitrageRange("GICS_SECTOR", "Information Technology", ECapitalGainType.eCAPITAL_GAIN);
            info2.SetLowerBound(250.0);

            CUtility util = m_Case.InitUtility();

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null) {
                CNewTaxOutput taxOut = output.GetNewTaxOutput();
                if (taxOut != null) {
                    double tgg = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Financials", ECapitalGainType.eCAPITAL_GAIN);
                    double tgl = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Financials", ECapitalGainType.eCAPITAL_LOSS);
                    double tgn = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Financials", ECapitalGainType.eCAPITAL_NET);
                    Console.WriteLine("Tax info (Financials):");
                    Console.WriteLine("Total Gain  = {0:0.0000}", tgg);
                    Console.WriteLine("Total Loss  = {0:0.0000}", tgl);
                    Console.WriteLine("Total Net   = {0:0.0000}\n", tgn);

                    tgg = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Information Technology", ECapitalGainType.eCAPITAL_GAIN);
                    tgl = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Information Technology", ECapitalGainType.eCAPITAL_LOSS);
                    tgn = taxOut.GetTotalCapitalGain("GICS_SECTOR", "Information Technology", ECapitalGainType.eCAPITAL_NET);
                    Console.WriteLine("Tax info (Information Technology):");
                    Console.WriteLine("Total Gain  = {0:0.0000}", tgg);
                    Console.WriteLine("Total Loss  = {0:0.0000}", tgl);
                    Console.WriteLine("Total Net   = {0:0.0000}\n", tgn);

                    CPortfolio portfolio = output.GetPortfolio();
                    CIDSet idSet = portfolio.GetAssetIDSet();
                    Console.WriteLine( "TaxlotID          Shares:" );
                    for ( String assetID=idSet.GetFirst(); !String.IsNullOrEmpty(assetID); assetID = idSet.GetNext() ) {
                        CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                        CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
                        for ( String lotID = oLotIDs.GetFirst(); !String.IsNullOrEmpty(lotID); lotID = oLotIDs.GetNext() ) {
                            double shares = sharesInTaxlot.GetValue( lotID );

                            if ( shares!=0 )
                                Console.WriteLine("{0}  {1:0.0000}", lotID, shares);
                        }
                    }

                    CAttributeSet newShares = taxOut.GetNewShares();
                    PrintAttributeSet(newShares, "\nNew Shares:");
                    Console.WriteLine("");
                }
            }
        }

        /**\brief Tax-aware Optimization with wash sales in the input.
        *
        * This tutorial illustrates how to specify wash sales, set the wash sale rule,
        * and access wash sale details from the output.
        */
        public void Tutorial_10g()
        {
            Initialize("10g", "Tax-aware Optimization with wash sales", false, true);

            // Add an extra lot whose age is within the wash sale period
            m_InitPf.AddTaxLot("USA11I1", 12, 21.44, 20.0);
            
            // Recalculate asset weight from tax lot data
            UpdatePortfolioWeights();

            // Add wash sale records
            m_InitPf.AddWashSaleRec("USA2ND1", 20, 12.54, 10.0, false);
            m_InitPf.AddWashSaleRec("USA3351", 35, 2.42, 25.0, false);
            m_InitPf.AddWashSaleRec("USA39K1", 12, 9.98, 25.0, false);

            // Create a case object
            m_Case = m_WS.CreateCase("Case 10g", m_InitPf, m_TradeUniverse, m_PfValue[0], 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Disable shorting and cash
            CConstraints oCons = m_Case.InitConstraints();
            CLinearConstraints linear = oCons.InitLinearConstraints();
            linear.SetTransactionType(ETranxType.eSHORT_NONE);
            linear.SetAssetTradeSize("CASH", 0);

            // Initialize a CNewTax object and set tax parameters
            CNewTax oTax = m_Case.InitNewTax();
            CTaxRule taxRule = oTax.AddTaxRule("*", "*");
            taxRule.EnableTwoRate();
            taxRule.SetTaxRate(0.243, 0.423);
            taxRule.SetWashSaleRule(EWashSaleRule.eTRADEOFF, 40);
            oTax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);

            CUtility util = m_Case.InitUtility();

            RunOptimize();

            // Retrieving tax related information from the output
            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null) {
                CNewTaxOutput taxOut = output.GetNewTaxOutput();
                if (taxOut != null) {
                    CPortfolio portfolio = output.GetPortfolio();
                    CIDSet idSet = portfolio.GetAssetIDSet();

                    // Shares in tax lots
                    Console.WriteLine("TaxlotID          Shares:");
                    for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext()) {
                        CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);

                        CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
                        for (String lotID = oLotIDs.GetFirst(); lotID != ""; lotID = oLotIDs.GetNext()) {
                            double shares = sharesInTaxlot.GetValue(lotID);

                            if ( shares!=0 )
                                Console.WriteLine("{0}  {1:0.0000}", lotID, shares);
                        }
                    }

                    // New shares
                    CAttributeSet newShares = taxOut.GetNewShares();
                    PrintAttributeSet(newShares, "\nNew Shares:");
                    Console.WriteLine("");

                    // Disqualified shares
                    CAttributeSet disqShares = taxOut.GetDisqualifiedShares();
                    PrintAttributeSet(disqShares, "Disqualified Shares:");
                    Console.WriteLine("");

                    // Wash sale details
                    Console.WriteLine("Wash Sale Details:");
                    Console.WriteLine("{0,-20}{1,12}{2,10}{3,10}{4,12}{5,20}",
                        "TaxLotID", "AdjustedAge", "CostBasis", "Shares", "SoldShares", "DisallowedLotID");
                    CIDSet assetIDs = m_Case.GetAssetIDs();
                    for (String assetID = assetIDs.GetFirst(); assetID != ""; assetID = assetIDs.GetNext()) {
                        CWashSaleDetail wsDetail = taxOut.GetWashSaleDetail(assetID);
                        if (wsDetail != null) {
                            for (int i = 0; i < wsDetail.GetCount(); i++) {
                                String lotID = wsDetail.GetLotID(i);
                                String disallowedLotID = wsDetail.GetDisallowedLotID(i);
                                Int32 age = wsDetail.GetAdjustedAge(i);
                                double costBasis = wsDetail.GetAdjustedCostBasis(i);
                                double shares = wsDetail.GetShares(i);
                                double soldShares = wsDetail.GetSoldShares(i);
                                Console.WriteLine("{0,-20}{1,12}{2,10:0.0000}{3,10:0.0000}{4,12:0.0000}{5,20}",
                                    lotID, age, costBasis, shares, soldShares, disallowedLotID);
                            }
                        }
                    }
                    Console.WriteLine("");
                }
            }
        }

        /**\brief Efficient Frontier
        *
        * In the following Risk-Reward Efficient Frontier problem, we have chosen the
        * return constraint, specifying a lower bound of 0% turnover, upper bound of 
        * 10% return and ten points.  
        */
        public void Tutorial_11a()
        {
            Initialize("11a", "Efficient Frontier", true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 11a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CFrontier frontier = m_Case.InitFrontier(EFrontierType.eRISK_RETURN);

            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.0, 0.1);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            m_Solver = m_WS.CreateSolver(m_Case, "");

            // m_dumpFilename contains all work space data that are useful for debugging
            if (m_DumpFilename.Length > 0) m_WS.Serialize(m_DumpFilename, true);

            Console.WriteLine( "\nNon-Interactive approach..." );

            CStatus oStatus = m_Solver.Optimize();

            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

            CFrontierOutput frontierOutput = m_Solver.GetFrontierOutput();
            for (int i = 0; i < frontierOutput.GetNumDataPoints(); i++)
            {
                CDataPoint dataPoint = frontierOutput.GetFrontierDataPoint(i);

                Console.WriteLine(
                        "Risk(%) = {0:0.000} \tReturn(%) = {1:0.000}", dataPoint.GetRisk(), dataPoint.GetReturn());
            }
            Console.WriteLine();

            Console.WriteLine("Interactive approach...");
            m_Solver.SetCallBack(new CSharpCallBack());
            CStatus oStatus2 = m_Solver.Optimize();
            Console.WriteLine(oStatus2.GetMessage());
            Console.WriteLine();
        }

        /**\brief Utility-Factor Constraint Frontier
        *
        * In the following Utility-Factor Constraint Frontier problem, we illustrate the effect of varying
        * factor bound on the optimal portfolio's utility, specifying a lower bound of 0% and 
        * upper bound of 7% exposure to Factor_1A, and 10 data points.
        */
        public void Tutorial_11b()
        {
            Initialize("11b", "Factor Constraint Frontier", true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 11b", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Create a factor constraint for Factor_1A for the frontier
            CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo factorCons = linear.SetFactorRange("Factor_1A");

            // Vary exposure to Factor_1A between 0% and 7% with 10 data points
            CFrontier frontier = m_Case.InitFrontier(EFrontierType.eUTILITY_FACTOR);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.0, 0.07);
            frontier.SetFrontierConstraintID(factorCons.GetID());

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            m_Solver = m_WS.CreateSolver(m_Case, "");

            // m_dumpFilename contains all work space data that are useful for debugging
            if (m_DumpFilename.Length > 0) m_WS.Serialize(m_DumpFilename, true);

            CStatus oStatus = m_Solver.Optimize();
            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

            CRiskModel rm = m_WS.GetRiskModel("GEM");
            CFrontierOutput frontierOutput = m_Solver.GetFrontierOutput();
            for (int i = 0; i < frontierOutput.GetNumDataPoints(); i++)
            {
                CDataPoint dataPoint = frontierOutput.GetFrontierDataPoint(i);

                Console.WriteLine("Utility = {0:0.000000} \tRisk(%) = {1:0.000} \tReturn(%) = {2:0.000}",
                    dataPoint.GetUtility(), dataPoint.GetRisk(), dataPoint.GetReturn());

                Console.WriteLine("Optimal portfolio exposure to Factor_1A = {0:0.0000}", dataPoint.GetConstraintSlack());
            }
            Console.WriteLine();
        }

        /**\brief Utility-General Linear Constraint Frontier
        *
        * In the following Utility-General Linear Constraint Frontier problem, we illustrate the effect of varying
        * sector exposure on the optimal portfolio's utility, specifying a lower bound of 10% and 
        * upper bound of 20% exposure to Information Technology sector, and 10 data points.
        */
        public void Tutorial_11c()
        {

            Initialize("11c", "General Linear Constraint Frontier", true);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                {
                    // Set GICS Sector attribute
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i], 1.0);
                }
            }

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 11c", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set a constraint to GICS_SECTOR - Information Technology
            CLinearConstraints linearCon = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo groupCons = linearCon.AddGroupConstraint("GICS_SECTOR", "Information Technology");

            CFrontier frontier = m_Case.InitFrontier(EFrontierType.eUTILITY_GENERAL_LINEAR);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.1, 0.2);
            frontier.SetFrontierConstraintID(groupCons.GetID());

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);
            
            m_Solver = m_WS.CreateSolver(m_Case, "");

            // m_dumpFilename contains all work space data that are useful for debugging
            if (m_DumpFilename.Length > 0) m_WS.Serialize(m_DumpFilename, true);

            CStatus oStatus = m_Solver.Optimize();
            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

            CFrontierOutput frontierOutput = m_Solver.GetFrontierOutput();
            for (int i = 0; i < frontierOutput.GetNumDataPoints(); i++)
            {
                CDataPoint dataPoint = frontierOutput.GetFrontierDataPoint(i);

                Console.WriteLine("Utility = {0:0.000000} \tRisk(%) = {1:0.000} \tReturn(%) = {2:0.000}",
                    dataPoint.GetUtility(), dataPoint.GetRisk(), dataPoint.GetReturn());
                Console.WriteLine("Optimal portfolio exposure to Information Technology = {0:0.0000}",
                    dataPoint.GetConstraintSlack());
            }
            Console.WriteLine();
        }

        /**\brief Utility-Leaverage Frontier
        *
        * In the following Utility-Leverage Frontier problem, we illustrate the effect of varying
        * total leverage range, specifying a lower bound of 30% and upper bound of 70%, and 10 data points.
        */
        public void Tutorial_11d()
        {

            Initialize("11d", "Utility-Leaverage Frontier", true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 11d", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set hedge settings
            m_TradeUniverse.AddAsset("CASH");		// Cash is required for L/S optimization 
            CHedgeConstraints hedgeConstr = m_Case.InitConstraints().InitHedgeConstraints();
            CConstraintInfo info = hedgeConstr.SetTotalLeverageRange();
 
            // Vary total leverage range between 30% and 70% with 10 data points
            CFrontier frontier = m_Case.InitFrontier(EFrontierType.eUTILITY_HEDGE);
            frontier.SetMaxNumDataPoints(10);
            frontier.SetFrontierRange(0.3, 0.7);
            frontier.SetFrontierConstraintID(info.GetID());

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            m_Solver = m_WS.CreateSolver(m_Case);

            // m_dumpFilename contains all work space data that are useful for debugging
            if (m_DumpFilename.Length > 0) m_WS.Serialize(m_DumpFilename, true);

            CStatus oStatus = m_Solver.Optimize();
            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

            CFrontierOutput frontierOutput = m_Solver.GetFrontierOutput();
            if (frontierOutput != null)
            {
                for (int i = 0; i < frontierOutput.GetNumDataPoints(); i++)
                {
                    CDataPoint dataPoint = frontierOutput.GetFrontierDataPoint(i);

                    Console.WriteLine("Utility = {0:0.000000}   Total leverage = {1:0.000}",
                        dataPoint.GetUtility(), dataPoint.GetConstraintSlack());
                }
            }
            else
                Console.WriteLine("Invalid frontier");

            Console.WriteLine();
        }
        
        /**\brief Constraint hierarchy
        *
        * This tutorial illustrates how to set up constraint hierarchy
        */
        public void Tutorial_12a()
        {
            Initialize("12a", "Constraint Hierarchy", true);

            // Create a case object. Set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 12a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CConstraints constraints = m_Case.InitConstraints();

            // Set minimum holding threshold; both for long and short positions
            // in this example 10%
            CParingConstraints paring = constraints.InitParingConstraints();
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_LONG, 0.1);
            paring.AddLevelParing(ELevelParingType.eMIN_HOLDING_SHORT, 0.1);

            // Set minimum trade size; both for long and short positions
            // in this example 20%
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_LONG, 0.2);
            paring.AddLevelParing(ELevelParingType.eMIN_TRANX_SHORT, 0.2);

            // Set Min # assets to 5, excluding cash and futures
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_ASSETS).SetMin(5);

            // Set Max # trades to 3 
            paring.AddAssetTradeParing(EAssetTradeParingType.eNUM_TRADES).SetMax(3);

            // Set hedge settings
            m_TradeUniverse.AddAsset("CASH", 0.0);		// Cash is required for L/S optimization 
            CHedgeConstraints hedgeConstr = constraints.InitHedgeConstraints();
            CConstraintInfo conInfo1 = hedgeConstr.SetLongSideLeverageRange(false);
            conInfo1.SetLowerBound(1.0, ERelativeMode.eABSOLUTE);
            conInfo1.SetUpperBound(1.1, ERelativeMode.eABSOLUTE);
            CConstraintInfo conInfo2 = hedgeConstr.SetShortSideLeverageRange(false);
            conInfo2.SetLowerBound(-0.3, ERelativeMode.eABSOLUTE);
            conInfo2.SetUpperBound(-0.3, ERelativeMode.eABSOLUTE);
            CConstraintInfo conInfo3 = hedgeConstr.SetTotalLeverageRange(false);
            conInfo3.SetLowerBound(1.5, ERelativeMode.eABSOLUTE);
            conInfo3.SetUpperBound(1.5, ERelativeMode.eABSOLUTE);

            // Set constraint hierarchy
            CConstraintHierarchy hier = constraints.InitConstraintHierarchy();
            hier.AddConstraintPriority(ECategory.eASSET_PARING, ERelaxOrder.eFIRST);
            hier.AddConstraintPriority(ECategory.eHEDGE, ERelaxOrder.eSECOND);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            //
            //constraint retrieval
            //
  	        //upper & lower bounds
            PrintLowerAndUpperBounds(ref hedgeConstr);
            //paring constraint
            PrintParingConstraints(ref paring);
            //constraint hierachy
            PrintConstraintPriority(ref hier);

            RunOptimize();
        }

        /** \brief Shortfall Beta Constraint
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for setting up shortfall beta constraint.  The shortfall beta data are 
        * read from a file that is an output file of BxR example.
        */
        public void Tutorial_14a()
	    {
		    Initialize( "14a", "Shortfall Beta Constraint", true );

		    // Create a case object, null trade universe
		    m_Case = m_WS.CreateCase("Case 14a", m_InitPf, m_TradeUniverse, 100000, 0.0);
		    m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));
		    m_Case.SetRiskTarget(0.05);

		    // Read shortfall beta from a file
		    m_Data.ReadShortfallBeta();

		    CAttributeSet attributeSet = m_WS.CreateAttributeSet();
		    for(int i=0; i<m_Data.m_AssetNum; i++) {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) == 0)
                    continue;

			    attributeSet.Set( m_Data.m_ID[i], m_Data.m_Shortfall_Beta[i] );
		    }

		    CLinearConstraints linearCon = m_Case.InitConstraints().InitLinearConstraints(); 

		    // Add coefficients with shortfall beta data read from file
		    CConstraintInfo oShortfallBetaInfo = linearCon.AddGeneralConstraint(attributeSet);
    		
		    // Set lower/upper bounds for shortfall beta
		    oShortfallBetaInfo.SetID("ShortfallBetaCon");
		    oShortfallBetaInfo.SetLowerBound(0.9, ERelativeMode.eABSOLUTE);
		    oShortfallBetaInfo.SetUpperBound(0.9, ERelativeMode.eABSOLUTE);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
		    util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            //constraint retrieval
  	        PrintLowerAndUpperBounds(ref linearCon);
            CAttributeSet coef = linearCon.GetCoefficients("ShortfallBetaCon");
            PrintAttributeSet(coef, "The Coefficients are:"); 
    		
		    RunOptimize();

		    CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		    if ( output != null ) {
			    CSlackInfo slackInfo = output.GetSlackInfo("ShortfallBetaCon");
                if (slackInfo != null)
                {
                    Console.WriteLine("Shortfall Beta Con Slack = {0:0.0000}", slackInfo.GetSlackValue());
                    Console.WriteLine();
                }
		    }
	    }
        /** \brief Minimizing Total Risk from both of primary and secondary risk models
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for minimizing Total Risk from both of primary and secondary risk models
        * and set a constraint for a factor in the secondary risk model.
        */
        public void Tutorial_15a()
        {
            // Create WorkSpace and setup Risk Model data,
            // Create initial portfolio, etc; no alpha
            Initialize("15a", "Minimize Total Risk from 2 Models");

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 15a", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Setup Secondary Risk Model 
            SetupRiskModel2();
            CRiskModel riskModel2 = m_WS.GetRiskModel("MODEL2");
            m_Case.SetSecondaryRiskModel(riskModel2);

            // Set secondary factor range
            CLinearConstraints linearConstraint = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linearConstraint.SetFactorRange("Factor2_2", false);
            info.SetLowerBound(0.00);
            info.SetUpperBound(0.40);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            // for primary risk model; No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            // for secondary risk model; No benchmark
            util.SetSecondaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();
        }

        /** \brief Constrain risk from secondary risk model
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for constraining risk from secondary risk model
        */
        public void Tutorial_15b()
	    {
		    Initialize( "15b", "Risk Budgeting - Dual Risk Model" );

		    // Create a case object, set initial portfolio and trade universe
		    CRiskModel riskModel = m_WS.GetRiskModel("GEM");
		    m_Case = m_WS.CreateCase("Case 15b", m_InitPf, m_TradeUniverse, 100000, 0.0);
		    m_Case.SetPrimaryRiskModel(riskModel);

		    // Setup Secondary Risk Model 
		    SetupRiskModel2();
		    CRiskModel riskModel2 = m_WS.GetRiskModel("MODEL2");
		    m_Case.SetSecondaryRiskModel(riskModel2);

		    CRiskConstraints riskConstraint = m_Case.InitConstraints().InitRiskConstraints();

		    // Set total risk from the secondary risk model 
		    CConstraintInfo info = riskConstraint.AddPLTotalConstraint(false, m_ModelPortfolio);
		    info.SetID( "RiskConstraint" );
		    info.SetUpperBound(0.1, ERelativeMode.eABSOLUTE);

		    CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

		    // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
		    util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

		    RunOptimize();

		    CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		    if ( output != null ) {
			    CSlackInfo slackInfo = output.GetSlackInfo("RiskConstraint");
			    if ( slackInfo != null )
				    Console.WriteLine("Risk Constraint Slack = {0:0.0000}", slackInfo.GetSlackValue());
		    }
	    }

        /** \brief Risk Parity Constraint
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * to set risk parity constraint.
        */
        public void Tutorial_15c()
        {
            // Create WorkSpace and setup Risk Model data,
            // Create initial portfolio, etc; no alpha
            Initialize("15c", "Risk parity constraint");

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 15c", m_InitPf, m_TradeUniverse, 100000);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CUtility util = m_Case.InitUtility();

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            // Create set of asset IDs to be included
            CIDSet ids = m_WS.CreateIDSet();
            for (int i = 0; i < m_Data.m_AssetNum; i++) {
                if (string.Compare(m_Data.m_ID[i], "USA11I1") == 0)
                    continue;

                ids.Add(m_Data.m_ID[i]);
            }

            // Set case as long only and set risk parity constraint
            CConstraints constraints = m_Case.InitConstraints();
            CLinearConstraints linConstraint = constraints.InitLinearConstraints();
            linConstraint.SetTransactionType(ETranxType.eSHORT_NONE);
            CRiskConstraints riskConstraint = constraints.InitRiskConstraints();
            riskConstraint.SetRiskParity(ERiskParityType.eASSET_RISK_PARITY, ids, true, null, false);

	        RunOptimize();
        }

        /** \brief Additional covariance term
        *
        * This self-documenting sample code illustrates how to specify the
        * additional covariance term that is added to the objective function.
        * 
        */
        public void Tutorial_16a()
        {
            Initialize("16a", "Additional covariance term - WXFX'W");

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 16a", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Setup Secondary Risk Model 
            SetupRiskModel2();
            CRiskModel riskModel2 = m_WS.GetRiskModel("MODEL2");
            m_Case.SetSecondaryRiskModel(riskModel2);

            // Setup weight matrix
            CAttributeSet attributeSet = m_WS.CreateAttributeSet();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) == 0)
                    continue;

                attributeSet.Set(m_Data.m_ID[i], 1);
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            // Sets the covariance term type = WXFXW with a benchmark and weight matrix, 
            // using secondary risk model
            util.AddCovarianceTerm(0.0075, ECovTermType.eWXFXW, m_BMPortfolio, attributeSet, false);

            RunOptimize();

        }

        /** \brief Additional covariance term
        *
        * This self-documenting sample code illustrates how to specify the
        * additional covariance term that is added to the objective function.
        * 
        */
        public void Tutorial_16b()
        {
            Initialize("16b", "Additional covariance term - XWFWX'");

            // Create a case object, null trade universe
            m_Case = m_WS.CreateCase("Case 16b", m_InitPf, null, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Setup weight matrix
            CAttributeSet attributeSet = m_WS.CreateAttributeSet();
            for (int i = 0; i < m_Data.m_FactorNum; i++)
            {
                attributeSet.Set(m_Data.m_Factor[i], 1);
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075;
            // No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            // Sets the covariance term type = XWFWX and the weight matrix
            // using primary risk model
            util.AddCovarianceTerm(0.0075, ECovTermType.eXWFWX, null, attributeSet, true);

            RunOptimize();

        }

        /** \brief Five-Ten-Forty Rule
        *
        * This self-documenting sample code illustrates how to apply the 5/10/40 rule
        * 
        */
        public void Tutorial_17a()
        {
            Initialize("17a", "Five-Ten-Forty Rule");

            // Create a case object and trade universe
            m_Case = m_WS.CreateCase("Case 17a", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set issuer for each asset
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetIssuer(m_Data.m_Issuer[i]);
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
            // No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            CConstraints constraints = m_Case.InitConstraints();

            C5_10_40Rule fiveTenFortyRule = constraints.Init5_10_40Rule();
            fiveTenFortyRule.SetRule(5, 10, 40);

            RunOptimize();
        }

        /** \brief Factor block structure
        *
        * This self-documenting sample code illustrates how to set up the factor block structure in
        * a risk model. 
        */
        public void Tutorial_18()
        {
            Initialize("18", "Factor exposure block");

            // Create a case object and trade universe
            m_Case = m_WS.CreateCase("Case 18", m_InitPf, m_TradeUniverse, 100000, 0.0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            CRiskModel riskModel;
            riskModel = m_WS.GetRiskModel("GEM");

            CIDSet factorGroupA;
            factorGroupA = m_WS.CreateIDSet();

            factorGroupA.Add("Factor_1A");
            factorGroupA.Add("Factor_2A");
            factorGroupA.Add("Factor_3A");
            factorGroupA.Add("Factor_4A");
            factorGroupA.Add("Factor_5A");
            factorGroupA.Add("Factor_6A");
            factorGroupA.Add("Factor_7A");
            factorGroupA.Add("Factor_8A");
            factorGroupA.Add("Factor_9A");
            riskModel.AddFactorBlock("A", factorGroupA);

            CIDSet factorGroupB;
            factorGroupB = m_WS.CreateIDSet();
            factorGroupB.Add("Factor_1B");
            factorGroupB.Add("Factor_2B");
            factorGroupB.Add("Factor_3B");
            factorGroupB.Add("Factor_4B");
            factorGroupB.Add("Factor_5B");
            factorGroupB.Add("Factor_6B");
            factorGroupB.Add("Factor_7B");
            factorGroupB.Add("Factor_8B");
            factorGroupB.Add("Factor_9B");
            riskModel.AddFactorBlock("B", factorGroupB);

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

            RunOptimize();
        }

        /** \brief Load Models Direct risk model data
        *
        * This self-documenting sample code illustrates how to load Models Direct data into USE4L risk model.
        */
        public void Tutorial_19()
        {
	        Initialize( "19", "Load risk model using Models Direct files" );

	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 19", m_InitPf, m_TradeUniverse, 100000);

	        // Specify the set of assets to load exposures and specific risk for
	        CIDSet idSet = m_WS.CreateIDSet();
	        for(int i=0; i<m_Data.m_AssetNum; i++) {
		        if (m_Data.m_ID[i].Equals("CASH"))
			        continue;

		        idSet.Add(m_Data.m_ID[i]);
	        }

	        // Create the risk model with the Barra model name
	        CRiskModel rm = m_WS.CreateRiskModel("USE4L");

	        // Load Models Direct data given location of the files, anaylsis date, and asset set
            ERiskModelStatus status = rm.LoadModelsDirectData(m_Data.m_Datapath, 20130501, idSet);
	        if (status != ERiskModelStatus.eSUCCESS) {
		        Console.WriteLine("Failed to load risk model data using Models Direct files");
		        return;
	        }
	        m_Case.SetPrimaryRiskModel(rm);

	        CLinearConstraints linear = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linear.SetFactorRange("USE4L_SIZE");
	        info.SetLowerBound(0.02);
	        info.SetUpperBound(0.05);

	        CUtility util = m_Case.InitUtility();

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        RunOptimize();

	        CPortfolioOutput pfOut = m_Solver.GetPortfolioOutput();
	        if ( pfOut != null ) {
                CSlackInfo slackInfo = pfOut.GetSlackInfo("USE4L_SIZE");

		        if ( slackInfo != null){
                    Console.WriteLine("Optimal portfolio exposure to USE4L_SIZE = {0:0.0000}", slackInfo.GetSlackValue());
		        }
	        }
        }

        /** \brief Change numeraire with Models Direct risk model data
        *
        * This self-documenting sample code illustrates how to change numeraire with Models Direct data
        */
        public void Tutorial_19b()
        {
	        Initialize( "19b", "Change numeraire with risk model loaded from Models Direct data", true );

	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 19b", m_InitPf, m_TradeUniverse, 100000);

	        // Specify the set of assets to load exposures and specific risk for
	        CIDSet idSet = m_WS.CreateIDSet();
	        for(int i=0; i<m_Data.m_AssetNum; i++) {
                if (m_Data.m_ID[i].Equals("CASH"))
			        continue;

		        idSet.Add(m_Data.m_ID[i]);
	        }

	        // Create the risk model with the Barra model name
	        CRiskModel pRM = m_WS.CreateRiskModel("GEM3L");

	        // Load Models Direct data given location of the files, anaylsis date, and asset set
	        ERiskModelStatus rmStatus = pRM.LoadModelsDirectData(m_Data.m_Datapath, 20131231, idSet);
            if (rmStatus != ERiskModelStatus.eSUCCESS)
            {
                Console.WriteLine("Failed to load risk model data using Models Direct files");
                return;
            } 

	        // Change numeraire to GEM3L_JPNC
	        CStatus numStatus = pRM.SetNumeraire("GEM3L_JPNC");
            if (numStatus.GetStatusCode() != EStatusCode.eOK)
            {
                Console.WriteLine(numStatus.GetMessage());
                Console.WriteLine(numStatus.GetAdditionalInfo());
                return;
            } 

	        m_Case.SetPrimaryRiskModel(pRM);

	        CUtility util = m_Case.InitUtility();

	        // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        RunOptimize();
        }

       /** \brief Loading asset exposures with CSV file
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * to load asset exposures with CSV file.
        */
        public void Tutorial_20()
	    {
		    Console.WriteLine("======== Running Tutorial 20 ========" );
		    Console.WriteLine("Minimize Total Risk" );
            SetupDumpFile ("20");

		    // Create a workspace and setup risk model data without asset exposures
		    SetupRiskModel(false);

		    // Load asset exposures from asset_exposures.csv
		    CRiskModel rm = m_WS.GetRiskModel("GEM");
		    CStatus status = rm.LoadAssetExposures(m_Data.m_Datapath + "asset_exposures.csv");
		    if (status.GetStatusCode() != EStatusCode.eOK) {
			    Console.WriteLine("Error loading asset exposures data: " + status.GetMessage());
                Console.WriteLine(status.GetAdditionalInfo());
		    }

		    // Create initial portfolio etc
		    SetupPortfolios();
    		
		    // Create a case object, null trade universe
		    m_Case = m_WS.CreateCase("Case 20", m_InitPf, null, 100000);
		    m_Case.SetPrimaryRiskModel(rm);

		    CUtility util = m_Case.InitUtility();

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

		    RunOptimize();
	    }

        /** \brief Retrieve constraint & asset KKT attribution terms
        *
        * This sample code illustrates how to use Barra Optimizer
        * to retrieve KKT terms of constraint and asset attributions 
        */
        public void Tutorial_21(){
		    Console.WriteLine("======== Running Tutorial 21 ========");
            Console.WriteLine("Retrieve KKT terms of constraint & asset attributions");
		    SetupDumpFile("21");

		    // Create a CWorkSpace instance; Release the existing one.
		    if ( m_WS!=null )
			    m_WS.Release();

		    m_WS = CWorkSpace.DeSerialize(m_Data.m_Datapath + "21.wsp");
		    m_Solver = m_WS.GetSolver(m_WS.GetSolverIDs().GetFirst());

		    RunOptimize(true);

		    CollectKKT();
	    }

        /** \brief Multi-period optimization
        *
        * The sample code illustrates how to set up a multi-period optimization for 2 periods.
        */
        public void Tutorial_22(){
	        Initialize( "22", "Multi-period optimization" );

	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 22", m_InitPf, m_TradeUniverse, 100000);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        // Set alphas, utility, constraints for period 1
	        m_WS.SwitchPeriod(1);
	        for( int i=0; i<m_Data.m_AssetNum; i++ ) {
		        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
		        asset.SetAlpha(m_Data.m_Alpha[i]);
	        }
	        // Set utility term
	        CUtility util = m_Case.InitUtility();
	        util.SetAlphaTerm(1.0);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        // Set constraints
	        CLinearConstraints linearConstraint = m_Case.InitConstraints().InitLinearConstraints();
	        CConstraintInfo range1 = linearConstraint.SetAssetRange("USA11I1");
	        range1.SetLowerBound(0.1);

	        // Set alphas, utility, constraints for period 2
	        m_WS.SwitchPeriod(2);
	        for( int i=0; i<m_Data.m_AssetNum; i++ ) {
		        CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
		        asset.SetAlpha(m_Data.m_Alpha[m_Data.m_AssetNum-1-i]);
	        }
	        // Set utility term
	        util.SetAlphaTerm(1.5);

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        // Set constraints
	        CConstraintInfo range = linearConstraint.SetAssetRange("USA13Y1");
	        range.SetLowerBound(0.2);

	        // Set cross-period constraint
	        CConstraintInfo turnoverConstraint = m_Case.GetConstraints().InitTurnoverConstraints().SetCrossPeriodNetConstraint();
	        turnoverConstraint.SetUpperBound(0.5);
	
	        m_Solver = m_WS.CreateSolver(m_Case);

	        // Add periods for multi-period optimization
	        m_Solver.AddPeriod(1);
	        m_Solver.AddPeriod(2);

            // Dump wsp file
            if (m_DumpFilename.Length > 0)
                m_WS.Serialize(m_DumpFilename, true);

	        CStatus oStatus = m_Solver.Optimize();

            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

	        if( oStatus.GetStatusCode() == EStatusCode.eOK ) {
		        CMultiPeriodOutput output = m_Solver.GetMultiPeriodOutput();
		        if ( output!=null ) {
			        // Retrieve cross-period output
			        CPortfolioOutput pCrossPeriodOutput = output.GetCrossPeriodOutput();
			        Console.WriteLine("Period      = Cross-period");
			        Console.WriteLine("Return(%)   = {0:0.0000}", pCrossPeriodOutput.GetReturn());
			        Console.WriteLine("Utility     = {0:0.0000}", pCrossPeriodOutput.GetUtility());
			        Console.WriteLine("Turnover(%) = {0:0.0000}\n", pCrossPeriodOutput.GetTurnover());

			        // Retrieve output for each period
			        for (int i=0; i<output.GetNumPeriods(); i++) {
				        CPortfolioOutput pPeriodOutput = output.GetPeriodOutput(i);
				        Console.WriteLine("Period      = {0:D}", pPeriodOutput.GetPeriodID());
				        Console.WriteLine("Risk(%)     = {0:0.0000}", pPeriodOutput.GetRisk());
				        Console.WriteLine("Return(%)   = {0:0.0000}", pPeriodOutput.GetReturn());
				        Console.WriteLine("Utility     = {0:0.0000}", pPeriodOutput.GetUtility());
				        Console.WriteLine("Turnover(%) = {0:0.0000}", pPeriodOutput.GetTurnover());
				        Console.WriteLine("Beta        = {0:0.0000}\n", pPeriodOutput.GetBeta());
			        }
		        }
	        }
        }

        /** \brief Portfolio concentration constraint
        *
        * The sample code illustrates how to run an optimization with a portfolio concentration constraint that limits
        * the total weight of 5 largest positions to no more than 70% of the portfolio.
        */
        public void Tutorial_23()
        {
	        Initialize( "23", "Portfolio concentration constraint", true );

	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 23", m_InitPf, m_TradeUniverse, 100000);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

	        // Set portfolio concentration constraint
	        CPortConcentrationConstraint portConcenCons = m_Case.InitConstraints().SetPortConcentrationConstraint();
	        portConcenCons.SetNumTopHoldings(5);
	        portConcenCons.SetUpperBound(0.7);

	        // Exclude asset USA11I1 from portfolio concentration constraint
	        CIDSet pExcludedAssets = m_WS.CreateIDSet();
	        pExcludedAssets.Add("USA11I1");
	        portConcenCons.SetExcludedAssets(pExcludedAssets);

	        CUtility util = m_Case.InitUtility();

            // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        // Run optimization and display results
	        RunOptimize();
            Console.WriteLine("Portfolio conentration={0:0.0000}",
			    m_Solver.Evaluate(EEvalType.ePORTFOLIO_CONCENTRATION, m_Solver.GetPortfolioOutput().GetPortfolio()));

        }

        /** \brief Multi-account optimization
        *
        * The sample code illustrates how to set up a multi-account optimization for 2 accounts.
        */
        public void Tutorial_25a()
        {
	        Initialize( "25a", "Multi-account optimization", true);

	        // Create a case object, set initial portfolio and trade universe
	        m_Case = m_WS.CreateCase("Case 25a", null, m_TradeUniverse, 1.0e+5);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

        // Set constraints for each individual accounts

	        m_WS.SwitchAccount(1);
	        // Set initial portfolio and base value for account 1
	        m_Case.SetPortBaseValue(1.0e+5);
	        m_Case.SetInitialPort(m_InitPfs[0]);
	        // Set utility term
	        CUtility util = m_Case.InitUtility();
	        util.SetAlphaTerm(1.0);

	        // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);

	        // Set constraints
	        CLinearConstraints linearConstraint = m_Case.InitConstraints().InitLinearConstraints();
	        CConstraintInfo range1 = linearConstraint.SetAssetRange("USA11I1");
	        range1.SetLowerBound(0.1);

            m_WS.SwitchAccount(2);
            // set up a different universe for account 2
            CPortfolio tradeUniverse2 = m_WS.CreatePortfolio("Trade Universe 2");
            for (int i = 0; i < m_Data.m_AssetNum - 3; i++)
                tradeUniverse2.AddAsset(m_Data.m_ID[i]);
            m_Case.SetTradeUniverse(tradeUniverse2);
            
            // Set initial portfolio and base value for account 2
	        m_Case.SetInitialPort(m_InitPfs[1]);
	        m_Case.SetPortBaseValue(3.0e+5);
	        // Set alphas, utility, constraints for account 2
	        // Set utility term
	        util.SetAlphaTerm(1.5);

	        // Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	        util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);

	        // Set constraints
	        CConstraintInfo range = linearConstraint.SetAssetRange("USA13Y1");
	        range.SetLowerBound(0.2);

        // Set constraints for all accounts and/or cross-account

	        m_WS.SwitchAccount(barraopt.ALL_ACCOUNT);
	        // Set joint market impact transaction cost
	        util.SetJointMarketImpactTerm(0.5);

	        // Set the piecewise linear transaction cost
	        CAsset asset = m_WS.GetAsset("USA11I1");
	        if (asset != null)
	        {
		        asset.AddPWLinearBuyCost(0.002833681, 1000.0);
		        asset.AddPWLinearBuyCost(0.003833681);
		        asset.AddPWLinearSellCost(0.003833681);
	        }
	        asset = m_WS.GetAsset("USA13Y1");
	        if (asset != null ) {
		        asset.AddPWLinearBuyCost(0.00287745);
		        asset.AddPWLinearSellCost(0.00387745);
	        }
	        asset = m_WS.GetAsset("USA1LI1");
	        if (asset != null )
	        {
		        asset.AddPWLinearBuyCost(0.00227745);
		        asset.AddPWLinearSellCost(0.00327745);
	        }

	        // Set cross-account constraint
	        CConstraintInfo turnoverConstraint = m_Case.GetConstraints().InitCrossAccountConstraints().SetNetTurnoverConstraint();
	        // cross-account constraint is specified in actual $ amount as opposed to percentage amount
	        // the portfolio base value is the aggregate of base values of all accounts' 
	        turnoverConstraint.SetUpperBound(0.5*(1.0e5 + 3.0e5));

	        m_Solver = m_WS.CreateSolver(m_Case);

	        // Add accounts for multi-account optimization
	        m_Solver.AddAccount(1);
	        m_Solver.AddAccount(2);

	        // Dump wsp file
	        if ( m_DumpFilename.Length > 0) 
		        m_WS.Serialize(m_DumpFilename, true);

	        CStatus oStatus = m_Solver.Optimize();

            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());
	
	        if( oStatus.GetStatusCode() == EStatusCode.eOK ) {
		        CMultiAccountOutput output = m_Solver.GetMultiAccountOutput();
		        if ( output != null ) {
			        // Retrieve cross-account output
			        CPortfolioOutput pCrossAccountOutput = output.GetCrossAccountOutput();
                    Console.WriteLine("Account     = Cross-account");
                    Console.WriteLine("Return(%)   = {0:0.0000}", pCrossAccountOutput.GetReturn());
                    Console.WriteLine("Utility     = {0:0.0000}", pCrossAccountOutput.GetUtility());
                    Console.WriteLine("Turnover(%) = {0:0.0000}", pCrossAccountOutput.GetTurnover());
                    Console.WriteLine("Joint Market Impact Buy Cost($) = {0:0.0000}", output.GetJointMarketImpactBuyCost());
                    Console.WriteLine("Joint Market Impact Sell Cost($) = {0:0.0000}\n", output.GetJointMarketImpactSellCost());
			        // Retrieve output for each account
			        for (int i=0; i<output.GetNumAccounts(); i++) {
				        CPortfolioOutput pAccountOutput = output.GetAccountOutput(i);
                        Console.WriteLine("Account     = {0:D}", pAccountOutput.GetAccountID());
                        Console.WriteLine("Risk(%)     = {0:0.0000}", pAccountOutput.GetRisk());
                        Console.WriteLine("Return(%)   = {0:0.0000}", pAccountOutput.GetReturn());
                        Console.WriteLine("Utility     = {0:0.0000}", pAccountOutput.GetUtility());
                        Console.WriteLine("Turnover(%) = {0:0.0000}", pAccountOutput.GetTurnover());
                        Console.WriteLine("Beta        = {0:0.0000}\n", pAccountOutput.GetBeta());
			        }
		        }
	        }
        }

		/** \brief Multi-account tax-aware optimization with 2 accounts
		*
		* This example illustrates how to set up a multi-account tax-aware
		* optimization for 2 accounts with cross-account tax bound
		* and an account-level tax bound.
		*/
		public void Tutorial_25b()
		{
			Initialize("25b", "Multi-account tax-aware optimization", true, true);

			// Create a case object, set initial portfolio and trade universe
			m_Case = m_WS.CreateCase("Case 25b", null, m_TradeUniverse, 0);
			m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

			// Use CMAOTax for tax settings
			CMAOTax  tax = m_Case.InitMAOTax();
			tax.SetTaxUnit(ETaxUnit.eDOLLAR);

			// Set cross-account tax limit to $40
			CConstraints  oCons = m_Case.InitConstraints();
			oCons.InitCrossAccountConstraints().SetTaxLimit().SetUpperBound(40);

			//
			// Account 1
			//
			m_WS.SwitchAccount(1);
			// Set tax lots, initial portfolio and base value for account 1
			m_Case.SetInitialPort(m_InitPfs[0]);
			m_Case.SetPortBaseValue(m_PfValue[0]);
			// Narrow the trade universe
			CPortfolio tradeUniverse = m_WS.CreatePortfolio("Trade Universe 1");
			for (int i = 0; i < 3; i++)
				tradeUniverse.AddAsset(m_Data.m_ID[i]);
			m_Case.SetTradeUniverse(tradeUniverse);
			// Tax rules
			CTaxRule taxRule1 = tax.AddTaxRule();
			taxRule1.EnableTwoRate();
			taxRule1.SetTaxRate(0.243, 0.423);
			tax.SetTaxRule("*", "*", taxRule1);
			// Set selling order rule as first in/first out for all assets
			tax.SetSellingOrderRule("*", "*", ESellingOrderRule.eFIFO);
			// Set utility term
			CUtility util = m_Case.InitUtility();
			util.SetAlphaTerm(1.0);
			util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
			// Specify long-only
			CLinearConstraints linearCon = oCons.InitLinearConstraints();
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			// Tax constraints
			CNewTaxConstraints taxCon = oCons.InitNewTaxConstraints();
			taxCon.SetTaxLotTradingRule("USA13Y1_TaxLot_0", ETaxLotTradingRule.eSELL_LOT);
			taxCon.SetTaxLimit().SetUpperBound(25);

			//
			// Account 2
			//
			m_WS.SwitchAccount(2);
			m_Case.SetInitialPort(m_InitPfs[1]);
			m_Case.SetPortBaseValue(m_PfValue[1]);
			// Tax rules
			CTaxRule taxRule2 = tax.AddTaxRule();
			taxRule2.EnableTwoRate();
			taxRule2.SetTaxRate(0.1, 0.2);
			tax.SetTaxRule("*", "*", taxRule2);
			// Set utility term
			util.SetAlphaTerm(1.5);
			util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);
			// Set constraints
			// long only
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			linearCon.SetAssetRange("USA13Y1").SetUpperBound(0.2);

			// Add accounts for multi-account optimization
			m_Solver = m_WS.CreateSolver(m_Case);
			m_Solver.AddAccount(1);
			m_Solver.AddAccount(2);

			RunOptimize(true);
		}

		/** \brief Multi-account tax-aware optimization with tax arbitrage
		*
		*/
		public void Tutorial_25c()
		{
			Initialize("25c", "Multi-account optimization with tax arbitrage", true, true);

			// Create a case object, set initial portfolio and trade universe
			m_Case = m_WS.CreateCase("Case 25c", null, m_TradeUniverse, 0);
			m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

			// Use CMAOTax for tax settings
			CMAOTax tax = m_Case.InitMAOTax();
			tax.SetTaxUnit(ETaxUnit.eDOLLAR);

			CConstraints oCons = m_Case.InitConstraints();

			//
			// Account 1
			//
			m_WS.SwitchAccount(1);
			// Set tax lots, initial portfolio and base value for account 1
			m_Case.SetInitialPort(m_InitPfs[0]);
			m_Case.SetPortBaseValue(m_PfValue[0]);
			// Tax rules
			CTaxRule taxRule1 = tax.AddTaxRule();
			taxRule1.EnableTwoRate();
			taxRule1.SetTaxRate(0.243, 0.423);
			tax.SetTaxRule("*", "*", taxRule1);
			// Set utility term
			CUtility util = m_Case.InitUtility();
			util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
			// Specify long-only
			CLinearConstraints linearCon = oCons.InitLinearConstraints();
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			// Specify minimum $50 long-term capital net gain
			CNewTaxConstraints taxCon = oCons.InitNewTaxConstraints();
			taxCon.SetTaxArbitrageRange("*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_NET).SetLowerBound(50.0);

			//
			// Account 2
			//
			m_WS.SwitchAccount(2);
			m_Case.SetInitialPort(m_InitPfs[1]);
			m_Case.SetPortBaseValue(m_PfValue[1]);
			// Tax rules
			CTaxRule taxRule2 = tax.AddTaxRule();
			taxRule2.EnableTwoRate();
			taxRule2.SetTaxRate(0.1, 0.2);
			tax.SetTaxRule("*", "*", taxRule2);
			// Set utility term
			util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);
			// Long only
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			// Minimum $100 short-term capital gain
			taxCon.SetTaxArbitrageRange("*", "*", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN).SetLowerBound(100.0);

			// Add accounts for multi-account optimization
			m_Solver = m_WS.CreateSolver(m_Case);
			m_Solver.AddAccount(1);
			m_Solver.AddAccount(2);

			RunOptimize(true);
		}

		/** \brief Multi-account tax-aware optimization with tax harvesting
		*
		*/
		public void Tutorial_25d()
		{
			Initialize("25d", "Multi-account optimization with tax harvesting", true, true);

			// Create a case object, set initial portfolio and trade universe
			m_Case = m_WS.CreateCase("Case 25d", null, m_TradeUniverse, 0);
			m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

			// Use CMAOTax for tax settings
			CMAOTax tax = m_Case.InitMAOTax();
			tax.SetTaxUnit(ETaxUnit.eDOLLAR);

			CConstraints oCons = m_Case.InitConstraints();

			//
			// Account 1
			//
			m_WS.SwitchAccount(1);
			// Set tax lots, initial portfolio and base value for account 1
			m_Case.SetInitialPort(m_InitPfs[0]);
			m_Case.SetPortBaseValue(m_PfValue[0]);
			// Tax rules
			CTaxRule taxRule1 = tax.AddTaxRule();
			taxRule1.EnableTwoRate();
			taxRule1.SetTaxRate(0.243, 0.423);
			tax.SetTaxRule("*", "*", taxRule1);
			// Set utility term
			CUtility util = m_Case.InitUtility();
			util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
			// Specify long-only
			CLinearConstraints linearCon = oCons.InitLinearConstraints();
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			// Target $50 long-term capital net gain
			tax.SetTaxHarvesting("*", "*", ETaxCategory.eLONG_TERM, 50, 0.1);

			//
			// Account 2
			//
			m_WS.SwitchAccount(2);
			m_Case.SetInitialPort(m_InitPfs[1]);
			m_Case.SetPortBaseValue(m_PfValue[1]);
			// Tax rules
			CTaxRule taxRule2 = tax.AddTaxRule();
			taxRule2.EnableTwoRate();
			taxRule2.SetTaxRate(0.1, 0.2);
			tax.SetTaxRule("*", "*", taxRule2);
			// Set utility term
			util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);
			// Long only
			for (int i = 0; i < m_Data.m_AssetNum; i++)
				linearCon.SetAssetRange(m_Data.m_ID[i]).SetLowerBound(0);
			// Target $100 short-term capital net gain
			tax.SetTaxHarvesting("*", "*", ETaxCategory.eSHORT_TERM, 100.0, 0.1);

			// Add accounts for multi-account optimization
			m_Solver = m_WS.CreateSolver(m_Case);
			m_Solver.AddAccount(1);
			m_Solver.AddAccount(2);

			RunOptimize(true);
		}

        /** \brief Multi-account tax-aware optimization with account groups
        *
        */
        public void Tutorial_25e()
        {
            Initialize("25e", "Multi-account optimization with account groups", true, true);

            // Create a case object, set initial portfolio and trade universe
            m_Case = m_WS.CreateCase("Case 25e", null, m_TradeUniverse, 0);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Use CMAOTax for tax settings
            CMAOTax tax = m_Case.InitMAOTax();
            tax.SetTaxUnit(ETaxUnit.eDOLLAR);

            CConstraints oCons = m_Case.InitConstraints();
            CNewTaxConstraints taxCons = oCons.InitNewTaxConstraints();
            CLinearConstraints linearCon = oCons.InitLinearConstraints();

            //
            // Account 1
            //
            m_WS.SwitchAccount(1);
            // Set tax lots, initial portfolio and base value for account 1
            m_Case.SetInitialPort(m_InitPfs[0]);
            m_Case.SetPortBaseValue(m_PfValue[0]);
            // Set tax rules
            CTaxRule taxRule1 = tax.AddTaxRule();
            taxRule1.EnableTwoRate();
            taxRule1.SetTaxRate(0.243, 0.423);
            tax.SetTaxRule("*", "*", taxRule1);
            // Set utility term
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(m_BMPortfolio, 0.0075, 0.0075);
            // Specify long-only
            linearCon.SetTransactionType(ETranxType.eSHORT_NONE);
            // Set tax limit to 30$
            CConstraintInfo info = taxCons.SetTaxLimit();
            info.SetUpperBound(30);

            //
            // Account 2
            //
            m_WS.SwitchAccount(2);
            m_Case.SetInitialPort(m_InitPfs[1]);
            m_Case.SetPortBaseValue(m_PfValue[1]);
            // Set utility term
            util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);
            // Long only
            linearCon.SetTransactionType(ETranxType.eSHORT_NONE);

            //
            // Account 3
            //
            m_WS.SwitchAccount(3);
            m_Case.SetInitialPort(m_InitPfs[2]);
            m_Case.SetPortBaseValue(m_PfValue[2]);
            // Set utility term
            util.SetPrimaryRiskTerm(m_ModelPortfolio, 0.0075, 0.0075);
            // Long only
            linearCon.SetTransactionType(ETranxType.eSHORT_NONE);

            //
            // Account Group 1
            //

            // Tax rules
            m_WS.SwitchAccountGroup(1);
            CTaxRule taxRule2 = tax.AddTaxRule();
            taxRule2.EnableTwoRate();
            taxRule2.SetTaxRate(0.1, 0.2);
            tax.SetTaxRule("*", "*", taxRule2);
            // Joint tax limit for the group is set on the CCrossAccountConstraint object
            CCrossAccountConstraints crossAcctCons = oCons.InitCrossAccountConstraints();
            crossAcctCons.SetTaxLimit().SetUpperBound(200);

            // Add accounts for multi-account optimization
            m_Solver = m_WS.CreateSolver(m_Case);
            m_Solver.AddAccount(1);        // account 1 is stand alone
            m_Solver.AddAccount(2, 1);    // account 2 and 3 are in account group 1
            m_Solver.AddAccount(3, 1);

            RunOptimize(true);
        }

        /** \brief Issuer constraint
        *
        * This self-documenting sample code illustrates how to set up the optimization with issuer constraints
        * 
        */
        public void Tutorial_26()
        {
	        Initialize( "26", "Issuer Constraint" );

	        // Create a case object and trade universe
	        m_Case = m_WS.CreateCase("Case 26", m_InitPf, m_TradeUniverse, 100000);
	        m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set issuer for each asset
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetIssuer(m_Data.m_Issuer[i]);
            }

            CUtility util = m_Case.InitUtility(EUtilityType.eQUADRATIC);

            // Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
            // No benchmark
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            CConstraints constraints = m_Case.InitConstraints();

	        CIssuerConstraints issuerCons = constraints.InitIssuerConstraints();
	        // add a global issuer constraint
            CConstraintInfo infoGlobal = issuerCons.AddHoldingConstraint(EIssuerConstraintType.eISSUER_NET);
	        infoGlobal.SetLowerBound(0.01);
	        // add an individual issuer constraint
            CConstraintInfo infoInd = issuerCons.AddHoldingConstraint(EIssuerConstraintType.eISSUER_NET, "4");
	        infoInd.SetUpperBound(0.3);

	        RunOptimize();
        }

        /** \brief Expected Shortfall Term
        *
        * The sample code illustrates how to add an expected shortfall term to the utility.
        */
        public void Tutorial_27a()
        {
            Initialize("27a", "Expected Shortfall Term");

            // Create a case object
            m_Case = m_WS.CreateCase("Case 27a", m_InitPf, m_TradeUniverse, 100000);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set expected shortfall data
            CExpectedShortfall shortfall = m_Case.InitExpectedShortfall();
            shortfall.SetConfidenceLevel(0.90);
            CAttributeSet attrSet = m_WS.CreateAttributeSet();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
                attrSet.Set(m_Data.m_ID[i], m_Data.m_Alpha[i]);
            shortfall.SetTargetMeanReturns(attrSet);
            for (int i = 0; i < m_Data.m_ScenarioNum; i++)
            {
                for (int j = 0; j < m_Data.m_AssetNum; j++)
                    attrSet.Set(m_Data.m_ID[j], m_Data.m_ScenarioData[i,j]);
                shortfall.AddScenarioReturns(attrSet);
            }

            // Set utility terms
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);
            util.SetExpectedShortfallTerm(1.0);

            RunOptimize();
        }

        /** \brief Expected Shortfall Constraint
        *
        * The sample code illustrates how to set up an expected shortfall constraint.
        */
        public void Tutorial_27b()
        {
            Initialize("27b", "Expected Shortfall Constraint");

            // Create a case object
            m_Case = m_WS.CreateCase("Case 27b", m_InitPf, m_TradeUniverse, 100000);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Set expected shortfall data
            CExpectedShortfall shortfall = m_Case.InitExpectedShortfall();
            shortfall.SetConfidenceLevel(0.90);
            shortfall.SetTargetMeanReturns(null); // use scenario averages
            CAttributeSet attrSet = m_WS.CreateAttributeSet();
            for (int i = 0; i < m_Data.m_ScenarioNum; i++)
            {
                for (int j = 0; j < m_Data.m_AssetNum; j++)
                    attrSet.Set(m_Data.m_ID[j], m_Data.m_ScenarioData[i,j]);
                shortfall.AddScenarioReturns(attrSet);
            }

            // Set expected shortfall constraint
            CLinearConstraints linCons = m_Case.InitConstraints().InitLinearConstraints();
            CConstraintInfo info = linCons.SetExpectedShortfallConstraint();
            info.SetUpperBound(0.30);

            // Set utility terms
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();
        }

        /** \brief General Ratio Constraint
        *
        * This example illustrates how to setup a ratio constraint specifying
        * the coefficients.
        */
        public void Tutorial_28a()
        {
            Initialize("28a", "General Ratio Constraint");

            // Create a case object
            m_Case = m_WS.CreateCase("Case 28a", m_InitPf, m_TradeUniverse, 100000);
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case.SetPrimaryRiskModel(riskModel);

            // Set a constraint on the weighted average of specific variances of the first three assets
            CRatioConstraints ratioCons = m_Case.InitConstraints().InitRatioConstraints();
            CAttributeSet numeratorCoeffs = m_WS.CreateAttributeSet();
            for (int i = 1; i <= 3; i++) {
                string id = m_Data.m_ID[i];
                numeratorCoeffs.Set(id, riskModel.GetSpecificVar(id, id));
            }
            // the denominator defaults to the sum of weights of the assets of the numerator
            CConstraintInfo info = ratioCons.AddGeneralConstraint(numeratorCoeffs);
            info.SetLowerBound(0.05);
            info.SetUpperBound(0.1);

            // Set utility terms
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null) {
                CSlackInfo slackInfo = output.GetSlackInfo(info.GetID());
                Console.WriteLine("Ratio       = {0:0.0000}\n", slackInfo.GetSlackValue());
            }
        }

        /** \brief Group Ratio Constraint
        *
        * This example illustrates how to setup a ratio constraint using asset attributes.
        */
        public void Tutorial_28b()
        {
            Initialize("28b", "Group Ratio Constraint");

            // Set up GICS_SECTOR group attribute
            for (int i = 0; i < m_Data.m_AssetNum; i++) {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null) {
                    asset.SetGroupAttribute("GICS_SECTOR", m_Data.m_GICS_Sector[i]);
                }
            }

            // Create a case object
            m_Case = m_WS.CreateCase("Case 28b", m_InitPf, m_TradeUniverse, 100000);
            m_Case.SetPrimaryRiskModel(m_WS.GetRiskModel("GEM"));

            // Initialize ratio constraints
            CRatioConstraints ratioCons = m_Case.InitConstraints().InitRatioConstraints();

            // Weight of "Financials" assets can be at most half of "Information Technology" assets
            CConstraintInfo info = ratioCons.AddGroupConstraint("GICS_SECTOR","Financials", "GICS_SECTOR", "Information Technology");
            info.SetUpperBound(0.5);

            // Ratio of "Information Technology" to "Minerals" should not differ from the benchmark more than +-10%
            CConstraintInfo info2 = ratioCons.AddGroupConstraint("GICS_SECTOR", "Minerals", "GICS_SECTOR", "Information Technology");
            info2.SetReference(m_BMPortfolio);
            info2.SetLowerBound(-0.1, ERelativeMode.ePLUS);
            info2.SetUpperBound(0.1, ERelativeMode.ePLUS);

            // Set utility terms
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();

            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null) {
                CSlackInfo slackInfo = output.GetSlackInfo(info.GetID());
                Console.WriteLine("Financials / IT = {0:0.0000}", slackInfo.GetSlackValue());
                slackInfo = output.GetSlackInfo(info2.GetID());
                Console.WriteLine("Minerals / IT   = {0:0.0000}\n", slackInfo.GetSlackValue());
            }
        }


        /** \brief General Quadratic Constraint
         *
         * This example illustrates how to setup a general quadratic constraint.
         */
        public void Tutorial_29()
        {
            Initialize("29", "General Quadratic Constraint");

            // Create a case object
            m_Case = m_WS.CreateCase("Case 29", m_InitPf, m_TradeUniverse, 100000);
            CRiskModel riskModel = m_WS.GetRiskModel("GEM");
            m_Case.SetPrimaryRiskModel(riskModel);

            // Initialize quadratic constraints
            CQuadraticConstraints quadraticCons =
                m_Case.InitConstraints().InitQuadraticConstraints();

            // Create the Q matrix and set some elements
            CSymmetricMatrix Q_mat = m_WS.CreateSymmetricMatrix(3);

            Q_mat.SetElement(m_Data.m_ID[1], m_Data.m_ID[1], 0.92473646);
            Q_mat.SetElement(m_Data.m_ID[2], m_Data.m_ID[2], 0.60338704);
            Q_mat.SetElement(m_Data.m_ID[2], m_Data.m_ID[3], 0.38904854);
            Q_mat.SetElement(m_Data.m_ID[3], m_Data.m_ID[3], 0.63569677);

            // The Q matrix must be positive semidefinite
            bool is_positive_semidefinite = Q_mat.IsPositiveSemidefinite();

            // Create the q vector and set some elements
            CAttributeSet q_vect = m_WS.CreateAttributeSet();
            for (int i = 1; i < 6; i++) {
                q_vect.Set(m_Data.m_ID[i], 0.1);
            }

            // Add the constraint and set an upper bound
            CConstraintInfo info = quadraticCons.AddConstraint(Q_mat,  // Q matrix
                q_vect,  // q vector
                null);  // benchmark
            info.SetUpperBound(0.1);

            // Set utility terms
            CUtility util = m_Case.InitUtility();
            util.SetPrimaryRiskTerm(null, 0.0075, 0.0075);

            RunOptimize();
        }

        public void ParseCommandLine(String[] args)
	    {
		    bool dump=false;
		    foreach (String arg in args) {
                if (arg.Equals("-d"))
                {
                    dump = true;
                    DumpAll(true);
                }else if (arg[0] == '-'){
                    dump = false;
                    if (arg.Equals("-c"))
                        SetCompatibleMode(true);
                }else if (dump)
                    m_DumpTID.Add(arg);
		    }
		    if( m_DumpTID.Count >0 )
 			    DumpAll(false);
	    }
	
	    protected bool dumpWorkspace(String tid){
		    return m_DumpTID.Contains(tid);
	    }

        /** \brief print upper & lower bound of linear constraints
        *
        * This self-documenting sample code illustrates how to retrieve linear constraints
        * one can apply the same methods to hedge constraints, turnover constraints & risk constraints
        */
        protected void PrintLowerAndUpperBounds(ref CLinearConstraints cons)
        {
            CIDSet ids = cons.GetConstraintIDSet();
            String cid = ids.GetFirst();
            for (int i = 0; i < ids.GetCount(); i++, cid = ids.GetNext())
            {
                CConstraintInfo info = cons.GetConstraintInfo(cid);

                Console.WriteLine("constraint ID: {0:D}", info.GetID());
                Console.WriteLine("lower bound: {0:0.00}, upper bound: {1:0.00}", info.GetLowerBound(), info.GetUpperBound());
            }
        }

        /** \brief print upper & lower bound of hedge constraints
        *
        * This self-documenting sample code illustrates how to retrieve hedge constraints
        * one can apply the same methods to linear constraints, turnover constraints & risk constraints
        */
        protected void PrintLowerAndUpperBounds(ref CHedgeConstraints cons)
        {
            CIDSet ids = cons.GetConstraintIDSet();
            String cid = ids.GetFirst();
            for (int i=0; i<ids.GetCount(); i++, cid = ids.GetNext())
            {
                CConstraintInfo info = cons.GetConstraintInfo(cid);

                Console.WriteLine("constraint ID: {0:D}", info.GetID());
                Console.WriteLine("lower bound: {0:0.00}, upper bound: {1:0.00}", info.GetLowerBound(), info.GetUpperBound());
            }
        }

        /** \brief print some paring constraints
        *
        * This self-documenting sample code illustrates how to retrieve paring constraints
        */
        protected void PrintParingConstraints(ref CParingConstraints paring)
        {
		    //tailored for tutorial 12a
            if( paring.ExistsAssetTradeParingType(EAssetTradeParingType.eNUM_ASSETS) )
			    Console.WriteLine("Minimum number of assets is: {0:D}",
                    paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_ASSETS).GetMin());
            if( paring.ExistsAssetTradeParingType(EAssetTradeParingType.eNUM_TRADES) )
			    Console.WriteLine("Maximum number of trades is: {0:D}", 
                    paring.GetAssetTradeParingRange(EAssetTradeParingType.eNUM_TRADES).GetMax());

            for (int lp = (int)ELevelParingType.eMIN_HOLDING_LONG; lp <= (int)ELevelParingType.eMIN_TRANX_SHORT; lp++)
            {
                ELevelParingType lpe = (ELevelParingType)lp;
		        if( paring.ExistsLevelParingType(lpe) ){
			        switch(lpe){
                        case ELevelParingType.eMIN_HOLDING_LONG:
					        Console.WriteLine("Min holding (long) threshold is: {0:0.00}", 
                                paring.GetThreshold((ELevelParingType)lp));
					        break;
                        case ELevelParingType.eMIN_HOLDING_SHORT:
					        Console.WriteLine("Min holding (short) threshold is: {0:0.00}",
                                paring.GetThreshold((ELevelParingType)lp));
					        break;
                        case ELevelParingType.eMIN_TRANX_LONG:
					        Console.WriteLine("Min transaction (long) threshold is: {0:0.00}",
                                paring.GetThreshold((ELevelParingType)lp));
					        break;
                        case ELevelParingType.eMIN_TRANX_SHORT:
					        Console.WriteLine("Min transaction (short) threshold is: {0:0.00}",
                                paring.GetThreshold((ELevelParingType)lp));
					        break;
                        case ELevelParingType.eMIN_TRANX_BUY:
                            Console.WriteLine("Min transaction (buy) threshold is: {0:0.00}",
                                paring.GetThreshold((ELevelParingType)lp));
                            break;
                        case ELevelParingType.eMIN_TRANX_SELL:
                            Console.WriteLine("Min transaction (sell) threshold is: {0:0.00}",
                                paring.GetThreshold((ELevelParingType)lp));
                            break;
			        }
		        }
	        }
            Console.WriteLine();
        }

        /** \brief print constraint priority
        *
        * This self-documenting sample code illustrates how to retrieve constraint hierachy
        */
        protected void PrintConstraintPriority(ref CConstraintHierarchy hier)
        {	
            ECategory[] cate = {
			    ECategory.eLINEAR,
			    ECategory.eFACTOR,
			    ECategory.eTURNOVER,
			    ECategory.eTRANSACTIONCOST,
			    ECategory.eHEDGE,
			    ECategory.ePARING,
			    ECategory.eASSET_PARING,
			    ECategory.eHOLDING_LEVEL_PARING,
			    ECategory.eTRANXSIZE_LEVEL_PARING,
			    ECategory.eTRADE_PARING,
			    ECategory.eRISK,
			    ECategory.eROUNDLOTTING
		    };

		    String[] cate_string = {
			    "eLINEAR",
			    "eFACTOR",
			    "eTURNOVER",
			    "eTRANSACTIONCOST",
			    "eHEDGE",
			    "ePARING",
			    "eASSET_PARING",
			    "eHOLDING_LEVEL_PARING",
			    "eTRANXSIZE_LEVEL_PARING",
			    "eTRADE_PARING",
			    "eRISK",
			    "eROUNDLOTTING"
		    };

	        for(int i=0; i<12; i++)
                if (hier.ExistsCategoryPriority(cate[i]))
                {
                    ERelaxOrder order = hier.GetPriorityForConstraintCategory(cate[i]);
                    if (order == ERelaxOrder.eFIRST)
                        Console.WriteLine("The category priority for {0:D} is the first", cate_string[i]);
                    else if (order == ERelaxOrder.eSECOND)
                        Console.WriteLine("The category priority for {0:D} is the second", cate_string[i]);
                    else if (order == ERelaxOrder.eLAST)
                        Console.WriteLine("The category priority for {0:D} is the last", cate_string[i]);
                };
  
	        Console.WriteLine();
        }
    }
}
