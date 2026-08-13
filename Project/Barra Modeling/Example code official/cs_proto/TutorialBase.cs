/** @file TutorialBase.cs
* \brief Contains definition of the TutorialBase class with
* the shared routines for all tutorials.
*/

using System;
using System.IO;
using optimizer.proto;
using Google.ProtocolBuffers;

namespace Tutorial_CS_Protobuf
{
    /**\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
    */
    class TutorialBase
    {
        public TutorialData m_Data;

        public WorkSpace.Builder m_WS;
        public Data.Builder m_PBData;
        public Portfolio.Builder m_InitPf;
        public Portfolio.Builder m_BMPortfolio;
        public Portfolio.Builder m_ModelPortfolio;
        public Portfolio.Builder m_TradeUniverse;
        public RiskModel.Builder m_PrimaryRiskModel;
        public RiskModel.Builder m_SecondaryRiskModel;
        public RebalanceProfile.Builder m_Profile;
        public RebalanceJob.Builder m_RebalanceJob;

        public const string m_cashAssetID = "CASH";
        public const string m_alphaAttributeID = "alpha";
        public const string m_priceAttributeID = "price";
        public const string m_roundlotAttributeID = "roundlot";
        public const string m_issuerAttributeID = "issuer";
        public const string m_initialPortfolioID = "Initial Portfolio";
        public const string m_benchmarkPortfolioID = "Benchmark";
        public const string m_modelPortfolioID = "Model";
        public const string m_universePortfolioID = "Trade Universe";
        public const string m_primaryRiskModelID = "GEM";
        public const string m_secondaryRiskModelID = "MODEL2";

        public TutorialBase(TutorialData data)
        {
            m_Data = data;
        }

        public double GetOPT_INF()
        {
            return 1000000000.0;
        }

        /// Initialize the optimization
        public void Initialize(String tutorialID, String description)
        {
            Initialize(tutorialID, description, false);
        }

        /// Initialize the optimization
        public void Initialize(String tutorialID, String description, bool setAlpha)
        {
            Console.WriteLine("======== Running Tutorial " + tutorialID +
                               " ========\r\n" + description + "\r\n");
            
            m_WS = WorkSpace.CreateBuilder();
            m_PBData = Data.CreateBuilder();

            // Setup asset data
            SetupData(setAlpha);

            // Setup risk model data
            SetupRiskModel();

            // Create initial portfolio etc
            SetupPortfolios();
        }

        public void SetupData(bool setAlpha)
        {
            AttributeAssignment.Builder attributeAssignBuilder = AttributeAssignment.CreateBuilder();
            attributeAssignBuilder.SetCashAssetId(m_cashAssetID);
            m_PBData.SetAttributeAssignment(attributeAssignBuilder);
            
            if (setAlpha) {
                SetAlpha();
            }
        }

        /// Setup initial portfolio, benchmarks and trade universe
        public void SetupPortfolios()
        {
            // Create an initial portfolio with no cash
            m_InitPf = Portfolio.CreateBuilder()
                .SetPortfolioId(m_initialPortfolioID);
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (m_Data.m_InitWeight[i] != 0.0)
                    m_InitPf.AddHolding(
                        Holding.CreateBuilder()
                            .SetAssetId(m_Data.m_ID[i])
                            .SetAmount(m_Data.m_InitWeight[i]));
            }

