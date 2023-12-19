/** @file TutorialData.cpp
* \brief Contains definitions of the CTutorialData class that handles 
* data used for all tutorials.
*/

#include "TutorialData.h"
#include <stdlib.h>
#include <iostream>
#include <fstream>
#include <sstream>
#include <cstring>

using namespace std;

/// Constructor; Calls SetData(), ReadCovariance() and ReadExposure().
CTutorialData::CTutorialData()
{
	// Assumes that the tutorial data files are in the "../tutorial_data/" folder.
	#ifdef WIN32
	const char slash = '\\';
	#else
	const char slash = '/';
	#endif
	m_Datapath = string("..") + slash + "tutorial_data" + slash;
	
	SetData();
	ReadCovariance();
	ReadExposure();
	ReadScenarioReturn();
}

/// Set hard coded data.
void CTutorialData::SetData()
{
	//Asset IDs
	const char*  id[] = {"CASH", "USA11I1", "USA13Y1", "USA1LI1", "USA1TY1", "USA2ND1", "USA3351",
		"USA37C1", "USA39K1", "USA45V1", "USA4GF1"};

	const char* GICS_Sector[] = { "", "Financials", "Information Technology", "Information Technology", 
		"Industrials", "Minerals", "Utilities", "Minerals", "Health Care", "Utilities", "Information Technology"};

	const char*  issuer[] = {"1", "2", "2", "2", "3", "3", "4", "4", "5", "5", "6"};

	const char* factor[] = {
				  "Factor_1A", "Factor_1B", "Factor_1C", "Factor_1D","Factor_1E","Factor_1F","Factor_1G","Factor_1H",
				  "Factor_2A", "Factor_2B", "Factor_2C", "Factor_2D","Factor_2E","Factor_2F","Factor_2G","Factor_2H",
				  "Factor_3A", "Factor_3B", "Factor_3C", "Factor_3D","Factor_3E","Factor_3F","Factor_3G","Factor_3H",
				  "Factor_4A", "Factor_4B", "Factor_4C", "Factor_4D","Factor_4E","Factor_4F","Factor_4G","Factor_4H",
				  "Factor_5A", "Factor_5B", "Factor_5C", "Factor_5D","Factor_5E","Factor_5F","Factor_5G","Factor_5H",
				  "Factor_6A", "Factor_6B", "Factor_6C", "Factor_6D","Factor_6E","Factor_6F","Factor_6G","Factor_6H",
				  "Factor_7A", "Factor_7B", "Factor_7C", "Factor_7D","Factor_7E","Factor_7F","Factor_7G","Factor_7H",
				  "Factor_8A", "Factor_8B", "Factor_8C", "Factor_8D","Factor_8E","Factor_8F","Factor_8G","Factor_8H",
				  "Factor_9A", "Factor_9B", "Factor_9C", "Factor_9D"
	};

	// Initial weights (holding) for all the assets and cash. Each element should be a
	// decimal instead of percentage, for example, 30% holding should be entered as 0.3.
	// In this asset array, the first item is cash, and only the index 0,1,10 assets 
	// have non-zero initial weight. 
	double initWeight[][m_AssetNum] =
				{ // Portfolio 1
				  { 0.000000e+000, 5.605964e-001, 4.394036e-001, 0.000000e+000, 0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000},
				  // Portfolio 2
				  { 0.000000e+000, 0.000000e+000, 2.405964e-001, 7.594036e-001,  0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000},
				  // Portfolio 3
				  { 0.000000e+000, 0.000000e+000, 0.000000e+000, 1.000000e+000,  0.000000e+000,
					0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000, 0.000000e+000,
					0.000000e+000} };

	// Benchmark Portofolio Weight
	double bmWeight[] = { 0.0000000, 0.169809, 0.0658566, 0.160816, 0.0989991,
                          0.0776341, 0.0768613, 0.0725244, 0.2774998, 0.0000000,
                          0.0000000};  

	// Benchmark 2 Portofolio Weight
	double bm2Weight[] = {0.0000000, 0.0000000, 0.2500000, 0.0000000, 0.0000000,
                           0.0000000, 0.5000000, 0.0000000, 0.0000000, 0.2500000,
                           0.0000000};  

	// Specific covariance
	double spCov[] = { 0.000000e+000, 3.247204e-002, 3.470769e-002, 1.313338e-001, 9.180900e-002,
						3.059001e-002, 6.996025e-002, 4.507129e-002, 5.225796e-002, 5.631129e-002,
						7.017201e-002};
	
	double price[] = {1.00, 23.99, 34.19, 67.24, 375.51, 70.06, 17.48, 17.66, 32.96, 14.73, 34.48};

	double alpha[] = {0.000000e+000, 1.576034e-002, 2.919658e-003, 6.419658e-003, 4.420342e-003,
					  9.996575e-004, 3.320342e-003, 2.700342e-003, 1.849966e-002, 1.459658e-003,
					  6.079658e-003};

	//Tax lot information
	int account[m_Taxlots] =
		{  0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,		0,
		   1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,		1,
		   2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2,		2 };

	int indices[m_Taxlots] = 
		{  0,		1,		1,		2,		2,		3,		4,		5,		6,		7,		8,		9,		10,
		   0,		1,		2,		2,		3,		3,		4,		5,		6,		7,		8,		9,		10,
		   0,		1,		2,		2,		3,		3,		4,		5,		6,		7,		8,		9,		10};

	int age[m_Taxlots] =
		{  0,	  937,    832,   1641,    295,      0,      0,      0,      0,      0,      0,      0,		0,
		   0,	    0,    512,    435,    295,    937,      0,      0,      0,      0,      0,      0,		0,
		   0,	    0,      0,      0,      0,    937,      0,      0,      0,      0,      0,      0,		0};

	double costBasis[m_Taxlots] = 
		{1.0,   28.22,  25.37,  15.19,  18.90,  67.24, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
		 1.0,   23.99,  26.56,  27.49,  18.90,  32.53, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48,
		 1.0,   23.99,  26.56,  27.49,  18.90,  32.53, 375.51,  70.06,  17.48,  17.66,  32.96,  14.73,  34.48};

	int shares[m_Taxlots] = 
		{  0,	   50,     50,     20,     35,      0,       0,      0,     0,      0,      0,      0,     0,
		   0,	    0,     50,     31,    100,     30,       0,      0,     0,      0,      0,      0,     0,
		   0,	    0,      0,      0,      0,    130,       0,      0,     0,      0,      0,      0,     0};

	// Copy the static data to the class member arrays
	memcpy(m_ID, id, m_AssetNum*sizeof(char*));
	memcpy(m_Factor, factor, m_FactorNum*sizeof(char*));
	memcpy(m_InitWeight, initWeight, m_AccountNum*m_AssetNum*sizeof(double));
	memcpy(m_BM2Weight, bm2Weight, m_AssetNum*sizeof(double));
	memcpy(m_BMWeight, bmWeight, m_AssetNum*sizeof(double));
	memcpy(m_GICS_Sector, GICS_Sector, m_AssetNum*sizeof(char*));
	memcpy(m_Alpha, alpha, m_AssetNum*sizeof(double));
	memcpy(m_Price, price, m_AssetNum*sizeof(double));
	memcpy(m_SpCov, spCov, m_AssetNum*sizeof(double));
	memcpy(m_Account, account, m_Taxlots*sizeof(int));
	memcpy(m_Indices, indices, m_Taxlots*sizeof(int));
	memcpy(m_Age, age, m_Taxlots*sizeof(int));
	memcpy(m_Shares, shares, m_Taxlots*sizeof(int));
	memcpy(m_CostBasis, costBasis, m_Taxlots*sizeof(double));
	memcpy(m_Issuer, issuer, m_AssetNum*sizeof(char*));
}

