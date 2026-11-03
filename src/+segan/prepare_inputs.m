function inputs = prepare_inputs(cfg)
%PREPARE_INPUTS Construct SEGAN inputs exclusively from raw source files.
%   INPUTS = SEGAN.PREPARE_INPUTS(CFG) builds the AMES five-bus case,
%   MATPOWER/PGLib hybrid 57-bus case, and seasonal demand trajectories.
%   A newly calculated MAT file is written to outputs/cache/segan_inputs.mat.
%   The routine never reads stored MATLAB results or runs DC-OPF.
%
    if nargin ~= 1 || ~isstruct(cfg)
        error('SEGAN:InvalidConfig', 'Pass the configuration from reproduction_config().');
    end
    requireFields(cfg, {'paths', 'files', 'withholding', 'fiveBus', 'fiftySevenBus'});
    verifyInputs(cfg);

    fprintf('\n=== SEGAN Stage 1: Raw input preparation ===\n');
    fprintf('Reading source files from the local repository.\n');

    settings = struct();
    settings.LMP_CAP = cfg.market.lmpCap;
    settings.CW.ECW_Ratios = cfg.withholding.economicRatios;
    settings.CW.FCW_Ratios = cfg.withholding.physicalRatios;
    settings.EconomicAccounting.CostFormula = ...
        'Hourly true cost = a * PG + b * PG^2; fixed cost is charged once per day.';
    settings.EconomicAccounting.CoreRule = ...
        'Reported offers determine clearing; baseline coefficients determine accounting.';

    fiveBus = prepareFiveBus(cfg, settings);
    case57 = prepareCase57(cfg, settings);
    seasonalLoad57 = prepareSeasonalLoads(cfg, case57);

    inputs = struct();
    inputs.Meta = struct('Description', ...
        'SEGAN study inputs rebuilt from raw files; no prior results are loaded.', ...
        'CreatedAt', datetime('now'), ...
        'SourceFiles', {{'AMES_5Bus.xlsx', 'case57.m', ...
                         'pglib_opf_case57_ieee__sad.m', ...
                         'power Generation and consumption.csv'}});
    inputs.Settings = settings;
    inputs.FiveBus = fiveBus;
    inputs.Case57 = case57;
    inputs.SeasonalLoad57 = seasonalLoad57;

    verifyPreparedData(inputs);
    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    save(cfg.files.preparedInputs, 'inputs', '-v7.3');

    fprintf('Saved freshly prepared inputs: outputs/cache/segan_inputs.mat\n');
    fprintf('No DC-OPF, clustering, figures, or tables were generated.\n');
    fprintf('=== SEGAN Stage 1 completed ===\n\n');
end

function verifyInputs(cfg)
    if exist('loadcase', 'file') ~= 2
        error('SEGAN:MissingMATPOWER', ...
            'MATPOWER is unavailable. Install MATPOWER 8.1 and add it to the MATLAB path.');
    end
    required = {cfg.files.ames5, cfg.files.case57, ...
                cfg.files.pglib57, cfg.files.turkeyLoad};
    for k = 1:numel(required)
        if ~isfile(required{k})
            error('SEGAN:MissingInput', 'Required raw input file not found: %s', required{k});
        end
    end
end

