#library(R6)

#dyn.load(Sys.getenv("BARRAOPT_WRAP"))
#source(Sys.getenv("BARRAOPT_WRAP_R"))

TutorialApp <- R6Class("TutorialApp",
inherit = TutorialBase, 
public = list(	
    # constructor with simulation data as the argument
    initialize = function(data){
        super$initialize(data)
        self$m_DumpTID = NULL
	},
    Initialize = function(tutorialID, description, setAlpha=FALSE, isTaxAware=FALSE){
        super$Initialize(tutorialID, description, self$dumpWorkspace(tutorialID), setAlpha, isTaxAware)
	},
	
    SetupDumpFile = function(tutorialID){
        super$SetupDumpFileBase(tutorialID, self$dumpWorkspace(tutorialID))
	},
	m_DumpTID = NULL,
    dumpWorkspace = function(tid){
		for( d in self$m_DumpTID ){
			if(d==tid)
				return(TRUE)
		}
		return(FALSE)
	},
	ParseCommandLine = function(argv){
        dump = FALSE
        for (arg in argv){
            if (arg=='-d'){ 
                dump = TRUE
                self$DumpAll(TRUE)
            }else if(grepl('-', arg, fixed = TRUE)){
                dump = FALSE
                if (arg=='-c')
                    self$SetCompatibleMode(TRUE)
            }else if (dump)
                self$m_DumpTID = c(self$m_DumpTID, arg)
		}
        if (length(self$m_DumpTID)>0)
            self$DumpAll(FALSE)
	},	
	
	PrintLowerAndUpperBounds = function(cons){
        ids = cons$GetConstraintIDSet()
        cid = CIDSet_GetFirst(ids)
        while (cid !=''){
            info = cons$GetConstraintInfo(cid)
            cat(sprintf('constraint ID: %s\n', CConstraintInfo_GetID(info)))
            cat(sprintf('lower bound: %.2f, upper bound: %.2f\n', CConstraintInfo_GetLowerBound(info), CConstraintInfo_GetUpperBound(info)))
            cid = CIDSet_GetNext(ids)
		}
	},	
	## Print Some Paring Constraints
    #
    # This self-documenting sample code illustrates how to retrieve paring constraints
    #
    PrintParingConstraints = function(paring){

    #tailored for tutorial 12a
        if (paring$ExistsAssetTradeParingType('eNUM_ASSETS'))
            cat(sprintf('Minimum number of assets is: %d\n', 
				paring$GetAssetTradeParingRange('eNUM_ASSETS')$GetMin()))
        
        if (paring$ExistsAssetTradeParingType('eNUM_TRADES'))
            cat(sprintf('Maximum number of trades is: %d\n',
				paring$GetAssetTradeParingRange('eNUM_TRADES')$GetMax()))
        
        lps = c('eMIN_HOLDING_LONG', 'eMIN_HOLDING_SHORT', 'eMIN_TRANX_LONG', 
			'eMIN_TRANX_SHORT', 'eMIN_TRANX_BUY', 'eMIN_TRANX_SELL')

        msg = c('Min holding (long) threshold is:',
                'Min holding (short) threshold is:',
				'Min transaction (long) threshold is:', 
				'Min transaction (short) threshold is:',  
				'Min transaction (buy) threshold is:',
				'Min transaction (sell) threshold is:') 

        for (i in 1:6)
            if (paring$ExistsLevelParingType(lps[i]))
                cat(sprintf('%s %.2f\n', msg[i], paring$GetThreshold(lps[i])))
            
        cat('\n')
    },
    ## Print Constraint Priority
    #
    # This self-documenting sample code illustrates how to retrieve constraint hierachy
    #
    PrintConstraintPriority = function(hier){

        cate = c(
			'eLINEAR',
			'eFACTOR',
			'eTURNOVER',
			'eTRANSACTIONCOST',
			'eHEDGE',
			'ePARING',
			'eASSET_PARING',
			'eHOLDING_LEVEL_PARING',
			'eTRANXSIZE_LEVEL_PARING',
			'eTRADE_PARING',
			'eRISK',
			'eROUNDLOTTING')

        for (i in 1:12){
            if (hier$ExistsCategoryPriority(cate[i])){
                order = hier$GetPriorityForConstraintCategory(cate[i])
                if (order=='eFIRST')
                    cat(sprintf('The category priority for %s is the first\n', cate[i] ))
                else if (order=='eSECOND')
                    cat(sprintf('The category priority for %s is the second\n', cate[i] ))
                else if (order=='eLAST')
                    cat(sprintf('The category priority for %s is the last\n,', cate[i] ))
			}
		}
        cat('\n')
	},

    PrintRisksByAsset = function(portfolio){
        assetIDs = portfolio$GetAssetIDSet()

	# copy assetIDs for safe iteration (calling EvaluateRisk() might invalidate iterators)
        ids = self$m_WS$CreateIDSet()
        id = assetIDs$GetFirst()
        for (i in 1:assetIDs$GetCount()){
            ids$Add(id)
            id = assetIDs$GetNext()
        }

	id = ids$GetFirst()
        for (i in 1:ids$GetCount()){
            idset = self$m_WS$CreateIDSet()
            idset$Add(id)
            risk = self$m_Solver$EvaluateRisk(portfolio, 'eTOTALRISK', NULL, idset, NULL, TRUE, TRUE)
            idset$Release()
            if (risk != 0) {
                cat(sprintf('Risk from %s = %.4f\n', id, risk))
            }
            id = ids$GetNext()
        }

        ids$Release()
    },
	
    ## Tutorial_1a: Minimizing Total Risk
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # for minimizing Total Risk.
    #
    Tutorial_1a = function(){
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; no alpha
        self$Initialize('1a', 'Minimize Total Risk')

        # Create a case selfect
        # null trade universe

        self$m_Case = self$m_WS$CreateCase('Case 1a', self$m_InitPf, NULL, 100000.0, 0.0)
        # set up prime risk model
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        util = self$m_Case$InitUtility()
        # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
        # No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        # Run optimization
        self$RunOptimize()

        # Get the slack information for default balance constraint.
        output = self$m_Solver$GetPortfolioOutput()
        slackInfo = output$GetSlackInfo4BalanceCon()

        # Get the KKT term of the balance constraint.
        impact = slackInfo$GetKKTTerm(TRUE)
        super$PrintAttributeSet(impact, 'Balance constraint KKT term')
    },

    ## Tutorial_1b: Adding Expected Returns and Adjusting Risk Aversion 
    #
    # The previous examples maximized mean-variance utility, but did not 
    # incorporate alpha (expected returns), so the optimizer was minimizing
    # risk.  When we add returns to the objective function, the optimizer 
    # will look for global maximum utility, trading off return and risk. The
    # common factor and specific risk aversion coefficients control how much
    # disutility that risk generates (in other words, the trade off between 
    # risk and return). 
    #
    # The example Tutorial_1b is to show how to set expected return for each 
    # asset and change the risk aversion coefficients for the common factors 
    # and specific risk:
    #
    Tutorial_1b = function(){
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; 
        # Set up alpha
        self$Initialize('1b', 'Maximize Return and Minimize Total Risk', TRUE)

        # Create a case selfect
        # no trade universe
        self$m_Case = self$m_WS$CreateCase('Case 1b', self$m_InitPf, NULL, 100000, 0.0)

        # Set primary risk model
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        self$m_Case$InitUtility()

        # Statement below is optional. 
        # change risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
        # util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        # Run optimization
        self$RunOptimize()	
	},
	## Tutorial_1c: Adding a Benchmark to Minimize Active Risk
    # 
    # This sample code illustrates how to use the Barra Optimizer for 
    # minimizing Active Risk by applying a Benchmark to the utility.  
    # With this source code, we extended Tutorial_1a to include a benchmark 
    # and change the objective function in the optimizer to minimize tracking
    # error.  This is a typical workflow for an indexer (tracking a benchmark
    # while minimizing transaction costs).
    #
    Tutorial_1c = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; no alpha           
        self$Initialize( '1c', 'Minimize Active Risk' )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 1c', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        util = self$m_Case$InitUtility()

        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        
        # Run optimization
        self$RunOptimize()
	},
    ## Tutorial_1d: Roundlotting
    # 
    # Barra Optimizer returns an optimal portfolio as a set of relative 
    # weights (floating point numbers, which result in fractional shares
    # when converted to share holdings using the portfolio value). 
    #
    # The optimizer supports the use of roundlots when solving the 
    # optimization problem to generate a more realistic trade list. This
    # requires prices and round lot sizes for the trade universe and the
    # base value of the the portfolio.  The roundlot constraint may result in 
    # infeasible solutions so the user can either relax the constraints or
    # round lot the optimization result in the client application (though 
    # this may result in a "less optimal" portfolio).
    #
    # Note that enforcing the roundlot constraint ensures that the trades are roundlotted, 
    # but the final optimal weights may not be in round lots.
    # 
    # This sample code Tutorial_1d is modified from Tutorial_1b to illustrate 
    # how to set-up roundlotting:
    #
    Tutorial_1d = function(){
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; 
        # Set up alpha            
        self$Initialize('1d', 'Roundlotting', TRUE)

        # Set round lot info
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i]!='CASH'){
                asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
                if(!is.null(asset)){
                    # Round lot requires the price of each asset
                    CAsset_SetPrice(asset,self$m_Data$m_Price[i])
                    # Set lot size to 20
                    CAsset_SetRoundLotSize(asset,20)
				}
			}
		}
        # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 1d', self$m_InitPf, NULL, 10000000, 0.0)
        self$m_Case$SetPrimaryRiskModel(CWorkSpace_GetRiskModel(self$m_WS,'GEM'))

        # Enable Roundlotting; do not allow odd lot clostout 
        CConstraints_EnableRoundLotting(self$m_Case$InitConstraints(),FALSE)

        self$m_Case$InitUtility()

        # Run optimization
        self$RunOptimize()
	},

    ## Tutorial_1e: Post Optimization Roundlotting
    # 
    # The sample code shows how to retrieve the roundlotted portfolio
    # post optimization. The resulting portfolio may not satisfy some of 
    # your optimization settings, such as asset bounds, maximum turnover 
    # and transaction costs, paring constraints, and factor-level 
    # constraints, etc. Post-optimization roundlotting may fail if 
    # roundlotting a trade would result in a change of sign of the asset 
    # position.
    #
    # The trade list is shown in this sample to illustrate the roundlotted
    # positions.
    #
    #
    Tutorial_1e = function(){
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; 
        # Set up alpha            
        self$Initialize( '1e', 'Post optimization roundlotting', TRUE )
        # Add cash
        CPortfolio_AddAsset(self$m_InitPf,'CASH', 1.0)

        # Set round lot info
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH'){
                asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
                if (!is.null(asset)){ 
                    # Round lot requires the price of each asset
                    CAsset_SetPrice(asset,self$m_Data$m_Price[i])
                    # Set lot size to 1000
                    CAsset_SetRoundLotSize(asset,1000)
				}
			}
		}
        # Create a case object with trade universe
        portfolioBaseValue = 10000000
        self$m_Case = self$m_WS$CreateCase('Case 1e', self$m_InitPf, self$m_TradeUniverse, portfolioBaseValue)
        self$m_Case$SetPrimaryRiskModel(CWorkSpace_GetRiskModel(self$m_WS,'GEM'))

        util = self$m_Case$InitUtility()

        # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075;
        # no benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        # Run optimization
        self$RunOptimize()

        # Retrieve trade list info from the optimal portfolio; 
        super$OutputTradeList(TRUE)

        # Retrieve trade list info from the roundlotted portfolio
        super$OutputTradeList(FALSE)
	},
    ## Tutorial_1f: Additional Statistics for Initial/Optimal Portfolio
    # 
    # The sample code shows how to retrieve the statistics for the 
    # initial and optimal portfolio. The available statistics are
    # return, common factor/specific risk, short rebate, and 
    # information ratio. The statistics can be retrieved for any
    # given portfolio as well.
    #
    #
    Tutorial_1f = function(){
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; no alpha
        self$Initialize( '1f', 'Additional Statistics for Initial/Optimal Portfolio' )

        # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 1f', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set Alpha
        self$SetAlpha()

        util = self$m_Case$InitUtility()
        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        # Run optimization
        self$RunOptimize()

        # Output initial portfolio
        cat('Initial portfolio statistics:\n')
        cat(sprintf('Return = %.4f\n', self$m_Solver$Evaluate('eRETURN')))
		factorRisk = self$m_Solver$Evaluate('eFACTOR_RISK')
		specificRisk = self$m_Solver$Evaluate('eSPECIFIC_RISK')
        cat(sprintf('Common factor risk = %.4f\n', factorRisk))
        cat(sprintf('Specific risk = %.4f\n', specificRisk))
        cat(sprintf('Active risk = %.4f\n', sqrt(factorRisk*factorRisk + specificRisk*specificRisk)))
        cat(sprintf('Short rebate = %.4f\n', self$m_Solver$Evaluate('eSHORT_REBATE')))
        cat(sprintf('Information ratio = %.4f\n', self$m_Solver$Evaluate('eINFO_RATIO')))
        cat('\n') 

        # Output optimal portfolio
        portfolio = self$m_Solver$GetPortfolioOutput()$GetPortfolio()
        cat('Optimal portfolio statistics:\n')
        cat(sprintf('Return = %.4f\n', self$m_Solver$Evaluate('eRETURN', portfolio)))
		factorRisk = self$m_Solver$Evaluate('eFACTOR_RISK', portfolio)
		specificRisk = self$m_Solver$Evaluate('eSPECIFIC_RISK', portfolio)
        cat(sprintf('Common factor risk = %.4f\n', factorRisk))
        cat(sprintf('Specific risk = %.4f\n', specificRisk))
        cat(sprintf('Active risk = %.4f\n', sqrt(factorRisk*factorRisk + specificRisk*specificRisk)))
        cat(sprintf('Short rebate = %.4f\n', self$m_Solver$Evaluate('eSHORT_REBATE', portfolio)))
        cat(sprintf('Information ratio = %.4f\n', self$m_Solver$Evaluate('eINFO_RATIO', portfolio)))
        cat('\n')
	},
    ## Tutorial_1g: Optimization Problem/Output Portfolio Type
    # 
    # The sample code shows how to tell if the optimization
    # problem is convex, and if the output portfolio is heuristic
    # or optimal.
    #
    #
    Tutorial_1g = function(){
        
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; no alpha
        self$Initialize( '1g', 'Optimization Problem/Output Portfolio Type' )

        # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 1g', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        util = self$m_Case$InitUtility()

        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        # Set constraints
        constraints = self$m_Case$InitConstraints()
        # Set max # of assets to be 6
        paring = constraints$InitParingConstraints() 
        paring$AddAssetTradeParing('eNUM_ASSETS')$SetMax(6)

        # Retrieve info
        if (self$m_Case$IsConvex()){
            convex = 'Yes'
        }else{ 
            convex = 'No'
		}
		cat(sprintf('Is type of optimization problem convex: %s\n', convex))

        # Retrieve paring constraints
        cat(sprintf('max number of assets is: %d\n\n',
        paring$GetAssetTradeParingRange('eNUM_ASSETS')$GetMax()))

        # Run optimization
        self$RunOptimize()

        # Retrieve optimization output
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){ 
            if (output$IsHeuristic()){
                opt = 'heuristic'
            }else{
                opt = 'optimal'
			}
		}
        cat(sprintf('The output portfolio is %s\n', opt))
        softBoundSlackIDs = output$GetSoftBoundSlackIDs()
        if (softBoundSlackIDs$GetCount() > 0)
            cat('Soft bound violation found\n')
	},
	## Tutorial_2a: Composites and Linked Assets
    #
    # Composite assets are themselves portfolios.  Examples of composite assets 
    # include ETFs, Mutual Funds, or manager portfolios (funds of funds).  The 
    # risk exposure of the composite can be aggregated from its constituents. 
    # Unlike regular assets, the composite may have non-zero specific covariance
    # with other assets in the initial portfolio. This is due to the fact that 
    # the composite may also contain these assets.
    #
    # Linked assets share some underlying fundamentals and have non-zero specific 
    # covariance between them. In order to compute portfolio risk when composites/linked 
    # assets are part of the investment universe or included in the benchmark, we need to
    # link the composite portfolio with the composite asset, which will allow optimizer
    # to compute specific covariance between the composite assets/linked assets and the
    # other assets. 
    #
    # The Tutorial_2a sample code illustrates how to set up a composite asset and add it
    # to the trade universe: 
    #
    Tutorial_2a = function(){
            
        # Set up workspace, risk model data, inital portfolio, etc.
        # Create WorkSpace and set up Risk Model data, 
        # Create initial portfolio, etc; no alpha
        self$Initialize('2a', 'Composite Asset')

        # Create a portfolio to represent the composite
        # add its constituents to the portfolio
        # in this example, all assets and equal weighted 
        pComposite = CWorkSpace_CreatePortfolio(self$m_WS,'Composite')
        for (i in 1:self$m_Data$m_AssetNum)
            CPortfolio_AddAsset(pComposite,self$m_Data$m_ID[i], 1.0/self$m_Data$m_AssetNum)  
    
        # Create a composite asset COMP1
        pAsset = CWorkSpace_CreateAsset(self$m_WS, 'COMP1', 'eCOMPOSITE')
        # Link the composite portfolio to the asset
        CAsset_SetCompositePort(pAsset,pComposite)

        # add the composite to the trading universe
        self$m_TradeUniverse = CWorkSpace_GetPortfolio(self$m_WS,'Trade Universe')    
        CPortfolio_AddAsset(self$m_TradeUniverse,'COMP1')

        # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 2a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(CWorkSpace_GetRiskModel(self$m_WS,'GEM'))

        self$m_Case$InitUtility()
            
        # Run Optimization
        self$RunOptimize()
	},
    ## Tutorial_2b: Futures Contracts 
    #
    # Futures contracts, such as equity index futures, are settled daily and have
    # no market value.  However, they are risky assets that can be used to hedge 
    # portfolio risk (by selling the Futures contract) or increase risk.  Equity 
    # Futures can be used to gain equity market exposure with excess portfolio
    # cash, until the portfolio manager has decided which stocks to buy.
    #
    # Futures can be included in an optimization problem by indicating which assets 
    # in the list are futures and linking the composite portfolio to the futures asset.  
    # Since Futures do not have market value, they have no weight in the portfolio (where 
    # portfolio weight is defined as position market value/total portfolio market
    # value).  However, Futures do have an effective weight based on the contract
    # specifications (e.g.,  [$250 x S&P500 Index x Number of Contracts]/Portfolio 
    # Market Value). 
    #
    # Futures do not have currency risk, since they are settled daily and the 
    # replicating portfolio of cash and stock index in any currency has zero market
    # value. Since Futures do not have market value, they behave differently from 
    # regular assets in the optimizer.  Equity Futures contracts have the same 
    # factor exposures as the underlying spot index. 
    #
    # Tutorial_2b treats the newly created composite as a futures contract, which 
    # hedges portfolio risk.  
    #
    Tutorial_2b = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('2b', 'Futures Contracts')

    # Create a portfolio to represent the composite
    # add its constituents to the portfolio
    # in this example, all assets and equal weighted 
        pComposite = self$m_WS$CreatePortfolio('Composite')
        for (i in 1:self$m_Data$m_AssetNum)
            CPortfolio_AddAsset(pComposite,self$m_Data$m_ID[i], 1.0/self$m_Data$m_AssetNum)

    # Create a composite asset COMP1 as FUTURES
        pAsset = CWorkSpace_CreateAsset(self$m_WS,'COMP1', 'eCOMPOSITE_FUTURES')
    # Link the composite portfolio the asset
        CAsset_SetCompositePort(pAsset,pComposite)

    # add the composite to the trading universe
        self$m_TradeUniverse = CWorkSpace_GetPortfolio(self$m_WS,'Trade Universe')    
        CPortfolio_AddAsset(self$m_TradeUniverse,'COMP1')

        # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 2b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        self$m_Case$InitUtility()
        
    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_2c: Cash Contributions, Cash Withdrawal, Invest All Cash
    #
    # Investment managers tend to have cash balances that increase prior to the next
    # portfolio rebalancing. These cash balances come from corporate actions (such as
    # dividends or spin-offs) as well as investor contributions.  Managers often want
    # to maintain a certain cash balance (in terms of portfolio weight) for market
    # timing or other reasons (e.g., anticipated redemptions that avoid liquidating
    # stocks, which in turn helps avoid transaction costs and potential taxes). 
    #
    # There are a couple of ways to model cash in the optimization problem:
    # - Add a cash or currency asset into the initial portfolio.
    # - Specify a cash contribution when initializing the CCase object.
    #
    # There should be only one cash asset in the initial portfolio. The currency asset
    # may be specified more than once and is used to model different currency holdings.
    # It is treated differently than a regular asset in determining the non-linear
    # transaction cost.
    #
    # To control the final cash position, a manager can manage the cash withdrawal 
    # level in the optimal portfolio by setting an asset range constraint in the cash
    # asset. Please refer to Tutorial_3a on how to set the asset range. To invest all
    # cash, it is simply set the lower bound and upper bound of the cash asset to 0.
    #
    # In Tutorial_2c example, we demonstrate how to add a 20# cash contribution to 
    # the initial portfolio:
    #
    Tutorial_2c = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('2c', 'Cash contribution')

    # Create a case object. Set initial portfolio
    # 20% cash contribution
        self$m_Case = self$m_WS$CreateCase('Case 2c', self$m_InitPf, NULL, 100000, 0.2)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        self$m_Case$InitUtility()
        
    # Run optimization
        self$RunOptimize()
    },
    ## Tutorial_3a: Asset Range Constraints/Penalty
    #
    # Asset range constraint is to limit the weight of some asset in the optimal portfolio.
    # You can set the upper and lower bound of the range. The default is from -OPT_INF to +OPT_INF.
    #
    # By setting the range of the assets, you can implement various transaction strategies. 
    # For instance, you can disallow selling an asset by setting the lower bound of the 
    # constraint to the initial weight.
    #
    # In Tutorial_3a, we want to limit the maximum weight of any asset in the optimal 
    # portfolio to be 30%. An asset-level penalty is set for USA11I1.
    #
    Tutorial_3a = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('3a', 'Asset Range Constraints')

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set linear constraints
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        for (j in 1:self$m_Data$m_AssetNum){
            info = linear$SetAssetRange(self$m_Data$m_ID[j])
            info$SetLowerBound(0.0)
            info$SetUpperBound(0.3)
        # set asset penalty
            if (self$m_Data$m_ID[j]=='USA11I1')  
                # Set target to be 0.1; min = 0.0 and max = 0.3
                info$SetPenalty(0.1, 0.0, 0.3)
        }
        self$m_Case$InitUtility()

    # constraint retrieval
        self$PrintLowerAndUpperBounds(linear)
        
    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_3a2: Relative Asset Range Constraints/Penalty
    #
    # Relative asset range constraint is to limit the weight of some asset in the optimal portfolio
    # relative to a reference portfolio. For example, you can set relative weight of +5# and -5#
    # relative to the benchmark weight.
    #
    # For asset penalty, the target, lower, and upper values are in absolute weights. For benchmark relative
    # penalty, you will need to shift the values by the benchmark weight.
    #
    # In Tutorial_3a2, we want to limit the weight of any asset except USA11I1 in the optimal 
    # portfolio to be +5% and -5% relative to the benchmark portfolio. 
    #
    # An asset-level penalty of +3% and -3% relative to benchmark weight is set for USA11I1 as absolute weights.
    #
    Tutorial_3a2 = function(){
        
        self$Initialize( '3a2', 'Relative Asset Range Constraints' )
     
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3a2', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        for (j in 1:self$m_Data$m_AssetNum){
            info = linear$SetAssetRange(self$m_Data$m_ID[j])
            if (self$m_Data$m_ID[j]=='USA11I1')
        # Set asset penalty, since benchmark weight is 0.169809
        # min = 0.169809 - 0.03 = 0.139809
        # max = 0.169809 + 0.03 = 0.199809
                info$SetPenalty(0.169809, 0.139809, 0.199809)
            else{ 
        # Set relative asset range constraint
                info$SetLowerBound(-0.05, 'ePLUS')
                info$SetUpperBound(0.05, 'ePLUS')
                info$SetReference(self$m_BMPortfolio)
			}
		}
        util = self$m_Case$InitUtility()

        self$RunOptimize()
    },
    ## Tutorial_3b: Factor Range Constraints
    #
    # In this example, the initial portfolio exposure to Factor_1A is 0.0781, and 
    # we want to reduce the exposure to Factor_1A to 0.01.
    #
    Tutorial_3b = function(){
        cat('======== Running Tutorial 3b ========\n')
        cat('Factor Range Constraints\n')
		self$SetupDumpFile('3b')
		
    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # Create initial portfolio etc
        self$SetupPortfolios()

        pRiskModel = self$m_WS$GetRiskModel('GEM')
    # show existing exposure to FACTOR_1A
        exposure = pRiskModel$ComputePortExposure(self$m_InitPf, 'Factor_1A')
        cat(sprintf('Initial portfolio exposure to Factor_1A = %.4f\n', exposure))

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(pRiskModel)

    # Set a linear constraint - factor range
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        info = linear$SetFactorRange('Factor_1A')
        info$SetLowerBound(0.00)
        info$SetUpperBound(0.01)

        self$m_Case$InitUtility()
        
    # Run optimization
        self$RunOptimize()

    # Retrieve optimization output
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            slackInfo = output$GetSlackInfo('Factor_1A')
            if (!is.null(slackInfo))
                cat(sprintf('Optimal portfolio exposure to Factor_1A = %.4f\n', slackInfo$GetSlackValue()))
		}
        #Get the KKT term of the factor range constraint.
        impact = slackInfo$GetKKTTerm(TRUE)
        self$PrintAttributeSet(impact, 'factor constraint KKT term')
	},
    ## Tutorial_3c: Beta Constraint
    #
    # The optimal portfolio in Tutorial_1c without any constraints has a Beta of .7181
    # to the benchmark, so we specify a range 0.9 to 1.0 for the Beta in this example 
    # to constrain the result.
    # 
    # This self-documenting sample code illustrates how to use the Barra Optimizer to 
    # restrict market exposure with a beta constraint. 
    #
    Tutorial_3c = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('3c', 'Beta Constraint')

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3c', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set the beta constriant
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        info = linear$SetBetaConstraint()
        info$SetLowerBound(0.90)
        info$SetUpperBound(1.0)

        util = self$m_Case$InitUtility()
    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()

    # Get the slack information for beta constraint.
        output = self$m_Solver$GetPortfolioOutput()
        slackInfo = output$GetSlackInfo(info$GetID())

    # Get the KKT term of the balance constraint.
        impact = slackInfo$GetKKTTerm(TRUE)
        self$PrintAttributeSet(impact, 'Beta constraint KKT term')
    },
    ## Tutorial_3c2: Multiple Beta Constraints
    #
    # A beta constraint relative to the benchmark portfolio in utility can be set by
    # calling SetBetaConstraint() which we limit to 0.9 in this case. To set the additional 
    # beta constraints, first compute asset betas for the universe, then pass the betas as 
    # coefficients for the general linear constraint. You can call CRiskModel::ComputePortBeta() 
    # to verify the optimal portfolio's beta to the different benchmarks.
    # 
    # This self-documenting sample code illustrates how to use the Barra Optimizer to 
    # restrict market exposure with multiple beta constraints. 
    #
    Tutorial_3c2 = function(){
        self$Initialize( '3c2', 'Multiple Beta Constraints' )
         
    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3c2', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)

        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case$SetPrimaryRiskModel(riskModel)

    # Set the beta constraint relative to the benchmark in utility (m_pBMPortfolio)
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        info = linear$SetBetaConstraint()
        info$SetLowerBound(0.9)
        info$SetUpperBound(0.9)

    # Set the beta constraint relative to a second benchmark (self$m_pBM2Portfolio)
        assetBetaSet = riskModel$ComputePortAssetBeta(self$m_TradeUniverse, self$m_BM2Portfolio)
        info2 = linear$AddGeneralConstraint(assetBetaSet)
        info2$SetLowerBound(1.1)
        info2$SetUpperBound(1.1)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            beta = riskModel$ComputePortBeta(output$GetPortfolio(), self$m_BMPortfolio)
            cat(sprintf('Optimal portfolio\'s beta relative to benchmark in utility = %.4f\n', beta))
            beta2 = riskModel$ComputePortBeta(output$GetPortfolio(), self$m_BM2Portfolio)
            cat(sprintf('Optimal portfolio\'s beta relative to second benchmark = %.4f\n', beta2))
		}
 	},
   ## Tutorial_3d: User Attribute Constraints
    #
    # You can associate additional user attributes to each asset and constraint the 
    # optimal portfolio's exposure to these attributes. For instance, you can assign
    # Country, Currency, GICS Sector attribute for each asset and limit your bets on
    # their exposures. The group name and its attributes can be arbitrary and you
    # can use it to model a variety of custom attributes.
    #
    # This self-documenting sample code illustrates how to use the Barra Optimizer 
    # to restrict allocation of assets and total risk in a specific GICS sector,
    # in this case, Information Technology.  
    #
    Tutorial_3d = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('3d', 'User Attribute Constraints')

    # Set up group attribute
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset))
        # Set GICS Sector attribute
                CAsset_SetGroupAttribute(asset,'GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
		}
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3d', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()
    # Set a constraint to GICS_SECTOR - Information Technology
        linear = constraints$InitLinearConstraints() 
        info = linear$AddGroupConstraint('GICS_SECTOR', 'Information Technology')

    # limit the exposure to 20%
        info$SetLowerBound(0.0)
        info$SetUpperBound(0.2)
        
    # Set the total risk constraint by group for GICS_SECTOR - Information Technology
        riskConstraint = constraints$InitRiskConstraints()
        risk = riskConstraint$AddTotalConstraintByGroup('GICS_SECTOR', 'Information Technology', NULL)
        risk$SetUpperBound(0.1);

        self$m_Case$InitUtility()
    
    # constraint retrieval
        self$PrintLowerAndUpperBounds(linear) 

    # Run optimization
        self$RunOptimize()
    },
    ## Tutorial_3e: Setting Relative Constraints
    #
    # In relative constraints, you can specify a positive or negative constant to
    # be added or multiplied to the reference portfolio's exposure to a factor, 
    # such as risk index, or industry.  The reference portfolio may be your 
    # benchmark, market portfolio, initial portfolio or any arbitrary portfolio.
    # This constant determines the range for the exposure to that factor in the 
    # optimal portfolios.  
    #
    # In the Tutorial_3e example, we want to set the factor exposure to Factor_1A
    # to be within +/- 0.10 of the reference portfolio and a maximum of 50% of
    # exposures to GICS Sector Information Technology relative to the reference
    # portfolio. 
    #
    Tutorial_3e = function(){

    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('3e', 'Relative Constraints')

    # Set up group attribute
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset))
        # Set GICS Sector attribute
                CAsset_SetGroupAttribute(asset,'GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
		}
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3e', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set a constraint to GICS_SECTOR - Information Technology
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        info1 = linear$AddGroupConstraint('GICS_SECTOR', 'Information Technology')

    # limit the exposure to 50% of the reference portfolio
        info1$SetReference(self$m_BMPortfolio)
        info1$SetLowerBound(0.0, 'eMULTIPLE')
        info1$SetUpperBound(0.5, 'eMULTIPLE')

        info2 = linear$SetFactorRange('Factor_1A')

    # limit the Factor_1A exposure to +/- 0.01 of the reference portfolio
        info2$SetReference(self$m_BMPortfolio)
        info2$SetLowerBound(-0.01, 'ePLUS')
        info2$SetUpperBound(0.01, 'ePLUS')

        self$m_Case$InitUtility()

    # Constraint retrieval
        self$PrintLowerAndUpperBounds(linear)
        
    # Run optimization
        self$RunOptimize()
    },
	## Tutorial_3f: Setting Transaction Type
    #
    # There are a number of transaction types that you can specify in the
    # CLinearConstraints object: Allow All, Buy None, Sell None, Short None, Buy
    # from Universe, Sell None and Buy from Universe, Buy/Short from Universe, 
    # Disallow Buy/Short, Disallow Sell/Short Cover, Buy/Short from Universe and
    # No Sell/Short Cover. 
    #
    # They are basically different transaction strategies in the optimization 
    # problem, and these strategies can be replicated using Asset Range 
    # Constraints.  The transaction type is a more convenient way to set up these
    # strategies.  You can refer to the Reference Guide for the details of each
    # strategy. See Section of barraopt.
    #
    # The Tutorial_3f sample code shows how to buy from a universe without selling
    # any existing positions:
    #
    Tutorial_3f = function(){

    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('3f', 'Transaction Type')

    # Create a case object. Set initial portfolio and trade universe
    # Contribute 30% cash for buying additional securities
        self$m_Case = self$m_WS$CreateCase('Case 3f', self$m_InitPf, self$m_TradeUniverse, 100000, 0.3)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set Transaction Type to Sell None/Buy From Universe
        linear = self$m_Case$InitConstraints()$InitLinearConstraints()
        linear$SetTransactionType('eSELL_NONE_BUY_FROM_UNIV')

        self$m_Case$InitUtility()
    # Run optimization
        self$RunOptimize()
	},
	## Tutorial_3g: Crossover Option
    #
    # A crossover trade makes an asset change from long position to short position, 
    # or vice versa. The following sample shows how to disable the crossover option.
    # If crossover option is disabled, an asset is not allowed to change position 
    # from long to short or from short to long. Crossover is enabled by default.
    #
    #
    Tutorial_3g = function(){
    
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize( '3g', 'Crossover Option' , TRUE)
    # Add cash
        CPortfolio_AddAsset(self$m_InitPf,'CASH', 1)

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3g', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set linear constraints
        constraints = self$m_Case$InitConstraints()
        linear = constraints$InitLinearConstraints()
    # Set transaction type
        linear$SetTransactionType('eBUY_SHORT_FROM_UNIV')
    # Disable crossover
        linear$EnableCrossovers(FALSE)
    # Set an asset range
        info = linear$SetAssetRange('USA11I1')
        info$SetLowerBound(-1.0)
        info$SetUpperBound(1.0)

        self$m_Case$InitUtility()
    # Run optimization
        self$RunOptimize()
	},
	## Tutorial_3h: Total Active Weight Constraint
    #
    # You can set a constraint on the total absolute value of active weights on the optimal portfolio or for a group
    # of assets. To set total active weight by group, you will need to first set the asset
    # group attribute, then set the constraint by calling AddTotalActiveWeightConstraintByGroup().
    #
    # Tutorial_3h illustrates how to constrain the sum of active weights in the optimal portfolio to less than 1#.
    # The reference portfolio used to calculate active weights is the m_pBMPortfolio object.
    #
    Tutorial_3h = function(){
        self$Initialize( '3h', 'Total Active Weight Constraint' , TRUE)

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3h', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()
        info = constraints$SetTotalActiveWeightConstraint()
        info$SetLowerBound(0)
        info$SetUpperBound(0.01)
        info$SetReference(self$m_BMPortfolio)
            
        self$m_Case$InitUtility()

        self$RunOptimize()

        sumActiveWeight = 0.0 
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            optimalPort = output$GetPortfolio()
            idSet = optimalPort$GetAssetIDSet()
            assetID = idSet$GetFirst()
            for (i in 1:idSet$GetCount()){
                benchWeight = self$m_BMPortfolio$GetAssetWeight(assetID)
                if (benchWeight != OPT_NAN())
                    sumActiveWeight = sumActiveWeight + abs(benchWeight - optimalPort$GetAssetWeight(assetID))
                assetID = idSet$GetNext()
			}
		}
        cat(sprintf('Total active weight = %.4f\n', sumActiveWeight))
    },   
    ## Long-Short Optimization: Dollar Neutral Strategy
    #
    # Long-Short strategies are common among portfolio managers. One particular use case is the dollar-neutral 
    # strategy, in which the long and short sides are equally invested such that the net portfolio value is 0. 
    # The optimal portfolio is said to be dollar neutral.
    #
    # This tutorial demonstrates how dollar-neutral portfolio managers can set up their optimization problem
    # if the cash asset is not managed by them. Barra Open Optimizer provides the flexibility to disable the 
    # balance constraint and allow the cash asset to be optional.
    #
    # Since the portfolio balance constraint is enabled by default,  you need to  first disable the constraint by
    # calling EnablePortfolioBalanceConstraint(false). Then, add a general linear constraint to replace the 
    # Balance Constraint.
    # In this case, the general linear constraint would be the sum of all non-cash holdings = 0.
    #
    # Tutorial_3i illustrates how to set up the dollar-neutral strategy by replacing the balance constraint with 
    # a customized general linear constraint. 
    #
    Tutorial_3i = function(){
        self$Initialize( '3i', 'Dollar Neutral Strategy', TRUE)

        # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3i', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()
        linear = constraints$InitLinearConstraints()
        # Disable the default portfolio balance constraint
        linear$EnablePortfolioBalanceConstraint(FALSE)
        # Set equal weights
        coeffs = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i]!='CASH')
                coeffs$Set( self$m_Data$m_ID[i], 1.0 )
		}
        info = linear$AddGeneralConstraint(coeffs)
        # Set the upper & lower bounds of the general linear constraint
        info$SetLowerBound(0)
        info$SetUpperBound(0)

        util = self$m_Case$InitUtility()

        self$RunOptimize()

        sumWeight = 0.0
        pOutput = self$m_Solver$GetPortfolioOutput()
        if (!is.null(pOutput)){
            optimalPort = pOutput$GetPortfolio()
            idSet = optimalPort$GetAssetIDSet()
            assetID = idSet$GetFirst()
            for (i in 1:idSet$GetCount()){
                if (assetID!='CASH')
                    sumWeight = sumWeight + optimalPort$GetAssetWeight(assetID)
                assetID = idSet$GetNext()
			}
            cat(sprintf('Sum of all weights = %.4f\n', sumWeight ))
		}
	},
    ## Tutorial_3j: Asset free range linear penalty
    #
    # Asset penalty functions are used to tilt portfolios toward user-specified targets on asset weights. Free range linear penalty is one type of
    # penalty function that allows user to specify an upper and lower bound of the target, where the penalty will be zero if the slack variable
    # falls within the free range. User can also specify the penalty rate for each side should the slack variable falls outside of the free range.
    #
    # Tutorial_3j illustrates how to set free range linear penalty that penalizes the objective function when a non-cash asset weight is outside -10% to 10%.
    # 
    #
    Tutorial_3j = function(){
        self$Initialize( '3j', 'Asset Free Range Linear Penalty' )

        # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 3j', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        linear = self$m_Case$InitConstraints()$InitLinearConstraints()
        for (j in 1:self$m_Data$m_AssetNum){
            # Set asset free range penalty
            if (self$m_Data$m_ID[j]!='CASH'){
                info = linear$SetAssetRange(self$m_Data$m_ID[j])
                # Set free range to -0.1 to 0.1, with downside slope = -0.01, upside slope = 0.01
                info$SetFreeRangeLinearPenalty(-0.01, 0.01, -0.10, 0.10)
			}
		}
        util = self$m_Case$InitUtility()
        self$RunOptimize()
	},
	## Tutorial_4a: Maximum Number of Assets and estimated utility upper bound
    #
    # To set a maximum number of assets in the optimal portfolio, you can set the
    # limit with the CParingConstraints class. For long-short optimizations, the 
    # limit applies to both the long side and the short side. This constraint is 
    # not available for Risk Target or Expected Return Target portfolio optimizations.
    #
    # Tutorial_4a illustrates how to replicate a benchmark portfolio (minimize the 
    # tracking error) with less number of assets. In this case, we set the maximum 
    # number of assets to be 6.
    # This tutorial also illustrates how to estimate utility upperbound.
    #
    Tutorial_4a = function(){
        cat('======== Running Tutorial 4a ========\n')
        cat('Max # of assets and estimated utility upper bound\n')
        self$SetupDumpFile('4a')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # Create an initial holding portfolio 
    # initial portfolio with cash only
    # replicate the benchmark risk with max # of assets
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')
        CPortfolio_AddAsset(self$m_InitPf,'CASH', 1.0)

        self$m_TradeUniverse = self$m_WS$CreatePortfolio('Trade Universe')    
        self$m_BMPortfolio = self$m_WS$CreatePortfolio('Benchmark')    
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i]!='CASH'){
                CPortfolio_AddAsset(self$m_TradeUniverse, self$m_Data$m_ID[i])
                CPortfolio_AddAsset(self$m_BMPortfolio, self$m_Data$m_ID[i], 0.1)
            }
		}
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()

    # Invest all cash
        linear = constraints$InitLinearConstraints() 
        info = linear$SetAssetRange('CASH')
        info$SetLowerBound(0.0)
        info$SetUpperBound(0.0)

    # Set max # of assets to be 6
        paring = constraints$InitParingConstraints() 
        paring$AddAssetTradeParing('eNUM_ASSETS')$SetMax(6)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimizeReportUtilUB()
    },

    ## Tutorial_4b: Holding and Transaction Size Thresholds
    #
    # The minimum holding level is measured as a percentage, expressed in decimals,
    # of the base value (in this example, 0.04 is 4%).  This feature ensures 
    # that the optimizer will not recommend trades too small to be meaningful in 
    # your analysis.
    #
    # Minimum transaction size is measured as a percentage of the base value
    # (in this example, 0.02 is 2%). 
    #
    Tutorial_4b = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('4b', 'Min Holding Level and Transaction Size')

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set constraints
        constraints = self$m_Case$InitConstraints()
    # Set minimum holding threshold; both for long and short positions
    # in this example 4%
        paring = constraints$InitParingConstraints() 
        paring$AddLevelParing('eMIN_HOLDING_LONG', 0.04)
        paring$AddLevelParing('eMIN_HOLDING_SHORT', 0.04)
        paring$EnableGrandfatherRule()	        # Enable grandfather rule
        
    # Set minimum trade size; both for long side and short side,
    # in this example 2%
        paring$AddLevelParing('eMIN_TRANX_LONG', 0.02)
        paring$AddLevelParing('eMIN_TRANX_SHORT', 0.02)

        self$m_Case$InitUtility()
        
    # Run optimzation
        self$RunOptimize()
	},
    ## Tutorial_4c: Soft Turnover Constraint
    #
    # Maximum turnover is specified in percentage, expressed in decimals, (in this
    # example, 0.2 is 20.00%). This considers all transactions, including buys, 
    # sells, and short sells.  Covered buys are measured as a percentage of initial
    # portfolio value adjusted for any cash infusions or withdrawals you have 
    # specified.  If you select Use Base Value, turnover is measured as a 
    # percentage of the Base Value.  
    #
    Tutorial_4c = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('4c', 'Soft Turnover Constraint')

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4c', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set constraints
        constraints = self$m_Case$InitConstraints()
    # Set soft turnover constraint
        turnover = constraints$InitTurnoverConstraints() 
        info = turnover$SetNetConstraint()
        info$SetSoft(TRUE)
        info$SetUpperBound(0.2)

        self$m_Case$InitUtility()
    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_4d: Buy Side Turnover Constraint
    #
    # The following tutorial limits the maximum turnover for the buy side.
    #
    #
    Tutorial_4d = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('4d', 'Limit Buy Side Turnover Constraint')

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4d', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set constraints
        constraints = self$m_Case$InitConstraints()
    # Set buy side turnover constraint
        turnover = constraints$InitTurnoverConstraints()
        info = turnover$SetBuySideConstraint()
        info$SetUpperBound(0.1)

        self$m_Case$InitUtility()
    # Run optimization
        self$RunOptimize()
    },
    ## Tutorial_4e: Paring by Group
    #
    # To set paring constraint by group, you will need to first set the asset
    # group attribute, then set the limit with the CParingConstraints class. 
    #
    # Tutorial_4e illustrates how to set a maximum number of assets for GICS_SECTOR/
    # Information Technology to one asset. It also sets a holding threshold constraint for
    # the asset in GICS_SECTOR/Information Technology to be at least 0.2.
    #
    Tutorial_4e = function(){
        
        self$Initialize( '4e', 'Paring by group' )

        for( i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetGroupAttribute(asset,'GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
		}
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4e', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()

    # Set max # of asset in GICS Sector/Information Technology to 1
        paring = constraints$InitParingConstraints()
        paringRange = paring$AddAssetTradeParingByGroup('eNUM_ASSETS', 'GICS_SECTOR', 'Information Technology')
        paringRange$SetMax(1)

    # Set minimum holding threshold for GICS Sector/Information Technology to 0.2
        paring$AddLevelParingByGroup('eMIN_HOLDING_LONG', 'GICS_SECTOR', 'Information Technology', 0.2)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()
    },
    ## Tutorial_4f: Net turnover limit by group
    #
    # To set turnover constraint by group, you will need to first set the asset
    # group attribute, then set the limit with the CTurnoverConstraints class. 
    #
    # Tutorial_4f illustrates how to limit turnover to 10% for assets having the Information Technology attribute
    # in the GICS_SECTOR group, while limiting overall portfolio turnover to 30%.
    #
    Tutorial_4f = function(){
        self$Initialize( '4f', 'Net turnover by group' )

    # Set up group attribute
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset))
        # Set GICS Sector attribute
                CAsset_SetGroupAttribute(asset,'GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
        }
    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4f', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set the net turnover by group for GICS_SECTOR - Information Technology
        toCons = self$m_Case$InitConstraints()$InitTurnoverConstraints()
        infoGroup = toCons$AddNetConstraintByGroup('GICS_SECTOR', 'Information Technology')
        infoGroup$SetUpperBound(0.03)

    # Set the overall portfolio turnover
        info = toCons$SetNetConstraint()
        info$SetUpperBound(0.3)

        self$m_Case$InitUtility()

        self$RunOptimize()
	},
    ## Paring penalty
    # 
    # Paring penalty is used to tell the optimizer make a tradeoff between "violating a paring constraint" 
    # and "getting a better utility".  Violation of of the paring constraints would generate disutilty at the 
    # rate specified by the user.
    #
    # Tutorial_4g illustrates how to set paring penalty
    #
    Tutorial_4g = function(){
        self$Initialize( '4g', 'Paring penalty' )

        # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 4g', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()

        paring = constraints$InitParingConstraints() 
        paring$AddAssetTradeParing('eNUM_TRADES')$SetMax(2)		# Set maximum number of trades
        paring$AddAssetTradeParing('eNUM_ASSETS')$SetMin(5)		# Set minimum number of assets

        # Set paring penalty. Violation of the "max# trades=2" constraint would generate 0.005 disutility per extra trade.
        paring$SetPenaltyPerExtraTrade(0.005)

        util = self$m_Case$InitUtility()

        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        self$RunOptimize()
	},
    ## Tutorial_5a: Piecewise Linear Transaction Costs
    #
    # A simple way to model transactions costs is a flat-fee-per-share (the 
    # commission component) plus the percentage that accounts for trade 
    # volume (e.g., the bid spread for small, illiquid stocks).  These can be set
    # as default market values and then overridden at the asset level by 
    # associating transactions costs with individual securities.  This 
    # unfortunately does not capture the non-linear cost of market impact
    # (trade size related to trading volume).
    #
    # The piecewise linear transactions cost penalty are set in the CAsset class,
    # as shown in this simple example using 2 cents per share and 20 basis
    # points for the first 10,000 dollar buy cost. For more than 10,000 dollar or
    # short selling, the cost is 2 cents per share and 30 basis points.
    #
    # In this example, the 2 cent per share transaction commission is translated
    # into a relative weight via the share's price. The simple-linear market impact
    # cost of 20 basis points is already in relative-weight terms.  
    #
    # In the case of Asset 1 (USA11I1), its share price is 23.99 USD, so the $.02 
    # per share cost becomes .02/23.99= .000833681, and added to the 20 basis 
    # points cost .002 + .000833681= .002833681. 
    #
    # The short sell cost is higher at 30 basis points, so that becomes 
    # 0.003 + .00833681 = .003833681, in terms of relative weight. 
    #
    # The breakpoints and slopes can be used to specify a piecewise linear cost 
    # function that can account for increasing market impact based on trade size
    # (approximating a curve by piecewise linear segments).  In this simple 
    # example, the four (4) breakpoints have a center at the initial weight of 
    # the asset in the portfolio, with leftmost breakpoint at negative infinity
    # and the rightmost breakpoint at positive infinity. The breakpoints on the
    # X-axis represent relative portfolio weights, while the Y-axis slopes 
    # represent the relative cost of trading that asset. 
    #
    # If you have a high-value portfolio to manage, and a number of smallcap stocks
    # with very high alphas, the optimizer may suggest that you execute a trade 
    # larger than the average daily trading volume for that stock, and therefore
    # have a very large market impact.  Specifying piecewise linear transactions 
    # cost penalties can trim back these suggested trade sizes to more realistic 
    # levels.
    #
    Tutorial_5a = function(){
        cat('======== Running Tutorial 5a ========\n')
        cat('Piecewise Linear Transaction Costs\n')
        self$SetupDumpFile ('5a')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # Create an initial holding portfolio with the hard coded data
    # portfolio with no Cash
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')
        CPortfolio_AddAsset(self$m_InitPf, 'USA11I1', 0.3)
        CPortfolio_AddAsset(self$m_InitPf, 'USA13Y1', 0.7)

    # Set the transaction cost
        asset = CWorkSpace_GetAsset(self$m_WS, 'USA11I1')
        if (!is.null(asset)){
        # the price is 23.99
        # the 1st 10,000, 
		# the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
            asset$AddPWLinearBuyCost(0.002833681, 10000.0)

        # from 10,000 to +OPT_INF, 
		# the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
            asset$AddPWLinearBuyCost(0.003833681)

		# Sell cost is 30 basis + $0.02 per share =  0.003 + 0.02/23.99
            asset$AddPWLinearSellCost(0.003833681)
        }

        asset = CWorkSpace_GetAsset(self$m_WS,'USA13Y1')
        if (!is.null(asset)){
        # the price is 34.19
		# the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
            asset$AddPWLinearBuyCost(0.00287745)

		# Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
            asset$AddPWLinearSellCost(0.00387745)
        }

    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 5a', self$m_InitPf, NULL, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))
        
    # Set transcaction cost term
        util = self$m_Case$InitUtility()
        util$SetTranxCostTerm(1.0)

    # Run Optimization
        self$RunOptimize()
    },

    ## Tutorial_5b: Nonlinear Transaction Costs
    #
    # Tutorial_5b illustrates how to set up the coefficient c, p and q for 
    # nonlinear transaction costs
    #
    Tutorial_5b = function(){
    
        cat('======== Running Tutorial 5b ========\n')
        cat('Nonlinear Transaction Costs\n')
        self$SetupDumpFile ('5b')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # Create an initial holding portfolio with the hard coded data
    # portfolio with no Cash
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')
        CPortfolio_AddAsset(self$m_InitPf, 'USA11I1', 0.3)
        CPortfolio_AddAsset(self$m_InitPf, 'USA13Y1', 0.7)

    # Asset nonlinear transaction cost
    # c = 0.00005, p = 1.1, and q = 0.01
        CWorkSpace_GetAsset(self$m_WS,'USA11I1')$SetNonLinearTranxCost(0.00005, 1.1, 0.01)

    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 5b', self$m_InitPf, NULL, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set nonlinear transaction cost
    # c = 0.00001, p = 1.1, and q = 0.01
        self$m_Case$SetNonLinearTranxCost(0.00001, 1.1, 0.01)

    # Set transaction cost term
        util = self$m_Case$InitUtility()
        util$SetTranxCostTerm(1.0)
        
    # Run optimization
        self$RunOptimize()
    
	},
	## Tutorial_5c: Transaction Cost Constraints
    #
    # You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
    #
    Tutorial_5c = function(){
        cat('======== Running Tutorial 5c ========\n')
        cat('Transaction Cost Constraint\n')
        self$SetupDumpFile ('5c')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # Create an initial portfolio with no Cash
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')
        CPortfolio_AddAsset(self$m_InitPf, 'USA11I1', 0.3)
        CPortfolio_AddAsset(self$m_InitPf,'USA13Y1', 0.7)

    # Set the transaction cost
        asset = CWorkSpace_GetAsset(self$m_WS,'USA11I1')
        if (!is.null(asset)){
        # the price is 23.99
        # the 1st 10,000, 
		# the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
            asset$AddPWLinearBuyCost(0.002833681, 10000.0)

        # from 10,000 to +OPT_INF, 
		# the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
            asset$AddPWLinearBuyCost(0.003833681)

		# Sell cost is 30 basis + $0.02 per share =  0.003 + 0.02/23.99
            asset$AddPWLinearSellCost(0.003833681)
		}
        asset = CWorkSpace_GetAsset(self$m_WS, 'USA13Y1')
        if (!is.null(asset)){
        # the price is 34.19
		# the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
            asset$AddPWLinearBuyCost(0.00287745)

		# Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
            asset$AddPWLinearSellCost(0.00387745)
        }
    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 5c', self$m_InitPf, NULL, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set transaction cost constraint
        constraints = self$m_Case$InitConstraints()
        
        info = constraints$SetTransactionCostConstraint()
        info$SetUpperBound(0.0005)

    # Set transaction cost term
        util = self$m_Case$InitUtility()
        util$SetTranxCostTerm(1.0)

    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_5d: Fixed Transaction Costs
    #
    # Tutorial_5d illustrates how to set up fixed transaction costs
    #
    Tutorial_5d = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize( '5d', 'Fixed Transaction Costs', TRUE )

    # Set fixed transaction costs for non-cash assets
        for (i in 1:self$m_Data$m_AssetNum){ 
            if (self$m_Data$m_ID[i]!='CASH'){ 
                asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
				if (!is.null(asset)){
                    asset$SetFixedBuyCost( 0.02 )
                    asset$SetFixedSellCost( 0.03 )
				}
			}
		}
    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 5d', self$m_InitPf, NULL, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set utility
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(10.0)        # default value of the multiplier is 1.
        util$SetTranxCostTerm(1.0)
        
    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_5e: Load asset-level data, including fixed transaction costs from csv file
    #
    # Tutorial_5e illustrates how to set up asset-level data including fixed transaction costs
    # and group associationfrom csv file
    #
	Tutorial_5e = function(){
    
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set alpha
        self$Initialize( '5e', 'Asset-Level Data incl. Fixed Transaction Costs', TRUE )

    # Set fixed transaction costs for non-cash assets
        # load asset-level group name & attributes 
        status = self$m_WS$LoadAssetData(file.path(self$m_Data$m_Datapath,'asset_data.csv'))
        if (status$GetStatusCode() != 'eOK'){ 
            cat(sprintf('Error loading transaction cost data: %s\n', status$GetMessage()))
            cat(sprintf('%s\n', status$GetAdditionalInfo()))
		}        
    # Create a case object. Set initial portfolio & trade universe
        self$m_Case = self$m_WS$CreateCase('Case 5e', self$m_InitPf, self$m_TradeUniverse, 100000.0, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()

        # Set a linear constraint to GICS_SECTOR - Information Technology
        linear = constraints$InitLinearConstraints()
        info = linear$AddGroupConstraint('GICS_SECTOR', 'Information Technology')
        # limit the exposure to between 10%-50%
        info$SetLowerBound(0.1)
        info$SetUpperBound(0.5)

        # Set a hedge constraint to GICS_SECTOR - Information Technology
        hedgeConstr = constraints$InitHedgeConstraints()
        wtlGrpConsInfo = hedgeConstr$AddTotalLeverageGroupConstraint('GICS_SECTOR', 'Information Technology')
        wtlGrpConsInfo$SetLowerBound(1.0, 'ePLUS')
        wtlGrpConsInfo$SetUpperBound(1.3, 'ePLUS')
        wtlGrpConsInfo$SetSoft(TRUE)

        # Set max # of asset in GICS Sector/Information Technology to 1
        paring = constraints$InitParingConstraints()
        rge = paring$AddAssetTradeParingByGroup('eNUM_ASSETS', 'GICS_SECTOR', 'Information Technology')
        rge$SetMax(1)
        # Set minimum holding threshold for GICS Sector/Information Technology to 0.2
        paring$AddLevelParingByGroup('eMIN_HOLDING_LONG', 'GICS_SECTOR', 'Information Technology', 0.2)

        # Set the net turnover by group for GICS_SECTOR - Information Technology
        toCons = constraints$InitTurnoverConstraints()
        infoGroup = toCons$AddNetConstraintByGroup('GICS_SECTOR', 'Information Technology')
        infoGroup$SetUpperBound(0.03)
            
    # Set utility
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(10.0)        # default value of the multiplier is 1.
        util$SetTranxCostTerm(1.0)
        
    # Run optimization
        self$RunOptimize()
    },
	
    ## Tutorial_5f: Fixed Holding Costs
    #
    # Tutorial_5f illustrates how to set up fixed holding costs
    #
    Tutorial_5f = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize( '5f', 'Fixed Holding Costs', TRUE )

    # Set fixed transaction costs for non-cash assets
        for (i in 1:self$m_Data$m_AssetNum){ 
            if (self$m_Data$m_ID[i] != 'CASH'){ 
                asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
                if(!is.null(asset)){ 
                    asset$SetUpSideFixedHoldingCost(0.02)
                    asset$SetDownSideFixedHoldingCost(0.03)
                }
			}
		}
    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 5f', self$m_InitPf, NULL, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set utility - alpha term
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(10.0)        # default value of the multiplier is 1.
        util$SetFixedHoldingCostTerm(1.5) # default value of the multiplier is 1.

    # Run optimization
        self$RunOptimize()
	},


    ## General Piecewise Linear Constraint
    #
    # Tutorial_5g illustrates how to set up general piecewise linear Constraints
    #
    Tutorial_5g = function(){
        self$Initialize( '5g', 'General Piecewise Linear Constraint', TRUE )

	# Create a case object. Set initial portfolio
	self$m_Case = self$m_WS$CreateCase('Case 5g', self$m_InitPf, NULL, 100000, 0.0)
	self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

	util = self$m_Case$InitUtility()
	util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

	constraints = self$m_Case$InitConstraints()
	generalPWLICon = constraints$AddGeneralPWLinearConstraint()
    
	generalPWLICon$SetStartingPoint( self$m_Data$m_ID[1], self$m_Data$m_BMWeight[1] )
	generalPWLICon$AddDownSideSlope( self$m_Data$m_ID[1], -0.01, 0.05 )
	generalPWLICon$AddDownSideSlope( self$m_Data$m_ID[1], -0.03 )
	generalPWLICon$AddUpSideSlope( self$m_Data$m_ID[1], 0.02, 0.04 )
	generalPWLICon$AddUpSideSlope( self$m_Data$m_ID[1], 0.03 )

	conInfo = generalPWLICon$SetConstraint()
	conInfo$SetLowerBound(0.0)
	conInfo$SetUpperBound(0.25)

	self$RunOptimize()
    },

    ## Tutorial_6a: Penalty
    #
    # Penalties, like constraints, let you customize optimization by tilting 
    # toward certain portfolio characteristics.
    # 
    # This self-documenting sample code illustrates how to use the Barra Optimizer
    # to set up a penalty function that helps restrict market exposure.
    #
    Tutorial_6a = function(){

    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc; no alpha
        self$Initialize('6a', 'Penalty')

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 6a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set linear constraints
        linear = self$m_Case$InitConstraints()$InitLinearConstraints() 
        info = linear$SetBetaConstraint()
        info$SetLowerBound(-1 * OPT_INF())
        info$SetUpperBound(OPT_INF())

    # Set target to be 0.95
    # min = 0.80 and max = 1.2
        info$SetPenalty(0.95, 0.80, 1.2)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()
    },
    ## Tutorial_7a: Risk Budgeting
    #
    # In the following example, we will constrain the amount of risk coming
    # from common factor risk.  
    #
    #
    Tutorial_7a = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set alpha
        self$Initialize( '7a', 'Risk Budgeting', TRUE )

    # Create a case object, set initial portfolio and trade universe
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case = self$m_WS$CreateCase('Case 7a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(riskModel)

        self$m_Case$InitUtility()

    # Run optimization
        self$RunOptimize()

        pfOut = self$m_Solver$GetPortfolioOutput()
        if (!is.null(pfOut)){ 
            cat(sprintf( 'Specific Risk(%%) = %.4f\n', pfOut$GetSpecificRisk()))
            cat(sprintf( 'Factor Risk(%%) = %.4f\n', pfOut$GetFactorRisk()))
		
			riskConstraint = self$m_Case$InitConstraints()$InitRiskConstraints()

			cat( '\nAdd a risk constraint: FactorRisk<=12%\n' )
		# add a risk constraint
			info = riskConstraint$AddPLFactorConstraint()
			info$SetUpperBound(0.12)

			fid = self$m_WS$CreateIDSet()

		# add four factors
			fid$Add('Factor_1B')
			fid$Add('Factor_1C')
			fid$Add('Factor_1D')
			fid$Add('Factor_1E')
                
			cat( 'Add a risk constraint: Factor_1B-1E<=1.9%\n\n' )
			# constraint Factor_1B-1E <=1.9%
			info2 = riskConstraint$AddFactorConstraint(NULL, fid)
			info2$SetUpperBound(0.019)
            
		# rerun optimization usingthe existing solver without recreating a new solver
			self$RunOptimize(TRUE)     

			pfOut2 = self$m_Solver$GetPortfolioOutput()
			if (!is.null(pfOut2)){
				cat(sprintf( 'Specific Risk(%%) = %.4f\n', pfOut2$GetSpecificRisk()))
				cat(sprintf( 'Factor Risk(%%) = %.4f\n', pfOut2$GetFactorRisk()))
			}
		}
    },       
    ## Tutorial_7b: Dual Benchmarks
    #
    # Asset managers often administer separate accounts against one model 
    # portfolio.  For example, an asset manager with 300 separate institutional 
    # accounts for the same product, such as Large Cap Growth, will typically 
    # rebalance the model portfolio on a periodic basis (e.g., monthly).  The model
    # becomes the target portfolio that all 300 accounts should match perfectly, in
    # the absence of any unique constraints (e.g., no tobacco stocks).  The asset
    # manager will report performance to his or her institutional clients using the
    # appropriate external benchmark (e.g., Russell 1000 Growth, or S&P 500 Growth).
    # The model portfolio is effectively an internal benchmark. 
    #
    # The dual benchmark feature in the Barra Optimizer enables portfolio managers
    # to maximize utility using one benchmark, while constraining active risk 
    # against a different benchmark.  The optimal portfolio is the one that 
    # maximizes utility subject to the active risk constraint on the secondary
    # benchmark.
    #
    # Tutorial_7b is modified from Tutoral_1c, which minimizes the active risk 
    # relative to the benchmark portfolio. In this example, we set a risk 
    # constraint relative to the model portfolio with an active risk upper bound of
    # 300 basis points.
    #
    # This self-documenting sample code illustrates how to perform risk-constrained
    # optimization with dual benchmarks: 
    #
    Tutorial_7b = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc, no alpha   
        self$Initialize('7b', 'Risk Budgeting - Dual Benchmark')

    # Create a case object, set initial portfolio and trade universe
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case = self$m_WS$CreateCase('Case 7b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(riskModel)

    # add a risk constraint
        riskConstraint = self$m_Case$InitConstraints()$InitRiskConstraints()

        info = riskConstraint$AddPLTotalConstraint(TRUE, self$m_BM2Portfolio)
        info$SetID('RiskConstraint')
        info$SetUpperBound(0.16)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()

    # Retrieve slack info
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            slackInfo = output$GetSlackInfo('RiskConstraint')
            if ( !is.null(slackInfo)){
                cat(sprintf('Risk Constraint Slack = %.4f\n', slackInfo$GetSlackValue()))
                cat('\n')  
			}
		}
	},

    ## Tutorial_7c: Risk Budgeting - Additive Definition
    #
    # In the following example, we will constrain the amount of risk coming
    # from subsets of assets/factors using additive risk definition   
    #
    #
    Tutorial_7c = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set alpha
        self$Initialize( '7c', 'Additive Risk Definition', TRUE )

    # Create a case object, set initial portfolio and trade universe
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case = self$m_WS$CreateCase('Case 7c', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(riskModel)

        self$m_Case$InitUtility()

    # Run optimization
        self$RunOptimize()

        pfOut = self$m_Solver$GetPortfolioOutput()
        if (!is.null(pfOut)){ 
            cat(sprintf( 'Specific Risk(%%) = %.4f\n', pfOut$GetSpecificRisk()))
            cat(sprintf( 'Factor Risk(%%) = %.4f\n', pfOut$GetFactorRisk()))
	
          # subset of assets
            aid = self$m_WS$CreateIDSet()
            aid$Add('USA13Y1')
            aid$Add('USA1TY1')

            # subset of factors (7|8|9*)
            fid = self$m_WS$CreateIDSet()
            for (i in 49:self$m_Data$m_FactorNum){ 
                fid$Add(self$m_Data$m_Factor[i])               
            }

            cat(sprintf('Risk from USA13Y1 & 1TY1 = %.4f\n', 
				self$m_Solver$EvaluateRisk(pfOut$GetPortfolio(), 'eTOTALRISK', NULL, aid, NULL, TRUE, TRUE)))
            cat(sprintf('Risk from Factor_7|8|9* = %.4f\n', 
				self$m_Solver$EvaluateRisk(pfOut$GetPortfolio(), 'eFACTORRISK', NULL, NULL, fid, TRUE, TRUE)))
		
			riskConstraint = self$m_Case$InitConstraints()$InitRiskConstraints()

			cat('\nAdd a risk constraint(additive def): from USA13Y1 & 1TY1 <=1%' )
            info = riskConstraint$AddTotalConstraint( aid, NULL, TRUE, NULL, FALSE, FALSE, FALSE, TRUE)
            info$SetUpperBound(0.01)
				
            cat('\nAdd a risk constraint(additive def): from Factor_7|8|9* <=1.9%\n\n' )
            info2 = riskConstraint$AddFactorConstraint( NULL, fid, TRUE, NULL, FALSE, FALSE, FALSE, TRUE)
            info2$SetUpperBound(0.019)
            
			# rerun optimization usingthe existing solver without recreating a new solver
			self$RunOptimize(TRUE)     

			pfOut2 = self$m_Solver$GetPortfolioOutput()
			if (!is.null(pfOut2)){
				cat(sprintf( 'Specific Risk(%%) = %.4f\n', pfOut2$GetSpecificRisk()))
				cat(sprintf( 'Factor Risk(%%) = %.4f\n', pfOut2$GetFactorRisk()))

                cat(sprintf('Risk from USA13Y1 & 1TY1 = %.4f\n', 
					self$m_Solver$EvaluateRisk(pfOut2$GetPortfolio(), 'eTOTALRISK', NULL, aid, NULL, TRUE, TRUE)))
                cat(sprintf('Risk from Factor_7|8|9* = %.4f\n\n', 
					self$m_Solver$EvaluateRisk(pfOut2$GetPortfolio(), 'eFACTORRISK', NULL, NULL, fid, TRUE, TRUE)))

                ids = pfOut2$GetSlackInfoIDs()
                id=ids$GetFirst()
                for (i in 1:ids$GetCount()){
                    cat(sprintf('Risk Constraint Slack of %s = %.4f\n', id, pfOut2$GetSlackInfo(id)$GetSlackValue()))
                    id=ids$GetNext()
				}
				cat('\n')
			}
		}    
	},

    ## Tutorial_7d: Risk Budgeting - By Asset
    #
    # In the following example, we will constrain the amount of risk coming from
    # individual assets using additive risk definition.
    #
    Tutorial_7d = function(){
        self$Initialize( '7d', 'Risk Budgeting By Asset', TRUE )

        # Create a case object, set initial portfolio and trade universe
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case = self$m_WS$CreateCase('Case 7d', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(riskModel)

        # Add a risk constraint by asset (additive def): risk from USA11I1 and from 13Y1 to be between 3% and 5% 
        riskConstraint = self$m_Case$InitConstraints()$InitRiskConstraints()
        pid = self$m_WS$CreateIDSet()
        pid$Add("USA11I1");
        pid$Add("USA13Y1");
        info = riskConstraint$AddRiskConstraintByAsset(pid, TRUE, NULL, FALSE, FALSE, FALSE, TRUE);
        info$SetLowerBound(0.03);
        info$SetUpperBound(0.05);

        self$m_Case$InitUtility()

        self$m_Solver = self$m_WS$CreateSolver(self$m_Case);

        # Print asset risks in the initial portfolio
        cat('Initial Portfolio:\n');
        self$PrintRisksByAsset(self$m_InitPf);
        cat('\n');

        # Run optimization
        self$RunOptimize(TRUE)

        pfOut = self$m_Solver$GetPortfolioOutput()
        if (!is.null(pfOut)){ 
            # Print asset risks in the optimal portfolio
            self$PrintRisksByAsset(pfOut$GetPortfolio());
            cat('\n');
    	

            ids = pfOut$GetSlackInfoIDs()
            id=ids$GetFirst()
            for (i in 1:ids$GetCount()) {
                cat(sprintf('Risk Constraint Slack of %s = %.4f\n', id, pfOut$GetSlackInfo(id)$GetSlackValue()))
                id=ids$GetNext()
            }
            cat('\n')
	}    
    },

    ## Tutorial_8a: Long-Short Optimization
    #
    # Long/Short portfolios can be described as consisting of cash, a set of long
    # positions, and a set of short positions. Long-Short portfolios can provide 
    # more "alpha" since a manager is not restricted to positive-alpha stocks 
    # (assuming the manager's ability to identify overvalued and undervalued stocks).
    # Market-neutral portfolios are a special case of long/short strategy, because
    # they are constructed to remove systematic market risk (with a beta of zero to
    # the market portfolio, and no common-factor risk).  Since market-neutral
    # portfolios have no market risk, managers measure their performance against a 
    # cash benchmark.
    #
    # In Long-Short (Hedge) Optimization, you start with setting the default asset
    # minimum bound to -100% (thus allowing short sales).  You can then enter 
    # constraints to the long side and the short side of the portfolio.
    #
    # In example Tutorial_8a, we begin with a portfolio of $10mm cash and let the
    # optimizer determine optimal leverage based on expected returns we provide 
    # (i.e. maximize utility) to perform  a 130/30 strategy (long positions can be
    # up to 130% of the portfolio base value and short positions can be up to 30%). 
    #
    Tutorial_8a = function(){
   
        cat('======== Running Tutorial 8a ========\n')
        cat('Long-Short Hedge Optimization\n')
        self$SetupDumpFile ('8a')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()

    # initial portolio, trade universe, & Alpha
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')    
        self$m_TradeUniverse = self$m_WS$CreatePortfolio('Trade Universe')
        self$SetAlpha()

    # add assets
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] !='CASH'){
                CPortfolio_AddAsset(self$m_TradeUniverse, self$m_Data$m_ID[i])
            }else{
                CPortfolio_AddAsset(self$m_InitPf, self$m_Data$m_ID[i], 1.0)
			}
		}
    # Create a case object with 10M cash portfolio
        self$m_Case = self$m_WS$CreateCase('Case 8a', self$m_InitPf, self$m_TradeUniverse, 10000000.0, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set asset ranges
        constraints = self$m_Case$InitConstraints()
        linear = constraints$InitLinearConstraints() 
        for (j in 1:self$m_Data$m_AssetNum){            
            info = linear$SetAssetRange(self$m_Data$m_ID[j])
            if (self$m_Data$m_ID[j] != 'CASH'){
                info$SetLowerBound(-1.0)
                info$SetUpperBound(1.0)
            }else{
                info$SetLowerBound(-0.3)
                info$SetUpperBound(0.3)
			}
		}
    # Set hedge constraints
        hedgeConstr = constraints$InitHedgeConstraints()
    # set long-side leverage range
        longInfo = hedgeConstr$SetLongSideLeverageRange()
        longInfo$SetLowerBound(1.0)
        longInfo$SetUpperBound(1.3)
    # set short-side leverage range
        shortInfo = hedgeConstr$SetShortSideLeverageRange()
        shortInfo$SetLowerBound(-0.3)
        shortInfo$SetUpperBound(0.0)

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()
    },
    ## Tutorial_8b: Short Costs as Single Attribute
    #
    # Short cost/rebate rate of asset i is defined as below:
    # ShortCost_i = CostOfLeverage + HardToBorrowPenalty_i - InterestRateOnProceed_i
    # 
    # Starting Optimizer 1.3, user can specify short cost via a single API as shown
    # below.
    #
    #
    Tutorial_8b = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize( '8b', 'Short Costs as Single Attribute' , TRUE)
    # Add cash
		CPortfolio_AddAsset(self$m_InitPf, 'CASH', 1)

    # Create a case object. Set initial portfolio
        self$m_Case = self$m_WS$CreateCase('Case 8b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set asset ranges
        constraints = self$m_Case$InitConstraints()

        linear = constraints$InitLinearConstraints()
        for (j in 1:self$m_Data$m_AssetNum){
            info = CLinearConstraints_SetAssetRange(linear, self$m_Data$m_ID[j])
            if (self$m_Data$m_ID[j] !='CASH'){
                info$SetLowerBound(-1.0)
                info$SetUpperBound(1.0)
            }else{
                info$SetLowerBound(-0.3)
                info$SetUpperBound(0.3)
            }
		}

    # Set a short leverage range
        hedgeConstr = constraints$InitHedgeConstraints()
        shortInfo = hedgeConstr$SetShortSideLeverageRange()
        shortInfo$SetLowerBound(-0.3)
        shortInfo$SetUpperBound(0.0)

    # Set the net short cost
        asset = CWorkSpace_GetAsset(self$m_WS,'USA11I1')
        if (!is.null(asset)) 
        # ShortCost = CostOfLeverage + HardToBorrowPenalty - InterestRateOnProceed
        # where CostOfLeverage=50 basis, HardToBorrowPenalty=10 basis, InterestRateOnProceed=20 basis
            asset$SetNetShortCost(0.004)

    # Set utility function
        util = self$m_Case$InitUtility()
        
    # Run optimization
        self$RunOptimize()
	},
   ## Tutorial_8c: Weighted Total Leverage Constraint
    #
    # The following example shows how to setup weighted total leverage constraint,
    # total leverage group constraint, and total leverage factor constraint.
    #
    #
    Tutorial_8c = function(){

        cat('======== Running Tutorial 8c ========\n')
        cat('Weighted Total Leverage Constraint Optimization\n')
        self$SetupDumpFile('8c')

    # Create WorkSpace and setup Risk Model data
        self$SetupRiskModel()
    # Initial portforlio, trade universe & Alpha
        self$m_InitPf = self$m_WS$CreatePortfolio('Initial Portfolio')
        self$m_TradeUniverse = self$m_WS$CreatePortfolio('Trade Universe')
        self$SetAlpha()

    # 
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] == 'CASH')
                CPortfolio_AddAsset(self$m_InitPf, self$m_Data$m_ID[i], 1.0)
            else
                CPortfolio_AddAsset(self$m_TradeUniverse, self$m_Data$m_ID[i])        
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                asset$SetGroupAttribute('GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
        }

    # Create a case object with 10M cash portfolio
        self$m_Case = self$m_WS$CreateCase('Case 8c', self$m_InitPf, self$m_TradeUniverse, 10000000.0, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set asset ranges
        constraints = self$m_Case$InitConstraints()
        linear = constraints$InitLinearConstraints()
        for (j in 1:self$m_Data$m_AssetNum){
            info = linear$SetAssetRange(self$m_Data$m_ID[j])
            if (self$m_Data$m_ID[j] != 'CASH'){
                info$SetLowerBound(-1.0)
                info$SetUpperBound(1.0)
			}else{
                info$SetLowerBound(-0.3)
                info$SetUpperBound(0.3)
			}
		}
    # Add hedge constraints
    # long & short side coefficients
        longSideCoeffs = self$m_WS$CreateAttributeSet()
        shortSideCoeffs = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH'){ 
                longSideCoeffs$Set( self$m_Data$m_ID[i], 1.0 )
                shortSideCoeffs$Set( self$m_Data$m_ID[i], 1.0 )
			}
        }
        # add a total leverage factor constraint
        hedgeConstr = constraints$InitHedgeConstraints()
        wtlFacConsInfo = CHedgeConstraints_AddTotalLeverageFactorConstraint(hedgeConstr,'Factor_1A')
        wtlFacConsInfo$SetLowerBound(1.0, 'ePLUS')
        wtlFacConsInfo$SetUpperBound(1.3, 'ePLUS')
        wtlFacConsInfo$SetPenalty(0.95, 0.80, 1.2)
        wtlFacConsInfo$SetSoft(TRUE)
    # add a weighted total leverage constraint
        wtlConsInfo = hedgeConstr$AddWeightedTotalLeverageConstraint(longSideCoeffs, shortSideCoeffs)
        wtlConsInfo$SetLowerBound(1.0, 'ePLUS')
        wtlConsInfo$SetUpperBound(1.3, 'ePLUS')
        wtlConsInfo$SetPenalty(0.95, 0.80, 1.2)
        wtlConsInfo$SetSoft(TRUE)
    # add a total leverage group constraint
        wtlGrpConsInfo = hedgeConstr$AddTotalLeverageGroupConstraint('GICS_SECTOR', 'Information Technology')
        wtlGrpConsInfo$SetLowerBound(1.0, 'ePLUS')
        wtlGrpConsInfo$SetUpperBound(1.3, 'ePLUS')
        wtlGrpConsInfo$SetPenalty(0.95, 0.80, 1.2)
        wtlGrpConsInfo$SetSoft(TRUE)

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

    # Constraint retrieval
        self$PrintLowerAndUpperBounds(linear)
        self$PrintLowerAndUpperBounds(hedgeConstr)
    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_8d: Long-side Turnover Constraint
    #
    # The following case illustrates the use of turnover by side constraint, which needs to
    # be used in conjunction with long-short optimization. The maximum turnover on the long side
    # is 20%, with total value on the long side equal to total value on the short side.
    # 
    #
    Tutorial_8d = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc, no alpha
        self$Initialize( '8d', 'Long-side Turnover Constraint' )
    # Add cash
        CPortfolio_AddAsset(self$m_InitPf, 'CASH')

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 8d', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set constraints
        constraints = self$m_Case$InitConstraints()

    # Set soft turnover constraint
        turnover = constraints$InitTurnoverConstraints() 
        info = turnover$SetLongSideConstraint()
        info$SetUpperBound(0.2)

    # Set hedge constraint
        hedge = constraints$InitHedgeConstraints()
        hedgeInfo = hedge$SetShortLongLeverageRatioRange()
        hedgeInfo$SetLowerBound(1.0)
        hedgeInfo$SetUpperBound(1.0)

    # Set utility function
        self$m_Case$InitUtility()

    # Run optimization
        self$RunOptimize()
	},

	## Tutorial_9a: Risk Target
    #
    # The following example uses the same two-asset portfolio and ten-asset 
    # benchmark/trade universe.  There are asset alphas specified for each stock.
    #
    # The optimized portfolio will represent the optimal tradeoff between a target
    # level of risk and the maximum level of return available.  In this example, we
    # selected a target risk of 14# (tracking error, in this case, since a 
    # benchmark is assigned).  
    #
    Tutorial_9a = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize('9a', 'Risk Target', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 9a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set risk target
        CCase_SetRiskTarget(self$m_Case, 0.14)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()
    },

    ## Tutorial_9b: Return Target
    #
    # Similar to Tutoral_9a, we define a return target of 1# in Tutorial_9b:
    #
    Tutorial_9b = function(){
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize('9b', 'Return Target', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 9b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))
 
    # Set return target
        CCase_SetReturnTarget(self$m_Case, 0.01)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize()
    },
	
	## Tutorial_10a: Tax-aware Optimization (using pre-v8.8 legacy APIs)
    #
    # Suppose an individual investor desires to rebalance a portfolio to be "more
    # like the benchmark," but also wants to avoid having any net tax liability 
    # doing so.  In Tutorial_10a, we are rebalancing without alphas, and assume 
    # the portfolio has no realized capital gains so far this year.  The trading
    # rule is FIFO.
    #
    Tutorial_10a = function(){

    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc, no alpha
        self$Initialize('10a', 'Tax-aware Optimization (using pre-v8.8 legacy APIs)')

    # Set prices
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetPrice(asset, self$m_Data$m_Price[i] )
		}
    # Add tax lots
        assetValue = vector('numeric', self$m_Data$m_AssetNum)
	pfValue = 0.0
        for (j in 1:self$m_Data$m_Taxlots){
            iAccount = self$m_Data$m_Account[j]
            if (iAccount == 1) {
                iAsset = self$m_Data$m_Indices[j]
                CPortfolio_AddTaxLot(self$m_InitPf, self$m_Data$m_ID[iAsset], 
                                     self$m_Data$m_Age[j], self$m_Data$m_CostBasis[j],
                                     self$m_Data$m_Shares[j], FALSE)
                lotValue = self$m_Data$m_Price[iAsset]*self$m_Data$m_Shares[j]
                assetValue[iAsset] = assetValue[iAsset] + lotValue
                pfValue = pfValue + lotValue
            }
        }

    # Reset asset initial weights that are calculated from tax lot information
    for (i in 1:self$m_Data$m_AssetNum){
        self$m_InitPf$AddAsset(self$m_Data$m_ID[i], assetValue[i]/pfValue)
    }        
    # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10a', self$m_InitPf, self$m_TradeUniverse, pfValue, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))
        
    # Set tax rates
        tax = self$m_Case$InitTax()
        tax$EnableTwoRate() # default is 365
        tax$SetTaxRate(0.243, 0.423) #long term and short term rates

    # not allow wash sale
        tax$SetWashSaleRule('eDISALLOWED', 30)

    # first in, first out
        tax$SetSellingOrderRule('eFIFO')

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimize
        self$RunOptimize()

    # output
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
			taxOut = output$GetTaxOutput()
			if (!is.null(taxOut)){
                cat('Tax Info:\n')
                cat(sprintf('Long Term Gain  = %.2f\n', taxOut$GetLongTermGain()))
                cat(sprintf('Long Term Loss  = %.2f\n', taxOut$GetLongTermLoss()))
                cat(sprintf('Long Term Tax   = %.2f\n', taxOut$GetLongTermTax()))
                cat(sprintf('Short Term Gain = %.2f\n', taxOut$GetShortTermGain()))
                cat(sprintf('Short Term Loss = %.2f\n', taxOut$GetShortTermLoss()))
                cat(sprintf('Short Term Tax  = %.2f\n', taxOut$GetShortTermTax()))
                cat(sprintf('Total Tax       = %.2f\n\n', taxOut$GetTotalTax()))
                
                portfolio = output$GetPortfolio()
                idSet = portfolio$GetAssetIDSet()
                cat('TaxlotID          Shares:\n')
                assetID = idSet$GetFirst()
                while (assetID!=''){ 
                    sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                    oLotIDs = sharesInTaxlot$GetKeySet()
                    lotID = oLotIDs$GetFirst()
                    while (lotID!=''){
                        shares = sharesInTaxlot$GetValue( lotID )
                        if (shares!=0.0)
                            cat(sprintf( '%s %8d\n', lotID, shares ))
                        lotID = oLotIDs$GetNext()
					}
                    assetID = idSet$GetNext()
				}
                cat('\n')
			}
		}
    },
	
    ## Tutorial_10b: Capital Gain Arbitrage (using pre-v8.8 legacy APIs)
    #
    # Portfolio managers focusing on tax impact during rebalancing want to harvest
    # losses and avoid gains to decrease tax cost rather than have gains net out
    # the losses. Other managers want to target gains to generate cash flow for
    # their clients. Still other managers want long -term gains and short-term 
    # losses. One can implement a tax loss harvesting strategy by setting the 
    # bounds appropriately.
    # 
    # Tutorial_10b illustrates how to constraint short term gain to 0 and long term
    # loss to 110.
    #
    Tutorial_10b = function(){
        
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc, no alpha
        self$Initialize('10b', 'Capital Gain Arbitrage (using pre-v8.8 legacy APIs)')

    # set prices
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetPrice( asset, self$m_Data$m_Price[i] )
		}
    # add tax lots
        for (j in 1:self$m_Data$m_Taxlots) {
            iAccount = self$m_Data$m_Account[j]
            if (iAccount == 1) {
                self$m_InitPf$AddTaxLot(self$m_Data$m_ID[self$m_Data$m_Indices[j]],
                                        self$m_Data$m_Age[j], self$m_Data$m_CostBasis[j],
                                        self$m_Data$m_Shares[j], FALSE)
            }
        }
        
    # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10b', self$m_InitPf, 
        self$m_TradeUniverse, 4279.4, 0.0)

    # primary risk model
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # tax rates
        tax = self$m_Case$InitTax()
        tax$EnableTwoRate() # default is 365
        tax$SetTaxRate(0.243, 0.423) #long term and short term rates

    # not allow wash sale
        tax$SetWashSaleRule('eDISALLOWED', 30)

    # first in, first out
        tax$SetSellingOrderRule('eFIFO')

    # set tax constraints
        constraints = self$m_Case$InitConstraints()
        taxConstr = constraints$InitTaxConstraints()
    # short gain arbitrage range
        shortConstr = taxConstr$SetShortGainArbitrageRange()
        shortConstr$SetLowerBound(0.0)
        shortConstr$SetUpperBound(0.0)
    # long loss arbitrage range   
        longConstr = taxConstr$SetLongLossArbitrageRange()
        longConstr$SetLowerBound(0.0)
        longConstr$SetUpperBound(110.0)

    # 
        self$m_Case$InitUtility()

    # Run optimization    
        self$RunOptimize()
	
    # Handle additional output information
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            taxOut = output$GetTaxOutput()
            if (!is.null(taxOut)){
                cat('Tax Info:\n')
                cat(sprintf('Long Term Gain  = %.2f\n', taxOut$GetLongTermGain()))
                cat(sprintf('Long Term Loss  = %.2f\n', taxOut$GetLongTermLoss()))
                cat(sprintf('Long Term Tax   = %.2f\n', taxOut$GetLongTermTax()))
                cat(sprintf('Short Term Gain = %.2f\n', taxOut$GetShortTermGain()))
                cat(sprintf('Short Term Loss = %.2f\n', taxOut$GetShortTermLoss()))
                cat(sprintf('Short Term Tax  = %.2f\n', taxOut$GetShortTermTax()))
                cat(sprintf('Total Tax       = %.2f\n\n', taxOut$GetTotalTax()))
			}
		}
	},


    ## Tutorial_10c: Tax-aware Optimization (Using new APIs introduced in v8.8)
    #
    # Suppose an individual investor desires to rebalance a portfolio to be “more
    # like the benchmark,” but also wants to minimize net tax liability. 
    # In Tutorial_10c, we are rebalancing without alphas, and assume 
    # the portfolio has no realized capital gains so far this year.  The trading
    # rule is FIFO. This tutorial illustrates how to set up a group-level tax 
    # arbitrage constraint.

	Tutorial_10c = function(){

        self$Initialize('10c', 'Tax-aware Optimization (Using new APIs introduced in v8.8)')

    # set prices
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset)) 
                CAsset_SetPrice( asset, self$m_Data$m_Price[i] )
		}

    # Set up group attribute
        for (i in 1:self$m_Data$m_AssetNum) {
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetGroupAttribute( asset, 'GICS_SECTOR', self$m_Data$m_GICS_Sector[i] )
		}

   # Add tax lots into the portfolio, compute asset values and portfolio value
		assetValue <- c(rep(0.0,self$m_Data$m_AssetNum))
        pfValue = 0
        for (j in 1:self$m_Data$m_Taxlots) {
            iAccount = self$m_Data$m_Account[j]
            if (iAccount == 1){
                iAsset = self$m_Data$m_Indices[j]
                self$m_InitPf$AddTaxLot(self$m_Data$m_ID[iAsset], self$m_Data$m_Age[j], self$m_Data$m_CostBasis[j], self$m_Data$m_Shares[j], FALSE)
                lotValue = self$m_Data$m_Price[iAsset]*self$m_Data$m_Shares[j]
                assetValue[iAsset] = assetValue[iAsset] + lotValue
                pfValue = pfValue + lotValue
            }
        }

   # Reset asset initial weights based on tax lot information
        for (i in 1:self$m_Data$m_AssetNum) 
			CPortfolio_AddAsset(self$m_InitPf,self$m_Data$m_ID[i], assetValue[i]/pfValue)

   # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10c', self$m_InitPf, self$m_TradeUniverse, pfValue, 0.0)

        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Initialize a CNewTax object
        oTax = self$m_Case$InitNewTax()

    # Add a tax rule that covers all assets
        taxRule = oTax$AddTaxRule( '*', '*' )
        taxRule$EnableTwoRate()
        taxRule$SetTaxRate(0.243, 0.423)
        taxRule$SetWashSaleRule('eDISALLOWED', 30)

    # Set selling order rule as first in/first out for all assets
        oTax$SetSellingOrderRule('*', '*', 'eFIFO')

    # Specify long-only
        oCons = self$m_Case$InitConstraints()
        linearCon = oCons$InitLinearConstraints() 
        for (i in 1:self$m_Data$m_AssetNum) {
            info = linearCon$SetAssetRange(self$m_Data$m_ID[i])
            info$SetLowerBound(0)
		}

    #Set a group level tax arbitrage constraint
        oTaxCons = oCons$InitNewTaxConstraints()
        lgRange = oTaxCons$SetTaxArbitrageRange( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_GAIN' )
        lgRange$SetUpperBound( 250 )

        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize();

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            taxOut = output$GetNewTaxOutput();
            if (!is.null(taxOut)){
               lgg = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_GAIN' );
               lgl = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_LOSS' );
               sgg = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eSHORT_TERM', 'eCAPITAL_GAIN' );
               sgl = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eSHORT_TERM', 'eCAPITAL_LOSS' );

               cat('Tax info for group GICS_SECTOR/Information Technology:\n')
               cat(sprintf('Long Term Gain  = %.4f\n', lgg))
               cat(sprintf('Long Term Loss  = %.4f\n', lgl))
               cat(sprintf('Short Term Gain = %.4f\n', sgg))
               cat(sprintf('Short Term Loss = %.4f\n', sgl))

               ltax = taxOut$GetLongTermTax( '*', '*' )
               stax = taxOut$GetShortTermTax('*', '*')
               lgg_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_GAIN' )
               lgl_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_LOSS' )
               
               cat('')
               cat('\nTax info for the tax rule group(all assets):\n')
               cat(sprintf('Long Term Gain = %.4f\n', lgg_all ))
               cat(sprintf('Long Term Loss = %.4f\n', lgl_all ))
               cat(sprintf('Long Term Tax  = %.4f\n', ltax ))
               cat(sprintf('Short Term Tax = %.4f\n', stax ))

               cat(sprintf('\nTotal Tax(for all tax rule groups) = %.4f\n', taxOut$GetTotalTax()))

               portfolio = output$GetPortfolio()
               idSet = portfolio$GetAssetIDSet()
               cat( '\nTaxlotID          Shares:\n' )
               assetID = idSet$GetFirst()
               while (assetID!=''){ 
                    sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                    oLotIDs = sharesInTaxlot$GetKeySet()
                    lotID = oLotIDs$GetFirst()
                    while(lotID!=''){
                        shares = sharesInTaxlot$GetValue( lotID )
                        if ( shares!=0.0 )
                            cat( sprintf('%s %.4f\n', lotID, shares) )
                        lotID = oLotIDs$GetNext()
					}
                    assetID = idSet$GetNext()
			   }

               cat('\n')
               newShares = taxOut$GetNewShares()
               self$PrintAttributeSet(newShares, 'New Shares:')
               cat('')
			}
		}
	},

    ## Tutorial_10d: Tax-aware Optimization (Using new APIs introduced in v8.8)
    #
    # This tutorial illustrates how to set up a tax-aware optimization case with cash outflow.

	Tutorial_10d = function(){

        self$Initialize('10d', 'Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow')

    # set prices
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset)) 
                CAsset_SetPrice( asset, self$m_Data$m_Price[i] )
		}

    # Set up group attribute
        for (i in 1:self$m_Data$m_AssetNum) {
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetGroupAttribute( asset, 'GICS_SECTOR', self$m_Data$m_GICS_Sector[i] )
		}

   # Add tax lots into the portfolio, compute asset values and portfolio value
		assetValue <- c(rep(0.0,self$m_Data$m_AssetNum))
        pfValue = 0
        for (j in 1:self$m_Data$m_Taxlots) {
            iAccount = self$m_Data$m_Account[j]
            if (iAccount == 1){
                iAsset = self$m_Data$m_Indices[j]
                self$m_InitPf$AddTaxLot(self$m_Data$m_ID[iAsset], self$m_Data$m_Age[j], self$m_Data$m_CostBasis[j], self$m_Data$m_Shares[j], FALSE)
                lotValue = self$m_Data$m_Price[iAsset]*self$m_Data$m_Shares[j]
                assetValue[iAsset] = assetValue[iAsset] + lotValue
                pfValue = pfValue + lotValue
            }
        }

   # Cash outflow 5% of the base value
		CFW = -0.05

   # Set base value so that the final optimal weight will sum up to 100%
		BV = pfValue / (1 - CFW)

   # Reset asset initial weights based on tax lot information
        for (i in 1:self$m_Data$m_AssetNum) 
			CPortfolio_AddAsset(self$m_InitPf,self$m_Data$m_ID[i], assetValue[i]/BV)

   # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10d', self$m_InitPf, self$m_TradeUniverse, BV, CFW)

        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Initialize a CNewTax object
        oTax = self$m_Case$InitNewTax()

    # Add a tax rule that covers all assets
        taxRule = oTax$AddTaxRule( '*', '*' )
        taxRule$EnableTwoRate()
        taxRule$SetTaxRate(0.243, 0.423)
        taxRule$SetWashSaleRule('eDISALLOWED', 30)

    # Set selling order rule as first in/first out for all assets
        oTax$SetSellingOrderRule('*', '*', 'eFIFO')

    # Specify long-only
        oCons = self$m_Case$InitConstraints()
        linearCon = oCons$InitLinearConstraints() 
        for (i in 1:self$m_Data$m_AssetNum) {
            info = linearCon$SetAssetRange(self$m_Data$m_ID[i])
            info$SetLowerBound(0)
		}

    #Set a group level tax arbitrage constraint
        oTaxCons = oCons$InitNewTaxConstraints()
        lgRange = oTaxCons$SetTaxArbitrageRange( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_GAIN' )
        lgRange$SetUpperBound( 250 )

        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Run optimization
        self$RunOptimize();

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            taxOut = output$GetNewTaxOutput();
            if (!is.null(taxOut)){
               lgg = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_GAIN' );
               lgl = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eLONG_TERM', 'eCAPITAL_LOSS' );
               sgg = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eSHORT_TERM', 'eCAPITAL_GAIN' );
               sgl = taxOut$GetCapitalGain( 'GICS_SECTOR', 'Information Technology', 'eSHORT_TERM', 'eCAPITAL_LOSS' );

               cat('Tax info for group GICS_SECTOR/Information Technology:\n')
               cat(sprintf('Long Term Gain  = %.4f\n', lgg))
               cat(sprintf('Long Term Loss  = %.4f\n', lgl))
               cat(sprintf('Short Term Gain = %.4f\n', sgg))
               cat(sprintf('Short Term Loss = %.4f\n', sgl))

               ltax = taxOut$GetLongTermTax( '*', '*' )
               stax = taxOut$GetShortTermTax('*', '*')
               lgg_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_GAIN' )
               lgl_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_LOSS' )
               
               cat('')
               cat('\nTax info for the tax rule group(all assets):\n')
               cat(sprintf('Long Term Gain = %.4f\n', lgg_all ))
               cat(sprintf('Long Term Loss = %.4f\n', lgl_all ))
               cat(sprintf('Long Term Tax  = %.4f\n', ltax ))
               cat(sprintf('Short Term Tax = %.4f\n', stax ))

               cat(sprintf('\nTotal Tax(for all tax rule groups) = %.4f\n', taxOut$GetTotalTax()))

               portfolio = output$GetPortfolio()
               idSet = portfolio$GetAssetIDSet()
               cat( '\nTaxlotID          Shares:\n' )
               assetID = idSet$GetFirst()
               while (assetID!=''){ 
                    sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                    oLotIDs = sharesInTaxlot$GetKeySet()
                    lotID = oLotIDs$GetFirst()
                    while(lotID!=''){
                        shares = sharesInTaxlot$GetValue( lotID )
                        if ( shares!=0.0 )
                            cat( sprintf('%s %.4f\n', lotID, shares) )
                        lotID = oLotIDs$GetNext()
					}
                    assetID = idSet$GetNext()
			   }

               cat('\n')
               newShares = taxOut$GetNewShares()
               self$PrintAttributeSet(newShares, 'New Shares:')
               cat('')
			}
		}
	},

    ## Tutorial_10e: Tax-aware Optimization with loss benefit
    #
    # This tutorial illustrates how to set up a tax-aware optimization case with
    # a loss benefit term in the utility.
    #
	Tutorial_10e = function(){

        self$Initialize('10e', 'Tax-aware Optimization with loss benefit', FALSE, TRUE)

    # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10e', self$m_InitPf, self$m_TradeUniverse, self$m_PfValue[1], 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Disable shorting
        linear = self$m_Case$InitConstraints()$InitLinearConstraints()
        linear$SetTransactionType('eSHORT_NONE');

    # Initialize a CNewTax object
        oTax = self$m_Case$InitNewTax()

    # Add a tax rule that covers all assets
        taxRule = oTax$AddTaxRule( '*', '*' )
        taxRule$EnableTwoRate()
        taxRule$SetTaxRate(0.243, 0.423)
        taxRule$SetWashSaleRule('eDISALLOWED', 30)  # not allow wash sale

    # Set selling order rule as first in/first out for all assets
        oTax$SetSellingOrderRule('*', '*', 'eFIFO') # first in, first out

        util = self$m_Case$InitUtility()
        util$SetLossBenefitTerm(1.0);

    # Run optimization
        self$RunOptimize();

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            taxOut = output$GetNewTaxOutput();
            if (!is.null(taxOut)){
               ltax = taxOut$GetLongTermTax( '*', '*' );
               stax = taxOut$GetShortTermTax( '*', '*' );
               lgg = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_GAIN' );
               lgl = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_LOSS' );
               sgg = taxOut$GetCapitalGain( '*', '*', 'eSHORT_TERM', 'eCAPITAL_GAIN' );
               sgl = taxOut$GetCapitalGain( '*', '*', 'eSHORT_TERM', 'eCAPITAL_LOSS' );
               lb = taxOut$GetTotalLossBenefit();
               tax = taxOut$GetTotalTax();

               cat('Tax info:\n')
               cat(sprintf('Long Term Gain  = %.4f\n', lgg))
               cat(sprintf('Long Term Loss  = %.4f\n', lgl))
               cat(sprintf('Short Term Gain = %.4f\n', sgg))
               cat(sprintf('Short Term Loss = %.4f\n', sgl))
               cat(sprintf('Long Term Tax   = %.4f\n', ltax))
               cat(sprintf('Short Term Tax  = %.4f\n', stax))
               cat(sprintf('Loss Benefit    = %.4f\n', lb))
               cat(sprintf('Total Tax       = %.4f\n', tax))

               portfolio = output$GetPortfolio()
               idSet = portfolio$GetAssetIDSet()
               cat( '\nTaxlotID          Shares:\n' )
               assetID = idSet$GetFirst()
               while (assetID!=''){
                    sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                    oLotIDs = sharesInTaxlot$GetKeySet()
                    lotID = oLotIDs$GetFirst()
                    while(lotID!=''){
                        shares = sharesInTaxlot$GetValue( lotID )
                        if ( shares!=0.0 )
                            cat( sprintf('%s %.4f\n', lotID, shares) )
                        lotID = oLotIDs$GetNext()
					}
                    assetID = idSet$GetNext()
			   }

               cat('\n')
               newShares = taxOut$GetNewShares()
               self$PrintAttributeSet(newShares, 'New Shares:')
               cat('\n')
			}
		}
	},

    ## Tutorial_10f: Tax-aware Optimization with total loss and gain constraints.
    #
    # This tutorial illustrates how to set up a tax-aware optimization case with
    # bounds on total gain and loss.
    #
    Tutorial_10f = function(){
        self$Initialize('10f', 'Tax-aware Optimization with total loss/gain constraints', FALSE, TRUE)

    # Set up GICS Sector attribute
        for (i in 1:self$m_Data$m_AssetNum) {
            asset = self$m_WS$GetAsset(self$m_Data$m_ID[i])
            if (!is.null(asset)) {
                asset$SetGroupAttribute('GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
            }
        }

    # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10f', self$m_InitPf, self$m_TradeUniverse, self$m_PfValue[1], 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Disable shorting and cash
        oCons = self$m_Case$InitConstraints()
        linear = oCons$InitLinearConstraints()
        linear$SetTransactionType('eSHORT_NONE')
        linear$SetAssetTradeSize('CASH', 0)

    # Initialize a CNewTax object and set tax parameters
        oTax = self$m_Case$InitNewTax()
        taxRule = oTax$AddTaxRule('*', '*')
        taxRule$EnableTwoRate()
        taxRule$SetTaxRate(0.243, 0.423)
        oTax$SetSellingOrderRule('*', '*', 'eFIFO')

    # Set a group level tax arbitrage constraint on total loss
        oTaxCons = oCons$InitNewTaxConstraints()
        info = oTaxCons$SetTotalTaxArbitrageRange('GICS_SECTOR', 'Financials', 'eCAPITAL_LOSS')
        info$SetUpperBound(100.)

    # Set a group level tax arbitrage constraint on total gain
        info2 = oTaxCons$SetTotalTaxArbitrageRange('GICS_SECTOR', 'Information Technology', 'eCAPITAL_GAIN')
        info2$SetLowerBound(250.)

        util = self$m_Case$InitUtility()

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)) {
            taxOut = output$GetNewTaxOutput()
            if (!is.null(taxOut)) {
                tgg = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Financials', 'eCAPITAL_GAIN')
                tgl = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Financials', 'eCAPITAL_LOSS')
                tgn = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Financials', 'eCAPITAL_NET')
                cat('Tax info (Financials):\n')
                cat(sprintf('Total Gain  = %.4f\n', tgg))
                cat(sprintf('Total Loss  = %.4f\n', tgl))
                cat(sprintf('Total Net   = %.4f\n\n', tgn))

                tgg = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', 'eCAPITAL_GAIN')
                tgl = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', 'eCAPITAL_LOSS')
                tgn = taxOut$GetTotalCapitalGain('GICS_SECTOR', 'Information Technology', 'eCAPITAL_NET')
                cat('Tax info (Information Technology):\n')
                cat(sprintf('Total Gain  = %.4f\n', tgg))
                cat(sprintf('Total Loss  = %.4f\n', tgl))
                cat(sprintf('Total Net   = %.4f\n\n', tgn))

                portfolio = output$GetPortfolio()
                idSet = portfolio$GetAssetIDSet()
                cat( '\nTaxlotID          Shares:\n' )
                assetID = idSet$GetFirst()
                while (assetID!=''){
                     sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                     oLotIDs = sharesInTaxlot$GetKeySet()
                     lotID = oLotIDs$GetFirst()
                     while(lotID!=''){
                         shares = sharesInTaxlot$GetValue( lotID )
                         if ( shares!=0.0 )
                             cat( sprintf('%s %.4f\n', lotID, shares) )
                         lotID = oLotIDs$GetNext() 
					 }
                     assetID = idSet$GetNext()
 			    }

                cat('\n')
                newShares = taxOut$GetNewShares()
                self$PrintAttributeSet(newShares, 'New Shares:')
                cat('\n')
            }
        }
    },

    ## Tutorial_10g: Tax-aware Optimization with wash sales in the input.
    #
    # This tutorial illustrates how to specify wash sales, set the wash sale rule,
    # and access wash sale details from the output.
    #
    Tutorial_10g = function(){
        self$Initialize('10g', 'Tax-aware Optimization with wash sales', FALSE, TRUE)

        # Add an extra lot whose age is within the wash sale period
        self$m_InitPf$AddTaxLot('USA11I1', 12, 21.44, 20.0)
        
        # Recalculate asset weight from tax lot data
        self$UpdatePortfolioWeights()

        # Add wash sale records
        self$m_InitPf$AddWashSaleRec('USA2ND1', 20, 12.54, 10.0, FALSE)
        self$m_InitPf$AddWashSaleRec('USA3351', 35, 2.42, 25.0, FALSE)
        self$m_InitPf$AddWashSaleRec('USA39K1', 12, 9.98, 25.0, FALSE)

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 10g', self$m_InitPf, self$m_TradeUniverse, self$m_PfValue[1], 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Disable shorting and cash
        oCons = self$m_Case$InitConstraints()
        linear = oCons$InitLinearConstraints()
        linear$SetTransactionType('eSHORT_NONE')
        linear$SetAssetTradeSize('CASH', 0)

        # Initialize a CNewTax object and set tax parameters
        oTax = self$m_Case$InitNewTax()
        taxRule = oTax$AddTaxRule('*', '*')
        taxRule$EnableTwoRate()
        taxRule$SetTaxRate(0.243, 0.423)
        taxRule$SetWashSaleRule('eTRADEOFF', 40)
        oTax$SetSellingOrderRule('*', '*', 'eFIFO')

        util = self$m_Case$InitUtility()

        self$RunOptimize()

        # Retrieving tax related information from the output
        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)) {
            taxOut = output$GetNewTaxOutput()
            if (!is.null(taxOut)) {
                portfolio = output$GetPortfolio()
                idSet = portfolio$GetAssetIDSet()

                # Shares in tax lots
                cat('TaxlotID          Shares:\n')
                assetID = idSet$GetFirst()
                while (assetID!=''){
                     sharesInTaxlot = taxOut$GetSharesInTaxLots(assetID)
                     oLotIDs = sharesInTaxlot$GetKeySet()
                     lotID = oLotIDs$GetFirst()
                     while(lotID!=''){
                         shares = sharesInTaxlot$GetValue( lotID )
                         if ( shares!=0.0 )
                             cat( sprintf('%s %.4f\n', lotID, shares) )
                         lotID = oLotIDs$GetNext() 
					 }
                     assetID = idSet$GetNext()
 			    }

                # New shares
                newShares = taxOut$GetNewShares()
                self$PrintAttributeSet(newShares, '\nNew Shares:')
                cat('\n')

                # Disqualified shares
                disqShares = taxOut$GetDisqualifiedShares()
                self$PrintAttributeSet(disqShares, 'Disqualified Shares:')
                cat('\n')

                # Wash sale details
                cat('Wash Sale Details:\n')
                cat(sprintf('%-20s%12s%10s%10s%12s%20s\n', 'TaxLotID', 'AdjustedAge', 'CostBasis', 'Shares', 'SoldShares', 'DisallowedLotID'))
                assetIDs = self$m_Case$GetAssetIDs()
                assetID = assetIDs$GetFirst()
                while (assetID != '') {
                    wsDetail = taxOut$GetWashSaleDetail(assetID)
                    if (!is.null(wsDetail)) {
                        for (i in 0:(wsDetail$GetCount()-1)) {
                            lotID = wsDetail$GetLotID(i)
                            disallowedLotID = wsDetail$GetDisallowedLotID(i)
                            age = wsDetail$GetAdjustedAge(i)
                            costBasis = wsDetail$GetAdjustedCostBasis(i)
                            shares = wsDetail$GetShares(i)
                            soldShares = wsDetail$GetSoldShares(i)
                            cat(sprintf('%-20s%12d%10.4f%10.4f%12.4f%20s\n',
                                    lotID, age, costBasis, shares, soldShares, disallowedLotID))
                        }
                    }
                    assetID = assetIDs$GetNext()
                }
                cat('\n')
            }
        }
    },

    ## Tutorial_11a: Efficient Frontier
    #
    # In the following Risk-Reward Efficient Frontier problem, we have chosen the
    # return constraint, specifying a lower bound of 0% turnover, upper bound of 
    # 10% return and ten points.  
    #
    Tutorial_11a = function(){
    
    # Set up workspace, risk model data, inital portfolio, etc.
    # Create WorkSpace and set up Risk Model data, 
    # Create initial portfolio, etc,
    # Set Alpha
        self$Initialize('11a', 'Efficient Frontier', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 11a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # set frontier
        frontier = self$m_Case$InitFrontier('eRISK_RETURN')

        frontier$SetMaxNumDataPoints(10)
        frontier$SetFrontierRange(0.0, 0.1)

    #
        self$m_Case$InitUtility()

        # 
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
        
    # opsdata info could be very helpful in debugging 
    #    if (len(self$m_DumpFilename)>0) 
    #        self$m_WS$Serialize(self$m_DumpFilename)
        
        cat( '\nNon-Interactive approach...\n' )

        oStatus = self$m_Solver$Optimize()

        if (oStatus$GetStatusCode() != 'eOK'){
            #show error message
            err = oStatus$GetMessage()
            cat(sprintf('Optimization error: %s\n',err))
        }
        cat(sprintf( '%s\n', oStatus$GetMessage()))
        cat(sprintf( '%s\n', self$m_Solver$GetLogMessage()))

        frontierOutput = self$m_Solver$GetFrontierOutput()
        for (i in 1:frontierOutput$GetNumDataPoints()){
            dataPoint = frontierOutput$GetFrontierDataPoint(i-1)
			cat(sprintf('Risk(%%) = %.3f \tReturn(%%) = %.3f\n', dataPoint$GetRisk(), dataPoint$GetReturn()))
		}
        cat('\n')
	},    

	## Tutorial_11b: Utility-Factor Constraint Frontier
    #
    # In the following Utility-Factor Constraint Frontier problem, we illustrate the effect of varying
    # factor bound on the optimal portfolio's utility, specifying a lower bound of 0% and 
    # upper bound of 7% exposure to Factor_1A, and 10 data points.
    #
    Tutorial_11b = function(){
    
        self$Initialize('11b', 'Factor Constraint Frontier', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 11b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Create a factor constraint for Factor_1A for the frontier
        linear = self$m_Case$InitConstraints()$InitLinearConstraints()
        factorCons = linear$SetFactorRange('Factor_1A')

    # Vary exposure to Factor_1A between 0% and 7% with 10 data points
        frontier = self$m_Case$InitFrontier('eUTILITY_FACTOR')
        frontier$SetMaxNumDataPoints(10)
        frontier$SetFrontierRange(0.0, 0.07)
        frontier$SetFrontierConstraintID(factorCons$GetID())

        self$m_Case$InitUtility()

        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
    # opsdata info could be very helpful in debugging 
    #    if len(self$m_DumpFilename)>0: 
    #        self$m_WS$Serialize(self$m_DumpFilename)    
        
        oStatus = self$m_Solver$Optimize()
        cat(sprintf('%s\n', oStatus$GetMessage()))
        cat(sprintf('%s\n', self$m_Solver$GetLogMessage()))

        frontierOutput = self$m_Solver$GetFrontierOutput()

        for (i in 1:frontierOutput$GetNumDataPoints()){
            dataPoint = frontierOutput$GetFrontierDataPoint(i-1)
            cat(sprintf('Utility = %.6f\tRisk(%%) = %.3f\tReturn(%%) = %.3f\n',
                  dataPoint$GetUtility(), dataPoint$GetRisk(), dataPoint$GetReturn()))
            cat(sprintf('Optimal portfolio exposure to Factor_1A = %.4f\n', dataPoint$GetConstraintSlack()))
        }
        cat('\n')
    },
    ## Tutorial_11c: Utility-General Linear Constraint Frontier
    #
    # In the following Utility-General Linear Constraint Frontier problem, we illustrate the effect of varying
    # sector exposure on the optimal portfolio's utility, specifying a lower bound of 10% and 
    # upper bound of 20% exposure to Information Technology sector, and 10 data points.
    #
    Tutorial_11c = function(){
    
        self$Initialize('11c', 'General Linear Constraint Frontier', TRUE)

        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset))
                # Set GICS Sector attribute
                CAsset_SetGroupAttribute(asset, 'GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
		}
    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 11c', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set a constraint to GICS_SECTOR - Information Technology
        linearCon = self$m_Case$InitConstraints()$InitLinearConstraints() 
        groupCons = linearCon$AddGroupConstraint('GICS_SECTOR', 'Information Technology')

        frontier = self$m_Case$InitFrontier('eUTILITY_GENERAL_LINEAR')
        frontier$SetMaxNumDataPoints(10)
        frontier$SetFrontierRange(0.1, 0.2)
        frontier$SetFrontierConstraintID(groupCons$GetID())

        self$m_Case$InitUtility()

        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
    # opsdata info could be very helpful in debugging 
    #    if len(self$m_DumpFilename)>0: 
    #        self$m_WS$Serialize(self$m_DumpFilename)
        
        
        oStatus = self$m_Solver$Optimize()
        cat(sprintf('%s\n', oStatus$GetMessage()))
        cat(sprintf('%s\n', self$m_Solver$GetLogMessage()))

        frontierOutput = self$m_Solver$GetFrontierOutput()

        for (i in 1:frontierOutput$GetNumDataPoints()){
            dataPoint = frontierOutput$GetFrontierDataPoint(i-1)
            cat(sprintf('Utility = %.6f\tRisk(%%) = %.3f\tReturn(%%) = %.3f\n',
                  dataPoint$GetUtility(),dataPoint$GetRisk(),dataPoint$GetReturn()))
            cat(sprintf('Optimal portfolio exposure to Information Technology = %.4f\n',
                  dataPoint$GetConstraintSlack())) 
		}				  
        cat('\n')
	},

    ## Tutorial_11d: Utility-Leaverage Frontier
    #
    # In the following Utility-Leverage Frontier problem, we illustrate the effect of varying
    # total leverage range, specifying a lower bound of 30% and upper bound of 70%, and 10 data points.  
    #
    Tutorial_11d = function(){
    
        self$Initialize('11d', 'Utility-Leaverage Frontier', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 11d', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set hedge settings
   	  CPortfolio_AddAsset(self$m_TradeUniverse,'CASH')		# Cash is required for L/S optimization 
        hedgeCons = self$m_Case$InitConstraints()$InitHedgeConstraints() 
        info = hedgeCons$SetTotalLeverageRange()

        frontier = self$m_Case$InitFrontier('eUTILITY_HEDGE')
        frontier$SetMaxNumDataPoints(10)
        frontier$SetFrontierRange(0.3, 0.7)
        frontier$SetFrontierConstraintID(info$GetID())

        self$m_Case$InitUtility()

        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
    # opsdata info could be very helpful in debugging 
    #    if len(self$m_DumpFilename)>0: 
    #        self$m_WS$Serialize(self$m_DumpFilename)
        
        
        oStatus = self$m_Solver$Optimize()
        cat(sprintf('%s\n', oStatus$GetMessage()))
        cat(sprintf('%s\n', self$m_Solver$GetLogMessage()))

        frontierOutput = self$m_Solver$GetFrontierOutput()
        if(!is.null(frontierOutput)){
            for (i in 1:frontierOutput$GetNumDataPoints()){
                dataPoint = frontierOutput$GetFrontierDataPoint(i-1)
                cat(sprintf('Utility = %.6f   Total leverage = %.3f\n',
                      dataPoint$GetUtility(), dataPoint$GetConstraintSlack())) 
			}
		}else{
			cat('Invalid frontier')
		}
        cat('\n')
	},

    ## Tutorial_12a: Constraint hierarchy
    #
    # This tutorial illustrates how to set up constraint hierarchy
    #
    Tutorial_12a = function(){
    
        self$Initialize( '12a', 'Constraint Hierarchy', TRUE )

    # Create a case object. Set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 12a', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        constraints = self$m_Case$InitConstraints()

    # Set minimum holding threshold; both for long and short positions
    # in this example 10%
        paring = constraints$InitParingConstraints() 
        paring$AddLevelParing('eMIN_HOLDING_LONG', 0.1)
        paring$AddLevelParing('eMIN_HOLDING_SHORT', 0.1)

    # Set minimum trade size; both for long and short positions
    # in this example 20%
        paring$AddLevelParing('eMIN_TRANX_LONG', 0.2)
        paring$AddLevelParing('eMIN_TRANX_SHORT', 0.2)

    # Set Min # assets to 5, excluding cash and futures
        paring$AddAssetTradeParing('eNUM_ASSETS')$SetMin(5)

    # Set Max # trades to 3 
        paring$AddAssetTradeParing('eNUM_TRADES')$SetMax(3)

    # Set hedge settings
        CPortfolio_AddAsset( self$m_TradeUniverse, 'CASH' )        # Cash is required for L/S optimization 
        hedgeConstr = constraints$InitHedgeConstraints()
        conInfo1 = hedgeConstr$SetLongSideLeverageRange()
        conInfo1$SetLowerBound(1.0)
        conInfo1$SetUpperBound(1.1)
        conInfo2 = hedgeConstr$SetShortSideLeverageRange()
        conInfo2$SetLowerBound(-0.3)
        conInfo2$SetUpperBound(-0.3)
        conInfo3 = hedgeConstr$SetTotalLeverageRange()
        conInfo3$SetLowerBound(1.5)
        conInfo3$SetUpperBound(1.5)

    # Set constraint hierarchy
        hier = constraints$InitConstraintHierarchy()
        hier$AddConstraintPriority('eASSET_PARING', 'eFIRST')
        hier$AddConstraintPriority('eHEDGE', 'eSECOND')

        self$m_Case$InitUtility()
    #
    # constraint retrieval
    #
        # upper & lower bounds
        self$PrintLowerAndUpperBounds(hedgeConstr)
    # paring constraint
        self$PrintParingConstraints(paring)
    # constraint hierachy
        self$PrintConstraintPriority(hier) 

        self$RunOptimize()
    },
    ## Tutorial_14a: Shortfall Beta Constraint
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # for setting up shortfall beta constraint.  The shortfall beta data are 
    # read from a file that is an output file of BxR example.
    #
    Tutorial_14a = function(){
    
        self$Initialize( '14a', 'Shortfall Beta Constraint', TRUE )

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 14a', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))
        CCase_SetRiskTarget(self$m_Case, 0.05)

    # Read shortfall beta from a file
        self$m_Data$ReadShortfallBeta()
    
        attributeSet = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH')
                attributeSet$Set( self$m_Data$m_ID[i], self$m_Data$m_Shortfall_Beta[i] )
		}
        linearCon = self$m_Case$InitConstraints()$InitLinearConstraints() 

    # Add coefficients with shortfall beta data read from file
        oShortfallBetaInfo = linearCon$AddGeneralConstraint(attributeSet)

    # Set lower/upper bounds for shortfall beta
        oShortfallBetaInfo$SetID('ShortfallBetaCon')
        oShortfallBetaInfo$SetLowerBound(0.9)
        oShortfallBetaInfo$SetUpperBound(0.9)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # constraint retrieval
        self$PrintLowerAndUpperBounds(linearCon)
        self$PrintAttributeSet(linearCon$GetCoefficients('ShortfallBetaCon'), 'The Coefficients are:')

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){
            slackInfo = output$GetSlackInfo('ShortfallBetaCon')
            if (!is.null(slackInfo))
                cat(sprintf('Shortfall Beta Con Slack = %.4f\n', slackInfo$GetSlackValue()))    
		}
	},

    ## Tutorial_15a: Minimizing Total Risk from both of primary and secondary risk models
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # for minimizing Total Risk from both of primary and secondary risk models
    # and set a constraint for a factor in the secondary risk model.
    #
    Tutorial_15a = function(){
        
    # Create WorkSpace and setup Risk Model data,
    # Create initial portfolio, etc; no alpha
        self$Initialize( '15a', 'Minimize Total Risk from 2 Models' )

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 15a', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Setup Secondary Risk Model 
        self$SetupRiskModel2()
        riskModel2 = self$m_WS$GetRiskModel('MODEL2')
        self$m_Case$SetSecondaryRiskModel(riskModel2)
          
        # Set secondary factor range
        linearConstraint = self$m_Case$InitConstraints()$InitLinearConstraints()
        info = linearConstraint$SetFactorRange('Factor2_2', FALSE)
        info$SetLowerBound(0.00)
        info$SetUpperBound(0.40)

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
    # for primary risk model; No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
    # for secondary risk model; No benchmark
        util$SetSecondaryRiskTerm(NULL, 0.0075, 0.0075)

        self$RunOptimize()
	},
	
    ## Tutorial_15b: Constrain risk from secondary risk model
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # for constraining risk from secondary risk model
    #
    Tutorial_15b = function(){
        self$Initialize( '15b', 'Risk Budgeting - Dual Risk Model' )

    # Create a case object, set initial portfolio and trade universe
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case = self$m_WS$CreateCase('Case 15b', self$m_InitPf, self$m_TradeUniverse, 100000, 0.0)
        self$m_Case$SetPrimaryRiskModel(riskModel)

    # Setup Secondary Risk Model 
        self$SetupRiskModel2()
        riskModel2 = self$m_WS$GetRiskModel('MODEL2')
        self$m_Case$SetSecondaryRiskModel(riskModel2)

        riskConstraint = self$m_Case$InitConstraints()$InitRiskConstraints()

    # Set total risk from the secondary risk model 
        info = riskConstraint$AddPLTotalConstraint(FALSE, self$m_BM2Portfolio)
        info$SetID( 'RiskConstraint' )
        info$SetUpperBound(0.1)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)){ 
            slackInfo = output$GetSlackInfo('RiskConstraint')
            if (!is.null(slackInfo))
                cat(sprintf('Risk Constraint Slack = %.4f\n', slackInfo$GetSlackValue()))
		}
	},
	
    ## Tutorial_15c: Risk Parity Constraint
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # to set risk parity constraint.
    #
    Tutorial_15c = function(){
    # Create WorkSpace and setup Risk Model data,
    # Create initial portfolio, etc; no alpha
        self$Initialize( '15c', 'Risk parity constraint' )

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 15c', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

	# Create set of asset IDs to be included
		ids = self$m_WS$CreateIDSet();
		for (i in 1:self$m_Data$m_AssetNum){
			if (self$m_Data$m_ID[i] != 'USA11I1')
				ids$Add(self$m_Data$m_ID[i])
		}

	# Set case as long only and set risk parity constraint
		constraints = self$m_Case$InitConstraints()
		linConstraint = constraints$InitLinearConstraints()
		linConstraint$SetTransactionType('eSHORT_NONE')
		riskConstraint = constraints$InitRiskConstraints()
		riskConstraint$SetRiskParity('eASSET_RISK_PARITY', ids, TRUE, NULL, FALSE)

        self$RunOptimize()
    },
	
    ## Tutorial_16a: Additional covariance term
    #
    # This self-documenting sample code illustrates how to specify the
    # additional covariance term that is added to the objective function.
    # 
    #
    Tutorial_16a = function(){

        self$Initialize( '16a', 'Additional covariance term - WXFX\'W' )

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 16a', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Setup Secondary Risk Model 
        self$SetupRiskModel2()
        riskModel2 = self$m_WS$GetRiskModel('MODEL2')
        self$m_Case$SetSecondaryRiskModel(riskModel2)

    # Setup weight matrix
        attributeSet = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH')
                attributeSet$Set( self$m_Data$m_ID[i], 1 )
		}
        

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

    # Sets the covariance term type = WXFXW with a benchmark and weight matrix, 
    # using secondary risk model
        util$AddCovarianceTerm(0.0075, 'eWXFXW', self$m_BMPortfolio, attributeSet, FALSE)

        self$RunOptimize()
	},

    ## Tutorial_16b: Additional covariance term
    #
    # This self-documenting sample code illustrates how to specify the
    # additional covariance term that is added to the objective function.
    # 
    #
    Tutorial_16b = function(){

        self$Initialize( '16b', 'Additional covariance term - XWFWX\'' )

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 16b', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Setup weight matrix
        attributeSet = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_FactorNum)
            attributeSet$Set( self$m_Data$m_Factor[i], 1 )
        

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

    # Sets the covariance term type = XWFWX and the weight matrix
    # using primary risk model
        util$AddCovarianceTerm(0.0075, 'eXWFWX', NULL, attributeSet) 

        self$RunOptimize()
	},

    ## Tutorial_17a: Five-Ten-Forty Rule
    #
    # This self-documenting sample code illustrates how to apply the 5/10/40 rule
    # 
    #
    Tutorial_17a = function(){
        self$Initialize( '17a', 'Five-Ten-Forty Rule' )

    # Create a case object and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 17a', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set issuer for each asset
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if (!is.null(asset))
                CAsset_SetIssuer(asset, self$m_Data$m_Issuer[i])
		}
        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        constraints = self$m_Case$InitConstraints()

        fiveTenFortyRule = constraints$Init5_10_40Rule()
        fiveTenFortyRule$SetRule(5, 10, 40)

        self$RunOptimize()
    },
    
    ## Tutorial_18: Adding factor block
    #
    # This self-documenting sample code illustrates how to set up the factor block structure
    # in a risk model.
    #
    #
    Tutorial_18 = function(){
        self$Initialize( '18', 'Factor exposure block' )

    # Create a case object and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 18', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        riskModel = self$m_WS$GetRiskModel('GEM')
        factorGroupA = self$m_WS$CreateIDSet()
        factorGroupA$Add('Factor_1A')
        factorGroupA$Add('Factor_2A')
        factorGroupA$Add('Factor_3A')
        factorGroupA$Add('Factor_4A')
        factorGroupA$Add('Factor_5A')
        factorGroupA$Add('Factor_6A')
        factorGroupA$Add('Factor_7A')
        factorGroupA$Add('Factor_8A')
        factorGroupA$Add('Factor_9A')
        riskModel$AddFactorBlock('A', factorGroupA)

        factorGroupB = self$m_WS$CreateIDSet()
        factorGroupB$Add('Factor_1B')
        factorGroupB$Add('Factor_2B')
        factorGroupB$Add('Factor_3B')
        factorGroupB$Add('Factor_4B')
        factorGroupB$Add('Factor_5B')
        factorGroupB$Add('Factor_6B')
        factorGroupB$Add('Factor_7B')
        factorGroupB$Add('Factor_8B')
        factorGroupB$Add('Factor_9B')
        riskModel$AddFactorBlock('B', factorGroupB)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()
	},

	## Tutorial_19: Load Models Direct risk model data
    #
    # This self-documenting sample code illustrates how to load Models Direct data into USE4L risk model.
    #
	Tutorial_19 = function(){
        self$Initialize( '19', 'Load risk model using Models Direct files' )

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 19', self$m_InitPf, self$m_TradeUniverse, 100000)

    # Specify the set of assets to load exposures and specific risk for
        idSet = self$m_WS$CreateIDSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH')
                idSet$Add(self$m_Data$m_ID[i])
		}
        
    # Create the risk model with the Barra model name
        riskModel = self$m_WS$CreateRiskModel('USE4L')

    # Load Models Direct data given location of the files, anaylsis date, and asset set
        status = riskModel$LoadModelsDirectData(self$m_Data$m_Datapath, 20130501, idSet)
        if (status != 'eSUCCESS'){
            cat('Failed to load risk model data using Models Direct files\n')
            return
        }
        self$m_Case$SetPrimaryRiskModel(riskModel)

        linear = self$m_Case$InitConstraints()$InitLinearConstraints()
        info = linear$SetFactorRange('USE4L_SIZE')
        info$SetLowerBound(0.02)
        info$SetUpperBound(0.05)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()

        pfOut = self$m_Solver$GetPortfolioOutput()
        if (!is.null(pfOut)){
            slackInfo = pfOut$GetSlackInfo( 'USE4L_SIZE' )
            if (!is.null(slackInfo))
                cat(sprintf('Optimal portfolio exposure to USE4L_SIZE = %.4f\n', slackInfo$GetSlackValue()))
		}
	},
	
    ## Tutorial_19b: Change numeraire with Models Direct risk model data
    #
    # This self-documenting sample code illustrates how to change numeraire with Models Direct data
    #
    Tutorial_19b = function(){
        self$Initialize( '19b', 'Change numeraire with risk model loaded from Models Direct data', TRUE)

    # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 19b', self$m_InitPf, self$m_TradeUniverse, 100000)

    # Specify the set of assets to load exposures and specific risk for
        idSet = self$m_WS$CreateIDSet()
        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i] != 'CASH')
                idSet$Add(self$m_Data$m_ID[i])         
        }
    # Create the risk model with the Barra model name
        riskModel = self$m_WS$CreateRiskModel('GEM3L')

    # Load Models Direct data given location of the files, anaylsis date, and asset set
        rmStatus = riskModel$LoadModelsDirectData(self$m_Data$m_Datapath, 20131231, idSet)
        if (rmStatus != 'eSUCCESS'){
            cat('Failed to load risk model data using Models Direct files\n')
            return
		}
    # Change numeraire to GEM3L_JPNC
        numStatus = riskModel$SetNumeraire('GEM3L_JPNC')
        if (numStatus$GetStatusCode() != 'eOK'){
            cat(sprintf('%s\n', numStatus$GetMessage()))
            cat(sprintf('%s\n', numStatus$GetAdditionalInfo()))
            return
		}
        self$m_Case$SetPrimaryRiskModel(riskModel)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        self$RunOptimize()
	},
	
	## Tutorial_20: Loading asset exposures with CSV file
    #
    # This self-documenting sample code illustrates how to use Barra Optimizer
    # to load asset exposures with CSV file.
    #
    Tutorial_20 = function(){

        cat('======== Running Tutorial 20 ========\n' )
        cat(paste0('Minimize Total Risk','\n' ))
        self$SetupDumpFile ('20')

    # Create a workspace and setup risk model data without asset exposures
        self$SetupRiskModel(FALSE)

    # Load asset exposures from asset_exposures.csv
        riskModel = self$m_WS$GetRiskModel('GEM')
        status = riskModel$LoadAssetExposures(file.path(self$m_Data$m_Datapath,'asset_exposures.csv') )
        if (status$GetStatusCode() != 'eOK'){
            cat(sprintf('Error loading asset exposures data: %s\n', status$GetMessage()))
            cat(sprintf('%s\n', status$GetAdditionalInfo()))
        }

    # Create initial portfolio etc
        self$SetupPortfolios()

    # Create a case object, null trade universe
        self$m_Case = self$m_WS$CreateCase('Case 20', self$m_InitPf, NULL, 100000)
        self$m_Case$SetPrimaryRiskModel(riskModel)

        util = self$m_Case$InitUtility()

    # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        self$RunOptimize()
	},

    ## Retrieve constraint & asset KKT attribution terms
    #
    # This sample code illustrates how to use Barra Optimizer
    # to retrieve KKT terms of constraint and asset attributions 
    #
    Tutorial_21 = function(){
        cat('======== Running Tutorial 21 ========\n')
        cat('Retrieve KKT terms of constraint & asset attributions\n')
        self$SetupDumpFile ('21')

    # Create a CWorkSpace instance; Release the existing one.
        if (!is.null(self$m_WS))
            self$m_WS$Release()

        self$m_WS = CWorkSpace_DeSerialize(file.path(self$m_Data$m_Datapath,'21.wsp'))
        self$m_Solver = self$m_WS$GetSolver(self$m_WS$GetSolverIDs()$GetFirst())

        self$RunOptimize(TRUE)

        self$CollectKKT()
	},
	
	## Tutorial_22: Multi-period optimization
    #
    # The sample code illustrates how to set up a multi-period optimization for 2 periods.
    #
    Tutorial_22 = function(){      
        self$Initialize( '22', 'Multi-period optimization' )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 22', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set alphas, utility, constraints for period 1
        self$m_WS$SwitchPeriod(1)
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            CAsset_SetAlpha(asset, self$m_Data$m_Alpha[i])
        }
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(1.0)
        
    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        # Set constraints
        linearConstraint = self$m_Case$InitConstraints()$InitLinearConstraints()
        range1 = linearConstraint$SetAssetRange('USA11I1')
        range1$SetLowerBound(0.1)

        # Set alphas, utility, constraints for period 2
        self$m_WS$SwitchPeriod(2)
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            CAsset_SetAlpha(asset, self$m_Data$m_Alpha[self$m_Data$m_AssetNum+1-i])
		}
        # Set utility term
        util$SetAlphaTerm(1.5)

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        # Set constraints
        linear = linearConstraint$SetAssetRange('USA13Y1')
        linear$SetLowerBound(0.2)

        # Set cross-period constraint
        turnoverConstraint = self$m_Case$GetConstraints()$InitTurnoverConstraints()$SetCrossPeriodNetConstraint()
        turnoverConstraint$SetUpperBound(0.5)
    
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)

        # Add periods for multi-period optimization
        self$m_Solver$AddPeriod(1)
        self$m_Solver$AddPeriod(2)

        # Dump wsp file
        if (nchar(self$m_DumpFilename)>0)
			self$m_WS$Serialize(self$m_DumpFilename)
            
        oStatus = self$m_Solver$Optimize()

        cat(sprintf('%s\n', oStatus$GetMessage()))
        cat(sprintf('%s\n\n', self$m_Solver$GetLogMessage()))
    
        if (oStatus$GetStatusCode() == 'eOK'){
            output = self$m_Solver$GetMultiPeriodOutput()
            if (!is.null(output)){
                # Retrieve cross-period output
                crossPeriodOutput = output$GetCrossPeriodOutput()
                cat('Period      = Cross-period\n')
                cat(sprintf('Return(%%)   = %.4f\n', crossPeriodOutput$GetReturn()))
                cat(sprintf('Utility     = %.4f\n', crossPeriodOutput$GetUtility()))
                cat(sprintf('Turnover(%%) = %.4f\n\n', crossPeriodOutput$GetTurnover()))

                # Retrieve output for each period
                for (i in 1:output$GetNumPeriods()){
                    periodOutput = output$GetPeriodOutput(i-1)
                    cat(sprintf('Period      = %d\n',periodOutput$GetPeriodID()))
                    cat(sprintf('Risk(%%)     = %.4f\n',periodOutput$GetRisk()))
                    cat(sprintf('Return(%%)   = %.4f\n', periodOutput$GetReturn()))
                    cat(sprintf('Utility     = %.4f\n', periodOutput$GetUtility()))
                    cat(sprintf('Turnover(%%) = %.4f\n', periodOutput$GetTurnover()))
                    cat(sprintf('Beta        = %.4f\n\n', periodOutput$GetBeta()))
				}
			}
		}
	},
    ## Tutorial_23: Portfolio concentration constraint
    #
    # The sample code illustrates how to run an optimization with a portfolio concentration constraint that limits
    # the total weight of 5 largest positions to no more than 70% of the portfolio.
    #
    Tutorial_23 = function(){    
        self$Initialize( '23', 'Portfolio concentration constraint', TRUE )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 23', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set portfolio concentration constraint
        portConcenCons = self$m_Case$InitConstraints()$SetPortConcentrationConstraint()
        portConcenCons$SetNumTopHoldings(5)
        portConcenCons$SetUpperBound(0.7)

        # Exclude asset USA11I1 from portfolio concentration constraint
        excludedAssets = self$m_WS$CreateIDSet()
        excludedAssets$Add('USA11I1')
        portConcenCons$SetExcludedAssets(excludedAssets)

        util = self$m_Case$InitUtility()

    # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)

        # Run optimization and display results
        self$RunOptimize()

        cat(sprintf('Portfolio conentration=%.4f\n',
			self$m_Solver$Evaluate('ePORTFOLIO_CONCENTRATION', self$m_Solver$GetPortfolioOutput()$GetPortfolio())))

	},
	
    ## Tutorial_25a: Multi-account optimization
    #
    # The sample code illustrates how to set up a multi-account optimization for 2 accounts.
    #
    Tutorial_25a = function(){      
        self$Initialize( '25a', 'Multi-account optimization', TRUE )

        # Create a case object, set trade universe
        self$m_Case = self$m_WS$CreateCase('Case 25a', NULL, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

    # Set constraints for each individual accounts

	# Set utility, constraints for account 1
        self$m_WS$SwitchAccount(1)
        # Set initial portfolio and base value     
        self$m_Case$SetPortBaseValue(1.0e+5)
        self$m_Case$SetInitialPort(self$m_InitPfs[[1]])
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(1.0)
        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        # Set constraints
        linearConstraint = self$m_Case$InitConstraints()$InitLinearConstraints()
        range1 = linearConstraint$SetAssetRange('USA11I1')
        range1$SetLowerBound(0.1)

        # Set utility, constraints for account 2
        self$m_WS$SwitchAccount(2)
        # Set up a different universe for account 2
        tradeUniverse2 = self$m_WS$CreatePortfolio('Trade Universe 2')
        for (i in 1:(self$m_Data$m_AssetNum-3))        
            CPortfolio_AddAsset(tradeUniverse2, self$m_Data$m_ID[i])
        self$m_Case$SetTradeUniverse(tradeUniverse2)
          
        # Set initial portfolio and base value
        self$m_Case$SetInitialPort(self$m_InitPfs[[2]])
        self$m_Case$SetPortBaseValue(3.0e+5)
        # Set utility term
        util$SetAlphaTerm(1.5)
        # Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Set constraints
        linear = linearConstraint$SetAssetRange('USA13Y1')
        linear$SetLowerBound(0.2)

    # set constraints for all accounts and/or cross-account

		self$m_WS$SwitchAccount(ALL_ACCOUNT())
        # Set joint market impact transaction cost
        util$SetJointMarketImpactTerm(0.5)
        # Set the piecewise linear transaction cost
        asset = CWorkSpace_GetAsset(self$m_WS, 'USA11I1')
        if (!is.null(asset)){
            asset$AddPWLinearBuyCost(0.002833681, 1000.0)
            asset$AddPWLinearBuyCost(0.003833681)
            asset$AddPWLinearSellCost(0.003833681)
		}            
        asset = CWorkSpace_GetAsset(self$m_WS, 'USA13Y1')
        if (!is.null(asset)){
            asset$AddPWLinearBuyCost(0.00287745)
            asset$AddPWLinearSellCost(0.00387745)
		}
        asset = CWorkSpace_GetAsset(self$m_WS, 'USA1LI1')
        if (!is.null(asset)){
            asset$AddPWLinearBuyCost(0.00227745)
            asset$AddPWLinearSellCost(0.00327745)
		}
	# Set cross-account constraint
		turnoverConstraint = self$m_Case$GetConstraints()$InitCrossAccountConstraints()$SetNetTurnoverConstraint()
        # cross-account constraint is specified in actual $ amount as opposed to percentage amount
        # the portfolio base value is the aggregate of base values of all accounts'                                       
        turnoverConstraint$SetUpperBound(0.5*(1.0e5 + 3.0e5))
    
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)

        # Add accounts for multi-account optimization
        self$m_Solver$AddAccount(1)
        self$m_Solver$AddAccount(2)

        # Dump wsp file
        if (nchar(self$m_DumpFilename)>0)
            self$m_WS$Serialize(self$m_DumpFilename)

        # Run optimization                              
        oStatus = self$m_Solver$Optimize()

        # Print results
        cat(sprintf('%s\n', oStatus$GetMessage()))
        cat(sprintf('%s\n', self$m_Solver$GetLogMessage()))
        if (oStatus$GetStatusCode() == 'eOK'){  
            output = self$m_Solver$GetMultiAccountOutput()
            if (!is.null(output)){
                # Retrieve cross-account output
                crossAccountOutput = output$GetCrossAccountOutput()
                cat('Account     = Cross-account\n')
                cat(sprintf('Return(%%)   = %.4f\n', crossAccountOutput$GetReturn()))
                cat(sprintf('Utility     = %.4f\n', crossAccountOutput$GetUtility()))
                cat(sprintf('Turnover(%%) = %.4f\n', crossAccountOutput$GetTurnover()))
                cat(sprintf('Joint Market Impact Buy Cost($) = %.4f\n', output$GetJointMarketImpactBuyCost()))
                cat(sprintf('Joint Market Impact Sell Cost($) = %.4f\n\n', output$GetJointMarketImpactSellCost()))
                # Retrieve output for each account
                for (i in 1:output$GetNumAccounts()){
                    accountOutput = output$GetAccountOutput(i-1)
                    cat(sprintf('Account     = %d\n', accountOutput$GetAccountID()))
                    cat(sprintf('Risk(%%)     = %.4f\n', accountOutput$GetRisk()))
                    cat(sprintf('Return(%%)   = %.4f\n', accountOutput$GetReturn()))
                    cat(sprintf('Utility     = %.4f\n', accountOutput$GetUtility()))
                    cat(sprintf('Turnover(%%) = %.4f\n', accountOutput$GetTurnover()))
                    cat(sprintf('Beta        = %.4f\n\n', accountOutput$GetBeta()))
				}
			}
		}
	},

    ## Tutorial_25b: Multi-account tax-aware optimization with 2 accounts
    #
    # This example illustrates how to set up a multi-account tax-aware
    # optimization for 2 accounts with cross-account tax bound
    # and an account-level tax bound.
    Tutorial_25b = function(){
        self$Initialize( '25b', 'Multi-account tax-aware optimization', TRUE, TRUE )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 25b', NULL, self$m_TradeUniverse, 0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Use CMAOTax for tax settings
        tax = self$m_Case$InitMAOTax()
        tax$SetTaxUnit('eDOLLAR')
        # Set cross-account tax limit to $40
        cons = self$m_Case$InitConstraints()
        cons$InitCrossAccountConstraints()$SetTaxLimit()$SetUpperBound(40)

        #
        # Account 1
        #
        self$m_WS$SwitchAccount(1)
        # Set tax lots, initial portfolio and base value for account 1
        self$m_Case$SetInitialPort(self$m_InitPfs[[1]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[1])
        # Narrow the trade universe
        tradeUniverse = self$m_WS$CreatePortfolio('Trade Universe 1')
        for (i in 1:3) {
            tradeUniverse$AddAsset(self$m_Data$m_ID[i])
        }
        self$m_Case$SetTradeUniverse(tradeUniverse)
        # Tax rules
        taxRule1 = tax$AddTaxRule()
        taxRule1$EnableTwoRate()
        taxRule1$SetTaxRate(0.243, 0.423)
        tax$SetTaxRule('*', '*', taxRule1)
        # Set selling order rule as first in/first out for all assets
        tax$SetSellingOrderRule('*', '*', 'eFIFO')
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetAlphaTerm(1.0)
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        # Specify long-only
        linearConstraint = cons$InitLinearConstraints()
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        # Tax constraints
        taxCon = cons$InitNewTaxConstraints()
        taxCon$SetTaxLotTradingRule('USA13Y1_TaxLot_0', 'eSELL_LOT')
        taxCon$SetTaxLimit()$SetUpperBound(25)

        #
        # Account 2
        #
        self$m_WS$SwitchAccount(2)
        self$m_Case$SetInitialPort(self$m_InitPfs[[2]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[2])
        # Tax rules
        taxRule2 = tax$AddTaxRule()
        taxRule2$EnableTwoRate()
        taxRule2$SetTaxRate(0.1, 0.2)
        tax$SetTaxRule('*', '*', taxRule2)
        # Set utility term
        util$SetAlphaTerm(1.5)
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Specify long-only
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        linearConstraint$SetAssetRange('USA13Y1')$SetUpperBound(0.2)

        # Add accounts for multi-account optimization
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
        self$m_Solver$AddAccount(1)
        self$m_Solver$AddAccount(2)

        # Run optimization                              
        self$RunOptimize(TRUE)
    },
	
    ## Tutorial_25c: Multi-account tax-aware optimization with tax arbitrage
    #
    Tutorial_25c = function(){
        self$Initialize( '25c', 'Multi-account optimization with tax arbitrage', TRUE, TRUE )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 25c', NULL, self$m_TradeUniverse, 0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Use CMAOTax for tax settings
        tax = self$m_Case$InitMAOTax()
        tax$SetTaxUnit('eDOLLAR')

        # Set cross-account tax limit to $40
        cons = self$m_Case$InitConstraints()

        #
        # Account 1
        #
        self$m_WS$SwitchAccount(1)
        # Set tax lots, initial portfolio and base value for account 1
        self$m_Case$SetInitialPort(self$m_InitPfs[[1]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[1])
        # Tax rules
        taxRule1 = tax$AddTaxRule()
        taxRule1$EnableTwoRate()
        taxRule1$SetTaxRate(0.243, 0.423)
        tax$SetTaxRule('*', '*', taxRule1)
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        # Specify long-only
        linearConstraint = cons$InitLinearConstraints()
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        # Specify minimum $50 long-term capital net gain
        taxCon = cons$InitNewTaxConstraints()
        taxCon$SetTaxArbitrageRange('*', '*', 'eLONG_TERM', 'eCAPITAL_NET')$SetLowerBound(50)

        #
        # Account 2
        #
        self$m_WS$SwitchAccount(2)
        self$m_Case$SetInitialPort(self$m_InitPfs[[2]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[2])
        # Tax rules
        taxRule2 = tax$AddTaxRule()
        taxRule2$EnableTwoRate()
        taxRule2$SetTaxRate(0.1, 0.2)
        tax$SetTaxRule('*', '*', taxRule2)
        # Set utility term
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Specify long-only
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        # Minimum $100 short-term capital gain
        taxCon$SetTaxArbitrageRange('*', '*', 'eSHORT_TERM', 'eCAPITAL_GAIN')$SetLowerBound(100)

        # Add accounts for multi-account optimization
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
        self$m_Solver$AddAccount(1)
        self$m_Solver$AddAccount(2)

        # Run optimization                              
        self$RunOptimize(TRUE)
    },
	
    ## Tutorial_25d: Multi-account tax-aware optimization with tax harvesting
    #
    Tutorial_25d = function(){
        self$Initialize( '25d', 'Multi-account optimization with tax harvesting', TRUE, TRUE )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 25d', NULL, self$m_TradeUniverse, 0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Use CMAOTax for tax settings
        tax = self$m_Case$InitMAOTax()
        tax$SetTaxUnit('eDOLLAR')

        # Set cross-account tax limit to $40
        cons = self$m_Case$InitConstraints()

        #
        # Account 1
        #
        self$m_WS$SwitchAccount(1)
        # Set tax lots, initial portfolio and base value for account 1
        self$m_Case$SetInitialPort(self$m_InitPfs[[1]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[1])
        # Tax rules
        taxRule1 = tax$AddTaxRule()
        taxRule1$EnableTwoRate()
        taxRule1$SetTaxRate(0.243, 0.423)
        tax$SetTaxRule('*', '*', taxRule1)
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        # Specify long-only
        linearConstraint = cons$InitLinearConstraints()
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        # Target $50 long-term capital net gain
        tax$SetTaxHarvesting('*', '*', 'eLONG_TERM', 50, 0.1)

        #
        # Account 2
        #
        self$m_WS$SwitchAccount(2)
        self$m_Case$SetInitialPort(self$m_InitPfs[[2]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[2])
        # Tax rules
        taxRule2 = tax$AddTaxRule()
        taxRule2$EnableTwoRate()
        taxRule2$SetTaxRate(0.1, 0.2)
        tax$SetTaxRule('*', '*', taxRule2)
        # Set utility term
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Specify long-only
        for (i in 1:self$m_Data$m_AssetNum){
            linearConstraint$SetAssetRange(self$m_Data$m_ID[i])$SetLowerBound(0)
        }
        # Target $100 short-term capital gain
        tax$SetTaxHarvesting('*', '*', 'eSHORT_TERM', 100.0, 0.1)

        # Add accounts for multi-account optimization
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
        self$m_Solver$AddAccount(1)
        self$m_Solver$AddAccount(2)

        # Run optimization                              
        self$RunOptimize(TRUE)
    },
	
    ## Tutorial_25e: Multi-account tax-aware optimization with account groups.
    #
    Tutorial_25e = function(){
        self$Initialize( '25e', 'Multi-account optimization with account groups', TRUE, TRUE )

        # Create a case object, set initial portfolio and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 25e', NULL, self$m_TradeUniverse, 0)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Use CMAOTax for tax settings
        tax = self$m_Case$InitMAOTax()
        tax$SetTaxUnit('eDOLLAR')

        cons = self$m_Case$InitConstraints()
        taxCons = cons$InitNewTaxConstraints()
        linearCons = cons$InitLinearConstraints()

        #
        # Account 1
        #
        self$m_WS$SwitchAccount(1)
        # Set tax lots, initial portfolio and base value for account 1
        self$m_Case$SetInitialPort(self$m_InitPfs[[1]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[1])
        # Tax rules
        taxRule1 = tax$AddTaxRule()
        taxRule1$EnableTwoRate()
        taxRule1$SetTaxRate(0.243, 0.423)
        tax$SetTaxRule('*', '*', taxRule1)
        # Set utility term
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(self$m_BMPortfolio, 0.0075, 0.0075)
        # Specify long-only
        linearCons$SetTransactionType('eSHORT_NONE')
        # Set tax limit to 30$
        info = taxCons$SetTaxLimit()
        info$SetUpperBound(30)

        #
        # Account 2
        #
        self$m_WS$SwitchAccount(2)
        self$m_Case$SetInitialPort(self$m_InitPfs[[2]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[2])
        # Set utility term
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Long-only
        linearCons$SetTransactionType('eSHORT_NONE')

        #
        # Account 3
        #
        self$m_WS$SwitchAccount(3)
        self$m_Case$SetInitialPort(self$m_InitPfs[[3]])
        self$m_Case$SetPortBaseValue(self$m_PfValue[3])
        # Set utility term
        util$SetPrimaryRiskTerm(self$m_BM2Portfolio, 0.0075, 0.0075)
        # Long-only
        linearCons$SetTransactionType('eSHORT_NONE')

        #
        # Account group 1
        #
        # Tax rules
        self$m_WS$SwitchAccountGroup(1)
        taxRule2 = tax$AddTaxRule()
        taxRule2$EnableTwoRate()
        taxRule2$SetTaxRate(0.1, 0.2)
        tax$SetTaxRule('*', '*', taxRule2)
        # Joint tax limit for the group is set on the CCrossAccountConstraint object
        crossAcctCons = cons$InitCrossAccountConstraints()
        crossAcctCons$SetTaxLimit()$SetUpperBound(200)
        
        # Add accounts for multi-account optimization
        self$m_Solver = self$m_WS$CreateSolver(self$m_Case)
        self$m_Solver$AddAccount(1)     # account 1 is stand alone
        self$m_Solver$AddAccount(2,1)   # account 2 and 3 are in account group 1
        self$m_Solver$AddAccount(3,1)

        # Run optimization                              
        self$RunOptimize(TRUE)
    },
	
    Tutorial_26 = function(){      
        self$Initialize( "26", "Issuer Constraint" )

        #Create a case object and trade universe
        self$m_Case = self$m_WS$CreateCase('Case 26', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set issuer for each asset
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS, self$m_Data$m_ID[i])
            if(!is.null(asset))
                CAsset_SetIssuer(asset, self$m_Data$m_Issuer[i])
		}
        util = self$m_Case$InitUtility()

        # Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; 
        # No benchmark
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        constraints = self$m_Case$InitConstraints()
        issuerCons = constraints$InitIssuerConstraints()
        # add a global issuer constraint
        infoGlobal = issuerCons$AddHoldingConstraint('eISSUER_NET')
        infoGlobal$SetLowerBound(0.01)
        # add an individual issuer constraint
        infoInd = issuerCons$AddHoldingConstraint('eISSUER_NET', '4')
        infoInd$SetUpperBound(0.3)

        self$RunOptimize()
	},

    ## Tutorial_27a: Expected Shortfall Term
    #
    # The sample code illustrates how to add an expected shortfall term to the utility.
    #
    Tutorial_27a = function(){
        self$Initialize("27a", "Expected Shortfall Term")

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 27a', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set expected shortfall data
        shortfall = self$m_Case$InitExpectedShortfall()
        shortfall$SetConfidenceLevel(0.90)
        attrSet = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_AssetNum){
            attrSet$Set(self$m_Data$m_ID[i], self$m_Data$m_Alpha[i])
        }
        shortfall$SetTargetMeanReturns(attrSet)
        for (i in 1:self$m_Data$m_ScenarioNum){
            for (j in 1:self$m_Data$m_AssetNum){
                attrSet$Set(self$m_Data$m_ID[j], self$m_Data$m_ScenarioData[i,j])
            }
            shortfall$AddScenarioReturns(attrSet)
        }

        # Set utility terms
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)
        util$SetExpectedShortfallTerm(1.0)
        
        self$RunOptimize()        
    },

    ## Tutorial_27b: Expected Shortfall Constraint
    #
    # The sample code illustrates how to set up an expected shortfall constraint.
    #
    Tutorial_27b = function(){
        self$Initialize("27b", "Expected Shortfall Constraint")

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 27b', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Set expected shortfall data
        shortfall = self$m_Case$InitExpectedShortfall()
        shortfall$SetConfidenceLevel(0.90)
        shortfall$SetTargetMeanReturns(NULL)
        attrSet = self$m_WS$CreateAttributeSet()
        for (i in 1:self$m_Data$m_ScenarioNum){
            for (j in 1:self$m_Data$m_AssetNum){
                attrSet$Set(self$m_Data$m_ID[j], self$m_Data$m_ScenarioData[i,j])
            }
            shortfall$AddScenarioReturns(attrSet)
        }

        # Set expected shortfall constraint
        linCons = self$m_Case$InitConstraints()$InitLinearConstraints()
        info = linCons$SetExpectedShortfallConstraint()
        info$SetUpperBound(0.30)

        # Set utility terms
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)
        
        self$RunOptimize()        
    },

    ## Tutorial_28a: General Ratio Constraint
    #
    # This example illustrates how to setup a ratio constraint specifying
    # the coefficients.
    #
    Tutorial_28a = function(){
        self$Initialize('28a', 'General Ratio Constraint')

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 28a', self$m_InitPf, self$m_TradeUniverse, 100000)
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case$SetPrimaryRiskModel(riskModel)

        # Set a constraint on the weighted average of specific variances of the first three assets
        ratioCons = self$m_Case$InitConstraints()$InitRatioConstraints()
        pNumeratorCoeffs = self$m_WS$CreateAttributeSet()
        for (i in 2:4) {
            id = self$m_Data$m_ID[i]
            pNumeratorCoeffs$Set(id, riskModel$GetSpecificVar(id, id))
        }
        # the denominator defaults to the sum of weights of the assets of the numerator
        info = ratioCons$AddGeneralConstraint(pNumeratorCoeffs)
        info$SetLowerBound(0.05)
        info$SetUpperBound(0.1)

        # Set utility terms
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)) {
            slackInfo = output$GetSlackInfo(info$GetID())
            cat(sprintf('Ratio       = %.4f\n\n', slackInfo$GetSlackValue()))
        }
    },

    ## Tutorial_28b: Group Ratio Constraint
    #
    # This example illustrates how to setup a ratio constraint using asset attributes.
    #
    Tutorial_28b = function(){
        self$Initialize('28b', 'Group Ratio Constraint')

        # Set up GICS_SECTOR group attribute
        for (i in 1:self$m_Data$m_AssetNum) {
            asset = self$m_WS$GetAsset(self$m_Data$m_ID[i])
            if (!is.null(asset)) {
                asset$SetGroupAttribute('GICS_SECTOR', self$m_Data$m_GICS_Sector[i])
            }
        }

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 28b', self$m_InitPf, self$m_TradeUniverse, 100000)
        self$m_Case$SetPrimaryRiskModel(self$m_WS$GetRiskModel('GEM'))

        # Initialize ratio constraints
        ratioCons = self$m_Case$InitConstraints()$InitRatioConstraints()

        # Weight of 'Financials' assets can be at most half of 'Information Technology' assets
        info = ratioCons$AddGroupConstraint('GICS_SECTOR','Financials', 'GICS_SECTOR', 'Information Technology')
        info$SetUpperBound(0.5)

        # Ratio of 'Information Technology' to 'Minerals' should not differ from the benchmark more than +-10%
        info2 = ratioCons$AddGroupConstraint('GICS_SECTOR', 'Minerals', 'GICS_SECTOR', 'Information Technology')
        info2$SetReference(self$m_BMPortfolio)
        info2$SetLowerBound(-0.1, 'ePLUS')
        info2$SetUpperBound(0.1, 'ePLUS')

        # Set utility terms
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        self$RunOptimize()

        output = self$m_Solver$GetPortfolioOutput()
        if (!is.null(output)) {
            slackInfo = output$GetSlackInfo(info$GetID())
            cat(sprintf('Financials / IT = %.4f\n', slackInfo$GetSlackValue()))
            slackInfo = output$GetSlackInfo(info2$GetID())
            cat(sprintf('Minerals / IT   = %.4f\n\n', slackInfo$GetSlackValue()))
        }
    },


    ## Tutorial_29: General Quadratic Constraint
    #
    # This example illustrates how to setup a general quadratic constraint.
    #
    Tutorial_29 = function(){
        self$Initialize('29', 'General Quadratic Constraint')

        # Create a case object
        self$m_Case = self$m_WS$CreateCase('Case 29', self$m_InitPf, self$m_TradeUniverse, 100000)
        riskModel = self$m_WS$GetRiskModel('GEM')
        self$m_Case$SetPrimaryRiskModel(riskModel)

        # Initialize quadratic constraints
        quadraticCons = self$m_Case$InitConstraints()$InitQuadraticConstraints()

        # Create the Q matrix and set some elements
        Q_mat = self$m_WS$CreateSymmetricMatrix(3)

        Q_mat$SetElement(self$m_Data$m_ID[2], self$m_Data$m_ID[2], 0.92473646)
        Q_mat$SetElement(self$m_Data$m_ID[3], self$m_Data$m_ID[3], 0.60338704)
        Q_mat$SetElement(self$m_Data$m_ID[3], self$m_Data$m_ID[4], 0.38904854)
        Q_mat$SetElement(self$m_Data$m_ID[4], self$m_Data$m_ID[4], 0.63569677)

        # The Q matrix must be positive semidefinite
        is_positive_semidefinite = Q_mat$IsPositiveSemidefinite()

        # Create the q vector and set some elements
        q_vect = self$m_WS$CreateAttributeSet()
        for (i in 2:6) {
            q_vect$Set(self$m_Data$m_ID[i], 0.1)
        }

        # Add the constraint and set an upper bound
        info = quadraticCons$AddConstraint(Q_mat,  # Q matrix
            q_vect,  # q vector
            NULL);  # benchmark
        info$SetUpperBound(0.1)

        # Set utility terms
        util = self$m_Case$InitUtility()
        util$SetPrimaryRiskTerm(NULL, 0.0075, 0.0075)

        self$RunOptimize()
    }

)
)