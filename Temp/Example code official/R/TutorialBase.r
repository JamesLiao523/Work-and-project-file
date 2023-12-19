# @file TutorialBase.r
# \brief Contains definition of the TutorialBase class with
# the shared routines for all tutorials.
#

## Contains the shared data structures & routines for collecting KKT terms.
#Define enum of EKKTSide
makeEnum <- function(inputList) {
	myEnum <- as.list(inputList)
	enumNames <- names(myEnum)
	if (is.null(enumNames)) {
		names(myEnum) <- myEnum
	} else if ("" %in% enumNames) {
		stop("The inputList has some but not all names assigned. They must be all assigned or none assigned")
	}
	return(myEnum)
} 	
EKKTSide = makeEnum(c(KKT_SIDE_DEFAULT = 0, KKT_UPSIDE = 1, KKT_DOWNSIDE = -1))    

## Contains shared data structure for a KKT column.
KKTCons<- R6Class("KKTCons",
public = list(
    initialize = function(term, id, ttl, side, pen){
        self$constraintID = id
        self$displayName = ttl
        self$isPenalty = pen
        self$upOrDownside = side
        self$map = new.env(hash=TRUE)
        
        idset = CAttributeSet_GetKeySet(term)
        asset = CIDSet_GetFirst(idset)
        while (asset != ''){
            self$map[[asset]] = CAttributeSet_GetValue(term,asset)
            asset = CIDSet_GetNext(idset)
		}			
    },
    Contains = function(id){
        return(exists(id, envir=self$map))
	},
    Get = function(id){
        return(self$map[[id]])
	},
    Keyset = function(){
        return(ls(self$map))
	},
	constraintID = NULL, 
    displayName = NULL,
    isPenalty = NULL,
    upOrDownside = NULL,
    map = NULL
)
)

## Contains shared class/routines for a KKT table.
KKTData<- R6Class("KKTData",
public = list(
	initialize = function(){
		self$kkt = NULL
	},
    AddConstraintPenalty = function(atr, cid, ttl, side=EKKTSide$KKT_SIDE_DEFAULT){
        self$AddConstraint(atr, cid, ttl, side, TRUE)
	},
    AddOnlyIfDifferentPenalty = function(atr, cid, ttl, side=EKKTSide$KKT_DOWNSIDE){
        self$AddOnlyIfDifferent(atr, cid, ttl, side, TRUE)
	},
    AddConstraint = function(atr, cid, ttl, side=EKKTSide$KKT_SIDE_DEFAULT, pen=FALSE){
        idset = CAttributeSet_GetKeySet(atr)
        # check if it's an empty or all-zero column
        id = idset$GetFirst()
        i = 0
        while (id != ''){
            # check if id is in the optimal portfolio
            if( (length(self$kkt)==0) || (self$kkt[[1]]$Contains(id)) ){
                # larger than display threshold
                val = CAttributeSet_GetValue(atr, id)
                if (val<0.0) 
                    val = -val
                if (val >= 1.0e-6) 
                    break
			}
            id = idset$GetNext()
            i=i+1
		}		
		# not empty
        if (i!=idset$GetCount())
            self$kkt = c(self$kkt, KKTCons$new(atr, cid, ttl, side, pen))
	},
    AddOnlyIfDifferent = function(atr, cid, ttl, side=EKKTSide$KKT_DOWNSIDE, pen=FALSE){
        idset = CAttributeSet_GetKeySet(atr)
        numCol = length(self$kkt)
		# check if it's an empty or all-zero column
        i=0
        id = idset$GetFirst()
        while (id!=''){
            val = CAttributeSet_GetValue(atr, id)
			# excludes ids not in the optimal portfolio and same value as the column before
            if (numCol==0 || (self$kkt[[1]]$Contains(id) && val!=self$kkt[[numCol]]$Get(id))){
                #larger than display threshold
                if (val<0.0)
                    val = -val
                if (val >=1.0e-6) 
                    break
			}
            id = idset$GetNext()
            i=i+1
		}
		#not empty
        if (i!=idset$GetCount()){
            self$kkt[[numCol]]$upOrDownside = EKKTSide$KKT_UPSIDE # change previous column to upside
            self$kkt = c(self$kkt, KKTCons$new(atr, cid, ttl, side, pen))
		}
	},
    Print = function(){
        if (length(self$kkt)<=0){
#			print('no kkt terms')
            return
        }
        cat('Constraint KKT attribution terms\n')
    
		# output header of KKT
        line = 'Asset ID'   	
        for (cons in self$kkt) {
            if (cons$upOrDownside != EKKTSide$KKT_DOWNSIDE){
				if(!is.null(cons$displayName))
					line = paste0(line, sprintf(', %s', cons$displayName))
				else
					line = paste0(line, ', ')
			}
            if (cons$upOrDownside == EKKTSide$KKT_UPSIDE)
                line = paste0(line, '(up/down)')
		}
		cat(sprintf('%s\n', line))

		# output the weights
		for (id in sort(self$kkt[[1]]$Keyset())){ 
			cat(id)
			for (cons in self$kkt){
				if (cons$Contains(id)){ #there is a value
					if (cons$upOrDownside == EKKTSide$KKT_DOWNSIDE) # merged column
						cat(sprintf('/%.6f', cons$Get(id)))
					else
						cat(sprintf(', %.6f', cons$Get(id)))
				}else if (cons$upOrDownside != EKKTSide$KKT_DOWNSIDE) # there is no value and not a merged column: empty column
					cat(', ')
			}
			cat('\n')
		}
	},
	kkt = NULL	
)
)