/// Read from a file the factor covariance data into the m_CovData array
void CTutorialData::ReadCovariance()
{
	// Read covariance matrix
	string filepath = m_Datapath + "cov.txt";
	ifstream ifs;
	ifs.open(filepath.c_str());
	if(!ifs.is_open()) {
		cout << "Tutorial data file not found: " << endl << filepath;
		exit(1);
	}

	// Skip all the comment line started with '!' at the beginning
	while(ifs.peek() == '!') 
		ifs.ignore(1024, '\n');

	// Only need to set the half of the matrix because it is symmetrical
	// set the lower half in this case
	int count = 0;
	for(int i=0; i<m_FactorNum; i++) {
		for(int j=0; j<=i; j++) 
			ifs >> m_CovData[count++];
	}
}

/// Read from a file the factor exposure data into the m_ExpData array
void CTutorialData::ReadExposure()
{
	//Read asset exposures
	string filepath = m_Datapath + "fx.txt";
	ifstream ifs;
	ifs.open(filepath.c_str());
	if(!ifs.is_open()) {
		cout << "Tutorial data file not found: " << endl << filepath;
		exit(1);
	}

	for (int i=0; i<m_AssetNum; i++) {
		while (ifs.peek() == '!' || ifs.peek() == '\n') 
			ifs.ignore(1024, '\n');

		for (int j=0; j<m_FactorNum; j++) 
			ifs >> m_ExpData[i][j];
	}
}

/** Read shortfall beta from the sampleTutorial2_assetAttribution.csv file into the 
*   m_Shortfall_Beta array. The sampleTutorial2_assetAttribution.csv file is the output 
*   of Barra BxR 1.0 tutorial 2.
*/
void CTutorialData::ReadShortfallBeta()
{
	string filepath = m_Datapath + "sampleTutorial2_assetAttribution.csv";

	ifstream ifs;
	ifs.open(filepath.c_str());
	if(!ifs.is_open()) {
		cout << "Tutorial data file not found: " << endl << filepath;
		exit(1);
	}

	// Read shortfall beta data
	string buf;
	getline( ifs, buf );					// skip the tilte line
	for ( int i=1; i<m_AssetNum; i++ ) {
		getline( ifs, buf );

		// search for the 5th ',' 
		size_t pos = 0;
		for ( int k=0; k<5; k++ )
			pos = buf.find(',', pos+1);
		size_t dataLen = buf.find(',', pos+1) - pos;

		m_Shortfall_Beta[i] = atof( buf.substr(pos+1, dataLen).c_str() );
	}
	m_Shortfall_Beta[0] = 0.;				// Cash
}

/** Read scenario return from the scenario_returns.csv file into the
*   m_ScenarioReturn array. The scenario_return.csv file was generated
*   by taking samples from a normal distribution with alphas as mean, and
*   with covariance matrix from the risk model.
*/
void CTutorialData::ReadScenarioReturn()
{
	string filepath = m_Datapath + "scenario_returns.csv";

	ifstream ifs;
	ifs.open(filepath.c_str());
	if (!ifs.is_open()) {
		cout << "Tutorial data file not found: " << endl << filepath;
		exit(1);
	}

	// Read scenario return data
	string line, word;
	for (int i = 0; i < m_ScenarioNum; i++) {
		getline(ifs, line);
		stringstream s(line);
		for (int j = 0; j < m_AssetNum; j++) {
			getline(s, word, ',');
			m_ScenarioData[i][j] = atof(word.c_str());
		}
	}
}
