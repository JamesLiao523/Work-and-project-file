/** @file TutorialBase.cpp
* \brief Contains definitions of the CTutorialBase class with
* the shared routines for all tutorials.
*/

#include <cstdio>
#include <cstring>
#include <iostream>
#include <sstream>

#include "TutorialBase.h"

using namespace BARRAOPT;
using namespace std;

CTutorialBase::CTutorialBase(CTutorialData* data) :
	m_pWS(NULL),
	m_pCase(NULL),
	m_pSolver(NULL),
	m_pData(data), 
	m_CompatibleMode(false),
	m_DumpAll(false)
{
}

CTutorialBase::~CTutorialBase()
{
	if ( m_pWS )
		m_pWS->Release();
}

/// Initialize the optimization
void CTutorialBase::Initialize( const char* tutorialID, const char* description, bool dumpWS, bool setAlpha, bool isTaxAware)
{
	cout.precision(4);

	cout << "======== Running Tutorial " << tutorialID << " ========" << endl
		 << description << endl;

	// Create a workspace and setup risk model data
	SetupRiskModel();

	// Create initial portfolio etc
	SetupPortfolios();

	if ( setAlpha )
		SetAlpha();
	
	if (isTaxAware) {
		SetPrice();
		SetupTaxLots();
	}

	SetupDumpFile (tutorialID, dumpWS);
}


// set up workspace dumping file
void CTutorialBase::SetupDumpFile(const char* tutorialID, bool dumpWS)
{
	if ( m_DumpAll || dumpWS ){
		m_DumpFilename = "opsdata_"; 
		m_DumpFilename += tutorialID;
		m_DumpFilename += ".wsp";
	}else 
		m_DumpFilename.clear();
}

/** Create a workspace and setup risk model data
*/
void CTutorialBase::SetupRiskModel(bool setExposures)
{
	// Create a CWorkSpace instance; Release the existing one.
	if ( m_pWS )
		m_pWS->Release();
	m_pWS = CWorkSpace::CreateInstance();

	// Add assets into the workspace
	CAsset* aAsset[CTutorialData::m_AssetNum];
	for( int i = 0; i<m_pData->m_AssetNum; i++ ) {
		if ( strcmp(m_pData->m_ID[i], "CASH")==0 )
			aAsset[i] = m_pWS->CreateAsset(m_pData->m_ID[i], eCASH);
		else
			aAsset[i] = m_pWS->CreateAsset(m_pData->m_ID[i], eREGULAR);
	}

	// Create a risk model
	CRiskModel* pRM = m_pWS->CreateRiskModel("GEM", eEQUITY);

	// Load the covariance matrix from the CTutorialData object
	int count = 0;
	for ( int i=0; i<m_pData->m_FactorNum; i++ ) {
		for ( int j=0; j<=i; j++ ) {
			pRM->SetFactorCovariance( m_pData->m_Factor[i], 
				m_pData->m_Factor[j], m_pData->m_CovData[count++] );
		}
	}

	if (setExposures) {
		// Load the exposure matrix from the CTutorialData object
		CAttributeSet* pExposureSet;
		for ( int i=0; i<m_pData->m_AssetNum; i++ ) {
			pExposureSet = m_pWS->CreateAttributeSet();
			for(int j=0; j<m_pData->m_FactorNum; j++) {
				pExposureSet->Set(m_pData->m_Factor[j], m_pData->m_ExpData[i][j]);
			}
			pRM->SetFactorExposureBySet(m_pData->m_ID[i], *pExposureSet); 
		}
	}

	// Load specific risk covariance
	for(int i=0; i<m_pData->m_AssetNum; i++) {
		pRM->SetSpecificCovariance(m_pData->m_ID[i], m_pData->m_ID[i], m_pData->m_SpCov[i]);
	}
}

