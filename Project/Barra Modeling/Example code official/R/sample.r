#
# Sample R language code that calls Barra Optimizer 
#
# run as R CMD BATCH sample.r
# the output is in sample.r.Rout
#
dyn.load(Sys.getenv("BARRAOPT_WRAP"))
source(Sys.getenv("BARRAOPT_WRAP_R"))

ws = CWorkSpace_CreateInstance()

riskModel = CWorkSpace_CreateRiskModel(ws, "BIM", "eEQUITY")

CRiskModel_SetFactorCovariance(riskModel, "GEMM_SIZE", "GEMM_SIZE", 6.485/10000.)
CRiskModel_SetFactorCovariance(riskModel, "GEMM_SUCCESS", "GEMM_SUCCESS", 1.899/10000.)
CRiskModel_SetFactorCovariance(riskModel, "GEMM_SUCCESS", "GEMM_SIZE", 2.308/10000.)

asset = CWorkSpace_CreateAsset(ws, "IBM")
asset = CWorkSpace_CreateAsset(ws, "JAVA")
asset = CWorkSpace_CreateAsset(ws, "GE")

exp1 = CWorkSpace_CreateAttributeSet(ws)
CAttributeSet_Set(exp1, "GEMM_SIZE", 0.615)
CAttributeSet_Set(exp1, "GEMM_SUCCESS", -0.315)

exp2 = CWorkSpace_CreateAttributeSet(ws)
CAttributeSet_Set(exp2, "GEMM_SIZE", -0.173)
CAttributeSet_Set(exp2, "GEMM_SUCCESS", -1.552)

exp3 = CWorkSpace_CreateAttributeSet(ws)
CAttributeSet_Set(exp3, "GEMM_SIZE", 0.477)
CAttributeSet_Set(exp3, "GEMM_SUCCESS", -0.057)

CRiskModel_SetFactorExposureBySet(riskModel, "IBM", exp1)
CRiskModel_SetFactorExposureBySet(riskModel, "JAVA", exp2)
CRiskModel_SetFactorExposureBySet(riskModel, "GE", exp3)

CRiskModel_SetSpecificCovariance(riskModel, "IBM", "IBM", 0.40)
CRiskModel_SetSpecificCovariance(riskModel, "JAVA", "JAVA", 0.35)
CRiskModel_SetSpecificCovariance(riskModel, "GE", "GE", 0.3);

p1 = CWorkSpace_CreatePortfolio(ws, "Portfolio")

CPortfolio_AddAsset(p1, "IBM", 0.2)
CPortfolio_AddAsset(p1, "JAVA", 0.6)
CPortfolio_AddAsset(p1, "GE", 0.2)

CPortfolio_GetAssetCount(p1)

p2 = CWorkSpace_CreatePortfolio(ws, "Universe")

optcase = CWorkSpace_CreateCase(ws, "Case 1", p1, p2, 100000.0, 0.0)

optConst = CCase_InitConstraints(optcase)

linear = CConstraints_InitLinearConstraints(optConst)

info1 = CLinearConstraints_SetAssetRange(linear, "IBM")
CConstraintInfo_SetLowerBound(info1,  0.0);
CConstraintInfo_SetUpperBound(info1,  1.0);

info2 = CLinearConstraints_SetAssetRange(linear, "JAVA")
CConstraintInfo_SetLowerBound(info2,  0.0);
CConstraintInfo_SetUpperBound(info2,  1.0);

info3 = CLinearConstraints_SetAssetRange(linear, "GE")
CConstraintInfo_SetLowerBound(info3,  0.0);
CConstraintInfo_SetUpperBound(info3,  1.0);

CCase_SetPrimaryRiskModel(optcase, riskModel)

util = CCase_InitUtility(optcase)

CUtility_SetPrimaryRiskTerm(util, p2, 0.0075, 0.0075)

solver = CWorkSpace_CreateSolver(ws, optcase)

# Uncomment the statment below to write a workspace file
# CWorkSpace_Serialize(ws, "opsdata.wsp")

status = CSolver_Optimize(solver)

code = CStatus_GetStatusCode(status)
print(code)

msg = CStatus_GetMessage(status)
print(msg)

output = CSolver_GetPortfolioOutput(solver)

CDataPoint_GetRisk(output)

pfOut = CDataPoint_GetPortfolio(output)

CPortfolio_GetAssetCount(pfOut)

w1 = CPortfolio_GetAssetWeight(pfOut, "IBM")

print(w1)

w2 = CPortfolio_GetAssetWeight(pfOut, "JAVA")

print(w2)

w3 = CPortfolio_GetAssetWeight(pfOut, "GE")

print(w3)

CWorkSpace_Release(ws)

q()