            m_BMPortfolio = Portfolio.CreateBuilder()
                .SetPortfolioId(m_benchmarkPortfolioID);
            m_ModelPortfolio = Portfolio.CreateBuilder()
                .SetPortfolioId(m_modelPortfolioID);
            m_TradeUniverse = Portfolio.CreateBuilder()
                .SetPortfolioId(m_universePortfolioID);
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!m_Data.m_ID[i].Equals(m_cashAssetID))
                {
                    m_TradeUniverse.AddHolding(
                        Holding.CreateBuilder()
                            .SetAssetId(m_Data.m_ID[i])
                            .SetAmount(0.0));

                    if (m_Data.m_BMWeight[i] != 0.0)
                        m_BMPortfolio.AddHolding(
                            Holding.CreateBuilder()
                                .SetAssetId(m_Data.m_ID[i])
                                .SetAmount(m_Data.m_BMWeight[i]));

                    if (m_Data.m_BM2Weight[i] != 0)
                        m_ModelPortfolio.AddHolding(
                            Holding.CreateBuilder()
                                .SetAssetId(m_Data.m_ID[i])
                                .SetAmount(m_Data.m_BM2Weight[i]));
                }
            }
        }

        /// Setup risk model data
        public void SetupRiskModel()
        {
            // Create Primary Risk Model
            m_PrimaryRiskModel = RiskModel.CreateBuilder()
                    .SetRiskModelId(m_primaryRiskModelID)
                    .SetRiskModelType(ERiskModelType.EQUITY);
            
            // Load the covariance matrix
            FactorCovariances.Builder covsBuilder = FactorCovariances.CreateBuilder();
            int count = 0;
            for (int i = 0; i < m_Data.m_FactorNum; i++)
            {
                for (int j = 0; j <= i; j++)
                {
                    covsBuilder.AddCovariance(
                        FactorCovariance.CreateBuilder()
                            .SetFactorId1(m_Data.m_Factor[i])
                            .SetFactorId2(m_Data.m_Factor[j])
                            .SetValue(m_Data.m_CovData[count++]));
                }
            }
            m_PrimaryRiskModel.SetFactorCovariances(covsBuilder);
            
            // Load the exposure matrix
            FactorExposures.Builder expMatrixBuilder = FactorExposures.CreateBuilder();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                FactorExposure.Builder assetExpBuilder = 
                    FactorExposure.CreateBuilder().SetAssetId(m_Data.m_ID[i]);

                for (int j = 0; j < m_Data.m_FactorNum; j++)
                {
                    assetExpBuilder.AddExposure(
                        Exposure.CreateBuilder()
                            .SetFactorId(m_Data.m_Factor[j])
                            .SetValue(m_Data.m_ExpData[i, j]));
                }
                expMatrixBuilder.AddAssetFactorExposure(assetExpBuilder);
            }
            m_PrimaryRiskModel.SetFactorExposures(expMatrixBuilder);

            // Load specific variance
            SpecificVariances.Builder specificVarBuilder = SpecificVariances.CreateBuilder();
            for (int i = 0; i < m_Data.m_AssetNum; i++) {
                specificVarBuilder.AddSpecificVariance(
                    SpecificVariance.CreateBuilder()
                        .SetAssetId(m_Data.m_ID[i])
                        .SetValue(m_Data.m_SpCov[i]));
            }
            m_PrimaryRiskModel.SetSpecificVariances(specificVarBuilder);
        }

        /// Setup a simple sample secondary risk model
        public void SetupRiskModel2()
        {
            // Create a risk model
            m_SecondaryRiskModel =
                RiskModel.CreateBuilder()
                    .SetRiskModelId(m_secondaryRiskModelID)
                    .SetRiskModelType(ERiskModelType.EQUITY);

            // Set factor covariances 
            FactorCovariances.Builder covsBuilder = FactorCovariances.CreateBuilder();
            covsBuilder.AddCovariance(FactorCovariance.CreateBuilder()
                                        .SetFactorId1("Factor2_1")
                                        .SetFactorId2("Factor2_1")
                                        .SetValue(1.0));
            covsBuilder.AddCovariance(FactorCovariance.CreateBuilder()
                                        .SetFactorId1("Factor2_1")
                                        .SetFactorId2("Factor2_2")
                                        .SetValue(0.1));
            covsBuilder.AddCovariance(FactorCovariance.CreateBuilder()
                                        .SetFactorId1("Factor2_2")
                                        .SetFactorId2("Factor2_2")
                                        .SetValue(0.5));
            m_SecondaryRiskModel.SetFactorCovariances(covsBuilder);

            // Set factor exposures 
            FactorExposures.Builder expMatrixBuilder = FactorExposures.CreateBuilder();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                FactorExposure.Builder assetExpBuilder =
                    FactorExposure.CreateBuilder().SetAssetId(m_Data.m_ID[i]);
                assetExpBuilder.AddExposure(Exposure.CreateBuilder()
                                             .SetFactorId("Factor2_1")
                                             .SetValue((double)i / (double)m_Data.m_AssetNum));
                assetExpBuilder.AddExposure(Exposure.CreateBuilder()
                                             .SetFactorId("Factor2_2")
                                             .SetValue((double)(2 * i) / (double)m_Data.m_AssetNum));
                expMatrixBuilder.AddAssetFactorExposure(assetExpBuilder);
            }
            m_SecondaryRiskModel.SetFactorExposures(expMatrixBuilder);

            // Set specific risk covariance
            SpecificVariances.Builder specificVarBuilder = SpecificVariances.CreateBuilder();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                 specificVarBuilder.AddSpecificVariance(
                                    SpecificVariance.CreateBuilder()
                                        .SetAssetId(m_Data.m_ID[i])
                                        .SetValue(0.05));
            }
            m_SecondaryRiskModel.SetSpecificVariances(specificVarBuilder);
        }

        /// Set the expected return for each asset in the model
        public void SetAlpha()
        {
            optimizer.proto.Attribute.Builder attribute = optimizer.proto.Attribute.CreateBuilder();
            attribute.SetAttributeId(m_alphaAttributeID);
            attribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                attribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(m_Data.m_Alpha[i]));
            }
            m_PBData.AddAttribute(attribute);
            m_PBData.SetAttributeAssignment(m_PBData.AttributeAssignment.ToBuilder()
                .SetAlphaAttributeId(m_alphaAttributeID));
            
        }

        public void SetPrice()
        {
            optimizer.proto.Attribute.Builder attribute = optimizer.proto.Attribute.CreateBuilder();
            attribute.SetAttributeId(m_priceAttributeID);
            attribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                attribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(m_Data.m_Price[i]));
            }
            m_PBData.AddAttribute(attribute);
            m_PBData.SetAttributeAssignment(m_PBData.AttributeAssignment.ToBuilder()
                .SetPriceAttributeId(m_priceAttributeID));
        }

        public void SetRoundlot(int roundlotSize)
        {
            optimizer.proto.Attribute.Builder attribute = optimizer.proto.Attribute.CreateBuilder();
            attribute.SetAttributeId(m_roundlotAttributeID);
            attribute.SetAttributeValueType(AttributeValueType.INTEGER);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (string.Compare(m_Data.m_ID[i], "CASH", true) == 0) //case-insensitive comparison
                    continue;

                attribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetIntegerValue(roundlotSize));
            }
            m_PBData.AddAttribute(attribute);
            m_PBData.SetAttributeAssignment(m_PBData.AttributeAssignment.ToBuilder()
                .SetRoundLotSizeAttributeId(m_roundlotAttributeID));
        }

        public void SetIssuer()
        {
            optimizer.proto.Attribute.Builder attribute = optimizer.proto.Attribute.CreateBuilder();
            attribute.SetAttributeId(m_issuerAttributeID);
            attribute.SetAttributeValueType(AttributeValueType.TEXT);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                attribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetTextValue(m_Data.m_Issuer[i]));
            }
            m_PBData.AddAttribute(attribute);
            m_PBData.SetAttributeAssignment(m_PBData.AttributeAssignment.ToBuilder()
                .SetIssuerAttributeId(m_issuerAttributeID));
        }

        public void SetGICSAttribute(string attributeID)
        {
            optimizer.proto.Attribute.Builder sectorAttribute = optimizer.proto.Attribute.CreateBuilder();
            sectorAttribute.SetAttributeId(attributeID);
            sectorAttribute.SetAttributeValueType(AttributeValueType.TEXT);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                sectorAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetTextValue(m_Data.m_GICS_Sector[i]));
            }
            m_PBData.AddAttribute(sectorAttribute);
        }

        public void SetCoefficientAttribute(string attributeID, double coefficient)
        {
            optimizer.proto.Attribute.Builder coeffAttribute = optimizer.proto.Attribute.CreateBuilder();
            coeffAttribute.SetAttributeId(attributeID);
            coeffAttribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (m_Data.m_ID[i].Equals("CASH"))
                    continue;

                coeffAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(coefficient));
            }
            m_PBData.AddAttribute(coeffAttribute);
        }

        public void SetTextAttribute(string attributeID, string value, bool includeCash)
        {
            optimizer.proto.Attribute.Builder coeffAttribute = optimizer.proto.Attribute.CreateBuilder();
            coeffAttribute.SetAttributeId(attributeID);
            coeffAttribute.SetAttributeValueType(AttributeValueType.TEXT);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!includeCash && m_Data.m_ID[i].Equals("CASH"))
                    continue;

                coeffAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetTextValue(value));
            }
            m_PBData.AddAttribute(coeffAttribute);
        }

        public void SetGroupingAttribute(string attributeID, string[] assetIDs)
        {
            optimizer.proto.Attribute.Builder attribute = optimizer.proto.Attribute.CreateBuilder();
            attribute.SetAttributeId(attributeID);
            attribute.SetAttributeValueType(AttributeValueType.TEXT);

            foreach (string assetID in assetIDs)
            {
                attribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(assetID)
                                        .SetTextValue(attributeID));
            }
            m_PBData.AddAttribute(attribute);

            GroupingScheme.Builder groupingScheme = GroupingScheme.CreateBuilder();
            groupingScheme.SetGroupingSchemeId(attributeID + "_GroupingScheme");
            groupingScheme.AddGroup(Group.CreateBuilder()
                .SetGroupId(attributeID + "_Group")
                .AddValue(attributeID));
            m_PBData.AddGroupingScheme(groupingScheme);
        }

        public void SetPiecewiseLinearTransactionCost()
        {
            TransactionCosts.Builder transactionCost = TransactionCosts.CreateBuilder();
            // the price is 23.99
            transactionCost.AddPiecewiseLinearBuyCost(PiecewiseLinearCost.CreateBuilder()
                .SetAssetId("USA11I1")
                .AddCost(Cost.CreateBuilder() // the 1st 10,000, 
                    .SetSlope(0.002833681)    // the cost rate is 20 basis + 2 cent per share = 0.002 + 0.02/23.99
                    .SetBreakPoint(10000.0))
                .AddCost(Cost.CreateBuilder() // from 10,000 to +OPT_INF, 
                    .SetSlope(0.003833681)    // the cost rate is 30 basis + 2 cent per share = 0.003 + 0.02/23.99
                    .SetBreakPoint(GetOPT_INF())));
            transactionCost.AddPiecewiseLinearSellCost(PiecewiseLinearCost.CreateBuilder()
                .SetAssetId("USA11I1")
                .AddCost(Cost.CreateBuilder()
                    .SetSlope(0.003833681)    // Sell cost is 30 basis + 2 cent per share = 0.003 + 0.02/23.99
                    .SetBreakPoint(GetOPT_INF())));
            // the price is 34.19
            transactionCost.AddPiecewiseLinearBuyCost(PiecewiseLinearCost.CreateBuilder()
                .SetAssetId("USA13Y1")
                .AddCost(Cost.CreateBuilder()
                    .SetSlope(0.00287745)     // the cost rate is 20 basis + 3 cent per share = 0.002 + 0.03/34.19
                    .SetBreakPoint(GetOPT_INF())));
            transactionCost.AddPiecewiseLinearSellCost(PiecewiseLinearCost.CreateBuilder()
                .SetAssetId("USA13Y1")
                .AddCost(Cost.CreateBuilder()
                    .SetSlope(0.00387745)     // Sell cost is 30 basis + 3 cent per share = 0.003 + 0.03/34.19
                    .SetBreakPoint(GetOPT_INF())));
            m_PBData.SetTransactionCosts(transactionCost);
        }

        public void SetFixedTransactionCosts()
        {
            optimizer.proto.Attribute.Builder buyCostAttribute = optimizer.proto.Attribute.CreateBuilder();
            buyCostAttribute.SetAttributeId("Fixed_Buy_Cost_Attribute");
            buyCostAttribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            optimizer.proto.Attribute.Builder sellCostAttribute = optimizer.proto.Attribute.CreateBuilder();
            sellCostAttribute.SetAttributeId("Fixed_Sell_Cost_Attribute");
            sellCostAttribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (!m_Data.m_ID[i].Equals("CASH"))
                {
                    buyCostAttribute.AddElement(Element.CreateBuilder()
                                            .SetElementId(m_Data.m_ID[i])
                                            .SetDoubleValue(0.02));
                    sellCostAttribute.AddElement(Element.CreateBuilder()
                                              .SetElementId(m_Data.m_ID[i])
                                              .SetDoubleValue(0.03));
                }
            }
            m_PBData.AddAttribute(buyCostAttribute);
            m_PBData.AddAttribute(sellCostAttribute);

            m_PBData.SetTransactionCosts(TransactionCosts.CreateBuilder()
                .SetFixedBuyCostAttributeId("Fixed_Buy_Cost_Attribute")
                .SetFixedSellCostAttributeId("Fixed_Sell_Cost_Attribute"));
        }

        public void SetShortfalBetaAttribute(string attributeID)
        {
            // Read shortfall beta from a file
            m_Data.ReadShortfallBeta();

            optimizer.proto.Attribute.Builder sbetaAttribute = optimizer.proto.Attribute.CreateBuilder();
            sbetaAttribute.SetAttributeId(attributeID);
            sbetaAttribute.SetAttributeValueType(AttributeValueType.DOUBLE);

            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (m_Data.m_ID[i].Equals("CASH"))
                    continue;

                sbetaAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(m_Data.m_Shortfall_Beta[i]));
            }
            m_PBData.AddAttribute(sbetaAttribute);
        }

        public void SetTaxLots()
        {
            optimizer.proto.TaxLotInfos.Builder taxLots = optimizer.proto.TaxLotInfos.CreateBuilder();
            double[] assetValue = new double[m_Data.m_AssetNum];
            double portfolioValue = 0.0;
            for (int i = 0; i < m_Data.m_Taxlots; i++)
            {
                int iAsset = m_Data.m_Indices[i];
                string assetID = m_Data.m_ID[iAsset];
                double price = m_Data.m_Price[iAsset];
                int age = m_Data.m_Age[i];
                double costBasis = m_Data.m_CostBasis[i];
                double shares = m_Data.m_Shares[i];
                taxLots.AddTaxLot(optimizer.proto.TaxLotInfo.CreateBuilder()
                    .SetAssetId(assetID)
                    .SetAge(age)
                    .SetCostBasis(costBasis)
                    .SetShares(shares));
                double lotValue = shares * price;
                assetValue[iAsset] += lotValue;
                portfolioValue += lotValue;
            }
            m_PBData.SetTaxLots(taxLots);

            // update initial portfolio holdings
            m_InitPf.ClearHolding();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                m_InitPf.AddHolding(
                    Holding.CreateBuilder()
                        .SetAssetId(m_Data.m_ID[i])
                        .SetAmount(assetValue[i]/portfolioValue));
            }
        }

        /// Calculate portfolio weights and values from tax lot data, return portfolio value.
        public double UpdatePortfolioWeights()
        {
            double[] assetValue = new double[m_Data.m_AssetNum];
            double portfolioValue = 0.0;
            for (int iAsset = 0; iAsset < m_Data.m_AssetNum; iAsset++)
            {
                double price = m_Data.m_Price[iAsset];
                string assetID = m_Data.m_ID[iAsset];

                foreach (optimizer.proto.TaxLotInfo info in m_PBData.TaxLots.TaxLotList)
                {
                    if (info.AssetId == assetID)
                    {
                        double value = info.Shares * price;
                        assetValue[iAsset] += value;
                        portfolioValue += value;
                    }
                }
            }

            // update initial portfolio holdings
            m_InitPf.ClearHolding();
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                m_InitPf.AddHolding(
                    Holding.CreateBuilder()
                        .SetAssetId(m_Data.m_ID[i])
                        .SetAmount(assetValue[i] / portfolioValue));
            }

            return portfolioValue;
        }

        /// Run optiimzation
        public RebalanceResult RunOptimize()
        {
            FileStream outputStream = File.Open("workspace.pb", FileMode.Create);
            m_WS.AddData(m_PBData);
            m_WS.SetRiskModels(RiskModels.CreateBuilder()
                .AddRiskmodel(m_PrimaryRiskModel));
            if (m_SecondaryRiskModel != null)
            {
                m_WS.SetRiskModels(m_WS.RiskModels.ToBuilder()
                    .AddRiskmodel(m_SecondaryRiskModel));
            }
            m_WS.SetPortfolios(Portfolios.CreateBuilder()
                .AddPortfolio(m_InitPf)
                .AddPortfolio(m_BMPortfolio)
                .AddPortfolio(m_ModelPortfolio)
                .AddPortfolio(m_TradeUniverse));
            m_WS.SetRebalanceProfiles(RebalanceProfiles.CreateBuilder()
                .AddRebalanceProfile(m_Profile.Build()));
            m_WS.SetRebalanceJob(m_RebalanceJob.Build());

            WorkSpace ws = m_WS.Build();
            ws.WriteTo(outputStream);
            outputStream.Close();
/*
            //FileStream testStream = File.Open("workspace.pb", FileMode.Open);
            //WorkSpace.Builder workspaceBuilder = WorkSpace.CreateBuilder().MergeFrom(testStream);
            //Console.WriteLine(workspaceBuilder.Build().ToString());
            byte[] wsBytes = ws.ToByteArray();
            string str;
            OpenOptimizer.Run(wsBytes, (uint)wsBytes.Length, out str);

            RebalanceResult result2 = RebalanceResult.ParseFrom(bytes);
            Console.WriteLine(str);
*/
            EStatusCode status = OpenOptimizer.Run("workspace.pb", "result.pb");
             FileStream inputStream = File.Open("result.pb", FileMode.Open);
 
             RebalanceResult result = RebalanceResult.ParseFrom(inputStream);
             inputStream.Close();
             return result;
        }

        public void PrintResult(RebalanceResult result)
        {
            Console.WriteLine(result.OptimizationStatus.Message);
            Console.WriteLine(result.OptimizationStatus.SolverLog);

            if (result.PortfolioSummary.OptimalPortfolioCount > 0) {
                OptimalPortfolio optimalPf = result.PortfolioSummary.OptimalPortfolioList[0];
                Console.WriteLine("Optimized Portfolio:");
                Console.WriteLine("Risk(%)     = {0:0.0000}", optimalPf.TotalRisk);
                Console.WriteLine("Return(%)   = {0:0.0000}", optimalPf.Return);
                Console.WriteLine("Utility     = {0:0.0000}", optimalPf.Utility);
                Console.WriteLine("Turnover(%) = {0:0.0000}", optimalPf.Turnover);
                Console.WriteLine("Penalty     = {0:0.0000}", optimalPf.Penalty);
                Console.WriteLine("TranxCost(%)= {0:0.0000}", optimalPf.TransactionCost);
                Console.WriteLine("Beta        = {0:0.0000}", optimalPf.Beta);
                Console.WriteLine();

                // Output the non-zero weight in the optimized portfolio
                Console.WriteLine("Asset Holdings:");
                Portfolio portfolio = optimalPf.PortfolioHoldings;
                foreach (Holding holding in portfolio.HoldingList)
                {
                    String assetID = holding.AssetId;
                    if (!assetID.Equals(""))
                    {
                        double weight = holding.Amount;
                        if (weight != 0)
                        {
                            Console.WriteLine("{0}: {1:0.0000}", assetID, weight);
                        }
                    }
                }
            }
            Console.WriteLine();
        }

        public void PrintSlackInfoList(RebalanceResult result)
        {
            if (result.ProfileDiagnosticsCount > 0)
            {
                ProfileDiagnostics profileDiagnostics = result.GetProfileDiagnostics(0);
                foreach (ConstraintDiagnosticInfo constraintInfo in profileDiagnostics.ConstraintDiagnosticsList)
                {
                    Console.WriteLine("{0} Slack = {1:0.0000}",
                        constraintInfo.ConstraintInfoId, constraintInfo.SlackValue);
                }
            }
        }

        public void PrintSlackInfo(string constraintID, RebalanceResult result)
        {
            if (result.ProfileDiagnosticsCount > 0)
            {
                ProfileDiagnostics profileDiagnostics = result.GetProfileDiagnostics(0);
                foreach (ConstraintDiagnosticInfo constraintInfo in profileDiagnostics.ConstraintDiagnosticsList)
                {
                    if (constraintInfo.ConstraintInfoId.Equals(constraintID))
                    {
                        Console.WriteLine(constraintID + " Slack = {0:0.0000}",
                                              constraintInfo.SlackValue);
                        Console.WriteLine();
                    }
                }
            }
        }

        /** Output trade list
        * @param isOptimalPortfolio If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
        */
        public void PrintTradeList(RebalanceResult result)
        {
            if (result.TradeListCount > 0) {
                Console.WriteLine();
                Console.WriteLine("Trade List:");
                Console.WriteLine("Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type");

                TradeList tradelist = result.GetTradeList(0);
                foreach (Transaction transaction in tradelist.TransactionList)
                {
                    if (!transaction.AssetId.Equals("CASH"))
                    {
                        Console.Write("{0}: {1:0.0000}, ", transaction.AssetId, transaction.InitialShares);
                        Console.Write("{0:0.0000}, ", transaction.FinalShares);
                        Console.Write("{0:0.0000}, ", transaction.TradedShares);
                        Console.Write("{0:0.0000}, ", transaction.Price);
                        Console.Write("{0:0.0000}, ", transaction.TradedValue);
                        Console.Write("{0:0.0000}, ", transaction.TradedValuePcnt);
                        Console.Write("{0:0.0000}, ", transaction.TotalTransactionCost);
                        Console.WriteLine("{0} ", transaction.TradeType.ToString());
                    }
                }
            }
            Console.WriteLine();
         }

        public void PrintTaxResult(RebalanceResult result)
        {
            if (result.HasPortfolioSummary)
            {
                foreach (OptimalPortfolio portfolio in result.PortfolioSummary.OptimalPortfolioList)
                {
                    if (portfolio.HasPortfolioTax)
                    {
                        TaxOutput taxOutput = portfolio.PortfolioTax;
                        foreach (TaxOutputByGroup taxByGroup in taxOutput.TaxByGroupList)
                        {
                            string groupName = taxByGroup.GroupingAttributeId;
                            string groupAttr = taxByGroup.GroupId;
                            if (groupName == "" && groupAttr == "")
                                Console.WriteLine("Tax info for the tax rule group(all assets):");
                            else
                                Console.WriteLine("Tax info for group {0}/{1}:", groupName, groupAttr);

                            double longTermGain = 0.0;
                            double shortTermGain = 0.0;
                            double longTermLoss = 0.0;
                            double shortTermLoss = 0.0;

                            foreach (TaxOutputByCategory taxByCat in taxByGroup.TaxByCategoryList)
                            {
                                switch (taxByCat.TaxCategory)
                                {
                                    case ETaxCategory.LONG_TERM:
                                        longTermGain = taxByCat.Gain;
                                        longTermLoss = taxByCat.Loss;
                                        break;
                                    case ETaxCategory.SHORT_TERM:
                                        shortTermGain = taxByCat.Gain;
                                        shortTermLoss = taxByCat.Loss;
                                        break;
                                }
                            }

                            Console.WriteLine("Long Term Gain  = {0:0.0000}", longTermGain);
                            Console.WriteLine("Long Term Loss  = {0:0.0000}", longTermLoss);
                            Console.WriteLine("Short Term Gain = {0:0.0000}", shortTermGain);
                            Console.WriteLine("Short Term Loss = {0:0.0000}", shortTermLoss);
                            Console.WriteLine("");
                        }
                        Console.WriteLine("Total Tax(for all tax rule groups) = {0:0.0000}", taxOutput.TotalTax);

                        Console.WriteLine("\nTaxlotID          Shares:");
                        foreach (TaxOutputByAsset taxByAsset in taxOutput.AssetTaxDetailList)
                        {
                            foreach (TaxLotShares taxLotShares in taxByAsset.TaxLotSharesList)
                            {
                                if (taxLotShares.Shares > 0)
                                    Console.WriteLine("{0}  {1:0.0000}", taxLotShares.TaxLotId, taxLotShares.Shares);
                            }
                        }

                        Console.WriteLine("\nNew Shares:");
                        foreach (TaxOutputByAsset taxByAsset in taxOutput.AssetTaxDetailList)
                        {
                            if (taxByAsset.NewShares > 0)
                                Console.WriteLine("{0}:  {1:0.0000}", taxByAsset.AssetId, taxByAsset.NewShares);
                        }
                        Console.WriteLine("");
                    }
                }

            }
        }

        /** Output elements in a given CAttributeSet object
         * @param attributeSet CAttributeSet object
         * @param title  Name of the attribute set
         * */
 /*       public void PrintAttributeSet(CAttributeSet attributeSet, String title)
        {
	        Console.WriteLine(title);
            CIDSet idSet = attributeSet.GetKeySet();

            String id = idSet.GetFirst();
	        while (!id.Equals("")){
                Console.WriteLine("{0}: {1:0.0000000}", id, attributeSet.GetValue(id));
                id = idSet.GetNext();
            }
        }
  */ 
    }   
}