/** Setup a simple sample secondary risk model
*/
void CTutorialBase::SetupRiskModel2()
{
	// Create a risk model
	CRiskModel* pRM = m_pWS->CreateRiskModel("MODEL2", eEQUITY);

	// Set factor covariances 
	pRM->SetFactorCovariance( "Factor2_1", "Factor2_1", 1.0 );
	pRM->SetFactorCovariance( "Factor2_1", "Factor2_2", 0.1 );
	pRM->SetFactorCovariance( "Factor2_2", "Factor2_2", 0.5 );

	// Set factor exposures 
	for ( int i=0; i<m_pData->m_AssetNum; i++ ) {
		pRM->SetFactorExposure( m_pData->m_ID[i], "Factor2_1", double(i)/m_pData->m_AssetNum );
		pRM->SetFactorExposure( m_pData->m_ID[i], "Factor2_2", double(2*i)/m_pData->m_AssetNum );
	}

	// Set specific risk covariance
	for ( int i=0; i<m_pData->m_AssetNum; i++ ) {
		pRM->SetSpecificCovariance( m_pData->m_ID[i], m_pData->m_ID[i], 0.05 );
	}
}

/** Setup initial portfolio, benchmarks and trade universe
*/
void CTutorialBase::SetupPortfolios()
{
	// Create an initial portfolio with no cash
	for ( int iAccount = 0; iAccount < m_pData->m_AccountNum; iAccount++ ) {
		stringstream out;
		out << iAccount + 1;
		String id = "Initial Portfolio" + (iAccount == 0 ? "" : out.str());
		m_pInitPfs[iAccount] = m_pWS->CreatePortfolio(id);
		for (int iAsset = 0; iAsset < m_pData->m_AssetNum; iAsset++) {
			if (m_pData->m_InitWeight[iAccount][iAsset] != 0.0) {
				m_pInitPfs[iAccount]->AddAsset(m_pData->m_ID[iAsset], m_pData->m_InitWeight[iAccount][iAsset]);
			}
		}
	}
	m_pInitPf = m_pInitPfs[0];

	m_pBMPortfolio = m_pWS->CreatePortfolio("Benchmark");	
	m_pBM2Portfolio = m_pWS->CreatePortfolio("Benchmark2");	
	m_pTradeUniverse = m_pWS->CreatePortfolio("Trade Universe");	
 
	for( int i = 0; i<m_pData->m_AssetNum; i++)	{
		if(strcmp(m_pData->m_ID[i], "CASH")!=0) {
			// no need to specify weight for assets in trade universe
			m_pTradeUniverse->AddAsset(m_pData->m_ID[i]);

			if (m_pData->m_BMWeight[i] != 0.0)
				m_pBMPortfolio->AddAsset(m_pData->m_ID[i], m_pData->m_BMWeight[i]);

			if (m_pData->m_BM2Weight[i] != 0)
				m_pBM2Portfolio->AddAsset(m_pData->m_ID[i], m_pData->m_BM2Weight[i]);	
		}
	}
}

/** Setup tax lots and recalculate asset weights
*/
void CTutorialBase::SetupTaxLots() {

	// Add tax lots into the portfolio, compute asset values
	double assetValue[CTutorialData::m_AccountNum][CTutorialData::m_AssetNum];
	for (int i = 0; i < CTutorialData::m_AccountNum; i++)
		for (int j = 0; j < CTutorialData::m_AssetNum; j++)
			assetValue[i][j] = 0;
	for (int j = 0; j < m_pData->m_Taxlots; j++) {
		int iAccount = m_pData->m_Account[j];
		int iAsset = m_pData->m_Indices[j];
		CPortfolio* pInitPf = m_pInitPfs[iAccount];
		pInitPf->AddTaxLot(m_pData->m_ID[iAsset], m_pData->m_Age[j],
			m_pData->m_CostBasis[j], m_pData->m_Shares[j], false);
		assetValue[iAccount][iAsset] += m_pData->m_Price[iAsset] * m_pData->m_Shares[j];
	}

	// set portfolio values
	for (int i = 0; i < CTutorialData::m_AccountNum; i++) {
		m_PfValue[i] = 0;
		for (int j = 0; j < CTutorialData::m_AssetNum; j++)
			m_PfValue[i] += assetValue[i][j];
	}

	// Reset asset initial weights based on tax lot information
	for (int i = 0; i < m_pData->m_AccountNum; i++) {
		CPortfolio* pInitPf = m_pInitPfs[i];
		for (int j = 0; j < m_pData->m_AssetNum; j++)
			pInitPf->AddAsset(m_pData->m_ID[j], assetValue[i][j] / m_PfValue[i]);
	}
}

