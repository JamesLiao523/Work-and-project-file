/** @file TutorialBase.java
* \brief Contains definition of the TutorialBase class with
* the shared routines for all tutorials.
*/

import java.text.*;
import com.barra.openopt.OpenOptimizer;
import com.barra.openopt.protobuf.*;

/**\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
*/
public class TutorialBase 
{
    public TutorialData m_Data;

    public WorkSpace m_WS;
    public Data.Builder m_PBData;
    public Portfolio.Builder m_InitPf;
    public Portfolio.Builder m_BMPortfolio;
    public Portfolio.Builder m_ModelPortfolio;
    public Portfolio.Builder m_TradeUniverse;
    public RiskModel.Builder m_PrimaryRiskModel;
    public RiskModel.Builder m_SecondaryRiskModel;
    public RebalanceProfile.Builder m_Profile;
    public RebalanceJob.Builder m_RebalanceJob;

    public static String m_cashAssetID = "CASH";
    public static String m_alphaAttributeID = "alpha";
    public static String m_priceAttributeID = "price";
    public static String m_roundlotAttributeID = "roundlot";
    public static String m_issuerAttributeID = "issuer";
    public static String m_initialPortfolioID = "Initial Portfolio";
    public static String m_benchmarkPortfolioID = "Benchmark";
    public static String m_modelPortfolioID = "Model";
    public static String m_universePortfolioID = "Trade Universe";
    public static String m_primaryRiskModelID = "GEM";
    public static String m_secondaryRiskModelID = "MODEL2";
    public static DecimalFormat f = new DecimalFormat("0.0000");

	TutorialBase(TutorialData data)
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
	void Initialize( String tutorialID, String description, boolean setAlpha )
	{
		System.out.println("======== Running Tutorial " + tutorialID + 
						   " ========\n" + description + "\n");

        m_WS = null;
        m_SecondaryRiskModel = null;
        m_PBData = Data.newBuilder();

        // Setup asset data
        SetupData(setAlpha);

		// Setup risk model data
		SetupRiskModel();

		// Create initial portfolio etc
		SetupPortfolios();
		
		if ( setAlpha )
			SetAlpha();
	}

    void SetupData(boolean setAlpha)
    {
        AttributeAssignment.Builder attributeAssignBuilder = AttributeAssignment.newBuilder();
        attributeAssignBuilder.setCashAssetId(m_cashAssetID);
        m_PBData.setAttributeAssignment(attributeAssignBuilder);

        if (setAlpha) {
            SetAlpha();
        }
    }

