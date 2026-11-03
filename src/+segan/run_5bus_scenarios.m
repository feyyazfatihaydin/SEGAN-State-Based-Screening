function output = run_5bus_scenarios(cfg, inputs)
%RUN_5BUS_SCENARIOS Recompute all 384 five-bus reported-offer DC-OPF cases.
%   OUTPUT = SEGAN.RUN_5BUS_SCENARIOS(CFG, INPUTS) accepts Stage 1 inputs
%   reconstructed from raw data. It never loads earlier OPF results.
%   True-cost economic accounting and clustering are separate later stages.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(inputs) || ...
            ~isfield(inputs, 'FiveBus')
        error('SEGAN:InvalidInput', ...
            'Pass cfg and freshly prepared Stage 1 inputs.');
    end
    if exist('rundcopf', 'file') ~= 2 || exist('mpoption', 'file') ~= 2
        error('SEGAN:MissingMATPOWER', ...
            'Add MATPOWER 8.1 to the MATLAB path before running this stage.');
    end

    fiveBus = inputs.FiveBus;
    nHours = fiveBus.Meta.nHours;
    nBus = fiveBus.Meta.nBus;
    nGen = fiveBus.Meta.nGen;
    nBranch = fiveBus.Meta.nBranch;
    assert(nHours == 24 && nBus == 5 && nGen == 5 && nBranch == 6, ...
        'Unexpected five-bus dimensions.');
    assert(isequal(size(fiveBus.Load.LoadBus_day_bus_hour), [1 5 24]), ...
        'Unexpected five-bus hourly demand array.');

    baseCase = segan.build_5bus_case(fiveBus);
    scenarios = segan.list_withholding_scenarios( ...
        cfg.withholding.economicRatios, cfg.withholding.physicalRatios, ...
        fiveBus.CWDesign.FocusGen);
    peakHours = fiveBus.CWDesign.PeakHours(:).';
    options = mpoption('verbose', 0, 'out.all', 0, ...
                       'opf.dc.solver', cfg.solver.dcSolver);

    define_constants;
    nScenarios = numel(scenarios);
    results = struct([]);
    successCounts = zeros(nScenarios, 1);
    meanLMP = nan(nScenarios, 1);
    maxLoading = nan(nScenarios, 1);

    fprintf('\n=== SEGAN Stage 2: Five-bus reported-offer DC-OPF ===\n');
    fprintf('Scenarios: %d | Hours per scenario: %d | Planned OPF cases: %d\n', ...
        nScenarios, nHours, nScenarios * nHours);
    fprintf('Peak activation hours: %s\n', mat2str(peakHours));
    fprintf('Solver selection: %s\n', cfg.solver.dcSolver);
    fprintf('No previous DC-OPF results are read.\n\n');

    for s = 1:nScenarios
        scenario = scenarios(s);
        hourly = struct();
        hourly.Success = false(nHours, 1);
        hourly.LoadMW = nan(nHours, nBus);
        hourly.DispatchMW = nan(nHours, nGen);
        hourly.LMP = nan(nHours, nBus);
        hourly.BranchFlowMW = nan(nHours, nBranch);
        hourly.BranchLoadingPercent = nan(nHours, nBranch);
        hourly.ReportedA = nan(nHours, nGen);
        hourly.ReportedB = nan(nHours, nGen);
        hourly.ReportedPmaxMW = nan(nHours, nGen);
        hourly.ActivePeakHour = false(nHours, 1);
        hourly.ReportedObjective = nan(nHours, 1);

        for h = 1:nHours
            % Use only Stage 1's freshly prepared demand inputs.
            demand = reshape(fiveBus.Load.LoadBus_day_bus_hour(1, :, h), [], 1);
            mpc = baseCase;
            mpc.bus(:, PD) = demand;
            [mpc, reported] = segan.apply_withholding( ...
                mpc, fiveBus.TrueCost, scenario, h, peakHours);

            hourly.LoadMW(h, :) = demand.';
            hourly.ReportedA(h, :) = reported.a.';
            hourly.ReportedB(h, :) = reported.b.';
            hourly.ReportedPmaxMW(h, :) = reported.Pmax.';
            hourly.ActivePeakHour(h) = reported.ActivePeakHour;

            try
                solved = rundcopf(mpc, options);
            catch solverError
                error('SEGAN:SolverError', ...
                    'DC-OPF failed for scenario %s, hour %d: %s', ...
                    scenario.Name, h, solverError.message);
            end
            if ~isfield(solved, 'success') || solved.success ~= 1
                error('SEGAN:UnsuccessfulOPF', ...
                    'DC-OPF returned no solution for scenario %s, hour %d.', ...
                    scenario.Name, h);
            end

            dispatch = solved.gen(:, PG);
            lmp = solved.bus(:, LAM_P);
            flows = solved.branch(:, PF);
            loading = 100 * abs(flows) ./ fiveBus.Branch.RateA(:);
            if any(~isfinite([dispatch; lmp; flows; loading]))
                error('SEGAN:InvalidResult', ...
                    'Nonfinite OPF result for scenario %s, hour %d.', ...
                    scenario.Name, h);
            end
            if abs(sum(dispatch) - sum(demand)) > 1e-3
                error('SEGAN:PowerBalance', ...
                    'DC power balance check failed for scenario %s, hour %d.', ...
                    scenario.Name, h);
            end
            if any(loading > 100 + 1e-2)
                error('SEGAN:BranchLimit', ...
                    'Branch loading exceeds numerical tolerance in %s, hour %d.', ...
                    scenario.Name, h);
            end

            hourly.Success(h) = true;
            hourly.DispatchMW(h, :) = dispatch.';
            hourly.LMP(h, :) = lmp.';
            hourly.BranchFlowMW(h, :) = flows.';
            hourly.BranchLoadingPercent(h, :) = loading.';
            hourly.ReportedObjective(h) = solved.f;
        end

        results(s).Scenario = scenario;
        results(s).Hourly = hourly;
        successCounts(s) = sum(hourly.Success);
        meanLMP(s) = mean(hourly.LMP(:));
        maxLoading(s) = max(hourly.BranchLoadingPercent(:));
        fprintf('%02d/%02d %-18s | %2d/%2d solved | Mean LMP %10.4f | Max loading %8.3f %%\n', ...
            s, nScenarios, scenario.Name, successCounts(s), nHours, ...
            meanLMP(s), maxLoading(s));
    end

    scenarioNames = string({scenarios.Name}).';
    regimes = string({scenarios.Regime}).';
    economicRatio = reshape([scenarios.ECW], [], 1);
    physicalRatio = reshape([scenarios.FCW], [], 1);
    summary = table((1:nScenarios).', scenarioNames, regimes, ...
        economicRatio, physicalRatio, successCounts, meanLMP, maxLoading, ...
        'VariableNames', {'ID', 'Scenario', 'Regime', 'ECW', 'FCW', ...
                          'SolvedHours', 'MeanLMP', 'MaxLoadingPercent'});

    output = struct();
    output.Meta = struct('Stage', 2, ...
        'Description', 'Five-bus reported-offer DC-OPF; no economic accounting.', ...
        'CreatedAt', datetime('now'), ...
        'CaseCount', nScenarios * nHours, ...
        'SolverSelection', cfg.solver.dcSolver, ...
        'Source', 'Stage 1 raw-input preparation');
    output.Scenarios = scenarios;
    output.Results = results;
    output.Summary = summary;

    if ~isfolder(cfg.paths.cache)
        mkdir(cfg.paths.cache);
    end
    fileName = fullfile(cfg.paths.cache, 'segan_5bus_opf.mat');
    save(fileName, 'output', '-v7');

    fprintf('\nSolved OPF cases: %d/%d\n', sum(successCounts), nScenarios * nHours);
    fprintf('Saved new Stage 2 output: outputs/cache/segan_5bus_opf.mat\n');
    fprintf('No true-cost accounting, clustering, figures, or publication tables were generated.\n');
    fprintf('=== SEGAN Stage 2 completed ===\n\n');
end
