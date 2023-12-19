/** @file TutorialBase.java
* \brief Contains definition of the TutorialBase class with
* the shared routines for all tutorials.
*/

import java.io.*;
import java.util.*;
import java.text.*;
import com.barra.optimizer.*;

/**\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
*/
public class TutorialBase 
{
	CWorkSpace m_WS; 
	CCase m_Case;
	CSolver m_Solver;
	TutorialData m_Data;
	
	//used to create a workspace dump file
	protected String m_DumpFilename;
	protected boolean m_DumpAll;
	//used to set compatible mode to the approach prior to version 8.0 for running optimization
	protected boolean m_CompatibleMode;

	CPortfolio m_InitPf;
	CPortfolio[] m_InitPfs;
	CPortfolio m_BMPortfolio;
	CPortfolio m_BM2Portfolio;
	CPortfolio m_TradeUniverse;
	double[] m_PfValue;

	TutorialBase(TutorialData data)
	{
		m_WS = null;
		m_Case = null;
		m_Solver = null;
		m_Data = data;
		m_CompatibleMode = false;	
		m_DumpAll = false;
		m_PfValue = new double[data.m_AccountNum];
		m_InitPfs = new CPortfolio[data.m_AccountNum];
	}

	/// Initialize the optimization
	void Initialize( String tutorialID, String description, boolean dumpWS, boolean setAlpha, boolean isTaxAware)
	{
		System.out.println("======== Running Tutorial " + tutorialID + " ========" );
		System.out.println( description );

		// Create a workspace and setup risk model data
		SetupRiskModel();

		// Create initial portfolio etc
		SetupPortfolios();
		
		if ( setAlpha )
			SetAlpha();

		if ( isTaxAware )
		{
			SetPrice();
			SetupTaxLots();
		}

		// set up workspace dumping file
        	SetupDumpFile (tutorialID, dumpWS);
	}
    
    // set up workspace dumping file
    protected void SetupDumpFile (String tutorialID, boolean dumpWS)
    {
        if (m_DumpAll || dumpWS)
        {
            m_DumpFilename = "opsdata_";
            m_DumpFilename += tutorialID;
            m_DumpFilename += ".wsp";
        }
        else
            m_DumpFilename = "";
    }
	// set flag of dump all tutorial
	public void DumpAll(boolean dumpWS)
	{
		m_DumpAll = dumpWS;
	}
	
	/** set approach compatible to that prior to version 8.0
	* @param mode  If True, run optimization in the approach prior to version 8.0. 
	*/
	void SetCompatibleMode(boolean mode) { m_CompatibleMode = mode; };

	/// Setup initial portfolio, benchmarks and trade universe
 	void SetupPortfolios()
	{
		// Create an initial holding portfolio with no Cash
        for ( int iAccount = 0; iAccount < m_Data.m_AccountNum; iAccount++ ) {
            String id = "Initial Portfolio" + (iAccount == 0 ? "" : Integer.toString(iAccount));
            m_InitPfs[iAccount] = m_WS.CreatePortfolio(id);
            for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++) {
                if (m_Data.m_InitWeight[iAccount][iAsset] != 0.0) {
                    m_InitPfs[iAccount].AddAsset(m_Data.m_ID[iAsset], m_Data.m_InitWeight[iAccount][iAsset]);
                }
            }
        }
        m_InitPf = m_InitPfs[0];

		m_BMPortfolio = m_WS.CreatePortfolio("Benchmark");
		m_BM2Portfolio = m_WS.CreatePortfolio("Benchmark2");	
		m_TradeUniverse = m_WS.CreatePortfolio("Trade Universe");	
	 