function fiveBus = prepareFiveBus(cfg, settings)
    % Explicit Excel ranges avoid shifts caused by text headers.
    gen = readmatrix(cfg.files.ames5, 'Sheet', 'input', 'Range', 'C3:H7');
    branches = readmatrix(cfg.files.ames5, 'Sheet', 'input', 'Range', 'M3:P8');
    load2 = readmatrix(cfg.files.ames5, 'Sheet', 'input', 'Range', 'C10:C33');
    load3 = readmatrix(cfg.files.ames5, 'Sheet', 'input', 'Range', 'G10:G33');
    load4 = readmatrix(cfg.files.ames5, 'Sheet', 'input', 'Range', 'K10:K33');

    assert(isequal(size(gen), [5, 6]), 'Unexpected AMES generator range dimensions.');
    assert(isequal(size(branches), [6, 4]), 'Unexpected AMES branch range dimensions.');
    assert(all([numel(load2), numel(load3), numel(load4)] == 24), ...
        'The five-bus demand series must contain 24 observations per bus.');
    assertFinite('AMES generator range', gen);
    assertFinite('AMES branch range', branches);
    assertFinite('AMES load profiles', [load2(:); load3(:); load4(:)]);

    genBus = gen(:, 1);
    trueA = gen(:, 2);
    trueB = gen(:, 3);
    fixedCost = gen(:, 4);
    pmin = gen(:, 5);
    pmax = gen(:, 6);

    assert(all(genBus == floor(genBus) & genBus >= 1 & genBus <= 5), ...
        'The five-bus generator-to-bus mapping is invalid.');
    assert(all(pmax >= pmin), 'Five-bus generator upper limits are below lower limits.');
    assert(all(branches(:, 3) > 0 & branches(:, 4) > 0), ...
        'Five-bus branch limits and reactances must be positive.');
    assert(all([load2(:); load3(:); load4(:)] >= 0), ...
        'Five-bus demand values must be nonnegative.');

    loadBus = zeros(1, 5, 24);
    loadBus(1, 2, :) = reshape(load2, [1, 1, 24]);
    loadBus(1, 3, :) = reshape(load3, [1, 1, 24]);
    loadBus(1, 4, :) = reshape(load4, [1, 1, 24]);
    totalLoad = reshape(sum(loadBus, 2), [1, 24]);

    fiveBus.Meta = struct('nBus', 5, 'nGen', 5, 'nBranch', 6, ...
                          'nDays', 1, 'nHours', 24, ...
                          'SourceFile', 'AMES_5Bus.xlsx');
    fiveBus.TrueCost = struct('a', trueA, 'b', trueB, 'Fcost', fixedCost);
    fiveBus.Generator = struct('Bus', genBus, 'Pmin', pmin, 'Pmax', pmax, ...
                               'Index', (1:5)');
    fiveBus.Branch = struct('From', branches(:, 1), 'To', branches(:, 2), ...
                            'RateA', branches(:, 3), 'RateB', branches(:, 3), ...
                            'RateC', branches(:, 3), 'X', branches(:, 4), ...
                            'Index', (1:6)');
    fiveBus.Load = struct('LoadBus_day_bus_hour', loadBus, ...
                          'TotalLoad_day_hour', totalLoad, ...
                          'LoadBus2_hour', load2(:), ...
                          'LoadBus3_hour', load3(:), ...
                          'LoadBus4_hour', load4(:));
    fiveBus.CWDesign = struct('FocusGen', cfg.fiveBus.focusGenerator, ...
                             'FocusGenBus', genBus(cfg.fiveBus.focusGenerator), ...
                             'PeakHours', cfg.fiveBus.peakHours, ...
                             'ECW_Ratios', settings.CW.ECW_Ratios, ...
                             'FCW_Ratios', settings.CW.FCW_Ratios, ...
                             'Regimes', {cfg.withholding.regimes});
    fprintf('Five-bus inputs: 5 buses, 5 generators, 6 branches, 24 hours.\n');
end

function case57 = prepareCase57(cfg, settings)
    % MATPOWER accepts case filenames with explicit paths.
    base = loadcase(cfg.files.case57);
    sad = loadcase(cfg.files.pglib57);

    assert(size(base.bus, 1) == 57 && size(base.gen, 1) == 7 && ...
           size(base.branch, 1) == 80, 'Unexpected MATPOWER case57 size.');
    assert(size(sad.bus, 1) == 57 && size(sad.branch, 1) == 80, ...
        'Unexpected PGLib-SAD case57 size.');
    assert(size(base.gencost, 1) == 7 && ...
           all(base.gencost(:, 1) == 2) && all(base.gencost(:, 4) == 3), ...
        'The baseline case must contain seven quadratic generator cost functions.');

    % MATPOWER branch columns: F_BUS=1, T_BUS=2, RATE_A=6, RATE_B=7, RATE_C=8.
    ratings = alignRatings(base.branch(:, 1:2), sad.branch(:, 1:2), ...
                           sad.branch(:, 6:8));
    assertFinite('PGLib-SAD thermal ratings', ratings);
    assert(all(ratings(:, 1) > 0), 'PGLib-SAD RATE_A must be positive.');

    hybrid = base;
    % Preserve the source workflow: copy A/B/C values while only RATE_A
    % constrains the published DC-OPF. Do not import SAD angle limits.
    hybrid.branch(:, 6:8) = ratings;

    trueB = hybrid.gencost(:, 5);
    trueA = hybrid.gencost(:, 6);
    fixedCost = zeros(7, 1);
    basePD = hybrid.bus(:, 3);
    baseQD = hybrid.bus(:, 4);
    totalPD = sum(basePD);
    assert(totalPD > 0, 'The total baseline demand must be positive.');
    assert(all(hybrid.gen(:, 9) >= hybrid.gen(:, 10)), ...
        'Generator maximum power must not be smaller than minimum power.');

    case57.Meta = struct('nBus', 57, 'nGen', 7, 'nBranch', 80, ...
                         'baseMVA', hybrid.baseMVA, ...
                         'baseTotalPD', totalPD, ...
                         'MainCaseSource', 'case57.m', ...
                         'RatingSource', 'pglib_opf_case57_ieee__sad.m', ...
                         'UseSADAngles', false);
    case57.OriginalCase = base;
    case57.HybridCase = hybrid;
    case57.TrueCost = struct('a', trueA, 'b', trueB, 'Fcost', fixedCost);
    case57.Generator = struct('Index', (1:7)', ...
                              'Bus', hybrid.gen(:, 1), ...
                              'Pmin', hybrid.gen(:, 10), ...
                              'Pmax', hybrid.gen(:, 9), ...
                              'Status', hybrid.gen(:, 8));
    case57.Branch = struct('Index', (1:80)', ...
                           'From', hybrid.branch(:, 1), ...
                           'To', hybrid.branch(:, 2), ...
                           'X', hybrid.branch(:, 4), ...
                           'RateA', hybrid.branch(:, 6), ...
                           'RateB', hybrid.branch(:, 7), ...
                           'RateC', hybrid.branch(:, 8), ...
                           'OriginalCase57_RateA', base.branch(:, 6), ...
                           'ImportedSAD_RateA', ratings(:, 1));
    case57.BaseLoad = struct('PD', basePD, 'QD', baseQD, ...
                             'TotalPD', totalPD, 'LoadShare', basePD / totalPD);
    case57.CWDesign.Strategies(1) = struct('Name', 'Single_G5', ...
                                          'GenIdx', cfg.fiftySevenBus.singleGenerator, ...
                                          'BusIdx', hybrid.gen(cfg.fiftySevenBus.singleGenerator, 1));
    case57.CWDesign.Strategies(2) = struct('Name', 'Double_G5G7', ...
                                          'GenIdx', cfg.fiftySevenBus.doubleGenerators, ...
                                          'BusIdx', hybrid.gen(cfg.fiftySevenBus.doubleGenerators, 1)');
    case57.CWDesign.ECW_Ratios = settings.CW.ECW_Ratios;
    case57.CWDesign.FCW_Ratios = settings.CW.FCW_Ratios;
    case57.CWDesign.Regimes = cfg.withholding.regimes;
    fprintf('Fifty-seven-bus inputs: 57 buses, 7 generators, 80 branches.\n');
end

function seasonalLoad57 = prepareSeasonalLoads(cfg, case57)
    opts = detectImportOptions(cfg.files.turkeyLoad, 'VariableNamingRule', 'preserve');
    demandTable = readtable(cfg.files.turkeyLoad, opts);
    headers = demandTable.Properties.VariableNames;
    assert(any(strcmp(headers, 'Date_Time')), 'Missing Date_Time column.');
    assert(any(strcmp(headers, 'Consumption (MWh)')), ...
        'Missing Consumption (MWh) column.');

    timestamps = parseDates(demandTable.('Date_Time'));
    consumption = parseNumbers(demandTable.('Consumption (MWh)'));
    assert(all(~isnat(timestamps)), 'Invalid timestamps in the demand file.');
    assertFinite('Demand consumption values', consumption);
    assert(all(consumption >= 0), 'Negative demand values are not permitted.');

    keep = year(timestamps) == 2022;
    yearDates = timestamps(keep);
    yearDemand = consumption(keep);
    [yearDates, order] = sort(yearDates);
    yearDemand = yearDemand(order);

    assert(numel(yearDates) == 8760, 'Expected exactly 8760 hours for 2022.');
    assert(numel(unique(yearDates)) == 8760, 'Duplicate hourly records detected.');
    assert(all(abs(hours(diff(yearDates)) - 1) < 1e-9), ...
        'The 2022 demand time series has missing or irregular hours.');

    nDays = cfg.fiftySevenBus.daysPerSeason;
    nHours = cfg.fiftySevenBus.hoursPerDay;
    avgAnnualLoad = mean(yearDemand);
    busShares = case57.BaseLoad.LoadShare(:);
    baseTotalPD = case57.BaseLoad.TotalPD;

    seasonalLoad57.Meta = struct('nSeasons', numel(cfg.fiftySevenBus.seasonNames), ...
                                 'nDays', nDays, 'nHours', nHours, 'nBus', 57, ...
                                 'AnnualMeanTurkeyLoad2022', avgAnnualLoad, ...
                                 'BaseTotalPD_case57', baseTotalPD, ...
                                 'SeasonNames', {cfg.fiftySevenBus.seasonNames}, ...
                                 'SourceCSV', 'power Generation and consumption.csv');

    for s = 1:numel(cfg.fiftySevenBus.seasonNames)
        name = cfg.fiftySevenBus.seasonNames{s};
        startDate = cfg.fiftySevenBus.seasonStarts(s);
        endExclusive = startDate + days(nDays);
        idx = yearDates >= startDate & yearDates < endExclusive;
        seasonDates = yearDates(idx);
        seasonDemand = yearDemand(idx);

        assert(numel(seasonDemand) == nDays * nHours, ...
            'Season %s does not contain the expected number of hours.', name);
        scaledLoad = baseTotalPD * (seasonDemand / avgAnnualLoad);
        datesDayHour = reshape(seasonDates, [nHours, nDays]).';
        rawDayHour = reshape(seasonDemand, [nHours, nDays]).';
        totalDayHour = reshape(scaledLoad, [nHours, nDays]).';
        loadBus = bsxfun(@times, ...
            reshape(totalDayHour, [nDays, 1, nHours]), ...
            reshape(busShares, [1, 57, 1]));

        meanHourly = mean(totalDayHour, 1);
        [~, order] = sort(meanHourly, 'descend');
        peakHours = sort(order(1:2));

        season.Meta = struct('Name', name, 'StartDate', startDate, ...
                             'EndDate', endExclusive - days(1), ...
                             'nDays', nDays, 'nHours', nHours, 'nBus', 57, ...
                             'PeakHours', peakHours, ...
                             'MeanHourlyLoad', meanHourly, ...
                             'RawMean_MWh', mean(seasonDemand), ...
                             'RawMin_MWh', min(seasonDemand), ...
                             'RawMax_MWh', max(seasonDemand), ...
                             'ScaledMean_MW', mean(scaledLoad), ...
                             'ScaledMin_MW', min(scaledLoad), ...
                             'ScaledMax_MW', max(scaledLoad));
        season.DateTime_day_hour = datesDayHour;
        season.RawLoad_day_hour = rawDayHour;
        season.TotalLoad_day_hour = totalDayHour;
        season.LoadBus_day_bus_hour = loadBus;
        seasonalLoad57.Seasons.(name) = season;
        fprintf('%-7s: 720 hours; withholding peak hours = %d, %d.\n', ...
            name, peakHours(1), peakHours(2));
    end
end

function matched = alignRatings(casePairs, sourcePairs, sourceRatings)
    n = size(casePairs, 1);
    assert(size(sourcePairs, 1) == n, 'Branch lists have unequal lengths.');
    matched = nan(n, size(sourceRatings, 2));
    used = false(n, 1);
    for i = 1:n
        idx = find(sourcePairs(:, 1) == casePairs(i, 1) & ...
                   sourcePairs(:, 2) == casePairs(i, 2) & ~used, 1);
        if isempty(idx)
            idx = find(sourcePairs(:, 2) == casePairs(i, 1) & ...
                       sourcePairs(:, 1) == casePairs(i, 2) & ~used, 1);
        end
        assert(~isempty(idx), 'Cannot match PGLib-SAD branch %d.', i);
        matched(i, :) = sourceRatings(idx, :);
        used(idx) = true;
    end
    assert(all(used), 'Some source branches were not matched.');
end

function timestamps = parseDates(rawDates)
    if isdatetime(rawDates)
        timestamps = rawDates;
        return;
    end
    candidate = string(rawDates);
    formats = {'dd.MM.yyyy HH:mm', 'dd.MM.yyyy HH:mm:ss', ...
               'yyyy-MM-dd HH:mm:ss', 'yyyy-MM-dd HH:mm'};
    for k = 1:numel(formats)
        try
            timestamps = datetime(candidate, 'InputFormat', formats{k});
            if all(~isnat(timestamps))
                return;
            end
        catch
            % Try another explicit timestamp format.
        end
    end
    error('SEGAN:DateFormat', 'Could not parse Date_Time with the supported formats.');
end

function values = parseNumbers(raw)
    if isnumeric(raw)
        values = double(raw);
    else
        values = str2double(strrep(string(raw), ',', '.'));
    end
    values = values(:);
end

function assertFinite(label, values)
    assert(all(isfinite(values(:))), '%s contains missing or nonfinite values.', label);
end

function requireFields(s, names)
    for k = 1:numel(names)
        if ~isfield(s, names{k})
            error('SEGAN:MissingConfigField', 'Missing configuration field: %s', names{k});
        end
    end
end

function verifyPreparedData(inputs)
    assert(isequal(size(inputs.FiveBus.Load.LoadBus_day_bus_hour), [1, 5, 24]), ...
        'The AMES load array has an unexpected shape.');
    assert(all([size(inputs.Case57.HybridCase.bus, 1), ...
                size(inputs.Case57.HybridCase.gen, 1), ...
                size(inputs.Case57.HybridCase.branch, 1)] == [57, 7, 80]), ...
        'The hybrid case has an unexpected size.');
    names = inputs.SeasonalLoad57.Meta.SeasonNames;
    for i = 1:numel(names)
        season = inputs.SeasonalLoad57.Seasons.(names{i});
        assert(isequal(size(season.LoadBus_day_bus_hour), [30, 57, 24]), ...
            'Unexpected seasonal bus-load array dimensions.');
    end
end
