// A sample to call Barra Optimizer via C++ API
#include <iostream>
#include "barraopt.h"
using namespace BARRAOPT;
using namespace std;

// Set the covariance matrix covData
double covData[][3] = {
	{0.30, 0.12, 0.03},
	{0.12, 0.25, 0.18},
	{0.03, 0.18, 0.48}
};

// Set the specific covariance matrix speRisk
double speRisk[] = {0.42, 0.64, 0.56, 0.49, 0.36};

// Set the exposure matrix expData
double expData[][3]= {
	{0.4, 0.4, 0.2},
	{0.2, 0.7, 0.1},
	{0.1, 0.3, 0.6},
	{0.0, 1.0, 0.0},
	{0.5, 0.3, 0.2}
};

// Set the factors
const int factor_size = 3;
string factor[] = {"Factor_1A","Factor_1B","Factor_1C"};

// Set the asset IDs
const int id_size = 5;
string id[] = {"USABUY1","FRAAAC1","AUSANL1","USAANY1","UKIBEY1"};

// Set the asset prices
double price[] = {50.10, 35.95, 12.54, 74.25, 36.30};

// Set the asset alpha
double alpha[] = {0.03, 0.11, 0.12, 0.08, 0.06};

// Set the managed portfolio weights
double mngWeight[] = {0.1, 0.3, 0.4, 0.1, 0.1};

// Set the benchmark portfolio weights
double bmkWeight[] = {0.2, 0.2, 0.2, 0.2, 0.2};

// Set the managed portfolio name
string mngName = "ManagedPortfolio";

// Set the benchmark portfolio name
string bmkName = "BenchmarkPortfolio";

// Set constraints
//   Lower bounds
double lB[] = {0.05,0.25,0.30,0.0,0.0};
//   Upper bounds
double uB[] = {0.15,0.35,0.50,0.50,0.50};

// Constants
double basevalue = 1000000.0;
double cashflowweight = 0.0;

int main()
{
	// Create a workspace instance
	CWorkSpace* workspace = CWorkSpace::CreateInstance();

	// Create a risk model
	CRiskModel* rm = workspace->CreateRiskModel("SampleModel", eEQUITY);
	 
	// Add assets to workspace
	for(int i=0; i<id_size; i++){
		CAsset* asset = workspace->CreateAsset(id[i], eREGULAR);
		asset->SetAlpha(alpha[i]); 
		asset->SetPrice(price[i]);   
	};

	// Set the covariance matrix from data object into the workspace
	for(int i=0; i<factor_size; i++)
		for(int j=0; j<factor_size; j++)
			rm->SetFactorCovariance(factor[i], factor[j], covData[i][j]);
	        
	// Set the exposure matrix  from data object
	for(int i=0; i<id_size; i++)
		for(int j=0; j<factor_size; j++)
			rm->SetFactorExposure(id[i],factor[j],expData[i][j]);
	        
	// Set the specific riks covariance matrix from data object
	for(int i=0; i<id_size; i++)
		rm->SetSpecificCovariance(id[i], id[i], speRisk[i]);

	// Create managed, benchmark and universe portfolio
	CPortfolio* mngPortfolio = workspace->CreatePortfolio(mngName);
	CPortfolio* bmkPortfolio = workspace->CreatePortfolio(bmkName);
	CPortfolio* uniPortfolio = workspace->CreatePortfolio("universePortfolio");

	// Set weights to portfolio assets
	for(int i=0; i<id_size; i++){
		mngPortfolio->AddAsset(id[i], mngWeight[i]);
		bmkPortfolio->AddAsset(id[i], bmkWeight[i]);
		uniPortfolio->AddAsset(id[i]);  // no weight is needed for universe portfolio
	};
	// Create a case
	CCase* testcase = workspace->CreateCase("SampleCase", mngPortfolio, uniPortfolio, basevalue, cashflowweight);

	// Initialize constraints
	CConstraints& constr = testcase->InitConstraints();
	CLinearConstraints& linearConstr = constr.InitLinearConstraints();
	for(int i=0; i<id_size; i++){
		CConstraintInfo& info = linearConstr.SetAssetRange(id[i]);
		info.SetLowerBound(lB[i]);
		info.SetUpperBound(uB[i]);
	};

	// Set risk model & risk term
	testcase->SetPrimaryRiskModel(*workspace->GetRiskModel("SampleModel"));
	CUtility& ut = testcase->InitUtility();
	ut.SetPrimaryRiskTerm(bmkPortfolio);

	CSolver* solver = workspace->CreateSolver(*testcase);

	// Uncomment the line below to dump workspace file
	// workspace.Serialize('opsdata.wsp');

	// Run optimizer
	const CStatus& status = solver->Optimize();
	int ret = 0;
	if( status.GetStatusCode() == eOK ){ 
		// Optimization completed
		const CPortfolioOutput* output = solver->GetPortfolioOutput();
		double risk = output->GetRisk();
		double utility = output->GetUtility();
		const CPortfolio& outputPortfolio = output->GetPortfolio();
		int assetCount = outputPortfolio.GetAssetCount();

		double outputWeight[id_size];
		for(int i=0; i<id_size; i++)
			outputWeight[i] = outputPortfolio.GetAssetWeight(id[i]);	
		
		// Show results on command window
		cout<<"Optimization completed"<<endl;
		cout<<"Optimal portfolio risk: "<< risk << endl;
		cout<<"Optimal portfolio utility: " << utility << endl;
		for(int i=0; i<id_size; i++)
			cout<<"Optimal portfolio weight of asset " 
				<< id[i] <<": " 
				<< outputWeight[i]<<endl;
	}else{
		// Optimization error
		cout<<"Optimization error";
		ret = 1;
	};

	workspace->Release();

	return ret;
}