		for( int i = 0; i<m_Data.m_AssetNum; i++)
		{
			if(m_Data.m_ID[i].compareTo("CASH") != 0)
			{
				m_TradeUniverse.AddAsset(m_Data.m_ID[i]);

				if (m_Data.m_BMWeight[i] != 0.0)
					m_BMPortfolio.AddAsset(m_Data.m_ID[i], m_Data.m_BMWeight[i]);	

				if (m_Data.m_BM2Weight[i] != 0)
					m_BM2Portfolio.AddAsset(m_Data.m_ID[i], m_Data.m_BM2Weight[i]);	
			}
		}		
	}

	// Setup tax lots and recalculate asset weights
	void SetupTaxLots()
	{
		// Add tax lots into the portfolio, compute asset values
		double[][] assetValue = new double[m_Data.m_AccountNum][m_Data.m_AssetNum];
		for (int j = 0; j < m_Data.m_Taxlots; j++) {
			int iAccount = m_Data.m_Account[j];
			int iAsset = m_Data.m_Indices[j];
			CPortfolio initPf = m_InitPfs[iAccount];
			initPf.AddTaxLot(m_Data.m_ID[iAsset], m_Data.m_Age[j],
				m_Data.m_CostBasis[j], m_Data.m_Shares[j], false);
			assetValue[iAccount][iAsset] += m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
		}

		// set portfolio values
		for (int i = 0; i < m_Data.m_AccountNum; i++) {
			m_PfValue[i] = 0;
			for (int j = 0; j < m_Data.m_AssetNum; j++)
				m_PfValue[i] += assetValue[i][j];
		}

		// Reset asset initial weights based on tax lot information
		for (int i = 0; i < m_Data.m_AccountNum; i++) {
			CPortfolio initPf = m_InitPfs[i];
			for (int j = 0; j < m_Data.m_AssetNum; j++)
				initPf.AddAsset(m_Data.m_ID[j], assetValue[i][j] / m_PfValue[i]);
		}
	}

	// Calculate portfolio weights and values from tax lot data.
	public void UpdatePortfolioWeights() {
		for (int iAccount = 0; iAccount < m_Data.m_AccountNum; iAccount++) {
			CPortfolio pInitPf = m_InitPfs[iAccount];
			if (pInitPf != null) {
				m_PfValue[iAccount] = 0.;
				double[] assetValue = new double[m_Data.m_AssetNum];
				CIDSet oTaxLotIDs = pInitPf.GetTaxLotIDs();
				for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++) {
					String assetID = m_Data.m_ID[iAsset];
					double price = m_Data.m_Price[iAsset];
					assetValue[iAsset] = 0.;
					for (String lotID = oTaxLotIDs.GetFirst(); !lotID.equals(""); lotID = oTaxLotIDs.GetNext()) {
						CTaxLot pLot = pInitPf.GetTaxLot(lotID);
						if (pLot.GetAssetID().equals(assetID)) {
							double value = pLot.GetShares() * price;
							m_PfValue[iAccount] += value;
							assetValue[iAsset] += value;
						}
					}
				}

				for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++) {
					pInitPf.AddAsset(m_Data.m_ID[iAsset], assetValue[iAsset] / m_PfValue[iAccount]);
				}
			}
		}
	}

	void SetupRiskModel()
	{
		SetupRiskModel(true);
	}
		
	/// Create a workspace and setup risk model data
	void SetupRiskModel(boolean setExposures)
	{
		// Initialize the Barra Optimizer CWorkSpace interface
		if ( m_WS != null )
			m_WS.Release();
		m_WS = CWorkSpace.CreateInstance();

		// Create Primary Risk Model
		CRiskModel pRM = m_WS.CreateRiskModel("GEM", ERiskModelType.eEQUITY);

		// Load the covariance matrix from the TutorialData object
		int count = 0;
		for(int i=0; i<m_Data.m_FactorNum; i++)
		{
			for(int j=0; j<=i; j++) 
			{
				pRM.SetFactorCovariance( m_Data.m_Factor[i], 
					m_Data.m_Factor[j], m_Data.m_CovData[count++] );
			}
		}

		// Add assets to the workspace
		for( int i = 0; i<m_Data.m_AssetNum; i++)
		{
			CAsset asset;
			
			if(m_Data.m_ID[i].compareTo("CASH")==0)
				asset = m_WS.CreateAsset(m_Data.m_ID[i], EAssetType.eCASH);
			else
				asset = m_WS.CreateAsset(m_Data.m_ID[i], EAssetType.eREGULAR);

			// Set expected return here
			asset.SetAlpha(0); 
		}

		if (setExposures)
		{
			// Load the exposure matrix from the TutorialData object
			CAttributeSet exposureSet;
			for(int i=0; i<m_Data.m_AssetNum; i++)
			{
				exposureSet = m_WS.CreateAttributeSet();
				for(int j=0; j<m_Data.m_FactorNum; j++)
				{
					exposureSet.Set(m_Data.m_Factor[j], 
							m_Data.m_ExpData[i][j]);
				}
				pRM.SetFactorExposureBySet(m_Data.m_ID[i], exposureSet); 
			}
		}
		
		// Load specific risk covariance
		for(int i=0; i < m_Data.m_AssetNum; i++)
			pRM.SetSpecificCovariance(m_Data.m_ID[i], m_Data.m_ID[i], m_Data.m_SpCov[i]);		
	}


	/// Setup a simple sample secondary risk model
	void SetupRiskModel2()
	{
		// Create a risk model
		CRiskModel rm = m_WS.CreateRiskModel("MODEL2", ERiskModelType.eEQUITY);

		// Set factor covariances 
		rm.SetFactorCovariance( "Factor2_1", "Factor2_1", 1.0 );
		rm.SetFactorCovariance( "Factor2_1", "Factor2_2", 0.1 );
		rm.SetFactorCovariance( "Factor2_2", "Factor2_2", 0.5 );

		// Set factor exposures 
		for ( int i=0; i<m_Data.m_AssetNum; i++ ) {
			rm.SetFactorExposure( m_Data.m_ID[i], "Factor2_1", (double)i/(double)m_Data.m_AssetNum );
			rm.SetFactorExposure( m_Data.m_ID[i], "Factor2_2", (double)(2*i)/(double)m_Data.m_AssetNum );
		}

		// Set specific risk covariance
		for ( int i=0; i<m_Data.m_AssetNum; i++ ) {
			rm.SetSpecificCovariance( m_Data.m_ID[i], m_Data.m_ID[i], 0.05 );
		}
	}

	/// Set the expected return for each asset in the model
	void SetAlpha()
	{
		// Set the expected return for each asset
		for( int i=0; i<m_Data.m_AssetNum; i++ ) {
			 CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
			 if ( asset!=null )
				 asset.SetAlpha(m_Data.m_Alpha[i]);
		}
	}

	/// Set the price for each asset in the model
	void SetPrice()
	{
		for (int i = 0; i < m_Data.m_AssetNum; i++)
		{
			CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
			if (asset != null)
				asset.SetPrice(m_Data.m_Price[i]);
		}
	}

	/// Run optiimzation; Create a new solver 
	void RunOptimize()
	{
		RunOptimize(false, false);
	}

	/// Run optiimzation; reuse old solver 
	void RunOptimize(boolean reuse)
	{
		RunOptimize(reuse, false);
    }
	
	///  Run optimization; and report estimated untility upperbound
	void RunOptimizeReportUtilUB()
	{
		RunOptimize(false, true);
	}

	/** Run optiimzation
	* @param useOldSolver If True, use the eixisting m_Solver pointer without recreate a new solver.
    * @param estUtilUB If True, estimate the uppper bound on utility.
	*/
	void RunOptimize(boolean useOldSolver, boolean estUtilUB)
	{
		if ( !useOldSolver )
			m_Solver = m_WS.CreateSolver(m_Case);
			
		// set compatible mode
		if( m_CompatibleMode ) 
			m_Solver.SetOption( "COMPATIBLE_MODE", 1.0);
			
        // estimate upperbound on utility
		if (estUtilUB)
			m_Solver.SetOption("REPORT_UPPERBOUND_ON_UTILITY", 1.0); 		
		
		// opsdata info could be very helpful in debugging 
		// m_WS.Serialize("opsdata.wsp");
		if ( m_DumpFilename.length()>0 ) m_WS.Serialize(m_DumpFilename);
		
		CStatus oStatus = m_Solver.Optimize();

		System.out.println(oStatus.GetMessage());
		System.out.println(m_Solver.GetLogMessage());

		if (oStatus.GetStatusCode() == EStatusCode.eOK)	{
			CPortfolioOutput output = m_Solver.GetPortfolioOutput();
			CMultiAccountOutput maOutput = m_Solver.GetMultiAccountOutput();
			CMultiPeriodOutput mpOutput = m_Solver.GetMultiPeriodOutput();
			if (output != null)
				PrintPortfolioOutput(output, estUtilUB);
			else if (maOutput != null)
				PrintMultiAccountOutput(maOutput);
			else if (mpOutput != null)
				PrintMultiPeriodOutput(mpOutput);
		}
		else if (oStatus.GetStatusCode() == EStatusCode.eLICENSE_ERROR)
			throw new IllegalStateException("Optimizer license error");
	}

	void PrintPortfolioOutput(CPortfolioOutput output, boolean estUtilUB) {
		DecimalFormat f = new DecimalFormat("0.0000");
		System.out.println("Optimized Portfolio:");
		System.out.println("Risk(%)     = " + f.format(output.GetRisk()));
		System.out.println("Return(%)   = " + f.format(output.GetReturn()));
		System.out.println("Utility     = " + f.format(output.GetUtility()));
		if (estUtilUB)
		{
			double utilUB = output.GetUpperBoundOnUtility();
			if (utilUB != barraopt.getOPT_NAN())
				System.out.println("Util. Upperbound = " + f.format(utilUB));
		};
		System.out.println("Turnover(%) = " + f.format(output.GetTurnover()));
		System.out.println("Penalty     = " + f.format(output.GetPenalty()));
		System.out.println("TranxCost(%)= " + f.format(output.GetTransactioncost()));
		System.out.println("Beta        = " + f.format(output.GetBeta()));
		if (output.GetExpectedShortfall() != barraopt.getOPT_NAN())
			System.out.println("ExpShortfall(%)= " + f.format(output.GetExpectedShortfall()));
		System.out.println();
		// Output the non-zero weight in the optimized portfolio
		System.out.println("Asset Holdings:");
		CPortfolio portfolio = output.GetPortfolio();
		CIDSet idSet = portfolio.GetAssetIDSet();
		String assetID = idSet.GetFirst();
		while (!assetID.equals(""))
		{
			double weight = portfolio.GetAssetWeight(assetID);
			if (weight != 0)
			{
				System.out.println(assetID + ": " + f.format(weight));
			}
			assetID = idSet.GetNext();
		}
		System.out.println();
	}

	void PrintMultiAccountOutput(CMultiAccountOutput output)
	{
		DecimalFormat fi = new DecimalFormat("0");
		DecimalFormat f = new DecimalFormat("0.0000");
		// Retrieve cross-account output
		CPortfolioOutput pCrossAccountOutput = output.GetCrossAccountOutput();
		CCrossAccountTaxOutput crossAccountTaxOutput = output.GetCrossAccountTaxOutput();
		System.out.println("Account     = Cross-account");
		System.out.println("Return(%)   = " + f.format(pCrossAccountOutput.GetReturn()));
		System.out.println("Utility     = " + f.format(pCrossAccountOutput.GetUtility()));
		System.out.println("Turnover(%) = " + f.format(pCrossAccountOutput.GetTurnover()));
		double jointMarketBuyCost = output.GetJointMarketImpactBuyCost();
		if (jointMarketBuyCost != barraopt.getOPT_NAN())
			System.out.println("Joint Market Impact Buy Cost($) = " + f.format(jointMarketBuyCost));
		double jointMarketSellCost = output.GetJointMarketImpactSellCost();
		if (jointMarketSellCost != barraopt.getOPT_NAN())
			System.out.println("Joint Market Impact Sell Cost($) = " + f.format(jointMarketSellCost));
		if (crossAccountTaxOutput != null)
			System.out.println("Total Tax   = " + f.format(crossAccountTaxOutput.GetTotalTax()));
		System.out.println();

		// Retrieve output for each account group
		if (output.GetNumAccountGroups() > 0) {
			for (int i = 0; i < output.GetNumAccountGroups(); i++) {
				CAccountGroupTaxOutput pGroupOutput = output.GetAccountGroupTaxOutput(i);
				System.out.println("Account Group = " + fi.format(pGroupOutput.GetAccountGroupID()));
				System.out.println("Total Tax     = " + f.format(pGroupOutput.GetTotalTax()));
			}
			System.out.println();
		}

		// Retrieve output for each account
		for (int i = 0; i < output.GetNumAccounts(); i++)
		{
			CPortfolioOutput pAccountOutput = output.GetAccountOutput(i);
			int accountID = pAccountOutput.GetAccountID();
			System.out.println("Account     = " + fi.format(accountID));
			System.out.println("Risk(%)     = " + f.format(pAccountOutput.GetRisk()));
			System.out.println("Return(%)   = " + f.format(pAccountOutput.GetReturn()));
			System.out.println("Utility     = " + f.format(pAccountOutput.GetUtility()));
			System.out.println("Turnover(%) = " + f.format(pAccountOutput.GetTurnover()));
			System.out.println("Beta        = " + f.format(pAccountOutput.GetBeta()));

			System.out.println("\nAsset Holdings:");
			CPortfolio portfolio = pAccountOutput.GetPortfolio();
			CIDSet idSet = portfolio.GetAssetIDSet();
			for (String assetID = idSet.GetFirst(); !assetID.equals(""); assetID = idSet.GetNext())
			{
				double weight = portfolio.GetAssetWeight(assetID);
				if (weight != 0.0)
					System.out.println(assetID + ": " + f.format(weight));
			}
			CNewTaxOutput taxOut = pAccountOutput.GetNewTaxOutput();
			if (taxOut != null)
			{
				if (GetAccountGroupID(accountID) == -1) {
					double ltax = taxOut.GetLongTermTax("*", "*");
					double stax = taxOut.GetShortTermTax("*", "*");
					double lgg_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN);
					double lgl_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS);
					double sgg_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN);
					double sgl_all = taxOut.GetCapitalGain("*", "*", ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS);
					System.out.println("\nTax info for the tax rule group(all assets):");
					System.out.println("Long Term Gain = " + f.format(lgg_all));
					System.out.println("Long Term Loss = " + f.format(lgl_all));
					System.out.println("Short Term Gain = " + f.format(sgg_all));
					System.out.println("Short Term Loss = " + f.format(sgl_all));
					System.out.println("Long Term Tax  = " + f.format(ltax));
					System.out.println("Short Term Tax = " + f.format(stax));

					System.out.println("\nTotal Tax(for all tax rule groups) = " + f.format(taxOut.GetTotalTax()) + "\n");
				}

				System.out.println("TaxlotID          Shares:");
				for (String assetID = idSet.GetFirst(); !assetID.equals(""); assetID = idSet.GetNext())
				{
					CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
					CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
					for (String lotID = oLotIDs.GetFirst(); !lotID.equals(""); lotID = oLotIDs.GetNext())
					{
						double shares = sharesInTaxlot.GetValue(lotID);
						if (shares != 0)
							System.out.println(lotID + "  " + f.format(shares));
					}
				}

				CAttributeSet newShares = taxOut.GetNewShares();
				PrintAttributeSet(newShares, "\nNew Shares:");
				System.out.println();
			}

		}
	}

	public void PrintMultiPeriodOutput(CMultiPeriodOutput output)
	{
		// Retrieve cross-period output
		DecimalFormat fi = new DecimalFormat("0");
		DecimalFormat f = new DecimalFormat("0.0000");
		CPortfolioOutput pCrossPeriodOutput = output.GetCrossPeriodOutput();
		System.out.println("Period      = Cross-period");
		System.out.println("Return(%)   = " + f.format(pCrossPeriodOutput.GetReturn()));
		System.out.println("Utility     = " + f.format(pCrossPeriodOutput.GetUtility()));
		System.out.println("Turnover(%) = " + f.format(pCrossPeriodOutput.GetTurnover()));
		System.out.println();
				
		// Retrieve output for each period
		for (int i=0; i<output.GetNumPeriods(); i++) {
			CPortfolioOutput pPeriodOutput = output.GetPeriodOutput(i);
			System.out.println("Period      = " + fi.format(pPeriodOutput.GetPeriodID()));
			System.out.println("Risk(%)     = " + f.format(pPeriodOutput.GetRisk()));
			System.out.println("Return(%)   = " + f.format(pPeriodOutput.GetReturn()));
			System.out.println("Utility     = " + f.format(pPeriodOutput.GetUtility()));
			System.out.println("Turnover(%) = " + f.format(pPeriodOutput.GetTurnover()));
			System.out.println("Beta        = " + f.format(pPeriodOutput.GetBeta()));
			System.out.println();
		}
	}

    /** Output trade list
    * @param isOptimalPortfolio If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
    */
    void OutputTradeList(boolean isOptimalPortfolio)
    {
        CPortfolioOutput output = m_Solver.GetPortfolioOutput();
        if (output != null)
        {
            DecimalFormat f = new DecimalFormat("0.0000");
            CIDSet oddLotIDSet;
            CPortfolio portfolio;
            if (isOptimalPortfolio)
            {
                System.out.println("Optimal Portfolio:");
                portfolio = output.GetPortfolio();
            }
            else
            {
                System.out.println("Roundlotted Portfolio:");
                oddLotIDSet = m_WS.CreateIDSet();
                portfolio = output.GetRoundlottedPortfolio(oddLotIDSet);
            }

            System.out.println("Asset Holdings:");
            CIDSet IDSet = portfolio.GetAssetIDSet();

            String assetID = IDSet.GetFirst();
            while (assetID.compareTo("") != 0)
            {
                double weight = portfolio.GetAssetWeight(assetID);
                if (weight != 0)
                    System.out.println(assetID + ": " + f.format(weight));
                assetID = IDSet.GetNext();
            }

            System.out.println();
            System.out.println("Trade List:");
            System.out.println("Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type");

            assetID = IDSet.GetFirst();
            while (assetID.compareTo("") != 0)
            {
                if (assetID.compareTo("CASH") != 0)
                {
                    CAssetTradeListInfo tradelistInfo = output.GetAssetTradeListInfo(assetID, isOptimalPortfolio);
                    String tradeType = "";
                    if (tradelistInfo.GetTradeType() == ETradeType.eHOLD)
                        tradeType = "Hold";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eBUY)
                        tradeType = "Buy";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eCOVER_BUY)
                        tradeType = "Cover Buy";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eCROSSOVER_BUY)
                        tradeType = "Crossover Buy";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eCROSSOVER_SELL)
                        tradeType = "Crossover Sell";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eSELL)
                        tradeType = "Sell";
                    else if (tradelistInfo.GetTradeType() == ETradeType.eSHORT_SELL)
                        tradeType = "Short Sell";

                    System.out.print(assetID + ": " + f.format(tradelistInfo.GetInitialShares()));
                    System.out.print(", " + f.format(tradelistInfo.GetFinalShares()));
                    System.out.print(", " + f.format(tradelistInfo.GetTradedShares()));
                    System.out.print(", " + f.format(tradelistInfo.GetPrice()));
                    System.out.print(", " + f.format(tradelistInfo.GetTradedValue()));
                    System.out.print(", " + f.format(tradelistInfo.GetTradedValuePcnt()));
                    System.out.print(", " + f.format(tradelistInfo.GetTotalTransactionCost()));
                    System.out.println(", " + tradeType);
                }
                assetID = IDSet.GetNext();
            }
            System.out.println();
        }
    }

    /** Returns the ID of the group which the account belongs to.
    * @param accountID the ID of the account.
    * @return the ID of the group, or -1.
    */
    public int GetAccountGroupID(int accountID)
    {
        if (m_Solver != null) {
           for (int i = 0; i < m_Solver.GetNumAccounts(); i++) {
               CAccount account = m_Solver.GetAccount(i);
               if (account.GetID() == accountID)
                  return account.GetGroupID();
           }
        }
        return -1;
    }

    void PrintAttributeSet(CAttributeSet attributeSet, String title)
    {
        CIDSet idSet = attributeSet.GetKeySet();
        String id = idSet.GetFirst();
		if(id.compareTo("") !=0 ){
			System.out.println(title);
			DecimalFormat f = new DecimalFormat("0.0000");
			while (id.compareTo("") != 0) {
				System.out.println(id + ": " + f.format(attributeSet.GetValue(id)));
				id = idSet.GetNext();
			}
		}	
    }
	
    public void PrintRisksByAsset(CPortfolio portfolio)
    {
        CIDSet assetIDs = portfolio.GetAssetIDSet();

        // copy assetIDs for safe iteration (calling EvaluateRisk() might invalidate iterators)
        CIDSet ids = m_WS.CreateIDSet();
        for (String id = assetIDs.GetFirst(); !id.equals(""); id = assetIDs.GetNext())
            ids.Add(id);

        for (String id = ids.GetFirst(); !id.equals(""); id = ids.GetNext()) {
            CIDSet idset = m_WS.CreateIDSet();
            idset.Add(id);
            double risk = m_Solver.EvaluateRisk(portfolio, ERiskType.eTOTALRISK, null, idset, null, true, true);
            if (risk != 0.0)
                System.out.format("Risk from %s = %.4f\n", id, risk);
            idset.Release();
        }
        ids.Release();
    }

	void CollectKKT(){
		CollectKKT(1.0);
	}
	
	void CollectKKT(double multiplier)
	{
		CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		if ( output != null ){
			KKTData kkt = new KKTData();
			//alpha
			CAttributeSet alphakkt = m_WS.CreateAttributeSet();
			CPortfolio portfolio = output.GetPortfolio();
			CIDSet idSet = portfolio.GetAssetIDSet();
			for (String assetID = idSet.GetFirst(); assetID.compareTo("") !=0 ; assetID = idSet.GetNext()){
				double weight = portfolio.GetAssetWeight(assetID);
				if ( weight != 0. ) 
						alphakkt.Set(assetID, m_WS.GetAsset(assetID).GetAlpha()*multiplier); //*alphaterm
			}
			kkt.AddConstraint(alphakkt, "alpha", "Alpha");

			// other kkt
			kkt.AddConstraint(output.GetPrimaryRiskModelKKTTerm(), "primaryRMKKT", "Primary RM");
			kkt.AddConstraint(output.GetSecondaryRiskModelKKTTerm(), "secondaryRMKKT", "Secondary RM");
			kkt.AddConstraint(output.GetResidualAlphaKKTTerm(), "residualAlphaKKTTerm", "Residual Alpha");
			kkt.AddConstraint(output.GetTransactioncostKKTTerm(true), "transactionCostKKTTerm", "transaction cost");

			// balanced kkt
			CSlackInfo balanceSlackInfo = output.GetSlackInfo4BalanceCon();
			if (balanceSlackInfo != null)
				kkt.AddConstraint(balanceSlackInfo.GetKKTTerm(true), "balanceKKTTerm", "Balance KKT");

			// get the KKT and penalty KKT terms for the asset bound constraints
			CIDSet slackInfoIDs = output.GetSlackInfoIDs();
			for (String slackID = slackInfoIDs.GetFirst(); slackID.compareTo("") != 0; slackID = slackInfoIDs.GetNext() ) {
				CSlackInfo slackInfo = output.GetSlackInfo(slackID);
				kkt.AddConstraint(slackInfo.GetKKTTerm(true), slackID,  slackID); //upside
				kkt.AddOnlyIfDifferent(slackInfo.GetKKTTerm(false), slackID,  slackID); //downside
				kkt.AddConstraintPenalty(slackInfo.GetPenaltyKKTTerm(true), slackID, slackID+" Penalty"); // upside
				kkt.AddOnlyIfDifferentPenalty(slackInfo.GetPenaltyKKTTerm(false), slackID, slackID+" Penalty"); // downside
			}

			kkt.print();
		}
	}
};



