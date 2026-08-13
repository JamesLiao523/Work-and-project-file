/** @file TutorialData.cs
* \brief Contains definitions of the TutorialData class that handles 
* data used for all tutorials.
*/

using System;
using System.IO;

namespace Tutorial_CS
{
    /// Handles data used for all tutorials.
    class TutorialData
    {
        public int m_AccountNum = 3;
	    public int m_AssetNum = 11;
	    public int m_FactorNum = 68;
	    public int m_Taxlots = 39;
        public int m_ScenarioNum = 100;

	    public String m_Datapath;
	    public double[] m_CovData;
	    public double[,] m_ExpData;
        public double[] m_Shortfall_Beta;
        public double[,] m_ScenarioData;

	    //Asset IDs
	    public String[]  m_ID = {"CASH", "USA11I1", "USA13Y1", "USA1LI1", "USA1TY1", "USA2ND1", "USA3351",
		    "USA37C1", "USA39K1", "USA45V1", "USA4GF1"};

	    public String[] m_GICS_Sector = { "", "Financials", "Information Technology", "Information Technology", 
		    "Industrials", "Minerals", "Utilities", "Minerals", "Health Care", "Utilities", "Information Technology"};

        public String[] m_Issuer = {"1", "2", "2", "2", "3", "3", "4", "4", "5", "5", "6"};

	    public String[] m_Factor = {"Factor_1A", "Factor_1B", "Factor_1C", "Factor_1D","Factor_1E","Factor_1F","Factor_1G","Factor_1H",
				      "Factor_2A", "Factor_2B", "Factor_2C", "Factor_2D","Factor_2E","Factor_2F","Factor_2G","Factor_2H",
				      "Factor_3A", "Factor_3B", "Factor_3C", "Factor_3D","Factor_3E","Factor_3F","Factor_3G","Factor_3H",
				      "Factor_4A", "Factor_4B", "Factor_4C", "Factor_4D","Factor_4E","Factor_4F","Factor_4G","Factor_4H",
				      "Factor_5A", "Factor_5B", "Factor_5C", "Factor_5D","Factor_5E","Factor_5F","Factor_5G","Factor_5H",
				      "Factor_6A", "Factor_6B", "Factor_6C", "Factor_6D","Factor_6E","Factor_6F","Factor_6G","Factor_6H",
				      "Factor_7A", "Factor_7B", "Factor_7C", "Factor_7D","Factor_7E","Factor_7F","Factor_7G","Factor_7H",
				      "Factor_8A", "Factor_8B", "Factor_8C", "Factor_8D","Factor_8E","Factor_8F","Factor_8G","Factor_8H",
				      "Factor_9A", "Factor_9B", "Factor_9C", "Factor_9D"};

 	    // Initial weights (holding) for all the assets and cash. Each element should be a decimal instead 
	    // of percent, for example, 30% holding should be entered as 0.3. In this asset array, the first 
	    // item is cash, and only the index 0,1,10 assets have non-zero initial weight. 
		public double[,] m_InitWeight =
				{ // Portfolio 1
				  { 0.000000e+000, 5.605964e-001, 4.394036e-001, 0.000000e+000, 0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000},
				  // Portfolio 2
				  { 0.000000e+000, 0.000000e+000, 2.405964e-001, 7.594036e-001,  0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000},
				  // Portfolio 3
				  { 0.000000e+000, 0.000000e+000, 0.000000e+000, 1.000000e+000, 0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000} };

	    // Benchmark Portofolio Weight
	    public double[] m_BMWeight = {0.0000000, 0.169809, 0.0658566, 0.160816, 0.0989991,
                               0.0776341, 0.0768613, 0.0725244, 0.2774998, 0.0000000,
                               0.0000000};

        // Benchmark 2 Portofolio Weight
	    public double[] m_BM2Weight = {0.0000000, 0.0000000, 0.2500000, 0.0000000, 0.0000000,
                               0.0000000, 0.5000000, 0.0000000, 0.0000000, 0.2500000,
                               0.0000000};  

	    // Specific covariance
	    public double[] m_SpCov = {0.000000e+000, 3.247204e-002, 3.470769e-002, 1.313338e-001, 9.180900e-002,
						    3.059001e-002, 6.996025e-002, 4.507129e-002, 5.225796e-002, 5.631129e-002,
						    7.017201e-002};
    	
	    // Asset Price 
	    public double[] m_Price = {1.00, 23.99, 34.19, 67.24, 375.51, 70.06, 17.48, 17.66, 32.96, 14.73, 34.48};

        public double[] m_Alpha = {0.000000e+000, 1.576034e-002, 2.919658e-003, 6.419658e-003, 4.420342e-003,
								     9.996575e-004, 3.320342e-003, 2.700342e-003, 1.849966e-002, 1.459658e-003,
								     6.079658e-003};

		//Tax lot information
		public int[] m_Account =
			{  0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,
			   1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,
			   2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2 };

		public int[] m_Indices = 
			{  0,		1,		1,		2,		2,		3,		4,		5,		6,		7,		8,		9,		10,
			   0,		1,		2,		2,		3,		3,		4,		5,		6,		7,		8,		9,		10,
			   0,		1,		2,		2,		3,		3,		4,		5,		6,		7,		8,		9,		10};

