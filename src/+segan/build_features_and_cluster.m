function output = build_features_and_cluster(cfg, inputs, opfOutput, metrics)
%BUILD_FEATURES_AND_CLUSTER Reconstruct the five-bus K=2 state taxonomy.
%   OUTPUT = SEGAN.BUILD_FEATURES_AND_CLUSTER(CFG, INPUTS, OPF, METRICS)
%   uses only the user's newly computed Stages 1-3 results. It generates
%   the hourly feature matrix, performs K-means, names states ex-post, and
%   compares the state signature against the published five-bus Table 5.
%
%   No published reference values are used as inputs to K-means.
%   The 57-bus experiments, figures, and final tables belong to later stages.

    assert(nargin==4 && isstruct(cfg) && ...
        isfield(cfg,'paths') && isfield(cfg.paths,'cache'), ...
        'Pass cfg and newly generated Stage 1-3 outputs.');
    fprintf('\n=== SEGAN Stage 4: Five-bus features and state clustering ===\n');
    fprintf('Building features from new OPF and true-cost accounting outputs.\n');

    featureTable = segan.build_5bus_feature_table(inputs,opfOutput,metrics);
    featureNames = { ...
        'TotalLoad', ...
        'MeanLMP','MaxLMP','MinLMP','StdLMP','LMPSpread', ...
        'TotalPG','MaxPG','MeanPG','StdPG','FocusG3_PG', ...
        'MeanBranchLoading','MaxBranchLoading','P95BranchLoading', ...
        'MeanAbsBranchFlow','MaxAbsBranchFlow', ...
        'SystemRevenue','SystemCost','SystemNetEarning','SystemProfit', ...
        'FocusG3_Revenue','FocusG3_Cost', ...
        'FocusG3_NetEarning','FocusG3_Profit'};
    targetName = 'FocusG3_NetEarning';
    partitions = segan.cluster_operating_states( ...
        featureTable,cfg,featureNames,targetName);
    comparison = segan.compare_5bus_publication_table( ...
        partitions.StateSignature);

    output = struct();
    output.Meta = struct('Stage',4, ...
        'Source','New Stage 2 DC-OPF and Stage 3 true-cost accounting', ...
        'CreatedAt',datetime('now'), ...
        'Scope','Five-bus state partitioning; no publication figures');
    output.FiveBus = partitions;
    output.FiveBus.Table5Comparison = comparison;

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    saveFile = fullfile(cfg.paths.cache,'segan_5bus_clusters.mat');
    save(saveFile,'output','-v7');

    fprintf('Hourly observations: %d\n',height(featureTable));
    fprintf('Active clustering features: %d / %d\n', ...
        numel(partitions.Main.ActiveFeatureNames),numel(featureNames));
    fprintf('Removed zero-variance features: %s\n', ...
        strjoin(partitions.Main.RemovedFeatureNames,', '));
    fprintf('Mean silhouette: %.4f\n',partitions.Main.MeanSilhouette);
    disp(partitions.StateSignature);
    fprintf('Table 5 validation: %d/%d checks passed.\n', ...
        comparison.PassedChecks,comparison.TotalChecks);
    if comparison.AllPass
        fprintf('All published five-bus Table 5 checks are within rounding tolerance.\n');
    else
        fprintf('WARNING: Some published Table 5 checks differ.\n');
        disp(comparison.Details(~comparison.Details.Pass,:));
        fprintf('Review feature choices, source inputs and solver settings before proceeding.\n');
    end
    fprintf('Saved newly generated Stage 4 output: outputs/cache/segan_5bus_clusters.mat\n');
    fprintf('No DC-OPF, economic recomputation, or publication figures were generated.\n');
    fprintf('=== SEGAN Stage 4 completed ===\n\n');
end