/**\brief Contains the shared routines for collecting KKT terms.
*/

/**\brief Contains shared data structure for a KKT column.
*/
class KKTCons{
	public static final int KKT_SIDE_DEFAULT = 0;
	public static final int KKT_UPSIDE = 1;
	public static final int KKT_DOWNSIDE = -1;	

	public String displayName;
	public String constraintID;
	public boolean isPenalty;
	public int upOrDownside; 
	public SortedMap<String, Double> weights;

	
	public KKTCons(CAttributeSet term, String id, String title, int side, boolean pen){
		constraintID = id;
		displayName = title;
		isPenalty = pen;
		upOrDownside = side;
		weights = new TreeMap<String, Double>();
		
		CIDSet idset = term.GetKeySet();
		for(String asset = idset.GetFirst(); asset.compareTo("") != 0; asset = idset.GetNext() )
			weights.put(asset, term.GetValue(asset));
	}
	
	public boolean Contains(String id) { return weights.containsKey(id); };
	public double Get(String id) { return weights.get(id); };
	public Iterator<String> KeyIterator() { return weights.keySet().iterator(); };
}

/**\brief Contains shared class/routines for a KKT table.
*/
class KKTData{
	ArrayDeque<KKTCons> kkt;	

	public KKTData(){
		kkt = new ArrayDeque<KKTCons>();
	}
	
