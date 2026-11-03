function clusterResult = cluster_operating_states(featureTable, cfg, featureNames, targetName)
%CLUSTER_OPERATING_STATES Partition hourly records and name states ex-post.
%   RESULT = SEGAN.CLUSTER_OPERATING_STATES(TABLE, CFG, FEATURES, TARGET)
%   standardizes nonconstant features, runs seeded K-means, and assigns the
%   high-profit label only after the unsupervised partition is complete.
%
%   No reference values or publication labels are passed into K-means.
%   The MATLAB Statistics and Machine Learning Toolbox is required.

    if exist('kmeans','file') ~= 2 || exist('statset','file') ~= 2
        error('SEGAN:MissingStatisticsToolbox', ...
            'K-means requires MATLAB Statistics and Machine Learning Toolbox.');
    end
    assert(istable(featureTable) && isstruct(cfg) && ...
        isfield(cfg,'clustering'), 'Feature table and clustering settings are required.');
    assert(iscellstr(featureNames) && ischar(targetName), ...
        'Feature names must be a cell array of character vectors.');
    assert(all(ismember([featureNames,{targetName}], ...
        featureTable.Properties.VariableNames)), ...
        'A requested feature or economic naming target is missing.');

    X = featureTable{:,featureNames};
    valid = all(isfinite(X),2);
    assert(all(valid), 'Five-bus data contain excluded/nonfinite observations.');
    Xvalid = X(valid,:);
    mu = mean(Xvalid,1);
    sigma = std(Xvalid,0,1);
    mask = isfinite(sigma) & sigma > cfg.clustering.zeroVarianceTolerance;
    assert(nnz(mask) >= 2, 'Insufficient nonconstant features for clustering.');
    activeNames = featureNames(mask);
    omittedNames = featureNames(~mask);
    Xstandardized = (Xvalid(:,mask)-mu(mask))./sigma(mask);

    k = 2;
    seed = cfg.clustering.seed;
    replicates = cfg.clustering.replicates;
    maxIter = cfg.clustering.maxIterations;
    oldRng = rng;
    restoreRng = onCleanup(@() rng(oldRng)); %#ok<NASGU>
    rng(seed,'twister');
    options = statset('MaxIter',maxIter,'Display','off');
    [rawLabel,centroids,sumDistances] = kmeans(Xstandardized,k, ...
        'Distance','sqeuclidean','Replicates',replicates,'Options',options);

    economicTarget = featureTable{valid,targetName};
    targetMeans = nan(k,1);
    clusterSizes = zeros(k,1);
    for c = 1:k
        clusterSizes(c) = nnz(rawLabel == c);
        targetMeans(c) = mean(economicTarget(rawLabel == c));
    end
    assert(all(clusterSizes > 0) && all(isfinite(targetMeans)), ...
        'K-means produced an empty or invalid economic state.');
    [~,highCluster] = max(targetMeans);

    assignedID = ones(nnz(valid),1);
    assignedID(rawLabel == highCluster) = 2;
    assignedName = repmat("ModerateStress",nnz(valid),1);
    assignedName(assignedID==2) = "HighProfit";

    featureWithStates = featureTable;
    featureWithStates.RawCluster = nan(height(featureTable),1);
    featureWithStates.StateID = nan(height(featureTable),1);
    featureWithStates.StateName = repmat("Excluded",height(featureTable),1);
    featureWithStates.IsUsedForKMeans = valid;
    featureWithStates.RawCluster(valid) = rawLabel;
    featureWithStates.StateID(valid) = assignedID;
    featureWithStates.StateName(valid) = assignedName;

    % State signatures are computed from actual clustered hourly outputs.
    names = ["ModerateStress";"HighProfit"];
    displayNames = ["Moderate-stress state";"High-profit state"];
    nStates = numel(names);
    counts = zeros(nStates,1);
    shares = zeros(nStates,1);
    meanLMP = nan(nStates,1);
    meanSpread = nan(nStates,1);
    meanMaxLoading = nan(nStates,1);
    targetMean = nan(nStates,1);
    for j = 1:nStates
        use = featureWithStates.StateName == names(j) & valid;
        counts(j) = nnz(use);
        shares(j) = counts(j)/nnz(valid);
        meanLMP(j) = mean(featureTable.MeanLMP(use));
        meanSpread(j) = mean(featureTable.LMPSpread(use));
        meanMaxLoading(j) = mean(featureTable.MaxBranchLoading(use));
        targetMean(j) = mean(featureTable{use,targetName});
    end
    stateSignature = table(displayNames,counts,shares,meanLMP, ...
        meanSpread,meanMaxLoading,targetMean, ...
        'VariableNames',{'State','Observations','Share','MeanLMP', ...
        'LMPSpread','MeanMaxLoading','FocusNetEarningTarget'});

    ids = unique(featureTable.ScenarioID(valid));
    scenarioShare = table(ids,strings(numel(ids),1),zeros(numel(ids),1), ...
        zeros(numel(ids),1),zeros(numel(ids),1), ...
        'VariableNames',{'ScenarioID','Scenario', ...
        'Observations','HighProfitShare','ModerateStateShare'});
    for j = 1:numel(ids)
        subset = valid & featureTable.ScenarioID == ids(j);
        scenarioShare.Scenario(j) = featureTable.ScenarioName(find(subset,1));
        scenarioShare.Observations(j) = nnz(subset);
        scenarioShare.HighProfitShare(j) = mean( ...
            featureWithStates.StateID(subset)==2);
        scenarioShare.ModerateStateShare(j) = mean( ...
            featureWithStates.StateID(subset)==1);
    end

    silhouetteValue = exact_silhouette(Xstandardized,rawLabel);
    clusterResult = struct();
    clusterResult.Main = struct('K',k,'Seed',seed,'Replicates',replicates, ...
        'MaxIterations',maxIter,'Distance','sqeuclidean', ...
        'ZeroVarianceTolerance',cfg.clustering.zeroVarianceTolerance, ...
        'InputFeatureNames',{featureNames}, ...
        'ActiveFeatureNames',{activeNames}, ...
        'RemovedFeatureNames',{omittedNames}, ...
        'FeatureMean',mu(mask),'FeatureStd',sigma(mask), ...
        'NamingTarget',targetName,'HighProfitRawCluster',highCluster, ...
        'RawClusterTargetMeans',targetMeans, ...
        'RawClusterSizes',clusterSizes, ...
        'CentroidsStandardized',centroids,'WithinClusterSumd',sumDistances, ...
        'MeanSilhouette',silhouetteValue);
    clusterResult.FeatureTableWithStates = featureWithStates;
    clusterResult.StandardizedFeatures = Xstandardized;
    clusterResult.StateSignature = stateSignature;
    clusterResult.ScenarioStateShares = scenarioShare;
end

function avg = exact_silhouette(X,labels)
%EXACT_SILHOUETTE Reproduce the study's Euclidean silhouette definition.
    n = size(X,1);
    scores = zeros(n,1);
    classes = unique(labels);
    for i = 1:n
        difference = X-X(i,:);
        distance = sqrt(sum(difference.^2,2));
        own = labels==labels(i);
        own(i) = false;
        if any(own)
            a = mean(distance(own));
        else
            a = 0;
        end
        b = Inf;
        for j = 1:numel(classes)
            if classes(j)==labels(i)
                continue;
            end
            other = labels==classes(j);
            if any(other)
                b = min(b,mean(distance(other)));
            end
        end
        if isinf(b)
            scores(i) = NaN;
        elseif max(a,b)==0
            scores(i) = 0;
        else
            scores(i) = (b-a)/max(a,b);
        end
    end
    avg = mean(scores,'omitnan');
end
