/** @file TutorialApp.cpp
* \brief Contains definations of the CTutorialApp class with specific code for
* each of tutorials.
*/

#include <math.h>
#include <stdio.h>
#include <iostream>
#include <iomanip> 
#include <cstring>
#include "TutorialApp.h"

using namespace BARRAOPT;
using namespace std;

/** \brief Minimizing Total Risk
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* for minimizing Total Risk.
*/
void CTutorialApp::Tutorial_1a()
{
	// Create WorkSpace and setup Risk Model data,
	// Create initial portfolio, etc; no alpha
	Initialize( "1a", "Minimize Total Risk" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 1a", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();
	
	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();

	//Get the slack information for default balance constraint.
	const CPortfolioOutput* pOutput = this->m_pSolver->GetPortfolioOutput();
	const CSlackInfo* pSlackInfo = pOutput->GetSlackInfo4BalanceCon();
	
	//Get the KKT term of the balance constraint.
	const CAttributeSet& impact = pSlackInfo->GetKKTTerm(true);
	printAttributeSet(impact, "Balance constraint KKT term");

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
void CTutorialApp::Tutorial_1b()
{
	Initialize( "1b", "Maximize Return and Minimize Total Risk", true );

	// Create a case object, no trade universe
	m_pCase = m_pWS->CreateCase("Case 1b", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

	// Statement below is optional. 
	// change risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	// util.SetPrimaryRiskTerm(NULL, 0.075, 0.075);

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
void CTutorialApp::Tutorial_1c()
{
	Initialize( "1c", "Minimize Active Risk");

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 1c", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

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
void CTutorialApp::Tutorial_1d()
{
	Initialize( "1d", "Roundlotting", true );

	// Set round lot info
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset) {
			// round lot requires the price of each asset
			asset->SetPrice(m_pData->m_Price[i]);

			// Set lot size to 20
			asset->SetRoundLotSize(20);
		}
	}

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 1d", m_pInitPf, 0, 10000000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

    // Enable Roundlotting; do not allow odd lot clostout 
	m_pCase->InitConstraints().EnableRoundLotting(false); 

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_1e()
{
	Initialize( "1e", "Post optimization roundlotting", true );
	m_pInitPf->AddAsset("CASH", 1.0);
	
	// Set round lot info
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset) {
			// round lot requires the price of each asset
			asset->SetPrice(m_pData->m_Price[i]);

			// Set lot size to 1000
			asset->SetRoundLotSize(1000);
		}
	}

	// Create a case object with trade universe
	double portfolioBaseValue = 10000000;
	m_pCase = m_pWS->CreateCase("Case 1e", m_pInitPf, m_pTradeUniverse, portfolioBaseValue);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();

	// Output trade list for optimal portfolio
	OutputTradeList(true);

	// Output trade list for roundlotted portfolio
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
void CTutorialApp::Tutorial_1f()
{
	Initialize( "1f", "Additional Statistics for Initial/Optimal Portfolio", true );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 1f", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	
	RunOptimize();

	printf("Initial portfolio statistics:\n");
	printf("Return = %.4f\n", m_pSolver->Evaluate(eRETURN) );
	double factorRisk = m_pSolver->Evaluate(eFACTOR_RISK);
	double specificRisk = m_pSolver->Evaluate(eSPECIFIC_RISK);
	printf("Common factor risk = %.4f\n", factorRisk );
	printf("Specific risk = %.4f\n", specificRisk );
	printf("Active risk = %.4f\n", sqrt(factorRisk*factorRisk + specificRisk*specificRisk));
	printf("Short rebate = %.4f\n", m_pSolver->Evaluate(eSHORT_REBATE) );
	printf("Information ratio = %.4f\n", m_pSolver->Evaluate(eINFO_RATIO) );
	cout << endl; 

	const CPortfolio &portfolio = m_pSolver->GetPortfolioOutput()->GetPortfolio();
	printf("Optimal portfolio statistics:\n");
	printf("Return = %.4f\n", m_pSolver->Evaluate(eRETURN, &portfolio) );
	factorRisk = m_pSolver->Evaluate(eFACTOR_RISK, &portfolio);
	specificRisk = m_pSolver->Evaluate(eSPECIFIC_RISK, &portfolio);
	printf("Common factor risk = %.4f\n", factorRisk );
	printf("Specific risk = %.4f\n", specificRisk );
	printf("Active risk = %.4f\n", sqrt(factorRisk*factorRisk + specificRisk*specificRisk));
	printf("Short rebate = %.4f\n", m_pSolver->Evaluate(eSHORT_REBATE, &portfolio) );
	printf("Information ratio = %.4f\n", m_pSolver->Evaluate(eINFO_RATIO, &portfolio) );
	cout << endl; 
}

/**\brief Optimization Problem/Output Portfolio Type
* 
* The sample code shows how to tell if the optimization
* problem is convex, and if the output portfolio is heuristic
* or optimal.
*
*/
void CTutorialApp::Tutorial_1g()
{
	Initialize( "1g", "Optimization Problem/Output Portfolio Type" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 1g", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));
	
	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	
	CConstraints &constraints = m_pCase->InitConstraints();

	// Set max # of assets to be 6
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	paring.AddAssetTradeParing(eNUM_ASSETS).SetMax(6);

	printf("Is type of optimization problem convex: %s\n", m_pCase->IsConvex() ? "Yes" : "No");
		//retrieve paring constraints
	printf("max number of assets is: %d\n\n", paring.GetAssetTradeParingRange(eNUM_ASSETS)->GetMax());

	RunOptimize();

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		printf("The output portfolio is %s\n", pPfOut->IsHeuristic() ? "heuristic" : "optimal");
		const CIDSet& softBoundSlackIDs = pPfOut->GetSoftBoundSlackIDs();
		if (softBoundSlackIDs.GetCount() > 0)
			printf("Soft bound violation found\n");
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
void CTutorialApp::Tutorial_2a()
{
	Initialize( "2a", "Composite Asset" );
 
	// Create a portfolio to represent the composite
	// add its constituents to the portfolio
	// in this example, all assets and equal weighted 
	CPortfolio *pComposite = m_pWS->CreatePortfolio("Composite");
	for(int i=0; i<m_pData->m_AssetNum; i++)
		pComposite->AddAsset(m_pData->m_ID[i], 1.0/m_pData->m_AssetNum);  

	// Create a composite asset COMP1
	CAsset* pAsset = m_pWS->CreateAsset("COMP1", eCOMPOSITE);

	// Link the composite portfolio to the asset
	pAsset->SetCompositePort(*pComposite);

	// add the composite to the trading universe
	m_pTradeUniverse = m_pWS->GetPortfolio("Trade Universe");	
	m_pTradeUniverse->AddAsset("COMP1");

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 2a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_2b()
{
	Initialize( "2b", "Futures Contracts" );
 
	// Create a portfolio to represent the composite
	// add its constituents to the portfolio
	// in this example, all assets and equal weighted 
	CPortfolio *pComposite = m_pWS->CreatePortfolio("Composite");
	for(int i=0; i<m_pData->m_AssetNum; i++)
		pComposite->AddAsset(m_pData->m_ID[i], 1.0/m_pData->m_AssetNum);  

	// Create a composite asset COMP1 as FUTURES
	CAsset *pAsset = m_pWS->CreateAsset("COMP1", eCOMPOSITE_FUTURES);

	// Link the composite portfolio the asset
	pAsset->SetCompositePort(*pComposite);

	// add the composite to the trading universe
	m_pTradeUniverse = m_pWS->GetPortfolio("Trade Universe");	
	m_pTradeUniverse->AddAsset("COMP1");

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 2b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

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
* cash, it is simply set the lower bound and upper bound of the cash asset to 0.
*
* In Tutorial_2c example, we demonstrate how to add a 20% cash contribution to 
* the initial portfolio:
*/
void CTutorialApp::Tutorial_2c()
{
	Initialize( "2c", "Cash contribution" );
 
	// Create a case object. Set initial portfolio
	// 20% cash contribution
	m_pCase = m_pWS->CreateCase("Case 2c", m_pInitPf, 0, 100000, 0.2);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_3a()
{
	Initialize( "3a", "Asset Range Constraints" );
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	for(int j=0; j<m_pData->m_AssetNum; j++) {
 		CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);
		info.SetLowerBound(0.0);
		info.SetUpperBound(0.3);

		// Set asset penalty
		if (!strcmp(m_pData->m_ID[j], "USA11I1")) {
			// Set target to be 0.1; min = 0.0 and max = 0.3
			info.SetPenalty(0.1, 0.0, 0.3);
		}
	}

	CUtility& util = m_pCase->InitUtility();

	//constraint retrieval
	PrintLowerAndUpperBounds(linear);

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
void CTutorialApp::Tutorial_3a2()
{
	Initialize( "3a2", "Relative Asset Range Constraints" );
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3a2", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	for(int j=0; j<m_pData->m_AssetNum; j++) {
 		CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);

		if (!strcmp(m_pData->m_ID[j], "USA11I1")) {
			// Set asset penalty, since benchmark weight is 0.169809
			// min = 0.169809 - 0.03 = 0.139809
			// max = 0.169809 + 0.03 = 0.199809
			info.SetPenalty(0.169809, 0.139809, 0.199809);
		}
		else {
			// Set relative asset range constraint
			info.SetLowerBound(-0.05, ePLUS);
			info.SetUpperBound(0.05, ePLUS);
			info.SetReference(m_pBMPortfolio);
		}
	}

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();
}

/**\brief Factor Range Constraints
*
* In this example, the initial portfolio exposure to Factor_1A is 0.0781, and 
* we want to reduce the exposure to Factor_1A to 0.01.
*/
void CTutorialApp::Tutorial_3b()
{
	Initialize( "3b", "Factor Range Constraints" );
 
	CRiskModel *pRiskModel = m_pWS->GetRiskModel("GEM");

	// show existing exposure to FACTOR_1A
	double exposure = pRiskModel->ComputePortExposure(*m_pInitPf, "Factor_1A");
	printf("Initial portfolio exposure to Factor_1A = %.4f\n", exposure);

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*pRiskModel);

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
 	CConstraintInfo& info = linear.SetFactorRange("Factor_1A");
	info.SetLowerBound(0.00);
	info.SetUpperBound(0.01);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		const CSlackInfo* pSlackInfo = pPfOut->GetSlackInfo( "Factor_1A" );

		if ( pSlackInfo ){
			printf("Optimal portfolio exposure to Factor_1A = %.4f\n", pSlackInfo->GetSlackValue() );
			
			//Get the KKT term of the factor range constraint.
			const CAttributeSet& impact = pSlackInfo->GetKKTTerm(true);
			printAttributeSet(impact, "factor constraint KKT term");
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
void CTutorialApp::Tutorial_3c()
{
	Initialize( "3c", "Beta Constraint" );
 
	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3c", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	CConstraintInfo& info = linear.SetBetaConstraint();
	info.SetLowerBound(0.90);
	info.SetUpperBound(1.0);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	//Get the slack information for beta constraint.
	String constraintID = info.GetID();
	const CPortfolioOutput* pOutput = this->m_pSolver->GetPortfolioOutput();
	const CSlackInfo* pSlackInfo = pOutput->GetSlackInfo(constraintID);
	
	//Get the KKT term of the beta constraint.
	const CAttributeSet& impact = pSlackInfo->GetKKTTerm(true);
	printAttributeSet(impact, "Beta constraint KKT term");
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
void CTutorialApp::Tutorial_3c2()
{
	Initialize( "3c2", "Multiple Beta Constraints" );
 
	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3c2", m_pInitPf, m_pTradeUniverse, 100000, 0.0);

	CRiskModel *pRM = m_pWS->GetRiskModel("GEM");
	m_pCase->SetPrimaryRiskModel(*pRM);

	// Set the beta constraint relative to the benchmark in utility (m_pBMPortfolio)
	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	CConstraintInfo& info = linear.SetBetaConstraint();
	info.SetLowerBound(0.9);
	info.SetUpperBound(0.9);

	// Set the beta constraint relative to a second benchmark (m_pBM2Portfolio)
	const CAttributeSet& assetBetaSet = pRM->ComputePortAssetBeta(*m_pTradeUniverse, m_pBM2Portfolio);
	CConstraintInfo& info2 = linear.AddGeneralConstraint(assetBetaSet);
	info2.SetLowerBound(1.1);
	info2.SetUpperBound(1.1);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput *pOutput = m_pSolver->GetPortfolioOutput();
	double beta = pRM->ComputePortBeta(pOutput->GetPortfolio(), *m_pBMPortfolio);
	cout << "Optimal portfolio's beta relative to benchmark in utility = " << beta << endl;

	double beta2 = pRM->ComputePortBeta(pOutput->GetPortfolio(), *m_pBM2Portfolio);
	cout << "Optimal portfolio's beta relative to second benchmark = " << beta2 << endl;
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
void CTutorialApp::Tutorial_3d()
{
	Initialize( "3d", "User Attribute Constraints" );

	// Set up group attribute
	for(int i=0; i<m_pData->m_AssetNum; i++)
	{
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			// Set GICS Sector attribute
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3d", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints& constraints = m_pCase->InitConstraints();

	// Set a constraint to GICS_SECTOR - Information Technology
	CLinearConstraints &linear = constraints.InitLinearConstraints(); 
	CConstraintInfo &info = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");

	// limit the exposure to 20%
	info.SetLowerBound(0.0);
	info.SetUpperBound(0.2);

	// Set the total risk constraint by group for GICS_SECTOR - Information Technology
	CRiskConstraints& riskConstraint = constraints.InitRiskConstraints();
	CConstraintInfo& risk = riskConstraint.AddTotalConstraintByGroup("GICS_SECTOR", "Information Technology", NULL );
	risk.SetUpperBound(0.1);

	CUtility& util = m_pCase->InitUtility();

	//constraint retrieval
	PrintLowerAndUpperBounds(linear);

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
void CTutorialApp::Tutorial_3e()
{
	Initialize( "3e", "Relative Constraints" );

	// Set up group attribute
	for(int i=0; i<m_pData->m_AssetNum; i++)
	{
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			// Set GICS Sector attribute
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3e", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set a constraint to GICS_SECTOR - Information Technology
	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	CConstraintInfo &info1 = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");

	// limit the exposure to 50% of the reference portfolio
	info1.SetReference(m_pBMPortfolio);
	info1.SetLowerBound(0.0, eMULTIPLE);
	info1.SetUpperBound(0.5, eMULTIPLE);

	CConstraintInfo &info2 = linear.SetFactorRange("Factor_1A");

	// limit the Factor_1A exposure to +/- 0.01 of the reference portfolio
	info2.SetReference(m_pBMPortfolio);
	info2.SetLowerBound(-0.01, ePLUS);
	info2.SetUpperBound(0.01, ePLUS);

	CUtility& util = m_pCase->InitUtility();

	//constraint retrieval
	PrintLowerAndUpperBounds(linear);

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
void CTutorialApp::Tutorial_3f()
{
	Initialize( "3f", "Transaction Type" );

	// Create a case object. Set initial portfolio and trade universe
	// Contribute 30% cash for buying additional securities
	m_pCase = m_pWS->CreateCase("Case 3f", m_pInitPf, m_pTradeUniverse, 100000, 0.3);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set Transaction Type to Sell None/Buy From Universe
	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints();
	linear.SetTransactionType(eSELL_NONE_BUY_FROM_UNIV);

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_3g()
{
	Initialize( "3g", "Crossover Option" , true);
	m_pInitPf->AddAsset("CASH", 1);

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3g", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();
	
	CLinearConstraints &linear = constraints.InitLinearConstraints();
	linear.SetTransactionType(eBUY_SHORT_FROM_UNIV);

	// Disable crossover
	linear.EnableCrossovers(false);

	CConstraintInfo& info = linear.SetAssetRange("USA11I1");
	info.SetLowerBound(-1.0);
	info.SetUpperBound(1.0);

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_3h()
{
	Initialize( "3h", "Total Active Weight Constraint" , true);

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3h", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();
	CConstraintInfo& info = constraints.SetTotalActiveWeightConstraint();
	info.SetLowerBound(0);
	info.SetUpperBound(0.01);
	info.SetReference(m_pBMPortfolio);
	
	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	double sumActiveWeight=0;
	const CPortfolioOutput* pOutput = m_pSolver->GetPortfolioOutput();
	if (pOutput) {
		const CPortfolio& optimalPort = pOutput->GetPortfolio();
		const CIDSet& idSet = optimalPort.GetAssetIDSet();
		for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext()) {
			double benchWeight = m_pBMPortfolio->GetAssetWeight(assetID);
			if (benchWeight != OPT_NAN) {
				sumActiveWeight += fabs(benchWeight - optimalPort.GetAssetWeight(assetID));
			}
		}
	}
	cout << "Total active weight = " << sumActiveWeight << endl;
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
* Tutorial_3h illustrates how to set up the dollar-neutral strategy by replacing the balance constraint with 
* a customized general linear constraint. 
*/
void CTutorialApp::Tutorial_3i()
{
	Initialize( "3i", "Dollar Neutral Strategy", true);

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3i", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();
	CLinearConstraints &linear = constraints.InitLinearConstraints();
	//  Disable the default portfolio balance constraint
	linear.EnablePortfolioBalanceConstraint(false);
	// Set equal weights
	CAttributeSet* coeffs = m_pWS->CreateAttributeSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;
		coeffs->Set( m_pData->m_ID[i], 1.0 );
	}
	CConstraintInfo& info = linear.AddGeneralConstraint(*coeffs);
	// Set the upper & lower bounds of the general linear constraint 
	info.SetLowerBound(0);
	info.SetUpperBound(0);
	
	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	double sumWeight=0;
	const CPortfolioOutput* pOutput = m_pSolver->GetPortfolioOutput();
	if (pOutput) {
		const CPortfolio& optimalPort = pOutput->GetPortfolio();
		const CIDSet& idSet = optimalPort.GetAssetIDSet();
		for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext())
			if(assetID!="CASH")
				sumWeight += optimalPort.GetAssetWeight(assetID);
	}
	cout << "Sum of all weights = " << sumWeight << endl;
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
void CTutorialApp::Tutorial_3j()
{
	Initialize( "3j", "Asset Free Range Linear Penalty" );
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 3j", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	for(int j=0; j<m_pData->m_AssetNum; j++) {
		// Set asset free range penalty
		if (strcmp(m_pData->m_ID[j], "CASH")) {
			 CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);
			// Set free range to -0.1 to 0.1, with downside slope = -0.01, upside slope = 0.01
			info.SetFreeRangeLinearPenalty(-0.01, 0.01, -0.10, 0.10);
		}
	}

	CUtility& util = m_pCase->InitUtility();

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
* This tutorial also illustrates how to estimate utility upper bound. 
*/
void CTutorialApp::Tutorial_4a()
{
	cout << "======== Running Tutorial 4a ========\n"
		 << "Max # of assets and estimated utility upper bound\n";
	SetupDumpFile("4a");

	SetupRiskModel();

	// Create an initial portfolio with cash only
	// replicate the benchmark risk with max # of assets
	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");
	m_pInitPf->AddAsset("CASH", 1.0);

	m_pTradeUniverse = m_pWS->CreatePortfolio("Trade Universe");	
	m_pBMPortfolio = m_pWS->CreatePortfolio("Benchmark");	
	for(int i=0; i<m_pData->m_AssetNum; i++)
	{
		if(strcmp(m_pData->m_ID[i], "CASH")!=0)
		{
			m_pTradeUniverse->AddAsset(m_pData->m_ID[i]);
			m_pBMPortfolio->AddAsset(m_pData->m_ID[i], 0.1);
		}
	}
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Invest all cash
	CLinearConstraints &linear = constraints.InitLinearConstraints(); 
	CConstraintInfo &info = linear.SetAssetRange("CASH");
	info.SetLowerBound(0.0);
	info.SetUpperBound(0.0);

	// Set max # of assets to be 6
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	paring.AddAssetTradeParing(eNUM_ASSETS).SetMax(6);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// run optimization and report estimated utility upperbound
	RunOptimizeReportUtilUB();
}

/**\brief Holding and Transaction Size Thresholds
*
* The minimum holding level is measured as a percentage, expressed in decimals,
* of the base value (in this example, 0.04 is 4%).  This feature ensures that 
* the optimizer will not recommend trades too small to be meaningful in your analysis.
*
* Minimum transaction size is measured as a percentage of the base value
* (in this example, 0.02 is 2%). 
*/
void CTutorialApp::Tutorial_4b()
{
	Initialize( "4b", "Min Holding Level and Transaction Size" );

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set minimum holding threshold; both for long and short positions
	// in this example 4%
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	paring.AddLevelParing(eMIN_HOLDING_LONG, 0.04);
	paring.AddLevelParing(eMIN_HOLDING_SHORT, 0.04);
	paring.EnableGrandfatherRule();					// Enable grandfather rule

	// Set minimum trade size; both for long side and short side,
	// in this example 2%
	paring.AddLevelParing(eMIN_TRANX_LONG, 0.02);
	paring.AddLevelParing(eMIN_TRANX_SHORT, 0.02);


	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_4c()
{
	Initialize( "4c", "Soft Turnover Constraint" );

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4c", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set soft turnover constraint
	CTurnoverConstraints &turnover = constraints.InitTurnoverConstraints(); 
	CConstraintInfo & info = turnover.SetNetConstraint();
	info.SetSoft(true);
	info.SetUpperBound(0.2);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();
}

/**\brief Buy Side Turnover Constraint
*
* The following tutorial limits the maximum turnover for the buy side.
*
*/
void CTutorialApp::Tutorial_4d()
{
	Initialize( "4d", "Limit Buy Side Turnover Constraint" );

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4d", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set buy side turnover constraint
	CTurnoverConstraints &turnover = constraints.InitTurnoverConstraints(); 
	CConstraintInfo & info = turnover.SetBuySideConstraint();
	info.SetUpperBound(0.1);

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_4e()
{
	Initialize( "4e", "Paring by group" );

	for( int i = 0; i<m_pData->m_AssetNum; i++)
	{
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4e", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set max # of asset in GICS Sector/Information Technology to 1
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	CParingRange &range = paring.AddAssetTradeParingByGroup(eNUM_ASSETS, "GICS_SECTOR", "Information Technology");
	range.SetMax(1);

	// Set minimum holding threshold for GICS Sector/Information Technology to 0.2
	paring.AddLevelParingByGroup(eMIN_HOLDING_LONG, "GICS_SECTOR", "Information Technology", 0.2);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

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
void CTutorialApp::Tutorial_4f()
{
	Initialize( "4f", "Net turnover by group" );

	// Set up group attribute
	for(int i=0; i<m_pData->m_AssetNum; i++)
	{
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			// Set GICS Sector attribute
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}
 
	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4f", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));


	// Set the net turnover by group for GICS_SECTOR - Information Technology
	CTurnoverConstraints &toCons = m_pCase->InitConstraints().InitTurnoverConstraints();
	CConstraintInfo &infoGroup = toCons.AddNetConstraintByGroup("GICS_SECTOR", "Information Technology");
	infoGroup.SetUpperBound(0.03);

	// Set the overall portfolio turnover
	CConstraintInfo &info = toCons.SetNetConstraint();
	info.SetUpperBound(0.3);

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_4g()
{
	Initialize( "4g", "Paring penalty" );

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 4g", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	CParingConstraints &paring = constraints.InitParingConstraints(); 
	paring.AddAssetTradeParing(eNUM_TRADES).SetMax(2);		// Set maximum number of trades
	paring.AddAssetTradeParing(eNUM_ASSETS).SetMin(5);		// Set minimum number of assets

	// Set paring penalty. Violation of the "max# trades=2" constraint would generate 0.005 disutility per extra trade.
	paring.SetPenaltyPerExtraTrade(0.005);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	RunOptimize();
}

/**\brief Linear Transaction Costs
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
* as shown in this simple example using two cents per share and 20 basis
* points for the first 10,000 dollar buy cost. For more than 10,000 dollar or
* short selling, the cost is 2 cents per share and 30 basis points.
*
* In this example, the 2 cents per share transaction commission is translated
* into a relative weight via the share’s price. The simple-linear market impact
* cost of 20 basis points is already in relative-weight terms.  
*
* In the case of Asset 1 (USA11I1), its share price is 23.99 USD, so the .02 
* per share cost becomes .02/23.99= .000833681, and added to the 20 basis 
* points cost .002 + .000833681= .002833681. 
*
* The short sell cost is higher at 30 basis points, so that becomes 
* 0.003 + .00833681 = .003833681, in terms of relative weight. 
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
void CTutorialApp::Tutorial_5a()
{
	cout << "======== Running Tutorial 5a ========\n"
		 << "Piecewise Linear Transaction Costs\n";
	SetupDumpFile ("5a");

	// Create WorkSpace and setup Risk Model data
	SetupRiskModel();

	// Create an initial holding portfolio with the hard coded data
	// portfolio with no Cash
	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");
	m_pInitPf->AddAsset("USA11I1", 0.3);
	m_pInitPf->AddAsset("USA13Y1", 0.7);
 
	// Set the transaction cost
	CAsset *asset = m_pWS->GetAsset("USA11I1");
	if (asset) {
		// the price is 23.99

		// the 1st 10,000, 
		// the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
		asset->AddPWLinearBuyCost(0.002833681, 10000.0);

		// from 10,000 to +INF, 
		// the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
		asset->AddPWLinearBuyCost(0.003833681);

		// Sell cost is 30 basis + $0.02 per share =  0.003 + 0.02/23.99
		asset->AddPWLinearSellCost(0.003833681);
	}

	asset = m_pWS->GetAsset("USA13Y1");
	if (asset)
	{
		// the price is 34.19

		// the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
		asset->AddPWLinearBuyCost(0.00287745);

		// Sell cost is 30 basis + $0.03 per share = 0.003 + 0.03/34.19
		asset->AddPWLinearSellCost(0.00387745);
	}

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5a", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();
	util.SetTranxCostTerm();

	RunOptimize();
}

/**\brief Nonlinear Transaction Costs
*
* Tutorial_5b illustrates how to set up the parameters c, p and q for 
* nonlinear transaction costs
*/
void CTutorialApp::Tutorial_5b()
{
	cout << "======== Running Tutorial 5b ========\n"
		 << "Nonlinear Transaction Costs\n";
	SetupDumpFile ("5b");

	// Create WorkSpace and setup Risk Model data
	SetupRiskModel();

	// Create an initial holding portfolio with the hard coded data
	// portfolio with no Cash
	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");
	m_pInitPf->AddAsset("USA11I1", 0.3);
	m_pInitPf->AddAsset("USA13Y1", 0.7);
 
	// Asset nonlinear transaction cost
	// Cost is 0.5 bps for 1% of USA11I1 traded and exponent of 1.1
	// c = 0.00005, p = 1.1, and q = 0.01
	m_pWS->GetAsset("USA11I1")->SetNonLinearTranxCost(0.00005, 1.1, 0.01);

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5b", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Case-level nonlinear transaction cost
	// Cost is 0.1 bps for 1% traded value and exponent of 1.1
	// c = 0.00001, p = 1.1, and q = 0.01
	m_pCase->SetNonLinearTranxCost(0.00001, 1.1, 0.01);

	CUtility& util = m_pCase->InitUtility();
	util.SetTranxCostTerm();

	RunOptimize();
}

/**\brief Transaction Cost Constraints
*
* You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
*/
void CTutorialApp::Tutorial_5c()
{
	cout << "======== Running Tutorial 5c ========\n"
		 << "Transaction Cost Constraint\n";
	SetupDumpFile ("5c");

	SetupRiskModel();

	// Create an initial portfolio with no Cash
	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");
	m_pInitPf->AddAsset("USA11I1", 0.3);
	m_pInitPf->AddAsset("USA13Y1", 0.7);
 
	// Set the transaction cost
	CAsset *asset = m_pWS->GetAsset("USA11I1");
	if (asset) {
		// the price is 23.99

		// the 1st 10,000, 
		// the cost rate is 20 basis + $0.02 per share = 0.002 + 0.02/23.99
		asset->AddPWLinearBuyCost(0.002833681, 10000.0);

		// from 10,000 to +OPT_INF, 
		// the cost rate is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
		asset->AddPWLinearBuyCost(0.003833681);

		// Sell cost is 30 basis + $0.02 per share = 0.003 + 0.02/23.99
		asset->AddPWLinearSellCost(0.003833681);
	}

	asset = m_pWS->GetAsset("USA13Y1");
	if (asset)
	{
		// the price is 34.19

		// the cost rate is 20 basis + $0.03 per share = 0.002 + 0.03/34.19
		asset->AddPWLinearBuyCost(0.00287745);

		// Sell cost is 30 basis + $0.03 per share = 0.003 + 0.02/34.19
		asset->AddPWLinearSellCost(0.00387745);
	}

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5c", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	CConstraintInfo& info = constraints.SetTransactionCostConstraint();
	info.SetUpperBound(0.0005);

	CUtility& util = m_pCase->InitUtility();
	util.SetTranxCostTerm();
	RunOptimize();
}

/**\brief Fixed Transaction Costs
*
* Tutorial_5d illustrates how to set up fixed transaction costs
*/
void CTutorialApp::Tutorial_5d()
{
	Initialize( "5d", "Fixed Transaction Costs", true );

	// Set fixed transaction costs for non-cash assets
	for( int i = 0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")!=0) {
			CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
			if ( asset ) {
				asset->SetFixedBuyCost(0.02);
				asset->SetFixedSellCost(0.03);
			}
		}
	}

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5d", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
	util.SetTranxCostTerm();

	RunOptimize();
}

/**\brief load asset-level data, including fixed transaction costs from csv file
*
* Tutorial_5e illustrates how to set up asset-level data including fixed transaction costs and group association from csv file
*/
void CTutorialApp::Tutorial_5e()
{
	Initialize( "5e", "Asset-Level Data incl. Fixed Transaction Costs", true );

	// Set fixed transaction costs for non-cash assets
	// load asset-level group name & attributes 
	const CStatus& status = m_pWS->LoadAssetData(m_pData->m_Datapath + "asset_data.csv");
	if (status.GetStatusCode() != eOK) {
		cout << "Error loading transaction cost data: "
			 << status.GetMessage() << endl
			 << status.GetAdditionalInfo() << endl;
	}

	// Create a case object. Set initial portfolio & trade universe
	m_pCase = m_pWS->CreateCase("Case 5e", m_pInitPf, m_pTradeUniverse, 100000.0, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set a linear constraint to GICS_SECTOR - Information Technology
	CLinearConstraints &linear = constraints.InitLinearConstraints(); 
	CConstraintInfo &info = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");
	// limit the exposure to between 10%-50%
	info.SetLowerBound(0.1);
	info.SetUpperBound(0.5);
	
	// Set a hedge constraint to GICS_SECTOR - Information Technology
	CHedgeConstraints &hedgeConstr = constraints.InitHedgeConstraints();
	CConstraintInfo& wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint("GICS_SECTOR", "Information Technology");
	wtlGrpConsInfo.SetLowerBound(1.0, ePLUS);
	wtlGrpConsInfo.SetUpperBound(1.3, ePLUS);
	wtlGrpConsInfo.SetSoft(true);

	// Set max # of asset in GICS Sector/Information Technology to 1
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	CParingRange &range = paring.AddAssetTradeParingByGroup(eNUM_ASSETS, "GICS_SECTOR", "Information Technology");
	range.SetMax(1);
	// Set minimum holding threshold for GICS Sector/Information Technology to 0.2
	paring.AddLevelParingByGroup(eMIN_HOLDING_LONG, "GICS_SECTOR", "Information Technology", 0.2);	

	// Set the net turnover by group for GICS_SECTOR - Information Technology
	CTurnoverConstraints &toCons = constraints.InitTurnoverConstraints();
	CConstraintInfo &infoGroup = toCons.AddNetConstraintByGroup("GICS_SECTOR", "Information Technology");
	infoGroup.SetUpperBound(0.03);

	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
	util.SetTranxCostTerm();

	RunOptimize();

	//m_pSolver->WriteInputToFile(m_pData->m_Datapath + "group-by-csv.txt");
}

/**\brief Fixed Holding Costs
*
* Tutorial_5f illustrates how to set up fixed holding costs
*/
void CTutorialApp::Tutorial_5f()
{
	Initialize( "5f", "Fixed Holding Costs", true );

	// Set fixed transaction costs for non-cash assets
	for( int i = 0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")!=0) {
			CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
			if ( asset ) {
				asset->SetUpSideFixedHoldingCost(0.02);
				asset->SetDownSideFixedHoldingCost(0.03);
			}
		}
	}

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5f", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(10.0);		// default value of the multiplier is 1.
	util.SetFixedHoldingCostTerm(1.5); // default value of the multiplier is 1.

	RunOptimize();
}

/**\brief General Piecewise Linear Constraint
*
* Tutorial_5g illustrates how to set up general piecewise linear Constraints
*/
void CTutorialApp::Tutorial_5g()
{
	Initialize( "5g", "General Piecewise Linear Constraint", true );

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 5g", m_pInitPf, 0, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	CConstraints& constraints = m_pCase->InitConstraints();
	CGeneralPWLinearConstraint& generalPWLICon = constraints.AddGeneralPWLinearConstraint();
    
	generalPWLICon.SetStartingPoint( m_pData->m_ID[0], m_pData->m_BMWeight[0] );
	generalPWLICon.AddDownSideSlope( m_pData->m_ID[0], -0.01, 0.05 );
	generalPWLICon.AddDownSideSlope( m_pData->m_ID[0], -0.03 );
	generalPWLICon.AddUpSideSlope( m_pData->m_ID[0], 0.02, 0.04 );
	generalPWLICon.AddUpSideSlope( m_pData->m_ID[0], 0.03 );

	CConstraintInfo& conInfo = generalPWLICon.SetConstraint();
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
void CTutorialApp::Tutorial_6a()
{
	Initialize( "6a", "Penalty" );
 
	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 6a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	CConstraintInfo& info = linear.SetBetaConstraint();
	info.SetLowerBound(-OPT_INF);
	info.SetUpperBound(OPT_INF);

	// Set target to be 0.95; min = 0.80 and max = 1.2
	info.SetPenalty(0.95, 0.80, 1.2);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();
}

/**\brief Risk Budgeting
*
* In the following example, we will constrain the amount of risk coming
* from common factor risk.  
*
*/
void CTutorialApp::Tutorial_7a()
{
	Initialize( "7a", "Risk Budgeting", true );

	// Create a case object, set initial portfolio and trade universe
	CRiskModel *riskModel = m_pWS->GetRiskModel("GEM");
	m_pCase = m_pWS->CreateCase("Case 7a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*riskModel);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		printf("Specific Risk(%%) = %.4f\n", pPfOut->GetSpecificRisk() );
		printf("Factor Risk(%%) = %.4f\n", pPfOut->GetFactorRisk() );

		CRiskConstraints& riskConstraint = m_pCase->InitConstraints().InitRiskConstraints();

		cout << endl << "Add a risk constraint: FactorRisk<=12%";
		CConstraintInfo& info = riskConstraint.AddPLFactorConstraint();
		info.SetUpperBound(0.12);

		CIDSet *pfid = m_pWS->CreateIDSet();
        //add four factors
		pfid->Add("Factor_1B");
		pfid->Add("Factor_1C");
		pfid->Add("Factor_1D");
		pfid->Add("Factor_1E");

		cout << endl << "Add a risk constraint: Factor_1B-1E<=1.9%" << endl <<endl;
		CConstraintInfo& info2 = riskConstraint.AddFactorConstraint( NULL, pfid );
		info2.SetUpperBound(0.019);

		RunOptimize(true);     // use the existing solver without recreating a new solver

		const CPortfolioOutput* pPfOut2 = m_pSolver->GetPortfolioOutput();
		if ( pPfOut2 ) {
			printf("Specific Risk(%%) = %.4f\n", pPfOut2->GetSpecificRisk() );
			printf("Factor Risk(%%) = %.4f\n", pPfOut2->GetFactorRisk() );
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
* constraint relative to the model portfolio with an active risk upper bound 
* of 300 basis points. 
*
* This self-documenting sample code illustrates how to perform risk-constrained
* optimization with dual benchmarks: 
*/
void CTutorialApp::Tutorial_7b()
{
	Initialize( "7b", "Risk Budgeting - Dual Benchmark" );

	// Create a case object, set initial portfolio and trade universe
	CRiskModel *riskModel = m_pWS->GetRiskModel("GEM");
	m_pCase = m_pWS->CreateCase("Case 7b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*riskModel);

	CRiskConstraints& riskConstraint = m_pCase->InitConstraints().InitRiskConstraints();

	CConstraintInfo& info = riskConstraint.AddPLTotalConstraint(true, m_pBM2Portfolio);
	info.SetID( "RiskConstraint" );
	info.SetUpperBound(0.16);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) {
		const CSlackInfo* pSlackInfo = output->GetSlackInfo("RiskConstraint");
		if ( pSlackInfo )
			cout << "Risk Constraint Slack = " << fixed
				 << pSlackInfo->GetSlackValue() << endl << endl; 
	}
}

/**\brief Risk Budgeting using additive definition
*
* In the following example, we will constrain the amount of risk coming from
* subsets of assets/factors using additive risk definition
*
*/
void CTutorialApp::Tutorial_7c()
{
	Initialize( "7c", "Additive Risk Definition", true );

	// Create a case object, set initial portfolio and trade universe
	CRiskModel *riskModel = m_pWS->GetRiskModel("GEM");
	m_pCase = m_pWS->CreateCase("Case 7c", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*riskModel);

	CUtility& util = m_pCase->InitUtility();
	RunOptimize();

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		printf("Specific Risk(%%) = %.4f\n", pPfOut->GetSpecificRisk() );
		printf("Factor Risk(%%) = %.4f\n", pPfOut->GetFactorRisk() );

		// subset of assets
		CIDSet *pid = m_pWS->CreateIDSet();
		pid->Add("USA13Y1");
		pid->Add("USA1TY1");

		// subset of factors (7|8|9*)
		CIDSet *pfid = m_pWS->CreateIDSet();
		for(int i=48; i<m_pData->m_FactorNum; i++) {
			pfid->Add(m_pData->m_Factor[i]);
		}

		printf("Risk from USA13Y1 & 1TY1 = %.4f\n", m_pSolver->EvaluateRisk(pPfOut->GetPortfolio(), eTOTALRISK, NULL, pid, NULL, true, true));
		printf("Risk from Factor_7|8|9* = %.4f\n", m_pSolver->EvaluateRisk(pPfOut->GetPortfolio(), eFACTORRISK, NULL, NULL, pfid, true, true));

		CRiskConstraints& riskConstraint = m_pCase->InitConstraints().InitRiskConstraints();

		cout << endl << "Add a risk constraint(additive def): from USA13Y1 & 1TY1 <=1%";
		CConstraintInfo& info = riskConstraint.AddTotalConstraint( pid, NULL, true, NULL, false, false, false, true);
		info.SetUpperBound(0.01);

		cout << endl << "Add a risk constraint(additive def): from Factor_7|8|9* <=1.9%" << endl <<endl;
		CConstraintInfo& info2 = riskConstraint.AddFactorConstraint( NULL, pfid, true, NULL, false, false, false, true);
		info2.SetUpperBound(0.019);

		RunOptimize(true);     // use the existing solver without recreating a new solver

		const CPortfolioOutput* pPfOut2 = m_pSolver->GetPortfolioOutput();
		if ( pPfOut2 ) {
			printf("Specific Risk(%%) = %.4f\n", pPfOut2->GetSpecificRisk() );
			printf("Factor Risk(%%) = %.4f\n", pPfOut2->GetFactorRisk() );
			printf("Risk from USA13Y1 & 1TY1 = %.4f\n", m_pSolver->EvaluateRisk(pPfOut2->GetPortfolio(), eTOTALRISK, NULL, pid, NULL, true, true));
			printf("Risk from Factor_7|8|9* = %.4f\n\n", m_pSolver->EvaluateRisk(pPfOut2->GetPortfolio(), eFACTORRISK, NULL, NULL, pfid, true, true));

			const CIDSet& ids = pPfOut2->GetSlackInfoIDs();
			for(String id=ids.GetFirst(); id!=""; id=ids.GetNext())
				printf("Risk Constraint Slack of %s = %.4f\n", id.c_str(), pPfOut2->GetSlackInfo(id)->GetSlackValue());
		}
	}
}

/**\brief Risk Budgeting by asset
*
* In the following example, we will constrain the amount of risk coming from
* individual assets using additive risk definition.
*/
void CTutorialApp::Tutorial_7d()
{
	Initialize("7d", "Risk Budgeting By Asset", true);

	// Create a case object, set initial portfolio and trade universe
	CRiskModel *riskModel = m_pWS->GetRiskModel("GEM");
	m_pCase = m_pWS->CreateCase("Case 7d", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*riskModel);

	// Add a risk constraint by asset (additive def): risk from USA11I1 and from 13Y1 to be between 3% and 5% 
	CRiskConstraints& riskConstraint = m_pCase->InitConstraints().InitRiskConstraints();
	CIDSet *pid = m_pWS->CreateIDSet();
	pid->Add("USA11I1");
	pid->Add("USA13Y1");
	CConstraintInfo& info = riskConstraint.AddRiskConstraintByAsset(pid, true, NULL, false, false, false, true);
	info.SetLowerBound(0.03);
	info.SetUpperBound(0.05);

	CUtility& util = m_pCase->InitUtility();

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// Print asset risks in the initial portfolio
	cout << "Initial Portfolio:" << endl;
	printRisksByAsset(*m_pInitPf);
	cout << endl;

	RunOptimize(true);

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if (pPfOut) {
		// Print asset risks in the optimal portfolio
		printRisksByAsset(pPfOut->GetPortfolio());
		cout << endl;

		const CIDSet& ids = pPfOut->GetSlackInfoIDs();
		for (String id = ids.GetFirst(); id != ""; id = ids.GetNext())
			printf("Risk Constraint Slack of %s = %.4f\n", id.c_str(), pPfOut->GetSlackInfo(id)->GetSlackValue());
		cout << endl;
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
void CTutorialApp::Tutorial_8a()
{
	cout << "======== Running Tutorial 8a ========\n"
		 << "Long-Short Hedge Optimization \n";
	SetupDumpFile ("8a");

	// Create WorkSpace and setup Risk Model data
	SetupRiskModel();

	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");	
	m_pTradeUniverse = m_pWS->CreatePortfolio("Trade Universe");	
 	SetAlpha();

	for( int i = 0; i<m_pData->m_AssetNum; i++)
	{
		if(strcmp(m_pData->m_ID[i], "CASH")!=0)
			m_pTradeUniverse->AddAsset(m_pData->m_ID[i]);
		else
			m_pInitPf->AddAsset(m_pData->m_ID[i], 1.0);
	}

	// Create a case object with 10M cash portfolio
	m_pCase = m_pWS->CreateCase("Case 8a", m_pInitPf, m_pTradeUniverse, 10000000.0, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints& constraints = m_pCase->InitConstraints();
	CLinearConstraints &linear = constraints.InitLinearConstraints(); 
	for(int j=0; j<m_pData->m_AssetNum; j++)
	{
	 	CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);
		if(strcmp(m_pData->m_ID[j], "CASH")!=0)
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

	CHedgeConstraints& hedgeConstr = constraints.InitHedgeConstraints();
	CConstraintInfo& longInfo = hedgeConstr.SetLongSideLeverageRange();
	longInfo.SetLowerBound(1.0);
	longInfo.SetUpperBound(1.3);

	CConstraintInfo& shortInfo = hedgeConstr.SetShortSideLeverageRange();
	shortInfo.SetLowerBound(-0.3);
	shortInfo.SetUpperBound(0.0);
	
	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

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
void CTutorialApp::Tutorial_8b()
{
	Initialize( "8b", "Short Costs as Single Attribute" , true);
	m_pInitPf->AddAsset("CASH", 1);

	// Create a case object. Set initial portfolio
	m_pCase = m_pWS->CreateCase("Case 8b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	CLinearConstraints &linear = constraints.InitLinearConstraints();
	for(int j=0; j<m_pData->m_AssetNum; j++)
	{
	 	CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);
		if(strcmp(m_pData->m_ID[j], "CASH")!=0)
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

	CHedgeConstraints& hedgeConstr = constraints.InitHedgeConstraints();
	CConstraintInfo& shortInfo = hedgeConstr.SetShortSideLeverageRange();
	shortInfo.SetLowerBound(-0.3);
	shortInfo.SetUpperBound(0.0);

	// Set the net short cost
	CAsset *asset = m_pWS->GetAsset("USA11I1");
	if (asset) {
		// ShortCost = CostOfLeverage + HardToBorrowPenalty – InterestRateOnProceed
		// where CostOfLeverage=50 basis, HardToBorrowPenalty=10 basis, InterestRateOnProceed=20 basis
		asset->SetNetShortCost(0.004);
	}

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();
}

/**\brief Weighted Total Leverage Constraint Optimization
*
* The following tutorial illustrates how to set Weighted Total Leverage Constraint
*
*/
void CTutorialApp::Tutorial_8c()
{
	cout << "======== Running Tutorial 8c ========\n"
		 << "Weighted Total Leverage Constraint Optimization \n";
	SetupDumpFile ("8c");

	// Create WorkSpace and setup Risk Model data
	SetupRiskModel();

	m_pInitPf = m_pWS->CreatePortfolio("Initial Portfolio");	
	m_pTradeUniverse = m_pWS->CreatePortfolio("Trade Universe");	
 	SetAlpha();

	for( int i = 0; i<m_pData->m_AssetNum; i++)
	{
		if(strcmp(m_pData->m_ID[i], "CASH")!=0)
			m_pTradeUniverse->AddAsset(m_pData->m_ID[i]);
		else
			m_pInitPf->AddAsset(m_pData->m_ID[i], 1.0);
		
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}

	// Create a case object with 10M cash portfolio
	m_pCase = m_pWS->CreateCase("Case 8c", m_pInitPf, m_pTradeUniverse, 10000000.0, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints& constraints = m_pCase->InitConstraints();
	CLinearConstraints &linear = constraints.InitLinearConstraints(); 
	for(int j=0; j<m_pData->m_AssetNum; j++)
	{
	 	CConstraintInfo& info = linear.SetAssetRange(m_pData->m_ID[j]);
		if(strcmp(m_pData->m_ID[j], "CASH")!=0)
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

	CAttributeSet* longSideCoeffs = m_pWS->CreateAttributeSet();
	CAttributeSet* shortSideCoeffs = m_pWS->CreateAttributeSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		longSideCoeffs->Set( m_pData->m_ID[i], 1.0 );
		shortSideCoeffs->Set( m_pData->m_ID[i], 1.0 );
	}

	CHedgeConstraints& hedgeConstr = constraints.InitHedgeConstraints();
	CConstraintInfo& wtlFacConsInfo = hedgeConstr.AddTotalLeverageFactorConstraint("Factor_1A");
	wtlFacConsInfo.SetLowerBound(1.0, ePLUS);
	wtlFacConsInfo.SetUpperBound(1.3, ePLUS);
	wtlFacConsInfo.SetPenalty(0.95, 0.80, 1.2);
	wtlFacConsInfo.SetSoft(true);

	CConstraintInfo& wtlConsInfo = hedgeConstr.AddWeightedTotalLeverageConstraint(*longSideCoeffs, *shortSideCoeffs);
	wtlConsInfo.SetLowerBound(1.0, ePLUS);
	wtlConsInfo.SetUpperBound(1.3, ePLUS);
	wtlConsInfo.SetPenalty(0.95, 0.80, 1.2);
	wtlConsInfo.SetSoft(true);

	CConstraintInfo& wtlGrpConsInfo = hedgeConstr.AddTotalLeverageGroupConstraint("GICS_SECTOR", "Information Technology");
	wtlGrpConsInfo.SetLowerBound(1.0, ePLUS);
	wtlGrpConsInfo.SetUpperBound(1.3, ePLUS);
	wtlGrpConsInfo.SetPenalty(0.95, 0.80, 1.2);
	wtlGrpConsInfo.SetSoft(true);

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; no benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	//constraint retrieval
	PrintLowerAndUpperBounds(linear);
	PrintLowerAndUpperBounds(hedgeConstr);

	RunOptimize();

}

/**\brief Long-side Turnover Constraint
*
* The following case illustrates the use of turnover by side constraint, which needs to
* be used in conjunction with long-short optimization. The maximum turnover on the long side
* is 20%, with total value on the long side equal to total value on the short side.
* 
*/
void CTutorialApp::Tutorial_8d()
{
	Initialize( "8d", "Long-side Turnover Constraint" );
	m_pInitPf->AddAsset("CASH");

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 8d", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set soft turnover constraint
	CTurnoverConstraints &turnover = constraints.InitTurnoverConstraints(); 
	CConstraintInfo & info = turnover.SetLongSideConstraint();
	info.SetUpperBound(0.2);

	// Set hedge constraint
	CHedgeConstraints &hedge = constraints.InitHedgeConstraints();
	CConstraintInfo &hedgeInfo = hedge.SetShortLongLeverageRatioRange();
	hedgeInfo.SetLowerBound(1.0);
	hedgeInfo.SetUpperBound(1.0);

	CUtility& util = m_pCase->InitUtility();

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
void CTutorialApp::Tutorial_9a()
{
	Initialize( "9a", "Risk Target", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 9a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set (active) risk target to 14%
	m_pCase->SetRiskTarget(0.14);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();
}

/**\brief Return Target
*
* Similar to Tutoral_9a, we define a return target of 1% in Tutorial_9b:
*/
void CTutorialApp::Tutorial_9b()
{
	Initialize( "9b", "Return Target", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 9b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set return target
	m_pCase->SetReturnTarget(0.01);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();
}

/**\brief Tax-aware Optimization (using pre-v8.8 legacy APIs)
*
* Suppose an individual investor desires to rebalance a portfolio to be “more
* like the benchmark,” but also wants to avoid having any net tax liability 
* doing so.  In Tutorial_10a, we are rebalancing without alphas, and assume 
* the portfolio has no realized capital gains so far this year.  The trading
* rule is FIFO.
*/
void CTutorialApp::Tutorial_10a()
{
	Initialize( "10a", "Tax-aware Optimization (using pre-v8.8 legacy APIs)" );

	double assetValue[m_pData->m_AssetNum];
	for (int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset* asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetPrice( m_pData->m_Price[i] );

		assetValue[i] = 0;
	}

	double pfValue = 0.;
	for (int j=0; j<m_pData->m_Taxlots; j++) {
		int iAccount = m_pData->m_Account[j];
		if (iAccount == 0) {
			int iAsset = m_pData->m_Indices[j];
			m_pInitPf->AddTaxLot(m_pData->m_ID[iAsset], m_pData->m_Age[j],
				m_pData->m_CostBasis[j], m_pData->m_Shares[j], false);

			double lotValue = m_pData->m_Price[iAsset] * m_pData->m_Shares[j];
			assetValue[iAsset] += lotValue;
			pfValue += lotValue;
		}
	}
	
	// Reset asset initial weights that are calculated from tax lot information
	for(int i=0; i<m_pData->m_AssetNum; i++)
		m_pInitPf->AddAsset( m_pData->m_ID[i], assetValue[i]/pfValue );

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10a", m_pInitPf, m_pTradeUniverse, pfValue, 0.0);

	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CTax& tax = m_pCase->InitTax();
	tax.EnableTwoRate(); //default is 365
	tax.SetTaxRate(0.243, 0.423); //long term and short term rates

	// not allow wash sale
	tax.SetWashSaleRule(eDISALLOWED, 30);

	// first in, first out
	tax.SetSellingOrderRule(eFIFO);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) { 
		const CTaxOutput *taxOut = output->GetTaxOutput();
		if (taxOut) {
			cout << "Tax Info:\n";
			printf("Long Term Gain  = %.2f\n", taxOut->GetLongTermGain());
			printf("Long Term Loss  = %.2f\n", taxOut->GetLongTermLoss());
			printf("Long Term Tax   = %.2f\n", taxOut->GetLongTermTax());
			printf("Short Term Gain = %.2f\n", taxOut->GetShortTermGain());
			printf("Short Term Loss = %.2f\n", taxOut->GetShortTermLoss());
			printf("Short Term Tax  = %.2f\n", taxOut->GetShortTermTax());
			printf("Total Tax       = %.2f\n\n", taxOut->GetTotalTax());

			const CPortfolio &portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();
			printf( "TaxlotID          Shares:\n" );
			for ( String assetID=idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext() ) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for ( String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext() ) {
					int shares = (int)sharesInTaxlot.GetValue( lotID );

					if ( shares!=0 ) 
						printf( "%s %8d\n", lotID.c_str(), shares );
				}
			}
			cout << endl;
		}
	}
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
void CTutorialApp::Tutorial_10b()
{
	Initialize( "10b", "Capital Gain Arbitrage (using pre-v8.8 legacy APIs)" );

	for (int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset* asset = m_pWS->GetAsset(m_pData->m_ID[i]);

		if (asset)
			asset->SetPrice( m_pData->m_Price[i] );
	}

	for (int j = 0; j < m_pData->m_Taxlots; j++) {
		int iAccount = m_pData->m_Account[j];
		if (iAccount == 0)
			m_pInitPf->AddTaxLot(m_pData->m_ID[m_pData->m_Indices[j]],
				m_pData->m_Age[j], m_pData->m_CostBasis[j],
				m_pData->m_Shares[j], false);
	}

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10b", m_pInitPf, m_pTradeUniverse, 4279.4, 0.0);

	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CTax& tax = m_pCase->InitTax();
	tax.EnableTwoRate();		  //default short term period is 365
	tax.SetTaxRate(0.243, 0.423); //long term and short term rates

	// not allow wash sale
	tax.SetWashSaleRule(eDISALLOWED, 30);

	// first in, first out
	tax.SetSellingOrderRule(eFIFO);

	CConstraints &constraints = m_pCase->InitConstraints();
	CTaxConstraints &taxConstr = constraints.InitTaxConstraints();

	CConstraintInfo &shortConstr = taxConstr.SetShortGainArbitrageRange();
	shortConstr.SetLowerBound(0.0);
	shortConstr.SetUpperBound(0.0);

	CConstraintInfo &longConstr = taxConstr.SetLongLossArbitrageRange();
	longConstr.SetLowerBound(0.0);
	longConstr.SetUpperBound(110.0);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();
	
	// print additional tax-related information
	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) {
		const CTaxOutput *taxOut = output->GetTaxOutput();
		if ( taxOut ) {
			cout << "Tax Info:\n";
			printf("Long Term Gain  = %.2f\n", taxOut->GetLongTermGain());
			printf("Long Term Loss  = %.2f\n", taxOut->GetLongTermLoss());
			printf("Long Term Tax   = %.2f\n", taxOut->GetLongTermTax());
			printf("Short Term Gain = %.2f\n", taxOut->GetShortTermGain());
			printf("Short Term Loss = %.2f\n", taxOut->GetShortTermLoss());
			printf("Short Term Tax  = %.2f\n", taxOut->GetShortTermTax());
			printf("Total Tax       = %.2f\n\n", taxOut->GetTotalTax());
		}
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
void CTutorialApp::Tutorial_10c()
{
	Initialize( "10c", "Tax-aware Optimization (Using new APIs introduced in v8.8)" );

	double assetValue[m_pData->m_AssetNum];
	for (int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset* asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetPrice( m_pData->m_Price[i] );

		assetValue[i] = 0;
	}

	// Set up group attribute
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		// Set GICS Sector attribute
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}

	// Add tax lots into the portfolio, compute asset values and portfolio value
	double pfValue = 0.;
	for (int j=0; j<m_pData->m_Taxlots; j++) {
		int iAccount = m_pData->m_Account[j];
		if (iAccount == 0) {
			int iAsset = m_pData->m_Indices[j];
			m_pInitPf->AddTaxLot(m_pData->m_ID[iAsset], m_pData->m_Age[j],
				m_pData->m_CostBasis[j], m_pData->m_Shares[j], false);

			double lotValue = m_pData->m_Price[iAsset] * m_pData->m_Shares[j];
			assetValue[iAsset] += lotValue;
			pfValue += lotValue;
		}
	}
	
	// Reset asset initial weights based on tax lot information
	for(int i=0; i<m_pData->m_AssetNum; i++)
		m_pInitPf->AddAsset( m_pData->m_ID[i], assetValue[i]/pfValue );

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10c", m_pInitPf, m_pTradeUniverse, pfValue, 0.0);

	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Initialize a CNewTax object
	CNewTax& oTax = m_pCase->InitNewTax();

	// Add a tax rule that covers all assets
	CTaxRule& taxRule  = oTax.AddTaxRule( "*", "*" );
	taxRule.EnableTwoRate();
	taxRule.SetTaxRate(0.243, 0.423);
	taxRule.SetWashSaleRule(eDISALLOWED, 30);	// not allow wash sale

	// Set selling order rule as first in/first out for all assets
	oTax.SetSellingOrderRule("*", "*", eFIFO);	// first in, first out
	
	// Specify long-only
	CConstraints& oCons = m_pCase->InitConstraints();
	CLinearConstraints &linearCon = oCons.InitLinearConstraints(); 
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		CConstraintInfo& info = linearCon.SetAssetRange(m_pData->m_ID[i]);
		info.SetLowerBound(0.0);
	}

	// Set a group level tax arbitrage constraint
	CNewTaxConstraints& oTaxCons = oCons.InitNewTaxConstraints();
	CConstraintInfo& lgRange = oTaxCons.SetTaxArbitrageRange( "GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_GAIN );
	lgRange.SetUpperBound( 250. );

	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) { 
		const CNewTaxOutput* taxOut = output->GetNewTaxOutput();
		if (taxOut) {
			double lgg = taxOut->GetCapitalGain( "GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_GAIN );
			double lgl = taxOut->GetCapitalGain( "GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_LOSS );
			double sgg = taxOut->GetCapitalGain( "GICS_SECTOR", "Information Technology", eSHORT_TERM, eCAPITAL_GAIN );
			double sgl = taxOut->GetCapitalGain( "GICS_SECTOR", "Information Technology", eSHORT_TERM, eCAPITAL_LOSS );

			cout << "Tax info for group GICS_SECTOR/Information Technology:\n";
			printf("Long Term Gain  = %.4f\n", lgg );
			printf("Long Term Loss  = %.4f\n", lgl );
			printf("Short Term Gain = %.4f\n", sgg );
			printf("Short Term Loss = %.4f\n", sgl );

			double ltax = taxOut->GetLongTermTax( "*", "*" );
			double stax = taxOut->GetShortTermTax("*", "*");
			double lgg_all = taxOut->GetCapitalGain( "*", "*", eLONG_TERM, eCAPITAL_GAIN );
			double lgl_all = taxOut->GetCapitalGain( "*", "*", eLONG_TERM, eCAPITAL_LOSS );
			
			cout << "\nTax info for the tax rule group(all assets):\n";
			printf("Long Term Gain = %.4f\n", lgg_all );
			printf("Long Term Loss = %.4f\n", lgl_all );
			printf("Long Term Tax  = %.4f\n", ltax );
			printf("Short Term Tax = %.4f\n", stax );

			printf("\nTotal Tax(for all tax rule groups) = %.4f\n\n", taxOut->GetTotalTax());

			const CPortfolio &portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();
			printf( "TaxlotID          Shares:\n" );
			for ( String assetID=idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext() ) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for ( String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext() ) {
					double shares = sharesInTaxlot.GetValue( lotID );

					if ( shares!=0 ) 
						printf( "%s  %.4f\n", lotID.c_str(), shares );
				}
			}

			const CAttributeSet& newShares = taxOut->GetNewShares();
			printAttributeSet(newShares, "\nNew Shares:");
			cout << endl;
		}
	}
}

/**\brief Tax-aware Optimization (Using new APIs introduced in v8.8)
*
* This tutorial illustrates how to set up a tax-aware optimization case with cash outflow.
*/
void CTutorialApp::Tutorial_10d()
{
	Initialize("10d", "Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow");

	double assetValue[m_pData->m_AssetNum];
	for (int i = 0; i < m_pData->m_AssetNum; i++) {
		CAsset* asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetPrice(m_pData->m_Price[i]);

		assetValue[i] = 0;
	}

	// Set up group attribute
	for (int i = 0; i < m_pData->m_AssetNum; i++) {
		// Set GICS Sector attribute
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}

	// Add tax lots into the portfolio, compute asset values and portfolio value
	double pfValue = 0.;
	for (int j = 0; j < m_pData->m_Taxlots; j++) {
		int iAccount = m_pData->m_Account[j];
		if (iAccount == 0) {
			int iAsset = m_pData->m_Indices[j];
			m_pInitPf->AddTaxLot(m_pData->m_ID[iAsset], m_pData->m_Age[j],
				m_pData->m_CostBasis[j], m_pData->m_Shares[j], false);

			double lotValue = m_pData->m_Price[iAsset] * m_pData->m_Shares[j];
			assetValue[iAsset] += lotValue;
			pfValue += lotValue;
		}
	}

	// Cash outflow 5% of the base value
	double CFW = -0.05;

	// Set base value so that the final optimal weight will sum up to 100%
	double BV = pfValue / (1 - CFW);

	// Reset asset initial weights based on tax lot information
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		m_pInitPf->AddAsset(m_pData->m_ID[i], assetValue[i]/BV );

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10d", m_pInitPf, m_pTradeUniverse, BV, CFW);

	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Initialize a CNewTax object
	CNewTax& oTax = m_pCase->InitNewTax();

	// Add a tax rule that covers all assets
	CTaxRule& taxRule = oTax.AddTaxRule("*", "*");
	taxRule.EnableTwoRate();
	taxRule.SetTaxRate(0.243, 0.423);
	taxRule.SetWashSaleRule(eDISALLOWED, 30);	// not allow wash sale

	// Set selling order rule as first in/first out for all assets
	oTax.SetSellingOrderRule("*", "*", eFIFO);	// first in, first out

	// Specify long-only
	CConstraints& oCons = m_pCase->InitConstraints();
	CLinearConstraints &linearCon = oCons.InitLinearConstraints();
	for (int i = 0; i < m_pData->m_AssetNum; i++) {
		CConstraintInfo& info = linearCon.SetAssetRange(m_pData->m_ID[i]);
		info.SetLowerBound(0.0);
	}

	// Set a group level tax arbitrage constraint
	CNewTaxConstraints& oTaxCons = oCons.InitNewTaxConstraints();
	CConstraintInfo& lgRange = oTaxCons.SetTaxArbitrageRange("GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_GAIN);
	lgRange.SetUpperBound(250.);

	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if (output) {
		const CNewTaxOutput* taxOut = output->GetNewTaxOutput();
		if (taxOut) {
			double lgg = taxOut->GetCapitalGain("GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_GAIN);
			double lgl = taxOut->GetCapitalGain("GICS_SECTOR", "Information Technology", eLONG_TERM, eCAPITAL_LOSS);
			double sgg = taxOut->GetCapitalGain("GICS_SECTOR", "Information Technology", eSHORT_TERM, eCAPITAL_GAIN);
			double sgl = taxOut->GetCapitalGain("GICS_SECTOR", "Information Technology", eSHORT_TERM, eCAPITAL_LOSS);

			cout << "Tax info for group GICS_SECTOR/Information Technology:\n";
			printf("Long Term Gain  = %.4f\n", lgg);
			printf("Long Term Loss  = %.4f\n", lgl);
			printf("Short Term Gain = %.4f\n", sgg);
			printf("Short Term Loss = %.4f\n", sgl);

			double ltax = taxOut->GetLongTermTax("*", "*");
			double stax = taxOut->GetShortTermTax("*", "*");
			double lgg_all = taxOut->GetCapitalGain("*", "*", eLONG_TERM, eCAPITAL_GAIN);
			double lgl_all = taxOut->GetCapitalGain("*", "*", eLONG_TERM, eCAPITAL_LOSS);

			cout << "\nTax info for the tax rule group(all assets):\n";
			printf("Long Term Gain = %.4f\n", lgg_all);
			printf("Long Term Loss = %.4f\n", lgl_all);
			printf("Long Term Tax  = %.4f\n", ltax);
			printf("Short Term Tax = %.4f\n", stax);

			printf("\nTotal Tax(for all tax rule groups) = %.4f\n\n", taxOut->GetTotalTax());

			const CPortfolio &portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();
			printf("TaxlotID          Shares:\n");
			for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext()) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for (String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext()) {
					double shares = sharesInTaxlot.GetValue(lotID);

					if (shares != 0)
						printf("%s  %.4f\n", lotID.c_str(), shares);
				}
			}

			const CAttributeSet& newShares = taxOut->GetNewShares();
			printAttributeSet(newShares, "\nNew Shares:");
			cout << endl;
		}
	}
}

/**\brief Tax-aware Optimization with loss benefit
*
* This tutorial illustrates how to set up a tax-aware optimization case with
* a loss benefit term in the utility.
*/
void CTutorialApp::Tutorial_10e()
{
	Initialize( "10e", "Tax-aware Optimization with loss benefit", false, true );

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10e", m_pInitPf, m_pTradeUniverse, m_PfValue[0], 0.0);

	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Disable shorting
	CLinearConstraints& linear = m_pCase->InitConstraints().InitLinearConstraints();
	linear.SetTransactionType(eSHORT_NONE);

	// Initialize a CNewTax object
	CNewTax& oTax = m_pCase->InitNewTax();

	// Add a tax rule that covers all assets
	CTaxRule& taxRule  = oTax.AddTaxRule( "*", "*" );
	taxRule.EnableTwoRate();
	taxRule.SetTaxRate(0.243, 0.423);
	taxRule.SetWashSaleRule(eDISALLOWED, 30);	// not allow wash sale

	// Set selling order rule as first in/first out for all assets
	oTax.SetSellingOrderRule("*", "*", eFIFO);	// first in, first out

	CUtility& util = m_pCase->InitUtility();
	util.SetLossBenefitTerm(1.0);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) {
		const CNewTaxOutput* taxOut = output->GetNewTaxOutput();
		if (taxOut) {
			double ltax = taxOut->GetLongTermTax( "*", "*" );
			double stax = taxOut->GetShortTermTax("*", "*");
			double lgg = taxOut->GetCapitalGain( "*", "*", eLONG_TERM, eCAPITAL_GAIN );
			double lgl = taxOut->GetCapitalGain( "*", "*", eLONG_TERM, eCAPITAL_LOSS );
			double sgg = taxOut->GetCapitalGain( "*", "*", eSHORT_TERM, eCAPITAL_GAIN );
			double sgl = taxOut->GetCapitalGain( "*", "*", eSHORT_TERM, eCAPITAL_LOSS );
			double lb = taxOut->GetTotalLossBenefit();
			double tax = taxOut->GetTotalTax();

			printf("Tax info:\n");
			printf("Long Term Gain  = %.4f\n", lgg );
			printf("Long Term Loss  = %.4f\n", lgl );
			printf("Short Term Gain = %.4f\n", sgg );
			printf("Short Term Loss = %.4f\n", sgl );
			printf("Long Term Tax   = %.4f\n", ltax );
			printf("Short Term Tax  = %.4f\n", stax );
			printf("Loss Benefit    = %.4f\n", lb );
			printf("Total Tax       = %.4f\n\n", tax);

			const CPortfolio &portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();
			printf( "TaxlotID          Shares:\n" );
			for ( String assetID=idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext() ) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for ( String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext() ) {
					double shares = sharesInTaxlot.GetValue( lotID );

					if ( shares!=0 )
						printf( "%s  %.4f\n", lotID.c_str(), shares );
				}
			}

			const CAttributeSet& newShares = taxOut->GetNewShares();
			printAttributeSet(newShares, "\nNew Shares:");
			cout << endl;
		}
	}
}

/**\brief Tax-aware Optimization with total loss and gain constraints.
*
* This tutorial illustrates how to set up a tax-aware optimization case with
* bounds on total gain and loss.
*/
void CTutorialApp::Tutorial_10f()
{
	Initialize("10f", "Tax-aware Optimization with total loss/gain constraints", false, true);

	// Set up GICS Sector attribute
	for (int i = 0; i < m_pData->m_AssetNum; i++) {
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
	}

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10f", m_pInitPf, m_pTradeUniverse, m_PfValue[0], 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Disable shorting and cash
	CConstraints& oCons = m_pCase->InitConstraints();
	CLinearConstraints& linear = oCons.InitLinearConstraints();
	linear.SetTransactionType(eSHORT_NONE);
	linear.SetAssetTradeSize("CASH", 0);

	// Initialize a CNewTax object and set tax parameters
	CNewTax& oTax = m_pCase->InitNewTax();
	CTaxRule& taxRule = oTax.AddTaxRule("*", "*");
	taxRule.EnableTwoRate();
	taxRule.SetTaxRate(0.243, 0.423);
	oTax.SetSellingOrderRule("*", "*", eFIFO);

	// Set a group level tax arbitrage constraint on total loss
	CNewTaxConstraints& oTaxCons = oCons.InitNewTaxConstraints();
	CConstraintInfo& info = oTaxCons.SetTotalTaxArbitrageRange("GICS_SECTOR", "Financials", eCAPITAL_LOSS);
	info.SetUpperBound(100.);

	// Set a group level tax arbitrage constraint on total gain
	CConstraintInfo& info2 = oTaxCons.SetTotalTaxArbitrageRange("GICS_SECTOR", "Information Technology", eCAPITAL_GAIN);
	info2.SetLowerBound(250.);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if (output) {
		const CNewTaxOutput* taxOut = output->GetNewTaxOutput();
		if (taxOut) {
			double tgg = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Financials", eCAPITAL_GAIN);
			double tgl = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Financials", eCAPITAL_LOSS);
			double tgn = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Financials", eCAPITAL_NET);
			printf("Tax info (Financials):\n");
			printf("Total Gain  = %.4f\n", tgg);
			printf("Total Loss  = %.4f\n", tgl);
			printf("Total Net   = %.4f\n\n", tgn);

			tgg = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Information Technology", eCAPITAL_GAIN);
			tgl = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Information Technology", eCAPITAL_LOSS);
			tgn = taxOut->GetTotalCapitalGain("GICS_SECTOR", "Information Technology", eCAPITAL_NET);
			printf("Tax info (Information Technology):\n");
			printf("Total Gain  = %.4f\n", tgg);
			printf("Total Loss  = %.4f\n", tgl);
			printf("Total Net   = %.4f\n\n", tgn);

			const CPortfolio &portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();
			printf("TaxlotID          Shares:\n");
			for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext()) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for (String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext()) {
					double shares = sharesInTaxlot.GetValue(lotID);

					if (shares != 0)
						printf("%s  %.4f\n", lotID.c_str(), shares);
				}
			}

			const CAttributeSet& newShares = taxOut->GetNewShares();
			printAttributeSet(newShares, "\nNew Shares:");
			cout << endl;
		}
	}
}

/**\brief Tax-aware Optimization with wash sales in the input.
*
* This tutorial illustrates how to specify wash sales, set the wash sale rule,
* and access wash sale details from the output.
*/
void CTutorialApp::Tutorial_10g()
{
	Initialize("10g", "Tax-aware Optimization with wash sales", false, true);

	// Add an extra lot whose age is within the wash sale period
	m_pInitPf->AddTaxLot("USA11I1", 12, 21.44, 20.0);
	
	// Recalculate asset weight from tax lot data
	UpdatePortfolioWeights();

	// Add wash sale records
	m_pInitPf->AddWashSaleRec("USA2ND1", 20, 12.54, 10.0, false);
	m_pInitPf->AddWashSaleRec("USA3351", 35, 2.42, 25.0, false);
	m_pInitPf->AddWashSaleRec("USA39K1", 12, 9.98, 25.0, false);

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 10g", m_pInitPf, m_pTradeUniverse, m_PfValue[0], 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Disable shorting and cash
	CConstraints& oCons = m_pCase->InitConstraints();
	CLinearConstraints& linear = oCons.InitLinearConstraints();
	linear.SetTransactionType(eSHORT_NONE);
	linear.SetAssetTradeSize("CASH", 0);

	// Initialize a CNewTax object and set tax parameters
	CNewTax& oTax = m_pCase->InitNewTax();
	CTaxRule& taxRule = oTax.AddTaxRule("*", "*");
	taxRule.EnableTwoRate();
	taxRule.SetTaxRate(0.243, 0.423);
	taxRule.SetWashSaleRule(eTRADEOFF, 40);
	oTax.SetSellingOrderRule("*", "*", eFIFO);

	CUtility& util = m_pCase->InitUtility();

	RunOptimize();

	// Retrieving tax related information from the output
	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if (output) {
		const CNewTaxOutput* taxOut = output->GetNewTaxOutput();
		if (taxOut) {
			const CPortfolio& portfolio = output->GetPortfolio();
			const CIDSet& idSet = portfolio.GetAssetIDSet();

			// Shares in tax lots
			printf("TaxlotID          Shares:\n");
			for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext()) {
				const CAttributeSet& sharesInTaxlot = taxOut->GetSharesInTaxLots(assetID);

				const CIDSet& oLotIDs = sharesInTaxlot.GetKeySet();
				for (String lotID = oLotIDs.GetFirst(); !lotID.empty(); lotID = oLotIDs.GetNext()) {
					double shares = sharesInTaxlot.GetValue(lotID);

					if (shares != 0)
						printf("%s  %.4f\n", lotID.c_str(), shares);
				}
			}

			// New shares
			const CAttributeSet& newShares = taxOut->GetNewShares();
			printAttributeSet(newShares, "\nNew Shares:");
			cout << endl;

			// Disqualified shares
			const CAttributeSet& disqShares = taxOut->GetDisqualifiedShares();
			printAttributeSet(disqShares, "Disqualified Shares:");
			cout << endl;

			// Wash sale details
			printf("Wash Sale Details:\n");
			printf("%-20s%12s%10s%10s%12s%20s\n", "TaxLotID", "AdjustedAge", "CostBasis", "Shares", "SoldShares", "DisallowedLotID");
			const CIDSet& assetIDs = m_pCase->GetAssetIDs();
			for (String assetID = assetIDs.GetFirst(); assetID != ""; assetID = assetIDs.GetNext()) {
				const CWashSaleDetail* pWSDetail = taxOut->GetWashSaleDetail(assetID);
				if (pWSDetail) {
					for (int i = 0; i < pWSDetail->GetCount(); i++) {
						String lotID = pWSDetail->GetLotID(i);
						String disallowedLotID = pWSDetail->GetDisallowedLotID(i);
						Int32 age = pWSDetail->GetAdjustedAge(i);
						double costBasis = pWSDetail->GetAdjustedCostBasis(i);
						double shares = pWSDetail->GetShares(i);
						double soldShares = pWSDetail->GetSoldShares(i);
						printf("%-20s%12d%10.4f%10.4f%12.4f%20s\n",
							lotID.c_str(), age, costBasis, shares, soldShares, disallowedLotID.c_str());
					}
				}
			}
			cout << endl;
		}
	}
}

/**\brief Efficient Frontier
*
* In the following Risk-Reward Efficient Frontier problem, we have chosen the
* return constraint, specifying a lower bound of 0% turnover, upper bound of 
* 10% return and ten points.  
*/
void CTutorialApp::Tutorial_11a()
{
	Initialize( "11a", "Efficient Frontier", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 11a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CFrontier &frontier = m_pCase->InitFrontier(eRISK_RETURN);

	frontier.SetMaxNumDataPoints(10);
	frontier.SetFrontierRange(0.0, 0.1);

	CUtility& util = m_pCase->InitUtility();

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// m_dumpFilename contains all work space data that are useful for debugging
	if ( m_DumpFilename.size() ) m_pWS->Serialize(m_DumpFilename);

	cout << "\nNon-Interactive approach..." << endl;

	const CStatus& oStatus = m_pSolver->Optimize();
	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;

	const CFrontierOutput *frontierOutput = m_pSolver->GetFrontierOutput();
	for (int i=0; i<frontierOutput->GetNumDataPoints(); i++) {
		const CDataPoint* dataPoint = frontierOutput->GetFrontierDataPoint(i);
	
		cout << "Risk(%) = " << fixed << setprecision(3) << dataPoint->GetRisk() << 
		  "    Return(%) = " << fixed << setprecision(3) << dataPoint->GetReturn() << endl;
	}

	cout << "\nInteractive approach..." << endl;
	m_pSolver->SetCallBack(this);
	const CStatus& oStatus2 = m_pSolver->Optimize();
	cout << oStatus2.GetMessage() << endl << endl;
}

/**\brief Utility-Factor Constraint Frontier
*
* In the following Utility-Factor Constraint Frontier problem, we illustrate the effect of varying
* factor bound on the optimal portfolio's utility, specifying a lower bound of 0% and 
* upper bound of 7% exposure to Factor_1A, and 10 data points.
*/
void CTutorialApp::Tutorial_11b()
{
	Initialize( "11b", "Factor Constraint Frontier", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 11b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Create a factor constraint for Factor_1A for the frontier
	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
 	CConstraintInfo& factorCons = linear.SetFactorRange("Factor_1A");

	// Vary exposure to Factor_1A between 0% and 7% with 10 data points
	CFrontier &frontier = m_pCase->InitFrontier(eUTILITY_FACTOR);
	frontier.SetMaxNumDataPoints(10);
	frontier.SetFrontierRange(0.0, 0.07);
	frontier.SetFrontierConstraintID(factorCons.GetID());

	CUtility& util = m_pCase->InitUtility();

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// m_dumpFilename contains all work space data that are useful for debugging
	if ( m_DumpFilename.size() ) m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();
	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;

	CRiskModel *rm = m_pWS->GetRiskModel("GEM");
	const CFrontierOutput *frontierOutput = m_pSolver->GetFrontierOutput();
	for (int i=0; i<frontierOutput->GetNumDataPoints(); i++) {
		const CDataPoint* dataPoint = frontierOutput->GetFrontierDataPoint(i);
	
		cout << "Utility = " << fixed << setprecision(6) << dataPoint->GetUtility() <<
		  "    Risk(%) = " << fixed << setprecision(3) << dataPoint->GetRisk() << 
		  "    Return(%) = " << fixed << setprecision(3) << dataPoint->GetReturn() << endl;
		
		printf("Optimal portfolio exposure to Factor_1A = %.4f\n", dataPoint->GetConstraintSlack());
	}
	cout<<endl;
}

/**\brief Utility-General Linear Constraint Frontier
*
* In the following Utility-General Linear Constraint Frontier problem, we illustrate the effect of varying
* sector exposure on the optimal portfolio's utility, specifying a lower bound of 10% and 
* upper bound of 20% exposure to Information Technology sector, and 10 data points.
*/
void CTutorialApp::Tutorial_11c()
{
	Initialize( "11c", "General Linear Constraint Frontier", true );

	for(int i=0; i<m_pData->m_AssetNum; i++)
	{
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset) {
			// Set GICS Sector attribute
			asset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
		}
	}

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 11c", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set a constraint to GICS_SECTOR - Information Technology
	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
	CConstraintInfo &groupCons = linear.AddGroupConstraint("GICS_SECTOR", "Information Technology");

	// Vary exposure to Information Technology between 10% and 20% with 10 data points
	CFrontier &frontier = m_pCase->InitFrontier(eUTILITY_GENERAL_LINEAR);
	frontier.SetMaxNumDataPoints(10);
	frontier.SetFrontierRange(0.1, 0.2);
	frontier.SetFrontierConstraintID(groupCons.GetID());

	CUtility& util = m_pCase->InitUtility();

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// m_dumpFilename contains all work space data that are useful for debugging
	if ( m_DumpFilename.size() ) m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();
	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;

	const CFrontierOutput *frontierOutput = m_pSolver->GetFrontierOutput();
	for (int i=0; i<frontierOutput->GetNumDataPoints(); i++) {
		const CDataPoint* dataPoint = frontierOutput->GetFrontierDataPoint(i);
	
		cout << "Utility = " << fixed << setprecision(6) << dataPoint->GetUtility() <<
		  "    Risk(%) = " << fixed << setprecision(3) << dataPoint->GetRisk() << 
		  "    Return(%) = " << fixed << setprecision(3) << dataPoint->GetReturn() << endl;
	    printf("Optimal portfolio exposure to Information Technology = %.4f\n", dataPoint->GetConstraintSlack());
	}
	cout<<endl;
}

/**\brief Utility-Leaverage Frontier
*
* In the following Utility-Leverage Frontier problem, we illustrate the effect of varying
* total leverage range, specifying a lower bound of 30% and upper bound of 70%, and 10 data points.
*/
void CTutorialApp::Tutorial_11d()
{
	Initialize( "11d", "Utility-Leaverage Frontier", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 11d", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set hedge settings
	m_pTradeUniverse->AddAsset( "CASH" );		// Cash is required for L/S optimization 
	CHedgeConstraints& hedgeConstr = m_pCase->InitConstraints().InitHedgeConstraints();
	CConstraintInfo& info = hedgeConstr.SetTotalLeverageRange();

	// Vary total leverage range between 30% and 70% with 10 data points
	CFrontier &frontier = m_pCase->InitFrontier(eUTILITY_HEDGE);
	frontier.SetMaxNumDataPoints(10);
	frontier.SetFrontierRange(0.3, 0.7);
	frontier.SetFrontierConstraintID(info.GetID());

	CUtility& util = m_pCase->InitUtility();

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// m_dumpFilename contains all work space data that are useful for debugging
	if ( m_DumpFilename.size() ) m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();
	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;

	const CFrontierOutput *frontierOutput = m_pSolver->GetFrontierOutput();
	if(frontierOutput){
		for (int i=0; i<frontierOutput->GetNumDataPoints(); i++) {
			const CDataPoint* dataPoint = frontierOutput->GetFrontierDataPoint(i);
	
			cout << "Utility = " << fixed << setprecision(6) << dataPoint->GetUtility() <<
  	      "   Total leverage = " << fixed << setprecision(3) << dataPoint->GetConstraintSlack() << endl;
		}
	}else
		cout << "Invalid frontier" << endl;

	cout<<endl;
}

/**\brief Constraint hierarchy
*
* This tutorial illustrates how to set up constraint hierarchy
*/
void CTutorialApp::Tutorial_12a()
{
	Initialize( "12a", "Constraint Hierarchy", true );

	// Create a case object. Set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 12a", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CConstraints &constraints = m_pCase->InitConstraints();

	// Set minimum holding threshold; both for long and short positions
	// in this example 10%
	CParingConstraints &paring = constraints.InitParingConstraints(); 
	paring.AddLevelParing(eMIN_HOLDING_LONG, 0.1);
	paring.AddLevelParing(eMIN_HOLDING_SHORT, 0.1);

	// Set minimum trade size; both for long and short positions
	// in this example 20%
	paring.AddLevelParing(eMIN_TRANX_LONG, 0.2);
	paring.AddLevelParing(eMIN_TRANX_SHORT, 0.2);

	// Set Min # assets to 5, excluding cash and futures
	paring.AddAssetTradeParing(eNUM_ASSETS).SetMin(5);

	// Set Max # trades to 3 
	paring.AddAssetTradeParing(eNUM_TRADES).SetMax(3);

	// Set hedge settings
	m_pTradeUniverse->AddAsset( "CASH" );		// Cash is required for L/S optimization 
	CHedgeConstraints& hedgeConstr = constraints.InitHedgeConstraints();
	CConstraintInfo& conInfo1 = hedgeConstr.SetLongSideLeverageRange();
	conInfo1.SetLowerBound(1.0);
	conInfo1.SetUpperBound(1.1);
	CConstraintInfo& conInfo2 = hedgeConstr.SetShortSideLeverageRange();
	conInfo2.SetLowerBound(-0.3);
	conInfo2.SetUpperBound(-0.3);
	CConstraintInfo& conInfo3 = hedgeConstr.SetTotalLeverageRange();
	conInfo3.SetLowerBound(1.5);
	conInfo3.SetUpperBound(1.5);

	// Set constraint hierarchy
	CConstraintHierarchy& hier = constraints.InitConstraintHierarchy();
	hier.AddConstraintPriority( eASSET_PARING, eFIRST );
	hier.AddConstraintPriority( eHEDGE, eSECOND );

	CUtility& util = m_pCase->InitUtility();

	//
	//constraint retrieval
	//
	//upper & lower bounds
	PrintLowerAndUpperBounds(hedgeConstr);
	//paring constraint
	PrintParingConstraints(paring);
	//constraint hierachy
	PrintConstraintPriority(hier);

	RunOptimize();
}

/** \brief Shortfall Beta Constraint
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* for setting up the shortfall beta constraint.  The shortfall beta data are 
* read from a file that is an output file of BxR example.
*/
void CTutorialApp::Tutorial_14a()
{
	Initialize( "14a", "Shortfall Beta Constraint", true );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 14a", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));
	m_pCase->SetRiskTarget(0.05);

	// Read shortfall beta from a file
	m_pData->ReadShortfallBeta();

	CAttributeSet* attributeSet = m_pWS->CreateAttributeSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		attributeSet->Set( m_pData->m_ID[i], m_pData->m_Shortfall_Beta[i] );
	}

	CLinearConstraints& linearCon = m_pCase->InitConstraints().InitLinearConstraints(); 

	// Add coefficients with shortfall beta data read from file
	CConstraintInfo& oShortfallBetaInfo = linearCon.AddGeneralConstraint(*attributeSet);
	
	// Set lower/upper bounds for shortfall beta
	oShortfallBetaInfo.SetID("ShortfallBetaCon");
	oShortfallBetaInfo.SetLowerBound(0.9);
	oShortfallBetaInfo.SetUpperBound(0.9);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	
	//constraint retrieval
	PrintLowerAndUpperBounds(linearCon);
	printAttributeSet(*linearCon.GetCoefficients("ShortfallBetaCon"), "The Coefficients are:");

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) {
		const CSlackInfo* pSlackInfo = output->GetSlackInfo("ShortfallBetaCon");
		if ( pSlackInfo )
			cout << "Shortfall Beta Con Slack = " << fixed << std::setprecision(4)
				 << pSlackInfo->GetSlackValue() << endl << endl; 
	}
}

/** \brief Minimizing Total Risk from both of primary and secondary risk models
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* for minimizing Total Risk from both of primary and secondary risk models
* and set a constraint for a factor in the secondary risk model.
*/
void CTutorialApp::Tutorial_15a()
{
	// Create WorkSpace and setup Risk Model data,
	// Create initial portfolio, etc; no alpha
	Initialize( "15a", "Minimize Total Risk from 2 Models" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 15a", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Setup Secondary Risk Model 
	SetupRiskModel2();
	CRiskModel *riskModel2 = m_pWS->GetRiskModel("MODEL2");
	m_pCase->SetSecondaryRiskModel(*riskModel2);

	// Set secondary factor range
	CLinearConstraints& linearConstraint = m_pCase->InitConstraints().InitLinearConstraints();
	CConstraintInfo& info = linearConstraint.SetFactorRange("Factor2_2", false);
	info.SetLowerBound(0.00);
	info.SetUpperBound(0.40);

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	// for primary risk model; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	// for secondary risk model; No benchmark
	util.SetSecondaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();

	//m_pSolver->WriteInputToFile(m_pData->m_Datapath + "seconary-factor-range.txt");
}

/** \brief Constrain risk from secondary risk model
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* for constraining risk from secondary risk model
*/
void CTutorialApp::Tutorial_15b()
{
	Initialize( "15b", "Risk Budgeting - Dual Risk Model" );

	// Create a case object, set initial portfolio and trade universe
	CRiskModel *riskModel = m_pWS->GetRiskModel("GEM");
	m_pCase = m_pWS->CreateCase("Case 15b", m_pInitPf, m_pTradeUniverse, 100000, 0.0);
	m_pCase->SetPrimaryRiskModel(*riskModel);

	// Setup Secondary Risk Model 
	SetupRiskModel2();
	CRiskModel *riskModel2 = m_pWS->GetRiskModel("MODEL2");
	m_pCase->SetSecondaryRiskModel(*riskModel2);

	CRiskConstraints& riskConstraint = m_pCase->InitConstraints().InitRiskConstraints();

	// Set total risk from the secondary risk model 
	CConstraintInfo& info = riskConstraint.AddPLTotalConstraint(false, m_pBM2Portfolio);
	info.SetID( "RiskConstraint" );
	info.SetUpperBound(0.1);

	CUtility& util = m_pCase->InitUtility();

	// use primary risk model in the objective
	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
	if ( output ) {
		const CSlackInfo* pSlackInfo = output->GetSlackInfo("RiskConstraint");
		if ( pSlackInfo )
			cout << "Risk Constraint Slack = " << fixed 
				 << pSlackInfo->GetSlackValue() << endl; 
	}
}

/** \brief Risk Parity Constraint
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* to set risk parity constraint.
*/
void CTutorialApp::Tutorial_15c()
{
	// Create WorkSpace and setup Risk Model data,
	// Create initial portfolio, etc; no alpha
	Initialize( "15c", "Risk parity constraint" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 15c", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	// Create set of asset IDs to be included
	CIDSet* ids = m_pWS->CreateIDSet();
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		if (strcmp(m_pData->m_ID[i],"USA11I1") != 0)
			ids->Add(m_pData->m_ID[i]);

	// Set case as long only and set risk parity constraint
	CConstraints& constraints = m_pCase->InitConstraints();
	CLinearConstraints& linConstraint = constraints.InitLinearConstraints();
	linConstraint.SetTransactionType(eSHORT_NONE);
	CRiskConstraints& riskConstraint = constraints.InitRiskConstraints();
	riskConstraint.SetRiskParity(eASSET_RISK_PARITY, ids, true, NULL, false);

	RunOptimize();
}

/** \brief Additional covariance term
*
* This self-documenting sample code illustrates how to specify the
* additional covariance term that is added to the objective function.
* 
*/
void CTutorialApp::Tutorial_16a()
{
	Initialize( "16a", "Additional covariance term - WXFX'W" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 16a", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Setup Secondary Risk Model 
	SetupRiskModel2();
	CRiskModel *riskModel2 = m_pWS->GetRiskModel("MODEL2");
	m_pCase->SetSecondaryRiskModel(*riskModel2);

	// Setup weight matrix
	CAttributeSet* attributeSet = m_pWS->CreateAttributeSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		attributeSet->Set( m_pData->m_ID[i], 1 );
	}

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// Sets the covariance term type = WXFXW with a benchmark and weight matrix, 
	// using secondary risk model
	util.AddCovarianceTerm(0.0075, eWXFXW, m_pBMPortfolio, attributeSet, false);

	RunOptimize();

}

/** \brief Additional covariance term
*
* This self-documenting sample code illustrates how to specify the
* additional covariance term that is added to the objective function.
* 
*/
void CTutorialApp::Tutorial_16b()
{
	Initialize( "16b", "Additional covariance term - XWFWX'" );

	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 16b", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Setup weight matrix
	CAttributeSet* attributeSet = m_pWS->CreateAttributeSet();
	for(int i=0; i<m_pData->m_FactorNum; i++) {
		attributeSet->Set( m_pData->m_Factor[i], 1 );
	}

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	// Sets the covariance term type = XWFWX and the weight matrix
	// using primary risk model
	util.AddCovarianceTerm(0.0075, eXWFWX, NULL, attributeSet); 

	RunOptimize();

}

/** \brief Five-Ten-Forty Rule
*
* This self-documenting sample code illustrates how to apply the 5/10/40 rule
* 
*/
void CTutorialApp::Tutorial_17a()
{
	Initialize( "17a", "Five-Ten-Forty Rule" );

	// Create a case object and trade universe
	m_pCase = m_pWS->CreateCase("Case 17a", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set issuer for each asset
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetIssuer(m_pData->m_Issuer[i]);
	}

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	CConstraints &constraints = m_pCase->InitConstraints();

	C5_10_40Rule &fiveTenFortyRule = constraints.Init5_10_40Rule();
	fiveTenFortyRule.SetRule(5, 10, 40);

	RunOptimize();
}

/** \brief Factor block structure
*
* This self-documenting sample code illustrates how to set up the factor block structure in
* a risk model. 
*/
void CTutorialApp::Tutorial_18()
{
	Initialize( "18", "Factor exposure block" );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 18", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));
	CRiskModel* pRM = m_pWS->GetRiskModel("GEM");

	CIDSet* pGroupA = m_pWS->CreateIDSet();
	pGroupA->Add("Factor_1A");
	pGroupA->Add("Factor_2A");
	pGroupA->Add("Factor_3A");
	pGroupA->Add("Factor_4A");
	pGroupA->Add("Factor_5A");
	pGroupA->Add("Factor_6A");
	pGroupA->Add("Factor_7A");
	pGroupA->Add("Factor_8A");
	pGroupA->Add("Factor_9A");
	pRM->AddFactorBlock("A", *pGroupA);

	CIDSet* pGroupB = m_pWS->CreateIDSet();
	pGroupB->Add("Factor_1B");
	pGroupB->Add("Factor_2B");
	pGroupB->Add("Factor_3B");
	pGroupB->Add("Factor_4B");
	pGroupB->Add("Factor_5B");
	pGroupB->Add("Factor_6B");
	pGroupB->Add("Factor_7B");
	pGroupB->Add("Factor_8B");
	pGroupB->Add("Factor_9B");
	pRM->AddFactorBlock("B", *pGroupB);

	// Set benchmark in utility
	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();
}

/** \brief Load Models Direct risk model data
*
* This self-documenting sample code illustrates how to load Models Direct data into USE4L risk model.
*/
void CTutorialApp::Tutorial_19()
{
	Initialize( "19", "Load risk model using Models Direct files" );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 19", m_pInitPf, m_pTradeUniverse, 100000);

	// Specify the set of assets to load exposures and specific risk for
	CIDSet* idSet = m_pWS->CreateIDSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		idSet->Add(m_pData->m_ID[i]);
	}

	// Create the risk model with the Barra model name
	CRiskModel* pRM = m_pWS->CreateRiskModel("USE4L");

	// Load Models Direct data given location of the files, anaylsis date, and asset set
	ERiskModelStatus status = pRM->LoadModelsDirectData(m_pData->m_Datapath, 20130501, idSet);
	if (status != eSUCCESS) {
		cout << "Failed to load risk model data using Models Direct files" << endl;
		return;
	}
	m_pCase->SetPrimaryRiskModel(*pRM);

	CLinearConstraints &linear = m_pCase->InitConstraints().InitLinearConstraints(); 
 	CConstraintInfo& info = linear.SetFactorRange("USE4L_SIZE");
	info.SetLowerBound(0.02);
	info.SetUpperBound(0.05);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		const CSlackInfo* pSlackInfo = pPfOut->GetSlackInfo( "USE4L_SIZE" );

		if ( pSlackInfo ){
			printf("Optimal portfolio exposure to USE4L_SIZE = %.4f\n", pSlackInfo->GetSlackValue() );
		}
	}
}

/** \brief Change numeraire with Models Direct risk model data
*
* This self-documenting sample code illustrates how to change numeraire with Models Direct data
*/
void CTutorialApp::Tutorial_19b()
{
	Initialize( "19b", "Change numeraire with risk model loaded from Models Direct data", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 19b", m_pInitPf, m_pTradeUniverse, 100000);

	// Specify the set of assets to load exposures and specific risk for
	CIDSet* idSet = m_pWS->CreateIDSet();
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		if(strcmp(m_pData->m_ID[i], "CASH")==0)
			continue;

		idSet->Add(m_pData->m_ID[i]);
	}

	// Create the risk model with the Barra model name
	CRiskModel* pRM = m_pWS->CreateRiskModel("GEM3L");

	// Load Models Direct data given location of the files, anaylsis date, and asset set
	ERiskModelStatus rmStatus = pRM->LoadModelsDirectData(m_pData->m_Datapath, 20131231, idSet);
	if (rmStatus != eSUCCESS) {
		cout << "Failed to load risk model data using Models Direct files" << endl;
		return;
	}

	// Change numeraire to GEM3L_JPNC
	const CStatus& numStatus = pRM->SetNumeraire("GEM3L_JPNC");
	if (numStatus.GetStatusCode() != eOK) {
		cout << numStatus.GetMessage() << endl;
		cout << numStatus.GetAdditionalInfo() << endl;
		return;
	}

	m_pCase->SetPrimaryRiskModel(*pRM);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	RunOptimize();
}

/** \brief Loading asset exposures with CSV file
*
* This self-documenting sample code illustrates how to use Barra Optimizer
* to load asset exposures with CSV file.
*/
void CTutorialApp::Tutorial_20()
{
	cout << "======== Running Tutorial 20 ========" << endl
		 << "Minimize Total Risk" << endl;
	SetupDumpFile ("20");

	// Create a workspace and setup risk model data without asset exposures
	SetupRiskModel(false);

	// Load asset exposures from asset_exposures.csv
	CRiskModel *pRM = m_pWS->GetRiskModel("GEM");
	const CStatus& status = pRM->LoadAssetExposures(m_pData->m_Datapath + "asset_exposures.csv");
	if (status.GetStatusCode() != eOK) {
		cout << "Error loading asset exposures data: "
			 << status.GetMessage() << endl
			 << status.GetAdditionalInfo() << endl;
	}

	// Create initial portfolio etc
	SetupPortfolios();
	
	// Create a case object, null trade universe
	m_pCase = m_pWS->CreateCase("Case 20", m_pInitPf, 0, 100000);
	m_pCase->SetPrimaryRiskModel(*pRM);

	CUtility& util = m_pCase->InitUtility();
	
	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();
}

/** \brief Retrieve constraint & asset KKT attribution terms
*
* This sample code illustrates how to use Barra Optimizer
* to retrieve KKT terms of constraint and asset attributions 
*/
void CTutorialApp::Tutorial_21()
{
	cout << "======== Running Tutorial 21 ========\n"
		 << "Retrieve KKT terms of constraint & asset attributions \n";
	SetupDumpFile ("21");

	// Create a CWorkSpace instance; Release the existing one.
	if ( m_pWS )
		m_pWS->Release();

	m_pWS = CWorkSpace::DeSerialize(m_pData->m_Datapath + "21.wsp");
	m_pSolver = m_pWS->GetSolver(m_pWS->GetSolverIDs().GetFirst());

	RunOptimize(true);

	CollectKKT(cout);
}

/** \brief Multi-period optimization
*
* The sample code illustrates how to set up a multi-period optimization for 2 periods.
*/
void CTutorialApp::Tutorial_22()
{
	Initialize( "22", "Multi-period optimization" );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 22", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set alphas, utility, constraints for period 1
	m_pWS->SwitchPeriod(1);
	for( int i=0; i<m_pData->m_AssetNum; i++ ) {
		 CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		 asset->SetAlpha(m_pData->m_Alpha[i]);
	}
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(1.0);

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// Set constraints
	CLinearConstraints& linearConstraint = m_pCase->InitConstraints().InitLinearConstraints();
	CConstraintInfo& range1 = linearConstraint.SetAssetRange("USA11I1");
	range1.SetLowerBound(0.1);

	
	// Set alphas, utility, constraints for period 2
	m_pWS->SwitchPeriod(2);
	for( int i=0; i<m_pData->m_AssetNum; i++ ) {
		 CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		 asset->SetAlpha(m_pData->m_Alpha[m_pData->m_AssetNum-1-i]);
	}
	// Set utility term
	util.SetAlphaTerm(1.5);

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// Set constraints
	CConstraintInfo& range = linearConstraint.SetAssetRange("USA13Y1");
	range.SetLowerBound(0.2);

	// Set cross-period constraint
	CConstraintInfo& turnoverConstraint = m_pCase->GetConstraints()->InitTurnoverConstraints().SetCrossPeriodNetConstraint();
	turnoverConstraint.SetUpperBound(0.5);
	
	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// Add periods for multi-period optimization
	m_pSolver->AddPeriod(1);
	m_pSolver->AddPeriod(2);

	// dump wsp file
	if ( m_DumpFilename.size() ) 
		m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();

	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;
	
	if( oStatus.GetStatusCode() == BARRAOPT::eOK ) {
		const CMultiPeriodOutput* output = m_pSolver->GetMultiPeriodOutput();
		if ( output ) {
			// Retrieve cross-period output
			const CPortfolioOutput* pCrossPeriodOutput = output->GetCrossPeriodOutput();
			printf("Period      = Cross-period\n");
			printf("Return(%%)   = %.4f\n", pCrossPeriodOutput->GetReturn());
			printf("Utility     = %.4f\n",  pCrossPeriodOutput->GetUtility());
			printf("Turnover(%%) = %.4f\n\n", pCrossPeriodOutput->GetTurnover());

			// Retrieve output for each period
			for (int i=0; i<output->GetNumPeriods(); i++) {
				const CPortfolioOutput* pPeriodOutput = output->GetPeriodOutput(i);
				printf("Period      = %d\n", pPeriodOutput->GetPeriodID());
				printf("Risk(%%)     = %.4f\n", pPeriodOutput->GetRisk());
				printf("Return(%%)   = %.4f\n", pPeriodOutput->GetReturn());
				printf("Utility     = %.4f\n",  pPeriodOutput->GetUtility());
				printf("Turnover(%%) = %.4f\n", pPeriodOutput->GetTurnover());
				printf("Beta        = %.4f\n\n", pPeriodOutput->GetBeta());
			}
		}
	}
}


/** \brief Portfolio concentration constraint
*
* The sample code illustrates how to run an optimization with a portfolio concentration constraint that limits
* the total weight of 5 largest positions to no more than 70% of the portfolio.
*/
void CTutorialApp::Tutorial_23()
{
	Initialize( "23", "Portfolio concentration constraint", true );

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 23", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set portfolio concentration constraint
	CPortConcentrationConstraint& portConcenCons = m_pCase->InitConstraints().SetPortConcentrationConstraint();
	portConcenCons.SetNumTopHoldings(5);
	portConcenCons.SetUpperBound(0.7);

	// Exclude asset USA11I1 from portfolio concentration constraint
	CIDSet* pExcludedAssets = m_pWS->CreateIDSet();
	pExcludedAssets->Add("USA11I1");
	portConcenCons.SetExcludedAssets(pExcludedAssets);

	CUtility& util = m_pCase->InitUtility();

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// Run optimization and display results
	RunOptimize();

	printf("Portfolio conentration=%.4f\n", m_pSolver->Evaluate(ePORTFOLIO_CONCENTRATION, &m_pSolver->GetPortfolioOutput()->GetPortfolio()));
}

/** \brief Multi-account optimization
*
* The sample code illustrates how to set up a multi-account optimization for 2 accounts.
*/
void CTutorialApp::Tutorial_25a()
{
	Initialize( "25a", "Multi-account optimization", true);

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 25a", NULL, m_pTradeUniverse, 1.0e+5);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));
	
// Set cosntraints for each individual accounts

	m_pWS->SwitchAccount(1);
	// Set initial portfolio and base value for account 1
	m_pCase->SetPortBaseValue(1.0e+5);
	m_pCase->SetInitialPort(m_pInitPfs[0]);
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(1.0);

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);

	// Set constraints
	CLinearConstraints& linearConstraint = m_pCase->InitConstraints().InitLinearConstraints();
	CConstraintInfo& range1 = linearConstraint.SetAssetRange("USA11I1");
	range1.SetLowerBound(0.1);

	m_pWS->SwitchAccount(2);
	// set up a different universe for account 2
	CPortfolio* pTradeUniverse2 = m_pWS->CreatePortfolio("Trade Universe 2");	
	for(int i=0; i<m_pData->m_AssetNum-3; i++)
		pTradeUniverse2->AddAsset(m_pData->m_ID[i]);
	m_pCase->SetTradeUniverse(pTradeUniverse2);	

	// Set initial portfolio and base value for account 2
	m_pCase->SetInitialPort(m_pInitPfs[1]);
	m_pCase->SetPortBaseValue(3.0e+5);
	// Set alphas, utility, constraints for account 2
	// Set utility term
	util.SetAlphaTerm(1.5);

	// Set benchmark, risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);

	// Set constraints
	CConstraintInfo& range = linearConstraint.SetAssetRange("USA13Y1");
	range.SetLowerBound(0.2);

// Set constraints for all accounts and/or cross-account

	m_pWS->SwitchAccount(ALL_ACCOUNT);
	// Set joint market impact transaction cost
	util.SetJointMarketImpactTerm(0.5);

	// Set the piecewise linear transaction cost
	CAsset *asset = m_pWS->GetAsset("USA11I1");
	if (asset)
	{
		asset->AddPWLinearBuyCost(0.002833681, 1000.0);
		asset->AddPWLinearBuyCost(0.003833681);
		asset->AddPWLinearSellCost(0.003833681);
	}
	asset = m_pWS->GetAsset("USA13Y1");
	if (asset) {
		asset->AddPWLinearBuyCost(0.00287745);
		asset->AddPWLinearSellCost(0.00387745);
	}
	asset = m_pWS->GetAsset("USA1LI1");
	if (asset)
	{
		asset->AddPWLinearBuyCost(0.00227745);
		asset->AddPWLinearSellCost(0.00327745);
	}

	// Set cross-account constraint
	CConstraintInfo& turnoverConstraint = m_pCase->GetConstraints()->InitCrossAccountConstraints().SetNetTurnoverConstraint();
	// cross-account constraint is specified in actual $ amount as opposed to percentage amount
	// the portfolio base value is the aggregate of base values of all accounts' 
	turnoverConstraint.SetUpperBound(0.5*(1.0e5 + 3.0e5));

	m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// Add accounts for multi-account optimization
	m_pSolver->AddAccount(1);
	m_pSolver->AddAccount(2);

	// dump wsp file
	if ( m_DumpFilename.size() ) 
		m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();

	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;
	
	if( oStatus.GetStatusCode() == BARRAOPT::eOK ) {
		const CMultiAccountOutput* output = m_pSolver->GetMultiAccountOutput();
		if ( output ) {
			// Retrieve cross-account output
			const CPortfolioOutput* pCrossAccountOutput = output->GetCrossAccountOutput();
			printf("Account     = Cross-account\n");
			printf("Return(%%)   = %.4f\n", pCrossAccountOutput->GetReturn());
			printf("Utility     = %.4f\n",  pCrossAccountOutput->GetUtility());
			printf("Turnover(%%) = %.4f\n", pCrossAccountOutput->GetTurnover());
			printf("Joint Market Impact Buy Cost($) = %.4f\n", output->GetJointMarketImpactBuyCost());
			printf("Joint Market Impact Sell Cost($) = %.4f\n\n", output->GetJointMarketImpactSellCost());
			// Retrieve output for each account
			for (int i=0; i<output->GetNumAccounts(); i++) {
				const CPortfolioOutput* pAccountOutput = output->GetAccountOutput(i);
				printf("Account     = %d\n", pAccountOutput->GetAccountID());
				printf("Risk(%%)     = %.4f\n", pAccountOutput->GetRisk());
				printf("Return(%%)   = %.4f\n", pAccountOutput->GetReturn());
				printf("Utility     = %.4f\n",  pAccountOutput->GetUtility());
				printf("Turnover(%%) = %.4f\n", pAccountOutput->GetTurnover());
				printf("Beta        = %.4f\n\n", pAccountOutput->GetBeta());
				/* Output the non-zero weight in the optimized portfolio
				printf("Asset Holdings:\n");
				const CPortfolio &portfolio = pAccountOutput->GetPortfolio();
				const CIDSet& idSet = portfolio.GetAssetIDSet();
				for ( String assetID=idSet.GetFirst(); assetID != ""; 
										  assetID = idSet.GetNext() ) {
					double weight = portfolio.GetAssetWeight(assetID);
					if ( weight != 0. )
						printf("%s: %.4f\n", assetID.c_str(), weight);
				}
				printf("\n");
				*/
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
void CTutorialApp::Tutorial_25b()
{
	Initialize("25b", "Multi-account tax-aware optimization", true, true);

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 25b", NULL, m_pTradeUniverse, 0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Use CMAOTax for tax settings
	CMAOTax& tax = m_pCase->InitMAOTax();
	tax.SetTaxUnit(eDOLLAR);

	// Set cross-account tax limit to $40
	CConstraints& oCons = m_pCase->InitConstraints();
	oCons.InitCrossAccountConstraints().SetTaxLimit().SetUpperBound(40);

	//
	// Account 1
	//
	m_pWS->SwitchAccount(1);
	// Set tax lots, initial portfolio and base value for account 1
	m_pCase->SetInitialPort(m_pInitPfs[0]);
	m_pCase->SetPortBaseValue(m_PfValue[0]);
	// Narrow the trade universe
	CPortfolio* tradeUniverse = m_pWS->CreatePortfolio("Trade Universe 1");
	for (int i = 0; i < 3; i++)
		tradeUniverse->AddAsset(m_pData->m_ID[i]);
	m_pCase->SetTradeUniverse(tradeUniverse);
	// Tax rules
	CTaxRule& taxRule1 = tax.AddTaxRule();
	taxRule1.EnableTwoRate();
	taxRule1.SetTaxRate(0.243, 0.423);
	tax.SetTaxRule("*", "*", taxRule1);
	// Set selling order rule as first in/first out for all assets
	tax.SetSellingOrderRule("*", "*", eFIFO);
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetAlphaTerm(1.0);
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	// Specify long-only
	CLinearConstraints& linearCon = oCons.InitLinearConstraints();
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	// Tax constraints
	CNewTaxConstraints& taxCon = oCons.InitNewTaxConstraints();
	taxCon.SetTaxLotTradingRule("USA13Y1_TaxLot_0", eSELL_LOT);
	taxCon.SetTaxLimit().SetUpperBound(25);

	//
	// Account 2
	//
	m_pWS->SwitchAccount(2);
	m_pCase->SetInitialPort(m_pInitPfs[1]);
	m_pCase->SetPortBaseValue(m_PfValue[1]);
	// Tax rules
	CTaxRule & taxRule2 = tax.AddTaxRule();
	taxRule2.EnableTwoRate();
	taxRule2.SetTaxRate(0.1, 0.2);
	tax.SetTaxRule("*", "*", taxRule2);
	// Set utility term
	util.SetAlphaTerm(1.5);
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);
	// Set constraints
	// long only
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	linearCon.SetAssetRange("USA13Y1").SetUpperBound(0.2);

	// Add accounts for multi-account optimization
	m_pSolver = m_pWS->CreateSolver(*m_pCase);
	m_pSolver->AddAccount(1);
	m_pSolver->AddAccount(2);

	RunOptimize(true);
}

/** \brief Multi-account tax-aware optimization with tax arbitrage
*
*/
void CTutorialApp::Tutorial_25c()
{
	Initialize("25c", "Multi-account optimization with tax arbitrage", true, true);

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 25c", NULL, m_pTradeUniverse, 0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Use CMAOTax for tax settings
	CMAOTax& tax = m_pCase->InitMAOTax();
	tax.SetTaxUnit(eDOLLAR);

	CConstraints& oCons = m_pCase->InitConstraints();

	//
	// Account 1
	//
	m_pWS->SwitchAccount(1);
	// Set tax lots, initial portfolio and base value for account 1
	m_pCase->SetInitialPort(m_pInitPfs[0]);
	m_pCase->SetPortBaseValue(m_PfValue[0]);
	// Tax rules
	CTaxRule& taxRule1 = tax.AddTaxRule();
	taxRule1.EnableTwoRate();
	taxRule1.SetTaxRate(0.243, 0.423);
	tax.SetTaxRule("*", "*", taxRule1);
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	// Specify long-only
	CLinearConstraints& linearCon = oCons.InitLinearConstraints();
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	// Specify minimum $50 long-term capital net gain
	CNewTaxConstraints& taxCon = oCons.InitNewTaxConstraints();
	taxCon.SetTaxArbitrageRange("*", "*", eLONG_TERM, eCAPITAL_NET).SetLowerBound(50.);

	//
	// Account 2
	//
	m_pWS->SwitchAccount(2);
	m_pCase->SetInitialPort(m_pInitPfs[1]);
	m_pCase->SetPortBaseValue(m_PfValue[1]);
	// Tax rules
	CTaxRule & taxRule2 = tax.AddTaxRule();
	taxRule2.EnableTwoRate();
	taxRule2.SetTaxRate(0.1, 0.2);
	tax.SetTaxRule("*", "*", taxRule2);
	// Set utility term
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);
	// Long only
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	// Minimum $100 short-term capital gain
	taxCon.SetTaxArbitrageRange("*", "*", eSHORT_TERM, eCAPITAL_GAIN).SetLowerBound(100.);

	// Add accounts for multi-account optimization
	m_pSolver = m_pWS->CreateSolver(*m_pCase);
	m_pSolver->AddAccount(1);
	m_pSolver->AddAccount(2);

	RunOptimize(true);
}

/** \brief Multi-account tax-aware optimization with tax harvesting
*
*/
void CTutorialApp::Tutorial_25d()
{
	Initialize("25d", "Multi-account optimization with tax harvesting", true, true);

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 25d", NULL, m_pTradeUniverse, 0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Use CMAOTax for tax settings
	CMAOTax& tax = m_pCase->InitMAOTax();
	tax.SetTaxUnit(eDOLLAR);

	CConstraints& oCons = m_pCase->InitConstraints();

	//
	// Account 1
	//
	m_pWS->SwitchAccount(1);
	// Set tax lots, initial portfolio and base value for account 1
	m_pCase->SetInitialPort(m_pInitPfs[0]);
	m_pCase->SetPortBaseValue(m_PfValue[0]);
	// Tax rules
	CTaxRule& taxRule1 = tax.AddTaxRule();
	taxRule1.EnableTwoRate();
	taxRule1.SetTaxRate(0.243, 0.423);
	tax.SetTaxRule("*", "*", taxRule1);
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	// Specify long-only
	CLinearConstraints& linearCon = oCons.InitLinearConstraints();
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	// Target $50 long-term capital net gain
	tax.SetTaxHarvesting("*", "*", eLONG_TERM, 50, 0.1);

	//
	// Account 2
	//
	m_pWS->SwitchAccount(2);
	m_pCase->SetInitialPort(m_pInitPfs[1]);
	m_pCase->SetPortBaseValue(m_PfValue[1]);
	// Tax rules
	CTaxRule & taxRule2 = tax.AddTaxRule();
	taxRule2.EnableTwoRate();
	taxRule2.SetTaxRate(0.1, 0.2);
	tax.SetTaxRule("*", "*", taxRule2);
	// Set utility term
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);
	// Long only
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		linearCon.SetAssetRange(m_pData->m_ID[i]).SetLowerBound(0);
	// Target $100 short-term capital net gain
	tax.SetTaxHarvesting("*", "*", eSHORT_TERM, 100., 0.1);

	// Add accounts for multi-account optimization
	m_pSolver = m_pWS->CreateSolver(*m_pCase);
	m_pSolver->AddAccount(1);
	m_pSolver->AddAccount(2);

	RunOptimize(true);
}

/** \brief Multi-account tax-aware optimization with account groups
*
*/
void CTutorialApp::Tutorial_25e()
{
	Initialize("25e", "Multi-account optimization with account groups", true, true);

	// Create a case object, set initial portfolio and trade universe
	m_pCase = m_pWS->CreateCase("Case 25e", NULL, m_pTradeUniverse, 0);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Use CMAOTax for tax settings
	CMAOTax& tax = m_pCase->InitMAOTax();
	tax.SetTaxUnit(eDOLLAR);

	CConstraints& oCons = m_pCase->InitConstraints();
	CNewTaxConstraints& taxCons = oCons.InitNewTaxConstraints();
	CLinearConstraints& linearCon = oCons.InitLinearConstraints();

	//
	// Account 1
	//
	m_pWS->SwitchAccount(1);
	// Set tax lots, initial portfolio and base value for account 1
	m_pCase->SetInitialPort(m_pInitPfs[0]);
	m_pCase->SetPortBaseValue(m_PfValue[0]);
	// Set tax rules
	CTaxRule& taxRule1 = tax.AddTaxRule();
	taxRule1.EnableTwoRate();
	taxRule1.SetTaxRate(0.243, 0.423);
	tax.SetTaxRule("*", "*", taxRule1);
	// Set utility term
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(m_pBMPortfolio, 0.0075, 0.0075);
	// Specify long-only
	linearCon.SetTransactionType(eSHORT_NONE);
	// Set tax limit to 30$
	CConstraintInfo& info = taxCons.SetTaxLimit();
	info.SetUpperBound(30);

	//
	// Account 2
	//
	m_pWS->SwitchAccount(2);
	m_pCase->SetInitialPort(m_pInitPfs[1]);
	m_pCase->SetPortBaseValue(m_PfValue[1]);
	// Set utility term
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);
	// Long only
	linearCon.SetTransactionType(eSHORT_NONE);

	//
	// Account 3
	//
	m_pWS->SwitchAccount(3);
	m_pCase->SetInitialPort(m_pInitPfs[2]);
	m_pCase->SetPortBaseValue(m_PfValue[2]);
	// Set utility term
	util.SetPrimaryRiskTerm(m_pBM2Portfolio, 0.0075, 0.0075);
	// Long only
	linearCon.SetTransactionType(eSHORT_NONE);

	//
	// Account Group 1
	//

	// Tax rules
	m_pWS->SwitchAccountGroup(1);
	CTaxRule & taxRule2 = tax.AddTaxRule();
	taxRule2.EnableTwoRate();
	taxRule2.SetTaxRate(0.1, 0.2);
	tax.SetTaxRule("*", "*", taxRule2);
	// Joint tax limit for the group is set on the CCrossAccountConstraint object
	CCrossAccountConstraints& crossAcctCons = oCons.InitCrossAccountConstraints();
	crossAcctCons.SetTaxLimit().SetUpperBound(200);

	// Add accounts for multi-account optimization
	m_pSolver = m_pWS->CreateSolver(*m_pCase);
	m_pSolver->AddAccount(1);		// account 1 is stand alone
	m_pSolver->AddAccount(2, 1);	// account 2 and 3 are in account group 1
	m_pSolver->AddAccount(3, 1);

	RunOptimize(true);
}

/** \brief Issuer constraint
*
* This self-documenting sample code illustrates how to set up the optimization with issuer constraints
* 
*/
void CTutorialApp::Tutorial_26()
{
	Initialize( "26", "Issuer Constraint" );

	// Create a case object and trade universe
	m_pCase = m_pWS->CreateCase("Case 26", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set issuer for each asset
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetIssuer(m_pData->m_Issuer[i]);
	}

	CUtility& util = m_pCase->InitUtility();

	// Set risk aversions for specific (lambdaD) and common factor (lambdaF) to 0.0075; No benchmark
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	CConstraints &constraints = m_pCase->InitConstraints();

	CIssuerConstraints& issuerCons = constraints.InitIssuerConstraints();
	// add a global issuer constraint
	CConstraintInfo& infoGlobal = issuerCons.AddHoldingConstraint(eISSUER_NET);
	infoGlobal.SetLowerBound(0.01);
	// add an individual issuer constraint
	CConstraintInfo& infoInd = issuerCons.AddHoldingConstraint(eISSUER_NET, "4");
	infoInd.SetUpperBound(0.3);

	RunOptimize();
}

/** \brief Expected Shortfall Term
*
* The sample code illustrates how to add an expected shortfall term to the utility.
*/
void CTutorialApp::Tutorial_27a()
{
	Initialize("27a", "Expected Shortfall Term");

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 27a", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set expected shortfall data
	CExpectedShortfall& shortfall = m_pCase->InitExpectedShortfall();
	shortfall.SetConfidenceLevel(0.90);
	CAttributeSet* pAttrSet = m_pWS->CreateAttributeSet();
	for (int i = 0; i < m_pData->m_AssetNum; i++)
		pAttrSet->Set(m_pData->m_ID[i], m_pData->m_Alpha[i]);
	shortfall.SetTargetMeanReturns(pAttrSet);
	for (int i = 0; i < m_pData->m_ScenarioNum; i++) {
		for (int j = 0; j < m_pData->m_AssetNum; j++)
			pAttrSet->Set(m_pData->m_ID[j], m_pData->m_ScenarioData[i][j]);
		shortfall.AddScenarioReturns(*pAttrSet);
	}

	// Set utility terms
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);
	util.SetExpectedShortfallTerm(1.0);

	RunOptimize();
}

/** \brief Expected Shortfall Constraint
*
* The sample code illustrates how to set up an expected shortfall constraint.
*/
void CTutorialApp::Tutorial_27b()
{
	Initialize("27b", "Expected Shortfall Constraint");

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 27b", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Set expected shortfall data
	CExpectedShortfall& shortfall = m_pCase->InitExpectedShortfall();
	shortfall.SetConfidenceLevel(0.90);
	shortfall.SetTargetMeanReturns(NULL); // use scenario averages
	CAttributeSet* pAttrSet = m_pWS->CreateAttributeSet();
	for (int i = 0; i < m_pData->m_ScenarioNum; i++) {
		for (int j = 0; j < m_pData->m_AssetNum; j++)
			pAttrSet->Set(m_pData->m_ID[j], m_pData->m_ScenarioData[i][j]);
		shortfall.AddScenarioReturns(*pAttrSet);
	}

	// Set expected shortfall constraint
	CLinearConstraints& linCons = m_pCase->InitConstraints().InitLinearConstraints();
	CConstraintInfo& info = linCons.SetExpectedShortfallConstraint();
	info.SetUpperBound(0.30);

	// Set utility terms
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();
}

/**\brief General Ratio Constraint
*
* This example illustrates how to setup a ratio constraint specifying
* the coefficients.
*/
void CTutorialApp::Tutorial_28a()
{
	Initialize("28a", "General Ratio Constraint");

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 28a", m_pInitPf, m_pTradeUniverse, 100000);
	CRiskModel* pRM = m_pWS->GetRiskModel("GEM");
	m_pCase->SetPrimaryRiskModel(*pRM);

	// Set a constraint on the weighted average of specific variances of the first three assets
	CRatioConstraints& ratioCons = m_pCase->InitConstraints().InitRatioConstraints();
	CAttributeSet* pNumeratorCoeffs = m_pWS->CreateAttributeSet();
	for (int i = 1; i <= 3; i++) {
		String id = m_pData->m_ID[i];
		pNumeratorCoeffs->Set(id, pRM->GetSpecificVar(id, id));
	}
	// the denominator defaults to the sum of weights of the assets of the numerator
	CConstraintInfo& info = ratioCons.AddGeneralConstraint(*pNumeratorCoeffs);
	info.SetLowerBound(0.05);
	info.SetUpperBound(0.1);

	// Set utility terms
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* pOutput = m_pSolver->GetPortfolioOutput();
	if (pOutput) {
		const CSlackInfo* pSlackInfo = pOutput->GetSlackInfo(info.GetID());
		printf("Ratio       = %.4f\n\n", pSlackInfo->GetSlackValue());
	}
}

/**\brief Group Ratio Constraint
*
* This example illustrates how to setup a ratio constraint using asset attributes.
*/
void CTutorialApp::Tutorial_28b()
{
	Initialize("28b", "Group Ratio Constraint");

	// Set up GICS_SECTOR group attribute
	for (int i = 0; i < m_pData->m_AssetNum; i++) {
		CAsset* pAsset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (pAsset) {
			pAsset->SetGroupAttribute("GICS_SECTOR", m_pData->m_GICS_Sector[i]);
		}
	}

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 28b", m_pInitPf, m_pTradeUniverse, 100000);
	m_pCase->SetPrimaryRiskModel(*m_pWS->GetRiskModel("GEM"));

	// Initialize ratio constraints
	CRatioConstraints& ratioCons = m_pCase->InitConstraints().InitRatioConstraints();

	// Weight of "Financials" assets can be at most half of "Information Technology" assets
	CConstraintInfo& info = ratioCons.AddGroupConstraint("GICS_SECTOR","Financials", "GICS_SECTOR", "Information Technology");
	info.SetUpperBound(0.5);

	// Ratio of "Information Technology" to "Minerals" should not differ from the benchmark more than +-10%
	CConstraintInfo& info2 = ratioCons.AddGroupConstraint("GICS_SECTOR", "Minerals", "GICS_SECTOR", "Information Technology");
	info2.SetReference(m_pBMPortfolio);
	info2.SetLowerBound(-0.1, ePLUS);
	info2.SetUpperBound(0.1, ePLUS);

	// Set utility terms
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();

	const CPortfolioOutput* pOutput = m_pSolver->GetPortfolioOutput();
	if (pOutput) {
		const CSlackInfo* pSlackInfo = pOutput->GetSlackInfo(info.GetID());
		printf("Financials / IT = %.4f\n", pSlackInfo->GetSlackValue());
		pSlackInfo = pOutput->GetSlackInfo(info2.GetID());
		printf("Minerals / IT   = %.4f\n\n", pSlackInfo->GetSlackValue());
	}
}

/**\brief General Quadratic Constraint
*
* This example illustrates how to setup a general quadratic constraint.
*/
void CTutorialApp::Tutorial_29()
{
	Initialize("29", "General Quadratic Constraint");

	// Create a case object
	m_pCase = m_pWS->CreateCase("Case 29", m_pInitPf, m_pTradeUniverse, 100000);
	CRiskModel* pRM = m_pWS->GetRiskModel("GEM");
	m_pCase->SetPrimaryRiskModel(*pRM);

	// Initialize quadratic constraints
	CQuadraticConstraints& quadraticCons =
		m_pCase->InitConstraints().InitQuadraticConstraints();

	// Create the Q matrix and set some elements
	CSymmetricMatrix* Q_mat = m_pWS->CreateSymmetricMatrix(3);

	Q_mat->SetElement(m_pData->m_ID[1], m_pData->m_ID[1], 0.92473646);
	Q_mat->SetElement(m_pData->m_ID[2], m_pData->m_ID[2], 0.60338704);
	Q_mat->SetElement(m_pData->m_ID[2], m_pData->m_ID[3], 0.38904854);
	Q_mat->SetElement(m_pData->m_ID[3], m_pData->m_ID[3], 0.63569677);

	// The Q matrix must be positive semidefinite
	const bool is_positive_semidefinite = Q_mat->IsPositiveSemidefinite();

	// Create the q vector and set some elements
	CAttributeSet* q_vect = m_pWS->CreateAttributeSet();
	for (int i = 1; i < 6; i++) {
		q_vect->Set(m_pData->m_ID[i], 0.1);
	}

	// Add the constraint and set an upper bound
	CConstraintInfo& info = quadraticCons.AddConstraint(*Q_mat,  // Q matrix
		q_vect,  // q vector
		NULL);  // benchmark
	info.SetUpperBound(0.1);

	// Set utility terms
	CUtility& util = m_pCase->InitUtility();
	util.SetPrimaryRiskTerm(NULL, 0.0075, 0.0075);

	RunOptimize();
}

void CTutorialApp::ParseCommandLine(int argc, char *argv[])
{
	bool dump = false;
	for (int i=1; i<argc; i++) {
		string arg = argv[i];
		if (arg == "-d"){ 
			dump = true;
			DumpAll(true);
		}else if(arg[0]=='-'){
			dump=false;
			if (arg == "-c") 
				SetCompatibleMode(true);
		}else if(dump)
			// Set up workspace dumping, if any
			m_DumpTID.insert(arg);
	}
	if( m_DumpTID.size()>0 )
		DumpAll(false);
}

void CTutorialApp::printRisksByAsset(const CPortfolio& portfolio)
{
	const CIDSet& assetIDs = portfolio.GetAssetIDSet();

	// copy assetIDs for safe iteration (calling EvaluateRisk() might invalidate iterators)
	CIDSet* pIDs = m_pWS->CreateIDSet();
	for (String id = assetIDs.GetFirst(); id != ""; id = assetIDs.GetNext())
		pIDs->Add(id);

	for (String id = pIDs->GetFirst(); id != ""; id = pIDs->GetNext()) {
		CIDSet* pid = m_pWS->CreateIDSet();
		pid->Add(id);
		double risk = m_pSolver->EvaluateRisk(portfolio, eTOTALRISK, NULL, pid, NULL, true, true);
		if (risk != 0.)
			printf("Risk from %s = %.4f\n", id.c_str(), risk);
		pid->Release();
	}
	pIDs->Release();
}

/** \brief print upper & lower bound of linear constraints
 *
 * This self-documenting sample code illustrates how to retrieve linear constraints
 * one can apply the same methods to hedge constraints, turnover constraints & risk constraints
 */
void CTutorialApp::PrintLowerAndUpperBounds(CLinearConstraints& cons)
{
	const CIDSet* pid = cons.GetConstraintIDSet();
	String cid = pid->GetFirst();
	cout<<std::fixed;
	for(int i=0; i<pid->GetCount(); i++, cid=pid->GetNext()){
		const CConstraintInfo* infoptr = cons.GetConstraintInfo(cid);
		cout<<"constraint ID: "<<infoptr->GetID()<<endl
			<<"lower bound: "<<std::setprecision(2)<<infoptr->GetLowerBound()
			<<", upper bound: "<<std::setprecision(2)<<infoptr->GetUpperBound()
			<<endl;
	}
}

/** \brief print upper & lower bound of hedge constraints
*
* This self-documenting sample code illustrates how to retrieve hedge constraints
* one can apply the same methods to linear constraints, turnover constraints & risk constraints
*/
void CTutorialApp::PrintLowerAndUpperBounds(CHedgeConstraints& cons)
{
	const CIDSet* pid = cons.GetConstraintIDSet();
	String cid = pid->GetFirst();
	cout<<std::fixed;
	for(int i=0; i<pid->GetCount(); i++, cid=pid->GetNext()){
		const CConstraintInfo* infoptr = cons.GetConstraintInfo(cid);
		cout<<"constraint ID: "<<infoptr->GetID()<<endl
			<<"lower bound: "<<std::setprecision(2)<<infoptr->GetLowerBound()
			<<", upper bound: "<<std::setprecision(2)<<infoptr->GetUpperBound()
			<<endl;
	}
}

/** \brief print some paring constraints
*
* This self-documenting sample code illustrates how to retrieve paring constraints
*/
void CTutorialApp::PrintParingConstraints(const CParingConstraints& paring)
{
	//tailored for tutorial 12a
	if( paring.ExistsAssetTradeParingType(eNUM_ASSETS) )
		cout<<"Minimum number of assets is: "
			<<paring.GetAssetTradeParingRange(eNUM_ASSETS)->GetMin()<<endl;
	if( paring.ExistsAssetTradeParingType(eNUM_TRADES) )
		cout<<"Maximum number of trades is: "
			<<paring.GetAssetTradeParingRange(eNUM_TRADES)->GetMax()<<endl;

	for(int lp = eMIN_HOLDING_LONG; lp<=eMIN_TRANX_SHORT; lp++){
		if( paring.ExistsLevelParingType((ELevelParingType)lp) ){
			switch(lp){
				case eMIN_HOLDING_LONG:
					cout<<"Min holding (long) threshold is: ";
					break;
				case eMIN_HOLDING_SHORT:
					cout<<"Min holding (short) threshold is: ";
					break;
				case eMIN_TRANX_LONG:
					cout<<"Min transaction (long) threshold is: ";
					break;
				case eMIN_TRANX_SHORT:
					cout<<"Min transaction (short) threshold is: ";
					break;
				case eMIN_TRANX_BUY:
					cout<<"Min transaction (buy) threshold is: ";
					break;
				case eMIN_TRANX_SELL:
					cout<<"Min transaction (sell) threshold is: ";
					break;
			}
			cout<<paring.GetThreshold((ELevelParingType)lp)<<endl;
		}
	}
	cout<<endl;
}

/** \brief print constraint priority
*
* This self-documenting sample code illustrates how to retrieve constraint hierachy
*/
void CTutorialApp::PrintConstraintPriority(const CConstraintHierarchy& hier)
{	
    ECategory cate[] = {
	    eLINEAR,
	    eFACTOR,
	    eTURNOVER,
	    eTRANSACTIONCOST,
	    eHEDGE,
	    ePARING,
	    eASSET_PARING,
	    eHOLDING_LEVEL_PARING,
	    eTRANXSIZE_LEVEL_PARING,
	    eTRADE_PARING,
	    eRISK,
	    eROUNDLOTTING
    };

    String cate_string[] = {
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
		if( hier.ExistsCategoryPriority(cate[i]) ){
			ERelaxOrder order = hier.GetPriorityForConstraintCategory(cate[i]);
			cout<<"The category priority for "<<cate_string[i];

			if (order == eFIRST)
				cout<<" is the first";
			else if (order == eSECOND)
				cout<<" is the second";
			else if (order == eLAST)
				cout<<" is the last";

			cout<<endl;
		}
	cout<<endl;
}