    /// Setup initial portfolio, benchmarks and trade universe
 	void SetupPortfolios()
	{
        // Create an initial portfolio with no cash
        m_InitPf = Portfolio.newBuilder()
            .setPortfolioId(m_initialPortfolioID);
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_InitWeight[i] != 0.0)
                m_InitPf.addHolding(
                    Holding.newBuilder()
                        .setAssetId(m_Data.m_ID[i])
                        .setAmount(m_Data.m_InitWeight[i]));
        }

        m_BMPortfolio = Portfolio.newBuilder()
            .setPortfolioId(m_benchmarkPortfolioID);
        m_ModelPortfolio = Portfolio.newBuilder()
            .setPortfolioId(m_modelPortfolioID);
        m_TradeUniverse = Portfolio.newBuilder()
            .setPortfolioId(m_universePortfolioID);
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_ID[i].compareTo(m_cashAssetID) != 0)
            {
                m_TradeUniverse.addHolding(
                    Holding.newBuilder()
                        .setAssetId(m_Data.m_ID[i])
                        .setAmount(0.0));

                if (m_Data.m_BMWeight[i] != 0.0)
                    m_BMPortfolio.addHolding(
                        Holding.newBuilder()
                            .setAssetId(m_Data.m_ID[i])
                            .setAmount(m_Data.m_BMWeight[i]));

                if (m_Data.m_BM2Weight[i] != 0)
                    m_ModelPortfolio.addHolding(
                        Holding.newBuilder()
                            .setAssetId(m_Data.m_ID[i])
                            .setAmount(m_Data.m_BM2Weight[i]));
            }
        }
	}

	/// Create a workspace and setup risk model data
	void SetupRiskModel()
	{
        // Create Primary Risk Model
        m_PrimaryRiskModel = RiskModel.newBuilder()
                .setRiskModelId(m_primaryRiskModelID)
                .setRiskModelType(ERiskModelType.EQUITY);

        // Load the covariance matrix
        FactorCovariances.Builder covsBuilder = FactorCovariances.newBuilder();
        int count = 0;
        for (int i = 0; i < m_Data.m_FactorNum; i++)
        {
            for (int j = 0; j <= i; j++)
            {
                covsBuilder.addCovariance(
                    FactorCovariance.newBuilder()
                        .setFactorId1(m_Data.m_Factor[i])
                        .setFactorId2(m_Data.m_Factor[j])
                        .setValue(m_Data.m_CovData[count++]));
            }
        }
        m_PrimaryRiskModel.setFactorCovariances(covsBuilder);

        // Load the exposure matrix
        FactorExposures.Builder expMatrixBuilder = FactorExposures.newBuilder();
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            FactorExposure.Builder assetExpBuilder =
                FactorExposure.newBuilder().setAssetId(m_Data.m_ID[i]);

            for (int j = 0; j < m_Data.m_FactorNum; j++)
            {
                assetExpBuilder.addExposure(
                    Exposure.newBuilder()
                        .setFactorId(m_Data.m_Factor[j])
                        .setValue(m_Data.m_ExpData[i][j]));
            }
            expMatrixBuilder.addAssetFactorExposure(assetExpBuilder);
        }
        m_PrimaryRiskModel.setFactorExposures(expMatrixBuilder);

        // Load specific variance
        SpecificVariances.Builder specificVarBuilder = SpecificVariances.newBuilder();
        for (int i = 0; i < m_Data.m_AssetNum; i++) {
            specificVarBuilder.addSpecificVariance(
                SpecificVariance.newBuilder()
                    .setAssetId(m_Data.m_ID[i])
                    .setValue(m_Data.m_SpCov[i]));
        }
        m_PrimaryRiskModel.setSpecificVariances(specificVarBuilder);
	}


	/// Setup a simple sample secondary risk model
	void SetupRiskModel2()
	{
        // Create a risk model
        m_SecondaryRiskModel =
            RiskModel.newBuilder()
                .setRiskModelId(m_secondaryRiskModelID)
                .setRiskModelType(ERiskModelType.EQUITY);

        // Set factor covariances
        FactorCovariances.Builder covsBuilder = FactorCovariances.newBuilder();
        covsBuilder.addCovariance(FactorCovariance.newBuilder()
                                    .setFactorId1("Factor2_1")
                                    .setFactorId2("Factor2_1")
                                    .setValue(1.0));
        covsBuilder.addCovariance(FactorCovariance.newBuilder()
                                    .setFactorId1("Factor2_1")
                                    .setFactorId2("Factor2_2")
                                    .setValue(0.1));
        covsBuilder.addCovariance(FactorCovariance.newBuilder()
                                    .setFactorId1("Factor2_2")
                                    .setFactorId2("Factor2_2")
                                    .setValue(0.5));
        m_SecondaryRiskModel.setFactorCovariances(covsBuilder);

        // Set factor exposures
        FactorExposures.Builder expMatrixBuilder = FactorExposures.newBuilder();
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            FactorExposure.Builder assetExpBuilder =
                FactorExposure.newBuilder().setAssetId(m_Data.m_ID[i]);
            assetExpBuilder.addExposure(Exposure.newBuilder()
                                         .setFactorId("Factor2_1")
                                         .setValue((double)i / (double)m_Data.m_AssetNum));
            assetExpBuilder.addExposure(Exposure.newBuilder()
                                         .setFactorId("Factor2_2")
                                         .setValue((double)(2 * i) / (double)m_Data.m_AssetNum));
            expMatrixBuilder.addAssetFactorExposure(assetExpBuilder);
        }
        m_SecondaryRiskModel.setFactorExposures(expMatrixBuilder);

        // Set specific risk covariance
        SpecificVariances.Builder specificVarBuilder = SpecificVariances.newBuilder();
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
             specificVarBuilder.addSpecificVariance(
                                SpecificVariance.newBuilder()
                                    .setAssetId(m_Data.m_ID[i])
                                    .setValue(0.05));
        }
        m_SecondaryRiskModel.setSpecificVariances(specificVarBuilder);
	}

    /// Set the expected return for each asset in the model
    public void SetAlpha()
    {
        Attribute.Builder attribute = Attribute.newBuilder();
        attribute.setAttributeId(m_alphaAttributeID);
        attribute.setAttributeValueType(AttributeValueType.DOUBLE);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            attribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(m_Data.m_Alpha[i]));
        }
        m_PBData.addAttribute(attribute);
        m_PBData.setAttributeAssignment(m_PBData.getAttributeAssignment().toBuilder()
            .setAlphaAttributeId(m_alphaAttributeID));

    }

    public void SetPrice()
    {
        Attribute.Builder attribute = Attribute.newBuilder();
        attribute.setAttributeId(m_priceAttributeID);
        attribute.setAttributeValueType(AttributeValueType.DOUBLE);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            attribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(m_Data.m_Price[i]));
        }
        m_PBData.addAttribute(attribute);
        m_PBData.setAttributeAssignment(m_PBData.getAttributeAssignment().toBuilder()
            .setPriceAttributeId(m_priceAttributeID));
    }

    public void SetRoundlot(int roundlotSize)
    {
        Attribute.Builder attribute = Attribute.newBuilder();
        attribute.setAttributeId(m_roundlotAttributeID);
        attribute.setAttributeValueType(AttributeValueType.INTEGER);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_ID[i].compareToIgnoreCase("CASH") == 0) //case-insensitive comparison
                continue;

            attribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setIntegerValue(roundlotSize));
        }
        m_PBData.addAttribute(attribute);
        m_PBData.setAttributeAssignment(m_PBData.getAttributeAssignment().toBuilder()
            .setRoundLotSizeAttributeId(m_roundlotAttributeID));
    }

    public void SetIssuer()
    {
        Attribute.Builder attribute = Attribute.newBuilder();
        attribute.setAttributeId(m_issuerAttributeID);
        attribute.setAttributeValueType(AttributeValueType.TEXT);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            attribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setTextValue(m_Data.m_Issuer[i]));
        }
        m_PBData.addAttribute(attribute);
        m_PBData.setAttributeAssignment(m_PBData.getAttributeAssignment().toBuilder()
            .setIssuerAttributeId(m_issuerAttributeID));
    }

    public void SetGICSAttribute(String attributeID)
    {
        Attribute.Builder sectorAttribute = Attribute.newBuilder();
        sectorAttribute.setAttributeId(attributeID);
        sectorAttribute.setAttributeValueType(AttributeValueType.TEXT);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            sectorAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setTextValue(m_Data.m_GICS_Sector[i]));
        }
        m_PBData.addAttribute(sectorAttribute);
    }

    public void SetCoefficientAttribute(String attributeID, double coefficient)
    {
        Attribute.Builder coeffAttribute = Attribute.newBuilder();
        coeffAttribute.setAttributeId(attributeID);
        coeffAttribute.setAttributeValueType(AttributeValueType.DOUBLE);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_ID[i].compareToIgnoreCase("CASH") == 0)
                continue;

            coeffAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(coefficient));
        }
        m_PBData.addAttribute(coeffAttribute);
    }

    public void SetTextAttribute(String attributeID, String value, boolean includeCash)
    {
        Attribute.Builder coeffAttribute = Attribute.newBuilder();
        coeffAttribute.setAttributeId(attributeID);
        coeffAttribute.setAttributeValueType(AttributeValueType.TEXT);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (!includeCash && m_Data.m_ID[i].compareToIgnoreCase("CASH") == 0)
                continue;

            coeffAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setTextValue(value));
        }
        m_PBData.addAttribute(coeffAttribute);
    }

	public void SetGroupingAttribute(String attributeID, String[] assetIDs)
    {
        Attribute.Builder attribute = Attribute.newBuilder();
        attribute.setAttributeId(attributeID);
        attribute.setAttributeValueType(AttributeValueType.TEXT);

        for (String assetID : assetIDs)
        {
            attribute.addElement(Element.newBuilder()
                                    .setElementId(assetID)
                                    .setTextValue(attributeID));
        }
        m_PBData.addAttribute(attribute);

        GroupingScheme.Builder groupingScheme = GroupingScheme.newBuilder();
        groupingScheme.setGroupingSchemeId(attributeID + "_GroupingScheme");
        groupingScheme.addGroup(Group.newBuilder()
            .setGroupId(attributeID + "_Group")
            .addValue(attributeID));
        m_PBData.addGroupingScheme(groupingScheme);
    }

    public void SetPiecewiseLinearTransactionCost()
    {
        TransactionCosts.Builder transactionCost = TransactionCosts.newBuilder();
        // the price is 23.99
        transactionCost.addPiecewiseLinearBuyCost(PiecewiseLinearCost.newBuilder()
            .setAssetId("USA11I1")
            .addCost(Cost.newBuilder() // the 1st 10,000,
                .setSlope(0.002833681)    // the cost rate is 20 basis + 2 cents per share = 0.002 + 0.02/23.99
                .setBreakPoint(10000.0))
            .addCost(Cost.newBuilder() // from 10,000 to +OPT_INF,
                .setSlope(0.003833681)    // the cost rate is 30 basis + 2 cents per share = 0.003 + 0.02/23.99
                .setBreakPoint(GetOPT_INF())));
        transactionCost.addPiecewiseLinearSellCost(PiecewiseLinearCost.newBuilder()
            .setAssetId("USA11I1")
            .addCost(Cost.newBuilder()
                .setSlope(0.003833681)    // Sell cost is 30 basis + 2 cents per share = 0.003 + 0.02/23.99 
                .setBreakPoint(GetOPT_INF())));
        // the price is 34.19
        transactionCost.addPiecewiseLinearBuyCost(PiecewiseLinearCost.newBuilder()
            .setAssetId("USA13Y1")
            .addCost(Cost.newBuilder()
                .setSlope(0.00287745)     // the cost rate is 20 basis + 3 cents per share = 0.002 + 0.03/34.19
                .setBreakPoint(GetOPT_INF())));
        transactionCost.addPiecewiseLinearSellCost(PiecewiseLinearCost.newBuilder()
            .setAssetId("USA13Y1")
            .addCost(Cost.newBuilder()
                .setSlope(0.00387745)     // Sell cost is 30 basis + 3 cents per share = 0.003 + 0.03/34.19
                .setBreakPoint(GetOPT_INF())));
        m_PBData.setTransactionCosts(transactionCost);
    }

    public void SetFixedTransactionCosts()
    {
        Attribute.Builder buyCostAttribute = Attribute.newBuilder();
        buyCostAttribute.setAttributeId("Fixed_Buy_Cost_Attribute");
        buyCostAttribute.setAttributeValueType(AttributeValueType.DOUBLE);

        Attribute.Builder sellCostAttribute = Attribute.newBuilder();
        sellCostAttribute.setAttributeId("Fixed_Sell_Cost_Attribute");
        sellCostAttribute.setAttributeValueType(AttributeValueType.DOUBLE);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_ID[i].compareToIgnoreCase("CASH") != 0)
            {
                buyCostAttribute.addElement(Element.newBuilder()
                                        .setElementId(m_Data.m_ID[i])
                                        .setDoubleValue(0.02));
                sellCostAttribute.addElement(Element.newBuilder()
                                          .setElementId(m_Data.m_ID[i])
                                          .setDoubleValue(0.03));
            }
        }
        m_PBData.addAttribute(buyCostAttribute);
        m_PBData.addAttribute(sellCostAttribute);

        m_PBData.setTransactionCosts(TransactionCosts.newBuilder()
            .setFixedBuyCostAttributeId("Fixed_Buy_Cost_Attribute")
            .setFixedSellCostAttributeId("Fixed_Sell_Cost_Attribute"));
    }

    public void SetShortfalBetaAttribute(String attributeID)
    {
        // Read shortfall beta from a file
        m_Data.ReadShortfallBeta();

        Attribute.Builder sbetaAttribute = Attribute.newBuilder();
        sbetaAttribute.setAttributeId(attributeID);
        sbetaAttribute.setAttributeValueType(AttributeValueType.DOUBLE);

        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (m_Data.m_ID[i].compareToIgnoreCase("CASH") == 0)
                continue;

            sbetaAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(m_Data.m_Shortfall_Beta[i]));
        }
        m_PBData.addAttribute(sbetaAttribute);
    }

    public void SetTaxLots()
    {
        TaxLotInfos.Builder taxLots = TaxLotInfos.newBuilder();
        double[] assetValue = new double[m_Data.m_AssetNum];
		double portfolioValue = 0.0;
        for (int i = 0; i < m_Data.m_Taxlots; i++)
        {
            int iAsset = m_Data.m_Indices[i];
            String assetID = m_Data.m_ID[iAsset];
            double price = m_Data.m_Price[iAsset];
            int age = m_Data.m_Age[i];
            double costBasis = m_Data.m_CostBasis[i];
            double shares = m_Data.m_Shares[i];
            taxLots.addTaxLot(TaxLotInfo.newBuilder()
                .setAssetId(assetID)
                .setAge(age)
                .setCostBasis(costBasis)
                .setShares(shares));
            double lotValue = shares * price;
            assetValue[iAsset] += lotValue;
            portfolioValue += lotValue;
        }
        m_PBData.setTaxLots(taxLots);

        // update initial portfolio holdings
        m_InitPf.clearHolding();
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            m_InitPf.addHolding(
                Holding.newBuilder()
                    .setAssetId(m_Data.m_ID[i])
                    .setAmount(assetValue[i]/portfolioValue));
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
            String assetID = m_Data.m_ID[iAsset];

            for (TaxLotInfo info : m_PBData.getTaxLots().getTaxLotList())
            {
                if (info.getAssetId().equals(assetID))
                {
                    double value = info.getShares() * price;
                    assetValue[iAsset] += value;
                    portfolioValue += value;
                }
            }
        }

        // update initial portfolio holdings
        m_InitPf.clearHolding();
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            m_InitPf.addHolding(
                Holding.newBuilder()
                    .setAssetId(m_Data.m_ID[i])
                    .setAmount(assetValue[i]/portfolioValue));
        }

        return portfolioValue;
    }

    /// Run optiimzation
    public RebalanceResult RunOptimize()
    {
        try {
            if (m_WS == null) {
                WorkSpace.Builder wsBuilder = WorkSpace.newBuilder();
                wsBuilder.addData(m_PBData);
                wsBuilder.setRiskModels(RiskModels.newBuilder()
                    .addRiskmodel(m_PrimaryRiskModel));
                if (m_SecondaryRiskModel != null)
                {
                    wsBuilder.setRiskModels(wsBuilder.getRiskModels().toBuilder()
                        .addRiskmodel(m_SecondaryRiskModel));
                }
                wsBuilder.setPortfolios(Portfolios.newBuilder()
                    .addPortfolio(m_InitPf)
                    .addPortfolio(m_BMPortfolio)
                    .addPortfolio(m_ModelPortfolio)
                    .addPortfolio(m_TradeUniverse));
                wsBuilder.setRebalanceProfiles(RebalanceProfiles.newBuilder()
                    .addRebalanceProfile(m_Profile.build()));
                wsBuilder.setRebalanceJob(m_RebalanceJob.build());
                m_WS = wsBuilder.build();
            }
            else {
                m_WS = m_WS.toBuilder().setRebalanceProfiles(RebalanceProfiles.newBuilder()
                    .addRebalanceProfile(m_Profile.build())).build();
            }

            byte[] input = OpenOptimizer.Run(m_WS.toByteArray());

            RebalanceResult result = RebalanceResult.parseFrom(input);
            return result;
        }
        catch (Exception e)
        {
            System.out.println("Exception caught!");
        }
        return null;
    }

    public void PrintResult(RebalanceResult result)
    {
        System.out.println(result.getOptimizationStatus().getMessage());
        System.out.println(result.getOptimizationStatus().getSolverLog());

        if (result.getPortfolioSummary().getOptimalPortfolioCount() > 0) {
            OptimalPortfolio optimalPf = result.getPortfolioSummary().getOptimalPortfolio(0);
            System.out.println("Optimized Portfolio:");
            System.out.println("Risk(%)     = " + f.format(optimalPf.getTotalRisk()));
            System.out.println("Return(%)   = " + f.format(optimalPf.getReturn()));
            System.out.println("Utility     = " + f.format(optimalPf.getUtility()));
            System.out.println("Turnover(%) = " + f.format(optimalPf.getTurnover()));
            System.out.println("Penalty     = " + f.format(optimalPf.getPenalty()));
            System.out.println("TranxCost(%)= " + f.format(optimalPf.getTransactionCost()));
            System.out.println("Beta        = " + f.format(optimalPf.getBeta()));
            System.out.println();

            // Output the non-zero weight in the optimized portfolio
            System.out.println("Asset Holdings:");
            Portfolio portfolio = optimalPf.getPortfolioHoldings();
            for (Holding holding : portfolio.getHoldingList())
            {
                String assetID = holding.getAssetId();
                if (assetID.compareTo("") != 0)
                {
                    double weight = holding.getAmount();
                    if (weight != 0)
                    {
                        System.out.println(assetID + ": " + f.format(weight));
                    }
                }
            }
        }
        System.out.println();
    }

    public void PrintSlackInfoList(RebalanceResult result)
    {
        if (result.getProfileDiagnosticsCount() > 0)
        {
            ProfileDiagnostics profileDiagnostics = result.getProfileDiagnostics(0);
            for (ConstraintDiagnosticInfo constraintInfo : profileDiagnostics.getConstraintDiagnosticsList())
            {
                System.out.println(constraintInfo.getConstraintInfoId() + " Slack = " + f.format(constraintInfo.getSlackValue()));
            }
        }
    }

    public void PrintSlackInfo(String constraintID, RebalanceResult result)
    {
        if (result.getProfileDiagnosticsCount() > 0)
        {
            ProfileDiagnostics profileDiagnostics = result.getProfileDiagnostics(0);
            for (ConstraintDiagnosticInfo constraintInfo : profileDiagnostics.getConstraintDiagnosticsList())
            {
                if (constraintInfo.getConstraintInfoId().compareToIgnoreCase(constraintID) == 0)
                {

                    System.out.println(constraintID + " Slack = " + f.format(constraintInfo.getSlackValue()));
                    System.out.println();
                }
            }
        }
    }

    /** Output trade list
    */
    public void PrintTradeList(RebalanceResult result)
    {
        if (result.getTradeListCount() > 0) {
            System.out.println();
            System.out.println("Trade List:");
            System.out.println("Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type");

            TradeList tradelist = result.getTradeList(0);
            for (Transaction transaction : tradelist.getTransactionList())
            {
                if (transaction.getAssetId().compareTo("CASH") != 0)
                {
                    System.out.print(transaction.getAssetId() + ": " + f.format(transaction.getInitialShares()) + ", ");
                    System.out.print(f.format(transaction.getFinalShares()) + ", ");
                    System.out.print(f.format(transaction.getTradedShares()) + ", ");
                    System.out.print(f.format(transaction.getPrice()) + ", ");
                    System.out.print(f.format(transaction.getTradedValue()) + ", ");
                    System.out.print(f.format(transaction.getTradedValuePcnt()) + ", ");
                    System.out.print(f.format(transaction.getTotalTransactionCost()) + ", ");
                    System.out.println(transaction.getTradeType().toString());
                }
            }
        }
        System.out.println();
     }


    public void PrintTaxResult(RebalanceResult result)
    {
        if (result.hasPortfolioSummary())
        {
            for (OptimalPortfolio portfolio : result.getPortfolioSummary().getOptimalPortfolioList())
            {
                if (portfolio.hasPortfolioTax())
                {
                    TaxOutput taxOutput = portfolio.getPortfolioTax();
                    for (TaxOutputByGroup taxByGroup : taxOutput.getTaxByGroupList())
                    {
                        String groupName = taxByGroup.getGroupingAttributeId();
                        String groupAttr = taxByGroup.getGroupId();
                        if (groupName.isEmpty() && groupAttr.isEmpty())
                            System.out.println("Tax info for the tax rule group(all assets):");
                        else
                            System.out.println("Tax info for group "+groupName+"/"+groupAttr+":");

                        double longTermGain = 0.0;
                        double shortTermGain = 0.0;
                        double longTermLoss = 0.0;
                        double shortTermLoss = 0.0;

                        for (TaxOutputByCategory taxByCat : taxByGroup.getTaxByCategoryList())
                        {
                            switch (taxByCat.getTaxCategory())
                            {
                                case LONG_TERM:
                                    longTermGain = taxByCat.getGain();
                                    longTermLoss = taxByCat.getLoss();
                                    break;
                                case SHORT_TERM:
                                    shortTermGain = taxByCat.getGain();
                                    shortTermLoss = taxByCat.getLoss();
                                    break;
                            }
                        }

                        System.out.println("Long Term Gain  = " + f.format(longTermGain));
                        System.out.println("Long Term Loss  = " + f.format(longTermLoss));
                        System.out.println("Short Term Gain = " + f.format(shortTermGain));
                        System.out.println("Short Term Loss = " + f.format(shortTermLoss));
                        System.out.println("");
                    }
                    System.out.println("Total Tax(for all tax rule groups) = " + f.format(taxOutput.getTotalTax()));

                    System.out.println("\nTaxlotID          Shares:");
                    for (TaxOutputByAsset taxByAsset : taxOutput.getAssetTaxDetailList())
                    {
                        for (TaxLotShares taxLotShares : taxByAsset.getTaxLotSharesList())
                        {
                            if (taxLotShares.getShares() > 0)
                                System.out.println(taxLotShares.getTaxLotId() + "  " + f.format(taxLotShares.getShares()));
                        }
                    }

                    System.out.println("\nNew Shares:");
                    for (TaxOutputByAsset taxByAsset : taxOutput.getAssetTaxDetailList())
                    {
                        if (taxByAsset.getNewShares() > 0)
                            System.out.println(taxByAsset.getAssetId() + ":  " + f.format(taxByAsset.getNewShares()));
                    }
                    System.out.println("");
                }
            }
        }
    }
}
