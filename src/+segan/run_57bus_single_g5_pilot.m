function pilot = run_57bus_single_g5_pilot(cfg, inputs)
%RUN_57BUS_SINGLE_G5_PILOT Recompute and verify one main 57-bus CCW case.
%   PILOT = SEGAN.RUN_57BUS_SINGLE_G5_PILOT(CFG, INPUTS) performs 2,160 new
%   DC-OPF solutions for the Single-G5 CCW 0.30/0.05 experiment. It uses
%   the freshly validated Stage 6A CW0 results solely as a reference.
%   Publication values are read only by the final validation step.
%
%   The complete hourly OPF and daily true-cost accounting records are
%   stored for later construction of the main 57-bus scenario library.
%   No prior published-study results, figures, or tables are loaded.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(cfg, 'paths') || ~isfield(cfg.paths, 'cache') || ...
            ~isfield(inputs, 'Case57')
        error('SEGAN:InvalidInput', ...
            'Pass the reproduction configuration and prepared Stage 1 inputs.');
    end

    baselineFile = fullfile(cfg.paths.cache, ...
        'segan_57bus_screening_baseline.mat');
    probeFile = fullfile(cfg.paths.cache, ...
        'segan_57bus_ccw_probes.mat');
    if ~isfile(baselineFile) || ~isfile(probeFile)
        error('SEGAN:MissingStage6', ...
            'Validated Stage 6A and Stage 6B outputs are required.');
    end
    baseData = load(baselineFile, 'baseline');
    probeData = load(probeFile, 'screening');
    if ~isfield(baseData, 'baseline') || ...
            ~isfield(probeData, 'screening')
        error('SEGAN:InvalidStage6', ...
            'The expected Stage 6A or Stage 6B variable is missing.');
    end
    baseline = baseData.baseline;
    screening = probeData.screening;
    if ~isfield(baseline, 'Validation') || ...
            ~baseline.Validation.AllPassed || ...
            baseline.Run.Summary.SolvedHours ~= 2160 || ...
            ~isfield(screening, 'Validation') || ...
            ~screening.Validation.AllPassed
        error('SEGAN:UnverifiedStage6', ...
            'The Stage 6A/6B result has not passed its validation.');
    end

    strategicGen = cfg.fiftySevenBus.singleGenerator;
    assert(isequal(strategicGen, 5), ...
        'The published Single-G5 pilot requires generator index G5.');
    economicRatio = 0.30;
    physicalRatio = 0.05;

    fprintf('\n=== SEGAN Stage 7A: Single-G5 main-scenario pilot ===\n');
    fprintf('Scenario: CCW 0.30/0.05, strategic set G5.\n');
    fprintf('Fresh seasonal DC-OPF solutions planned: 2160.\n');
    fprintf('Reference: freshly generated and verified Stage 6A CW0.\n');
    fprintf('Full hourly arrays are retained for later feature construction.\n');
    fprintf('No historical study outcomes or publication tables are loaded.\n\n');

    % This is a fresh, complete run; prior Stage 6B probes stored summaries
    % only and are not used as hourly market-clearing observations.
    run = segan.solve_57bus_case(cfg, inputs, strategicGen, ...
        economicRatio, physicalRatio, true);
    assert(run.Summary.SolvedHours == 2160, ...
        'The pilot did not solve all 2,160 hours.');
    assert(isfield(run, 'Hourly') && ...
        isequal(size(run.Hourly.LMP), [2160, 57]) && ...
        isequal(size(run.Hourly.DispatchMW), [2160, 7]) && ...
        isequal(size(run.Hourly.BranchFlowMW), [2160, 80]) && ...
        all(run.Hourly.Success(:)), ...
        'The hourly output arrays are incomplete.');

    % Verify that only G5 is modified and only during the 180 activated
    % seasonal peak hours. True baseline costs are not overwritten.
    active = logical(run.Hourly.ActivePeakHour(:));
    nHours = numel(active);
    nPeakHours = sum(active);
    assert(nPeakHours == 180, ...
        'Expected two peak hours for each of the 90 simulated days.');
    trueCost = inputs.Case57.TrueCost;
    trueA = trueCost.a(:).';
    trueB = trueCost.b(:).';
    basePmax = inputs.Case57.Generator.Pmax(:).';
    basePmin = inputs.Case57.Generator.Pmin(:).';
    expectedA = repmat(trueA, nHours, 1);
    expectedB = repmat(trueB, nHours, 1);
    expectedPmax = repmat(basePmax, nHours, 1);
    expectedA(active, strategicGen) = trueA(strategicGen) * (1 + economicRatio);
    expectedB(active, strategicGen) = trueB(strategicGen) * (1 + economicRatio);
    expectedPmax(active, strategicGen) = max( ...
        basePmax(strategicGen) * (1 - physicalRatio), ...
        basePmin(strategicGen));
    offerError = max([ ...
        max(abs(run.Hourly.ReportedA(:) - expectedA(:))), ...
        max(abs(run.Hourly.ReportedB(:) - expectedB(:))), ...
        max(abs(run.Hourly.ReportedPmaxMW(:) - expectedPmax(:)))]);
    offerTolerance = 1e-9 * max(1, max(abs([expectedA(:); ...
        expectedB(:); expectedPmax(:)])));
    assert(offerError <= offerTolerance, ...
        'Reported offers/capacities differ from the published peak-gating rule.');

    % The strategic economic quantity is summed over all 90 simulated days.
    % Table 7 prints M$/day, but its numeric values are 90-day aggregates.
    baselineNE = sum(baseline.Run.Economic.DailyNetEarning(:, strategicGen));
    pilotNE = sum(run.Economic.DailyNetEarning(:, strategicGen));
    deltaNE = pilotNE - baselineNE;
    deltaMeanLMP = run.Summary.MeanLMP - baseline.Run.Summary.MeanLMP;
    maxLoading = run.Summary.MaxBranchLoadingPercent;

    metrics = struct();
    metrics.BaselineStrategicNE_90Days = baselineNE;
    metrics.PilotStrategicNE_90Days = pilotNE;
    metrics.DeltaStrategicNE_90Days = deltaNE;
    metrics.BaselineStrategicMeanDailyNE = baselineNE / 90;
    metrics.PilotStrategicMeanDailyNE = pilotNE / 90;
    metrics.DeltaMeanLMP = deltaMeanLMP;
    metrics.MaxBranchLoadingPercent = maxLoading;
    metrics.ActivePeakHours = nPeakHours;

    % The published values below serve only as post-computation checks.
    names = ["CW0 strategic NE (million units, 90 days)"; ...
             "CCW strategic NE (million units, 90 days)"; ...
             "Delta strategic NE (million units, 90 days)"; ...
             "Delta mean LMP (units/MWh)"; ...
             "Maximum branch loading (%)"];
    published = [13.964; 14.276; 0.312; 0.406; 59.50];
    computed = [baselineNE / 1e6; pilotNE / 1e6; ...
                deltaNE / 1e6; deltaMeanLMP; maxLoading];
    tolerance = [0.00051; 0.00051; 0.00051; 0.00051; 0.0051];
    difference = computed - published;
    passed = abs(difference) <= tolerance;
    publicationComparison = table(names, published, computed, ...
        difference, tolerance, passed, ...
        'VariableNames', {'Metric', 'Published', 'Computed', ...
        'Difference', 'Tolerance', 'Pass'});

    % Independently cross-check the 90-day net-earning change against the
    % freshly calculated Stage 6B probe. The same OPF case was recomputed.
    probeDelta = screening.Comparison.Computed90DayDelta(strategicGen);
    crossCheckDifference = deltaNE - probeDelta;
    crossCheckTolerance = 0.05;
    crossCheckPassed = abs(crossCheckDifference) <= crossCheckTolerance;

    pilot = struct();
    pilot.Scenario = struct('Name', 'Single_G5_CCW_E0.30_F0.05', ...
        'Regime', 'CCW', 'StrategicGenerators', strategicGen, ...
        'ECW', economicRatio, 'FCW', physicalRatio);
    pilot.Run = run;
    pilot.Metrics = metrics;
    pilot.Table7Comparison = publicationComparison;
    pilot.Validation = struct( ...
        'SolvedHours', run.Summary.SolvedHours, ...
        'PeakHourCount', nPeakHours, ...
        'PeakOfferRulePassed', offerError <= offerTolerance, ...
        'PublishedChecksPassed', sum(passed), ...
        'PublishedChecksTotal', numel(passed), ...
        'Stage6BDeltaDifference', crossCheckDifference, ...
        'Stage6BCrossCheckPassed', crossCheckPassed, ...
        'AllPassed', all(passed) && crossCheckPassed);

    fprintf('\nComputed Single-G5 CCW pilot metrics:\n');
    fprintf('  CW0 strategic net earning (90 days): %.3f model units\n', baselineNE);
    fprintf('  CCW strategic net earning (90 days): %.3f model units\n', pilotNE);
    fprintf('  Delta strategic net earning       : %+.3f model units\n', deltaNE);
    fprintf('  Delta mean LMP                    : %+.6f units/MWh\n', deltaMeanLMP);
    fprintf('  Maximum branch loading           : %.4f %%\n', maxLoading);
    fprintf('  Peak-hour offer checks            : passed (%d hours)\n', nPeakHours);
    disp(publicationComparison);
    fprintf('Published Table 7 pilot checks: %d/%d passed.\n', ...
        sum(passed), numel(passed));
    fprintf('Stage 6B net-earning cross-check difference: %.9f model units.\n', ...
        crossCheckDifference);
    if ~pilot.Validation.AllPassed
        error('SEGAN:Stage7APilotMismatch', ...
            'The pilot validation failed. Results were not saved.');
    end

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    save(fullfile(cfg.paths.cache, 'segan_57bus_single_g5_ccw_pilot.mat'), ...
        'pilot', '-v7.3');
    fprintf('Saved: outputs/cache/segan_57bus_single_g5_ccw_pilot.mat\n');
    fprintf('Unit note: Table 7 net-earning values represent 90-day totals.\n');
    fprintf('No main-scenario library, clustering, figures, or tables were generated.\n');
    fprintf('=== SEGAN Stage 7A completed ===\n\n');
end