/** Calculate portfolio weights and values from tax lot data.
*/
void CTutorialBase::UpdatePortfolioWeights() {
	for (int iAccount = 0; iAccount < m_pData->m_AccountNum; iAccount++) {
		CPortfolio* pInitPf = m_pInitPfs[iAccount];
		if (pInitPf) {
			m_PfValue[iAccount] = 0.0;
			double assetValue[CTutorialData::m_AssetNum];
			const CIDSet& oTaxLotIDs = pInitPf->GetTaxLotIDs();
			for (int iAsset = 0; iAsset < m_pData->m_AssetNum; iAsset++) {
				String assetID = m_pData->m_ID[iAsset];
				double price = m_pData->m_Price[iAsset];
				assetValue[iAsset] = 0.0;
				for (String lotID = oTaxLotIDs.GetFirst(); lotID != ""; lotID = oTaxLotIDs.GetNext()) {
					const CTaxLot* pLot = pInitPf->GetTaxLot(lotID);
					if (pLot->GetAssetID() == assetID) {
						double value = pLot->GetShares() * price;
						m_PfValue[iAccount] += value;
						assetValue[iAsset] += value;
					}
				}
			}

			for (int iAsset = 0; iAsset < m_pData->m_AssetNum; iAsset++) {
				pInitPf->AddAsset(m_pData->m_ID[iAsset], assetValue[iAsset] / m_PfValue[iAccount]);
			}
		}
	}
}

/** Set the expected return for each asset in the model
*/
void CTutorialBase::SetAlpha()
{
	// Set the expected return for each asset
	for( int i=0; i<m_pData->m_AssetNum; i++ ) {
		 CAsset *asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		 if ( asset )
			 asset->SetAlpha(m_pData->m_Alpha[i]);
	}
}

/** Set the price for each asset in the model
*/
void CTutorialBase::SetPrice()
{
	for (int i=0; i<m_pData->m_AssetNum; i++) {
		CAsset* asset = m_pWS->GetAsset(m_pData->m_ID[i]);
		if (asset)
			asset->SetPrice(m_pData->m_Price[i]);
	}
}

/** Run optimization
* @param useOldSolver If True, use the eixisting m_pSolver pointer without recreate a new solver.
*/
void CTutorialBase::RunOptimize( bool useOldSolver, bool estUtilUB )
{
	if ( !useOldSolver )
		m_pSolver = m_pWS->CreateSolver(*m_pCase);

	// set compatible mode
	if( m_CompatibleMode ) 
		m_pSolver->SetOption( "COMPATIBLE_MODE", 1);

	// estimate upperbound on utility
	if( estUtilUB ) 
		m_pSolver->SetOption( "REPORT_UPPERBOUND_ON_UTILITY", 1);

	// m_dumpFilename contains all work space data that are useful for debugging
	if ( m_DumpFilename.size() ) m_pWS->Serialize(m_DumpFilename);

	const CStatus& oStatus = m_pSolver->Optimize();

	cout << oStatus.GetMessage() << endl
		 << m_pSolver->GetLogMessage() << endl;
	
	if( oStatus.GetStatusCode() == BARRAOPT::eOK ) {        
		const CPortfolioOutput* output = m_pSolver->GetPortfolioOutput();
		const CMultiAccountOutput* maOutput = m_pSolver->GetMultiAccountOutput();
		const CMultiPeriodOutput* mpOutput = m_pSolver->GetMultiPeriodOutput();
		if (output)
			PrintPortfolioOutput(output, estUtilUB);
		else if (maOutput)
			PrintMultiAccountOutput(maOutput);
		else if (mpOutput)
			PrintMultiPeriodOutput(mpOutput);
	}else if( oStatus.GetStatusCode() == BARRAOPT::eLICENSE_ERROR ) 
		throw BARRAOPT::eLICENSE_ERROR;
}

