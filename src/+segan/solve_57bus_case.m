function result = solve_57bus_case(cfg, inputs, strategicGenerators, economicRatio, physicalRatio, storeHourly)
%SOLVE_57BUS_CASE Recompute one seasonal 57-bus DC-OPF experiment from inputs.
%   RESULT = SEGAN.SOLVE_57BUS_CASE(CFG, INPUTS, GENERATORS, E, F, STOREHOURLY)
%   uses the newly prepared MATPOWER/PGLib hybrid network and all 90 days of
%   seasonal demand. Withholding affects reported offers at each season's two
%   peak hours. Ex-post economic accounting always uses baseline true costs.
%
%   This function never loads previous OPF, economic, or clustering outputs.
%   STOREHOURLY controls the retention of detailed hourly arrays; daily and
%   generator summaries are always calculated. No figures are generated.

    if nargin ~= 6 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(inputs, 'Case57') || ~isfield(inputs, 'SeasonalLoad57')
        error('SEGAN:InvalidInput', 'Pass the configuration and prepared Stage 1 inputs.');
    end
    if exist('rundcopf', 'file') ~= 2 || exist('mpoption', 'file') ~= 2
        error('SEGAN:MissingMATPOWER', 'MATPOWER must be on the MATLAB path.');
    end
    assert(islogical(storeHourly) && isscalar(storeHourly), ...
        'STOREHOURLY must be a logical scalar.');
    assert(isnumeric(economicRatio) && isscalar(economicRatio) && ...
        isfinite(economicRatio) && economicRatio >= 0, 'Invalid economic ratio.');
    assert(isnumeric(physicalRatio) && isscalar(physicalRatio) && ...
        isfinite(physicalRatio) && physicalRatio >= 0 && physicalRatio < 1, ...
        'Invalid physical ratio.');

    define_constants;
    case57 = inputs.Case57;
    seasonal = inputs.SeasonalLoad57;
    baseCase = case57.HybridCase;
    nGen = case57.Meta.nGen;
    nBus = case57.Meta.nBus;
    nBranch = case57.Meta.nBranch;
    genBus = case57.Generator.Bus(:);
    trueA = case57.TrueCost.a(:);
    trueB = case57.TrueCost.b(:);
    fixedCost = case57.TrueCost.Fcost(:);
    pmax = case57.Generator.Pmax(:);
    pmin = case57.Generator.Pmin(:);
    branchRates = case57.Branch.RateA(:);
    seasonNames = seasonal.Meta.SeasonNames;
    nDays = seasonal.Meta.nDays;
    hoursPerDay = seasonal.Meta.nHours;
    nSeasons = numel(seasonNames);
    totalHours = nSeasons * nDays * hoursPerDay;
    totalDays = nSeasons * nDays;
    assert(nGen == 7 && nBus == 57 && nBranch == 80 && ...
        nDays == 30 && hoursPerDay == 24 && nSeasons == 3, ...
        'Unexpected 57-bus or seasonal experiment dimensions.');
    assert(all(branchRates > 0) && all(pmax >= pmin), ...
        'Invalid generator or branch constraints.');
    assert(all(ismember(strategicGenerators(:), 1:nGen)) && ...
        numel(unique(strategicGenerators)) == numel(strategicGenerators), ...
        'Invalid strategic generator set.');
    assert(all(case57.Generator.Status == 1), ...
        'This study expects all seven baseline generators to be in service.');

    % Preserve original bus reactive-to-active demand ratios. Reactive
    % demand is not used by the DC-OPF solver but remains internally consistent.
    originalPD = baseCase.bus(:, PD);
    originalQD = baseCase.bus(:, QD);
    qRatio = zeros(nBus, 1);
    hasLoad = originalPD > 0;
    qRatio(hasLoad) = originalQD(hasLoad) ./ originalPD(hasLoad);
    qRatio(~isfinite(qRatio)) = 0;

    scenario = struct('StrategicGenerators', strategicGenerators(:).', ...
                      'ECW', economicRatio, 'FCW', physicalRatio);
    mpopt = mpoption('verbose', 0, 'out.all', 0, ...
                    'opf.dc.solver', cfg.solver.dcSolver);

    % All daily economic quantities are accumulated independently of the
    % optional hourly output storage.
    dailyRevenue = zeros(totalDays, nGen);
    dailyVariableCost = zeros(totalDays, nGen);
    dailyNetEarning = zeros(totalDays, nGen);
    sumDispatch = zeros(1, nGen);
    sumGenBusLMP = zeros(1, nGen);
    sumPeakDispatch = zeros(1, nGen);
    sumPeakNetEarning = zeros(1, nGen);
    nPeakHours = 0;
    sumAllLMP = 0;
    maxBranchLoading = -Inf;
    nSolved = 0;

    if storeHourly
        hourly = struct();
        hourly.Success = false(totalHours, 1);
        hourly.SeasonID = zeros(totalHours, 1);
        hourly.DayID = zeros(totalHours, 1);
        hourly.HourID = zeros(totalHours, 1);
        hourly.ActivePeakHour = false(totalHours, 1);
        hourly.LoadMW = nan(totalHours, nBus);
        hourly.DispatchMW = nan(totalHours, nGen);
        hourly.LMP = nan(totalHours, nBus);
        hourly.BranchFlowMW = nan(totalHours, nBranch);
        hourly.BranchLoadingPercent = nan(totalHours, nBranch);
        hourly.ReportedA = nan(totalHours, nGen);
        hourly.ReportedB = nan(totalHours, nGen);
        hourly.ReportedPmaxMW = nan(totalHours, nGen);
    else
        hourly = struct();
    end

    seasonSummary = table('Size', [nSeasons 4], ...
        'VariableTypes', {'string', 'double', 'double', 'double'}, ...
        'VariableNames', {'Season', 'SolvedHours', 'ExpectedHours', 'MeanLMP'});

    for s = 1:nSeasons
        name = seasonNames{s};
        loadData = seasonal.Seasons.(name);
        peakHours = loadData.Meta.PeakHours(:).';
        loads = loadData.LoadBus_day_bus_hour;
        assert(isequal(size(loads), [nDays, nBus, hoursPerDay]), ...
            'Unexpected demand shape for season %s.', name);
        assert(numel(peakHours) == 2 && all(ismember(peakHours, 1:24)), ...
            'Season %s must have exactly two peak hours.', name);

        seasonSumLMP = 0;
        seasonSolved = 0;
        for d = 1:nDays
            dayIndex = (s - 1) * nDays + d;
            for h = 1:hoursPerDay
                hourIndex = (dayIndex - 1) * hoursPerDay + h;
                demand = reshape(loads(d, :, h), [nBus, 1]);
                opfCase = baseCase;
                opfCase.bus(:, PD) = demand;
                opfCase.bus(:, QD) = demand .* qRatio;
                [opfCase, reported] = segan.apply_withholding( ...
                    opfCase, case57.TrueCost, scenario, h, peakHours);

                try
                    sol = rundcopf(opfCase, mpopt);
                catch solverError
                    error('SEGAN:57BusSolverError', ...
                        '57-bus DC-OPF failed at %s, day %d, hour %d: %s', ...
                        name, d, h, solverError.message);
                end
                if ~isfield(sol, 'success') || sol.success ~= 1
                    error('SEGAN:57BusInfeasible', ...
                        '57-bus DC-OPF unsuccessful at %s, day %d, hour %d.', ...
                        name, d, h);
                end

                dispatch = sol.gen(:, PG);
                lmp = sol.bus(:, LAM_P);
                flow = sol.branch(:, PF);
                loading = 100 * abs(flow) ./ branchRates;
                if isfinite(cfg.market.lmpCap)
                    lmp = min(lmp, cfg.market.lmpCap);
                end
                if any(~isfinite([dispatch; lmp; flow; loading]))
                    error('SEGAN:57BusNonfinite', ...
                        'Nonfinite output at %s, day %d, hour %d.', name, d, h);
                end
                if abs(sum(dispatch) - sum(demand)) > 1e-3
                    error('SEGAN:57BusBalance', ...
                        'DC-OPF balance failed at %s, day %d, hour %d.', name, d, h);
                end
                if any(loading > 100.01)
                    error('SEGAN:57BusBranchLimit', ...
                        'Branch rating violation at %s, day %d, hour %d.', name, d, h);
                end
                if any(dispatch < pmin - 1e-3) || ...
                        any(dispatch > reported.Pmax + 1e-3)
                    error('SEGAN:57BusGenLimit', ...
                        'Generator constraint violation at %s, day %d, hour %d.', ...
                        name, d, h);
                end

                % Market clearing uses reported costs; these economic outputs
                % use the unmodified baseline generator cost parameters.
                genLMP = lmp(genBus);
                revenue = genLMP .* dispatch;
                variableCost = trueA .* dispatch + trueB .* (dispatch.^2);
                netEarning = revenue - variableCost;

                dailyRevenue(dayIndex, :) = dailyRevenue(dayIndex, :) + revenue.';
                dailyVariableCost(dayIndex, :) = ...
                    dailyVariableCost(dayIndex, :) + variableCost.';
                dailyNetEarning(dayIndex, :) = ...
                    dailyNetEarning(dayIndex, :) + netEarning.';
                sumDispatch = sumDispatch + dispatch.';
                sumGenBusLMP = sumGenBusLMP + genLMP.';
                sumAllLMP = sumAllLMP + sum(lmp);
                seasonSumLMP = seasonSumLMP + sum(lmp);
                maxBranchLoading = max(maxBranchLoading, max(loading));
                nSolved = nSolved + 1;
                seasonSolved = seasonSolved + 1;
                if ismember(h, peakHours)
                    sumPeakDispatch = sumPeakDispatch + dispatch.';
                    sumPeakNetEarning = sumPeakNetEarning + netEarning.';
                    nPeakHours = nPeakHours + 1;
                end

                if storeHourly
                    hourly.Success(hourIndex) = true;
                    hourly.SeasonID(hourIndex) = s;
                    hourly.DayID(hourIndex) = d;
                    hourly.HourID(hourIndex) = h;
                    hourly.ActivePeakHour(hourIndex) = reported.ActivePeakHour;
                    hourly.LoadMW(hourIndex, :) = demand.';
                    hourly.DispatchMW(hourIndex, :) = dispatch.';
                    hourly.LMP(hourIndex, :) = lmp.';
                    hourly.BranchFlowMW(hourIndex, :) = flow.';
                    hourly.BranchLoadingPercent(hourIndex, :) = loading.';
                    hourly.ReportedA(hourIndex, :) = reported.a.';
                    hourly.ReportedB(hourIndex, :) = reported.b.';
                    hourly.ReportedPmaxMW(hourIndex, :) = reported.Pmax.';
                end
            end
        end
        seasonSummary.Season(s) = string(name);
        seasonSummary.SolvedHours(s) = seasonSolved;
        seasonSummary.ExpectedHours(s) = nDays * hoursPerDay;
        seasonSummary.MeanLMP(s) = seasonSumLMP / (seasonSolved * nBus);
        fprintf('  %-7s | %4d/%4d solved | Mean LMP %.6f\n', ...
            name, seasonSolved, nDays * hoursPerDay, seasonSummary.MeanLMP(s));
    end

    assert(nSolved == totalHours, 'Some seasonal DC-OPF hours were not completed.');
    assert(nPeakHours == totalDays * 2, 'Unexpected count of peak withholding hours.');
    dailyProfit = dailyNetEarning - fixedCost.';
    dailyCost = dailyVariableCost + fixedCost.';
    economicError = max(abs(dailyNetEarning(:) - ...
        (dailyRevenue(:) - dailyVariableCost(:))));
    assert(economicError <= 1e-7 * max(1, max(abs(dailyRevenue(:)))), ...
        'True-cost accounting identity failed.');
    meanDispatch = (sumDispatch / totalHours).';
    dispatchShare = (sumDispatch / sum(sumDispatch)).';
    capacityUtil = meanDispatch ./ pmax;
    meanDailyNE = mean(dailyNetEarning, 1).';
    meanDailyProfit = mean(dailyProfit, 1).';
    totalDailyNE = sum(dailyNetEarning, 1).';
    genIDs = (1:nGen).';
    genCoMetrics = table(genIDs, genBus, pmax, meanDispatch, ...
        dispatchShare, capacityUtil, meanDailyNE, meanDailyProfit, totalDailyNE, ...
        'VariableNames', {'GenCo', 'Bus', 'Pmax', 'MeanPG', ...
        'DispatchShare', 'CapacityUtilization', 'MeanDailyNetEarning', ...
        'MeanDailyProfit', 'TotalDailyNetEarning'});
    genCoMetrics.PeakMeanPG = (sumPeakDispatch / nPeakHours).';
    genCoMetrics.PeakTotalNetEarning = sumPeakNetEarning.';
    genCoMetrics.MeanGenBusLMP = (sumGenBusLMP / totalHours).';

    result = struct();
    result.Meta = struct('StrategicGenerators', strategicGenerators(:).', ...
        'ECW', economicRatio, 'FCW', physicalRatio, ...
        'StoredHourlyData', storeHourly, 'ExpectedHours', totalHours, ...
        'Source', 'Stage 1 raw-input preparation');
    result.Summary = struct('SolvedHours', nSolved, 'ExpectedHours', totalHours, ...
        'MeanLMP', sumAllLMP / (nSolved * nBus), ...
        'MaxBranchLoadingPercent', maxBranchLoading);
    result.SeasonSummary = seasonSummary;
    result.GenCoMetrics = genCoMetrics;
    result.Economic = struct('DailyRevenue', dailyRevenue, ...
        'DailyTrueVariableCost', dailyVariableCost, ...
        'DailyTrueTotalCost', dailyCost, ...
        'DailyNetEarning', dailyNetEarning, 'DailyProfit', dailyProfit);
    result.Hourly = hourly;
end
