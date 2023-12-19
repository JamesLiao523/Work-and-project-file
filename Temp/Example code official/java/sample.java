// A sample to call Barra Optimizer via SWIG Java API
import java.io.*;
import java.text.*;
import static java.lang.System.*;
import com.barra.optimizer.*;

public class sample
{
	// Set the factors
	static String[] factor = { "Factor_1A", "Factor_1B", "Factor_1C" };

	// Set the asset IDs
	static String[] id = { "USABUY1", "FRAAAC1", "AUSANL1", "USAANY1", "UKIBEY1" };

	// Set the covariance matrix covData
	static double[] covData = {
		0.30, 0.12, 0.03,
		0.12, 0.25, 0.18,
		0.03, 0.18, 0.48
	};

	// Set the specific covariance matrix speRisk
	static double[] speRisk = { 0.42, 0.64, 0.56, 0.49, 0.36 };

	// Set the exposure matrix expData
	static double[][] expData = {
		{0.4, 0.4, 0.2},
		{0.2, 0.7, 0.1},
		{0.1, 0.3, 0.6},
		{0.0, 1.0, 0.0},
		{0.5, 0.3, 0.2}
	};

	// Set the asset prices
	static double[] price = { 50.10, 35.95, 12.54, 74.25, 36.30 };

	// Set the asset alpha
	static double[] alpha = { 0.03, 0.11, 0.12, 0.08, 0.06 };

	// Set the managed portfolio weights
	static double[] mngWeight = { 0.1, 0.3, 0.4, 0.1, 0.1 };

	// Set the benchmark portfolio weights
	static double[] bmkWeight = { 0.2, 0.2, 0.2, 0.2, 0.2 };

	// Set the managed portfolio name
	static String mngName = "ManagedPortfolio";

	// Set the benchmark portfolio name
	static String bmkName = "BenchmarkPortfolio";

	// Set constraints
	//   Lower bounds
	static double[] lB = { 0.05, 0.25, 0.30, 0.0, 0.0 };
	//   Upper bounds
	static double[] uB = { 0.15, 0.35, 0.50, 0.50, 0.50 };

	// Constants
	static double basevalue = 1000000.0;
	static double cashflowweight = 0.0;

	/// Driver routine that runs each of the tutorials in sequence.
    public static void main(String[] args)
	{
		// Load the Barra Optimizer native C++ library
		COptJavaInterface.Init();		

		// Create a workspace instance
		CWorkSpace workspace =  CWorkSpace.CreateInstance();

		// Create a risk model
		CRiskModel rm = workspace.CreateRiskModel("SampleModel", ERiskModelType.eEQUITY);
		 
		// Add assets to workspace
		for(int i=0; i<id.length; i++){
			CAsset asset = workspace.CreateAsset(id[i], EAssetType.eREGULAR);
			asset.SetAlpha(alpha[i]); 
			asset.SetPrice(price[i]);   
		};

		// Set the covariance matrix from data object using vectorized API
		rm.SetFactorCovariances(factor, covData);
		// Set the covariance matrix from data object using point-by-point API
		//for(int i=0; i<factor.length; i++)
		//	for(int j=0; j<factor.length; j++)
		//		rm.SetFactorCovariance(factor[i], factor[j], covData[i*factor_size+j]);
				
		// Set the exposure matrix from data object
		for(int i=0; i<id.length; i++)
			rm.SetFactorExposuresForAsset(id[i], factor, expData[i]);
			// point-by-point API
			//for(int j=0; j<factor.length; j++)
			//	rm.SetFactorExposure(id[i],factor[j],expData[i][j]);
				
		// Set the specific riks covariance matrix from data object
		rm.SetSpecificCovariances(id, id, speRisk);
		// point-by-point API 
		//for(int i=0; i<id.length; i++)
		//	rm.SetSpecificCovariance(id[i], id[i], speRisk[i]);
	
		// Create managed, benchmark and universe portfolio
		CPortfolio mngPortfolio = workspace.CreatePortfolio(mngName);
		CPortfolio bmkPortfolio = workspace.CreatePortfolio(bmkName);
		CPortfolio uniPortfolio = workspace.CreatePortfolio("universePortfolio");

		// Set weights to portfolio assets	
		mngPortfolio.AddAssets(id, mngWeight);
		bmkPortfolio.AddAssets(id, bmkWeight);
		uniPortfolio.AddAssets(id);  // no weight is needed for universe portfolio
		
		// Create a case
		CCase testcase = workspace.CreateCase("SampleCase", mngPortfolio, uniPortfolio, basevalue, cashflowweight);

		// Initialize constraints
		CConstraints constr = testcase.InitConstraints();
		CLinearConstraints linearConstr = constr.InitLinearConstraints();
		for(int i=0; i<id.length; i++){
			CConstraintInfo info = linearConstr.SetAssetRange(id[i]);
			info.SetLowerBound(lB[i]);
			info.SetUpperBound(uB[i]);
		};

		// Set risk model & term 
		testcase.SetPrimaryRiskModel(workspace.GetRiskModel("SampleModel"));
		CUtility ut = testcase.InitUtility();
		ut.SetPrimaryRiskTerm(bmkPortfolio);

		CSolver solver = workspace.CreateSolver(testcase);

		// Uncomment the line below to dump workspace file
		// workspace.Serialize('opsdata.wsp');

		// Run optimizer
		CStatus status = solver.Optimize();
		
		if (status.GetStatusCode() == EStatusCode.eOK)
		{ 
			// Optimization completed
			CPortfolioOutput output = solver.GetPortfolioOutput();
			double risk = output.GetRisk();
			double utility = output.GetUtility();
			CPortfolio outputPortfolio = output.GetPortfolio();
			int assetCount = outputPortfolio.GetAssetCount();

			double[] outputWeight = new double[id.length];
			for(int i=0; i<id.length; i++)
				outputWeight[i] = outputPortfolio.GetAssetWeight(id[i]);	
			
			// Show results on command window
			System.out.printf("Optimization completed\n");
			System.out.printf("Optimal portfolio risk: %g\n", risk);
			System.out.printf("Optimal portfolio utility: %g\n",utility);
			DecimalFormat f = new DecimalFormat("0.######");
			for(int i=0; i<id.length; i++)
				System.out.printf("Optimal portfolio weight of asset %s: %s\n", 
					id[i], f.format(outputWeight[i]));
		}else{
			// Optimization error
			System.out.println("Optimization error");
		};

		workspace.Release();

	}
}
