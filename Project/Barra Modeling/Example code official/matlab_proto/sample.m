% A sample to call Barra Optimizer via JAVA API

% Set the covariance matrix covData
data.covData = [0.30 0.12 0.03;
                0.12 0.25 0.18;
                0.03 0.18 0.48];

% Set the specific covariance matrix speRisk
data.speRisk = [0.42; 0.64; 0.56; 0.49; 0.36];

% Set the exposure matrix expData
data.expData =[0.4 0.4 0.2;
               0.2 0.7 0.1;
               0.1 0.3 0.6;
               0.0 1.0 0.0;
               0.5 0.3 0.2];

% Set the factors
data.factor = cellstr(['Factor_1A';'Factor_1B';'Factor_1C']);

% Set the asset IDs
data.id = cellstr(['USABUY1';'FRAAAC1';'AUSANL1';'USAANY1';'UKIBEY1']);

% Set the asset prices
data.price = [50.10;35.95;12.54;74.25;36.30];

% Set the asset alpha
data.alpha = [0.03;0.11;0.12;0.08;0.06];

% Set the managed portfolio weights
data.mngWeight = [0.1;0.3;0.4;0.1;0.1];

% Set the benchmark portfolio weights
data.bmkWeight = [0.2;0.2;0.2;0.2;0.2];

% Set the managed portfolio name
data.mngName = 'ManagedPortfolio';

% Set the benchmark portfolio name
data.bmkName = 'BenchmarkPortfolio';

% Set constraints
%   Lower bounds
data.lB = [0.05;0.25;0.30;0.0;0.0];

%   Upper bounds
data.uB = [0.15;0.35;0.50;0.50;0.50];

% Constants
basevalue = 1000000.0;
cashflowweight = 0.0;


% Initialize java optimizer interface
import com.barra.openopt.*;
COptJavaInterface.Init;

workSpace = javaMethod('newBuilder','com.barra.openopt.protobuf$WorkSpace');

% Set risk model data

% Set factor covariances
factorCovariancesBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$FactorCovariances');
for i = 1 : size(data.covData,1)
	for j = 1 : i
		factorCovBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$FactorCovariance');
		factorCovBuilder.setFactorId1(data.factor(i));
		factorCovBuilder.setFactorId2(data.factor(j));
		factorCovBuilder.setValue(data.covData(i,j));
		factorCovariancesBuilder.addCovariance(factorCovBuilder);
	end
end

% Set factor exposures
factorExposuresBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$FactorExposures');
for i = 1 : size(data.id,1)
	factorExposureBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$FactorExposure');
	factorExposureBuilder.setAssetId(data.id(i));
	for j = 1 : size(data.expData,2)
		exposureBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Exposure');
		exposureBuilder.setFactorId(data.factor(j));
		exposureBuilder.setValue(data.expData(i,j));
		factorExposureBuilder.addExposure(exposureBuilder);
	end
	factorExposuresBuilder.addAssetFactorExposure(factorExposureBuilder);
end

% Set specific risk
specificRiskBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$SpecificVariances');
for i = 1 : size(data.speRisk,1)
	speVarBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$SpecificVariance');
	speVarBuilder.setAssetId(data.id(i));
	speVarBuilder.setValue(data.speRisk(i));
	specificRiskBuilder.addSpecificVariance(speVarBuilder);
end
specificRiskBuilder.getSpecificVarianceCount();

riskModels = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RiskModels');
riskModel = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RiskModel');
riskModel.setRiskModelId('SampleModel');
riskModel.setFactorCovariances(factorCovariancesBuilder);
riskModel.setFactorExposures(factorExposuresBuilder);
riskModel.setSpecificVariances(specificRiskBuilder);
riskModels.addRiskmodel(riskModel);
workSpace.setRiskModels(riskModels);

% Set portfolios
portfoliosBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Portfolios');

portfolioBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Portfolio');
portfolioBuilder.setPortfolioId(data.mngName);
for i = 1 : size(data.id,1)
	holdingBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Holding');
	holdingBuilder.setAssetId(data.id(i));
	holdingBuilder.setAmount(data.mngWeight(i));
	portfolioBuilder.addHolding(holdingBuilder);
end
portfoliosBuilder.addPortfolio(portfolioBuilder);

portfolioBuilder2 = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Portfolio');
portfolioBuilder2.setPortfolioId(data.bmkName);
for i = 1 : size(data.id,1)
	holdingBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Holding');
	holdingBuilder.setAssetId(data.id(i));
	holdingBuilder.setAmount(data.bmkWeight(i));
	portfolioBuilder2.addHolding(holdingBuilder);
end
portfoliosBuilder.addPortfolio(portfolioBuilder2);