void CTutorialBase::PrintPortfolioOutput(const CPortfolioOutput* output, bool estUtilUB) {
	printf("Optimized Portfolio:\n");
	printf("Risk(%%)     = %.4f\n", output->GetRisk());
	printf("Return(%%)   = %.4f\n", output->GetReturn());
	printf("Utility     = %.4f\n", output->GetUtility());
	if (estUtilUB) {
		double utilUB = output->GetUpperBoundOnUtility();
		if (utilUB != OPT_NAN)
			printf("Util. Upperbound = %.4f\n", utilUB);
	};
	printf("Turnover(%%) = %.4f\n", output->GetTurnover());
	printf("Penalty     = %.4f\n", output->GetPenalty());
	printf("TranxCost(%%)= %.4f\n", output->GetTransactioncost());
	printf("Beta        = %.4f\n", output->GetBeta());
	if (output->GetExpectedShortfall() != OPT_NAN)
		printf("ExpShortfall(%%)= %.4f\n", output->GetExpectedShortfall());
	printf("\n");

	// Output the non-zero weight in the optimized portfolio
	printf("Asset Holdings:\n");
	const CPortfolio &portfolio = output->GetPortfolio();
	const CIDSet& idSet = portfolio.GetAssetIDSet();
	for (String assetID = idSet.GetFirst(); assetID != "";
		assetID = idSet.GetNext()) {
		double weight = portfolio.GetAssetWeight(assetID);
		if (weight != 0.)
			printf("%s: %.4f\n", assetID.c_str(), weight);
	}

	cout << endl;
}

