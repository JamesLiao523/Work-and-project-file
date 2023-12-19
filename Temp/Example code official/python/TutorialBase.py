# @file TutorialBase.cs
# \brief Contains definition of the TutorialBase class with
# the shared routines for all tutorials.
#

#\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
#
import barraopt
from collections import OrderedDict

## Contains the shared data structures & routines for collecting KKT terms.
class KKTCons(object):
    KKT_SIDE_DEFAULT = 0;
    KKT_UPSIDE = 1;
    KKT_DOWNSIDE = -1;    

    def __init__(self, term, id, title, side, pen):
        self.constraintID = id
        self.displayName = title
        self.isPenalty = pen
        self.upOrDownside = side
        self.weights = OrderedDict()
        
        for asset in term:
            self.weights[asset] = term.GetValue(asset)
    
    def Contains(self, id):
        return id in self.weights
    def Get(self, id):
        return self.weights[id]
    def Keyset(self):
        return self.weights.keys()
    

## Contains shared class/routines for a KKT table.
import sys
class KKTData(object):

    def __init__(self):
        self.kkt = []

    def AddConstraintPenalty(self, attr, cid, title, side=KKTCons.KKT_SIDE_DEFAULT):
        self.AddConstraint(attr, cid, title, side, True)

    def AddOnlyIfDifferentPenalty(self, attr, cid, title, side=KKTCons.KKT_DOWNSIDE):
        self.AddOnlyIfDifferent(attr, cid, title, side, True)

    def AddConstraint(self, attr, cid, title, side=KKTCons.KKT_SIDE_DEFAULT, pen=False):
        # check if it's an empty or all-zero column
        i = 0
        for id in attr:
            # check if id is in the optimal portfolio
            if (len(self.kkt)==0) or (self.kkt[0].Contains(id)):
                # larger than display threshold
                val = attr.GetValue(id)
                if val<0.0: 
                    val = -val
                if val >= 1.0e-6: 
                    break
            i=i+1

    # not empty
        if i!=attr.GetCount():
            self.kkt.append(KKTCons(attr, cid, title, side, pen))

    def AddOnlyIfDifferent(self, attr, cid, title, side=KKTCons.KKT_DOWNSIDE, pen=False):
        numCol = len(self.kkt)
    # check if it's an empty or all-zero column
        i=0
        for id in attr:
            val = attr.GetValue(id);
        # excludes ids not in the optimal portfolio and same value as the column before
            if numCol==0 or (self.kkt[0].Contains(id) and val!=self.kkt[numCol-1].Get(id)):
                #larger than display threshold
                if val<0.0:
                    val = -val;
                if val >=1.0e-6: 
                    break
            i=i+1

    #not empty
        if i!=attr.GetCount():
            self.kkt[numCol-1].upOrDownside = KKTCons.KKT_UPSIDE # change previous column to upside
            self.kkt.append(KKTCons(attr, cid, title, side, pen))
    
    def Print(self, os=sys.stdout):
        if len(self.kkt)<=0:
            return
        
        os.write('Constraint KKT attribution terms\n')
    
    # output header of KKT
        os.write('Asset ID')         
        for cons in self.kkt:
            if cons.upOrDownside != KKTCons.KKT_DOWNSIDE:
                 os.write(', '+cons.displayName)
            if cons.upOrDownside == KKTCons.KKT_UPSIDE:
                os.write('(up/down)')
        os.write('\n')

    # output the weights
        for id in sorted(self.kkt[0].Keyset()):
            os.write(id) 
            for cons in self.kkt:
                if cons.Contains(id): #there is a value
                    if cons.upOrDownside == KKTCons.KKT_DOWNSIDE: # merged column
                        os.write('/%.6f' % cons.Get(id))
                    else:
                        os.write(', %.6f' % cons.Get(id))
                elif cons.upOrDownside != KKTCons.KKT_DOWNSIDE: # there is no value and not a merged column: empty column
                    os.write(', ')
            os.write('\n')