	public void AddConstraint(CAttributeSet attr, String cid, String title, int side){
		AddConstraint(attr, cid, title, side, false);
	};
	public void AddConstraint(CAttributeSet attr, String cid, String title){
		AddConstraint(attr, cid, title, KKTCons.KKT_SIDE_DEFAULT, false);
	};

	public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title, int side){
		AddOnlyIfDifferent(attr, cid, title, side, false);
	};
	public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title){
		AddOnlyIfDifferent(attr, cid, title, KKTCons.KKT_DOWNSIDE, false);
	};	
	
	public void AddConstraintPenalty(CAttributeSet attr, String cid, String title, int side){
		AddConstraint(attr, cid, title, side, true);
	}
	public void AddConstraintPenalty(CAttributeSet attr, String cid, String title){
		AddConstraint(attr, cid, title, KKTCons.KKT_SIDE_DEFAULT, true);
	}
	
	public void AddOnlyIfDifferentPenalty(CAttributeSet attr, String cid, String title, int side){
		AddOnlyIfDifferent(attr, cid, title, side, true);
	}
	public void AddOnlyIfDifferentPenalty(CAttributeSet attr, String cid, String title){
		AddOnlyIfDifferent(attr, cid, title, KKTCons.KKT_DOWNSIDE, true);
	}

	public void AddConstraint(CAttributeSet attr, String cid, String title, int side, boolean pen){
		CIDSet idset = attr.GetKeySet();

		// check if it's an empty or all-zero column
		int i=0;
		for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
			// check if id is in the optimal portfolio
			if((kkt.size()>0) && (!kkt.getFirst().Contains(id)))
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
			kkt.add(new KKTCons(attr, cid, title, side, pen));
	}

	public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title, int side, boolean pen){
		CIDSet idset = attr.GetKeySet();

		// check if it's an empty or all-zero column
		int i=0;
		for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
			double val = attr.GetValue(id);

			//excludes ids not in the optimal portfolio and same value as the column before
			if(kkt.size()>0){
				// check if id is in the optimal portfolio
				if(kkt.getFirst().Contains(id)){
					if( val==kkt.getLast().Get(id) ) 
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
			kkt.getLast().upOrDownside = KKTCons.KKT_UPSIDE; // change previous column to upside
			kkt.add(new KKTCons(attr, cid, title, side, pen));
		}
	}

	public void print()
	{
		if(kkt.size()<=0)
			return;
		
		System.out.println("Constraint KKT attribution terms"); 
		// output header of KKT
		System.out.print("Asset ID");
		
		Iterator<KKTCons> itr = kkt.iterator();
		while(itr.hasNext()){
			KKTCons cons = itr.next(); 
			if(cons.upOrDownside != KKTCons.KKT_DOWNSIDE){
				System.out.print(", " + cons.displayName);
				if(cons.upOrDownside == KKTCons.KKT_UPSIDE)
					System.out.print("(up/down)");
			}
		}
		
		System.out.print(System.getProperty("line.separator"));

		// output the weights
		DecimalFormat f = new DecimalFormat("0.000000");
		for(Iterator<String> assetItr = kkt.getFirst().KeyIterator(); assetItr.hasNext(); ){
			String id = assetItr.next();
			System.out.print(id);
			itr = kkt.iterator();
			for(itr=kkt.iterator(); itr.hasNext(); ){
				KKTCons cons = itr.next();
				if( cons.Contains(id) ){ //there is a value
					if(cons.upOrDownside == KKTCons.KKT_DOWNSIDE) // merged column
						System.out.print("/" + f.format(cons.Get(id)));
					else
						System.out.print(", " + f.format(cons.Get(id)));
				}else if(cons.upOrDownside != KKTCons.KKT_DOWNSIDE)  //there is no value and not a merged column: empty column
					System.out.print(", ");
			}
			System.out.print(System.getProperty("line.separator"));
		}
	}
}
