/** @file TutorialApp.h
* \brief Contains declaration of the CTutorialApp class
*/

#ifndef TUTORIALAPP_H
#define TUTORIALAPP_H

#include "TutorialBase.h"
#include <set>

/**\brief Contains specific code for each of tutorials
*/
class CTutorialApp: public CTutorialBase
{
public:
	CTutorialApp(CTutorialData *data) : CTutorialBase(data) {}

	// basic optimization examples
	void Tutorial_1a();
	void Tutorial_1b();
	void Tutorial_1c();
	void Tutorial_1d();
	void Tutorial_1e();
	void Tutorial_1f();
	void Tutorial_1g();

	// asset class examples
	void Tutorial_2a();
	void Tutorial_2b();
	void Tutorial_2c();

	// linear constraint examples
	void Tutorial_3a();
	void Tutorial_3a2();
	void Tutorial_3b();
	void Tutorial_3c();
	void Tutorial_3c2();
	void Tutorial_3d();
	void Tutorial_3e();
	void Tutorial_3f();
	void Tutorial_3g();
	void Tutorial_3h();
	void Tutorial_3i();
	void Tutorial_3j();

	// paring constraint examples
	void Tutorial_4a();
	void Tutorial_4b();
	void Tutorial_4c();
	void Tutorial_4d();
	void Tutorial_4e();
	void Tutorial_4f();
	void Tutorial_4g();

	// transaction cost examples
	void Tutorial_5a();
	void Tutorial_5b();
	void Tutorial_5c();
	void Tutorial_5d();
	void Tutorial_5e();
	void Tutorial_5f();
	void Tutorial_5g();

	// Penalty examples
	void Tutorial_6a();

	// Risk constraint examples
	void Tutorial_7a();
	void Tutorial_7b();
	void Tutorial_7c();
	void Tutorial_7d();

	void Tutorial_8a();			// long-short (hedge) optimization example
	void Tutorial_8b();			// Short Costs as Single Attribute
	void Tutorial_8c();			// Weighted total leverage constraint
	void Tutorial_8d();

	// Risk/Return target examples
	void Tutorial_9a();
	void Tutorial_9b();

	// tax optimization examples
	void Tutorial_10a();
	void Tutorial_10b();
	void Tutorial_10c();
	void Tutorial_10d();
	void Tutorial_10e();
	void Tutorial_10f();
	void Tutorial_10g();

	void Tutorial_11a();		// Efficient Frontier
	void Tutorial_11b();		// Factor Constraint Frontier
	void Tutorial_11c();		// General Linear Constraint Frontier
	void Tutorial_11d();		// Hedge Constraint Frontier

	void Tutorial_12a();		// Constraint hierarchy

	void Tutorial_14a();		// Shortfall beta

	void Tutorial_15a();		// Minimize risk from 2 risk models 
	void Tutorial_15b();		// Constrain risk from secondary risk model
	void Tutorial_15c();		// Risk parity constraint

	// Additional covariance terms
	void Tutorial_16a();
	void Tutorial_16b();

	void Tutorial_17a();		// Five-Ten-Forty rule

	void Tutorial_18();         //Test factor block

	void Tutorial_19();
	void Tutorial_19b();

	void Tutorial_20();

	void Tutorial_21();
	
	void Tutorial_22();			// Multi-period optimization

	void Tutorial_23();			// Portfolio concentration constraint
	
	void Tutorial_25a();		// Multi-account optimization
	void Tutorial_25b();		// Multi-account tax-aware optimization
	void Tutorial_25c();		// Multi-account optimization with tax arbitrage
	void Tutorial_25d();		// Multi-account optimization with tax harvesting
	void Tutorial_25e();		// Multi-account optimization with account groups

	void Tutorial_26();			// Issuer constraints

	void Tutorial_27a();		// Expected Shortfall term
	void Tutorial_27b();		// Expected Shortfall constraint

	// ratio constraint examples
	void Tutorial_28a();		// General ratio constraints
	void Tutorial_28b();		// Group ratio constraints

	void Tutorial_29();			// General quadratic constraints

	//
	// tutorial wrapper for dumping workspace
	//
	inline void Initialize( const char* tutorialID, const char* description, bool setAlpha=false, bool isTaxAware=false)	{
		CTutorialBase::Initialize(tutorialID, description, dumpWorkspace(tutorialID), setAlpha, isTaxAware);
	}

	void printRisksByAsset(const CPortfolio& portfolio);

	// Parses command line and set up dump tutorial ID & compatible mode
	void ParseCommandLine(int argc, char *argv[]);

protected:

	inline bool dumpWorkspace(const char *tid){
		return m_DumpTID.find(tid)!=m_DumpTID.end();
	};

	inline void SetupDumpFile(const char* tutorialID) { 
		CTutorialBase::SetupDumpFile(tutorialID, dumpWorkspace(tutorialID)); 
	}

	void PrintParingConstraints(const CParingConstraints& paring);
	void PrintConstraintPriority(const CConstraintHierarchy& hier);
	void PrintLowerAndUpperBounds(CLinearConstraints& cons);
	void PrintLowerAndUpperBounds(CHedgeConstraints& cons);

	set<string> m_DumpTID;
};
#endif

