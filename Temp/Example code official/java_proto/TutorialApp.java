/** @file TutorialApp.java
* \brief Contains definitions of the CTutorialApp class with specific code for
* each of tutorials.
*/

import com.barra.openopt.protobuf.*;

import java.io.FileInputStream;

/**\brief Contains specific code for each of the tutorials
*/
public class TutorialApp extends TutorialBase
{
	TutorialApp(TutorialData data)
	{
		super(data);
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 1a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 1a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
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
        // Create WorkSpace and setup Risk Model data,
        // Create initial portfolio, etc; set alpha
        Initialize("1b", "Maximize Return and Minimize Total Risk", true);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 1b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 1b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 1c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)  // set benchmark in utility
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 1c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
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
	* base value of the the portfolio.  The roundlot constraint may result in 
	* infeasible solutions so the user can either relax the constraints or
	* round lot the optimization result in the client application (though 
	* this may result in a "less optimal" portfolio).
	* 
	* This sample code Tutorial_1d is modified from Tutorial_1a to illustrate 
	* how to set-up roundlotting:
	*/
    public void Tutorial_1d()
    {
        Initialize("1d", "Roundlotting", true);

        // Set price as required by roundlotting
        SetPrice();

        // Set lot size to 20
        SetRoundlot(20);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 1d");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));
        // Enable Roundlotting; do not allow odd lot clostout
        m_Profile.setRoundlotConstraint(RoundlotConstraint.newBuilder()
            .setAllowOddLotCloseout(false)
            .setIsSoft(false));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 1d");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(10000000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
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
        m_InitPf.addHolding(Holding.newBuilder()
            .setAssetId("CASH")
            .setAmount(1.0));

        // Set price as required by roundlotting
        SetPrice();

        // Set lot size to 1000
        SetRoundlot(1000);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 1e");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 1e");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setPortfolioBaseValue(10000000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintTradeList(result);
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 2c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 2c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setCashflowWeight(0.2);    // 20% cash contribution
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /**\brief Asset Bound Constraints
    *
    * Asset bound constraint is to limit the weight of some asset in the optimal portfolio.
    * You can set the upper and lower bound of the range. The default is from -OPT_INF to +OPT_INF.
    *
    * By setting the range of the assets, you can implement various transaction strategies.
    * For instance, you can disallow selling an asset by setting the lower bound of the
    * constraint to the initial weight.
    *
    * In Tutorial_3a, we want to limit the maximum weight of any asset in the optimal
    * portfolio to be 30%.
    */
    public void Tutorial_3a()
    {
        Initialize("3a", "Asset Bounds");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set asset bounds
        LinearConstraint.Builder linearConstraint = LinearConstraint.newBuilder();
        linearConstraint.setNoncashAssetBound(NonCashAssetBoundInfo.newBuilder()
            .setLowerBound(0.0)
            .setUpperBound(0.3));

        // Set cash bound
        m_InitPf.addHolding(Holding.newBuilder()
            .setAssetId("CASH")
            .setAmount(0.2));
        linearConstraint.setCashAssetBound(CashAssetBoundInfo.newBuilder()
            .setLowerBound(0.1)
            .setUpperBound(0.1));

        m_Profile.setLinearConstraint(linearConstraint);

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
    }

    public void Tutorial_3b()
    {
        Initialize("3b", "Asset Relative Bounds");

        // Create asset bound attribute
        Attribute.Builder ubAttribute = Attribute.newBuilder();
        ubAttribute.setAttributeId("AssetUpperBoundAttribute");
        ubAttribute.setAttributeValueType(AttributeValueType.TEXT);
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            ubAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setTextValue("b + 0.001"));
        }
        m_PBData.addAttribute(ubAttribute);

