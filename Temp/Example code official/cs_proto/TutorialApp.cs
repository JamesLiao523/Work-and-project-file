/** @file TutorialApp.cs
* \brief Contains definitions of the TutorialApp class with specific code for
* each of tutorials.
*/

using System;
using System.IO;
using System.Diagnostics;
using optimizer.proto;

namespace Tutorial_CS_Protobuf
{
    /**\brief Contains specific code for each of the tutorials
    */
    class TutorialApp : TutorialBase
    {
        public TutorialApp(TutorialData data)
            : base(data)
        {
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 1a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 1a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 1b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 1b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 1c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)  // set benchmark in utility
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 1c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
       * portfolio’s base value.  The roundlot constraint may result in 
       * infeasible solutions so the user can either relax the constraints or
       * round lot the optimization result in the client application (though 
       * this may result in a less “optimal” portfolio).
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 1d");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));
            // Enable Roundlotting; do not allow odd lot clostout 
            m_Profile.SetRoundlotConstraint(RoundlotConstraint.CreateBuilder()
                .SetAllowOddLotCloseout(false)
                .SetIsSoft(false));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 1d");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(10000000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            Initialize("1e", "Post optimization roundlotting", true);
            m_InitPf.AddHolding(Holding.CreateBuilder()
                .SetAssetId("CASH")
                .SetAmount(1.0));

            // Set price as required by roundlotting
            SetPrice();

            // Set lot size to 1000
            SetRoundlot(1000);

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 1e");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 1e");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetPortfolioBaseValue(10000000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 2c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 2c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetCashflowWeight(0.2);    // 20% cash contribution
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set asset bounds
            LinearConstraint.Builder linearConstraint = LinearConstraint.CreateBuilder();
            linearConstraint.SetNoncashAssetBound(NonCashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(0.0)
                .SetUpperBound(0.3));

            // Set cash bound
            m_InitPf.AddHolding(Holding.CreateBuilder()
                .SetAssetId("CASH")
                .SetAmount(0.2));
            linearConstraint.SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(0.1)
                .SetUpperBound(0.1));

