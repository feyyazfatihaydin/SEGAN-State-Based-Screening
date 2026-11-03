function screening = run_57bus_ccw_probes(cfg, inputs)
%RUN_57BUS_CCW_PROBES Recompute seven 57-bus single-generator CCW probes.
%   SCREENING = SEGAN.RUN_57BUS_CCW_PROBES(CFG, INPUTS) compares fresh
%   90-day, 2,160-hour DC-OPF experiments (one strategic generator at a time)
%   against the locally recomputed Stage 6A CW0 baseline.
%
%   This is an intermediate verification stage, not the complete Table 4
%   generator-ranking procedure. The ECW/FCW probes and final ranks are
%   deliberately reserved for a later stage.
%
%   IMPORTANT UNIT CONVENTION:
%   The published Table 4 CCW response numbers were calculated from the
%   difference of net earnings summed across the 90 simulated days, although
%   the printed column heading uses "$ /day". Both the 90-day total
%   difference and the per-day average difference are reported separately.
%
%   No historical research results, figures, or exported tables are loaded.
%   No existing MATLAB source file is modified.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(cfg, 'paths') || ~isfield(cfg.paths, 'cache')
        error('SEGAN:InvalidInput', 'Pass the reproduction configuration and Stage 1 inputs.');
    end

    baselinePath = fullfile(cfg.paths.cache, 'segan_57bus_screening_baseline.mat');
    if ~isfile(baselinePath)
        error('SEGAN:BaselineNotFound', ...
            'Stage 6A baseline is missing. Run segan.run_57bus_baseline first.');
    end
    loaded = load(baselinePath, 'baseline');
    if ~isfield(loaded, 'baseline')
        error('SEGAN:BaselineInvalid', 'The Stage 6A file has no baseline variable.');
    end
    baseline = loaded.baseline;
    if ~isfield(baseline, 'Run') || ~isfield(baseline, 'Validation') || ...
            ~isfield(baseline.Run, 'GenCoMetrics') || ...
            ~isfield(baseline.Run, 'Summary') || ...
            ~baseline.Validation.AllPassed || ...
            baseline.Run.Summary.SolvedHours ~= 2160
        error('SEGAN:BaselineInvalid', ...
            'The Stage 6A CW0 baseline is incomplete or has failed checks.');
    end

    baselineMetrics = baseline.Run.GenCoMetrics;
    nGen = height(baselineMetrics);
    nDays = cfg.fiftySevenBus.daysPerSeason * ...
        numel(cfg.fiftySevenBus.seasonNames);
    nHours = nDays * cfg.fiftySevenBus.hoursPerDay;
    assert(nGen == 7 && nDays == 90 && nHours == 2160, ...
        'This experiment requires seven generators and 90 simulated days.');
    assert(isequal(baselineMetrics.GenCo(:), (1:7).'), ...
        'Baseline generator identifiers are not in the expected order.');

    economicRatio = 0.30;
    physicalRatio = 0.05;
    publishedDeltaTotal = [176888; -19724; -4777; -19724; ...
                           311825; -19724; 183708];
    deltaTotal = nan(nGen, 1);
    deltaMeanDaily = nan(nGen, 1);
    probeTotal = nan(nGen, 1);
    probeMeanDaily = nan(nGen, 1);
    completedHours = zeros(nGen, 1);
    runs = cell(nGen, 1);

    fprintf('\n=== SEGAN Stage 6B: 57-bus CCW screening probes ===\n');
    fprintf('Probe setting: ECW %.2f, FCW %.2f; strategic generator activated alone.\n', ...
        economicRatio, physicalRatio);
    fprintf('Seven fresh probes x %d seasonal hours = %d planned DC-OPF cases.\n', ...
        nHours, nGen * nHours);
    fprintf('The CW0 reference is the newly computed Stage 6A baseline.\n');
    fprintf('Historical OPF outcomes are not read, and no old source code is used.\n\n');

    for g = 1:nGen
        fprintf('Probe %d/%d: G%d, CCW %.2f/%.2f\n', ...
            g, nGen, g, economicRatio, physicalRatio);
        % STOREHOURLY=false preserves daily accounting without duplicating
        % the large hourly market-clearing arrays in the saved probe file.
        run = segan.solve_57bus_case( ...
            cfg, inputs, g, economicRatio, physicalRatio, false);
        if run.Summary.SolvedHours ~= nHours
            error('SEGAN:ProbeIncomplete', ...
                'G%d solved %d of %d expected hours.', ...
                g, run.Summary.SolvedHours, nHours);
        end
        probeTotal(g) = run.GenCoMetrics.TotalDailyNetEarning(g);
        probeMeanDaily(g) = run.GenCoMetrics.MeanDailyNetEarning(g);
        deltaTotal(g) = probeTotal(g) - ...
            baselineMetrics.TotalDailyNetEarning(g);
        deltaMeanDaily(g) = probeMeanDaily(g) - ...
            baselineMetrics.MeanDailyNetEarning(g);
        completedHours(g) = run.Summary.SolvedHours;
        runs{g} = run;

        % The aggregate and mean views must describe the same 90 days.
        consistencyError = abs(deltaTotal(g) - nDays * deltaMeanDaily(g));
        if consistencyError > 1e-6 * max(1, abs(deltaTotal(g)))
            error('SEGAN:AccountingInconsistent', ...
                'G%d total and mean daily net-earning differences disagree.', g);
        end
        fprintf('  Completed: %d/%d hours | 90-day delta: %+.3f | Mean daily delta: %+.3f\n\n', ...
            completedHours(g), nHours, deltaTotal(g), deltaMeanDaily(g));
    end

    genID = (1:nGen).';
    publishedTolerance = 0.51;  % Nearest whole model-dollar rounding.
    difference = deltaTotal - publishedDeltaTotal;
    passed = abs(difference) <= publishedTolerance;
    comparison = table(genID, baselineMetrics.Bus, publishedDeltaTotal, ...
        deltaTotal, difference, deltaMeanDaily, passed, ...
        'VariableNames', {'GenCo', 'Bus', 'PublishedCCWDelta', ...
        'Computed90DayDelta', 'Difference', 'ComputedMeanDailyDelta', 'Pass'});

    screening = struct();
    screening.Meta = struct( ...
        'ECW', economicRatio, 'FCW', physicalRatio, ...
        'SimulatedDays', nDays, 'HoursPerProbe', nHours, ...
        'NumberOfProbes', nGen, 'SourceBaseline', 'Fresh Stage 6A CW0', ...
        'PublishedDeltaUnitNote', ...
        'Published Table 4 response uses a 90-day aggregate; printed heading says per day.');
    screening.ProbeResults = runs;
    screening.Comparison = comparison;
    screening.Validation = struct('ChecksPassed', sum(passed), ...
        'TotalChecks', nGen, 'AllPassed', all(passed), ...
        'PublishedRoundingTolerance', publishedTolerance);

    fprintf('Published Table 4 CCW response checks: %d/%d passed.\n', ...
        sum(passed), nGen);
    disp(comparison);
    if ~all(passed)
        warning('SEGAN:Table4CCWMismatch', ...
            'At least one CCW response differs from the published values.');
    end
    fprintf(['Unit note: Computed90DayDelta reproduces the published numbers; ' ...
             'ComputedMeanDailyDelta is the 90-day average.\n']);

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    save(fullfile(cfg.paths.cache, 'segan_57bus_ccw_probes.mat'), ...
        'screening', '-v7.3');
    fprintf('Saved: outputs/cache/segan_57bus_ccw_probes.mat\n');
    fprintf('No ECW/FCW probes, ranking, clustering, figures, or tables were generated.\n');
    fprintf('=== SEGAN Stage 6B completed ===\n\n');
end
