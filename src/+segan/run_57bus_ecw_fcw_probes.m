function probes = run_57bus_ecw_fcw_probes(cfg, inputs)
%RUN_57BUS_ECW_FCW_PROBES Run the fourteen remaining 57-bus screening probes.
%   PROBES = SEGAN.RUN_57BUS_ECW_FCW_PROBES(CFG, INPUTS) freshly solves
%   ECW 0.30 and FCW 0.05 experiments for each of the seven generators.
%   Each probe uses three 30-day seasons (2,160 hours) and is compared
%   against the validated, newly computed Stage 6A CW0 reference.
%
%   Stage 6B CCW responses are loaded only for the side-by-side screening
%   overview. All ECW and FCW dispatches and economics are recalculated.
%   No historical results, old scripts, or publication outputs are used.
%
%   Monetary-unit clarification: DeltaOwnNE90Day is the sum over the
%   ninety simulated days. DeltaOwnNEMeanDaily is the per-day average.
%   This stage does NOT calculate the final published screening ranks.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(cfg, 'paths') || ~isfield(cfg.paths, 'cache') || ...
            ~isfield(inputs, 'Case57') || ~isfield(inputs, 'SeasonalLoad57')
        error('SEGAN:InvalidInput', ...
            'Provide a valid reproduction configuration and Stage 1 inputs.');
    end

    baselineFile = fullfile(cfg.paths.cache, ...
        'segan_57bus_screening_baseline.mat');
    ccwFile = fullfile(cfg.paths.cache, 'segan_57bus_ccw_probes.mat');
    if ~isfile(baselineFile) || ~isfile(ccwFile)
        error('SEGAN:MissingScreeningDependency', ...
            'Complete and validate Stage 6A and Stage 6B first.');
    end
    baseData = load(baselineFile, 'baseline');
    ccwData = load(ccwFile, 'screening');
    if ~isfield(baseData, 'baseline') || ~isfield(ccwData, 'screening')
        error('SEGAN:InvalidScreeningDependency', ...
            'Stage 6A/6B files do not contain their expected variables.');
    end
    baseline = baseData.baseline;
    ccw = ccwData.screening;
    if ~isfield(baseline, 'Validation') || ...
            ~baseline.Validation.AllPassed || ...
            ~isfield(ccw, 'Validation') || ~ccw.Validation.AllPassed
        error('SEGAN:InvalidScreeningDependency', ...
            'Stage 6A/6B publication checks must have passed.');
    end
    if ~isfield(baseline, 'Run') || ...
            ~isfield(baseline.Run, 'GenCoMetrics') || ...
            ~isfield(baseline.Run, 'Economic') || ...
            ~isfield(ccw, 'Comparison')
        error('SEGAN:InvalidScreeningDependency', ...
            'The saved Stage 6A/6B records are incomplete.');
    end

    baseRun = baseline.Run;
    baseGen = baseRun.GenCoMetrics;
    nGen = height(baseGen);
    nDays = cfg.fiftySevenBus.daysPerSeason * ...
        numel(cfg.fiftySevenBus.seasonNames);
    nHours = nDays * cfg.fiftySevenBus.hoursPerDay;
    if nGen ~= 7 || nDays ~= 90 || nHours ~= 2160 || ...
            baseRun.Summary.SolvedHours ~= nHours || ...
            ~isequal(baseGen.GenCo(:), (1:7).')
        error('SEGAN:UnexpectedExperimentDimensions', ...
            'The 57-bus screening experiment must use 7 generators and 90 days.');
    end
    if ~isequal(size(baseRun.Economic.DailyNetEarning), [nDays, nGen])
        error('SEGAN:InvalidBaselineEconomics', ...
            'The Stage 6A daily net-earning matrix has unexpected dimensions.');
    end
    ccwTable = ccw.Comparison;
    if height(ccwTable) ~= nGen || ...
            ~isequal(ccwTable.GenCo(:), (1:7).') || ...
            any(~isfinite(ccwTable.Computed90DayDelta))
        error('SEGAN:InvalidCCWComparison', ...
            'The Stage 6B CCW results are incomplete or misordered.');
    end

    % The original study uses one economic-only and one physical-only
    % candidate probe for each generator, in addition to the completed CCW.
    probeNames = {'ECW', 'FCW'};
    economicLevels = [0.30, 0.00];
    physicalLevels = [0.00, 0.05];
    nTypes = numel(probeNames);
    nProbes = nGen * nTypes;
    probeRuns = cell(nGen, nTypes);

    scenarioIDs = (1:nProbes).';
    genIDs = zeros(nProbes, 1);
    regimes = strings(nProbes, 1);
    ecwLevels = zeros(nProbes, 1);
    fcwLevels = zeros(nProbes, 1);
    solvedHours = zeros(nProbes, 1);
    ownDelta90Day = nan(nProbes, 1);
    ownDeltaMeanDaily = nan(nProbes, 1);
    systemDelta90Day = nan(nProbes, 1);
    meanLMPDelta = nan(nProbes, 1);
    maxLoadingDelta = nan(nProbes, 1);
    accountingPassed = false(nProbes, 1);

    baseSystemNE = sum(baseRun.Economic.DailyNetEarning, 'all');
    fprintf('\n=== SEGAN Stage 6C: 57-bus ECW/FCW screening probes ===\n');
    fprintf('Seven generators x two probe types x %d hours = %d fresh DC-OPF cases.\n', ...
        nHours, nProbes * nHours);
    fprintf('ECW: 0.30 offer markup; FCW: 0.05 capacity derating.\n');
    fprintf('Only the Stage 6A CW0 and Stage 6B CCW records are loaded.\n');
    fprintf('No previous ECW or FCW market-clearing results are loaded.\n\n');

    row = 0;
    for g = 1:nGen
        for j = 1:nTypes
            row = row + 1;
            e = economicLevels(j);
            f = physicalLevels(j);
            fprintf('Probe %02d/%02d: G%d, %s (ECW %.2f; FCW %.2f)\n', ...
                row, nProbes, g, probeNames{j}, e, f);

            % STOREHOURLY=false keeps the required 90-day economic records
            % and summaries without writing redundant hourly OPF arrays.
            newRun = segan.solve_57bus_case(cfg, inputs, g, e, f, false);
            if newRun.Summary.SolvedHours ~= nHours || ...
                    ~isequal(size(newRun.Economic.DailyNetEarning), [nDays, nGen])
                error('SEGAN:IncompleteProbe', ...
                    'Generator G%d %s probe did not complete as expected.', ...
                    g, probeNames{j});
            end

            deltaTotal = newRun.GenCoMetrics.TotalDailyNetEarning(g) - ...
                baseGen.TotalDailyNetEarning(g);
            deltaMean = newRun.GenCoMetrics.MeanDailyNetEarning(g) - ...
                baseGen.MeanDailyNetEarning(g);
            identityError = abs(deltaTotal - nDays * deltaMean);
            tolerance = 1e-6 * max(1, abs(deltaTotal));
            isConsistent = isfinite(deltaTotal) && isfinite(deltaMean) && ...
                identityError <= tolerance;
            if ~isConsistent
                error('SEGAN:EconomicIdentityFailure', ...
                    'G%d %s 90-day and daily net-earning differences disagree.', ...
                    g, probeNames{j});
            end

            genIDs(row) = g;
            regimes(row) = string(probeNames{j});
            ecwLevels(row) = e;
            fcwLevels(row) = f;
            solvedHours(row) = newRun.Summary.SolvedHours;
            ownDelta90Day(row) = deltaTotal;
            ownDeltaMeanDaily(row) = deltaMean;
            systemDelta90Day(row) = ...
                sum(newRun.Economic.DailyNetEarning, 'all') - baseSystemNE;
            meanLMPDelta(row) = ...
                newRun.Summary.MeanLMP - baseRun.Summary.MeanLMP;
            maxLoadingDelta(row) = ...
                newRun.Summary.MaxBranchLoadingPercent - ...
                baseRun.Summary.MaxBranchLoadingPercent;
            accountingPassed(row) = isConsistent;
            probeRuns{g, j} = newRun;

            fprintf(['  Solved %d/%d | Own 90-day NE: %+12.3f | ' ...
                'Mean daily NE: %+10.3f | Mean LMP delta: %+9.5f\n\n'], ...
                solvedHours(row), nHours, deltaTotal, deltaMean, meanLMPDelta(row));
        end
    end

    if any(~isfinite([ownDelta90Day; ownDeltaMeanDaily; ...
            systemDelta90Day; meanLMPDelta; maxLoadingDelta]))
        error('SEGAN:NonfiniteScreeningMetric', ...
            'A screening metric is NaN or infinite.');
    end

    probeSummary = table(scenarioIDs, genIDs, regimes, ecwLevels, ...
        fcwLevels, solvedHours, ownDelta90Day, ownDeltaMeanDaily, ...
        systemDelta90Day, meanLMPDelta, maxLoadingDelta, ...
        accountingPassed, 'VariableNames', ...
        {'ProbeID', 'GenCo', 'Regime', 'ECW', 'FCW', 'SolvedHours', ...
         'DeltaOwnNE90Day', 'DeltaOwnNEMeanDaily', 'DeltaSystemNE90Day', ...
         'DeltaMeanLMP', 'DeltaMaxBranchLoading', 'AccountingPass'});

    ecwRows = strcmp(regimes, 'ECW');
    fcwRows = strcmp(regimes, 'FCW');
    if ~isequal(genIDs(ecwRows), (1:nGen).') || ...
            ~isequal(genIDs(fcwRows), (1:nGen).')
        error('SEGAN:UnexpectedProbeOrdering', ...
            'Probe output rows are not grouped as expected.');
    end

    genCoComparison = table((1:nGen).', baseGen.Bus, ...
        ownDelta90Day(ecwRows), ownDelta90Day(fcwRows), ...
        ccwTable.Computed90DayDelta, ...
        ownDeltaMeanDaily(ecwRows), ownDeltaMeanDaily(fcwRows), ...
        ccwTable.ComputedMeanDailyDelta, ...
        'VariableNames', {'GenCo', 'Bus', 'ECWDelta90Day', ...
        'FCWDelta90Day', 'CCWDelta90Day', 'ECWDeltaMeanDaily', ...
        'FCWDeltaMeanDaily', 'CCWDeltaMeanDaily'});

    allSolved = all(solvedHours == nHours);
    allAccountingValid = all(accountingPassed);
    if ~allSolved || ~allAccountingValid
        error('SEGAN:ProbeValidationFailed', ...
            'At least one ECW/FCW probe failed the completion checks.');
    end

    probes = struct();
    probes.Meta = struct('NumberOfProbes', nProbes, ...
        'HoursPerProbe', nHours, 'SimulatedDays', nDays, ...
        'EconomicProbeMarkup', 0.30, 'PhysicalProbeDerating', 0.05, ...
        'TotalFreshOPFCases', sum(solvedHours), ...
        'SourceBaseline', 'Fresh Stage 6A CW0', ...
        'SourceCCW', 'Fresh Stage 6B CCW', ...
        'RankStatus', 'Not yet computed');
    probes.ProbeRuns = probeRuns;
    probes.ProbeSummary = probeSummary;
    probes.GenCoComparison = genCoComparison;
    probes.Validation = struct('TotalProbes', nProbes, ...
        'SolvedProbes', sum(solvedHours == nHours), ...
        'AccountingChecksPassed', sum(accountingPassed), ...
        'AllPassed', allSolved && allAccountingValid);

    fprintf('Fresh ECW/FCW probes: %d/%d completed.\n', ...
        probes.Validation.SolvedProbes, nProbes);
    fprintf('Daily-to-aggregate accounting checks: %d/%d passed.\n', ...
        probes.Validation.AccountingChecksPassed, nProbes);
    fprintf('Total newly solved DC-OPF cases: %d.\n\n', sum(solvedHours));
    fprintf('Seven-generator comparison (90-day aggregates):\n');
    disp(genCoComparison(:, ...
        {'GenCo','ECWDelta90Day','FCWDelta90Day','CCWDelta90Day'}));

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    destination = fullfile(cfg.paths.cache, ...
        'segan_57bus_ecw_fcw_probes.mat');
    if isfile(destination)
        error('SEGAN:OutputAlreadyExists', ...
            ['The Stage 6C output already exists. Move or remove it ' ...
             'intentionally before rerunning this stage.']);
    end
    save(destination, 'probes', '-v7.3');
    fprintf('Saved: outputs/cache/segan_57bus_ecw_fcw_probes.mat\n');
    fprintf(['No screening ranks or publication tables were generated. ' ...
             'Final rankings require the original full ranking inputs.\n']);
    fprintf('=== SEGAN Stage 6C completed ===\n\n');
end