void CTutorialBase::PrintMultiAccountOutput(const CMultiAccountOutput* output)
{
	// Retrieve cross-account output
	const CPortfolioOutput* pCrossAccountOutput = output->GetCrossAccountOutput();
	const CCrossAccountTaxOutput* pCrossAccountTaxOutput = output->GetCrossAccountTaxOutput();
	printf("Account     = Cross-account\n");
	printf("Return(%%)   = %.4f\n", pCrossAccountOutput->GetReturn());
	printf("Utility     = %.4f\n", pCrossAccountOutput->GetUtility());
	printf("Turnover(%%) = %.4f\n", pCrossAccountOutput->GetTurnover());
	double jointMarketImpactBuyCost = output->GetJointMarketImpactBuyCost();
	if (jointMarketImpactBuyCost != OPT_NAN)
		printf("Joint Market Impact Buy Cost($) = %.4f\n", jointMarketImpactBuyCost);
	double jointMarketImpactSellCost = output->GetJointMarketImpactSellCost();
	if (jointMarketImpactSellCost != OPT_NAN)
		printf("Joint Market Impact Sell Cost($) = %.4f\n", jointMarketImpactSellCost);
	if (pCrossAccountTaxOutput)
		printf("Total Tax   = %.4f\n", pCrossAccountTaxOutput->GetTotalTax());
	cout << endl;

	// Retrieve output for each account group
	if (output->GetNumAccountGroups() > 0) {
		for (int i = 0; i < output->GetNumAccountGroups(); i++) {
			const CAccountGroupTaxOutput* pGroupOutput = output->GetAccountGroupTaxOutput(i);
			printf("Account Group = %d\n", pGroupOutput->GetAccountGroupID());
			printf("Total Tax     = %.4f\n", pGroupOutput->GetTotalTax());
		}
		cout << endl;
	}

	// Retrieve output for each account
	for (int i = 0; i < output->GetNumAccounts(); i++) {
		const CPortfolioOutput* pAccountOutput = output->GetAccountOutput(i);
		Int32 accountID = pAccountOutput->GetAccountID();

		printf("Account     = %d\n", accountID);
		printf("Risk(%%)     = %.4f\n", pAccountOutput->GetRisk());
		printf("Return(%%)   = %.4f\n", pAccountOutput->GetReturn());
		printf("Utility     = %.4f\n", pAccountOutput->GetUtility());
		printf("Turnover(%%) = %.4f\n", pAccountOutput->GetTurnover());
		printf("Beta        = %.4f\n", pAccountOutput->GetBeta());

		printf("\nAsset Holdings:\n");
		const CPortfolio &portfolio = pAccountOutput->GetPortfolio();
		const CIDSet& idSet = portfolio.GetAssetIDSet();
		for (String assetID = idSet.GetFirst(); assetID != "";
			assetID = idSet.GetNext()) {
			double weight = portfolio.GetAssetWeight(assetID);
			if (weight != 0.)
				printf("%s: %.4f\n", assetID.c_str(), weight);
		}

		const CNewTaxOutput* taxOut = pAccountOutput->GetNewTaxOutput();
		if (taxOut) {
			if (GetAccountGroupID(accountID) == -1) {
				double ltax = taxOut->GetLongTermTax("*", "*");
				double stax = taxOut->GetShortTermTax("*", "*");
				double lgg_all = taxOut->GetCapitalGain("*", "*", eLONG_TERM, eCAPITAL_GAIN);
				double lgl_all = taxOut->GetCapitalGain("*", "*", eLONG_TERM, eCAPITAL_LOSS);
				double sgg_all = taxOut->GetCapitalGain("*", "*", eSHORT_TERM, eCAPITAL_GAIN);
				double sgl_all = taxOut->GetCapitalGain("*", "*", eSHORT_TERM, eCAPITAL_LOSS);

				cout << "\nTax info for the tax rule group(all assets):\n";
				printf("Long Term Gain = %.4f\n", lgg_all);
				printf("Long Term Loss = %.4f\n", lgl_all);
				printf("Short Term Gain = %.4f\n", sgg_all);
				printf("Short Term Loss = %.4f\n", sgl_all);
				printf("Long Term Tax  = %.4f\n", ltax);
				printf("Short Term Tax = %.4f\n", stax);

				printf("\nTotal Tax(for all tax rule groups) = %.4f\n\n", taxOut->GetTotalTax());
			}

			const CPortfolio &portfolio = pAccountOutput->GetPortfolio();
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

void CTutorialBase::PrintMultiPeriodOutput(const CMultiPeriodOutput* output)
{
	// Retrieve cross-period output
	const CPortfolioOutput* pCrossPeriodOutput = output->GetCrossPeriodOutput();
	printf("Period      = Cross-period\n");
	printf("Return(%%)   = %.4f\n", pCrossPeriodOutput->GetReturn());
	printf("Utility     = %.4f\n", pCrossPeriodOutput->GetUtility());
	printf("Turnover(%%) = %.4f\n\n", pCrossPeriodOutput->GetTurnover());

	// Retrieve output for each period
	for (int i = 0; i < output->GetNumPeriods(); i++) {
		const CPortfolioOutput* pPeriodOutput = output->GetPeriodOutput(i);
		printf("Period      = %d\n", pPeriodOutput->GetPeriodID());
		printf("Risk(%%)     = %.4f\n", pPeriodOutput->GetRisk());
		printf("Return(%%)   = %.4f\n", pPeriodOutput->GetReturn());
		printf("Utility     = %.4f\n", pPeriodOutput->GetUtility());
		printf("Turnover(%%) = %.4f\n", pPeriodOutput->GetTurnover());
		printf("Beta        = %.4f\n\n", pPeriodOutput->GetBeta());
	}
}

void CTutorialBase::printAttributeSet(const CAttributeSet& oAttSet, String title)
{
	const CIDSet& oIDSet = oAttSet.GetKeySet();
	String id = oIDSet.GetFirst();

	if (!id.empty()) {
		cout << title << endl;

		while (!id.empty()) {
			printf("%s: %.4f\n", id.c_str(), oAttSet.GetValue(id));
			id = oIDSet.GetNext();
		}
	}
}


/** Output trade list
* @param isOptimalPortfolio If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
*/
void CTutorialBase::OutputTradeList( bool isOptimalPortfolio )
{
	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut ) {
		CIDSet* pOddLotIDs = m_pWS->CreateIDSet();
		const CPortfolio* portfolio = isOptimalPortfolio ? &pPfOut->GetPortfolio() : pPfOut->GetRoundlottedPortfolio(*pOddLotIDs);
		if ( portfolio )
		{
			// Output the non-zero weight in the optimized portfolio
			if (isOptimalPortfolio)
				printf("Optimal Portfolio:\n");
			else
				printf("Roundlotted Portfolio:\n");
			printf("Asset Holdings:\n");
			const CIDSet& idSet = portfolio->GetAssetIDSet();
			for ( String assetID=idSet.GetFirst(); assetID != ""; 
									  assetID = idSet.GetNext() ) {
				double weight = portfolio->GetAssetWeight(assetID);
				if ( weight != 0. )
					printf("%s: %.4f\n", assetID.c_str(), weight);
			}
			cout << endl; 

			printf("Trade List:\n");
			printf("Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%%), Transaction Cost, Trade Type\n");
			for ( String assetID=idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext() ) 
			{
			  	if(!strcmp(assetID.c_str(), "CASH")) continue;
				const CAssetTradeListInfo *pTradeListInfo = pPfOut->GetAssetTradeListInfo(assetID, isOptimalPortfolio);
				double initialShares	= pTradeListInfo->GetInitialShares();
				double finalShares		= pTradeListInfo->GetFinalShares();
				double tradedShares		= pTradeListInfo->GetTradedShares();
				ETradeType tradeType	= pTradeListInfo->GetTradeType();
				double price			= pTradeListInfo->GetPrice();
				double tradedValue		= pTradeListInfo->GetTradedValue();
				double tradedValuePct	= pTradeListInfo->GetTradedValuePcnt();
				double transactionCost	= pTradeListInfo->GetTotalTransactionCost();
				
				String tradeTypeStr;
				switch (tradeType)
				{
					case eHOLD:
						tradeTypeStr = "Hold";
						break;
					case eBUY:
						tradeTypeStr = "Buy";
						break;
					case eSELL:
						tradeTypeStr = "Sell";
						break;
					case eCOVER_BUY:
						tradeTypeStr = "Cover Buy";
						break;
					case eSHORT_SELL:
						tradeTypeStr = "Short Sell";
						break;
					case eCROSSOVER_BUY:
						tradeTypeStr = "Crossover Buy";
						break;
					case eCROSSOVER_SELL:
						tradeTypeStr = "Crossover Sell";
						break;
				}

				printf("%s: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %s\n", assetID.c_str(), initialShares, finalShares, tradedShares,
					price, tradedValue, tradedValuePct, transactionCost, tradeTypeStr.c_str());
			}
			cout << endl; 
		}
	}
}

Int32 CTutorialBase::GetAccountGroupID(Int32 accountID)
{
	if (m_pSolver) {
		for (int i = 0; i < m_pSolver->GetNumAccounts(); i++) {
			const CAccount* pAccount = m_pSolver->GetAccount(i);
			if (pAccount->GetID() == accountID)
				return pAccount->GetGroupID();
		}
	}
	return -1;
}

/** Callback function for handling data points generated during the efficient 
* frontier optimization
* @param oDataPt  A data point on the efficient frontier
*/
bool CTutorialBase::OnDataPoint(CDataPoint& oDataPt)
{
	cout << "Risk(%) = " << oDataPt.GetRisk() << "    Return(%) = " << oDataPt.GetReturn() << endl;

	return false;
}

/** Callback function for handling messages generated during efficient frontier optimization
@param oMessage  A message generated by the optimizer
*/
bool CTutorialBase::OnMessage(CMessage& oMessage)
{
	cout << "Message: " << oMessage.GetMessage() << endl;

	return false;
}


void CTutorialBase::CollectKKT(ostream& os, double multiplier)
{
	const CPortfolioOutput* pPfOut = m_pSolver->GetPortfolioOutput();
	if ( pPfOut != NULL ){
		KKTData kkt;
		//alpha
		CAttributeSet* alphakkt = m_pWS->CreateAttributeSet();
		const CPortfolio &portfolio = pPfOut->GetPortfolio();
		const CIDSet& idSet = portfolio.GetAssetIDSet();
		for ( String assetID=idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext() ) {
			double weight = portfolio.GetAssetWeight(assetID);
			if ( weight != 0. ) 
					alphakkt->Set(assetID, m_pWS->GetAsset(assetID)->GetAlpha()*multiplier); //*alphaterm
		}
		kkt.AddConstraint(*alphakkt, "alpha", "Alpha");

		// other kkt
		kkt.AddConstraint(pPfOut->GetPrimaryRiskModelKKTTerm(), "primaryRMKKT", "Primary RM");
		kkt.AddConstraint(pPfOut->GetSecondaryRiskModelKKTTerm(), "secondaryRMKKT", "Secondary RM");
		kkt.AddConstraint(pPfOut->GetResidualAlphaKKTTerm(), "residualAlphaKKTTerm", "Residual Alpha");
		kkt.AddConstraint(pPfOut->GetTransactioncostKKTTerm(true), "transactionCostKKTTerm", "transaction cost");

		// balanced kkt
		const CSlackInfo* balanceSlackInfo = pPfOut->GetSlackInfo4BalanceCon();
		if (balanceSlackInfo != NULL)
			kkt.AddConstraint(balanceSlackInfo->GetKKTTerm(true), "balanceKKTTerm", "Balance KKT");

		// get the KKT and penalty KKT terms for the asset bound constraints
		const CIDSet& slackInfoIDs = pPfOut->GetSlackInfoIDs();
		for (String slackID = slackInfoIDs.GetFirst(); slackID!=""; slackID = slackInfoIDs.GetNext() ) {
			const CSlackInfo* slackInfo = pPfOut->GetSlackInfo(slackID);
			kkt.AddConstraint(slackInfo->GetKKTTerm(true), slackID,  slackID); //upside
			kkt.AddOnlyIfDifferent(slackInfo->GetKKTTerm(false), slackID,  slackID); //downside
			kkt.AddConstraintPenalty(slackInfo->GetPenaltyKKTTerm(true), slackID, slackID+" Penalty"); // upside
			kkt.AddOnlyIfDifferentPenalty(slackInfo->GetPenaltyKKTTerm(false), slackID, slackID+" Penalty"); // downside
		}

		os<<kkt <<endl;
	}
}


KKTCons::KKTCons(const CAttributeSet& term, String id, String title, EKKTSide side, bool pen)
	:constraintID(id), displayName(title), isPenalty(pen), upOrDownside(side){

	const CIDSet& idset = term.GetKeySet();
	for(String id = idset.GetFirst(); id != ""; id = idset.GetNext() )
		weights[id] = term.GetValue(id);
}


void KKTData::AddConstraint(const CAttributeSet& attr, const String& cid, const String& title, EKKTSide side, bool pen)
{
	const CIDSet& idset = attr.GetKeySet();

	// check if it's an empty or all-zero column
	int i=0;
	for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
		// check if id is in the optimal portfolio
		if((kkt.size()>0) && (!kkt[0].Contains(id)))
			continue;
		// larger than display threshold
		double val = attr.GetValue(id);
		if (val<0.) 
			val = -val;
		if( val >=1.0e-6) 
			break;
	}

	//not empty
	if(i!=idset.GetCount())
		kkt.push_back(KKTCons(attr, cid, title, side, pen));
}

void KKTData::AddOnlyIfDifferent(const CAttributeSet& attr, const String& cid, const String& title, EKKTSide side, bool pen)
{
	const CIDSet& idset = attr.GetKeySet();

	// check if it's an empty or all-zero column
	int i=0;
	for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
		double val = attr.GetValue(id);

		//excludes ids not in the optimal portfolio and same value as the column before
		if(kkt.size()>0){
			// check if id is in the optimal portfolio
			if(kkt[0].Contains(id)){
				if( val==kkt.back().weights[id] ) 
					continue;
			}else 
				continue;
		}
		// larger than display threshold
		if (val<0.) 
			val = -val;
		if( val >=1.0e-6) 
			break;
	}

	//not empty
	if(i!=idset.GetCount()){
		kkt.back().upOrDownside = KKT_UPSIDE; // change previous colomn to upside
		kkt.push_back(KKTCons(attr, cid, title, side, pen));
	}
}

