function metrics = compute_economic_network_metrics(cfg, inputs, opfOutput)
%COMPUTE_ECONOMIC_NETWORK_METRICS Analyze fresh five-bus DC-OPF outcomes.
%   METRICS = SEGAN.COMPUTE_ECONOMIC_NETWORK_METRICS(CFG, INPUTS, OPFOUTPUT)
%   computes hourly and daily true-cost accounting, price statistics, and
%   network-utilization summaries for the complete five-bus scenario set.
%
%   It does NOT run OPF, perform clustering, or generate paper figures.
%   It does NOT read historical MATLAB results. OPFOUTPUT must come from
%   the current Stage 2 run. This stage writes a new Stage 3 MAT file.

    if nargin ~= 3 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isstruct(opfOutput) || ~isfield(inputs, 'FiveBus') || ...
            ~all(isfield(opfOutput, {'Results', 'Scenarios', 'Summary'}))
        error('SEGAN:InvalidStage3Input', ...
            'Pass cfg, Stage 1 inputs, and the newly computed Stage 2 output.');
    end

    fiveBus = inputs.FiveBus;
    focusGenerator = fiveBus.CWDesign.FocusGen;
    nScenarios = numel(opfOutput.Results);
    assert(nScenarios == 16 && numel(opfOutput.Scenarios) == 16, ...
        'Expected exactly 16 five-bus scenarios.');
    assert(focusGenerator >= 1 && focusGenerator <= fiveBus.Meta.nGen, ...
        'The focus generator is outside the five-bus generator set.');
    assert(strcmp(opfOutput.Scenarios(1).Name, 'CW0_BASE'), ...
        'The first scenario must be the zero-withholding reference.');

    dailyEconomics = repmat(struct('Scenario', struct(), 'Economics', struct()), ...
        nScenarios, 1);
    scenarioID = (1:nScenarios).';
    scenarioName = strings(nScenarios, 1);
    regime = strings(nScenarios, 1);
    economicRatio = nan(nScenarios, 1);
    physicalRatio = nan(nScenarios, 1);
    solvedHours = zeros(nScenarios, 1);
    meanLMP = nan(nScenarios, 1);
    maxLMP = nan(nScenarios, 1);
    meanLMPSpread = nan(nScenarios, 1);
    meanBranchLoadingPercent = nan(nScenarios, 1);
    maxBranchLoadingPercent = nan(nScenarios, 1);
    meanMaxBranchLoadingPercent = nan(nScenarios, 1);
    bindingBranchObservationShare = nan(nScenarios, 1);
    focusDailyRevenue = nan(nScenarios, 1);
    focusDailyVariableCost = nan(nScenarios, 1);
    focusDailyTotalCost = nan(nScenarios, 1);
    focusDailyNetEarning = nan(nScenarios, 1);
    focusDailyProfit = nan(nScenarios, 1);
    systemDailyRevenue = nan(nScenarios, 1);
    systemDailyTotalCost = nan(nScenarios, 1);
    systemDailyNetEarning = nan(nScenarios, 1);
    systemDailyProfit = nan(nScenarios, 1);
    bindingThresholdPercent = 99.9;

    fprintf('\n=== SEGAN Stage 3: Five-bus true-cost accounting and metrics ===\n');
    fprintf('Reading newly generated Stage 2 OPF outcomes.\n');
    fprintf('No DC-OPF, clustering, figures, or publication tables are generated.\n\n');

    for s = 1:nScenarios
        result = opfOutput.Results(s);
        scenario = opfOutput.Scenarios(s);
        hourly = result.Hourly;
        assert(strcmp(result.Scenario.Name, scenario.Name), ...
            'Stage 2 scenario metadata is inconsistent.');
        assert(isequal(size(hourly.DispatchMW), [24, fiveBus.Meta.nGen]), ...
            'Unexpected 5-bus dispatch matrix shape.');
        assert(isequal(size(hourly.LMP), [24, fiveBus.Meta.nBus]), ...
            'Unexpected 5-bus LMP matrix shape.');
        assert(isequal(size(hourly.BranchLoadingPercent), ...
            [24, fiveBus.Meta.nBranch]), ...
            'Unexpected 5-bus branch loading matrix shape.');
        assert(all(hourly.Success), 'Stage 2 includes an unsuccessful OPF hour.');

        % Reported offers never enter this accounting routine.
        economics = segan.compute_true_cost_accounting( ...
            hourly, fiveBus.TrueCost, fiveBus.Generator.Bus);
        dailyEconomics(s).Scenario = scenario;
        dailyEconomics(s).Economics = economics;

        scenarioName(s) = string(scenario.Name);
        regime(s) = string(scenario.Regime);
        economicRatio(s) = scenario.ECW;
        physicalRatio(s) = scenario.FCW;
        solvedHours(s) = sum(hourly.Success);
        meanLMP(s) = mean(hourly.LMP(:));
        maxLMP(s) = max(hourly.LMP(:));
        meanLMPSpread(s) = mean(max(hourly.LMP, [], 2) ...
                                - min(hourly.LMP, [], 2));
        loading = hourly.BranchLoadingPercent;
        meanBranchLoadingPercent(s) = mean(loading(:));
        maxBranchLoadingPercent(s) = max(loading(:));
        meanMaxBranchLoadingPercent(s) = mean(max(loading, [], 2));
        bindingBranchObservationShare(s) = ...
            mean(loading(:) >= bindingThresholdPercent);

        daily = economics.Daily;
        focusDailyRevenue(s) = daily.Revenue(focusGenerator);
        focusDailyVariableCost(s) = daily.TrueVariableCost(focusGenerator);
        focusDailyTotalCost(s) = daily.TrueTotalCost(focusGenerator);
        focusDailyNetEarning(s) = daily.NetEarning(focusGenerator);
        focusDailyProfit(s) = daily.Profit(focusGenerator);
        systemDailyRevenue(s) = economics.SystemDaily.Revenue;
        systemDailyTotalCost(s) = economics.SystemDaily.TrueTotalCost;
        systemDailyNetEarning(s) = economics.SystemDaily.NetEarning;
        systemDailyProfit(s) = economics.SystemDaily.Profit;

        % A cross-stage consistency check, not a publication-value test.
        idx = find(opfOutput.Summary.ID == scenario.ID, 1);
        assert(~isempty(idx), 'Scenario ID missing from Stage 2 summary.');
        assert(abs(meanLMP(s) - opfOutput.Summary.MeanLMP(idx)) < 1e-8, ...
            'Mean LMP does not match the freshly calculated OPF summary.');
        assert(abs(maxBranchLoadingPercent(s) - ...
            opfOutput.Summary.MaxLoadingPercent(idx)) < 1e-8, ...
            'Branch loading does not match the freshly calculated OPF summary.');

        fprintf('%02d/%02d %-18s | Focus daily NE %12.3f | Focus daily profit %12.3f\n', ...
            s, nScenarios, scenario.Name, focusDailyNetEarning(s), focusDailyProfit(s));
    end

    deltaFocusDailyNetEarningVsCW0 = ...
        focusDailyNetEarning - focusDailyNetEarning(1);
    deltaSystemDailyNetEarningVsCW0 = ...
        systemDailyNetEarning - systemDailyNetEarning(1);

    summary = table(scenarioID, scenarioName, regime, economicRatio, ...
        physicalRatio, solvedHours, meanLMP, maxLMP, meanLMPSpread, ...
        meanBranchLoadingPercent, maxBranchLoadingPercent, ...
        meanMaxBranchLoadingPercent, bindingBranchObservationShare, ...
        focusDailyRevenue, focusDailyVariableCost, focusDailyTotalCost, ...
        focusDailyNetEarning, focusDailyProfit, ...
        deltaFocusDailyNetEarningVsCW0, systemDailyRevenue, ...
        systemDailyTotalCost, systemDailyNetEarning, systemDailyProfit, ...
        deltaSystemDailyNetEarningVsCW0, ...
        'VariableNames', { ...
        'ScenarioID', 'Scenario', 'Regime', 'ECW', 'FCW', 'SolvedHours', ...
        'MeanLMP', 'MaxLMP', 'MeanLMPSpread', ...
        'MeanBranchLoadingPercent', 'MaxBranchLoadingPercent', ...
        'MeanMaxBranchLoadingPercent', 'BindingBranchObservationShare', ...
        'FocusDailyRevenue', 'FocusDailyVariableCost', 'FocusDailyTotalCost', ...
        'FocusDailyNetEarning', 'FocusDailyProfit', ...
        'DeltaFocusDailyNetEarningVsCW0', 'SystemDailyRevenue', ...
        'SystemDailyTotalCost', 'SystemDailyNetEarning', 'SystemDailyProfit', ...
        'DeltaSystemDailyNetEarningVsCW0'});

    assert(all(summary.SolvedHours == 24), ...
        'All five-bus scenario hours must be successfully solved.');
    assert(all(abs(summary.FocusDailyNetEarning - ...
        (summary.FocusDailyRevenue - summary.FocusDailyVariableCost)) < 1e-6), ...
        'Focus generator net-earning identity failed.');
    assert(all(abs(summary.FocusDailyProfit - ...
        (summary.FocusDailyRevenue - summary.FocusDailyTotalCost)) < 1e-6), ...
        'Focus generator profit identity failed.');

    metrics = struct();
    metrics.Meta = struct( ...
        'Stage', 3, ...
        'Description', 'New five-bus true-cost economic and network metrics.', ...
        'CreatedAt', datetime('now'), ...
        'Source', 'Freshly computed Stage 2 DC-OPF outcomes');
    metrics.FiveBus = struct( ...
        'FocusGenerator', focusGenerator, ...
        'Accounting', dailyEconomics, ...
        'ScenarioSummary', summary, ...
        'BindingThresholdPercent', bindingThresholdPercent);

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    saveFile = fullfile(cfg.paths.cache, 'segan_5bus_metrics.mat');
    save(saveFile, 'metrics', '-v7');

    fprintf('\nComputed true-cost accounting for %d scenarios.\n', nScenarios);
    fprintf('Saved new Stage 3 output: outputs/cache/segan_5bus_metrics.mat\n');
    fprintf('=== SEGAN Stage 3 completed ===\n\n');
end