        Attribute.Builder lbAttribute = Attribute.newBuilder();
        lbAttribute.setAttributeId("AssetLowerBoundAttribute");
        lbAttribute.setAttributeValueType(AttributeValueType.TEXT);
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            lbAttribute.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setTextValue("b - 0.001"));
        }
        m_PBData.addAttribute(lbAttribute);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));
        // Set asset relative bound
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setAssetBounds(AssetBoundInfo.newBuilder()
                .setLowerBoundAttributeId("AssetLowerBoundAttribute")
                .setUpperBoundAttributeId("AssetUpperBoundAttribute")));

              // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setReferencePortfolios(ReferencePortfolios.newBuilder()
            .setPrimaryBenchmark(m_benchmarkPortfolioID));  // set reference portfolio for asset bound

        PrintResult(RunOptimize());
    }


    /**\brief Factor Range Constraints
   *
   * In this example, the initial portfolio exposure to Factor_1A is 0.0781, and
   * we want to reduce the exposure to Factor_1A to 0.01.
   */
    public void Tutorial_3c()
    {
        Initialize("3c", "Factor Constraint");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set asset bounds
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .addFactorConstraint(FactorConstraintInfo.newBuilder()
                .setFactorId("Factor_1A")
                .setLowerBound(0.0)
                .setUpperBound(0.01)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("Factor_1A", result);
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
    public void Tutorial_3d()
    {
        Initialize("3d", "Beta Constraint");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3d");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Set beta constraint
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setBetaConstraint(BetaConstraintInfo.newBuilder()
                .setLowerBound(0.9)
                .setUpperBound(1.0)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3d");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
    }

	/**\brief User Attribute Constraints
	*
	* You can associate additional user attributes to each asset and constraint the 
	* optimal portfolio's exposure to these attributes. For instance, you can assign
	* Country, Currency, GICS Sector attribute for each asset and limit your bets on
	* their exposures. The group name and its attributes can be arbitrary and you
	* can use it to model a variety of custom attributes.
	*
	* This self-documenting sample code illustrates how to use the Barra Optimizer 
	* to restrict allocation of assets to a specific GICS sector, in this case,
	* Information Technology.  
	*/
    public void Tutorial_3e()
    {
        Initialize("3e", "Constraint by group");

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("GICS_Sector")
                .addValue("Information Technology")));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3e");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set constraint by group, limit the exposure to Information Technology sector to 20%
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .addConstraintByGroup(ConstraintByGroupInfo.newBuilder()
                .setConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("GICS_Sector")
                .setLowerBound(0.0)
                .setUpperBound(0.2)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3e");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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
	* exposures to GICS Sector Information Technology relative to the reference
	* portfolio. 
	*/
    public void Tutorial_3f()
    {
        Initialize("3f", "Relative Constraints");

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("GICS_Sector")
                .addValue("Information Technology")));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3f");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set constraint by group, limit the exposure to Information Technology sector to
        // 50% of the reference portfolio
        LinearConstraint.Builder linearConstraint = LinearConstraint.newBuilder();
        linearConstraint.addConstraintByGroup(ConstraintByGroupInfo.newBuilder()
            .setConstraintAttributeId("GICS_Sector_Coeff_Attribute")
            .setGroupingAttributeId("GICS_Sector_Attribute")
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .setGroupId("GICS_Sector")
            .setReferencePortfolioId(m_benchmarkPortfolioID)
            .setLowerBound(0.0)
            .setLowerBoundMode(ERelativeModeType.MULTIPLE)
            .setUpperBound(0.5)
            .setUpperBoundMode(ERelativeModeType.MULTIPLE));

        linearConstraint.addFactorConstraint(FactorConstraintInfo.newBuilder()
            .setFactorId("Factor_1A")
            .setReferencePortfolioId(m_benchmarkPortfolioID)
            .setLowerBound(-0.01)
            .setLowerBoundMode(ERelativeModeType.PLUS)
            .setUpperBound(0.01)
            .setUpperBoundMode(ERelativeModeType.PLUS));

        m_Profile.setLinearConstraint(linearConstraint);

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3f");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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
    public void Tutorial_3g()
    {
        Initialize("3g", "Transaction Type");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3g");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set Transaction Type to Sell None/Buy From Universe
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
                .setTransactionType(ETransactionType.SELL_NONE_BUY_FROM_UNIV));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3g");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setCashflowWeight(0.3);  // Contribute 30% cash for buying additional securities

        PrintResult(RunOptimize());
    }

    /**\brief Crossover Option
    *
    * A crossover trade makes an asset change from long position to short position,
    * or vice versa. The following sample shows how to disable the crossover option.
    * If crossover option is disabled, an asset is not allowed to change position
    * from long to short or from short to long. Crossover is enabled by default.
    *
    */
    public void Tutorial_3h()
    {
        Initialize("3h", "Crossover Option", true);

        // Add Cash asset
        m_InitPf.addHolding(Holding.newBuilder()
            .setAssetId("CASH")
            .setAmount(1.0));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 3h");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set Transaction Type to Sell None/Buy From Universe
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
                .setTransactionType(ETransactionType.BUY_SHORT_FROM_UNIV)
                .setEnableCrossover(false));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 3h");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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
    */
    public void Tutorial_4a()
    {
        Initialize("4a", "Maximum Number of Assets");

        // Add Cash asset
        m_InitPf.addHolding(Holding.newBuilder()
            .setAssetId("CASH")
            .setAmount(1.0));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 4a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));
        // Invest all cash
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setCashAssetBound(CashAssetBoundInfo.newBuilder()
                .setLowerBound(0.0)
                .setUpperBound(0.0)));

        // Set max # of assets to be 6
        m_Profile.setCardinalityConstraint(CardinalityConstraint.newBuilder()
               .setNumAssets(CardinalityConstraintInfo.newBuilder()
                    .setMaximum(6)
                    .setIsMaxSoft(false)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 4a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
    }

    /**\brief Holding and Transaction Size Thresholds
    *
    * The minimum holding level is measured as a percentage, expressed in decimals,
    * of net portfolio value (in this example, 0.04 is 4%).  This feature ensures
    * that the optimizer will not recommend trades too small to be meaningful in
    * your analysis.
    *
    * Minimum transaction size is measured as a percentage of the initial portfolio value
    * (in this example, 0.02 is 2%).
    */
    public void Tutorial_4b()
    {
        Initialize("4b", "Min Holding Level and Transaction Size");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 4b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Invest all cash
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setCashAssetBound(CashAssetBoundInfo.newBuilder()
                .setLowerBound(0.0)
                .setUpperBound(0.0)));

        // set minimum holding threshold; both for long and short positions
        // in this example 4%
        // set minimum trade size; both for long and short positions
        // in this example 2%
        m_Profile.setThresholdConstraint(ThresholdConstraint.newBuilder()
               .setLongSideHoldingLevel(ThresholdConstraintInfo.newBuilder()
                    .setMinimum(0.04)
                    .setIsMinSoft(false))
               .setShortSideHoldingLevel(ThresholdConstraintInfo.newBuilder()
                    .setMinimum(0.04)
                    .setIsMinSoft(false))
               .setLongSideTranxLevel(ThresholdConstraintInfo.newBuilder()
                    .setMinimum(0.02)
                    .setIsMinSoft(false))
               .setShortSideTranxLevel(ThresholdConstraintInfo.newBuilder()
                    .setMinimum(0.02)
                    .setIsMinSoft(false)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 4b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 4c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Set turnover constraint
        m_Profile.addTurnoverConstraint(TurnoverConstraintInfo.newBuilder()
               .setBySide(EBySideType.NET)
               .setUsePortfolioBaseValue(false)
               .setIsSoft(true)
               .setUpperBound(0.2));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 4c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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
	* as shown in this simple example using two (.02) cents per share and 20 basis
	* points for the first 10,000 dollar buy cost. For more than 10,000 dollar or
	* short selling, the cost is 0.2 cents per share and 30 basis points.
	*
	* In this example, the .02 cent per share transaction commission is translated
	* into a relative weight via the share's price. The simple-linear market impact
	* cost of 20 basis points is already in relative-weight terms.  
	*
	* In the case of Asset 1 (USA11I1), its share price is 23.99 USD, so the .02 
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
        Initialize("5a", "Piecewise Linear Transaction Costs");

        m_InitPf = Portfolio.newBuilder().setPortfolioId(m_initialPortfolioID);
        m_InitPf.addHolding(Holding.newBuilder()
               .setAssetId("USA11I1")
               .setAmount(0.3));
        m_InitPf.addHolding(Holding.newBuilder()
                .setAssetId("USA13Y1")
                .setAmount(0.7));

        SetPiecewiseLinearTransactionCost();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 5a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .setTransactionCostTerm(1.0));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 5a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /**\brief Nonlinear Transaction Costs
    *
    * Tutorial_5b illustrates how to set up the nonlinear transaction costs
    */
    public void Tutorial_5b()
    {
        Initialize("5b", "Nonlinear Transaction Costs");

        m_InitPf = Portfolio.newBuilder().setPortfolioId(m_initialPortfolioID);
        m_InitPf.addHolding(Holding.newBuilder()
               .setAssetId("USA11I1")
               .setAmount(0.3));
        m_InitPf.addHolding(Holding.newBuilder()
                .setAssetId("USA13Y1")
                .setAmount(0.7));

        // Set nonlinear transaction cost
        m_PBData.setTransactionCosts(TransactionCosts.newBuilder()
            .setNonlinearTransactionCost(NonLinearTransactionCost.newBuilder()
                .setExponent(1.1)
                .setFittedCost(0.00001)
                .setTradedAmount(0.01)));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 5b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .setTransactionCostTerm(1.0));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 5b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /**\brief Transaction Cost Constraints
    *
    * You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
    */
    public void Tutorial_5c()
    {
        Initialize("5c", "Transaction Cost Constraint");

        m_InitPf = Portfolio.newBuilder().setPortfolioId(m_initialPortfolioID);
        m_InitPf.addHolding(Holding.newBuilder()
               .setAssetId("USA11I1")
               .setAmount(0.3));
        m_InitPf.addHolding(Holding.newBuilder()
                .setAssetId("USA13Y1")
                .setAmount(0.7));

        SetPiecewiseLinearTransactionCost();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 5c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .setTransactionCostTerm(1.0));
        m_Profile.setTransactionCostConstraint(TransactionCostConstraintInfo.newBuilder()
            .setUpperBound(0.0005));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 5c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /**\brief Fixed Transaction Costs
    *
    * Tutorial_5d illustrates how to set up fixed transaction costs
    */
    public void Tutorial_5d()
    {
        Initialize("5d", "Fixed Transaction Costs", true);

        SetFixedTransactionCosts();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 5d");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .setTransactionCostTerm(1.0)
            .setAlphaTerm(10.0));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 5d");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /**\brief General Piecewise Linear Constraint
	*
    * Tutorial_5g illustrates how to set up general piecewise linear Constraints
    */
    public void Tutorial_5g()
    {
        Initialize("5g", "General Piecewise Linear Constraint", true);

        // Create a case object. Set initial portfolio
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 5g");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Setup constraint
        m_Profile.addGeneralPwliConstraint(GeneralPWLIConstraintInfo.newBuilder()
            .addStartingPoint(StartingPoint.newBuilder().setAssetId(m_Data.m_ID[0]).setWeight(m_Data.m_BMWeight[0]))
            .addDownside(PWLISegment.newBuilder().setAssetId(m_Data.m_ID[0]).setSlope(-0.01).setBreakPoint(0.05))
            .addDownside(PWLISegment.newBuilder().setAssetId(m_Data.m_ID[0]).setSlope(-0.03))
            .addUpside(PWLISegment.newBuilder().setAssetId(m_Data.m_ID[0]).setSlope(0.02).setBreakPoint(0.04))
            .addUpside(PWLISegment.newBuilder().setAssetId(m_Data.m_ID[0]).setSlope(0.03))
            .setLowerBound(0)
            .setUpperBound(0.25));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 5g");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        RebalanceResult result = RunOptimize();
        PrintResult(result);
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 6a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Set beta constraint
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setBetaConstraint(BetaConstraintInfo.newBuilder()
                .setLowerBound(-1 * GetOPT_INF())
                .setUpperBound(GetOPT_INF())
                .setPenalty(Penalty.newBuilder()
                    .setTarget(0.95)
                    .setLower(0.80)
                    .setUpper(1.2)
                    .setIsPureLinear(true)
                    .setMultiplier(1.0))));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 6a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 7a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 7a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        if (result.hasPortfolioSummary())
        {
            OptimalPortfolio optimalPf = result.getPortfolioSummary().getOptimalPortfolio(0);
            System.out.println("Specific Risk(%) = " + f.format(optimalPf.getSpecificRisk()));
            System.out.println("Factor Risk(%) = " + f.format(optimalPf.getCommonFactorRisk()));
        }

        System.out.println("\nAdd a risk constraint: FactorRisk<=12%");

        m_Profile = m_WS.getRebalanceProfiles().getRebalanceProfileList().get(0).toBuilder();
        m_Profile.addRiskConstraint(RiskConstraintInfo.newBuilder()
            .setRiskSourceType(ERiskSourceType.FACTOR_RISK)
            .setIsPrimaryRiskModel(true)
            .setIsRiskContribution(false)
            .setUpperBound(0.12)
            .setIsSoft(false));

        //m_RebalanceJob = m_WS.getRebalanceJob().toBuilder();
        RebalanceResult result2 = RunOptimize();
        PrintResult(result2);
        if (result.hasPortfolioSummary())
        {
            OptimalPortfolio optimalPf = result2.getPortfolioSummary().getOptimalPortfolio(0);
            System.out.println("Specific Risk(%) = " + f.format(optimalPf.getSpecificRisk()));
            System.out.println("Factor Risk(%) = " + f.format(optimalPf.getCommonFactorRisk()));
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 7b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        m_Profile.addRiskConstraint(RiskConstraintInfo.newBuilder()
            .setConstraintInfoId("RiskConstraint")
            .setRiskSourceType(ERiskSourceType.TOTAL_RISK)
            .setIsPrimaryRiskModel(true)
            .setReferencePortfolioId(m_modelPortfolioID)
            .setIsRiskContribution(false)
            .setUpperBound(0.16)
            .setIsSoft(false));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 7b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("RiskConstraint", result);
    }

    /**\brief Risk Budgeting by asset
    *
    * In the following example, we will constrain the amount of risk coming from
    * individual assets using additive risk definition.
    */
    public void Tutorial_7d()
    {
        Initialize("7d", "Risk Budgeting By Asset", true);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 7d");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        SetGroupingAttribute("RiskByAsset", new String[] { "USA11I1", "USA13Y1" });
        m_Profile.addRiskConstraintByGroup(RiskConstraintByGroupInfo.newBuilder()
            .setConstraintInfoId("RiskByAsset")
            .setAssetGroupingAttributeId("RiskByAsset")
            .setAssetGroupId("RiskByAsset_Group")
            .setAssetGroupingSchemeId("RiskByAsset_GroupingScheme")
            .setRiskSourceType(ERiskSourceType.TOTAL_RISK)
            .setIsPrimaryRiskModel(true)
            .setIsRiskContribution(false)
            .setIsAdditiveDefinition(true)
            .setIsSoft(false)
            .setIsByAsset(true)
            .setLowerBound(0.03)
            .setUpperBound(0.05));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder()
            .setRebalanceProfileId("Case 7d")
            .setInitialPortfolioId(m_initialPortfolioID)
            .setPortfolioBaseValue(100000)
            .setPrimaryRiskModelId(m_primaryRiskModelID)
            .setUniversePortfolioId(m_universePortfolioID); // set trade universe

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfoList(result);
        System.out.println();
    }

	/**\brief Long-Short Optimization
	*
	* Long/Short portfolios can be described as consisting of cash, a set of long
	* positions, and a set of short positions. Long-Short portfolios can provide 
	* more "alpha" since a manager is not restricted to positive-alpha stocks 
	* (assuming the manager's ability to identify overvalued and undervalued stocks).
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
        Initialize("8a", "Long-Short Hedge Optimization", true);

        // All cash in initial portfolio
        m_InitPf.clearHolding()
            .addHolding(Holding.newBuilder()
                .setAssetId("CASH")
                .setAmount(1.0));

       // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 8a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        LinearConstraint.Builder linearConstraint = LinearConstraint.newBuilder();
        linearConstraint.setNoncashAssetBound(NonCashAssetBoundInfo.newBuilder()
            .setLowerBound(-1.0)
            .setUpperBound(1.0));
        linearConstraint.setCashAssetBound(CashAssetBoundInfo.newBuilder()
            .setLowerBound(-0.3)
            .setUpperBound(0.3));
        m_Profile.setLinearConstraint(linearConstraint);

        // Set leverage constraints
        m_Profile.addLeverageConstraint(LeverageConstraintInfo.newBuilder()
            .setBySide(EBySideType.LONG)
            .setNoChange(false)
            .setLowerBound(1.0)
            .setUpperBound(1.3));
        m_Profile.addLeverageConstraint(LeverageConstraintInfo.newBuilder()
            .setBySide(EBySideType.SHORT)
            .setNoChange(false)
            .setLowerBound(-0.3)
            .setUpperBound(0.0));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 8a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(10000000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
    }

     /**\brief Weighted Total Leverage Constraint
    *
    * The following example shows how to setup weighted total leverage constraint,
    * total leverage group constraint, and total leverage factor constraint.
    *
    */
    public void Tutorial_8c()
    {
        Initialize("8c", "Weighted Total Leverage Constraint Optimization", true);

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("GICS_Sector")
                .addValue("Information Technology")));

        // All cash in initial portfolio
        m_InitPf.clearHolding()
            .addHolding(Holding.newBuilder()
                .setAssetId("CASH")
                .setAmount(1.0));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 8c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        LinearConstraint.Builder linearConstraint = LinearConstraint.newBuilder();
        linearConstraint.setNoncashAssetBound(NonCashAssetBoundInfo.newBuilder()
            .setLowerBound(-1.0)
            .setUpperBound(1.0));
        linearConstraint.setCashAssetBound(CashAssetBoundInfo.newBuilder()
            .setLowerBound(-0.3)
            .setUpperBound(0.3));

        // Set total leverage factor constraint
        linearConstraint.addFactorConstraint(FactorConstraintInfo.newBuilder()
            .setBySide(EBySideType.TOTAL)
            .setFactorId("Factor_1A")
            .setLowerBound(1.0)
            .setUpperBound(1.3)
            .setIsSoft(true)
            .setPenalty(Penalty.newBuilder()
                .setTarget(0.95)
                .setLower(0.80)
                .setUpper(1.2)));

        // Set total leverage group constraint
        linearConstraint.addConstraintByGroup(ConstraintByGroupInfo.newBuilder()
            .setBySide(EBySideType.TOTAL)
            .setConstraintAttributeId("GICS_Sector_Coeff_Attribute")
            .setGroupingAttributeId("GICS_Sector_Attribute")
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .setGroupId("GICS_Sector")
            .setLowerBound(1.0)
            .setUpperBound(1.3)
            .setIsSoft(true)
            .setPenalty(Penalty.newBuilder()
                .setTarget(0.95)
                .setLower(0.80)
                .setUpper(1.2)));

        m_Profile.setLinearConstraint(linearConstraint);

        // Set weighted total leverage constraint
        SetCoefficientAttribute("WTLC_Long_Coeff_Attribute", 1.0);
        SetCoefficientAttribute("WTLC_Short_Coeff_Attribute", 1.0);

        m_Profile.addWeightedTotalLeverageConstraint(WeightedTotalLeverageConstraintInfo.newBuilder()
            .setLongSideAttributeId("WTLC_Long_Coeff_Attribute")
            .setShortSideAttributeId("WTLC_Short_Coeff_Attribute")
            .setLowerBound(1.0)
            .setUpperBound(1.3)
            .setIsSoft(true)
            .setPenalty(Penalty.newBuilder()
                .setTarget(0.95)
                .setLower(0.80)
                .setUpper(1.2)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 8c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(10000000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 9a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setIsPrimaryRiskModel(true)
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 9a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .setOptimizationType(EOptimizationType.RISK_TARGET)
            .setRiskTarget(0.14));  // set risk target

        PrintResult(RunOptimize());
    }

    /**\brief Return Target
    *
    * Similar to Tutoral_9a, we define a return target of 1% in Tutorial_9b:
    */
    public void Tutorial_9b()
    {
        Initialize("9b", "Return Target", true);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 9b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setIsPrimaryRiskModel(true)
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 9b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .setOptimizationType(EOptimizationType.RETURN_TARGET)
            .setReturnTarget(0.01));  // set return target

        PrintResult(RunOptimize());
    }

    /**\brief Tax-aware Optimization (Using new APIs introduced in v8.8)
    *
    * Suppose an individual investor desires to rebalance a portfolio to be more
    * like the benchmark, but also wants to minimize net tax liability.
    * In Tutorial_10c, we are rebalancing without alphas, and assume
    * the portfolio has no realized capital gains so far this year.  The trading
    * rule is FIFO. This tutorial illustrates how to set up a group-level tax
    * arbitrage constraint.
    */
    public void Tutorial_10c()
    {
        Initialize( "10c", "Tax-aware Optimization (Using new APIs introduced in v8.8)" );

        // Set price
        SetPrice();

        // Set lower bound attribute for holding constraints
        SetTextAttribute("asset_lower_bound_attribute", "0.0", false);

        // Tax lot info
        SetTaxLots();

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("GICS_Sector")
                .addValue("Information Technology")));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 10c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));
        // Set constraints
        m_Profile.setTaxConstraints(TaxConstraints.newBuilder()
            .addTaxArbitrageRange(TaxArbitrageConstraint.newBuilder()
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("GICS_Sector")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setTaxCategory(ETaxCategory.LONG_TERM)
                .setGainType(ECapitalGainType.CAPITAL_GAIN)
                .setTaxConstraint(TaxArbitrageConstraintInfo.newBuilder()
                    .setUpperBound(250.0))));
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setCashAssetBound(CashAssetBoundInfo.newBuilder()
                .setLowerBound(0.0)
                .setLowerBoundMode(ERelativeModeType.ABSOLUTE))
            .setAssetBounds(AssetBoundInfo.newBuilder()
                .setLowerBoundAttributeId("asset_lower_bound_attribute")));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 10c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(4279.45);
        m_RebalanceJob.setCashflowWeight(0.0);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);

        // Set tax rules
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .addTaxSetting(TaxSetting.newBuilder()
                .setTaxUnit(ETaxUnit.DOLLAR)
                .addTaxRule(TaxRule.newBuilder()
                    .setEnableTwoRate(true)
                    .setLongTermRate(0.243)
                    .setShortTermRate(0.423)
                    .setShortTermPeriod(365)
                    .setWashSalePeriod(30)
                    .setWashSaleRule(EWashSaleRule.DISALLOWED))
                .addSellingOrderRule(SellingOrderRuleByGroupInfo.newBuilder()
                    .setRule(ESellingOrderRule.FIFO))));

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintTaxResult(result);
    }


    /**\brief Tax-aware Optimization (Using new APIs introduced in v8.8)
    *
    * This tutorial illustrates how to set up a tax-aware optimization case with cash outflow.
    */
    public void Tutorial_10d()
    {
        Initialize( "10d", "Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow" );

        // Set price
        SetPrice();

        // Set lower bound attribute for holding constraints
        SetTextAttribute("asset_lower_bound_attribute", "0.0", false);

        // Tax lot info
        SetTaxLots();

        // Calculate asset values and portfolio value from tax lots
        double[] assetValue = new double[m_Data.m_AssetNum];
        double pfValue = 0.0;
        for (int j = 0; j < m_Data.m_Taxlots; j++)
        {
            int iAsset = m_Data.m_Indices[j];
            double lotValue = m_Data.m_Price[iAsset] * m_Data.m_Shares[j];
            assetValue[iAsset] += lotValue;
            pfValue += lotValue;
        }

        // Cash outflow 5% of the base value
        double CFW = -0.05;
        // Set base value so that the final optimal weight will sum up to 100%
        double BV = pfValue / (1 - CFW);
        // Reset asset initial weights based on tax lot information
        for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            m_InitPf.setHolding(i, Holding.newBuilder()
                        .setAssetId(m_Data.m_ID[i])
                        .setAmount(assetValue[i] / BV));
        }

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("GICS_Sector")
                .addValue("Information Technology")));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 10d");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));
        // Set constraints
        m_Profile.setTaxConstraints(TaxConstraints.newBuilder()
            .addTaxArbitrageRange(TaxArbitrageConstraint.newBuilder()
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("GICS_Sector")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setTaxCategory(ETaxCategory.LONG_TERM)
                .setGainType(ECapitalGainType.CAPITAL_GAIN)
                .setTaxConstraint(TaxArbitrageConstraintInfo.newBuilder()
                    .setUpperBound(250.0))));
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setCashAssetBound(CashAssetBoundInfo.newBuilder()
                .setLowerBound(0.0)
                .setLowerBoundMode(ERelativeModeType.ABSOLUTE))
            .setAssetBounds(AssetBoundInfo.newBuilder()
                .setLowerBoundAttributeId("asset_lower_bound_attribute")));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 10d");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(BV);
        m_RebalanceJob.setCashflowWeight(CFW);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);

        // Set tax rules
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .addTaxSetting(TaxSetting.newBuilder()
                .setTaxUnit(ETaxUnit.DOLLAR)
                .addTaxRule(TaxRule.newBuilder()
                    .setEnableTwoRate(true)
                    .setLongTermRate(0.243)
                    .setShortTermRate(0.423)
                    .setShortTermPeriod(365)
                    .setWashSalePeriod(30)
                    .setWashSaleRule(EWashSaleRule.DISALLOWED))
                .addSellingOrderRule(SellingOrderRuleByGroupInfo.newBuilder()
                    .setRule(ESellingOrderRule.FIFO))));

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintTaxResult(result);
    }

	/**\brief Tax-aware Optimization with loss benefit
    *
    * This tutorial illustrates how to set up a tax-aware optimization case with
    * a loss benefit term in the utility.
    */
    public void Tutorial_10e()
    {
            Initialize("10e", "Tax-aware Optimization with loss benefit");

            // Set price
            SetPrice();

            // Set lower bound attribute for holding constraints
            SetTextAttribute("asset_lower_bound_attribute", "0.0", false);

            // Tax lot info
            SetTaxLots();

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.newBuilder();
            m_Profile.setRebalanceProfileId("Case 10e");
            m_Profile.setUtility(Utility.newBuilder()
                .setUtilityType(EUtilityType.QUADRATIC)
                .addRiskTerm(RiskTerm.newBuilder()
                    .setCommonFactorRiskAversion(0.0075)
                    .setSpecificRiskAversion(0.0075))
                .setLossBenefitTerm(1.0));

            // Set constraints
            m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
                .setTransactionType(ETransactionType.SHORT_NONE));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.newBuilder();
            m_RebalanceJob.setRebalanceProfileId("Case 10e");
            m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.setPortfolioBaseValue(4279.45);
            m_RebalanceJob.setCashflowWeight(0.0);
            m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
                .addTaxSetting(TaxSetting.newBuilder()
                    .setTaxUnit(ETaxUnit.DOLLAR)
                    .addTaxRule(TaxRule.newBuilder()
                        .setEnableTwoRate(true)
                        .setLongTermRate(0.243)
                        .setShortTermRate(0.423)
                        .setShortTermPeriod(365)
                        .setWashSalePeriod(30)
                        .setWashSaleRule(EWashSaleRule.DISALLOWED))
                    .addSellingOrderRule(SellingOrderRuleByGroupInfo.newBuilder()
                        .setRule(ESellingOrderRule.FIFO))));

            RebalanceResult result = RunOptimize();
            PrintResult(result);
            PrintTaxResult(result);
    }

    /**\brief Tax-aware Optimization with total loss and gain constraints.
    *
    * This tutorial illustrates how to set up a tax-aware optimization case with
    * bounds on total gain and loss.
    */
    public void Tutorial_10f()
    {
        Initialize("10f", "Tax-aware Optimization with total gain/loss constraints");

        // Set price
        SetPrice();

        // Tax lot info
        SetTaxLots();

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("Information Technology")
                .addValue("Information Technology"))
            .addGroup(Group.newBuilder()
                .setGroupId("Financials")
                .addValue("Financials")));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 10f");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));
        // Linear constraints
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .setTransactionType(ETransactionType.SHORT_NONE)
            .setCashAssetBound(CashAssetBoundInfo.newBuilder()
                .setLowerBound(0.0)
                .setUpperBound(0.0)));
        // Tax constraints
        m_Profile.setTaxConstraints(TaxConstraints.newBuilder()
            .addTaxArbitrageRange(TaxArbitrageConstraint.newBuilder()
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("Financials")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setGainType(ECapitalGainType.CAPITAL_LOSS)
                .setTaxConstraint(TaxArbitrageConstraintInfo.newBuilder()
                    .setUpperBound(100.0)))
            .addTaxArbitrageRange(TaxArbitrageConstraint.newBuilder()
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("Information Technology")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setGainType(ECapitalGainType.CAPITAL_GAIN)
                .setTaxConstraint(TaxArbitrageConstraintInfo.newBuilder()
                    .setLowerBound(250.0))));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder()
            .setRebalanceProfileId("Case 10f")
            .setInitialPortfolioId(m_initialPortfolioID)
            .setPortfolioBaseValue(4279.45)
            .setCashflowWeight(0.0)
            .setPrimaryRiskModelId(m_primaryRiskModelID)
            .setUniversePortfolioId(m_universePortfolioID);

        // Set tax rules
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .addTaxSetting(TaxSetting.newBuilder()
                .setTaxUnit(ETaxUnit.DOLLAR)
                .addTaxRule(TaxRule.newBuilder()
                    .setEnableTwoRate(true)
                    .setLongTermRate(0.243)
                    .setShortTermRate(0.423)
                    .setShortTermPeriod(365)
                    .setWashSalePeriod(30)
                    .setWashSaleRule(EWashSaleRule.DISALLOWED))
                .addSellingOrderRule(SellingOrderRuleByGroupInfo.newBuilder()
                    .setRule(ESellingOrderRule.FIFO))));

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintTaxResult(result);
    }

	/**\brief Tax-aware Optimization with wash sales in the input.
	*
	* This tutorial illustrates how to specify wash sales, set the wash sale rule,
	* and access wash sale details from the output.
	*/
	public void Tutorial_10g()
	{
		Initialize("10g", "Tax-aware Optimization with wash sales");

		// Set price
		SetPrice();

		// Tax lot info
		SetTaxLots();

		// Add an extra lot whose age is within the wash sale period
		TaxLotInfos.Builder taxLots = TaxLotInfos.newBuilder();
		taxLots.mergeFrom(m_PBData.getTaxLots());
		taxLots.addTaxLot(TaxLotInfo.newBuilder()
			.setAssetId("USA11I1")
			.setAge(12)
			.setCostBasis(21.44)
			.setShares(20.0));
		m_PBData.setTaxLots(taxLots);

		// Recalculate asset weight from tax lot data
		double pfValue = UpdatePortfolioWeights();

		WashSaleRecords.Builder washSales = WashSaleRecords.newBuilder();
		washSales
			.addWashSale(WashSaleRecord.newBuilder().setAssetId("USA2ND1")
				.setAge(20).setLossPerShare(12.54).setShares(10.0))
			.addWashSale(WashSaleRecord.newBuilder().setAssetId("USA3351")
				.setAge(35).setLossPerShare(2.42).setShares(25.0))
			.addWashSale(WashSaleRecord.newBuilder().setAssetId("USA39K1")
				.setAge(12).setLossPerShare(9.98).setShares(25.0));
		m_PBData.setWashSales(washSales);

		// Build rebalance profile, set utility and risk aversion
		m_Profile = RebalanceProfile.newBuilder();
		m_Profile.setRebalanceProfileId("Case 10g");
		m_Profile.setUtility(Utility.newBuilder()
			.setUtilityType(EUtilityType.QUADRATIC)
			.addRiskTerm(RiskTerm.newBuilder()
				.setCommonFactorRiskAversion(0.0075)
				.setSpecificRiskAversion(0.0075)));
		// Linear constraints
		m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
			.setTransactionType(ETransactionType.SHORT_NONE)
			.setCashAssetBound(CashAssetBoundInfo.newBuilder()
				.setLowerBound(0.0)
				.setUpperBound(0.0)));

		// Build rebalance job, set profile ID, initial portfolio and primary risk model
		m_RebalanceJob = RebalanceJob.newBuilder()
			.setRebalanceProfileId("Case 10g")
			.setInitialPortfolioId(m_initialPortfolioID)
			.setPortfolioBaseValue(pfValue)
			.setCashflowWeight(0.0)
			.setPrimaryRiskModelId(m_primaryRiskModelID)
			.setUniversePortfolioId(m_universePortfolioID);

		// Set tax rules
		m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
			.addTaxSetting(TaxSetting.newBuilder()
				.setTaxUnit(ETaxUnit.DOLLAR)
				.addTaxRule(TaxRule.newBuilder()
					.setEnableTwoRate(true)
					.setLongTermRate(0.243)
					.setShortTermRate(0.423)
					.setShortTermPeriod(365)
					.setWashSalePeriod(40)
					.setWashSaleRule(EWashSaleRule.TRADEOFF))
				.addSellingOrderRule(SellingOrderRuleByGroupInfo.newBuilder()
					.setRule(ESellingOrderRule.FIFO))));

		RebalanceResult result = RunOptimize();
		PrintResult(result);

		// Retrieving tax related information from the output
		if (result.hasPortfolioSummary())
		{
			for (OptimalPortfolio portfolio : result.getPortfolioSummary().getOptimalPortfolioList())
			{
				if (portfolio.hasPortfolioTax())
				{
					TaxOutput taxOutput = portfolio.getPortfolioTax();

					// Shares in tax lots
                    System.out.println("\nTaxlotID          Shares:");
                    for (TaxOutputByAsset taxByAsset : taxOutput.getAssetTaxDetailList())
                    {
                        for (TaxLotShares taxLotShares : taxByAsset.getTaxLotSharesList())
                        {
                            if (taxLotShares.getShares() > 0)
                                System.out.println(taxLotShares.getTaxLotId() + "  " + f.format(taxLotShares.getShares()));
                        }
                    }

					// New shares
					System.out.println("\nNew Shares:");
                    for (TaxOutputByAsset taxByAsset : taxOutput.getAssetTaxDetailList())
                    {
                        if (taxByAsset.getNewShares() > 0)
                            System.out.println(taxByAsset.getAssetId() + ":  " + f.format(taxByAsset.getNewShares()));
                    }
                    System.out.println();


					// Disqualified shares
					System.out.println("Disqualified Shares:");
					for (DisqualifiedShares disqShares : taxOutput.getDisqualifiedSharesList())
					{
                        System.out.println(disqShares.getWashSaleId() + ":  " + f.format(disqShares.getShares()));
					}
					System.out.println();

					// Wash sale details
					System.out.println("Wash Sale Details:");
					System.out.format("%-20s%12s%10s%10s%12s%20s\n",
						"TaxLotID", "AdjustedAge", "CostBasis", "Shares", "SoldShares", "DisallowedLotID");
					for (TaxOutputByAsset taxByAsset : taxOutput.getAssetTaxDetailList())
					{
						for (WashSaleDetail wsDetail : taxByAsset.getWashSaleDetailList())
						{
							System.out.format("%-20s%12d%10.4f%10.4f%12.4f%20s\n",
								wsDetail.getLotId(), wsDetail.getAdjustedAge(), wsDetail.getAdjustedCostBasis(),
								wsDetail.getShares(), wsDetail.getSoldShares(), wsDetail.getDisallowedLotId());
						}
					}
					System.out.println();
				}
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

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 11a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 11a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .setOptimizationType(EOptimizationType.EFFICIENT_FRONTIER)
            .setFrontier(Frontier.newBuilder()
                .setFrontierType(EFrontierType.RISK_RETURN)
                .setLowerBound(0.0)
                .setUpperBound(0.1)
                .setMaxDataPoints(10)));  // set frontier

        RebalanceResult result = RunOptimize();

        System.out.println(result.getOptimizationStatus().getMessage());
        System.out.println(result.getOptimizationStatus().getSolverLog());

        if (result.hasPortfolioSummary())
        {
            int index = 0;
            PortfolioSummary portfolioSummary = result.getPortfolioSummary();
            for (OptimalPortfolio optimalPortfolio : portfolioSummary.getOptimalPortfolioList())
            {
                System.out.println(index+
                    ": Risk(%) = " + f.format(optimalPortfolio.getTotalRisk())+
                    " \tReturn(%) = " + f.format(optimalPortfolio.getReturn()));
                index++;
            }
            System.out.println();
        }
    }

    /**\brief Constraint priority
    *
    * This tutorial illustrates how to set up constraint priority
    */
    public void Tutorial_12a()
    {
        Initialize("12a", "Constraint Priority", true);

        // Build rebalance profile, set utility
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 12a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC));

        m_Profile.setThresholdConstraint(ThresholdConstraint.newBuilder()
            // Set minimum holding threshold; both for long and short positions
            // in this example 10%
            .setLongSideHoldingLevel(ThresholdConstraintInfo.newBuilder()
                .setMinimum(0.1))
            .setShortSideHoldingLevel(ThresholdConstraintInfo.newBuilder()
                .setMinimum(0.1))
            // Set minimum trade size; both for long and short positions
            // in this example 20%
            .setLongSideTranxLevel(ThresholdConstraintInfo.newBuilder()
                .setMinimum(0.2))
            .setShortSideTranxLevel(ThresholdConstraintInfo.newBuilder()
                .setMinimum(0.2)));

        m_Profile.setCardinalityConstraint(CardinalityConstraint.newBuilder()
            .setNumAssets(CardinalityConstraintInfo.newBuilder()
                .setMinimum(5)) // Set Min # assets to 5, excluding cash and futures
             .setNumTrades(CardinalityConstraintInfo.newBuilder()
                .setMaximum(3)));   // Set Max # trades to 3

        // Set leverage constraints
        m_TradeUniverse.addHolding(Holding.newBuilder()
            .setAssetId("CASH")
            .setAmount(0.0));   // Cash is required for L/S optimization
        m_Profile.addLeverageConstraint(LeverageConstraintInfo.newBuilder()
            .setBySide(EBySideType.LONG)
            .setLowerBound(1.0)
            .setUpperBound(1.1));
        m_Profile.addLeverageConstraint(LeverageConstraintInfo.newBuilder()
            .setBySide(EBySideType.SHORT)
            .setLowerBound(-0.3)
            .setUpperBound(-0.3));
        m_Profile.addLeverageConstraint(LeverageConstraintInfo.newBuilder()
            .setBySide(EBySideType.TOTAL)
            .setLowerBound(1.5)
            .setUpperBound(1.5));

        // Set constraint priority
        m_Profile.addConstraintPriority(ConstraintPriority.newBuilder()
            .setCategory(EConstraintCategory.ASSET_CARDINALITY)
            .setRelaxOrder(ERelaxOrderType.FIRST));
        m_Profile.addConstraintPriority(ConstraintPriority.newBuilder()
            .setCategory(EConstraintCategory.HEDGE)
            .setRelaxOrder(ERelaxOrderType.SECOND));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 12a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe

        PrintResult(RunOptimize());
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

        SetShortfalBetaAttribute("Shortfall_Beta_Attribute");

        // Build rebalance profile, set utility
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 14a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                .setIsPrimaryRiskModel(true)
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setCommonFactorRiskAversion(0.0075)
                .setSpecificRiskAversion(0.0075)));

        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .addCustomConstraint(CustomConstraintInfo.newBuilder()
                .setConstraintInfoId("ShortfallBetaCon")
                .setAttributeId("Shortfall_Beta_Attribute")
                .setLowerBound(0.9)
                .setUpperBound(0.9)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 14a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setOptimizationSetting(OptimizationSetting.newBuilder()
            .setOptimizationType(EOptimizationType.RISK_TARGET)
            .setRiskTarget(0.05));  // set risk target

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("ShortfallBetaCon", result);
    }

    /** \brief Minimizing Total Risk from both of primary and secondary risk models
    *
    * This self-documenting sample code illustrates how to use Barra Optimizer
    * for minimizing Total Risk from both of primary and secondary risk models
    */
    public void Tutorial_15a()
    {
        // Create WorkSpace and setup Risk Model data,
        // Create initial portfolio, etc; no alpha
        Initialize("15a", "Minimize Total Risk from 2 Models");

        SetupRiskModel2();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 15a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075))
            // Set risk aversions for CF and SP to 0.0075 for secondary risk model; No benchmark
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(false)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 15a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model

        PrintResult(RunOptimize());
    }

    /** \brief Constrain risk from secondary risk model
    *
    * This self-documenting sample code illustrates how to use Barra Optimizer
    * for constraining risk from secondary risk model
    */
    public void Tutorial_15b()
    {
        Initialize( "15b", "Risk Budgeting - Dual Risk Model" );

        SetupRiskModel2();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 15b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // set total risk from the secondary risk model
        m_Profile.addRiskConstraint(RiskConstraintInfo.newBuilder()
            .setRiskSourceType(ERiskSourceType.TOTAL_RISK)
            .setConstraintInfoId("RiskConstraint")
            .setIsPrimaryRiskModel(false)
            .setReferencePortfolioId(m_modelPortfolioID)
            .setUpperBound(0.1));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 15b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("RiskConstraint", result);
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
        Initialize( "15c", "Risk parity constraint" );

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 15c");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));
        // Add all assets except USA11I1 to risk parity constraint
        Attribute.Builder rpAttribute = Attribute.newBuilder();
        rpAttribute.setAttributeId("RiskParity_AssetGroupID");
        rpAttribute.setAttributeValueType(AttributeValueType.DOUBLE);
		for (int i = 0; i < m_Data.m_AssetNum; i++)
        {
            if (!m_Data.m_ID[i].equals("USA11I1"))
				rpAttribute.addElement(Element.newBuilder()
					.setElementId(m_Data.m_ID[i])
					.setDoubleValue(0));
        }
        m_PBData.addAttribute(rpAttribute);

		// Set Transaction Type to Short None
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
                .setTransactionType(ETransactionType.SHORT_NONE));

		// Set risk parity constraint
        m_Profile.setRiskParityConstraint(RiskParityConstraintInfo.newBuilder()
			.setEnabled(true)
			.setType(ERiskParityType.ASSET_RISK_PARITY)
			.setGroupingAttributeId("RiskParity_AssetGroupID")
			.setCanUseExcluded(false)
            .setIsPrimaryRiskModel(true));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 15c");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
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

        SetupRiskModel2();

        SetCoefficientAttribute("Covterm_Weight_Coeff_Attribute", 1.0);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 16a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075))
            .addCovarianceTerm(CovarianceTerm.newBuilder()
                .setCovarianceTermType(ECovarianceTermType.WXFXW)
                .setCovarianceTerm(0.0075)
                .setIsPrimaryRiskModel(false)
                .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                .setWeightMatrixAttributeId("Covterm_Weight_Coeff_Attribute")));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 16a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model

        PrintResult(RunOptimize());
    }

     /** \brief Five-Ten-Forty Rule
    *
    * This self-documenting sample code illustrates how to apply the 5/10/40 rule
    *
    */
    public void Tutorial_17a()
    {
        Initialize("17a", "Five-Ten-Forty Rule");

        SetIssuer();

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 17a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Set 5-10-40 rule
        m_Profile.setFiveTenFortyRule(FiveTenFortyRule.newBuilder()
            .setFive(5)
            .setTen(10)
            .setForty(40));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 17a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

    /** \brief Factor block structure
    *
    * This self-documenting sample code illustrates how to set up the factor block structure in
    * a risk model.
    */
    public void Tutorial_18()
    {
        Initialize("18", "Factor exposure block");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 18");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));
        FactorBlocks.Builder factorBlocks = FactorBlocks.newBuilder();
        factorBlocks.addFactorBlock(FactorBlock.newBuilder()
                .setFactorBlockId("A")
                .addFactorId("Factor_1A")
                .addFactorId("Factor_2A")
                .addFactorId("Factor_3A")
                .addFactorId("Factor_4A")
                .addFactorId("Factor_5A")
                .addFactorId("Factor_6A")
                .addFactorId("Factor_7A")
                .addFactorId("Factor_8A")
                .addFactorId("Factor_9A"));
        factorBlocks.addFactorBlock(FactorBlock.newBuilder()
                .setFactorBlockId("B")
                .addFactorId("Factor_1B")
                .addFactorId("Factor_2B")
                .addFactorId("Factor_3B")
                .addFactorId("Factor_4B")
                .addFactorId("Factor_5B")
                .addFactorId("Factor_6B")
                .addFactorId("Factor_7B")
                .addFactorId("Factor_8B")
                .addFactorId("Factor_9B"));
        m_PrimaryRiskModel.setFactorBlocks(factorBlocks);

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 18");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);

        PrintResult(RunOptimize());
    }

     /** \brief Load Models Direct risk model data
    *
    * This self-documenting sample code illustrates how to load Models Direct data into USE4L risk model.
    */
    public void Tutorial_19()
    {
        Initialize("19", "Load risk model using Models Direct files");

        String modelName = "USE4L";
        try {
           String executable;
	   String modelsDirectPath;
            if (System.getProperty("os.name").toLowerCase().indexOf("win") >= 0) 
	    {
                executable = "openopt.exe";
		modelsDirectPath = "\"" + m_Data.m_Datapath + "\"";
	    }
            else
	    {
                executable = "../../runopenopt.sh";
		modelsDirectPath = m_Data.m_Datapath;
	    }
            long analysisDate = 20130501;
            String riskModelFile = "USE4L.pb";
            String commandLine = executable + " -md"
                    + " -m " + modelName
                    + " -d " + analysisDate
                    + " -o " + riskModelFile
                    + " -path " + modelsDirectPath;
            System.out.println(commandLine);
            Runtime rt = Runtime.getRuntime();
            Process pr = rt.exec(commandLine);
            pr.waitFor();
            if (pr.exitValue() != 0) {
                System.out.println("Error running " + executable);
                return;
            }
            FileInputStream input = new FileInputStream(riskModelFile);
            RiskModel rm = RiskModel.parseFrom(input);
            m_PrimaryRiskModel = rm.toBuilder();

        }
        catch (Exception e) {
              System.out.println(e.getMessage());
              return;
        }
        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 19");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setBenchmarkPortfolioId(m_benchmarkPortfolioID)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));
       // Set factor constraint
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .addFactorConstraint(FactorConstraintInfo.newBuilder()
                .setFactorId("USE4L_SIZE")
                .setLowerBound(0.02)
                .setUpperBound(0.05)));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 19");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(modelName);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("USE4L_SIZE", result);
    }

    /** \brief General Ratio Constraint
    *
    * This example code illustrates how to setup a ratio constraint specifying
    * the coefficients.
    */
    public void Tutorial_28a()
    {
        // Create WorkSpace and setup Risk Model data,
        // Create initial portfolio, etc; no alpha
        Initialize("28a", "General Ratio Constraint");

        // Create attribute for numerator coefficients
        Attribute.Builder numeratorCoeffs = Attribute.newBuilder();
        numeratorCoeffs.setAttributeId("RatioConstraintNumerCoeffs");
        numeratorCoeffs.setAttributeValueType(AttributeValueType.DOUBLE);
        for (int i = 1; i <= 3; i++)
        {
            numeratorCoeffs.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(m_Data.m_SpCov[i]));
        }
        m_PBData.addAttribute(numeratorCoeffs);

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 28a");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Add a ratio constraint
        m_Profile.addGeneralRatioConstraint(GeneralRatioConstraintInfo.newBuilder()
            .setConstraintInfoId("RatioConstraint")
            .setNumeratorAttributeId("RatioConstraintNumerCoeffs")
            .setLowerBound(0.05)
            .setUpperBound(0.1));


        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 28a");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID); // set trade universe
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("RatioConstraint", result);
    }

    /** \brief Group Ratio Constraint
    *
    * This example illustrates how to setup a ratio constraint using asset attributes.
    */
    public void Tutorial_28b()
    {
        // Create WorkSpace and setup Risk Model data,
        // Create initial portfolio, etc; no alpha
        Initialize("28b", "Group Ratio Constraint");

        // create asset attribute for GICS sector and coefficients
        SetGICSAttribute("GICS_Sector_Attribute");
        SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

        // Create grouping scheme for GICS sector
        m_PBData.addGroupingScheme(GroupingScheme.newBuilder()
            .setGroupingSchemeId("GICS_Grouping_Scheme")
            .addGroup(Group.newBuilder()
                .setGroupId("Information Technology")
                .addValue("Information Technology"))
            .addGroup(Group.newBuilder()
                .setGroupId("Financials")
                .addValue("Financials"))
            .addGroup(Group.newBuilder()
                .setGroupId("Minerals")
                .addValue("Minerals")));

        // Set constraint by group, limit the exposure to Information Technology sector to 20%
        m_Profile.setLinearConstraint(LinearConstraint.newBuilder()
            .addConstraintByGroup(ConstraintByGroupInfo.newBuilder()
                .setConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                .setGroupingAttributeId("GICS_Sector_Attribute")
                .setGroupingSchemeId("GICS_Grouping_Scheme")
                .setGroupId("GICS_Sector")
                .setLowerBound(0.0)
                .setUpperBound(0.2)));

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 28b");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Add a ratio constraints
        // 1. Weight of "Financials" assets can be at most half of "Information Technology" assets
        m_Profile.addGroupRatioConstraint(GroupRatioConstraintInfo.newBuilder()
            .setConstraintInfoId("Financials / IT")
            .setNumeratorAttributeId("GICS_Sector_Coeff_Attribute")
            .setNumeratorGroupingAttributeId("GICS_Sector_Attribute")
            .setNumeratorGroupingSchemeId("GICS_Grouping_Scheme")
            .setNumeratorGroupId("Financials")
            .setDenominatorGroupId("Information Technology") // same grouping scheme as for the numerator
            .setUpperBound(0.5));
        // 2. Ratio of "Information Technology" to "Minerals" should not differ from the benchmark more than +-10%
        m_Profile.addGroupRatioConstraint(GroupRatioConstraintInfo.newBuilder()
            .setConstraintInfoId("Minerals / IT")
            .setNumeratorAttributeId("GICS_Sector_Coeff_Attribute")
            .setNumeratorGroupingAttributeId("GICS_Sector_Attribute")
            .setNumeratorGroupingSchemeId("GICS_Grouping_Scheme")
            .setNumeratorGroupId("Minerals")
            .setDenominatorGroupId("Information Technology") // same grouping scheme as for the numerator
            .setReferencePortfolioId(m_benchmarkPortfolioID)
            .setLowerBound(-0.1)
            .setLowerBoundMode(ERelativeModeType.PLUS)
            .setUpperBound(0.1)
            .setUpperBoundMode(ERelativeModeType.PLUS));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder();
        m_RebalanceJob.setRebalanceProfileId("Case 28b");
        m_RebalanceJob.setInitialPortfolioId(m_initialPortfolioID);
        m_RebalanceJob.setUniversePortfolioId(m_universePortfolioID);
        m_RebalanceJob.setPortfolioBaseValue(100000);
        m_RebalanceJob.setPrimaryRiskModelId(m_primaryRiskModelID);

        RebalanceResult result = RunOptimize();
        PrintResult(result);
        PrintSlackInfo("Financials / IT", result);
        PrintSlackInfo("Minerals / IT", result);
    }

    /** \brief General Quadratic Constraint
    *
    * This example illustrates how to setup a general quadratic constraint.
    */
    public void Tutorial_29()
    {
        // Create WorkSpace and setup Risk Model data,
        // Create initial portfolio, etc; no alpha
        Initialize("29", "General Quadratic Constraint");

        // Build rebalance profile, set utility and risk aversion
        m_Profile = RebalanceProfile.newBuilder();
        m_Profile.setRebalanceProfileId("Case 29");
        m_Profile.setUtility(Utility.newBuilder()
            .setUtilityType(EUtilityType.QUADRATIC)
            .addRiskTerm(RiskTerm.newBuilder()
                            .setIsPrimaryRiskModel(true)
                            .setCommonFactorRiskAversion(0.0075)
                            .setSpecificRiskAversion(0.0075)));

        // Create a symmetric matrix for quadratic coefficients
        SymmetricMatrix.Builder quadraticCoeffs = SymmetricMatrix.newBuilder();
        quadraticCoeffs.setId("Q");
        String[] rowids = { "USA11I1", "USA13Y1", "USA1LI1" };
        for (String rowid : rowids)
        {
            quadraticCoeffs.addRowId(rowid);
        }
        double[] values = { 0.92473646, 0, 0, 0.60338704, 0.38904854, 0.63569677 };
        for (double v : values)
        {
            quadraticCoeffs.addValue(v);
        }
        m_PBData.addSymmetricMatrix(quadraticCoeffs);

        // Create attribute for numerator coefficients
        Attribute.Builder linearCoeffs = Attribute.newBuilder();
        linearCoeffs.setAttributeId("q");
        linearCoeffs.setAttributeValueType(AttributeValueType.DOUBLE);
        for (int i = 1; i < 6; i++)
        {
            linearCoeffs.addElement(Element.newBuilder()
                                    .setElementId(m_Data.m_ID[i])
                                    .setDoubleValue(0.1));
        }
        m_PBData.addAttribute(linearCoeffs);

        // Add a quadratic constraint
        m_Profile.addQuadraticConstraint(QuadraticConstraintInfo.newBuilder()
            .setQuadraticTermMatrixId("Q")
            .setLinearTermAttributeId("q")
            .setUpperBound(0.1));

        // Build rebalance job, set profile ID, initial portfolio and primary risk model
        m_RebalanceJob = RebalanceJob.newBuilder()
            .setRebalanceProfileId("Case 29")
            .setInitialPortfolioId(m_initialPortfolioID)
            .setUniversePortfolioId(m_universePortfolioID)
            .setPortfolioBaseValue(100000)
            .setPrimaryRiskModelId(m_primaryRiskModelID);

        PrintResult(RunOptimize());
    }

}
