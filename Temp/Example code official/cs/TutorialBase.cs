/** @file TutorialBase.cs
* \brief Contains definition of the TutorialBase class with
* the shared routines for all tutorials.
*/

using System;
using System.Collections.Generic;

namespace Tutorial_CS
{
    /**\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
    */
    class TutorialBase
    {
        public CWorkSpace m_WS;
        public CCase m_Case;
        public CSolver m_Solver;
        public TutorialData m_Data;

        //used to create a workspace dump file
        protected String m_DumpFilename;
        protected Boolean m_DumpAll;
        //used to set compatible mode to the approach prior to version 8.0 for running optimization
        protected bool m_CompatibleMode;


        public CPortfolio m_InitPf;
        public CPortfolio[] m_InitPfs;
        public CPortfolio m_BMPortfolio;
        public CPortfolio m_ModelPortfolio;
        public CPortfolio m_TradeUniverse;
        public double[] m_PfValue;

        public TutorialBase(TutorialData data)
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
        protected void Initialize(String tutorialID, String description, bool dumpWS, bool setAlpha, bool isTaxAware)
        {
            Console.WriteLine("======== Running Tutorial " + tutorialID + " ========");
            Console.WriteLine(description);

            // Create a workspace and setup risk model data
            SetupRiskModel();

            // Create initial portfolio etc
            SetupPortfolios();

            if (setAlpha)
                SetAlpha();

            if (isTaxAware)
            {
                SetPrice();
                SetupTaxLots();
            }

            // set up workspace dumping file
            SetupDumpFile(tutorialID, dumpWS);
        }

        // set up workspace dumping file
        protected void SetupDumpFile(String tutorialID, bool dumpWS)
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
        public void DumpAll(Boolean dumpWS)
        {
            m_DumpAll = dumpWS;
        }

        /** set approach compatible to that prior to version 8.0
	    * @param mode  If True, run optimization in the approach prior to version 8.0. 
	    */
        public void SetCompatibleMode(bool mode) { m_CompatibleMode = mode; }


        /// Setup initial portfolio, benchmarks and trade universe
        public void SetupPortfolios()
        {
            // Create an initial portfolio with no Cash
            for ( int iAccount = 0; iAccount < m_Data.m_AccountNum; iAccount++ ) {
                String id = "Initial Portfolio" + (iAccount == 0 ? "" : iAccount.ToString());
                m_InitPfs[iAccount] = m_WS.CreatePortfolio(id);
                for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++) {
                    if (m_Data.m_InitWeight[iAccount,iAsset] != 0.0) {
                        m_InitPfs[iAccount].AddAsset(m_Data.m_ID[iAsset], m_Data.m_InitWeight[iAccount,iAsset]);
                    }
                }
            }
            m_InitPf = m_InitPfs[0];

