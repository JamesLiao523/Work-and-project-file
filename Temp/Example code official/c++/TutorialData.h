/** @file TutorialData.h
* \brief Contains declaration of the CTutorialData class
*/

#ifndef TUTORIAL_DATA_H
#define TUTORIAL_DATA_H
#include <string>

/**\brief Handles data used in all tutorials 
*/
class CTutorialData
{
public:
	/// Constructor; Calls SetData(), ReadCovariance() and ReadExposure().
	CTutorialData();

	/// Set hard coded data.
	void SetData();
	
	/// Read factor covariance data from a file
	void ReadCovariance();

	/// Read factor exposure data from a file
	void ReadExposure();

	/// Read shortfall beta from a file
	void ReadShortfallBeta();

	/// Read scenario returns from a file
	void ReadScenarioReturn();

	static const int m_AccountNum = 3;			//!< Number of accounts in the model
	static const int m_AssetNum = 11;			//!< Number of assets in the model
	static const int m_FactorNum = 68;			//!< Number of factors in the model
	static const int m_Taxlots = 39;			//!< Number of taxlots in the model
	static const int m_ScenarioNum = 100;		//!< Number of return scenarios

	std::string m_Datapath;
	const char* m_ID[m_AssetNum];				//!< Asset IDs
	const char* m_Issuer[m_AssetNum];			//!< Issuer IDs
	const char* m_Factor[m_FactorNum];			//!< Factor IDs
	const char* m_GICS_Sector[m_AssetNum];		//!< GiCS sectors
	double m_InitWeight[m_AccountNum][m_AssetNum];	//!< Initial weights
	double m_Alpha[m_AssetNum];					//!< Alphas
	double m_Price[m_AssetNum];					//!< Prices
	double m_BMWeight[m_AssetNum];				//!< Asset weights in the 1st benchmark
	double m_BM2Weight[m_AssetNum];				//!< Asset weights in the 2nd benchmark
	double m_SpCov[m_AssetNum];					//!< Specific covariance
	double m_CovData[2500];						//!< Factor covariance
	double m_ExpData[m_AssetNum][m_FactorNum];	//!< Factor exposures
	double m_Shortfall_Beta[m_AssetNum];		//!< Shortfall beta
	double m_ScenarioData[m_ScenarioNum][m_AssetNum];	//!< Scenario returns

	// tax lot info
	int    m_Account[m_Taxlots];				//!< Account indeces of the taxlots
	int    m_Indices[m_Taxlots];				//!< Asset indices of the taxlots
	int    m_Age[m_Taxlots];					//!< Ages of the taxlots
	int    m_Shares[m_Taxlots];					//!< Shares of the taxlots
	double m_CostBasis[m_Taxlots];				//!< Cost basis of the taxlots
};
#endif
