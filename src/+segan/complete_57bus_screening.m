function result = complete_57bus_screening(cfg, inputs)
%COMPLETE_57BUS_SCREENING Reconstruct Table 4 generator-screening ranks.
%   RESULT = SEGAN.COMPLETE_57BUS_SCREENING(CFG, INPUTS) combines the
%   freshly computed Stage 6A CW0, Stage 6B CCW, and Stage 6C ECW/FCW
%   outcomes. The original screening rule uses six baseline and six
%   withholding-sensitivity ranks. Reference ranks are compared only after
%   the computational ranking is complete.
%
%   To recover the required 95th-percentile CCW LMPs, only activated peak
%   hours are newly solved. Non-peak observations are copied from the fresh
%   Stage 6A baseline because the study changes reported offers exclusively
%   in the specified peak hours. This avoids rerunning 15,120 OPF cases.
%
%   The printed Table 4 CCW response uses a 90-day aggregate even though
%   its column heading reports dollars per day. Both aggregate and average
%   daily responses are retained here under unambiguous variable names.
%
%   This function does not read historical research outputs or run any
%   published-answer-dependent optimization. No source file is modified.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(cfg, 'paths') || ~isfield(cfg.paths, 'cache') || ...
            ~isfield(inputs, 'Case57') || ~isfield(inputs, 'SeasonalLoad57')
        error('SEGAN:InvalidInput', ...
            'Provide the reproduction configuration and Stage 1 inputs.');
    end
    if exist('rundcopf', 'file') ~= 2 || exist('mpoption', 'file') ~= 2
        error('SEGAN:MissingMATPOWER', 'MATPOWER must be on the MATLAB path.');
    end

    target = fullfile(cfg.paths.cache, 'segan_57bus_screening_ranks.mat');
    if isfile(target)
        error('SEGAN:OutputAlreadyExists', ...
            'Stage 6D output already exists; do not overwrite it implicitly.');
    end
    baseFile = fullfile(cfg.paths.cache, ...
        'segan_57bus_screening_baseline.mat');
    ccwFile = fullfile(cfg.paths.cache, 'segan_57bus_ccw_probes.mat');
    otherFile = fullfile(cfg.paths.cache, ...
        'segan_57bus_ecw_fcw_probes.mat');
    if ~isfile(baseFile) || ~isfile(ccwFile) || ~isfile(otherFile)
        error('SEGAN:MissingStages', 'Run and validate Stages 6A, 6B and 6C first.');
    end
    b = load(baseFile, 'baseline');
    c = load(ccwFile, 'screening');
    e = load(otherFile, 'probes');
    if ~isfield(b, 'baseline') || ~isfield(c, 'screening') || ...
            ~isfield(e, 'probes')
        error('SEGAN:InvalidStages', 'Unexpected variables in stage output files.');
    end
    b = b.baseline;
    c = c.screening;
    e = e.probes;
    if ~b.Validation.AllPassed || ~c.Validation.AllPassed || ...
            ~e.Validation.AllPassed
        error('SEGAN:FailedPrerequisites', ...
            'Stages 6A, 6B and 6C must pass their validation checks.');
    end
    if ~isfield(b.Run, 'Hourly') || ~isfield(b.Run.Hourly, 'LMP') || ...
            ~isfield(c, 'ProbeResults') || ~isfield(e, 'ProbeSummary') || ...
            ~isfield(e, 'GenCoComparison')
        error('SEGAN:IncompleteStages', 'Required screening inputs are missing.');
    end

    define_constants;
    baseRun = b.Run;
    baseG = baseRun.GenCoMetrics;
    ccwRuns = c.ProbeResults;
    ecwFcw = e.GenCoComparison;
    ecwFcwSummary = e.ProbeSummary;
    nGen = height(baseG);
    nBus = inputs.Case57.Meta.nBus;
    seasonNames = cfg.fiftySevenBus.seasonNames;
    nSeasons = numel(seasonNames);
    nDays = cfg.fiftySevenBus.daysPerSeason;
    hoursPerDay = cfg.fiftySevenBus.hoursPerDay;
    nHours = nSeasons * nDays * hoursPerDay;
    nSimDays = nSeasons * nDays;
    baselineLMP = baseRun.Hourly.LMP;
    if nGen ~= 7 || nBus ~= 57 || nSeasons ~= 3 || ...
            nDays ~= 30 || hoursPerDay ~= 24 || nHours ~= 2160 || ...
            ~isequal(size(baselineLMP), [nHours, nBus]) || ...
            any(~isfinite(baselineLMP), 'all') || ...
            numel(ccwRuns) ~= nGen || ...
            height(ecwFcw) ~= nGen || height(ecwFcwSummary) ~= 2*nGen || ...
            ~isequal(baseG.GenCo(:), (1:nGen).') || ...
            ~isequal(ecwFcw.GenCo(:), (1:nGen).')
        error('SEGAN:UnexpectedDimensions', ...
            'The screening data dimensions do not match the published design.');
    end
    baselineP95 = localPercentile(baselineLMP(:), 95);
    baselineSystemTotalNE = sum(baseRun.Economic.DailyNetEarning, 'all');
    ccwP95 = nan(nGen, 1);
    deltaCCWP95 = nan(nGen, 1);
    deltaCCWMeanLMP = nan(nGen, 1);
    deltaCCWSystemNE = nan(nGen, 1);
    meanReconstructionError = nan(nGen, 1);
    newSolvedHours = zeros(nGen, 1);

    case57 = inputs.Case57;
    baseCase = case57.HybridCase;
    oldPD = baseCase.bus(:, PD);
    oldQD = baseCase.bus(:, QD);
    qRatio = zeros(nBus, 1);
    nonzeroLoad = oldPD > 0;
    qRatio(nonzeroLoad) = oldQD(nonzeroLoad) ./ oldPD(nonzeroLoad);
    qRatio(~isfinite(qRatio)) = 0;
    opts = mpoption('verbose', 0, 'out.all', 0, ...
        'opf.dc.solver', cfg.solver.dcSolver);
    nExpectedPeak = nSimDays * 2;

    fprintf('\n=== SEGAN Stage 6D: 57-bus screening ranks ===\n');
    fprintf('Source: validated, newly computed Stage 6A/6B/6C data.\n');
    fprintf('Recovering CCW p95 LMPs using peak-hour-only OPF solutions.\n');
    fprintf('Expected new OPF solutions: %d x %d = %d.\n', ...
        nGen, nExpectedPeak, nGen*nExpectedPeak);
    fprintf('No previous research outputs or publication tables are loaded.\n\n');

    for g = 1:nGen
        run = ccwRuns{g};
        if ~isstruct(run) || ~isfield(run, 'Summary') || ...
                run.Summary.SolvedHours ~= nHours || ...
                ~isfield(run, 'Economic') || ...
                ~isequal(size(run.Economic.DailyNetEarning), [nSimDays, nGen])
            error('SEGAN:IncompleteCCW', 'G%d CCW screening record is invalid.', g);
        end
        if ~isequal(run.Meta.StrategicGenerators, g) || ...
                abs(run.Meta.ECW - 0.30) > 1e-12 || ...
                abs(run.Meta.FCW - 0.05) > 1e-12
            error('SEGAN:UnexpectedCCWCase', ...
                'G%d CCW conditions differ from the published probe.', g);
        end

        reconstructedLMP = baselineLMP;
        scenario = struct('StrategicGenerators', g, 'ECW', 0.30, 'FCW', 0.05);
        for s = 1:nSeasons
            name = seasonNames{s};
            season = inputs.SeasonalLoad57.Seasons.(name);
            loadProfiles = season.LoadBus_day_bus_hour;
            peakHours = season.Meta.PeakHours(:).';
            if ~isequal(size(loadProfiles), [nDays, nBus, hoursPerDay]) || ...
                    numel(peakHours) ~= 2 || ...
                    any(~ismember(peakHours, 1:hoursPerDay))
                error('SEGAN:InvalidSeason', ...
                    'Invalid 57-bus demand window or peak hours for %s.', name);
            end
            for d = 1:nDays
                for h = peakHours
                    hourID = ((s-1)*nDays + d-1)*hoursPerDay + h;
                    caseNow = baseCase;
                    demand = reshape(loadProfiles(d, :, h), [nBus, 1]);
                    caseNow.bus(:, PD) = demand;
                    caseNow.bus(:, QD) = demand .* qRatio;
                    [caseNow, reported] = segan.apply_withholding( ...
                        caseNow, case57.TrueCost, scenario, h, peakHours);
                    if ~reported.ActivePeakHour
                        error('SEGAN:PeakGateMismatch', ...
                            'A designated withholding hour was not activated.');
                    end
                    try
                        solved = rundcopf(caseNow, opts);
                    catch solverError
                        error('SEGAN:PeakSolverError', ...
                            'G%d %s day %d hour %d: %s', ...
                            g, name, d, h, solverError.message);
                    end
                    if ~isfield(solved, 'success') || solved.success ~= 1
                        error('SEGAN:PeakSolverFailed', ...
                            'Unsuccessful G%d CCW OPF at %s day %d hour %d.', ...
                            g, name, d, h);
                    end
                    price = solved.bus(:, LAM_P);
                    if isfinite(cfg.market.lmpCap)
                        price = min(price, cfg.market.lmpCap);
                    end
                    if any(~isfinite(price))
                        error('SEGAN:NonfiniteLMP', ...
                            'Nonfinite CCW nodal price at G%d hour %d.', g, hourID);
                    end
                    reconstructedLMP(hourID, :) = price.';
                    newSolvedHours(g) = newSolvedHours(g) + 1;
                end
            end
        end
        if newSolvedHours(g) ~= nExpectedPeak
            error('SEGAN:IncompletePeakRecon', ...
                'G%d has %d reconstructed peak hours, expected %d.', ...
                g, newSolvedHours(g), nExpectedPeak);
        end

        reconstructedMean = mean(reconstructedLMP, 'all');
        meanReconstructionError(g) = reconstructedMean - run.Summary.MeanLMP;
        if abs(meanReconstructionError(g)) > 0.001
            error('SEGAN:PeakReconstructionMismatch', ...
                ['G%d reconstructed mean LMP differs from the fresh ' ...
                 'Stage 6B result by %.6f. Do not rank these records.'], ...
                g, meanReconstructionError(g));
        end
        ccwP95(g) = localPercentile(reconstructedLMP(:), 95);
        deltaCCWP95(g) = ccwP95(g) - baselineP95;
        deltaCCWMeanLMP(g) = ...
            run.Summary.MeanLMP - baseRun.Summary.MeanLMP;
        deltaCCWSystemNE(g) = ...
            sum(run.Economic.DailyNetEarning, 'all') - baselineSystemTotalNE;

        fprintf('G%d: %d peak OPF solved | CCW p95 LMP = %.6f | ', ...
            g, newSolvedHours(g), ccwP95(g));
        fprintf('mean LMP cross-check difference = %+.8f\n', ...
            meanReconstructionError(g));
    end

    % Reproduce the original, unrounded strict-sort rank rule exactly.
    % Lower rank numbers indicate stronger screening candidates.
    baselineRankInputs = [baseG.Pmax, baseG.MeanPG, ...
        baseG.DispatchShare, baseG.MeanDailyNetEarning, ...
        baseG.PeakMeanPG, baseG.PeakTotalNetEarning];
    baselineComponentRanks = zeros(nGen, 6);
    for j = 1:6
        baselineComponentRanks(:, j) = localOrdinalRank( ...
            baselineRankInputs(:, j), 'descend');
    end
    baselineAverageRank = mean(baselineComponentRanks, 2);

    % Three own-profit responses, plus CCW price and system-wide responses.
    sensitivityRankInputs = [ecwFcw.ECWDelta90Day, ...
        ecwFcw.FCWDelta90Day, ecwFcw.CCWDelta90Day, ...
        deltaCCWMeanLMP, deltaCCWP95, deltaCCWSystemNE];
    sensitivityComponentRanks = zeros(nGen, 6);
    for j = 1:6
        sensitivityComponentRanks(:, j) = localOrdinalRank( ...
            sensitivityRankInputs(:, j), 'descend');
    end
    sensitivityAverageRank = mean(sensitivityComponentRanks, 2);
    overallAverageRank = mean([baselineAverageRank, ...
        sensitivityAverageRank], 2);
    computedRank = localOrdinalRank(overallAverageRank, 'ascend');

    % Published ranks are used only for a post-computation check.
    publishedRank = [2;4;5;6;1;7;3];
    rankMatch = computedRank == publishedRank;
    table4 = table(baseG.GenCo, baseG.Bus, baseG.Pmax, ...
        baseG.MeanPG, baseG.DispatchShare, baseG.CapacityUtilization, ...
        baseG.MeanDailyNetEarning, ecwFcw.CCWDelta90Day, ...
        ecwFcw.CCWDeltaMeanDaily, computedRank, ...
        'VariableNames', {'GenCo', 'Bus', 'Pmax', 'MeanPG', ...
        'DispatchShare', 'CapacityUtilization', 'MeanDailyNetEarning', ...
        'CCWDelta90Day', 'CCWDeltaMeanDaily', 'ScreeningRank'});
    rankDetails = table(baseG.GenCo, baselineAverageRank, ...
        sensitivityAverageRank, overallAverageRank, publishedRank, ...
        computedRank, rankMatch, ...
        'VariableNames', {'GenCo','BaselineAverageRank', ...
        'SensitivityAverageRank','OverallAverageRank', ...
        'PublishedRank','ComputedRank','Pass'});

    p95Checks = all(abs(meanReconstructionError) <= 0.001) && ...
        all(isfinite(ccwP95)) && sum(newSolvedHours) == nGen*nExpectedPeak;
    result = struct();
    result.Table4 = table4;
    result.RankDetails = rankDetails;
    result.BaselineComponentRanks = baselineComponentRanks;
    result.SensitivityComponentRanks = sensitivityComponentRanks;
    result.BaselineP95LMP = baselineP95;
    result.CCWP95LMP = ccwP95;
    result.CCWDeltaP95LMP = deltaCCWP95;
    result.CCWDeltaMeanLMP = deltaCCWMeanLMP;
    result.CCWDeltaSystemNE90Day = deltaCCWSystemNE;
    result.Validation = struct('PeakOPFCases', sum(newSolvedHours), ...
        'PeakReconstructionPassed', p95Checks, ...
        'PublishedRanksMatched', sum(rankMatch), ...
        'TotalPublishedRanks', nGen, ...
        'AllPassed', p95Checks && all(rankMatch));
    result.Meta = struct('Method', 'Original six-plus-six ordinal rank method', ...
        'Source', 'Fresh 6A CW0, 6B CCW, and 6C ECW/FCW', ...
        'PeakOPFCasesPerGenerator', nExpectedPeak, ...
        'PublishedUnitNote', ...
        'CCWDelta90Day is the sum over 90 days, not a per-day average.');

    fprintf('\nFull Table 4 screening calculations:\n');
    disp(table4);
    fprintf('\nRank verification against the published article:\n');
    disp(rankDetails);
    fprintf('Peak-only DC-OPF solutions: %d/%d.\n', ...
        sum(newSolvedHours), nGen*nExpectedPeak);
    fprintf('Published screening ranks: %d/%d matched.\n', ...
        sum(rankMatch), nGen);
    if ~all(rankMatch)
        warning('SEGAN:RankingMismatch', ...
            ['The computed ranking differs from the printed Table 4. ' ...
             'Inspect numerical ties and component ranks before proceeding.']);
    end

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    save(target, 'result', '-v7.3');
    fprintf('Saved: outputs/cache/segan_57bus_screening_ranks.mat\n');
    fprintf('No Figure, table export, or 57-bus scenario library was generated.\n');
    fprintf('=== SEGAN Stage 6D completed ===\n\n');
end

function ranks = localOrdinalRank(values, direction)
%LOCALORDINALRANK Assign strict ordinal ranks using MATLAB sort order.
%   This deliberately does not average, round, or merge nearly tied scores.
    values = values(:);
    if any(~isfinite(values))
        error('SEGAN:InvalidRankInput', ...
            'Nonfinite metrics cannot be used in generator ranking.');
    end
    [~, order] = sort(values, direction);
    ranks = zeros(numel(values), 1);
    ranks(order) = (1:numel(values)).';
end

function q = localPercentile(values, percentile)
%LOCALPERCENTILE Match the original linear interpolation convention.
    values = values(:);
    values = values(isfinite(values));
    if isempty(values)
        error('SEGAN:EmptyPercentileInput', ...
            'Cannot compute the percentile of an empty price vector.');
    end
    values = sort(values);
    n = numel(values);
    if n == 1
        q = values(1);
        return;
    end
    position = 1 + (percentile/100) * (n-1);
    lowerIndex = floor(position);
    upperIndex = ceil(position);
    if lowerIndex == upperIndex
        q = values(lowerIndex);
    else
        q = values(lowerIndex) + ...
            (position - lowerIndex) * (values(upperIndex) - values(lowerIndex));
    end
end