#\brief Contains the shared routines for setting up risk model, portfolio and alpha, etc.
#

#library(R6)

#dyn.load(Sys.getenv("BARRAOPT_WRAP"))
#source(Sys.getenv("BARRAOPT_WRAP_R"))

TutorialBase<- R6Class("TutorialBase",
public = list(
    initialize = function(tdata){
        self$m_InitPf = NULL
        self$m_InitPfs = list()
        self$m_BMPortfolio = NULL
        self$m_BM2Portfolio = NULL
        self$m_TradeUniverse = NULL
        self$m_PfValue = numeric(tdata$m_AccountNum)

        self$m_WS = NULL
        self$m_Case = NULL
        self$m_Solver = NULL

        self$m_Data = tdata
        self$m_CompatibleMode = FALSE

        # internal
        self$m_DumpFilename = ''
        self$m_DumpAll = FALSE
	}, 
	
    # Initialize the optimization
    Initialize = function(tutorialID, description, dumpWS, setAlpha, isTaxAware){
		cat(paste0('======== Running Tutorial ', tutorialID, ' ========\n'))
        cat(paste0(description, '\n'))

        # Create a workspace and setup risk model data
        self$SetupRiskModel()

        # Create initial portfolio etc
        self$SetupPortfolios()

        if (setAlpha){
            self$SetAlpha()
        }

        if (isTaxAware) {
            self$SetPrice()
            self$SetupTaxLots()
        }

        # set up workspace dumping file
        self$SetupDumpFileBase(tutorialID, dumpWS)
	},

    # set up workspace dumping file
    SetupDumpFileBase = function(tutorialID, dumpWS){
        if (self$m_DumpAll || dumpWS){
            self$m_DumpFilename = paste0('opsdata_', tutorialID, '.wsp')
        }else{
            self$m_DumpFilename = ''
		}
	},
    # set flag of dump all tutorial
    DumpAll = function(dumpWS){
        self$m_DumpAll = dumpWS
	},
    # set approach compatible to that prior to version 8.0
    # @param mode  If TRUE, run optimization in the approach prior to version 8.0. 
    #
    SetCompatibleMode = function(mode){
        self$m_CompatibleMode = mode
    },
    # Setup initial portfolio, benchmarks and trade universe
    SetupPortfolios = function(){
        # Create an initial portfolio with no Cash
        for (iAccount in 1:self$m_Data$m_AccountNum) {
            pfID = (if (iAccount==1) 'Initial Portfolio' else  paste('Initial Portfolio', as.character(iAccount), sep=''))
            self$m_InitPfs[[iAccount]] = self$m_WS$CreatePortfolio(pfID)
            for (i in 1:self$m_Data$m_AssetNum){
                if (self$m_Data$m_InitWeight[iAccount, i] != 0.0){ 
                   self$m_InitPfs[[iAccount]]$AddAsset(self$m_Data$m_ID[i], self$m_Data$m_InitWeight[iAccount, i])
			    }
		    }
        }
        self$m_InitPf = self$m_InitPfs[[1]]
        
        self$m_BMPortfolio = CWorkSpace_CreatePortfolio(self$m_WS,'Benchmark')
        self$m_BM2Portfolio = CWorkSpace_CreatePortfolio(self$m_WS,'Model')
        self$m_TradeUniverse = CWorkSpace_CreatePortfolio(self$m_WS,'Trade Universe')

        for (i in 1:self$m_Data$m_AssetNum){
            if (self$m_Data$m_ID[i]!='CASH'){
                CPortfolio_AddAsset(self$m_TradeUniverse,self$m_Data$m_ID[i], 0.0)
                if (self$m_Data$m_BMWeight[i] != 0.0){
                    CPortfolio_AddAsset(self$m_BMPortfolio,self$m_Data$m_ID[i], self$m_Data$m_BMWeight[i])
				}
                if (self$m_Data$m_BM2Weight[i] != 0){
                    CPortfolio_AddAsset(self$m_BM2Portfolio,self$m_Data$m_ID[i], self$m_Data$m_BM2Weight[i])
				}
			}
		}
	},
    # Setup tax lots and recalculate asset weights
    SetupTaxLots = function(){
        # Add tax lots into the portfolio, compute asset values
        assetValue = array(0, dim=c(self$m_Data$m_AccountNum, self$m_Data$m_AssetNum))
        for (j in 1:self$m_Data$m_Taxlots){
            iAccount = self$m_Data$m_Account[j]
            iAsset = self$m_Data$m_Indices[j]
            initPf = self$m_InitPfs[[iAccount]]
            initPf$AddTaxLot(self$m_Data$m_ID[iAsset], self$m_Data$m_Age[j], self$m_Data$m_CostBasis[j], self$m_Data$m_Shares[j], FALSE)
            assetValue[iAccount,iAsset] = assetValue[iAccount,iAsset] + self$m_Data$m_Price[iAsset]*self$m_Data$m_Shares[j]
        }
        # Set portfolio values
        for (i in 1:self$m_Data$m_AccountNum){
            self$m_PfValue[i] = sum(assetValue[i,])
        }
        # Reset asset initial weights based on tax lot information
        for (i in 1:self$m_Data$m_AccountNum){
            initPf = self$m_InitPfs[[i]]
            for (j in 1:self$m_Data$m_AssetNum){
                initPf$AddAsset(self$m_Data$m_ID[j], assetValue[i,j] / self$m_PfValue[i])
            }
        }
    },

    # Calculate portfolio weights and values from tax lot data.
    UpdatePortfolioWeights = function(){
        for (iAccount in 1:self$m_Data$m_AccountNum) {
            pInitPf = self$m_InitPfs[[iAccount]]
            if (!is.null(pInitPf)) {
                self$m_PfValue[iAccount] = 0.0
                assetValue = vector('double', self$m_Data$m_AssetNum)
                oTaxLotIDs = pInitPf$GetTaxLotIDs()
                for (iAsset in 1:self$m_Data$m_AssetNum) {
                    assetID = self$m_Data$m_ID[iAsset]
                    price = self$m_Data$m_Price[iAsset]
                    lotID = oTaxLotIDs$GetFirst()
                    while (lotID != '') {
                        pLot = pInitPf$GetTaxLot(lotID)
                        if (pLot$GetAssetID() == assetID) {
                            value = pLot$GetShares() * price
                            self$m_PfValue[iAccount] = self$m_PfValue[iAccount] + value
                            assetValue[iAsset] = assetValue[iAsset] + value
                        }
                        lotID = oTaxLotIDs$GetNext()
                    }
                }
                for (iAsset in 1:self$m_Data$m_AssetNum) {
                    pInitPf$AddAsset(self$m_Data$m_ID[iAsset], assetValue[iAsset] / self$m_PfValue[iAccount])
                }
            }
        }
    },

    # Create a workspace and setup risk model data
    SetupRiskModel = function(setExposures=TRUE){
        # Initialize the Barra Optimizer CWorkSpace interface
        if (!is.null(self$m_WS)){
			CWorkSpace_Release(self$m_WS)
		}
        self$m_WS = CWorkSpace_CreateInstance()

        # Create Primary Risk Model
        pRM = CWorkSpace_CreateRiskModel(self$m_WS,'GEM', 'eEQUITY')

        # Load the covariance matrix from the CData object
        count = 1
        for (i in 1:self$m_Data$m_FactorNum){ 
            for (j in 1:i){
                CRiskModel_SetFactorCovariance(pRM,self$m_Data$m_Factor[i], self$m_Data$m_Factor[j], self$m_Data$m_CovData[count])
                count=count+1
			}
		}
        # Add assets to the workspace
        for (i in 1:self$m_Data$m_AssetNum){
            asset = NULL
            if (self$m_Data$m_ID[i]=='CASH'){ 
                asset = CWorkSpace_CreateAsset(self$m_WS, self$m_Data$m_ID[i], 'eCASH')
            }else{
                asset = CWorkSpace_CreateAsset(self$m_WS, self$m_Data$m_ID[i], 'eREGULAR')
			}
			# Set expected return here
			CAsset_SetAlpha(asset, 0)
		}

        if (setExposures){
            # Load the exposure matrix from the CData object
            for (i in 1:self$m_Data$m_AssetNum){
                exposureSet = CWorkSpace_CreateAttributeSet(self$m_WS)
                for (j in 1:self$m_Data$m_FactorNum){
                    CAttributeSet_Set(exposureSet,self$m_Data$m_Factor[j], self$m_Data$m_ExpData[i,j])
				}
				CRiskModel_SetFactorExposureBySet(pRM, self$m_Data$m_ID[i], exposureSet)
			}
		}
        # Load specific risk covariance
        for (i in 1:self$m_Data$m_AssetNum){
            CRiskModel_SetSpecificCovariance(pRM,self$m_Data$m_ID[i], self$m_Data$m_ID[i], self$m_Data$m_SpCov[i])
		}
	},
    # Setup a simple sample secondary risk model
    SetupRiskModel2 = function(){
        # Create a risk model
        riskModel = CWorkSpace_CreateRiskModel(self$m_WS,'MODEL2', 'eEQUITY')

        # Set factor covariances 
        CRiskModel_SetFactorCovariance(riskModel,'Factor2_1', 'Factor2_1', 1.0)
        CRiskModel_SetFactorCovariance(riskModel,'Factor2_1', 'Factor2_2', 0.1)
        CRiskModel_SetFactorCovariance(riskModel,'Factor2_2', 'Factor2_2', 0.5)

        # Set factor exposures 
        for (i in 1:self$m_Data$m_AssetNum){
            CRiskModel_SetFactorExposure(riskModel,self$m_Data$m_ID[i], 'Factor2_1', (i-1.0) / self$m_Data$m_AssetNum)
            CRiskModel_SetFactorExposure(riskModel,self$m_Data$m_ID[i], 'Factor2_2', (2.0 * (i-1)) / self$m_Data$m_AssetNum)
		}
        # Set specific risk covariance
        for (i in 1:self$m_Data$m_AssetNum){
            CRiskModel_SetSpecificCovariance(riskModel,self$m_Data$m_ID[i], self$m_Data$m_ID[i], 0.05)
		}
	},
    # Set the expected return for each asset in the model
    SetAlpha = function(){
        # Set the expected return for each asset
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset)){
                CAsset_SetAlpha(asset,self$m_Data$m_Alpha[i])
			}
		}
	},
    # Set the price for each asset in the model
    SetPrice = function() {
        for (i in 1:self$m_Data$m_AssetNum){
            asset = CWorkSpace_GetAsset(self$m_WS,self$m_Data$m_ID[i])
            if (!is.null(asset)){
                CAsset_SetPrice(asset, self$m_Data$m_Price[i])
            }
        }
    },

    # Run optimization
    # parameter useOldSolver: If TRUE, use the eixisting m_Solver pointer without recreate a new solver.
    # parameter estUtilUB: If TRUE, estimate upperbound on utility
    #
    RunOptimize = function(useOldSolver=FALSE, estUtilUB=FALSE){
        if (!useOldSolver){ 
            self$m_Solver = CWorkSpace_CreateSolver(self$m_WS,self$m_Case)
		}
        # set compatible mode
        if (self$m_CompatibleMode){  
			 CSolver_SetOption(self$m_Solver,'COMPATIBLE_MODE', 1.0)
		}
        # estimate upperbound on utility
        if (estUtilUB){  
             CSolver_SetOption(self$m_Solver,'REPORT_UPPERBOUND_ON_UTILITY', 1.0)
		}
        # opsdata info could be very helpful in debugging 
        if (self$m_DumpFilename != ''){ 
            CWorkSpace_Serialize(self$m_WS,self$m_DumpFilename)
        }
		
        oStatus = CSolver_Optimize(self$m_Solver)
        cat(paste0(CStatus_GetMessage(oStatus), '\n'))
		cat(paste0(CSolver_GetLogMessage(self$m_Solver), '\n'))

        if (CStatus_GetStatusCode(oStatus) == 'eOK'){    
            output = CSolver_GetPortfolioOutput(self$m_Solver)
            maOutput = CSolver_GetMultiAccountOutput(self$m_Solver)
            mpOutput = CSolver_GetMultiPeriodOutput(self$m_Solver)
            if (!is.null(output)){
                self$PrintPortfolioOutput(output, estUtilUB)
            } else if (!is.null(maOutput)){
                self$PrintMultiAccountOutput(maOutput)
            } else if (!is.null(mpOutput)){
                self$PrintMultiPeriodOutput(mpOutput)
            }
        }else if (CStatus_GetStatusCode(oStatus) == 'eLICENSE_ERROR'){
            stop('Optimizer license error')
        }
	},
    #
    # Run optimization and estimate the upperbound on utility
    # 
    RunOptimizeReportUtilUB = function(){
        self$RunOptimize(FALSE, TRUE)
	},

    PrintPortfolioOutput = function(output,estUtilUB){
        cat('Optimized Portfolio:\n')
        cat(sprintf('Risk(%%)     = %.4f\n', CDataPoint_GetRisk(output)))
        cat(sprintf('Return(%%)   = %.4f\n',  CDataPoint_GetReturn(output)))
        cat(sprintf('Utility     = %.4f\n', CDataPoint_GetUtility(output)))
        if (estUtilUB){
            utilUB = CPortfolioOutput_GetUpperBoundOnUtility(output)
            if (utilUB != OPT_NAN()){
                cat(sprintf('Util. Upperbound = %.4f\n', utilUB))
            }
        }
        cat(sprintf('Turnover(%%) = %.4f\n', CDataPoint_GetTurnover(output)))
        cat(sprintf('Penalty     = %.4f\n', CDataPoint_GetPenalty(output)))
        cat(sprintf('TranxCost(%%)= %.4f\n', CDataPoint_GetTransactioncost(output)))
        cat(sprintf('Beta        = %.4f\n', CDataPoint_GetBeta(output)))
        if (CDataPoint_GetExpectedShortfall(output) != OPT_NAN()) {
           cat(sprintf('ExpShortfall(%%)= %.4f\n', CDataPoint_GetExpectedShortfall(output)))
        }
        cat('\n')
        # Output the non-zero weight in the optimized portfolio
        cat('Asset Holdings:\n')
        portfolio = CDataPoint_GetPortfolio(output)
        idSet = CPortfolio_GetAssetIDSet(portfolio)
                
        assetID = CIDSet_GetFirst(idSet)
        while (assetID!=''){
            weight = CPortfolio_GetAssetWeight(portfolio,assetID)
            if (weight != 0.00){
                cat(sprintf('%s: %.4f\n', assetID, weight))
            }
            assetID = CIDSet_GetNext(idSet)
        }
        cat('\n')
    },

    PrintMultiAccountOutput = function(output){
        # Retrieve cross-account output
        crossAccountOutput = output$GetCrossAccountOutput()
        crossAccountTaxOutput = output$GetCrossAccountTaxOutput()
        cat('Account     = Cross-account\n')
        cat(sprintf('Return(%%)   = %.4f\n', crossAccountOutput$GetReturn()))
        cat(sprintf('Utility     = %.4f\n', crossAccountOutput$GetUtility()))
        cat(sprintf('Turnover(%%) = %.4f\n', crossAccountOutput$GetTurnover()))
        jointMarketBuyCost = output$GetJointMarketImpactBuyCost()
        if (jointMarketBuyCost != OPT_NAN()){
            cat(sprintf('Joint Market Impact Buy Cost($) = %.4f\n', jointMarketBuyCost))
        }
        jointMarketSellCost = output$GetJointMarketImpactSellCost()
        if (jointMarketSellCost != OPT_NAN()){
            cat(sprintf('Joint Market Impact Sell Cost($) = %.4f\n\n', jointMarketSellCost))
        }
        if (!is.null(crossAccountTaxOutput)) {
            cat(sprintf('Total Tax    = %.4f\n', crossAccountTaxOutput$GetTotalTax()))
        }
        cat('\n')

        # Retrieve output for each account group
        if (output$GetNumAccountGroups() > 0) {
            for (i in 1:output$GetNumAccountGroups()) {
                groupOutput = output$GetAccountGroupTaxOutput(i-1)
                cat(sprintf('Account Group = %d\n', groupOutput$GetAccountGroupID()))
                cat(sprintf('Total Tax     = %.4f\n', groupOutput$GetTotalTax()))
            }
            cat('\n');
        }

        # Retrieve output for each account
        for (i in 1:output$GetNumAccounts()){
            accountOutput = output$GetAccountOutput(i-1)
            accountID = accountOutput$GetAccountID()
            cat(sprintf('Account     = %d\n', accountID))
            cat(sprintf('Risk(%%)     = %.4f\n', accountOutput$GetRisk()))
            cat(sprintf('Return(%%)   = %.4f\n', accountOutput$GetReturn()))
            cat(sprintf('Utility     = %.4f\n', accountOutput$GetUtility()))
            cat(sprintf('Turnover(%%) = %.4f\n', accountOutput$GetTurnover()))
            cat(sprintf('Beta        = %.4f\n', accountOutput$GetBeta()))
            cat('\n')

            # Output the non-zero weight in the optimized portfolio
            cat('Asset Holdings:\n')
            portfolio = accountOutput$GetPortfolio()
            idSet = portfolio$GetAssetIDSet()
            assetID = idSet$GetFirst()
            while (assetID!=''){
                weight = portfolio$GetAssetWeight(assetID)
                if (weight != 0.00){
                    cat(sprintf('%s: %.4f\n', assetID, weight))
                }
                assetID = idSet$GetNext()
            }
            cat('\n')

            taxOut = accountOutput$GetNewTaxOutput();
            if (!is.null(taxOut)){
               if (self$GetAccountGroupID(accountID) == -1) {
                  ltax = taxOut$GetLongTermTax( '*', '*' )
                  stax = taxOut$GetShortTermTax('*', '*')
                  lgg_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_GAIN' )
                  lgl_all = taxOut$GetCapitalGain( '*', '*', 'eLONG_TERM', 'eCAPITAL_LOSS' )
                  sgg_all = taxOut$GetCapitalGain( '*', '*', 'eSHORT_TERM', 'eCAPITAL_GAIN' )
                  sgl_all = taxOut$GetCapitalGain( '*', '*', 'eSHORT_TERM', 'eCAPITAL_LOSS' )
               
                  cat('')
                  cat('Tax info for the tax rule group(all assets):\n')
                  cat(sprintf('Long Term Gain = %.4f\n', lgg_all ))
                  cat(sprintf('Long Term Loss = %.4f\n', lgl_all ))
                  cat(sprintf('Short Term Gain = %.4f\n', sgg_all ))
                  cat(sprintf('Short Term Loss = %.4f\n', sgl_all ))
                  cat(sprintf('Long Term Tax  = %.4f\n', ltax ))
                  cat(sprintf('Short Term Tax = %.4f\n', stax ))

                  cat(sprintf('\nTotal Tax(for all tax rule groups) = %.4f\n\n', taxOut$GetTotalTax()))
               }

               cat( 'TaxlotID          Shares:\n' )
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

    PrintMultiPeriodOutput = function(output){
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
    },
 
    # Output trade list
    # parameter isOptimalPortfolio: If TRUE, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
    #
    OutputTradeList = function(isOptimalPortfolio){
        output = CSolver_GetPortfolioOutput(self$m_Solver)
        if (!is.null(output)){
            if (isOptimalPortfolio){
                cat('Optimal Portfolio:\n')
                portfolio = CDataPoint_GetPortfolio(output)
            }else{
                cat('Roundlotted Portfolio:\n')
                oddLotIDSet = CWorkSpace_CreateIDSet(self$m_WS)
                portfolio = CPortfolioOutput_GetRoundlottedPortfolio(output, oddLotIDSet)
			}
            cat('Asset Holdings:\n')
            IDSet = CPortfolio_GetAssetIDSet(portfolio)

            assetID = CIDSet_GetFirst(IDSet)
            while (assetID!=''){
                weight = CPortfolio_GetAssetWeight(portfolio,assetID)
                if (weight != 0){
                    cat(sprintf('%s: %.4f\n', assetID, weight))
				}
                assetID = CIDSet_GetNext(IDSet)
            }
            cat("\n")
            cat('Trade List:\n')
            cat('Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%), Transaction Cost, Trade Type\n')

            assetID = CIDSet_GetFirst(IDSet)
            while (assetID!=''){
                if (assetID!='CASH'){
                    tradelistInfo = CPortfolioOutput_GetAssetTradeListInfo(output,assetID, isOptimalPortfolio)
                    tradeType = ''
                    if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eHOLD'){
                        tradeType = 'Hold'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eBUY'){
                        tradeType = 'Buy'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eCOVER_BUY'){
                        tradeType = 'Cover Buy'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eCROSSOVER_BUY'){
                        tradeType = 'Crossover Buy'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eCROSSOVER_SELL'){
                        tradeType = 'Crossover Sell'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eSELL'){
                        tradeType = 'Sell'
                    }else if (CAssetTradeListInfo_GetTradeType(tradelistInfo) == 'eSHORT_SELL'){
                        tradeType = 'Short Sell'
					}
                    cat(sprintf('%s: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %s\n',
                        assetID, CAssetTradeListInfo_GetInitialShares(tradelistInfo), CAssetTradeListInfo_GetFinalShares(tradelistInfo), 
						CAssetTradeListInfo_GetTradedShares(tradelistInfo),CAssetTradeListInfo_GetPrice(tradelistInfo), 
						CAssetTradeListInfo_GetTradedValue(tradelistInfo), CAssetTradeListInfo_GetTradedValuePcnt(tradelistInfo),
                        CAssetTradeListInfo_GetTotalTransactionCost(tradelistInfo), tradeType))
				}
                assetID = CIDSet_GetNext(IDSet)
			}
            cat('\n')
		}
	}, 

    # Returns the ID of the group which the account belongs to.
    GetAccountGroupID = function(accountID){
        groupID = -1
        if (!is.null(self$m_Solver)) {
            for (i in 1:self$m_Solver$GetNumAccounts()) {
                account = self$m_Solver$GetAccount(i-1)
                if (account$GetID()==accountID) {
                   groupID = account$GetGroupID()
                   break
                }
            }
        }
        groupID
    },

    # output AttributeSet
    PrintAttributeSet = function(attributeSet, title){
        idSet = CAttributeSet_GetKeySet(attributeSet)
        id = CIDSet_GetFirst(idSet)
        if(id !=''){
            cat(paste0(title,'\n'))
            while (id != ''){
                cat(sprintf('%s: %.4f\n', id, CAttributeSet_GetValue(attributeSet,id)))
                id = CIDSet_GetNext(idSet)
			}
		}
	},
	
	CollectKKT = function(multiplier=1.0){
		output = self$m_Solver$GetPortfolioOutput()
		if (!is.null(output)){ 
			kkt = KKTData$new()
			#alpha
			alphakkt = self$m_WS$CreateAttributeSet()
			portfolio = output$GetPortfolio()
			idSet = portfolio$GetAssetIDSet()
			assetID = idSet$GetFirst()
			while (assetID !=''){
				weight = CPortfolio_GetAssetWeight(portfolio, assetID)
				if (weight != 0.0) 
					CAttributeSet_Set(alphakkt, assetID, CAsset_GetAlpha(CWorkSpace_GetAsset(self$m_WS, assetID))*multiplier) # *alphaterm
				assetID = idSet$GetNext()
			}
			kkt$AddConstraint(alphakkt, 'alpha', 'Alpha')

			# other kkt 
			kkt$AddConstraint(output$GetPrimaryRiskModelKKTTerm(), 'primaryRMKKT', 'Primary RM')
			kkt$AddConstraint(output$GetSecondaryRiskModelKKTTerm(), 'secondaryRMKKT', 'Secondary RM')
			kkt$AddConstraint(output$GetResidualAlphaKKTTerm(), 'residualAlphaKKTTerm', 'Residual Alpha')
			kkt$AddConstraint(output$GetTransactioncostKKTTerm(TRUE), 'transactionCostKKTTerm', 'transaction cost')

			# balance kkt
			balanceSlackInfo = output$GetSlackInfo4BalanceCon()
			if (!is.null(balanceSlackInfo))
				kkt$AddConstraint(balanceSlackInfo$GetKKTTerm(TRUE), 'balanceKKTTerm', 'Balance KKT')

			# get the KKT and penalty KKT terms for the asset bound constraints
			slackInfoIDs = output$GetSlackInfoIDs()
			slackID = slackInfoIDs$GetFirst()
			while (slackID != ''){
				slackInfo = output$GetSlackInfo(slackID)
				if (!is.null(slackInfo)){
					kkt$AddConstraint(slackInfo$GetKKTTerm(TRUE), slackID,  slackID) #upside
					kkt$AddOnlyIfDifferent(slackInfo$GetKKTTerm(FALSE), slackID,  slackID) #downside
					kkt$AddConstraintPenalty(slackInfo$GetPenaltyKKTTerm(TRUE), slackID, paste0(slackID,' Penalty')) # upside
					kkt$AddOnlyIfDifferentPenalty(slackInfo$GetPenaltyKKTTerm(FALSE), slackID, paste0(slackID,' Penalty')) # downside
				}
				slackID = slackInfoIDs$GetNext()
			}
			kkt$Print()
		}		
	},
	
	m_InitPf = NULL,
	m_InitPfs = NULL,
	m_BMPortfolio = NULL,
	m_BM2Portfolio = NULL,
	m_TradeUniverse = NULL,
        m_PfValue = NULL,
	m_WS = NULL,
	m_Case = NULL,
	m_Solver = NULL,
	m_Data = NULL,
	m_CompatibleMode = FALSE,

    # internal
	m_DumpFilename = '',
	m_DumpAll = FALSE
)
)