            m_BMPortfolio = m_WS.CreatePortfolio("Benchmark");
            m_ModelPortfolio = m_WS.CreatePortfolio("Model");
            m_TradeUniverse = m_WS.CreatePortfolio("Trade Universe");

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!m_Data.m_ID[i].Equals("CASH"))
                {
                    m_TradeUniverse.AddAsset(m_Data.m_ID[i], 0.0);

                    if (m_Data.m_BMWeight[i] != 0.0)
                        m_BMPortfolio.AddAsset(m_Data.m_ID[i], m_Data.m_BMWeight[i]);

                    if (m_Data.m_BM2Weight[i] != 0)
                        m_ModelPortfolio.AddAsset(m_Data.m_ID[i], m_Data.m_BM2Weight[i]);
                }
            }
        }

        // Setup tax lots and recalculate asset weights
        public void SetupTaxLots()
        {

            // Add tax lots into the portfolio, compute asset values
            double[,] assetValue = new double[m_Data.m_AccountNum,m_Data.m_AssetNum];
            for (int j = 0; j < m_Data.m_Taxlots; j++) {
                int iAccount = m_Data.m_Account[j];
                int iAsset = m_Data.m_Indices[j];
                CPortfolio initPf = m_InitPfs[iAccount];
                initPf.AddTaxLot(m_Data.m_ID[iAsset], m_Data.m_Age[j],
                                 m_Data.m_CostBasis[j], m_Data.m_Shares[j], false);
                assetValue[iAccount,iAsset] += m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
            }

            // set portfolio values
            for (int i = 0; i < m_Data.m_AccountNum; i++) {
                m_PfValue[i] = 0;
                for (int j = 0; j < m_Data.m_AssetNum; j++)
                    m_PfValue[i] += assetValue[i,j];
            }

            // Reset asset initial weights based on tax lot information
            for (int i = 0; i < m_Data.m_AccountNum; i++) {
                CPortfolio initPf = m_InitPfs[i];
                for (int j = 0; j < m_Data.m_AssetNum; j++)
                    initPf.AddAsset(m_Data.m_ID[j], assetValue[i,j] / m_PfValue[i]);
            }
        }

        /// Calculate portfolio weights and values from tax lot data.
        public void UpdatePortfolioWeights() {
            for (int iAccount = 0; iAccount < m_Data.m_AccountNum; iAccount++) {
                CPortfolio pInitPf = m_InitPfs[iAccount];
                if (pInitPf != null) {
                    m_PfValue[iAccount] = 0;
                    double[] assetValue = new double[m_Data.m_AssetNum];
                    CIDSet oTaxLotIDs = pInitPf.GetTaxLotIDs();
                    for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++) {
                        String assetID = m_Data.m_ID[iAsset];
                        double price = m_Data.m_Price[iAsset];
                        assetValue[iAsset] = 0;
                        for (String lotID = oTaxLotIDs.GetFirst(); lotID != ""; lotID = oTaxLotIDs.GetNext()) {
                            CTaxLot pLot = pInitPf.GetTaxLot(lotID);
                            if (pLot.GetAssetID() == assetID) {
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

        public void SetupRiskModel()
        {
            SetupRiskModel(true);
        }

        /// Create a workspace and setup risk model data
        public void SetupRiskModel(bool setExposures)
        {
            // Create a CWorkSpace instance; Release the existing one.
            if (m_WS != null)
                m_WS.Dispose();
            m_WS = CWorkSpace.CreateInstance();

            // Create Primary Risk Model
            CRiskModel pRM = m_WS.CreateRiskModel("GEM", ERiskModelType.eEQUITY);

            // Load the covariance matrix from the CData object
            int count = 0;
            for (int i = 0; i < m_Data.m_FactorNum; i++)
            {
                for (int j = 0; j <= i; j++)
                {
                    pRM.SetFactorCovariance(m_Data.m_Factor[i],
                        m_Data.m_Factor[j], m_Data.m_CovData[count++]);
                }
            }

            // Add assets to the workspace
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset;

                if (m_Data.m_ID[i].Equals("CASH"))
                    asset = m_WS.CreateAsset(m_Data.m_ID[i], EAssetType.eCASH);
                else
                    asset = m_WS.CreateAsset(m_Data.m_ID[i], EAssetType.eREGULAR);

                // Set expected return here
                asset.SetAlpha(0);
            }

            if (setExposures)
            {
                // Load the exposure matrix from the CData object
                CAttributeSet exposureSet;
                for (int i = 0; i < m_Data.m_AssetNum; i++)
                {
                    exposureSet = m_WS.CreateAttributeSet();
                    for (int j = 0; j < m_Data.m_FactorNum; j++)
                    {
                        exposureSet.Set(m_Data.m_Factor[j], m_Data.m_ExpData[i, j]);
                    }
                    pRM.SetFactorExposureBySet(m_Data.m_ID[i], exposureSet);
                }
            }

            // Load specific risk covariance
            for (int i = 0; i < m_Data.m_AssetNum; i++)
                pRM.SetSpecificCovariance(m_Data.m_ID[i], m_Data.m_ID[i], m_Data.m_SpCov[i]);
        }

        /// Setup a simple sample secondary risk model
        public void SetupRiskModel2()
        {
            // Create a risk model
            CRiskModel rm = m_WS.CreateRiskModel("MODEL2", ERiskModelType.eEQUITY);

            // Set factor covariances 
            rm.SetFactorCovariance("Factor2_1", "Factor2_1", 1.0);
            rm.SetFactorCovariance("Factor2_1", "Factor2_2", 0.1);
            rm.SetFactorCovariance("Factor2_2", "Factor2_2", 0.5);

            // Set factor exposures 
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                rm.SetFactorExposure(m_Data.m_ID[i], "Factor2_1", (double)i / (double)m_Data.m_AssetNum);
                rm.SetFactorExposure(m_Data.m_ID[i], "Factor2_2", (double)(2 * i) / (double)m_Data.m_AssetNum);
            }

            // Set specific risk covariance
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                rm.SetSpecificCovariance(m_Data.m_ID[i], m_Data.m_ID[i], 0.05);
            }
        }

        /// Set the expected return for each asset in the model
        public void SetAlpha()
        {
            // Set the expected return for each asset
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetAlpha(m_Data.m_Alpha[i]);
            }
        }

        /// Set the price for each asset in the model
        public void SetPrice()
        {
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                CAsset asset = m_WS.GetAsset(m_Data.m_ID[i]);
                if (asset != null)
                    asset.SetPrice(m_Data.m_Price[i]);
            }
        }

        /// Run optiimzation; Create a new solver 
        public void RunOptimize()
        {
            RunOptimize(false, false);
        }

        /// Run optiimzation; reuse old solver 
        public void RunOptimize(bool reuse)
        {
            RunOptimize(reuse, false);
        }

        ///  Run optimization; and report estimated untility upperbound
        public void RunOptimizeReportUtilUB()
        {
            RunOptimize(false, true);
        }

        /** Run optiimzation
        * @param useOldSolver If True, use the eixisting m_Solver pointer without recreate a new solver
        * @param estUtilUB If True, estimate the uppper bound on utility.
        */
        public void RunOptimize(bool useOldSolver, bool estUtilUB)
        {
            if (!useOldSolver)
                m_Solver = m_WS.CreateSolver(m_Case, "GEM");

            // set compatible mode
            if (m_CompatibleMode)
                m_Solver.SetOption("COMPATIBLE_MODE", 1.0);

            // estimate upperbound on utility
            if (estUtilUB)
                m_Solver.SetOption("REPORT_UPPERBOUND_ON_UTILITY", 1.0);

            // opsdata info could be very helpful in debugging using wsptool
            // m_WS.Serialize("opsdata.wsp", true);
            if (m_DumpFilename.Length > 0)
                m_WS.Serialize(m_DumpFilename, true);

            CStatus oStatus = m_Solver.Optimize();

            Console.WriteLine(oStatus.GetMessage());
            Console.WriteLine(m_Solver.GetLogMessage());

            if (oStatus.GetStatusCode() == EStatusCode.eOK)
            {
                CPortfolioOutput output = m_Solver.GetPortfolioOutput();
                CMultiAccountOutput maOutput = m_Solver.GetMultiAccountOutput();
                CMultiPeriodOutput mpOutput = m_Solver.GetMultiPeriodOutput();
                if (output != null)
                    PrintPortfolioOutput(output, estUtilUB);
                else if (maOutput != null)
                    PrintMultiAccountOutput(maOutput);
                else if (mpOutput != null)
                    PrintMultiPeriodOutput(mpOutput);
            } else if (oStatus.GetStatusCode() == EStatusCode.eLICENSE_ERROR)
                throw new InvalidOperationException("Optimizer license error");
        }

		public void PrintPortfolioOutput(CPortfolioOutput output, bool estUtilUB) {
			Console.WriteLine("Optimized Portfolio:");
			Console.WriteLine("Risk(%)     = {0:0.0000}", output.GetRisk());
			Console.WriteLine("Return(%)   = {0:0.0000}", output.GetReturn());
			Console.WriteLine("Utility     = {0:0.0000}", output.GetUtility());
			if (estUtilUB)
			{
				double utilUB = output.GetUpperBoundOnUtility();
				if (utilUB != barraopt.OPT_NAN)
					Console.WriteLine("Util. Upperbound = {0:0.0000}", utilUB);
			};
			Console.WriteLine("Turnover(%) = {0:0.0000}", output.GetTurnover());
			Console.WriteLine("Penalty     = {0:0.0000}", output.GetPenalty());
			Console.WriteLine("TranxCost(%)= {0:0.0000}", output.GetTransactioncost());
			Console.WriteLine("Beta        = {0:0.0000}", output.GetBeta());
            if (output.GetExpectedShortfall() != barraopt.OPT_NAN)
                Console.WriteLine("ExpShortfall(%)= {0:0.0000}", output.GetExpectedShortfall());
            Console.WriteLine();

			// Output the non-zero weight in the optimized portfolio
			Console.WriteLine("Asset Holdings:");
			CPortfolio portfolio = output.GetPortfolio();
			CIDSet idSet = portfolio.GetAssetIDSet();
			String assetID = idSet.GetFirst();

			while (!assetID.Equals(""))
			{
				double weight = portfolio.GetAssetWeight(assetID);
				if (weight != 0)
				{
					Console.WriteLine("{0}: {1:0.0000}", assetID, weight);
				}

				assetID = idSet.GetNext();
			}
			Console.WriteLine();
		}

		public void PrintMultiAccountOutput(CMultiAccountOutput output)
		{
			// Retrieve cross-account output
			CPortfolioOutput pCrossAccountOutput = output.GetCrossAccountOutput();
			CCrossAccountTaxOutput crossAccountTaxOutput = output.GetCrossAccountTaxOutput();
			Console.WriteLine("Account     = Cross-account");
			Console.WriteLine("Return(%)   = {0:0.0000}", pCrossAccountOutput.GetReturn());
			Console.WriteLine("Utility     = {0:0.0000}", pCrossAccountOutput.GetUtility());
			Console.WriteLine("Turnover(%) = {0:0.0000}", pCrossAccountOutput.GetTurnover());
			double jointMarketBuyCost = output.GetJointMarketImpactBuyCost();
			if (jointMarketBuyCost != barraopt.OPT_NAN)
				Console.WriteLine("Joint Market Impact Buy Cost($) = {0:0.0000}", jointMarketBuyCost);
			double jointMarketSellCost = output.GetJointMarketImpactSellCost();
			if (jointMarketSellCost != barraopt.OPT_NAN)
				Console.WriteLine("Joint Market Impact Sell Cost($) = {0:0.0000}", jointMarketSellCost);
			if (crossAccountTaxOutput != null)
				Console.WriteLine("Total Tax   = {0:0.0000}", crossAccountTaxOutput.GetTotalTax());
			Console.WriteLine();

			// Retrieve output for each account group
			if (output.GetNumAccountGroups() > 0) {
				for (int i = 0; i < output.GetNumAccountGroups(); i++) {
					CAccountGroupTaxOutput pGroupOutput = output.GetAccountGroupTaxOutput(i);
					Console.WriteLine("Account Group = {0:D}", pGroupOutput.GetAccountGroupID());
					Console.WriteLine("Total Tax     = {0:0.0000}", pGroupOutput.GetTotalTax());
				}
				Console.WriteLine("");
			}

			// Retrieve output for each account
			for (int i = 0; i < output.GetNumAccounts(); i++)
			{
				CPortfolioOutput pAccountOutput = output.GetAccountOutput(i);
				int accountID = pAccountOutput.GetAccountID();
				Console.WriteLine("Account     = {0:D}", accountID);
				Console.WriteLine("Risk(%)     = {0:0.0000}", pAccountOutput.GetRisk());
				Console.WriteLine("Return(%)   = {0:0.0000}", pAccountOutput.GetReturn());
				Console.WriteLine("Utility     = {0:0.0000}", pAccountOutput.GetUtility());
				Console.WriteLine("Turnover(%) = {0:0.0000}", pAccountOutput.GetTurnover());
				Console.WriteLine("Beta        = {0:0.0000}", pAccountOutput.GetBeta());

				Console.WriteLine("\nAsset Holdings:");
				CPortfolio portfolio = pAccountOutput.GetPortfolio();
				CIDSet idSet = portfolio.GetAssetIDSet();
				for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext())
				{
					double weight = portfolio.GetAssetWeight(assetID);
					if (weight != 0.0)
						Console.WriteLine("{0}: {1:0.0000}", assetID, weight);
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

					   Console.WriteLine("\nTax info for the tax rule group(all assets):");
					   Console.WriteLine("Long Term Gain = {0:0.0000}", lgg_all);
					   Console.WriteLine("Long Term Loss = {0:0.0000}", lgl_all);
					   Console.WriteLine("Short Term Gain = {0:0.0000}", sgg_all);
					   Console.WriteLine("Short Term Loss = {0:0.0000}", sgl_all);
					   Console.WriteLine("Long Term Tax  = {0:0.0000}", ltax);
					   Console.WriteLine("Short Term Tax = {0:0.0000}", stax);

					   Console.WriteLine("\nTotal Tax(for all tax rule groups) = {0:0.0000}\n", taxOut.GetTotalTax());
                    }

					Console.WriteLine("TaxlotID          Shares:");
					for (String assetID = idSet.GetFirst(); assetID != ""; assetID = idSet.GetNext())
					{
						CAttributeSet sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
						CIDSet oLotIDs = sharesInTaxlot.GetKeySet();
						for (String lotID = oLotIDs.GetFirst(); lotID != ""; lotID = oLotIDs.GetNext())
						{
							double shares = sharesInTaxlot.GetValue(lotID);
							if (shares != 0)
								Console.WriteLine("{0}  {1:0.0000}", lotID, shares);
						}
					}

					CAttributeSet newShares = taxOut.GetNewShares();
					PrintAttributeSet(newShares, "\nNew Shares:");
					Console.WriteLine();
				}

			}
		}

		public void PrintMultiPeriodOutput(CMultiPeriodOutput output)
		{
			// Retrieve cross-period output
			CPortfolioOutput pCrossPeriodOutput = output.GetCrossPeriodOutput();
			Console.WriteLine("Period      = Cross-period");
			Console.WriteLine("Return(%)   = {0:0.0000}", pCrossPeriodOutput.GetReturn());
			Console.WriteLine("Utility     = {0:0.0000}", pCrossPeriodOutput.GetUtility());
			Console.WriteLine("Turnover(%) = {0:0.0000}\n", pCrossPeriodOutput.GetTurnover());

			// Retrieve output for each period
			for (int i = 0; i < output.GetNumPeriods(); i++)
			{
				CPortfolioOutput pPeriodOutput = output.GetPeriodOutput(i);
				Console.WriteLine("Period      = {0:D}", pPeriodOutput.GetPeriodID());
				Console.WriteLine("Risk(%)     = {0:0.0000}", pPeriodOutput.GetRisk());
				Console.WriteLine("Return(%)   = {0:0.0000}", pPeriodOutput.GetReturn());
				Console.WriteLine("Utility     = {0:0.0000}", pPeriodOutput.GetUtility());
				Console.WriteLine("Turnover(%) = {0:0.0000}", pPeriodOutput.GetTurnover());
				Console.WriteLine("Beta        = {0:0.0000}\n", pPeriodOutput.GetBeta());
			}
		}

        /** Output trade list
        * @param isOptimalPortfolio If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
        */
        public void OutputTradeList(bool isOptimalPortfolio)
        {
            CPortfolioOutput output = m_Solver.GetPortfolioOutput();
            if (output != null)
            {
                CIDSet oddLotIDSet;
                CPortfolio portfolio;
                if (isOptimalPortfolio)
                {
                    Console.WriteLine("Optimal Portfolio:");
                    portfolio = output.GetPortfolio();
                }
                else
                {
                    Console.WriteLine("Roundlotted Portfolio:");
                    oddLotIDSet = m_WS.CreateIDSet();
                    portfolio = output.GetRoundlottedPortfolio(oddLotIDSet);
                }

                Console.WriteLine("Asset Holdings:");
                CIDSet IDSet = portfolio.GetAssetIDSet();

                String assetID = IDSet.GetFirst();
                while (!assetID.Equals(""))
                {
                    double weight = portfolio.GetAssetWeight(assetID);
                    if (weight != 0)
                        Console.WriteLine("{0}: {1:0.0000}", assetID, weight);
                    assetID = IDSet.GetNext();
                }

                Console.WriteLine();
                Console.WriteLine("Trade List:");
                Console.WriteLine("Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type");

                assetID = IDSet.GetFirst();
                while (!assetID.Equals(""))
                {
                    if (!assetID.Equals("CASH"))
                    {
                        CAssetTradeListInfo tradelistInfo = output.GetAssetTradeListInfo(assetID, isOptimalPortfolio);
                        String tradeType = "";
                        switch (tradelistInfo.GetTradeType())
                        {
                            case ETradeType.eHOLD:
                                tradeType = "Hold";
                                break;
                            case ETradeType.eBUY:
                                tradeType = "Buy";
                                break;
                            case ETradeType.eCOVER_BUY:
                                tradeType = "Cover Buy";
                                break;
                            case ETradeType.eCROSSOVER_BUY:
                                tradeType = "Crossover Buy";
                                break;
                            case ETradeType.eCROSSOVER_SELL:
                                tradeType = "Crossover Sell";
                                break;
                            case ETradeType.eSELL:
                                tradeType = "Sell";
                                break;
                            case ETradeType.eSHORT_SELL:
                                tradeType = "Short Sell";
                                break;
                        }
                        Console.Write("{0}: {1:0.0000}, ", assetID, tradelistInfo.GetInitialShares());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetFinalShares());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetTradedShares());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetPrice());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetTradedValue());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetTradedValuePcnt());
                        Console.Write("{0:0.0000}, ", tradelistInfo.GetTotalTransactionCost());
                        Console.WriteLine("{0} ", tradeType);
                    }
                    assetID = IDSet.GetNext();
                }
                Console.WriteLine();
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

        /** Output elements in a given CAttributeSet object
         * @param attributeSet CAttributeSet object
         * @param title  Name of the attribute set
         * */
        public void PrintAttributeSet(CAttributeSet attributeSet, String title)
        {
            CIDSet idSet = attributeSet.GetKeySet();
            String id = idSet.GetFirst();
            if( !id.Equals("") ){
                Console.WriteLine(title);
                while (!id.Equals("")){
                    Console.WriteLine("{0}: {1:0.0000}", id, attributeSet.GetValue(id));
                    id = idSet.GetNext();
                }
            }
        }

        public void PrintRisksByAsset(CPortfolio portfolio)
        {
	        CIDSet assetIDs = portfolio.GetAssetIDSet();

	        // copy assetIDs for safe iteration (calling EvaluateRisk() might invalidate iterators)
	        CIDSet ids = m_WS.CreateIDSet();
	        for (String id = assetIDs.GetFirst(); id != ""; id = assetIDs.GetNext())
		        ids.Add(id);

	        for (String id = ids.GetFirst(); id != ""; id = ids.GetNext()) {
		        CIDSet idset = m_WS.CreateIDSet();
                idset.Add(id);
                double risk = m_Solver.EvaluateRisk(portfolio, ERiskType.eTOTALRISK, null, idset, null, true, true);
		        if (risk != 0.0)
			        Console.WriteLine("Risk from {0} = {1:0.0000}", id, risk);
                idset.Release();
            }
            ids.Release();
        }


        /** Release resources
        */
        ~TutorialBase()
        {
            m_WS.Dispose();
        }       

	    public void CollectKKT(){
		    CollectKKT(1.0);
	    }
    	
	    public void CollectKKT(double multiplier)
	    {
		    CPortfolioOutput output = m_Solver.GetPortfolioOutput();
		    if ( output != null ){
			    KKTData kkt = new KKTData();
			    //alpha
			    CAttributeSet alphakkt = m_WS.CreateAttributeSet();
			    CPortfolio portfolio = output.GetPortfolio();
			    CIDSet idSet = portfolio.GetAssetIDSet();
			    for (String assetID = idSet.GetFirst(); !assetID.Equals(""); assetID = idSet.GetNext()){
				    double weight = portfolio.GetAssetWeight(assetID);
				    if ( weight != 0.0) 
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
			    for (String slackID = slackInfoIDs.GetFirst(); !slackID.Equals(""); slackID = slackInfoIDs.GetNext() ) {
				    CSlackInfo slackInfo = output.GetSlackInfo(slackID);
				    kkt.AddConstraint(slackInfo.GetKKTTerm(true), slackID,  slackID); //upside
				    kkt.AddOnlyIfDifferent(slackInfo.GetKKTTerm(false), slackID,  slackID); //downside
				    kkt.AddConstraintPenalty(slackInfo.GetPenaltyKKTTerm(true), slackID, slackID+" Penalty"); // upside
				    kkt.AddOnlyIfDifferentPenalty(slackInfo.GetPenaltyKKTTerm(false), slackID, slackID+" Penalty"); // downside
			    }

			    kkt.print();
                Console.WriteLine();
		    }
	    }
    }

    /**\brief Contains shared data structure for a KKT column.
    */
    class KKTCons{
	    public const int KKT_SIDE_DEFAULT = 0;
	    public const int KKT_UPSIDE = 1;
	    public const int KKT_DOWNSIDE = -1;	

	    public String displayName;
	    public String constraintID;
	    public bool isPenalty;
	    public int upOrDownside; 
	    public Dictionary<String, double> weights;

    	
	    public KKTCons(CAttributeSet term, String id, String title, int side, bool pen){
		    constraintID = id;
		    displayName = title;
		    isPenalty = pen;
		    upOrDownside = side;
		    weights = new Dictionary<String, double>();
    		
		    CIDSet idset = term.GetKeySet();
		    for(String asset = idset.GetFirst(); !asset.Equals(""); asset = idset.GetNext() )
			    weights.Add(asset, term.GetValue(asset));
	    }
    	
	    public bool Contains(String id) { return weights.ContainsKey(id); }
        public double Get(String id) { return weights[id]; }
    }

    /**\brief Contains shared class/routines for a KKT table.
    */
    class KKTData{
	    LinkedList<KKTCons> kkt;	

	    public KKTData(){
		    kkt = new LinkedList<KKTCons>();
	    }
    	
	    public void AddConstraint(CAttributeSet attr, String cid, String title, int side){
		    AddConstraint(attr, cid, title, side, false);
	    }
	    public void AddConstraint(CAttributeSet attr, String cid, String title){
		    AddConstraint(attr, cid, title, KKTCons.KKT_SIDE_DEFAULT, false);
	    }

	    public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title, int side){
		    AddOnlyIfDifferent(attr, cid, title, side, false);
	    }
	    public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title){
		    AddOnlyIfDifferent(attr, cid, title, KKTCons.KKT_DOWNSIDE, false);
	    }	
    	
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

	    public void AddConstraint(CAttributeSet attr, String cid, String title, int side, bool pen){
		    CIDSet idset = attr.GetKeySet();

		    // check if it's an empty or all-zero column
		    int i=0;
		    for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
			    // check if id is in the optimal portfolio
			    if((kkt.Count>0) && (!kkt.First.Value.Contains(id)))
				    continue;
			    // larger than display threshold
			    double val = attr.GetValue(id);
			    if (val<0.0) 
				    val = -val;
			    if( val >=1.0e-6) 
				    break;
		    }

		    //not empty
		    if(i!=idset.GetCount())
			    kkt.AddLast(new KKTCons(attr, cid, title, side, pen));
	    }

	    public void AddOnlyIfDifferent(CAttributeSet attr, String cid, String title, int side, bool pen){
		    CIDSet idset = attr.GetKeySet();

		    // check if it's an empty or all-zero column
		    int i=0;
		    for(String id = idset.GetFirst(); i<idset.GetCount(); id = idset.GetNext(), i++ ){
			    double val = attr.GetValue(id);

			    //excludes ids not in the optimal portfolio and same value as the column before
			    if(kkt.Count>0){
				    // check if id is in the optimal portfolio
				    if(kkt.First.Value.Contains(id)){
					    if( val==kkt.Last.Value.Get(id) ) 
						    continue;
				    }else 
					    continue;
			    }
			    // larger than display threshold
			    if (val<0.0) 
				    val = -val;
			    if( val >=1.0e-6) 
				    break;
		    }

		    //not empty
		    if(i!=idset.GetCount()){
			    kkt.Last.Value.upOrDownside = KKTCons.KKT_UPSIDE; // change previous column to upside
			    kkt.AddLast(new KKTCons(attr, cid, title, side, pen));
		    }
	    }

	    public void print()
	    {
		    if(kkt.Count==0)
			    return;
    		
		    Console.WriteLine("Constraint KKT attribution terms"); 
		    // output header of KKT
		    Console.Write("Asset ID");
            foreach( KKTCons cons in kkt ){ 
			    if(cons.upOrDownside != KKTCons.KKT_DOWNSIDE)
                    Console.Write(", " + cons.displayName);
			    if(cons.upOrDownside == KKTCons.KKT_UPSIDE)
				    Console.Write("(up/down)");
		    }

		    Console.Write(Environment.NewLine);

		    // output the weights
		    foreach( KeyValuePair<String, double> pf in kkt.First.Value.weights){
			    Console.Write(pf.Key);
			    foreach( KKTCons cons in kkt ){
				    if( cons.Contains(pf.Key) ){ //there is a value
					    if(cons.upOrDownside == KKTCons.KKT_DOWNSIDE) // merged column
                            Console.Write("/{0:0.000000}" + cons.Get(pf.Key));
					    else
                            Console.Write(", {0:0.000000}", cons.Get(pf.Key));
				    }else if(cons.upOrDownside != KKTCons.KKT_DOWNSIDE)  //there is no value and not a merged column: empty column
					    Console.Write(", ");
			    }
			    Console.Write(Environment.NewLine);
		    }
	    }
    }
}
