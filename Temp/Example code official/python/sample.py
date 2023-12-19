#!/usr/bin/env python
# A sample to call Barra Optimizer via SWIG C++ API

# Set the covariance matrix covData
covData = [
    [0.30, 0.12, 0.03],
    [0.12, 0.25, 0.18],
    [0.03, 0.18, 0.48],
    ]

# Set the specific covariance matrix speRisk
speRisk = [0.42, 0.64, 0.56, 0.49, 0.36]

# Set the exposure matrix expData
expData =[
    [0.4, 0.4, 0.2],
    [0.2, 0.7, 0.1],
    [0.1, 0.3, 0.6],
    [0.0, 1.0, 0.0],
    [0.5, 0.3, 0.2],
]
# Set the factors
factor = ['Factor_1A','Factor_1B','Factor_1C']

# Set the asset IDs
id = ['USABUY1','FRAAAC1','AUSANL1','USAANY1','UKIBEY1']

# Set the asset prices
price = [50.10, 35.95, 12.54, 74.25, 36.30]

# Set the asset alpha
alpha = [0.03, 0.11, 0.12, 0.08, 0.06]

# Set the managed portfolio weights
mngWeight = [0.1, 0.3, 0.4, 0.1, 0.1]

# Set the benchmark portfolio weights
bmkWeight = [0.2, 0.2, 0.2, 0.2, 0.2]

# Set the managed portfolio name
mngName = 'ManagedPortfolio'

# Set the benchmark portfolio name
bmkName = 'BenchmarkPortfolio'

# Set constraints
#   Lower bounds
lB = [0.05,0.25,0.30,0.0,0.0]
#   Upper bounds
uB = [0.15,0.35,0.50,0.50,0.50]

# Constants
basevalue = 1000000.0
cashflowweight = 0.0

# Initialize java optimizer interface
import barraopt

# Create a workspace instance
workspace = barraopt.CWorkSpace.CreateInstance()

# Create a risk model
rm = workspace.CreateRiskModel('SampleModel',barraopt.eEQUITY);
 
# Add assets to workspace
for i in range(len(id)):
    asset = workspace.CreateAsset(id[i], barraopt.eREGULAR)
    asset.SetAlpha(alpha[i]) 
    asset.SetPrice(price[i])   

# Set the covariance matrix from data object into the workspace
for i in range(len(factor)):
    for j in range(i,len(factor)):
        rm.SetFactorCovariance(factor[i], factor[j], covData[i][j])
        #print(i,j)
        
# Set the exposure matrix from data object
for i in range(len(id)):
    for j in range(len(factor)):
        rm.SetFactorExposure(id[i],factor[j],expData[i][j])
        
# Set the specific riks covariance matrix from data object
for i in range(len(id)):
    rm.SetSpecificCovariance(id[i], id[i], speRisk[i])

# Create managed, benchmark and universe portfolio
mngPortfolio = workspace.CreatePortfolio(mngName)
bmkPortfolio = workspace.CreatePortfolio(bmkName)
uniPortfolio = workspace.CreatePortfolio('universePortfolio')

# Set weights to portfolio assets
for i in range(len(id)):
    mngPortfolio.AddAsset(id[i], mngWeight[i])
    bmkPortfolio.AddAsset(id[i], bmkWeight[i])
    uniPortfolio.AddAsset(id[i])  # no weight is needed for universe portfolio

# Create a case
testcase = workspace.CreateCase('SampleCase', mngPortfolio, uniPortfolio, basevalue, cashflowweight)

# Initialize constraints
constr = testcase.InitConstraints()
linearConstr = constr.InitLinearConstraints()
for i in range(len(id)):
    info = linearConstr.SetAssetRange(id[i])
    info.SetLowerBound (lB[i])
    info.SetUpperBound (uB[i])

# Set risk model & term 
testcase.SetPrimaryRiskModel(workspace.GetRiskModel('SampleModel'));
ut = testcase.InitUtility()
ut.SetPrimaryRiskTerm(bmkPortfolio)

solver = workspace.CreateSolver(testcase)

# Uncomment the line below to dump workspace file
#workspace.Serialize('opsdata.wsp')

# Run optimizer
status = solver.Optimize()

if status.GetStatusCode() == barraopt.eOK: 
    # Optimization completed
    output = solver.GetPortfolioOutput();
    risk = output.GetRisk();
    utility = output.GetUtility();
    outputPortfolio = output.GetPortfolio();
    assetCount = outputPortfolio.GetAssetCount();

    outputWeight = [];
    for i in range(len(id)):
        outputWeight.append(outputPortfolio.GetAssetWeight(id[i]));	

	# Show results on command window
    print('Optimization completed');
    print('Optimal portfolio risk: %g' % risk);
    print('Optimal portfolio utility: %g' % utility);
    for i in range(len(id)):
        print('Optimal portfolio weight of asset %s: %g'% (id[i], outputWeight[i]));
else:
    # Optimization error
    print('Optimization error');

workspace.Release();