class TutorialBase(object):
    def __init__(self, data):
        self.m_InitPf = None
        self.m_InitPfs = None
        self.m_BMPortfolio = None
        self.m_BM2Portfolio = None
        self.m_TradeUniverse = None
        self.m_PfValue = None

        self.m_WS = None
        self.m_Case = None
        self.m_Solver = None

        self.m_Data = data
        self.m_CompatibleMode = False

        # internal
        self.m_DumpFilename = ''
        self.m_DumpAll = False
        
    # Initialize the optimization
    def Initialize(self, tutorialID, description, dumpWS, setAlpha, isTaxAware):
        print('======== Running Tutorial ' + tutorialID + ' ========')
        print(description)

        # Create a workspace and setup risk model data
        self.SetupRiskModel()

        # Create initial portfolio etc
        self.SetupPortfolios()

        if setAlpha:
            self.SetAlpha()

        if isTaxAware:
            self.SetPrice()
            self.SetupTaxLots()

        # set up workspace dumping file
        self.SetupDumpFileBase(tutorialID, dumpWS)

    # set up workspace dumping file
    def SetupDumpFileBase(self, tutorialID, dumpWS):
        if (self.m_DumpAll or dumpWS):
            self.m_DumpFilename = 'opsdata_'
            self.m_DumpFilename += tutorialID
            self.m_DumpFilename += '.wsp'
        else:
            self.m_DumpFilename = ''
            
    # set flag of dump all tutorial
    def DumpAll(self, dumpWS):
        self.m_DumpAll = dumpWS

    # set approach compatible to that prior to version 8.0
    # @param mode  If True, run optimization in the approach prior to version 8.0. 
    #
    def SetCompatibleMode(self, mode):
        self.m_CompatibleMode = mode
    
    # Setup initial portfolio, benchmarks and trade universe
    def SetupPortfolios(self):
        # Create an initial portfolio with no Cash
        self.m_InitPfs = [None for _ in range(self.m_Data.m_AccountNum)]
        for iAccount in range(self.m_Data.m_AccountNum):
            accId = 'Initial Portfolio' + ('' if iAccount == 0 else str(iAccount + 1))
            self.m_InitPfs[iAccount] = self.m_WS.CreatePortfolio(accId)
            for iAsset in range(self.m_Data.m_AssetNum):
                if self.m_Data.m_InitWeight[iAccount][iAsset] != 0.0:
                    self.m_InitPfs[iAccount].AddAsset(self.m_Data.m_ID[iAsset], self.m_Data.m_InitWeight[iAccount][iAsset])
        self.m_InitPf = self.m_InitPfs[0]

        self.m_BMPortfolio = self.m_WS.CreatePortfolio('Benchmark')
        self.m_BM2Portfolio = self.m_WS.CreatePortfolio('Model')
        self.m_TradeUniverse = self.m_WS.CreatePortfolio('Trade Universe')

        for i in range(self.m_Data.m_AssetNum):
            if self.m_Data.m_ID[i]!='CASH':
                self.m_TradeUniverse.AddAsset(self.m_Data.m_ID[i], 0.0)
                if self.m_Data.m_BMWeight[i] != 0.0:
                    self.m_BMPortfolio.AddAsset(self.m_Data.m_ID[i], self.m_Data.m_BMWeight[i])
                if self.m_Data.m_BM2Weight[i] != 0:
                    self.m_BM2Portfolio.AddAsset(self.m_Data.m_ID[i], self.m_Data.m_BM2Weight[i])

    # Create a workspace and setup risk model data
    def SetupRiskModel(self, setExposures=True):
        # Initialize the Barra Optimizer CWorkSpace interface
        if self.m_WS:
                self.m_WS.Release();
        self.m_WS = barraopt.CWorkSpace.CreateInstance()

        # Create Primary Risk Model
        pRM = self.m_WS.CreateRiskModel('GEM', barraopt.eEQUITY)

        # Load the covariance matrix from the CData object
        count = 0
        for i in range(self.m_Data.m_FactorNum): 
            for j in range(i+1):
                pRM.SetFactorCovariance(self.m_Data.m_Factor[i], self.m_Data.m_Factor[j], self.m_Data.m_CovData[count])
                count=count+1

        # Add assets to the workspace
        for i in  range(self.m_Data.m_AssetNum):
            asset = None
            if self.m_Data.m_ID[i]=='CASH': 
                asset = self.m_WS.CreateAsset(self.m_Data.m_ID[i], barraopt.eCASH)
            else:
                asset = self.m_WS.CreateAsset(self.m_Data.m_ID[i], barraopt.eREGULAR)
        # Set expected return here
        asset.SetAlpha(0)

        if setExposures:
            # Load the exposure matrix from the CData object
            for i in range(self.m_Data.m_AssetNum):
                exposureSet = self.m_WS.CreateAttributeSet()
                for j in range(self.m_Data.m_FactorNum):
                    exposureSet.Set(self.m_Data.m_Factor[j], self.m_Data.m_ExpData[i][j])
                    pRM.SetFactorExposureBySet(self.m_Data.m_ID[i], exposureSet)

        # Load specific risk covariance
        for i in range(self.m_Data.m_AssetNum):
            pRM.SetSpecificCovariance(self.m_Data.m_ID[i], self.m_Data.m_ID[i], self.m_Data.m_SpCov[i])

    # Setup a simple sample secondary risk model
    def SetupRiskModel2(self):
        # Create a risk model
        rm = self.m_WS.CreateRiskModel('MODEL2', barraopt.eEQUITY)

        # Set factor covariances 
        rm.SetFactorCovariance('Factor2_1', 'Factor2_1', 1.0)
        rm.SetFactorCovariance('Factor2_1', 'Factor2_2', 0.1)
        rm.SetFactorCovariance('Factor2_2', 'Factor2_2', 0.5)

        # Set factor exposures 
        for i in range(self.m_Data.m_AssetNum):
            rm.SetFactorExposure(self.m_Data.m_ID[i], 'Factor2_1', (i+0.0) / self.m_Data.m_AssetNum)
            rm.SetFactorExposure(self.m_Data.m_ID[i], 'Factor2_2', (2.0 * i) / self.m_Data.m_AssetNum)

        # Set specific risk covariance
        for i in range(self.m_Data.m_AssetNum):
            rm.SetSpecificCovariance(self.m_Data.m_ID[i], self.m_Data.m_ID[i], 0.05)

    # Setup tax lots and recalculate asset weights
    def SetupTaxLots(self):
        # Add tax lots into the portfolio, compute asset values
        assetValue = [[0.0] * self.m_Data.m_AssetNum for i in range(self.m_Data.m_AssetNum) ]
        for i in range(self.m_Data.m_Taxlots):
            iAccount = self.m_Data.m_Account[i]
            iAsset = self.m_Data.m_Indices[i]
            initPf = self.m_InitPfs[iAccount]
            initPf.AddTaxLot(self.m_Data.m_ID[iAsset], self.m_Data.m_Age[i],
                             self.m_Data.m_CostBasis[i], self.m_Data.m_Shares[i], False)
            assetValue[iAccount][iAsset] += self.m_Data.m_Price[iAsset] * self.m_Data.m_Shares[i]

        # Set portfolio values
        self.m_PfValue = [ sum(assetValue[i]) for i in range(self.m_Data.m_AccountNum) ]

        # Reset asset weights based on tax lot information
        for i in range(self.m_Data.m_AccountNum):
            initPf = self.m_InitPfs[i]
            for j in range(self.m_Data.m_AssetNum):
                initPf.AddAsset(self.m_Data.m_ID[j], assetValue[i][j] / self.m_PfValue[i])

    # Set the expected return for each asset in the model
    def SetAlpha(self):
        # Set the expected return for each asset
        for i in range(self.m_Data.m_AssetNum):
            asset = self.m_WS.GetAsset(self.m_Data.m_ID[i])
            if asset:
                asset.SetAlpha(self.m_Data.m_Alpha[i])

    # Set the price for each asset in the model
    def SetPrice(self):
        for i in range(self.m_Data.m_AssetNum):
            asset = self.m_WS.GetAsset(self.m_Data.m_ID[i])
            if asset:
                asset.SetPrice(self.m_Data.m_Price[i])

    # Calculate portfolio weights and values from tax lot data.
    def UpdatePortfolioWeights(self):
        for iAccount in range(self.m_Data.m_AccountNum):
            pInitPf = self.m_InitPfs[iAccount]
            if pInitPf:
                self.m_PfValue[iAccount] = 0.0
                assetValue = [0.0] * self.m_Data.m_AssetNum
                oTaxLotIDs = pInitPf.GetTaxLotIDs()
                for iAsset in range(self.m_Data.m_AssetNum):
                    assetID = self.m_Data.m_ID[iAsset]
                    price = self.m_Data.m_Price[iAsset]
                    assetValue[iAsset] = 0.0
                    for lotID in oTaxLotIDs:
                        pLot = pInitPf.GetTaxLot(lotID)
                        if (pLot.GetAssetID() == assetID):
                            value = pLot.GetShares() * price
                            self.m_PfValue[iAccount] += value
                            assetValue[iAsset] += value
                for iAsset in range(self.m_Data.m_AssetNum):
                    pInitPf.AddAsset(self.m_Data.m_ID[iAsset], assetValue[iAsset] / self.m_PfValue[iAccount])

    # Run optimization
    # parameter useOldSolver: If True, use the eixisting m_Solver pointer without recreate a new solver.
    # parameter estUtilUB: If True, estimate upperbound on utility
    #
    def RunOptimize(self, useOldSolver=False, estUtilUB=False):
        # access to optimizer namespace
        # import com.barra.optimizer.*;
        if not useOldSolver: 
            self.m_Solver = self.m_WS.CreateSolver(self.m_Case)
            
        # set compatible mode
        if self.m_CompatibleMode:  
            self.m_Solver.SetOption( 'COMPATIBLE_MODE', 1.0)

        # estimate upperbound on utility
        if estUtilUB:  
            self.m_Solver.SetOption( 'REPORT_UPPERBOUND_ON_UTILITY', 1.0)
            
        # opsdata info could be very helpful in debugging 
        if self.m_DumpFilename != '': 
            self.m_WS.Serialize(self.m_DumpFilename)
        
        oStatus = self.m_Solver.Optimize()
        print(oStatus.GetMessage())
        print(self.m_Solver.GetLogMessage())

        if oStatus.GetStatusCode() == barraopt.eOK:    
            output = self.m_Solver.GetPortfolioOutput()
            maOutput = self.m_Solver.GetMultiAccountOutput()
            mpOutput = self.m_Solver.GetMultiPeriodOutput()
            if output:
                self.PrintPortfolioOutput(output, estUtilUB)
            elif maOutput:
                self.PrintMultiAccountOutput(maOutput)
            elif mpOuput:
                self.PrintMultiPeriodOutput(mpOutput)
        elif oStatus.GetStatusCode() == barraopt.eLICENSE_ERROR:
            raise 'Optimizer license error'

    #
    # Print single portfolio optimization output
    #
    def PrintPortfolioOutput(self, output, estUtilUB):
        print('Optimized Portfolio:')
        print('Risk(%%)     = %.4f' % output.GetRisk())
        print('Return(%%)   = %.4f' % output.GetReturn())
        print('Utility     = %.4f' % output.GetUtility())
        if estUtilUB:
            utilUB = output.GetUpperBoundOnUtility()
            if utilUB != barraopt.OPT_NAN:
                print('Util. Upperbound = %.4f' % utilUB)
        print('Turnover(%%) = %.4f' % output.GetTurnover())
        print('Penalty     = %.4f' % output.GetPenalty())
        print('TranxCost(%%)= %.4f' % output.GetTransactioncost())
        print('Beta        = %.4f' % output.GetBeta())
        if output.GetExpectedShortfall() != barraopt.OPT_NAN:
            print('ExpShortfall(%%)= %.4f' % output.GetExpectedShortfall())
        print('')
        # Output the non-zero weight in the optimized portfolio
        print('Asset Holdings:')
        portfolio = output.GetPortfolio()
        for assetID in portfolio.GetAssetIDSet():
            weight = portfolio.GetAssetWeight(assetID)
            if weight != 0.0:
                print('%s: %.4f' % (assetID, weight) )
        print('')

    #
    # Print multi-account optimization output
    #
    def PrintMultiAccountOutput(self, output):
        # Retrieve cross-account output
        crossAccountOutput = output.GetCrossAccountOutput()
        crossAccountTaxOutput = output.GetCrossAccountTaxOutput()
        print('Account     = Cross-account')
        print('Return(%%)   = %.4f' % crossAccountOutput.GetReturn())
        print('Utility     = %.4f' % crossAccountOutput.GetUtility())
        print('Turnover(%%) = %.4f' % crossAccountOutput.GetTurnover())
        jointMarketImpactBuyCost = output.GetJointMarketImpactBuyCost()
        if jointMarketImpactBuyCost != barraopt.OPT_NAN:
            print('Joint Market Impact Buy Cost($) = %.4f' % jointMarketImpactBuyCost)
        jointMarketImpactSellCost = output.GetJointMarketImpactSellCost()
        if jointMarketImpactSellCost != barraopt.OPT_NAN:
            print('Joint Market Impact Sell Cost($) = %.4f' % jointMarketImpactSellCost)
        if crossAccountTaxOutput:
            print('Total Tax   = %.4f' % crossAccountTaxOutput.GetTotalTax())
        print('')
        
        # Retrieve output for each account group
        if output.GetNumAccountGroups() > 0:
            for i in range(output.GetNumAccountGroups()):
                groupOutput = output.GetAccountGroupTaxOutput(i)
                print('Account Group = %d' % groupOutput.GetAccountGroupID())
                print('Total Tax     = %.4f' % groupOutput.GetTotalTax())
            print('')
    
        # Retrieve output for each account
        for i in range(output.GetNumAccounts()):
            accountOutput = output.GetAccountOutput(i)
            accountID = accountOutput.GetAccountID()
            print('Account     = %d' % accountID)
            print('Risk(%%)     = %.4f' % accountOutput.GetRisk())
            print('Return(%%)   = %.4f' % accountOutput.GetReturn())
            print('Utility     = %.4f' % accountOutput.GetUtility())
            print('Turnover(%%) = %.4f' % accountOutput.GetTurnover())
            print('Beta        = %.4f\n' % accountOutput.GetBeta())

            # Output the non-zero weight in the optimized portfolio
            print('Asset Holdings:')
            portfolio = accountOutput.GetPortfolio()
            for assetID in portfolio.GetAssetIDSet():
                weight = portfolio.GetAssetWeight(assetID)
                if weight != 0.0:
                    print('%s: %.4f' % (assetID, weight) )
            print('')

            taxOut = accountOutput.GetNewTaxOutput()
            if taxOut:
                if self.GetAccountGroupID(accountID) == -1:
                    ltax = taxOut.GetLongTermTax( '*', '*' )
                    stax = taxOut.GetShortTermTax('*', '*')
                    lgg_all = taxOut.GetCapitalGain( '*', '*', barraopt.eLONG_TERM, barraopt.eCAPITAL_GAIN )
                    lgl_all = taxOut.GetCapitalGain( '*', '*', barraopt.eLONG_TERM, barraopt.eCAPITAL_LOSS )
                    sgg_all = taxOut.GetCapitalGain( '*', '*', barraopt.eSHORT_TERM, barraopt.eCAPITAL_GAIN )
                    sgl_all = taxOut.GetCapitalGain( '*', '*', barraopt.eSHORT_TERM, barraopt.eCAPITAL_LOSS )
                   
                    print('Tax info for the tax rule group(all assets):')
                    print('Long Term Gain = %.4f' % lgg_all )
                    print('Long Term Loss = %.4f' % lgl_all )
                    print('Short Term Gain = %.4f' % sgg_all )
                    print('Short Term Loss = %.4f' % sgl_all )
                    print('Long Term Tax  = %.4f' % ltax )
                    print('Short Term Tax = %.4f' % stax )

                    print('')
                    print('Total Tax(for all tax rule groups) = %.4f' % taxOut.GetTotalTax())
                    print('')
                    
                print('TaxlotID          Shares:' )
                for assetID in portfolio.GetAssetIDSet():
                    sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID)
                    for lotID,shares in sharesInTaxlot.items():
                        if shares!=0:
                            print( '%s %.4f' %(lotID, shares) )

                print('')
                newShares = taxOut.GetNewShares()
                self.PrintAttributeSet(newShares, 'New Shares:')
                print('')


    #
    # Print multi-period optimization output
    #
    def PrintMultiPeriodOutput(self, output):
        # Retrieve cross-period output
        crossPeriodOutput = output.GetCrossPeriodOutput()
        print('Period      = Cross-period')
        print('Return(%%)   = %.4f' % crossPeriodOutput.GetReturn())
        print('Utility     = %.4f' % crossPeriodOutput.GetUtility())
        print('Turnover(%%) = %.4f\n' % crossPeriodOutput.GetTurnover())

        # Retrieve output for each period
        for i in range(output.GetNumPeriods()):
            periodOutput = output.GetPeriodOutput(i)
            print('Period      = %d' % periodOutput.GetPeriodID())
            print('Risk(%%)     = %.4f' % periodOutput.GetRisk())
            print('Return(%%)   = %.4f' % periodOutput.GetReturn())
            print('Utility     = %.4f' % periodOutput.GetUtility())
            print('Turnover(%%) = %.4f' % periodOutput.GetTurnover())
            print('Beta        = %.4f\n' % periodOutput.GetBeta())

    #
    # Run optimization and estimate the upperbound on utility
    # 
    def RunOptimizeReportUtilUB(self):
        self.RunOptimize(False, True)
        
    # Output trade list
    # parameter isOptimalPortfolio: If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
    #
    def OutputTradeList(self, isOptimalPortfolio):
        # access to optimizer namespace
        # import com.barra.optimizer.*;
        output = self.m_Solver.GetPortfolioOutput()
        if output:
            if isOptimalPortfolio:
                print('Optimal Portfolio:')
                portfolio = output.GetPortfolio()
            else:
                print('Roundlotted Portfolio:')
                oddLotIDSet = self.m_WS.CreateIDSet()
                portfolio = output.GetRoundlottedPortfolio(oddLotIDSet)

            print('Asset Holdings:')
            IDSet = portfolio.GetAssetIDSet()
            for assetID in IDSet:
                weight = portfolio.GetAssetWeight(assetID)
                if weight != 0:
                    print('%s: %.4f' % (assetID, weight))
            
            print("")
            print('Trade List:')
            print('Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type')

            for assetID in IDSet:
                if assetID!='CASH':
                    tradelistInfo = output.GetAssetTradeListInfo(assetID, isOptimalPortfolio)
                    tradeType = ''
                    if tradelistInfo.GetTradeType() == barraopt.eHOLD:
                        tradeType = 'Hold'
                    elif tradelistInfo.GetTradeType() == barraopt.eBUY:
                        tradeType = 'Buy'
                    elif tradelistInfo.GetTradeType() == barraopt.eCOVER_BUY:
                        tradeType = 'Cover Buy'
                    elif tradelistInfo.GetTradeType() == barraopt.eCROSSOVER_BUY:
                        tradeType = 'Crossover Buy'
                    elif tradelistInfo.GetTradeType() == barraopt.eCROSSOVER_SELL:
                        tradeType = 'Crossover Sell'
                    elif tradelistInfo.GetTradeType() == barraopt.eSELL:
                        tradeType = 'Sell'
                    elif tradelistInfo.GetTradeType() == barraopt.eSHORT_SELL:
                        tradeType = 'Short Sell'

                    print('%s: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %s' %
                        (assetID, tradelistInfo.GetInitialShares(), tradelistInfo.GetFinalShares(), tradelistInfo.GetTradedShares(),
                         tradelistInfo.GetPrice(), tradelistInfo.GetTradedValue(), tradelistInfo.GetTradedValuePcnt(),
                         tradelistInfo.GetTotalTransactionCost(), tradeType) )
            print('')

    ## Returns the ID of the group which the account belongs to.
    # @param accountID the ID of the account.
    # @return the ID of the group, or -1.
    #
    def GetAccountGroupID(self, accountID):
        if self.m_Solver:
            for i in range(self.m_Solver.GetNumAccounts()):
                account =  self.m_Solver.GetAccount(i)
                if account.GetID() == accountID:
                    return account.GetGroupID()
        return -1

    def CollectKKT(self, multiplier=1.0):
      output = self.m_Solver.GetPortfolioOutput()
      if output:
        kkt = KKTData()
        #alpha
        alphakkt = self.m_WS.CreateAttributeSet()
        portfolio = output.GetPortfolio()
        for assetID in portfolio.GetAssetIDSet():
            weight = portfolio.GetAssetWeight(assetID)
            if weight != 0.0: 
                alphakkt.Set(assetID, self.m_WS.GetAsset(assetID).GetAlpha()*multiplier); # *alphaterm
        kkt.AddConstraint(alphakkt, 'alpha', 'Alpha')

        # other kkt
        kkt.AddConstraint(output.GetPrimaryRiskModelKKTTerm(), 'primaryRMKKT', 'Primary RM')
        kkt.AddConstraint(output.GetSecondaryRiskModelKKTTerm(), 'secondaryRMKKT', 'Secondary RM')
        kkt.AddConstraint(output.GetResidualAlphaKKTTerm(), 'residualAlphaKKTTerm', 'Residual Alpha')
        kkt.AddConstraint(output.GetTransactioncostKKTTerm(True), 'transactionCostKKTTerm', 'transaction cost')

        # balance kkt
        balanceSlackInfo = output.GetSlackInfo4BalanceCon()
        if balanceSlackInfo:
            kkt.AddConstraint(balanceSlackInfo.GetKKTTerm(True), 'balanceKKTTerm', 'Balance KKT')

        # get the KKT and penalty KKT terms for the asset bound constraints
        for slackID in output.GetSlackInfoIDs():
            slackInfo = output.GetSlackInfo(slackID)
            if slackInfo:
                kkt.AddConstraint(slackInfo.GetKKTTerm(True), slackID,  slackID) #upside
                kkt.AddOnlyIfDifferent(slackInfo.GetKKTTerm(False), slackID,  slackID) #downside
                kkt.AddConstraintPenalty(slackInfo.GetPenaltyKKTTerm(True), slackID, slackID+' Penalty') # upside
                kkt.AddOnlyIfDifferentPenalty(slackInfo.GetPenaltyKKTTerm(False), slackID, slackID+' Penalty') # downside
        kkt.Print()
 
    # output AttributeSet
    @staticmethod
    def PrintAttributeSet(attributeSet, title):
        if attributeSet:
            print(title)
            for id,value in attributeSet.items():
                print('%s: %.4f' % (id, value) )