portfolioBuilder3 = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Portfolio');
portfolioBuilder3.setPortfolioId('universePortfolio');
for i = 1 : size(data.id,1)
	holdingBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Holding');
	holdingBuilder.setAssetId(data.id(i));
	holdingBuilder.setAmount(0);
	portfolioBuilder3.addHolding(holdingBuilder);
end
portfoliosBuilder.addPortfolio(portfolioBuilder3);

workSpace.setPortfolios(portfoliosBuilder);

% set asset attributes
dataBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Data');

attributeBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Attribute');
attributeBuilder.setAttributeId('AssetLowerBound');
doubleAttrType = javaMethod('valueOf','com.barra.openopt.protobuf$AttributeValueType','DOUBLE');
attributeBuilder.setAttributeValueType(doubleAttrType);

for i = 1 : size(data.id,1)
	elementBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Element');
	elementBuilder.setElementId(data.id(i));
	elementBuilder.setDoubleValue(data.lB(i));
	attributeBuilder.addElement(elementBuilder);
end
dataBuilder.addAttribute(attributeBuilder);

attribute2Builder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Attribute');
attribute2Builder.setAttributeId('AssetUpperBound');
attribute2Builder.setAttributeValueType(doubleAttrType);

for i = 1 : size(data.id,1)
	elementBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Element');
	elementBuilder.setElementId(data.id(i));
	elementBuilder.setDoubleValue(data.uB(i));
	attribute2Builder.addElement(elementBuilder);
end
dataBuilder.addAttribute(attribute2Builder);

attribute3Builder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Attribute');
attribute3Builder.setAttributeId('Alpha');
attribute3Builder.setAttributeValueType(doubleAttrType);

for i = 1 : size(data.id,1)
	elementBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Element');
	elementBuilder.setElementId(data.id(i));
	elementBuilder.setDoubleValue(data.alpha(i));
	attribute3Builder.addElement(elementBuilder);
end
dataBuilder.addAttribute(attribute3Builder);

attributeAssignment = javaMethod('newBuilder', 'com.barra.openopt.protobuf$AttributeAssignment');
attributeAssignment.setAlphaAttributeId('Alpha');
dataBuilder.setAttributeAssignment(attributeAssignment);

workSpace.addData(dataBuilder);

% Set rebalance profile
rebalanceProfileBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RebalanceProfile');

% Set asset bounds
assetBoundBuilder =  javaMethod('newBuilder', 'com.barra.openopt.protobuf$AssetBoundInfo');
assetBoundBuilder.setLowerBoundAttributeId('AssetLowerBound');
boundMode = javaMethod('valueOf','com.barra.openopt.protobuf$ERelativeModeType','ABSOLUTE');
assetBoundBuilder.setLowerBoundMode(boundMode);
assetBoundBuilder.setUpperBoundAttributeId('AssetUpperBound');
assetBoundBuilder.setUpperBoundMode(boundMode);

linearConstraintBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$LinearConstraint');
linearConstraintBuilder.setAssetBounds(assetBoundBuilder);

% Set Utility
utilityBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$Utility');

% Set risk term
risktermBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RiskTerm');
risktermBuilder.setBenchmarkPortfolioId(data.bmkName);
utilityBuilder.addRiskTerm(risktermBuilder);

rebalanceProfileBuilder.setUtility(utilityBuilder);
rebalanceProfileBuilder.setRebalanceProfileId('RebalanceProfile1');
rebalanceProfileBuilder.setLinearConstraint(linearConstraintBuilder);

rebalanceProfiles = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RebalanceProfiles');
rebalanceProfiles.addRebalanceProfile(rebalanceProfileBuilder);
workSpace.setRebalanceProfiles(rebalanceProfiles);

% Set rebalance job
rebalanceJobBuilder = javaMethod('newBuilder', 'com.barra.openopt.protobuf$RebalanceJob');
rebalanceJobBuilder.setRebalanceProfileId('RebalanceProfile1');
rebalanceJobBuilder.setInitialPortfolioId(data.mngName);
rebalanceJobBuilder.setPortfolioBaseValue(basevalue);
rebalanceJobBuilder.setCashflowWeight(cashflowweight);
rebalanceJobBuilder.setUniversePortfolioId('universePortfolio');
rebalanceJobBuilder.setPrimaryRiskModelId('SampleModel');
workSpace.setRebalanceJob(rebalanceJobBuilder);

% Serialize to byte array
workSpaceMessage = workSpace.build();
wsByteArray = workSpaceMessage.toByteArray();

% Run optimization
resultByteArray = OpenOptimizer.Run(wsByteArray);

pbResult = javaMethod('parseFrom', 'com.barra.openopt.protobuf$RebalanceResult', resultByteArray);
str = pbResult.toString();
str

java.lang.System.exit(0);