#include <iostream>
#include <iomanip>
ostream& operator<<(ostream& output, const KKTData& d)
{
	if(d.kkt.size()<=0)
		return output;
	
	output<<"Constraint KKT attribution terms"<<endl; 
	// output header of KKT
	output<<"Asset ID";
	for(size_t col=0; col<d.kkt.size(); col++){
		output << ", " << d.kkt[col].displayName;
		if(d.kkt[col].upOrDownside==KKT_UPSIDE){
			output<<"(up/down)";
			col++;
		}
	}
	output<<endl;

	// output the weights
	for(map<String,double>::const_iterator it = d.kkt[0].weights.begin(); it != d.kkt[0].weights.end(); ++it){
		output<<it->first;
		for(size_t col=0; col<d.kkt.size(); col++){
			map<String, double>::const_iterator itCol = d.kkt[col].weights.find(it->first);
			if( itCol != d.kkt[col].weights.end() ){ //there is a value
				if(d.kkt[col].upOrDownside == KKT_DOWNSIDE) // merged colomn
					output <<"/"<<std::fixed << std::setprecision(6)<<itCol->second;
				else
					output << ", " << std::fixed << std::setprecision(6)<<itCol->second;
			}else if(d.kkt[col].upOrDownside != KKT_DOWNSIDE)  //there is no value and not a merged column
				output << ", ";
		}
		output << endl;
	}

	return output;
}
