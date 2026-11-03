function baseline = run_57bus_baseline(cfg, inputs)
%RUN_57BUS_BASELINE Recompute the 2,160-hour CW0 screening reference.
%   BASELINE = SEGAN.RUN_57BUS_BASELINE(CFG, INPUTS) runs fresh DC-OPF
%   solutions for Winter, Summer, and Neutral seasonal demand trajectories.
%   It compares baseline generator metrics with published Table 4 values.
%   The 21 withholding probes and final screening ranks are NOT run here.

    assert(nargin == 2 && isstruct(cfg) && isstruct(inputs) && ...
        isfield(inputs, 'Case57') && isfield(inputs, 'SeasonalLoad57'), ...
        'Pass cfg and the Stage 1 prepared inputs.');
    fprintf('\n=== SEGAN Stage 6A: 57-bus CW0 screening baseline ===\n');
    fprintf('Fresh seasonal DC-OPF cases: 3 seasons x 30 days x 24 hours = 2160\n');
    fprintf('No existing 57-bus OPF or screening results are loaded.\n');
    result = segan.solve_57bus_case(cfg, inputs, [], 0, 0, true);

    % These rounded values come only from the published article (Table 4).
    % They are never inputs to DC-OPF, generator dispatch, or accounting.
    expectedBus = [1;2;3;6;8;9;12];
    expectedPmax = [576;100;140;100;550;100;410];
    expectedMeanPG = [153.5;72.6;47.6;72.6;498.1;72.6;348.5];
    expectedDailyNE = [46315;7252;14372;7252;155159;7252;108005];
    actual = result.GenCoMetrics;
    assert(height(actual) == 7, 'Unexpected generator screening summary length.');
    check = table(actual.GenCo, ...
        expectedBus, actual.Bus, expectedPmax, actual.Pmax, ...
        expectedMeanPG, actual.MeanPG, expectedDailyNE, ...
        actual.MeanDailyNetEarning, ...
        'VariableNames', {'GenCo', 'PublishedBus', 'ComputedBus', ...
        'PublishedPmax', 'ComputedPmax', 'PublishedMeanPG', ...
        'ComputedMeanPG', 'PublishedMeanDailyNE', 'ComputedMeanDailyNE'});
    check.BusPass = check.PublishedBus == check.ComputedBus;
    check.PmaxPass = abs(check.PublishedPmax - check.ComputedPmax) <= 0.51;
    check.MeanPGPass = abs(check.PublishedMeanPG - check.ComputedMeanPG) <= 0.051;
    check.MeanDailyNEPass = abs(check.PublishedMeanDailyNE - ...
        check.ComputedMeanDailyNE) <= 0.51;
    nPassed = sum(check.BusPass) + sum(check.PmaxPass) + ...
        sum(check.MeanPGPass) + sum(check.MeanDailyNEPass);
    nChecks = 4 * height(check);

    baseline = struct();
    baseline.Run = result;
    baseline.Table4BaselineCheck = check;
    baseline.Validation = struct('ChecksPassed', nPassed, ...
        'TotalChecks', nChecks, 'AllPassed', nPassed == nChecks, ...
        'PmaxDisplayToleranceMW', 0.51, ...
        'MeanPGToleranceMW', 0.051, 'DailyNETolerance', 0.51);

    fprintf('\nComputed generator baseline metrics:\n');
    disp(result.GenCoMetrics(:, {'GenCo', 'Bus', 'Pmax', ...
        'MeanPG', 'DispatchShare', 'CapacityUtilization', ...
        'MeanDailyNetEarning'}));
    fprintf('Published Table 4 baseline values: %d/%d checks passed.\n', ...
        nPassed, nChecks);
    if nPassed ~= nChecks
        warning('SEGAN:Table4BaselineMismatch', ...
            'The new baseline differs from published Table 4 values. Inspect the checks.');
        disp(check);
    end

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    save(fullfile(cfg.paths.cache, 'segan_57bus_screening_baseline.mat'), ...
        'baseline', '-v7.3');
    fprintf('Saved fresh baseline: outputs/cache/segan_57bus_screening_baseline.mat\n');
    fprintf('No withholding probes, screening ranks, figures, or tables were generated.\n');
    fprintf('=== SEGAN Stage 6A completed ===\n\n');
end
