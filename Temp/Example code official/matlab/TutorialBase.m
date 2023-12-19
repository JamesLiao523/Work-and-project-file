%% definition of the TutorialBase class 
% TutorialBase class contains shared routines for all tutorials.  
%% Pass object by reference
% matlab class passes object by value by default. In order to pass by
% reference as in JAVA class, derive your class from "handle" class
classdef TutorialBase < handle
    %% stores optimizer's objects
    % workspace, case, solver 
    % & simulation data
    properties (SetAccess='protected')
        m_WS
        m_Case
        m_Solver
        m_Data
    end
    %% of type CPortfolio
    properties (SetAccess='protected')
        m_InitPf
        m_InitPfs
        m_BMPortfolio
        m_BM2Portfolio
        m_TradeUniverse
    end
    %% portfolio values (for tax-aware optimizations)
    properties (SetAccess='protected')
        m_PfValue
    end
    %% facilities for dumping workspace file
    properties (SetAccess='protected')
        m_DumpFilename = '';
        m_DumpAll = false;
        % used to set compatible mode to the approach prior to version 8.0 for running optimization
        m_CompatibleMode = false;
    end
    
    methods (Access='protected')
        %% Initialize the optimization
        function InitializeBase( self, tutorialID, description, dumpWS, setAlpha, isTaxAware)
            fprintf('======== Running Tutorial %s  ========\n', tutorialID );
            fprintf( '%s\n', description ); 

            % Create a workspace and setup risk model data
            self.SetupRiskModel();

            % Create initial portfolio etc
            self.SetupPortfolios();

            if setAlpha 
                self.SetAlpha();
            end
            
            if isTaxAware
                self.SetPrice();
                self.SetupTaxLots();
            end
            % set up workspace dumping file
            self.SetupDumpFileBase(tutorialID, dumpWS);
        end
        %% set up workspace dumping file
        function SetupDumpFileBase(self, tutorialID, dumpWS)
            if ( self.m_DumpAll || dumpWS)
                self.m_DumpFilename = strcat('opsdata_',tutorialID,'.wsp');
            else
                self.m_DumpFilename = '';
            end
        end    
    end
    
    methods
        %% Constructor 
        function self = TutorialBase(data)
            self.m_Data = data;
        end
        
        %% set flag of dump all tutorial
        function DumpAll(self, dumpWS)
            self.m_DumpAll = dumpWS;
        end

        %% set approach compatible to that prior to version 8.0
        % parameter mode:  If True, run optimization in the approach prior to version 8.0. 
        %
        function SetCompatibleMode(self, mode) 
             self.m_CompatibleMode = mode; 
        end

        %% Setup initial portfolio, benchmarks and trade universe
        function SetupPortfolios(self)
            % Create an initial holding portfolio with no Cash
            self.m_InitPfs = javaArray('com.barra.optimizer.CPortfolio', self.m_Data.m_AccountNum);
            for iAccount = 1 : self.m_Data.m_AccountNum
                if iAccount==1
                    pfID = 'Initial Portfolio';
                else
                    pfID = strcat('Initial Portfolio', int2str(iAccount));
                end
                self.m_InitPfs(iAccount) = self.m_WS.CreatePortfolio(pfID);
                for i = 1 : self.m_Data.m_AssetNum
                    if self.m_Data.m_InitWeight(iAccount, i) ~= 0.0
                        self.m_InitPfs(iAccount).AddAsset(self.m_Data.m_ID(i), self.m_Data.m_InitWeight(iAccount,i));  
                    end
                end
            end
            self.m_InitPf = self.m_InitPfs(1);

            self.m_BMPortfolio = self.m_WS.CreatePortfolio('Benchmark');
            self.m_BM2Portfolio = self.m_WS.CreatePortfolio('Benchmark2');	
            self.m_TradeUniverse = self.m_WS.CreatePortfolio('Trade Universe');	

            for i = 1 : self.m_Data.m_AssetNum
                if ~strcmp( self.m_Data.m_ID(i), 'CASH' )
                    self.m_TradeUniverse.AddAsset(self.m_Data.m_ID(i));               
                    if self.m_Data.m_BMWeight(i) ~= 0.0
                        self.m_BMPortfolio.AddAsset(self.m_Data.m_ID(i), self.m_Data.m_BMWeight(i));	
                    end
                    if self.m_Data.m_BM2Weight(i) ~= 0
                        self.m_BM2Portfolio.AddAsset(self.m_Data.m_ID(i), self.m_Data.m_BM2Weight(i));	
                    end
                end
            end
        end
        
        %% Set up tax lots and recalculate asset weights
        function SetupTaxLots(self)
            % Add tax lots into the portfolio, compute asset values
            assetValue = zeros(self.m_Data.m_AccountNum, self.m_Data.m_AssetNum);
            for j=1:self.m_Data.m_Taxlots
                iAccount = self.m_Data.m_Account(j);
                iAsset = self.m_Data.m_Indices(j);
                initPf = self.m_InitPfs(iAccount);
				initPf.AddTaxLot(self.m_Data.m_ID(iAsset), self.m_Data.m_Age(j),...
                    		     self.m_Data.m_CostBasis(j), self.m_Data.m_Shares(j), false);
				assetValue(iAccount,iAsset) = assetValue(iAccount,iAsset) + self.m_Data.m_Price(iAsset)*self.m_Data.m_Shares(j);
            end
            % Set portfolio values
            self.m_PfValue = zeros(self.m_Data.m_AccountNum, 1);
            for i=1:self.m_Data.m_AccountNum
                for j=1:self.m_Data.m_AssetNum
                    self.m_PfValue(i) = self.m_PfValue(i) + assetValue(i,j);
                end
            end
            % Reset asset initial weights based on tax lot information
            for i=1:self.m_Data.m_AccountNum
                initPf = self.m_InitPfs(i);
                for j=1:self.m_Data.m_AssetNum
                    initPf.AddAsset(self.m_Data.m_ID(j), assetValue(i,j) / self.m_PfValue(i));
                end
            end
        end
        
        %% Calculate portfolio weights and values from tax lot data.
        function UpdatePortfolioWeights(self)
            for iAccount=1:self.m_Data.m_AccountNum
                pInitPf = self.m_InitPfs(iAccount);
                if (~isempty(pInitPf))
                    self.m_PfValue(iAccount) = 0.0;
                    assetValue = zeros(self.m_Data.m_AssetNum, 1);
                    oTaxLotIDs = pInitPf.GetTaxLotIDs();
                    for iAsset=1:self.m_Data.m_AssetNum
                        assetID = self.m_Data.m_ID(iAsset);
                        price = self.m_Data.m_Price(iAsset);
						lotID = oTaxLotIDs.GetFirst();
                        while ~strcmp(lotID,'')
                            lot = pInitPf.GetTaxLot(lotID);
                            if strcmp(lot.GetAssetID(), assetID)
                                value = lot.GetShares() * price;
                                self.m_PfValue(iAccount) = self.m_PfValue(iAccount) + value;
                                assetValue(iAsset) = assetValue(iAsset) + value;
                            end
							lotID = oTaxLotIDs.GetNext();
                        end
                    end

                    for iAsset=1:self.m_Data.m_AssetNum
                        pInitPf.AddAsset(self.m_Data.m_ID(iAsset), assetValue(iAsset) / self.m_PfValue(iAccount));
                    end
                end
            end
        end

        function SetupRiskModel(self)
            self.SetupRiskModelExposureOption(true);
        end

        %% Create a workspace and setup risk model data
        % In this function, vectorized APIs to set 
        % factorconvariance, exposure & specific covariance are
        % illustrated. Vectorized APIs are fast in performance. 
        function SetupRiskModelExposureOption(self, setExposures)
            % access to optimizer namespace
            import com.barra.optimizer.*
            % Initialize the Barra Optimizer CWorkSpace interface
            if  ~isempty(self.m_WS)
                self.m_WS.Release();
            end
            self.m_WS = CWorkSpace.CreateInstance;
                
            % Create Primary Risk Model
            pRM = self.m_WS.CreateRiskModel('GEM', ERiskModelType.eEQUITY);

            % Load the covariance matrix from the TutorialData object via
            % vectorized API
            pRM.SetFactorCovariances(self.m_Data.m_Factor, self.m_Data.m_CovData(:));

            % Add assets to the workspace
            for i = 1 : self.m_Data.m_AssetNum
                if( strcmp(self.m_Data.m_ID(i),'CASH') )
                    asset = self.m_WS.CreateAsset(self.m_Data.m_ID(i), EAssetType.eCASH);
                else
                    asset = self.m_WS.CreateAsset(self.m_Data.m_ID(i), EAssetType.eREGULAR);
                end
                % Set expected return here
                asset.SetAlpha(0); 
            end

            if setExposures  
                % Load the exposure matrix from the TutorialData object
                % via a vectorized API
                for i=1:self.m_Data.m_AssetNum
                    pRM.SetFactorExposuresForAsset(self.m_Data.m_ID(i), self.m_Data.m_Factor, self.m_Data.m_ExpData(i, :)); 
                end
                % or via an alternative vectorized API
                % assetIDs = repmat(self.m_Data.m_ID, 1, size(self.m_Data.m_Factor, 1));
                % factorIDs = repmat(self.m_Data.m_Factor, 1, size(self.m_Data.m_ID, 1))';
                % pRM.SetFactorExposures(assetIDs(:), factorIDs(:), self.m_Data.m_ExpData(:));
            end
            
            % Load specific risk covariance via vectorized API
            pRM.SetSpecificCovariances(self.m_Data.m_ID, self.m_Data.m_ID, self.m_Data.m_SpCov);
        end

        %% Setup a simple sample secondary risk model
        % In this function, poinit-by-point APIs are used to set 
        % factor covariance, exposure, specific covariance when the data is
        % sparse.
        function SetupRiskModel2(self)
            % access to optimizer namespace
            import com.barra.optimizer.*;
            % Create a risk model
            rm = self.m_WS.CreateRiskModel('MODEL2', ERiskModelType.eEQUITY);

            % Set factor covariances
            % via point-by-point API
            rm.SetFactorCovariance( 'Factor2_1', 'Factor2_1', 1.0 );
            rm.SetFactorCovariance( 'Factor2_1', 'Factor2_2', 0.1 );
            rm.SetFactorCovariance( 'Factor2_2', 'Factor2_2', 0.5 );

            % Set factor exposures
            % via point-by-point API
            for i = 1:self.m_Data.m_AssetNum
                rm.SetFactorExposure( self.m_Data.m_ID(i), 'Factor2_1', (i-1)/self.m_Data.m_AssetNum );
                rm.SetFactorExposure( self.m_Data.m_ID(i), 'Factor2_2', (2*(i-1))/self.m_Data.m_AssetNum );
            end

            % Set specific risk covariance
            % via point-by-point API 
            for i = 1:self.m_Data.m_AssetNum
                rm.SetSpecificCovariance( self.m_Data.m_ID(i), self.m_Data.m_ID(i), 0.05 );
            end
        end
        
        %% Set the expected return for each asset in the model
        function SetAlpha(self)
            
            % Set the expected return for each asset
            for i = 1:self.m_Data.m_AssetNum
                 asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                 if ~isempty(asset) 
                     asset.SetAlpha(self.m_Data.m_Alpha(i));
                 end
            end
        end
        
        %% Set the price for each asset in the model
        function SetPrice(self)
            for i = 1:self.m_Data.m_AssetNum
                asset = self.m_WS.GetAsset(self.m_Data.m_ID(i));
                if ~isempty(asset)
                    asset.SetPrice(self.m_Data.m_Price(i));
                end
            end
        end
        
        %% Run optimization by creating a new solver.
        function RunOptimize(self)
            self.RunOptimizeReuseSolverEstUtilUB(false,false);
        end 
        
        %% Run optimization without creating a new solver.
        function RunOptimizeReuseSolver(self)
            self.RunOptimizeReuseSolverEstUtilUB(true,false);
        end 
        
        %% Run optimization by creating a new solver & report the upperbound on the utility
        function RunOptimizeReportUtilUB(self)
            self.RunOptimizeReuseSolverEstUtilUB(false,true);
        end 
        
        %% Run optimization
        % parameter useOldSolver: If True, use the eixisting m_Solver pointer without recreate a new solver.
        % parameter estUtilUB: If True, estimate the upperbound on the utility.
        function RunOptimizeReuseSolverEstUtilUB(self, useOldSolver, estUtilUB)
            % access to optimizer namespace
            import com.barra.optimizer.*;
            if ~useOldSolver 
                self.m_Solver = self.m_WS.CreateSolver(self.m_Case);
            end
            % set compatible mode
            if self.m_CompatibleMode  
                self.m_Solver.SetOption( 'COMPATIBLE_MODE', 1.0);
            end
            
            % estimate upperbound on utility
            if estUtilUB 
                self.m_Solver.SetOption( 'REPORT_UPPERBOUND_ON_UTILITY', 1.0);
            end
            % opsdata info could be very helpful in debugging 
            if  size(self.m_DumpFilename,2)>0 
                self.m_WS.Serialize(self.m_DumpFilename);
            end
            
            oStatus = self.m_Solver.Optimize();
            
            fprintf('%s\n', char(oStatus.GetMessage()));
            fprintf('%s\n', char(self.m_Solver.GetLogMessage()));

            if oStatus.GetStatusCode() == EStatusCode.eOK	
                output = self.m_Solver.GetPortfolioOutput();
                maOutput = self.m_Solver.GetMultiAccountOutput();
                mpOutput = self.m_Solver.GetMultiPeriodOutput();
                if ~isempty(output) 
                    self.PrintPortfolioOutput(output, estUtilUB);
                elseif ~isempty(maOutput)
                    self.PrintMultiAccountOutput(maOutput);
                elseif ~isempty(mpOutput)
                    self.PrintMultiPeriodOutput(mpOutput);
                end
            elseif oStatus.GetStatusCode() == EStatusCode.eLICENSE_ERROR
                throw( MException('Optimizer:License','Optimizer license error') ) 
            end
        end
        
        function PrintPortfolioOutput(self, output, estUtilUB)
                    import com.barra.optimizer.*;
                    fprintf('Optimized Portfolio:\n');
                    fprintf('Risk(%%)     = %.4f\n', output.GetRisk());
                    fprintf('Return(%%)   = %.4f\n', output.GetReturn());
                    fprintf('Utility     = %.4f\n' , output.GetUtility());
                    if estUtilUB
                        utilUB = output.GetUpperBoundOnUtility();
                        if utilUB ~= barraopt.getOPT_NAN()
                            fprintf('Util. Upperbound = %.4f\n', utilUB);  
                        end
                    end
                    fprintf('Turnover(%%) = %.4f\n', output.GetTurnover());
                    fprintf('Penalty     = %.4f\n', output.GetPenalty());
                    fprintf('TranxCost(%%)= %.4f\n', output.GetTransactioncost());
                    fprintf('Beta        = %.4f\n', output.GetBeta());
                    if output.GetExpectedShortfall() ~= barraopt.getOPT_NAN()
                        fprintf('ExpShortfall(%%)= %.4f\n', output.GetExpectedShortfall());
                    end
                    fprintf('\n');
                    % Output the non-zero weight in the optimized portfolio
                    fprintf('Asset Holdings:\n');
                    portfolio = output.GetPortfolio();
                    idSet = portfolio.GetAssetIDSet();
                    assetID = idSet.GetFirst();

                    while ~strcmp(assetID,'') 
                        weight = portfolio.GetAssetWeight(assetID);
                        if weight ~= 0.0
                            fprintf('%s: %.4f\n', char(assetID), weight);
                        end
                        assetID = idSet.GetNext();
                    end
                    fprintf('\n');
        end
        
        function PrintMultiAccountOutput(self, output)
                    import com.barra.optimizer.*;
                    % Retrieve cross-account output
                    crossAccountOutput = output.GetCrossAccountOutput();
                    crossAccountTaxOutput = output.GetCrossAccountTaxOutput();
                    fprintf('Account     = Cross-account\n');
                    fprintf('Return(%%)   = %.4f\n', crossAccountOutput.GetReturn());
                    fprintf('Utility     = %.4f\n',  crossAccountOutput.GetUtility());
                    fprintf('Turnover(%%) = %.4f\n', crossAccountOutput.GetTurnover());
                    jointMarketImpactBuyCost = output.GetJointMarketImpactBuyCost();
                    if jointMarketImpactBuyCost ~= barraopt.getOPT_NAN()
                        fprintf('Joint Market Impact Buy Cost($) = %.4f\n', jointMarketImpactBuyCost);
                    end
                    jointMarketImpactSellCost = output.GetJointMarketImpactSellCost();
                    if jointMarketImpactSellCost ~= barraopt.getOPT_NAN()
                        fprintf('Joint Market Impact Sell Cost($) = %.4f\n', jointMarketImpactSellCost);
                    end
                    if ~isempty(crossAccountTaxOutput)
                        fprintf('Total Tax   = %.4f\n', crossAccountTaxOutput.GetTotalTax());
                    end
                    fprintf('\n');

                    % Retrieve output for each account group
                    if output.GetNumAccountGroups() > 0
                        for i = 1:output.GetNumAccountGroups()
                            groupOutput = output.GetAccountGroupTaxOutput(i-1);
                            fprintf('Account Group = %d\n', groupOutput.GetAccountGroupID());
                            fprintf('Total Tax     = %.4f\n', groupOutput.GetTotalTax());
                        end
                        fprintf('\n');
                    end
                    
                    % Retrieve output for each account
                    for i=1:output.GetNumAccounts()
                        accountOutput = output.GetAccountOutput(i-1);
                        accountID = accountOutput.GetAccountID();
                        fprintf('Account     = %d\n', accountID);
                        fprintf('Risk(%%)     = %.4f\n', accountOutput.GetRisk());
                        fprintf('Return(%%)   = %.4f\n', accountOutput.GetReturn());
                        fprintf('Utility     = %.4f\n',  accountOutput.GetUtility());
                        fprintf('Turnover(%%) = %.4f\n', accountOutput.GetTurnover());
                        fprintf('Beta        = %.4f\n\n', accountOutput.GetBeta());

                        % Output the non-zero weight in the optimized portfolio
                        fprintf('Asset Holdings:\n');
                        portfolio = accountOutput.GetPortfolio();
                        idSet = portfolio.GetAssetIDSet();
                        assetID = idSet.GetFirst();
                        while ~strcmp(assetID,'') 
                            weight = portfolio.GetAssetWeight(assetID);
                            if weight ~= 0.0
                                fprintf('%s: %.4f\n', char(assetID), weight);
                            end
                            assetID = idSet.GetNext();
                        end
                        fprintf('\n');

				        taxOut = accountOutput.GetNewTaxOutput();
                        if ~isempty(taxOut)
                            if self.GetAccountGroupID(accountID) == -1
                                ltax = taxOut.GetLongTermTax( '*', '*' );
                                stax = taxOut.GetShortTermTax('*', '*');
                                lgg_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_GAIN );
                                lgl_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eLONG_TERM, ECapitalGainType.eCAPITAL_LOSS );
                                sgg_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_GAIN );
                                sgl_all = taxOut.GetCapitalGain( '*', '*', ETaxCategory.eSHORT_TERM, ECapitalGainType.eCAPITAL_LOSS );
			
                                fprintf( 'Tax info for the tax rule group(all assets):\n' );
                                fprintf('Long Term Gain = %.4f\n', lgg_all);
                                fprintf('Long Term Loss = %.4f\n', lgl_all);
                                fprintf('Short Term Gain = %.4f\n', sgg_all);
                                fprintf('Short Term Loss = %.4f\n', sgl_all);
                                fprintf('Long Term Tax  = %.4f\n', ltax);
                                fprintf('Short Term Tax = %.4f\n', stax);

                                fprintf('\nTotal Tax(for all tax rule groups) = %.4f\n\n', taxOut.GetTotalTax());
                            end

                            fprintf( 'TaxlotID          Shares:\n' );
                            assetID = idSet.GetFirst();
                            while ~strcmp(char(assetID), '')
                                sharesInTaxlot = taxOut.GetSharesInTaxLots(assetID);
                                oLotIDs = sharesInTaxlot.GetKeySet();
                                lotID = oLotIDs.GetFirst();
                                while ~strcmp(char(lotID), '')
                                    shares = sharesInTaxlot.GetValue( lotID );
                                    if shares~=0
                                        fprintf( '%s %.4f\n', char(lotID), shares );
                                    end
                                    lotID = oLotIDs.GetNext();
                                end
                                assetID = idSet.GetNext();
                            end

                            newShares = taxOut.GetNewShares();
                            fprintf( '\n' );
                            self.PrintAttributeSet(newShares, 'New Shares:');
                            fprintf( '\n' );
                        end
                    end
        end
        
        function PrintMultiPeriodOutput(self, output)
                    % Retrieve cross-period output
                    crossPeriodOutput = output.GetCrossPeriodOutput();
                    fprintf('Period      = Cross-period\n');
                    fprintf('Return(%%)   = %.4f\n', crossPeriodOutput.GetReturn());
                    fprintf('Utility     = %.4f\n',  crossPeriodOutput.GetUtility());
                    fprintf('Turnover(%%) = %.4f\n\n', crossPeriodOutput.GetTurnover());

                    % Retrieve output for each period
                    for i=1:output.GetNumPeriods()
                        periodOutput = output.GetPeriodOutput(i-1);
                        fprintf('Period      = %d\n', periodOutput.GetPeriodID());
                        fprintf('Risk(%%)     = %.4f\n', periodOutput.GetRisk());
                        fprintf('Return(%%)   = %.4f\n', periodOutput.GetReturn());
                        fprintf('Utility     = %.4f\n',  periodOutput.GetUtility());
                        fprintf('Turnover(%%) = %.4f\n', periodOutput.GetTurnover());
                        fprintf('Beta        = %.4f\n\n', periodOutput.GetBeta());
                    end
        end
        
        %% Output trade list
        % parameter isOptimalPortfolio: If True, retrieve trade list info from the optimal portfolio; otherwise from the roundlotted portfolio
        %
        function OutputTradeList(self, isOptimalPortfolio)
            % access to optimizer namespace
            import com.barra.optimizer.*;
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                if isOptimalPortfolio
                    fprintf('Optimal Portfolio:\n');
                    portfolio = output.GetPortfolio();
                else
                    fprintf('Roundlotted Portfolio:\n');
                    oddLotIDSet = self.m_WS.CreateIDSet();
                    portfolio = output.GetRoundlottedPortfolio(oddLotIDSet);
                end

                fprintf('Asset Holdings:\n');
                IDSet = portfolio.GetAssetIDSet();

                assetID = IDSet.GetFirst();
                while ~strcmp(assetID,'')
                    weight = portfolio.GetAssetWeight(assetID);
                    if weight ~= 0
                        fprintf('%s: %.4f\n', char(assetID), weight);
                    end
                    assetID = IDSet.GetNext();
                end
                
                fprintf('\nTrade List:\n');
                fprintf('Asset: Initial Shares, Final Shares, Traded Shares, Price, Traded Value, Traded Value(%%), Transaction Cost, Trade Type\n');

                assetID = IDSet.GetFirst();
                while ~strcmp(assetID, '')
                    if ~strcmp(assetID, 'CASH')
                        tradelistInfo = output.GetAssetTradeListInfo(assetID, isOptimalPortfolio);
                        tradeType = '';
                        if tradelistInfo.GetTradeType() == ETradeType.eHOLD
                            tradeType = 'Hold';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eBUY
                            tradeType = 'Buy';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eCOVER_BUY
                            tradeType = 'Cover Buy';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eCROSSOVER_BUY
                            tradeType = 'Crossover Buy';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eCROSSOVER_SELL
                            tradeType = 'Crossover Sell';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eSELL
                            tradeType = 'Sell';
                        elseif tradelistInfo.GetTradeType() == ETradeType.eSHORT_SELL
                            tradeType = 'Short Sell';
                        end
                        fprintf('%s: %.4f', char(assetID), tradelistInfo.GetInitialShares());
                        fprintf(', %.4f', tradelistInfo.GetFinalShares());
                        fprintf(', %.4f', tradelistInfo.GetTradedShares());
                        fprintf(', %.4f', tradelistInfo.GetPrice());
                        fprintf(', %.4f', tradelistInfo.GetTradedValue());
                        fprintf(', %.4f', tradelistInfo.GetTradedValuePcnt());
                        fprintf(', %.4f', tradelistInfo.GetTotalTransactionCost());
                        fprintf(', %s\n', tradeType);
                    end
                    assetID = IDSet.GetNext();
                end
                fprintf('\n');
            end
        end

        %% Returns the ID of the group which the account belongs to.
        % parameter accountID: the ID of the account.
        %
        function groupID = GetAccountGroupID(self, accountID)
            groupID = -1;
            if ~isempty(self.m_Solver)
                for i=1:self.m_Solver.GetNumAccounts()
                    account = self.m_Solver.GetAccount(i-1);
                    if account.GetID()==accountID
                        groupID = account.GetGroupID();
                        break
                    end
                end
            end
        end
		
        function CollectKKT(self, multiplier)
            output = self.m_Solver.GetPortfolioOutput();
            if ~isempty(output)
                kkt = KKTData();
                %alpha
                alphakkt = self.m_WS.CreateAttributeSet();
                portfolio = output.GetPortfolio();
                idSet = portfolio.GetAssetIDSet();
                assetID = idSet.GetFirst();
                while ~strcmp(assetID, '')
                    weight = portfolio.GetAssetWeight(assetID);
                    if weight ~= 0. 
                        alphakkt.Set(assetID, self.m_WS.GetAsset(assetID).GetAlpha()*multiplier); %*alphaterm
                    end        
                    assetID = idSet.GetNext();
                end
                kkt.AddConstraint(alphakkt, 'alpha', 'Alpha');

                % other kkt
                kkt.AddConstraint(output.GetPrimaryRiskModelKKTTerm(), 'primaryRMKKT', 'Primary RM');
                kkt.AddConstraint(output.GetSecondaryRiskModelKKTTerm(), 'secondaryRMKKT', 'Secondary RM');
                kkt.AddConstraint(output.GetResidualAlphaKKTTerm(), 'residualAlphaKKTTerm', 'Residual Alpha');
                kkt.AddConstraint(output.GetTransactioncostKKTTerm(true), 'transactionCostKKTTerm', 'transaction cost');

                % balanced kkt
                balanceSlackInfo = output.GetSlackInfo4BalanceCon();
                if ~isempty(balanceSlackInfo)
                    kkt.AddConstraint(balanceSlackInfo.GetKKTTerm(true), 'balanceKKTTerm', 'Balance KKT');
                end
                % get the KKT and penalty KKT terms for the asset bound constraints
                slackInfoIDs = output.GetSlackInfoIDs();
                slackID = slackInfoIDs.GetFirst();     
                while ~strcmp(slackID, '')
                    slackInfo = output.GetSlackInfo(slackID);
                    kkt.AddConstraint(slackInfo.GetKKTTerm(true), slackID,  slackID); %upside
                    kkt.AddOnlyIfDifferent(slackInfo.GetKKTTerm(false), slackID,  slackID); %downside
                    kkt.AddConstraintPenalty(slackInfo.GetPenaltyKKTTerm(true), slackID, strcat(char(slackID), ' Penalty')); % upside
                    kkt.AddOnlyIfDifferentPenalty(slackInfo.GetPenaltyKKTTerm(false), slackID, strcat(char(slackID), ' Penalty')); % downside
                    slackID = slackInfoIDs.GetNext();
                end
                kkt.print();
            end
        end
    
        function PrintRisksByAsset(self, portfolio)
            import com.barra.optimizer.*;
            assetIDs = portfolio.GetAssetIDSet();

            % copy assetIDs for safe iteration (calling EvaluateRisk() might invalidate iterators)
	        ids = self.m_WS.CreateIDSet();
            id = assetIDs.GetFirst();
	        for i = 1:assetIDs.GetCount()
		        ids.Add(id);
                id = assetIDs.GetNext();
            end
            
            id = ids.GetFirst();
	        for i = 1:ids.GetCount()
		        idset = self.m_WS.CreateIDSet();
                idset.Add(id);
                risk = self.m_Solver.EvaluateRisk(portfolio, ERiskType.eTOTALRISK, [], idset, [], true, true);
		        if risk ~= 0.0
			        fprintf('Risk from %s = %.4f\n', char(id), risk);
                end
                idset.Release();
                id = ids.GetNext();
            end
            ids.Release();
        end
    end
    
    %% output AttributeSet
    methods(Static)
        function PrintAttributeSet(attributeSet, title)
            idSet = attributeSet.GetKeySet();
            id = idSet.GetFirst();
            if ~strcmp(id, '')
                fprintf('%s\n', title);
                while ~strcmp(id, '')
                    fprintf('%s: %.4f\n', char(id), attributeSet.GetValue(id));
                    id = idSet.GetNext();
                end
            end
        end
    end
end