            m_Profile.SetLinearConstraint(linearConstraint);

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
        }

        public void Tutorial_3b()
        {
            Initialize("3b", "Asset Relative Bounds");

            // Create asset bound attribute
            optimizer.proto.Attribute.Builder ubAttribute = optimizer.proto.Attribute.CreateBuilder();
            ubAttribute.SetAttributeId("AssetUpperBoundAttribute");
            ubAttribute.SetAttributeValueType(AttributeValueType.TEXT);
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                ubAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetTextValue("b + 0.001"));
            }
            m_PBData.AddAttribute(ubAttribute);

            optimizer.proto.Attribute.Builder lbAttribute = optimizer.proto.Attribute.CreateBuilder();
            lbAttribute.SetAttributeId("AssetLowerBoundAttribute");
            lbAttribute.SetAttributeValueType(AttributeValueType.TEXT);
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                lbAttribute.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetTextValue("b - 0.001"));
            }
            m_PBData.AddAttribute(lbAttribute);

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));
            // Set asset relative bound
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetAssetBounds(AssetBoundInfo.CreateBuilder()
                    .SetLowerBoundAttributeId("AssetLowerBoundAttribute")
                    .SetUpperBoundAttributeId("AssetUpperBoundAttribute")));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetReferencePortfolios(ReferencePortfolios.CreateBuilder()
                .SetPrimaryBenchmark(m_benchmarkPortfolioID));  // set reference portfolio for asset bound

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set asset bounds
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .AddFactorConstraint(FactorConstraintInfo.CreateBuilder()
                    .SetFactorId("Factor_1A")
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.01)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
            foreach (ConstraintDiagnosticInfo info in result.GetProfileDiagnostics(0).ConstraintDiagnosticsList)
            {
                if (info.ConstraintInfoId.Equals("Factor_1A"))
                {
                    Console.WriteLine("Optimal portfolio exposure to Factor_1A = {0:0.0000}", info.SlackValue);
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
        public void Tutorial_3d()
        {
            Initialize("3d", "Beta Constraint");

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3d");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Set beta constraint
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetBetaConstraint(BetaConstraintInfo.CreateBuilder()
                    .SetLowerBound(0.9)
                    .SetUpperBound(1.0)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3d");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("GICS_Sector")
                    .AddValue("Information Technology")));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3e");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set constraint by group, limit the exposure to Information Technology sector to 20%
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .AddConstraintByGroup(ConstraintByGroupInfo.CreateBuilder()
                    .SetConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("GICS_Sector")
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.2)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3e");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
        public void Tutorial_3f()
        {
            Initialize("3f", "Relative Constraints");

            // create asset attribute for GICS sector and coefficients
            SetGICSAttribute("GICS_Sector_Attribute");
            SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

            // Create grouping scheme for GICS sector
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("GICS_Sector")
                    .AddValue("Information Technology")));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3f");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set constraint by group, limit the exposure to Information Technology sector to 
            // 50% of the reference portfolio
            LinearConstraint.Builder linearConstraint = LinearConstraint.CreateBuilder();
            linearConstraint.AddConstraintByGroup(ConstraintByGroupInfo.CreateBuilder()
                .SetConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                .SetGroupingAttributeId("GICS_Sector_Attribute")
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .SetGroupId("GICS_Sector")
                .SetReferencePortfolioId(m_benchmarkPortfolioID)
                .SetLowerBound(0.0)
                .SetLowerBoundMode(ERelativeModeType.MULTIPLE)
                .SetUpperBound(0.5)
                .SetUpperBoundMode(ERelativeModeType.MULTIPLE));

            linearConstraint.AddFactorConstraint(FactorConstraintInfo.CreateBuilder()
                .SetFactorId("Factor_1A")
                .SetReferencePortfolioId(m_benchmarkPortfolioID)
                .SetLowerBound(-0.01)
                .SetLowerBoundMode(ERelativeModeType.PLUS)
                .SetUpperBound(0.01)
                .SetUpperBoundMode(ERelativeModeType.PLUS));

            m_Profile.SetLinearConstraint(linearConstraint);

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3f");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3g");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set Transaction Type to Sell None/Buy From Universe
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                    .SetTransactionType(ETransactionType.SELL_NONE_BUY_FROM_UNIV));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3g");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetCashflowWeight(0.3);  // Contribute 30% cash for buying additional securities

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_InitPf.AddHolding(Holding.CreateBuilder()
                .SetAssetId("CASH")
                .SetAmount(1.0));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 3h");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set Transaction Type to Sell None/Buy From Universe
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                    .SetTransactionType(ETransactionType.BUY_SHORT_FROM_UNIV)
                    .SetEnableCrossover(false));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 3h");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_InitPf.AddHolding(Holding.CreateBuilder()
                .SetAssetId("CASH")
                .SetAmount(1.0));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 4a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));
            // Invest all cash
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.0)));

            // Set max # of assets to be 6
            m_Profile.SetCardinalityConstraint(CardinalityConstraint.CreateBuilder()
                   .SetNumAssets(CardinalityConstraintInfo.CreateBuilder()
                        .SetMaximum(6)
                        .SetIsMaxSoft(false)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 4a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 4b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Invest all cash
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.0)));

            // set minimum holding threshold; both for long and short positions
            // in this example 4%
            // set minimum trade size; both for long and short positions
            // in this example 2%
            m_Profile.SetThresholdConstraint(ThresholdConstraint.CreateBuilder()
                   .SetLongSideHoldingLevel(ThresholdConstraintInfo.CreateBuilder()
                        .SetMinimum(0.04)
                        .SetIsMinSoft(false))
                   .SetShortSideHoldingLevel(ThresholdConstraintInfo.CreateBuilder()
                        .SetMinimum(0.04)
                        .SetIsMinSoft(false))
                   .SetLongSideTranxLevel(ThresholdConstraintInfo.CreateBuilder()
                        .SetMinimum(0.02)
                        .SetIsMinSoft(false))
                   .SetShortSideTranxLevel(ThresholdConstraintInfo.CreateBuilder()
                        .SetMinimum(0.02)
                        .SetIsMinSoft(false)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 4b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 4c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Set turnover constraint
            m_Profile.AddTurnoverConstraint(TurnoverConstraintInfo.CreateBuilder()
                   .SetBySide(EBySideType.NET)
                   .SetUsePortfolioBaseValue(false)
                   .SetIsSoft(true)
                   .SetUpperBound(0.2));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 4c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

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
        * into a relative weight via the share’s price. The simple-linear market impact
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

            m_InitPf = Portfolio.CreateBuilder().SetPortfolioId(m_initialPortfolioID);
            m_InitPf.AddHolding(Holding.CreateBuilder()
                   .SetAssetId("USA11I1")
                   .SetAmount(0.3));
            m_InitPf.AddHolding(Holding.CreateBuilder()
                    .SetAssetId("USA13Y1")
                    .SetAmount(0.7));

            SetPiecewiseLinearTransactionCost();

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 5a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .SetTransactionCostTerm(1.0));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 5a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

            PrintResult(RunOptimize());
        }

        /**\brief Nonlinear Transaction Costs
        *
        * Tutorial_5b illustrates how to set up the nonlinear transaction costs
        */
        public void Tutorial_5b()
        {
            Initialize("5b", "Nonlinear Transaction Costs");

            m_InitPf = Portfolio.CreateBuilder().SetPortfolioId(m_initialPortfolioID);
            m_InitPf.AddHolding(Holding.CreateBuilder()
                   .SetAssetId("USA11I1")
                   .SetAmount(0.3));
            m_InitPf.AddHolding(Holding.CreateBuilder()
                    .SetAssetId("USA13Y1")
                    .SetAmount(0.7));

            // Set nonlinear transaction cost
            m_PBData.SetTransactionCosts(TransactionCosts.CreateBuilder()
                .SetNonlinearTransactionCost(NonLinearTransactionCost.CreateBuilder()
                    .SetExponent(1.1)
                    .SetFittedCost(0.00001)
                    .SetTradedAmount(0.01)));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 5b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .SetTransactionCostTerm(1.0));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 5b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

            PrintResult(RunOptimize());
        }

        /**\brief Transaction Cost Constraints
        *
        * You can set up a constraint on the transaction cost.  Tutorial_5c demonstrates the setup:
        */
        public void Tutorial_5c()
        {
            Initialize("5c", "Transaction Cost Constraint");

            m_InitPf = Portfolio.CreateBuilder().SetPortfolioId(m_initialPortfolioID);
            m_InitPf.AddHolding(Holding.CreateBuilder()
                   .SetAssetId("USA11I1")
                   .SetAmount(0.3));
            m_InitPf.AddHolding(Holding.CreateBuilder()
                    .SetAssetId("USA13Y1")
                    .SetAmount(0.7));

            SetPiecewiseLinearTransactionCost();

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 5c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .SetTransactionCostTerm(1.0));
            m_Profile.SetTransactionCostConstraint(TransactionCostConstraintInfo.CreateBuilder()
                .SetUpperBound(0.0005));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 5c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 5d");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .SetTransactionCostTerm(1.0)
                .SetAlphaTerm(10.0));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 5d");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 5g");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Setup constraint
            m_Profile.AddGeneralPwliConstraint(GeneralPWLIConstraintInfo.CreateBuilder()
                .AddStartingPoint(StartingPoint.CreateBuilder().SetAssetId(m_Data.m_ID[0]).SetWeight(m_Data.m_BMWeight[0]))
                .AddDownside(PWLISegment.CreateBuilder().SetAssetId(m_Data.m_ID[0]).SetSlope(-0.01).SetBreakPoint(0.05))
                .AddDownside(PWLISegment.CreateBuilder().SetAssetId(m_Data.m_ID[0]).SetSlope(-0.03))
                .AddUpside(PWLISegment.CreateBuilder().SetAssetId(m_Data.m_ID[0]).SetSlope(0.02).SetBreakPoint(0.04))
                .AddUpside(PWLISegment.CreateBuilder().SetAssetId(m_Data.m_ID[0]).SetSlope(0.03))
                .SetLowerBound(0)
                .SetUpperBound(0.25));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 5g");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 6a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Set beta constraint
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetBetaConstraint(BetaConstraintInfo.CreateBuilder()
                    .SetLowerBound(-1 * GetOPT_INF())
                    .SetUpperBound(GetOPT_INF())
                    .SetPenalty(Penalty.CreateBuilder()
                        .SetTarget(0.95)
                        .SetLower(0.80)
                        .SetUpper(1.2)
                        .SetIsPureLinear(true)
                        .SetMultiplier(1.0))));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 6a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 7a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 7a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
            if (result.HasPortfolioSummary)
            {
                OptimalPortfolio optimalPf = result.PortfolioSummary.GetOptimalPortfolio(0);
                Console.WriteLine("Specific Risk(%) = {0:0.0000}", optimalPf.SpecificRisk);
                Console.WriteLine("Factor Risk(%) = {0:0.0000}", optimalPf.CommonFactorRisk);
            }

            Console.WriteLine("\nAdd a risk constraint: FactorRisk<=12%");

            m_Profile = m_WS.RebalanceProfiles.GetRebalanceProfile(0).ToBuilder();
            m_Profile.AddRiskConstraint(RiskConstraintInfo.CreateBuilder()
                .SetRiskSourceType(ERiskSourceType.FACTOR_RISK)
                .SetIsPrimaryRiskModel(true)
                .SetIsRiskContribution(false)
                .SetUpperBound(0.12)
                .SetIsSoft(false));

            m_RebalanceJob = m_WS.RebalanceJob.ToBuilder();
            RebalanceResult result2 = RunOptimize();
            PrintResult(result2);
            if (result.HasPortfolioSummary)
            {
                OptimalPortfolio optimalPf = result2.PortfolioSummary.GetOptimalPortfolio(0);
                Console.WriteLine("Specific Risk(%) = {0:0.0000}", optimalPf.SpecificRisk);
                Console.WriteLine("Factor Risk(%) = {0:0.0000}", optimalPf.CommonFactorRisk);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 7b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            m_Profile.AddRiskConstraint(RiskConstraintInfo.CreateBuilder()
                .SetConstraintInfoId("RiskConstraint")
                .SetRiskSourceType(ERiskSourceType.TOTAL_RISK)
                .SetIsPrimaryRiskModel(true)
                .SetReferencePortfolioId(m_modelPortfolioID)
                .SetIsRiskContribution(false)
                .SetUpperBound(0.16)
                .SetIsSoft(false));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 7b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 7d");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            SetGroupingAttribute("RiskByAsset", new string[] { "USA11I1", "USA13Y1" });
            m_Profile.AddRiskConstraintByGroup(RiskConstraintByGroupInfo.CreateBuilder()
                .SetConstraintInfoId("RiskByAsset")
                .SetAssetGroupingAttributeId("RiskByAsset")
                .SetAssetGroupId("RiskByAsset_Group")
                .SetAssetGroupingSchemeId("RiskByAsset_GroupingScheme")
                .SetRiskSourceType(ERiskSourceType.TOTAL_RISK)
                .SetIsPrimaryRiskModel(true)
                .SetIsRiskContribution(false)
                .SetIsAdditiveDefinition(true)
                .SetIsSoft(false)
                .SetIsByAsset(true)
                .SetLowerBound(0.03)
                .SetUpperBound(0.05));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder()
                .SetRebalanceProfileId("Case 7d")
                .SetInitialPortfolioId(m_initialPortfolioID)
                .SetPortfolioBaseValue(100000)
                .SetPrimaryRiskModelId(m_primaryRiskModelID)
                .SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
            PrintSlackInfoList(result);
            Console.WriteLine();
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
            Initialize("8a", "Long-Short Hedge Optimization", true);

            // All cash in initial portfolio
            m_InitPf.ClearHolding()
                .AddHolding(Holding.CreateBuilder()
                    .SetAssetId("CASH")
                    .SetAmount(1.0));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 8a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            LinearConstraint.Builder linearConstraint = LinearConstraint.CreateBuilder();
            linearConstraint.SetNoncashAssetBound(NonCashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(-1.0)
                .SetUpperBound(1.0));
            linearConstraint.SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(-0.3)
                .SetUpperBound(0.3));
            m_Profile.SetLinearConstraint(linearConstraint);

            // Set leverage constraints
            m_Profile.AddLeverageConstraint(LeverageConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.LONG)
                .SetNoChange(false)
                .SetLowerBound(1.0)
                .SetUpperBound(1.3));
            m_Profile.AddLeverageConstraint(LeverageConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.SHORT)
                .SetNoChange(false)
                .SetLowerBound(-0.3)
                .SetUpperBound(0.0));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 8a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(10000000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("GICS_Sector")
                    .AddValue("Information Technology")));

            // All cash in initial portfolio
            m_InitPf.ClearHolding()
                .AddHolding(Holding.CreateBuilder()
                    .SetAssetId("CASH")
                    .SetAmount(1.0));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 8c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            LinearConstraint.Builder linearConstraint = LinearConstraint.CreateBuilder();
            linearConstraint.SetNoncashAssetBound(NonCashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(-1.0)
                .SetUpperBound(1.0));
            linearConstraint.SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                .SetLowerBound(-0.3)
                .SetUpperBound(0.3));

            // Set total leverage factor constraint
            linearConstraint.AddFactorConstraint(FactorConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.TOTAL)
                .SetFactorId("Factor_1A")
                .SetLowerBound(1.0)
                .SetUpperBound(1.3)
                .SetIsSoft(true)
                .SetPenalty(Penalty.CreateBuilder()
                    .SetTarget(0.95)
                    .SetLower(0.80)
                    .SetUpper(1.2)));

            // Set total leverage group constraint
            linearConstraint.AddConstraintByGroup(ConstraintByGroupInfo.CreateBuilder()
                .SetBySide(EBySideType.TOTAL)
                .SetConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                .SetGroupingAttributeId("GICS_Sector_Attribute")
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .SetGroupId("GICS_Sector")
                .SetLowerBound(1.0)
                .SetUpperBound(1.3)
                .SetIsSoft(true)
                .SetPenalty(Penalty.CreateBuilder()
                    .SetTarget(0.95)
                    .SetLower(0.80)
                    .SetUpper(1.2)));

            m_Profile.SetLinearConstraint(linearConstraint);

            // Set weighted total leverage constraint
            SetCoefficientAttribute("WTLC_Long_Coeff_Attribute", 1.0);
            SetCoefficientAttribute("WTLC_Short_Coeff_Attribute", 1.0);

            m_Profile.AddWeightedTotalLeverageConstraint(WeightedTotalLeverageConstraintInfo.CreateBuilder()
                .SetLongSideAttributeId("WTLC_Long_Coeff_Attribute")
                .SetShortSideAttributeId("WTLC_Short_Coeff_Attribute")
                .SetLowerBound(1.0)
                .SetUpperBound(1.3)
                .SetIsSoft(true)
                .SetPenalty(Penalty.CreateBuilder()
                    .SetTarget(0.95)
                    .SetLower(0.80)
                    .SetUpper(1.2)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 8c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(10000000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 9a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetIsPrimaryRiskModel(true)
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 9a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .SetOptimizationType(EOptimizationType.RISK_TARGET)
                .SetRiskTarget(0.14));  // set risk target

            RebalanceResult result = RunOptimize();
            PrintResult(result);
        }

        /**\brief Return Target
        *
        * Similar to Tutoral_9a, we define a return target of 1% in Tutorial_9b:
        */
        public void Tutorial_9b()
        {
            Initialize("9b", "Return Target", true);

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 9b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetIsPrimaryRiskModel(true)
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 9b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .SetOptimizationType(EOptimizationType.RETURN_TARGET)
                .SetReturnTarget(0.01));  // set return target

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("GICS_Sector")
                    .AddValue("Information Technology")));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 10c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));
            // Set constraints
            m_Profile.SetTaxConstraints(TaxConstraints.CreateBuilder()
                .AddTaxArbitrageRange(TaxArbitrageConstraint.CreateBuilder()
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("GICS_Sector")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetTaxCategory(ETaxCategory.LONG_TERM)
                    .SetGainType(ECapitalGainType.CAPITAL_GAIN)
                    .SetTaxConstraint(TaxArbitrageConstraintInfo.CreateBuilder()
                        .SetUpperBound(250.0))));
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetLowerBoundMode(ERelativeModeType.ABSOLUTE))
                .SetAssetBounds(AssetBoundInfo.CreateBuilder()
                    .SetLowerBoundAttributeId("asset_lower_bound_attribute")));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 10c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(4279.45);
            m_RebalanceJob.SetCashflowWeight(0.0);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .AddTaxSetting(TaxSetting.CreateBuilder()
                    .SetTaxUnit(ETaxUnit.DOLLAR)
                    .AddTaxRule(TaxRule.CreateBuilder()
                        .SetEnableTwoRate(true)
                        .SetLongTermRate(0.243)
                        .SetShortTermRate(0.423)
                        .SetShortTermPeriod(365)
                        .SetWashSalePeriod(30)
                        .SetWashSaleRule(EWashSaleRule.DISALLOWED))
                    .AddSellingOrderRule(SellingOrderRuleByGroupInfo.CreateBuilder()
                        .SetRule(ESellingOrderRule.FIFO))));

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
            Initialize("10d", "Tax-aware Optimization (Using new APIs introduced in v8.8) with cash outflow");

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
                m_InitPf.SetHolding(i, Holding.CreateBuilder()
                            .SetAssetId(m_Data.m_ID[i])
                            .SetAmount(assetValue[i] / BV));
            }

            // create asset attribute for GICS sector and coefficients
            SetGICSAttribute("GICS_Sector_Attribute");
            SetCoefficientAttribute("GICS_Sector_Coeff_Attribute", 1.0);

            // Create grouping scheme for GICS sector
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("GICS_Sector")
                    .AddValue("Information Technology")));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 10d");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));
            // Set constraints
            m_Profile.SetTaxConstraints(TaxConstraints.CreateBuilder()
                .AddTaxArbitrageRange(TaxArbitrageConstraint.CreateBuilder()
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("GICS_Sector")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetTaxCategory(ETaxCategory.LONG_TERM)
                    .SetGainType(ECapitalGainType.CAPITAL_GAIN)
                    .SetTaxConstraint(TaxArbitrageConstraintInfo.CreateBuilder()
                        .SetUpperBound(250.0))));
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetLowerBoundMode(ERelativeModeType.ABSOLUTE))
                .SetAssetBounds(AssetBoundInfo.CreateBuilder()
                    .SetLowerBoundAttributeId("asset_lower_bound_attribute")));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 10d");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(BV);
            m_RebalanceJob.SetCashflowWeight(CFW);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .AddTaxSetting(TaxSetting.CreateBuilder()
                    .SetTaxUnit(ETaxUnit.DOLLAR)
                    .AddTaxRule(TaxRule.CreateBuilder()
                        .SetEnableTwoRate(true)
                        .SetLongTermRate(0.243)
                        .SetShortTermRate(0.423)
                        .SetShortTermPeriod(365)
                        .SetWashSalePeriod(30)
                        .SetWashSaleRule(EWashSaleRule.DISALLOWED))
                    .AddSellingOrderRule(SellingOrderRuleByGroupInfo.CreateBuilder()
                        .SetRule(ESellingOrderRule.FIFO))));

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 10e");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075))
                .SetLossBenefitTerm(1.0));

            // Set constraints
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetTransactionType(ETransactionType.SHORT_NONE));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 10e");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(4279.45);
            m_RebalanceJob.SetCashflowWeight(0.0);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .AddTaxSetting(TaxSetting.CreateBuilder()
                    .SetTaxUnit(ETaxUnit.DOLLAR)
                    .AddTaxRule(TaxRule.CreateBuilder()
                        .SetEnableTwoRate(true)
                        .SetLongTermRate(0.243)
                        .SetShortTermRate(0.423)
                        .SetShortTermPeriod(365)
                        .SetWashSalePeriod(30)
                        .SetWashSaleRule(EWashSaleRule.DISALLOWED))
                    .AddSellingOrderRule(SellingOrderRuleByGroupInfo.CreateBuilder()
                        .SetRule(ESellingOrderRule.FIFO))));

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
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("Information Technology")
                    .AddValue("Information Technology"))
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("Financials")
                    .AddValue("Financials")));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 10f");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));
            // Linear constraints
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetTransactionType(ETransactionType.SHORT_NONE)
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.0)));
            // Tax constraints
            m_Profile.SetTaxConstraints(TaxConstraints.CreateBuilder()
                .AddTaxArbitrageRange(TaxArbitrageConstraint.CreateBuilder()
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("Financials")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetGainType(ECapitalGainType.CAPITAL_LOSS)
                    .SetTaxConstraint(TaxArbitrageConstraintInfo.CreateBuilder()
                        .SetUpperBound(100.0)))
                .AddTaxArbitrageRange(TaxArbitrageConstraint.CreateBuilder()
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("Information Technology")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetGainType(ECapitalGainType.CAPITAL_GAIN)
                    .SetTaxConstraint(TaxArbitrageConstraintInfo.CreateBuilder()
                        .SetLowerBound(250.0))));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder()
                .SetRebalanceProfileId("Case 10f")
                .SetInitialPortfolioId(m_initialPortfolioID)
                .SetPortfolioBaseValue(4279.45)
                .SetCashflowWeight(0.0)
                .SetPrimaryRiskModelId(m_primaryRiskModelID)
                .SetUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .AddTaxSetting(TaxSetting.CreateBuilder()
                    .SetTaxUnit(ETaxUnit.DOLLAR)
                    .AddTaxRule(TaxRule.CreateBuilder()
                        .SetEnableTwoRate(true)
                        .SetLongTermRate(0.243)
                        .SetShortTermRate(0.423)
                        .SetShortTermPeriod(365)
                        .SetWashSalePeriod(30)
                        .SetWashSaleRule(EWashSaleRule.DISALLOWED))
                    .AddSellingOrderRule(SellingOrderRuleByGroupInfo.CreateBuilder()
                        .SetRule(ESellingOrderRule.FIFO))));

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
            optimizer.proto.TaxLotInfos.Builder taxLots = optimizer.proto.TaxLotInfos.CreateBuilder();
            taxLots.MergeFrom(m_PBData.TaxLots);
            taxLots.AddTaxLot(optimizer.proto.TaxLotInfo.CreateBuilder()
                .SetAssetId("USA11I1")
                .SetAge(12)
                .SetCostBasis(21.44)
                .SetShares(20.0));
            m_PBData.SetTaxLots(taxLots);

            // Recalculate asset weight from tax lot data
            double pfValue = UpdatePortfolioWeights();

            optimizer.proto.WashSaleRecords.Builder washSales = optimizer.proto.WashSaleRecords.CreateBuilder();
            washSales
                .AddWashSale(new WashSaleRecord.Builder { AssetId = "USA2ND1", Age = 20, LossPerShare = 12.54, Shares = 10.0 })
                .AddWashSale(new WashSaleRecord.Builder { AssetId = "USA3351", Age = 35, LossPerShare = 2.42, Shares = 25.0 })
                .AddWashSale(new WashSaleRecord.Builder { AssetId = "USA39K1", Age = 12, LossPerShare = 9.98, Shares = 25.0 });
            m_PBData.SetWashSales(washSales);

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 10g");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));
            // Linear constraints
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .SetTransactionType(ETransactionType.SHORT_NONE)
                .SetCashAssetBound(CashAssetBoundInfo.CreateBuilder()
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.0)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder()
                .SetRebalanceProfileId("Case 10g")
                .SetInitialPortfolioId(m_initialPortfolioID)
                .SetPortfolioBaseValue(pfValue)
                .SetCashflowWeight(0.0)
                .SetPrimaryRiskModelId(m_primaryRiskModelID)
                .SetUniversePortfolioId(m_universePortfolioID);

            // Set tax rules
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .AddTaxSetting(TaxSetting.CreateBuilder()
                    .SetTaxUnit(ETaxUnit.DOLLAR)
                    .AddTaxRule(TaxRule.CreateBuilder()
                        .SetEnableTwoRate(true)
                        .SetLongTermRate(0.243)
                        .SetShortTermRate(0.423)
                        .SetShortTermPeriod(365)
                        .SetWashSalePeriod(40)
                        .SetWashSaleRule(EWashSaleRule.TRADEOFF))
                    .AddSellingOrderRule(SellingOrderRuleByGroupInfo.CreateBuilder()
                        .SetRule(ESellingOrderRule.FIFO))));

            RebalanceResult result = RunOptimize();
            PrintResult(result);

            // Retrieving tax related information from the output
            if (result.HasPortfolioSummary)
            {
                foreach (OptimalPortfolio portfolio in result.PortfolioSummary.OptimalPortfolioList)
                {
                    if (portfolio.HasPortfolioTax)
                    {
                        TaxOutput taxOutput = portfolio.PortfolioTax;

                        // Shares in tax lots
                        Console.WriteLine("TaxlotID          Shares:");
                        foreach (TaxOutputByAsset taxByAsset in taxOutput.AssetTaxDetailList)
                        {
                            foreach (TaxLotShares taxLotShares in taxByAsset.TaxLotSharesList)
                            {
                                if (taxLotShares.Shares > 0)
                                    Console.WriteLine("{0}  {1:0.0000}", taxLotShares.TaxLotId, taxLotShares.Shares);
                            }
                        }

                        // New shares
                        Console.WriteLine("\nNew Shares:");
                        foreach (TaxOutputByAsset taxByAsset in taxOutput.AssetTaxDetailList)
                        {
                            if (taxByAsset.NewShares > 0)
                                Console.WriteLine("{0}:  {1:0.0000}", taxByAsset.AssetId, taxByAsset.NewShares);
                        }
                        Console.WriteLine("");

                        // Disqualified shares
                        Console.WriteLine("Disqualified Shares:");
                        foreach (DisqualifiedShares disqShares in taxOutput.DisqualifiedSharesList)
                        {
                            Console.WriteLine("{0}:  {1:0.0000}", disqShares.WashSaleId, disqShares.Shares);
                        }
                        Console.WriteLine("");

                        // Wash sale details
                        Console.WriteLine("Wash Sale Details:");
                        Console.WriteLine("{0,-20}{1,12}{2,10}{3,10}{4,12}{5,20}",
                            "TaxLotID", "AdjustedAge", "CostBasis", "Shares", "SoldShares", "DisallowedLotID");
                        foreach (TaxOutputByAsset taxByAsset in taxOutput.AssetTaxDetailList)
                        {
                            foreach (WashSaleDetail wsDetail in taxByAsset.WashSaleDetailList)
                            {
                                Console.WriteLine("{0,-20}{1,12}{2,10:0.0000}{3,10:0.0000}{4,12:0.0000}{5,20}",
                                    wsDetail.LotId, wsDetail.AdjustedAge, wsDetail.AdjustedCostBasis,
                                    wsDetail.Shares, wsDetail.SoldShares, wsDetail.DisallowedLotId);
                            }
                        }
                        Console.WriteLine("");
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 11a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 11a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .SetOptimizationType(EOptimizationType.EFFICIENT_FRONTIER)
                .SetFrontier(Frontier.CreateBuilder()
                    .SetFrontierType(EFrontierType.RISK_RETURN)
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.1)
                    .SetMaxDataPoints(10)));  // set frontier

            RebalanceResult result = RunOptimize();

            Console.WriteLine(result.OptimizationStatus.Message);
            Console.WriteLine(result.OptimizationStatus.SolverLog);

            if (result.HasPortfolioSummary)
            {
                int index = 0;
                PortfolioSummary portfolioSummary = result.PortfolioSummary;
                foreach (OptimalPortfolio optimalPortfolio in portfolioSummary.OptimalPortfolioList)
                {
                    Console.WriteLine("{0}: Risk(%) = {1:0.000} \tReturn(%) = {2:0.000}",
                        index++, optimalPortfolio.TotalRisk, optimalPortfolio.Return);
                }
                Console.WriteLine();
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 12a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC));

            m_Profile.SetThresholdConstraint(ThresholdConstraint.CreateBuilder()
                // Set minimum holding threshold; both for long and short positions
                // in this example 10%
                .SetLongSideHoldingLevel(ThresholdConstraintInfo.CreateBuilder()
                    .SetMinimum(0.1))
                .SetShortSideHoldingLevel(ThresholdConstraintInfo.CreateBuilder()
                    .SetMinimum(0.1))
                // Set minimum trade size; both for long and short positions
                // in this example 20%
                .SetLongSideTranxLevel(ThresholdConstraintInfo.CreateBuilder()
                    .SetMinimum(0.2))
                .SetShortSideTranxLevel(ThresholdConstraintInfo.CreateBuilder()
                    .SetMinimum(0.2)));

            m_Profile.SetCardinalityConstraint(CardinalityConstraint.CreateBuilder()
                .SetNumAssets(CardinalityConstraintInfo.CreateBuilder()
                    .SetMinimum(5)) // Set Min # assets to 5, excluding cash and futures
                 .SetNumTrades(CardinalityConstraintInfo.CreateBuilder()
                    .SetMaximum(3)));   // Set Max # trades to 3 

            // Set leverage constraints
            m_TradeUniverse.AddHolding(Holding.CreateBuilder()
                .SetAssetId("CASH")
                .SetAmount(0.0));   // Cash is required for L/S optimization 
            m_Profile.AddLeverageConstraint(LeverageConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.LONG)
                .SetLowerBound(1.0)
                .SetUpperBound(1.1));
            m_Profile.AddLeverageConstraint(LeverageConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.SHORT)
                .SetLowerBound(-0.3)
                .SetUpperBound(-0.3));
            m_Profile.AddLeverageConstraint(LeverageConstraintInfo.CreateBuilder()
                .SetBySide(EBySideType.TOTAL)
                .SetLowerBound(1.5)
                .SetUpperBound(1.5));

            // Set constraint priority
            m_Profile.AddConstraintPriority(ConstraintPriority.CreateBuilder()
                .SetCategory(EConstraintCategory.ASSET_CARDINALITY)
                .SetRelaxOrder(ERelaxOrderType.FIRST));
            m_Profile.AddConstraintPriority(ConstraintPriority.CreateBuilder()
                .SetCategory(EConstraintCategory.HEDGE)
                .SetRelaxOrder(ERelaxOrderType.SECOND));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 12a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe

            RebalanceResult result = RunOptimize();
            PrintResult(result);
        }

        /** \brief Shortfall Beta Constraint
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for setting up shortfall beta constraint.  The shortfall beta data are 
        * read from a file that is an output file of BxR example.
        */
        public void Tutorial_14a()
        {
            Initialize("14a", "Shortfall Beta Constraint", true);

            SetShortfalBetaAttribute("Shortfall_Beta_Attribute");

            // Build rebalance profile, set utility
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 14a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                    .SetIsPrimaryRiskModel(true)
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetCommonFactorRiskAversion(0.0075)
                    .SetSpecificRiskAversion(0.0075)));

            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .AddCustomConstraint(CustomConstraintInfo.CreateBuilder()
                    .SetConstraintInfoId("ShortfallBetaCon")
                    .SetAttributeId("Shortfall_Beta_Attribute")
                    .SetLowerBound(0.9)
                    .SetUpperBound(0.9)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 14a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetOptimizationSetting(OptimizationSetting.CreateBuilder()
                .SetOptimizationType(EOptimizationType.RISK_TARGET)
                .SetRiskTarget(0.05));  // set risk target

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 15a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075))
                // Set risk aversions for CF and SP to 0.0075 for secondary risk model; No benchmark
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(false)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 15a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model 

            PrintResult(RunOptimize());
        }

        /** \brief Constrain risk from secondary risk model
        *
        * This self-documenting sample code illustrates how to use Barra Optimizer
        * for constraining risk from secondary risk model
        */
        public void Tutorial_15b()
        {
            Initialize("15b", "Risk Budgeting - Dual Risk Model");

            SetupRiskModel2();

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 15b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // set total risk from the secondary risk model 
            m_Profile.AddRiskConstraint(RiskConstraintInfo.CreateBuilder()
                .SetRiskSourceType(ERiskSourceType.TOTAL_RISK)
                .SetConstraintInfoId("RiskConstraint")
                .SetIsPrimaryRiskModel(false)
                .SetReferencePortfolioId(m_modelPortfolioID)
                .SetUpperBound(0.1));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 15b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model 

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
            Initialize("15c", "Risk parity constraint");

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 15c");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Add all assets except USA11I1 to risk parity constraint
            optimizer.proto.Attribute.Builder rpAttribute = optimizer.proto.Attribute.CreateBuilder();
            rpAttribute.SetAttributeId("RiskParity_AssetGroupID");
            rpAttribute.SetAttributeValueType(AttributeValueType.DOUBLE);
            for (int i = 0; i < m_Data.m_AssetNum; i++)
            {
                if (m_Data.m_ID[i] != "USA11I1")
                    rpAttribute.AddElement(Element.CreateBuilder()
                        .SetElementId(m_Data.m_ID[i])
                        .SetDoubleValue(0));
            }
            m_PBData.AddAttribute(rpAttribute);

            // Set Transaction Type to Short None
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                    .SetTransactionType(ETransactionType.SHORT_NONE));

            // Set risk parity constraint
            m_Profile.SetRiskParityConstraint(RiskParityConstraintInfo.CreateBuilder()
                .SetEnabled(true)
                .SetType(ERiskParityType.ASSET_RISK_PARITY)
                .SetGroupingAttributeId("RiskParity_AssetGroupID")
                .SetCanUseExcluded(false)
                .SetIsPrimaryRiskModel(true));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 15c");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 16a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                // Set risk aversions for CF and SP to 0.0075 for primary risk model; No benchmark
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075))
                .AddCovarianceTerm(CovarianceTerm.CreateBuilder()
                    .SetCovarianceTermType(ECovarianceTermType.WXFXW)
                    .SetCovarianceTerm_(0.0075)
                    .SetIsPrimaryRiskModel(false)
                    .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                    .SetWeightMatrixAttributeId("Covterm_Weight_Coeff_Attribute")));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 16a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetSecondaryRiskModelId(m_secondaryRiskModelID); // Setup Secondary Risk Model 

            RebalanceResult result = RunOptimize();
            PrintResult(result);
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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 17a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Set 5-10-40 rule
            m_Profile.SetFiveTenFortyRule(FiveTenFortyRule.CreateBuilder()
                .SetFive(5)
                .SetTen(10)
                .SetForty(40));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 17a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 18");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));
            FactorBlocks.Builder factorBlocks = FactorBlocks.CreateBuilder();
            factorBlocks.AddFactorBlock(FactorBlock.CreateBuilder()
                    .SetFactorBlockId("A")
                    .AddFactorId("Factor_1A")
                    .AddFactorId("Factor_2A")
                    .AddFactorId("Factor_3A")
                    .AddFactorId("Factor_4A")
                    .AddFactorId("Factor_5A")
                    .AddFactorId("Factor_6A")
                    .AddFactorId("Factor_7A")
                    .AddFactorId("Factor_8A")
                    .AddFactorId("Factor_9A"));
            factorBlocks.AddFactorBlock(FactorBlock.CreateBuilder()
                    .SetFactorBlockId("B")
                    .AddFactorId("Factor_1B")
                    .AddFactorId("Factor_2B")
                    .AddFactorId("Factor_3B")
                    .AddFactorId("Factor_4B")
                    .AddFactorId("Factor_5B")
                    .AddFactorId("Factor_6B")
                    .AddFactorId("Factor_7B")
                    .AddFactorId("Factor_8B")
                    .AddFactorId("Factor_9B"));
            m_PrimaryRiskModel.SetFactorBlocks(factorBlocks);

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 18");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);

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
            try
            {
                String executable = "openopt.exe";
                String modelsDirectPath = String.Concat("\"", m_Data.m_Datapath, "\"");
                long analysisDate = 20130501;
                String riskModelFile = "USE4L.pb";
                String commandLine = " -md"
                        + " -m " + modelName
                        + " -d " + analysisDate
                        + " -o " + riskModelFile
                        + " -path " + modelsDirectPath;
                Console.WriteLine(executable + commandLine);

                Process process = new Process();
                ProcessStartInfo startInfo = new ProcessStartInfo();
                startInfo.WindowStyle = ProcessWindowStyle.Hidden;
                startInfo.FileName = executable;
                startInfo.Arguments = commandLine;
                startInfo.UseShellExecute = false;
                process.StartInfo = startInfo;
                process.Start();
                process.WaitForExit();
                if (process.ExitCode != 0)
                {
                    Console.WriteLine("Error running " + startInfo.FileName);
                    return;
                }
                FileStream input = File.Open(riskModelFile, FileMode.Open);
                RiskModel rm = RiskModel.ParseFrom(input);
                m_PrimaryRiskModel = rm.ToBuilder();
            }
            catch (Exception e)
            {
                Console.WriteLine(e.Message);
                return;
            }
            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 19");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetBenchmarkPortfolioId(m_benchmarkPortfolioID)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));
            // Set factor constraint
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .AddFactorConstraint(FactorConstraintInfo.CreateBuilder()
                    .SetFactorId("USE4L_SIZE")
                    .SetLowerBound(0.02)
                    .SetUpperBound(0.05)));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 19");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(modelName);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);

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
            optimizer.proto.Attribute.Builder numeratorCoeffs = optimizer.proto.Attribute.CreateBuilder();
            numeratorCoeffs.SetAttributeId("RatioConstraintNumerCoeffs");
            numeratorCoeffs.SetAttributeValueType(AttributeValueType.DOUBLE);
            for (int i = 1; i <= 3; i++)
            {
                numeratorCoeffs.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(m_Data.m_SpCov[i]));
            }
            m_PBData.AddAttribute(numeratorCoeffs);

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 28a");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Add a ratio constraint
            m_Profile.AddGeneralRatioConstraint(GeneralRatioConstraintInfo.CreateBuilder()
                .SetConstraintInfoId("RatioConstraint")
                .SetNumeratorAttributeId("RatioConstraintNumerCoeffs")
                .SetLowerBound(0.05)
                .SetUpperBound(0.1));


            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 28a");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID); // set trade universe
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_PBData.AddGroupingScheme(GroupingScheme.CreateBuilder()
                .SetGroupingSchemeId("GICS_Grouping_Scheme")
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("Information Technology")
                    .AddValue("Information Technology"))
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("Financials")
                    .AddValue("Financials"))
                .AddGroup(Group.CreateBuilder()
                    .SetGroupId("Minerals")
                    .AddValue("Minerals")));

            // Set constraint by group, limit the exposure to Information Technology sector to 20%
            m_Profile.SetLinearConstraint(LinearConstraint.CreateBuilder()
                .AddConstraintByGroup(ConstraintByGroupInfo.CreateBuilder()
                    .SetConstraintAttributeId("GICS_Sector_Coeff_Attribute")
                    .SetGroupingAttributeId("GICS_Sector_Attribute")
                    .SetGroupingSchemeId("GICS_Grouping_Scheme")
                    .SetGroupId("GICS_Sector")
                    .SetLowerBound(0.0)
                    .SetUpperBound(0.2)));

            // Build rebalance profile, set utility and risk aversion
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 28b");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Add a ratio constraints
            // 1. Weight of "Financials" assets can be at most half of "Information Technology" assets
            m_Profile.AddGroupRatioConstraint(GroupRatioConstraintInfo.CreateBuilder()
                .SetConstraintInfoId("Financials / IT")
                .SetNumeratorAttributeId("GICS_Sector_Coeff_Attribute")
                .SetNumeratorGroupingAttributeId("GICS_Sector_Attribute")
                .SetNumeratorGroupingSchemeId("GICS_Grouping_Scheme")
                .SetNumeratorGroupId("Financials")
                .SetDenominatorGroupId("Information Technology") // same grouping scheme as for the numerator
                .SetUpperBound(0.5));
            // 2. Ratio of "Information Technology" to "Minerals" should not differ from the benchmark more than +-10%
            m_Profile.AddGroupRatioConstraint(GroupRatioConstraintInfo.CreateBuilder()
                .SetConstraintInfoId("Minerals / IT")
                .SetNumeratorAttributeId("GICS_Sector_Coeff_Attribute")
                .SetNumeratorGroupingAttributeId("GICS_Sector_Attribute")
                .SetNumeratorGroupingSchemeId("GICS_Grouping_Scheme")
                .SetNumeratorGroupId("Minerals")
                .SetDenominatorGroupId("Information Technology") // same grouping scheme as for the numerator
                .SetReferencePortfolioId(m_benchmarkPortfolioID)
                .SetLowerBound(-0.1)
                .SetLowerBoundMode(ERelativeModeType.PLUS)
                .SetUpperBound(0.1)
                .SetUpperBoundMode(ERelativeModeType.PLUS));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder();
            m_RebalanceJob.SetRebalanceProfileId("Case 28b");
            m_RebalanceJob.SetInitialPortfolioId(m_initialPortfolioID);
            m_RebalanceJob.SetUniversePortfolioId(m_universePortfolioID);
            m_RebalanceJob.SetPortfolioBaseValue(100000);
            m_RebalanceJob.SetPrimaryRiskModelId(m_primaryRiskModelID);

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
            m_Profile = RebalanceProfile.CreateBuilder();
            m_Profile.SetRebalanceProfileId("Case 29");
            m_Profile.SetUtility(Utility.CreateBuilder()
                .SetUtilityType(EUtilityType.QUADRATIC)
                .AddRiskTerm(RiskTerm.CreateBuilder()
                                .SetIsPrimaryRiskModel(true)
                                .SetCommonFactorRiskAversion(0.0075)
                                .SetSpecificRiskAversion(0.0075)));

            // Create a symmetric matrix for quadratic coefficients
            optimizer.proto.SymmetricMatrix.Builder quadraticCoeffs = optimizer.proto.SymmetricMatrix.CreateBuilder();
            quadraticCoeffs.SetId("Q");
            string[] rowids = { "USA11I1", "USA13Y1", "USA1LI1" };
            foreach (string rowid in rowids)
            {
                quadraticCoeffs.AddRowId(rowid);
            }
            double[] values = { 0.92473646, 0, 0, 0.60338704, 0.38904854, 0.63569677 };
            foreach (double v in values)
            {
                quadraticCoeffs.AddValue(v);
            }
            m_PBData.AddSymmetricMatrix(quadraticCoeffs);

            // Create attribute for numerator coefficients
            optimizer.proto.Attribute.Builder linearCoeffs = optimizer.proto.Attribute.CreateBuilder();
            linearCoeffs.SetAttributeId("q");
            linearCoeffs.SetAttributeValueType(AttributeValueType.DOUBLE);
            for (int i = 1; i < 6; i++)
            {
                linearCoeffs.AddElement(Element.CreateBuilder()
                                        .SetElementId(m_Data.m_ID[i])
                                        .SetDoubleValue(0.1));
            }
            m_PBData.AddAttribute(linearCoeffs);

            // Add a quadratic constraint
            m_Profile.AddQuadraticConstraint(QuadraticConstraintInfo.CreateBuilder()
                .SetQuadraticTermMatrixId("Q")
                .SetLinearTermAttributeId("q")
                .SetUpperBound(0.1));

            // Build rebalance job, set profile ID, initial portfolio and primary risk model
            m_RebalanceJob = RebalanceJob.CreateBuilder()
                .SetRebalanceProfileId("Case 29")
                .SetInitialPortfolioId(m_initialPortfolioID)
                .SetUniversePortfolioId(m_universePortfolioID)
                .SetPortfolioBaseValue(100000)
                .SetPrimaryRiskModelId(m_primaryRiskModelID);

            PrintResult(RunOptimize());
        }

    }
}