		public int[] m_Age =
			{  0,	  937,    832,   1641,    295,      0,      0,      0,      0,      0,      0,      0,		0,
			   0,	    0,    512,    435,    295,    937,      0,      0,      0,      0,      0,      0,		0,
			   0,	    0,      0,      0,      0,    937,      0,      0,      0,      0,      0,      0,		0};

		public double[] m_CostBasis = 
			{1.0,   28.22,  25.37,  15.19,  18.90,  67.24, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
			 1.0,   23.99,  26.56,  27.49,  18.90,  32.53, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
			 1.0,   23.99,  26.56,  27.49,  18.90,  32.53, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48};

		public int[] m_Shares = 
			{  0,	   50,     50,     20,     35,      0,       0,      0,     0,      0,      0,      0,     0,
			   0,	    0,     50,     31,    100,     30,       0,      0,     0,      0,      0,      0,     0,
			   0,	    0,      0,      0,      0,    130,       0,      0,     0,      0,      0,      0,     0};

        /// Constructor; Calls ReadCovariance() and ReadExposure().
        public TutorialData()
        {
            String curDir = Directory.GetCurrentDirectory();
            DirectoryInfo pDir1 = Directory.GetParent(curDir);
            m_Datapath = pDir1.ToString();
            int p = (int)Environment.OSVersion.Platform;
            if (p == 4 || p == 6 || p == 128 ) 
    		    m_Datapath += "/tutorial_data/";
	        else
		        m_Datapath += "\\tutorial_data\\";

            ReadCovariance();
            ReadExposure();
            ReadScenarioReturn();
        }


        /// Read from a file the factor covariance data into the m_CovData array
        public void ReadCovariance()
        {
            String filepath = m_Datapath + "cov.txt";
            try
            {
                TextReader tr = new StreamReader(filepath);
                String str;
                int count = 0;
                m_CovData = new double[2500];
                while((str = tr.ReadLine()) != null )
                {
                    str.Trim();
                    if (str.Length != 0 && !str.StartsWith("!"))
                    {
                        String[] din = str.Split(' ');
                        for (int i = 0; i < din.Length; i++)
                        {
                            din[i] = din[i].Trim();
                            if (din[i].Length != 0)
                                m_CovData[count++] = Double.Parse(din[i]);
                        }
                    }
                }
                 tr.Close();
            }
            catch(Exception e)
            {
                Console.WriteLine("Error: {0}", e.Message); 
            }
        }

        /// Read from a file the factor exposure data into the m_ExpData array
        public void ReadExposure()
        {
            //Read asset exposures
            String filepath = m_Datapath + "fx.txt";
            try
            {
                TextReader tr = new StreamReader(filepath);
                m_ExpData = new double[m_AssetNum, m_FactorNum];
                String strLine;
                int assetCount = -1;
                int factorIDcount = 0;
                while ((strLine = tr.ReadLine()) != null)
                {
                    strLine.Trim();
                    if (strLine.Length != 0)
                    {
                        if (!strLine.StartsWith("!"))
                        {
                            String[] din = strLine.Split(' ');
                             for (int i = 0; i < din.Length; i++)
                            {
                                din[i] = din[i].Trim();
                                if (din[i].Length != 0)
                                {
                                    m_ExpData[assetCount,factorIDcount++] = Double.Parse(din[i]);
                                }
                            }
                        }
                        else
                        {
                            assetCount++;
                            factorIDcount = 0;
                        }
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Error: {0}", e.Message);
            }
        }


        /** Read shortfall beta from the sampleTutorial2_assetAttribution.csv file into the 
        *   m_Shortfall_Beta array. The sampleTutorial2_assetAttribution.csv file is the output 
        *   of Barra BxR 1.0 tutorial 2.
        */
        public void ReadShortfallBeta()
	    {
		    // Open the input file from BxR 1.0 tutorial 2
		    String filepath = m_Datapath + "sampleTutorial2_assetAttribution.csv";	

		    try
		    {
                TextReader tr = new StreamReader(filepath);
			    m_Shortfall_Beta = new double[m_AssetNum];

			    // Read shortfall beta data
			    String strLine = tr.ReadLine();			// Skip title line
			    for ( int i=1; i<m_AssetNum; i++ )
			    {
				    strLine = tr.ReadLine();
                    String[] din = strLine.Split(',');
				    m_Shortfall_Beta[i] = Double.Parse(din[5]);
			    }
			    m_Shortfall_Beta[0] = 0.0;				// Cash
		    }
		    catch (Exception e)
		    {
                Console.WriteLine("Error: {0}", e.Message);
		    }
	    }

        /** Read scenario return from the scenario_returns.csv file into the
        *   m_ScenarioReturn array. The scenario_return.csv file was generated
        *   by taking samples from a normal distribution with alphas as mean, and
        *   with covariance matrix from the risk model.
        */
        public void ReadScenarioReturn()
        {
            String filepath = m_Datapath + "scenario_returns.csv";

            try
            {
                TextReader tr = new StreamReader(filepath);
                m_ScenarioData = new double[m_ScenarioNum, m_AssetNum];

                for (int i = 0; i < m_ScenarioNum; i++)
                {
                    String strLine = tr.ReadLine();
                    String[] words = strLine.Split(',');
                    for (int j = 0; j < m_AssetNum; j++)
                    {
                        m_ScenarioData[i, j] = Double.Parse(words[j]);
                    }
                }
            }
            catch (Exception e)
            {
                Console.WriteLine("Error: {0}", e.Message);
            }
        }
    }
 }

