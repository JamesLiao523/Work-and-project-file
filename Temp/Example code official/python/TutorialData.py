# TutorialData.py
# \brief Contains definitions of the TutorialData class that handles 
# data used for all tutorials.
#

import os

# Handles data used for all tutorials.
class TutorialData(object):
    m_AccountNum = 3
    m_AssetNum = 11
    m_FactorNum = 68
    m_Taxlots = 39
    m_ScenarioNum = 100
    m_CovData = []
    m_Shortfall_Beta = []
    m_ExpData = [[0 for y in range(68)] for x in range(11)]
    m_ScenarioData = [[0 for y in range(11)] for x in range(100)]

    #Asset IDs
    m_ID = ['CASH', 'USA11I1', 'USA13Y1', 'USA1LI1', 'USA1TY1', 'USA2ND1', 'USA3351',
            'USA37C1', 'USA39K1', 'USA45V1', 'USA4GF1']
    m_GICS_Sector = [ '', 'Financials', 'Information Technology', 'Information Technology',
                      'Industrials', 'Minerals', 'Utilities', 'Minerals', 'Health Care', 'Utilities', 'Information Technology']
    m_Issuer = ['1', '2', '2', '2', '3', '3', '4', '4', '5', '5', '6']
    m_Factor = ['Factor_1A', 'Factor_1B', 'Factor_1C', 'Factor_1D','Factor_1E','Factor_1F','Factor_1G','Factor_1H',
                'Factor_2A', 'Factor_2B', 'Factor_2C', 'Factor_2D','Factor_2E','Factor_2F','Factor_2G','Factor_2H',
                'Factor_3A', 'Factor_3B', 'Factor_3C', 'Factor_3D','Factor_3E','Factor_3F','Factor_3G','Factor_3H',
                'Factor_4A', 'Factor_4B', 'Factor_4C', 'Factor_4D','Factor_4E','Factor_4F','Factor_4G','Factor_4H',
                'Factor_5A', 'Factor_5B', 'Factor_5C', 'Factor_5D','Factor_5E','Factor_5F','Factor_5G','Factor_5H',
                'Factor_6A', 'Factor_6B', 'Factor_6C', 'Factor_6D','Factor_6E','Factor_6F','Factor_6G','Factor_6H',
                'Factor_7A', 'Factor_7B', 'Factor_7C', 'Factor_7D','Factor_7E','Factor_7F','Factor_7G','Factor_7H',
                'Factor_8A', 'Factor_8B', 'Factor_8C', 'Factor_8D','Factor_8E','Factor_8F','Factor_8G','Factor_8H',
                'Factor_9A', 'Factor_9B', 'Factor_9C', 'Factor_9D']
    #Initial weights (holding) for all the assets and cash. Each element should be a decimal instead 
    #of percent, for example, 30% holding should be entered as 0.3. In this asset array, the first 
    #item is cash, and only the index 0,1,10 assets have non-zero initial weight. 
    m_InitWeight = [ 
            # Portfolio 1
              [0.000000e+000, 5.605964e-001, 4.394036e-001, 0.000000e+000, 0.000000e+000,
               0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
               0.000000e+000],
            # Portfolio 2
              [0.000000e+000, 0.000000e+000, 2.405964e-001, 7.594036e-001, 0.000000e+000,
               0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
               0.000000e+000],
            # Portfolio 3
              [0.000000e+000, 0.000000e+000, 0.000000e+000, 1.000000e+000, 0.000000e+000,
               0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
               0.000000e+000]]

    # Benchmark Portofolio Weight
    m_BMWeight = [0.0000000, 0.169809, 0.0658566, 0.160816, 0.0989991,
                  0.0776341, 0.0768613, 0.0725244, 0.2774998, 0.0000000,
                  0.0000000]
    # Benchmark 2 Portofolio Weight
    m_BM2Weight = [0.0000000, 0.0000000, 0.2500000, 0.0000000, 0.0000000,
                   0.0000000, 0.5000000, 0.0000000, 0.0000000, 0.2500000,
                   0.0000000]  

    # Specific covariance
    m_SpCov = [0.000000e+000, 3.247204e-002, 3.470769e-002, 1.313338e-001, 9.180900e-002,
               3.059001e-002, 6.996025e-002, 4.507129e-002, 5.225796e-002, 5.631129e-002,
               7.017201e-002]
    
    # Asset Price
    m_Price = [1.00, 23.99, 34.19, 67.24, 375.51, 70.06, 17.48, 17.66, 32.96, 14.73, 34.48]
    m_Alpha = [0.000000e+000, 1.576034e-002, 2.919658e-003, 6.419658e-003, 4.420342e-003,
               9.996575e-004, 3.320342e-003, 2.700342e-003, 1.849966e-002, 1.459658e-003,
               6.079658e-003]
    
    # Tax lot information
    m_Account = [0, 0,  0,  0,  0,  0,  0,  0,  0,  0,  0,  0,   0,
                 1, 1,  1,  1,  1,  1,  1,  1,  1,  1,  1,  1,   1,
                 2, 2,  2,  2,  2,  2,  2,  2,  2,  2,  2,  2,   2]
    m_Indices = [0, 1,  1,  2,  2,  3,  4,  5,  6,  7,  8,  9,  10,
                 0, 1,  2,  2,  3,  3,  4,  5,  6,  7,  8,  9,  10,
                 0, 1,  2,  2,  3,  3,  4,  5,  6,  7,  8,  9,  10]
    m_Age = [0,	937, 832, 1641, 295, 0, 0, 0, 0, 0, 0, 0, 0,
             0,   0, 512,  435, 295, 937, 0, 0, 0, 0, 0, 0, 0,
             0,	  0,   0,    0,   0, 937, 0, 0, 0, 0, 0, 0, 0]
    m_CostBasis = [1.0, 28.22,  25.37,  15.19,  18.90,  67.24, 375.51, 70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
                   1.0, 23.99,  26.56,  27.49,  18.90,  32.53, 375.51, 70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
                   1.0, 23.99,  26.56,  27.49,  18.90,  32.53, 375.51, 70.06,  17.48,  17.66,  32.96,  14.73,  34.48]
    m_Shares = [0,    50,     50,     20,      35,      0,       0,      0,     0,      0,      0,      0,     0,
                0,     0,     50,     31,     100,     30,       0,      0,     0,      0,      0,      0,     0,
                0,     0,      0,      0,       0,    130,       0,      0,     0,      0,      0,      0,     0]

    # Constructor; Calls ReadCovariance() and ReadExposure().
    def __init__(self):
        parentDir = os.path.abspath('..')
        self.m_Datapath = parentDir + os.sep + 'tutorial_data' + os.sep
        self.ReadCovariance()
        self.ReadExposure()
        self.ReadScenarioReturn()
 
    # Read from a file the factor covariance data into the m_CovData array
    def ReadCovariance(self):
        # Read covariance matrix
        filepath = self.m_Datapath + 'cov.txt'
        if not os.path.isfile(filepath):
            print('Tutorial data file not found: \n' + filepath)
            exit(1)           
        with open(filepath, 'r') as ifs:
            for line in ifs:
                row=line.strip()
                # Skip all the comment line started with '!' at the beginning
                if not row.startswith('!'):
                    # Only need to set the half of the matrix because it is symmetrical
                    # set the lower half in this case
                    columns = row.split()
                    for col in range(len(columns)):
                        self.m_CovData.append(float(columns[col]))
                        
    # Read from a file the factor exposure data into the m_ExpData array
    def ReadExposure(self):
        # Read asset exposures
        filepath = self.m_Datapath + 'fx.txt'
        if not os.path.isfile(filepath):
            print('Tutorial data file not found: \n' + filepath)
            exit(1)
   
        with open(filepath, 'r') as ifs:
            i=0
            j=0
            for line in ifs:
                if i>=self.m_AssetNum:
                    break
                else: 
                    row=line.strip()
                    if not ( row.startswith('!') or row.startswith('\n') ):
                        columns = row.split()
                        for ind in range(len(columns)):  
                            self.m_ExpData[i][j]=float(columns[ind])
                            j=j+1
                        if j>=self.m_FactorNum:
                            i=i+1
                            j=0

    # Read shortfall beta from the sampleTutorial2_assetAttribution.csv file into the 
    # m_Shortfall_Beta array. The sampleTutorial2_assetAttribution.csv file is the output 
    # of Barra BxR 1.0 tutorial 2.
    #
    def ReadShortfallBeta(self):
        filepath = self.m_Datapath + 'sampleTutorial2_assetAttribution.csv'
        if not os.path.isfile(filepath):
            print( 'Tutorial data file not found: \n' + filepath )
            exit(1)
 
        # Read shortfall beta data
        with open(filepath, 'r') as ifs:
            i = 0
            for line in ifs:
                if i>=self.m_AssetNum:
                    break
                else:
                    if i==0:    # Cash
                        self.m_Shortfall_Beta.append(0.0)
                    else:       # search for the 5th ',' 
                        row=line.strip()
                        columns = row.split(',')
                        self.m_Shortfall_Beta.append(float(columns[5]))
                    i=i+1

    # Read scenario return from the scenario_return.csv file into the
    # m_ScenarioData array. The scenario_return.csv file was generated
    # by taking samples from a normal distribution with alphas as mean,
    # and with covariance matrix from the risk model.
    def ReadScenarioReturn(self):
        filepath = self.m_Datapath + 'scenario_returns.csv'
        if not os.path.isfile(filepath):
            print('Tutorial data file not found: \n' + filepath)
            exit(1)

        with open(filepath, 'r') as ifs:
            for i,line in enumerate(ifs):
                if i >= self.m_ScenarioNum:
                    break
                else:
                    row = line.strip()
                    columns = row.split(',')
                    for j,val in enumerate(columns):
                        self.m_ScenarioData[i][j] = float(val)
