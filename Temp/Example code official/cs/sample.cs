// A sample to call Barra Optimizer via C++ API
using System;

namespace Sample_CS
{
    class Sample
    {
        // Set the factors
        static string[] factor = new string[] { "Factor_1A", "Factor_1B", "Factor_1C" };

        // Set the asset IDs 
        static string[] id = new string[] { "USABUY1", "FRAAAC1", "AUSANL1", "USAANY1", "UKIBEY1" };

        // Set the covariance matrix covData
        static double[,] covData = new double[,]{
	        {0.30, 0.12, 0.03},
	        {0.12, 0.25, 0.18},
	        {0.03, 0.18, 0.48}
        };

        // Set the specific covariance matrix speRisk
        static double[] speRisk = new double[] { 0.42, 0.64, 0.56, 0.49, 0.36 };

        // Set the exposure matrix expData
        static double[,] expData = new double[,]{
	        {0.4, 0.4, 0.2},
	        {0.2, 0.7, 0.1},
	        {0.1, 0.3, 0.6},
	        {0.0, 1.0, 0.0},
	        {0.5, 0.3, 0.2}
        };

        // Set the asset prices
        static double[] price = new double[] { 50.10, 35.95, 12.54, 74.25, 36.30 };

        // Set the asset alpha
        static double[] alpha = new double[] { 0.03, 0.11, 0.12, 0.08, 0.06 };

        // Set the managed portfolio weights
        static double[] mngWeight = new double[] { 0.1, 0.3, 0.4, 0.1, 0.1 };

        // Set the benchmark portfolio weights
        static double[] bmkWeight = new double[] { 0.2, 0.2, 0.2, 0.2, 0.2 };

        // Set the managed portfolio name
        static string mngName = "ManagedPortfolio";

        // Set the benchmark portfolio name
        static string bmkName = "BenchmarkPortfolio";

        // Set constraints
        //   Lower bounds
        static double[] lB = new double[] { 0.05, 0.25, 0.30, 0.0, 0.0 };
        //   Upper bounds
        static double[] uB = new double[] { 0.15, 0.35, 0.50, 0.50, 0.50 };

        // Constants
        const double basevalue = 1000000.0;
        const double cashflowweight = 0.0;

        /// Driver routine that runs each of the tutorials in sequence.
        public static int Main()         
        {
	        // Create a workspace instance
	        CWorkSpace workspace =  CWorkSpace.CreateInstance();

	        // Create a risk model
            CRiskModel rm = workspace.CreateRiskModel("SampleModel", ERiskModelType.eEQUITY);
        	 
	        // Add assets to workspace
	        for(int i=0; i<id.Length; i++){
                CAsset asset = workspace.CreateAsset(id[i], EAssetType.eREGULAR);
		        asset.SetAlpha(alpha[i]); 
		        asset.SetPrice(price[i]);   
	        };

	        // Set the covariance matrix from data object into the workspace
	        for(int i=0; i<factor.Length; i++)
		        for(int j=0; j<factor.Length; j++)
			        rm.SetFactorCovariance(factor[i], factor[j], covData[i,j]);
        	        
	        // Set the exposure matrix  from data object
	        for(int i=0; i<id.Length; i++)
		        for(int j=0; j<factor.Length; j++)
			        rm.SetFactorExposure(id[i],factor[j],expData[i,j]);
        	        
	        // Set the specific riks covariance matrix from data object
	        for(int i=0; i<id.Length; i++)
		        rm.SetSpecificCovariance(id[i], id[i], speRisk[i]);

	        // Create managed, benchmark and universe portfolio
	        CPortfolio mngPortfolio = workspace.CreatePortfolio(mngName);
	        CPortfolio bmkPortfolio = workspace.CreatePortfolio(bmkName);
	        CPortfolio uniPortfolio = workspace.CreatePortfolio("universePortfolio");

	        // Set weights to portfolio assets
	        for(int i=0; i<id.Length; i++){
		        mngPortfolio.AddAsset(id[i], mngWeight[i]);
		        bmkPortfolio.AddAsset(id[i], bmkWeight[i]);
		        uniPortfolio.AddAsset(id[i]);  // no weight is needed for universe portfolio
	        };
	        // Create a case
	        CCase testcase = workspace.CreateCase("SampleCase", mngPortfolio, uniPortfolio, basevalue, cashflowweight);

	        // Initialize constraints
	        CConstraints constr = testcase.InitConstraints();
	        CLinearConstraints linearConstr = constr.InitLinearConstraints();
	        for(int i=0; i<id.Length; i++){
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
	        int ret = 0;
            if (status.GetStatusCode() == EStatusCode.eOK)
            { 
		        // Optimization completed
		        CPortfolioOutput output = solver.GetPortfolioOutput();
		        double risk = output.GetRisk();
		        double utility = output.GetUtility();
		        CPortfolio outputPortfolio = output.GetPortfolio();
		        int assetCount = outputPortfolio.GetAssetCount();

		        double[] outputWeight = new double[id.Length];
		        for(int i=0; i<id.Length; i++)
			        outputWeight[i] = outputPortfolio.GetAssetWeight(id[i]);

                // Show results on command window 
                Console.WriteLine("Optimization completed");
		        Console.WriteLine("Optimal portfolio risk: {0:g6}", risk);
		        Console.WriteLine("Optimal portfolio utility: {0:g6}", utility);
		        for(int i=0; i<id.Length; i++)
			        Console.WriteLine("Optimal portfolio weight of asset {0}: {1:g6}", id[i], outputWeight[i]);
	        }else{
		        // Optimization error
                Console.WriteLine("Optimization error");
		        ret = 1;
	        };

	        workspace.Release();

	        return ret;
        }
    }
}
