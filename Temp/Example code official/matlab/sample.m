% A sample to call Barra Optimizer via SWIG Java API

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
import com.barra.optimizer.*;
COptJavaInterface.Init;

% Create a workspace instance
workspace = CWorkSpace.CreateInstance;

% Create a risk model
rm = workspace.CreateRiskModel('SampleModel',ERiskModelType.eEQUITY);

% Add assets to workspace
for i = 1 : size(data.id,1)
    asset(i) = workspace.CreateAsset(data.id(i), EAssetType.eREGULAR);
    asset(i).SetAlpha(data.alpha(i)); 
    asset(i).SetPrice(data.price(i));   

end

% Set the covariance matrix from data object into the workspace
rm.SetFactorCovariances(data.factor, data.covData(:));

% Set the exposure matrix from data object
for i = 1 : size(data.id,1)

    rm.SetFactorExposuresForAsset(data.id(i), data.factor, data.expData(i, :));
% point-by-point api	
%    for j = 1 : size(data.expData,2)
%        rm.SetFactorExposure(data.id(i),data.factor(j),data.expData(i,j));
%    end
end

% Set the exposure matrix  from data object
assetIDs = repmat(data.id, 1, 3)';
factorIDs = repmat(data.factor, 1, 5);
exposures = data.expData';
rm.SetFactorExposures(assetIDs(:),factorIDs(:),exposures(:));
        
% Set the specific riks covariance matrix from data object
% rm.SetSpecificVariances(data.id, data.speRisk(:));
rm.SetSpecificCovariances(data.id, data.id, data.speRisk(:));

% Create managed, benchmark and universe portfolio
mngPortfolio = workspace.CreatePortfolio(data.mngName);
bmkPortfolio = workspace.CreatePortfolio(data.bmkName);
uniPortfolio = workspace.CreatePortfolio('universePortfolio');

% Set weights to portfolio assets
mngPortfolio.AddAssets(data.id, data.mngWeight(:));
bmkPortfolio.AddAssets(data.id, data.bmkWeight(:));
uniPortfolio.AddAssets(data.id);  % no weight is needed for universe portfolio

% Create a case
testcase = workspace.CreateCase('SampleCase', mngPortfolio, uniPortfolio, basevalue, cashflowweight);

% Initialize constraints
constr = testcase.InitConstraints();
linearConstr = constr.InitLinearConstraints();
for i = 1 : size(data.id,1)
    info = linearConstr.SetAssetRange(data.id(i));
	info.SetLowerBound (data.lB(i));
    info.SetUpperBound (data.uB(i));
end

% Set risk model & term 
testcase.SetPrimaryRiskModel(workspace.GetRiskModel('SampleModel'));
ut = testcase.InitUtility();
ut.SetPrimaryRiskTerm(bmkPortfolio);

solver = workspace.CreateSolver(testcase);

% Uncomment the line below to dump workspace file
% workspace.Serialize('opsdata.wsp')

% Run optimizer
status = solver.Optimize();

if (status.GetStatusCode() == EStatusCode.eOK)
    % Optimization completed
    output = solver.GetPortfolioOutput();
    risk = output.GetRisk();
    utility = output.GetUtility();
    outputPortfolio = output.GetPortfolio();
    assetCount = outputPortfolio.GetAssetCount();

	for i = 1 : size(data.id,1)
        outputWeight(i) = outputPortfolio.GetAssetWeight(data.id(i));	
    end
    % Show results on command window	
    fprintf('Optimization completed\n');
    fprintf('Optimal portfolio risk: %g\n',risk);
    fprintf('Optimal portfolio utility: %g\n',utility);
    for i = 1 : size(data.id,1)
        fprintf('Optimal portfolio weight of asset %s: %g\n',char(data.id(i)),outputWeight(i));
    end
else
    % Optimization error
    fprintf('Optimization error');
end

workspace.Release();
