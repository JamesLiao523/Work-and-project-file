%% Handles data used for all tutorials.
%% Pass object by reference
% matlab class passes object by value by default. In order to pass by
% reference as in JAVA class, derive your class from "handle" class
classdef TutorialData < handle
    %% constant properties
	properties (Constant)
        m_AccountNum = 3;
        m_AssetNum = 11;
        m_FactorNum = 68;
        m_Taxlots = 39;
        m_ScenarioNum = 100;
    end
    %% Path for simultion data files
    properties 
        m_Datapath;
    end
    %% vectors
    properties
		m_Shortfall_Beta
        m_ID = cellstr( ['CASH   '; 'USA11I1'; 'USA13Y1'; 'USA1LI1'; 'USA1TY1'; 'USA2ND1'; 'USA3351'; 'USA37C1';...
            'USA39K1'; 'USA45V1'; 'USA4GF1'] );
        
        m_GICS_Sector = cellstr([   '                      '; ...
                                    'Financials            '; ...
                                    'Information Technology'; ...
                                    'Information Technology'; ...
                                    'Industrials           '; ...
                                    'Minerals              '; ...
                                    'Utilities             '; ...
                                    'Minerals              '; ...
                                    'Health Care           '; ...
                                    'Utilities             '; ...
                                    'Information Technology' ]);
                                
        m_Issuer = ['1'; '2'; '2'; '2'; '3'; '3'; '4'; '4'; '5'; '5'; '6'];
        m_Factor = cellstr( ['Factor_1A'; 'Factor_1B'; 'Factor_1C'; 'Factor_1D';'Factor_1E';'Factor_1F';'Factor_1G';'Factor_1H'; ...
				  'Factor_2A'; 'Factor_2B'; 'Factor_2C'; 'Factor_2D';'Factor_2E';'Factor_2F';'Factor_2G';'Factor_2H'; ...
				  'Factor_3A'; 'Factor_3B'; 'Factor_3C'; 'Factor_3D';'Factor_3E';'Factor_3F';'Factor_3G';'Factor_3H'; ...
				  'Factor_4A'; 'Factor_4B'; 'Factor_4C'; 'Factor_4D';'Factor_4E';'Factor_4F';'Factor_4G';'Factor_4H'; ...
				  'Factor_5A'; 'Factor_5B'; 'Factor_5C'; 'Factor_5D';'Factor_5E';'Factor_5F';'Factor_5G';'Factor_5H'; ...
				  'Factor_6A'; 'Factor_6B'; 'Factor_6C'; 'Factor_6D';'Factor_6E';'Factor_6F';'Factor_6G';'Factor_6H'; ...
				  'Factor_7A'; 'Factor_7B'; 'Factor_7C'; 'Factor_7D';'Factor_7E';'Factor_7F';'Factor_7G';'Factor_7H'; ...
				  'Factor_8A'; 'Factor_8B'; 'Factor_8C'; 'Factor_8D';'Factor_8E';'Factor_8F';'Factor_8G';'Factor_8H'; ...
				  'Factor_9A'; 'Factor_9B'; 'Factor_9C'; 'Factor_9D'] );

        % Initial weights (holding) for all the assets and cash. Each element should be a decimal instead 
        % of percent, for example, 30% holding should be entered as 0.3. In this asset array, the first 
        % item is cash, and only the index 0,1,10 assets have non-zero initial weight. 
        m_InitWeight = [ % Portfolio 1
                        [0.000000e+000, 5.605964e-001, 4.394036e-001, 0.000000e+000, 0.000000e+000, ...
						 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, ...
						 0.000000e+000];
                         % Portfolio 2
                        [0.000000e+000, 0.000000e+000, 2.405964e-001, 7.594036e-001, 0.000000e+000, ...
						 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, ...
						 0.000000e+000];
                         % Portfolio 3
                        [0.000000e+000, 0.000000e+000, 0.000000e+000, 1.000000e+000, 0.000000e+000, ...
						 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, ...
						 0.000000e+000]];
                    
        % Benchmark Portofolio Weight
        m_BMWeight = [0.0000000; 0.169809; 0.0658566; 0.160816; 0.0989991; ... 
                      0.0776341; 0.0768613; 0.0725244; 0.2774998; 0.0000000; ...
                      0.0000000];

        % Benchmark 2 Portofolio Weight
	    m_BM2Weight = [0.0000000; 0.0000000; 0.2500000; 0.0000000; 0.0000000; ...
                       0.0000000; 0.5000000; 0.0000000; 0.0000000; 0.2500000; ...
                       0.0000000];  

        % Specific covariance
        m_SpCov = [0.000000e+000; 3.247204e-002; 3.470769e-002; 1.313338e-001; 9.180900e-002; ...
                    3.059001e-002; 6.996025e-002; 4.507129e-002; 5.225796e-002; 5.631129e-002; ...
                    7.017201e-002];
	
        m_Price = [1.00; 23.99; 34.19; 67.24; 375.51; 70.06; 17.48; 17.66; 32.96; 14.73; 34.48];

        m_Alpha = [0.000000e+000; 1.576034e-002; 2.919658e-003; 6.419658e-003; 4.420342e-003; ...
                    9.996575e-004; 3.320342e-003; 2.700342e-003; 1.849966e-002; 1.459658e-003; ...
                    6.079658e-003];
                
        % Tax lot information
        m_Account = [0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;	0+1;
                     1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;	1+1;
                     2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1;	2+1];

        m_Indices = [0+1;	1+1;	1+1;	2+1;	2+1;	3+1;	4+1;	5+1;	6+1;	7+1;	8+1;	9+1;	10+1;
                     0+1;	1+1;	2+1;	2+1;	3+1;	3+1;	4+1;	5+1;	6+1;	7+1;	8+1;	9+1;	10+1;
                     0+1;	1+1;	2+1;	2+1;	3+1;	3+1;	4+1;	5+1;	6+1;	7+1;	8+1;	9+1;	10+1];

        m_Age = [0; 937;    832;    1641;   295;    0;  0;  0;  0;  0;  0;  0;  0;
                 0;   0;    512;     435;   295;  937;  0;  0;  0;  0;  0;  0;  0;
                 0;   0;      0;       0;     0;  937;  0;  0;  0;  0;  0;  0;  0];

        m_CostBasis = [1.0;	28.22;  25.37;  15.19;  18.90;  67.24; 375.51; 70.06;  17.48;  17.66;  32.96;  14.73;  34.48;
                       1.0;	23.99;  26.56;  27.49;  18.90;  32.53; 375.51; 70.06;  17.48;  17.66;  32.96;  14.73;  34.48;
                       1.0;	23.99;  26.56;  27.49;  18.90;  32.53; 375.51; 70.06;  17.48;  17.66;  32.96;  14.73;  34.48];

        m_Shares = [0;  50; 50; 20;  35;  0;  0;  0;  0;  0;  0;  0; 0;
                    0;   0; 50; 31; 100; 30;  0;  0;  0;  0;  0;  0; 0;
                    0;   0;  0;  0;   0;130;  0;  0;  0;  0;  0;  0; 0];
    end   
    
    %% matrices
    properties
        m_CovData
        m_ExpData
        m_ScenarioData
    end 
 
    %% Methods
    methods   
        %% Constructor
        function self = TutorialData()
            pathstr = fileparts(pwd);
            self.m_Datapath = strcat(pathstr, '/tutorial_data/');
            self.ReadCovariance();
            self.ReadExposure();
            self.ReadScenarioReturn();
        end
        
        %% Read factor covariance from a data file 
        % Read from a file the factor covariance data into the m_CovData array
        function ReadCovariance(self)
            % Read covariance matrix
            filepath = strcat(self.m_Datapath, 'cov.txt');
            fid = fopen(filepath,'r');
            if ( fid == -1 )
                fprintf('Tutorial data file not found: \n %s ', filepath);
                exit(1);
            end

            % Skip all the comment line started with '!' at the beginning
            % Read ~half of the matrix data is in the file
            % Because it is symmetrical
            count = 0;
            while count == 0
                [buf, count] = fscanf(fid, '%e'); 
                if count == 0
                    fgetl(fid);
                end
            end
            fclose(fid);
            
            % Set up factor covariance matrix to use more efficient 
            % optimizer's API to load covariance 
            count = 1;
            for i=1:self.m_FactorNum
                for j=1:i-1 
                    self.m_CovData(i,j)=buf(count);
                    self.m_CovData(j,i)=buf(count);
                    count=count+1;
                end
                self.m_CovData(i,i) = buf(count);
                count=count+1;
            end
        end
        
        %% Read from a file the factor exposure data into the m_ExpData array
        function ReadExposure(self)
            % Read asset exposures
            filepath = strcat(self.m_Datapath, 'fx.txt');
            fid = fopen(filepath,'r');
            if ( fid == -1 )
                fprintf('Tutorial data file not found: \n %s ', filepath);
                exit(1);
            end
            
            % Read m_Asset*m_FactorNum exposures
            for i=1:self.m_AssetNum
                count = 0;
                % Skip all the comment line started with '!' at the beginning
                while count ~= self.m_FactorNum
                    [buf, count] = fscanf(fid, '%e', self.m_FactorNum ); 
                    switch count
                        case 0
                            fgetl(fid);
                        case self.m_FactorNum
                            for j=1:self.m_FactorNum
                                self.m_ExpData(i,j) = buf(j);
                            end
                        otherwise
                            disp('not enough exposure data!')
                    end
                end
            end
            
            fclose(fid);
        end
        
        %%   Read shortfall beta 
        %   from the sampleTutorial2_assetAttribution.csv file into the 
        %   m_Shortfall_Beta array. The sampleTutorial2_assetAttribution.csv file is the output 
        %   of Barra BxR 1.0 tutorial 2.
        %
        function ReadShortfallBeta( self )
            filepath = strcat( self.m_Datapath, 'sampleTutorial2_assetAttribution.csv' );
            fid = fopen(filepath,'r');
            if ( fid == -1 )
                fprintf('Tutorial data file not found: \n %s ', filepath);
                exit(1);
            end

        % Read shortfall beta data
            % skip the tilte line
            fgetl( fid );					
            for i=2:self.m_AssetNum 
                buf = fgetl( fid );

                % search for the 5th ',' 
                pos = strfind( buf, ',' );
                % dataLen = pos(6) - pos(5) - 1;
                self.m_Shortfall_Beta(i) = sscanf( buf(pos(5)+1:pos(6)), '%f');
            end
            % Cash
            self.m_Shortfall_Beta(1) = 0.0;				
        end
        
        %% Read scenario return
        % from the scenario_returns.csv file into the
        % m_ScenarioData array. The scenario_return.csv file was generated
        % by taking samples from a normal distribution with alphas as mean,
        % and with covariance matrix from the risk model.
        function ReadScenarioReturn( self )
            filepath = strcat( self.m_Datapath, 'scenario_returns.csv' );
            fid = fopen(filepath,'r');
            if ( fid == -1 )
                fprintf('Tutorial data file not found: \n %s ', filepath);
                exit(1);
            end

            % Read scenario returns
            for i=1:self.m_ScenarioNum 
                buf = fgetl( fid );
                vals = sscanf( buf, '%f,' );
                for j=1:self.m_AssetNum
                    self.m_ScenarioData(i,j) = vals(j);
                end
            end
        end
    end
end
