function evidence = probe_dc_solver(cfg)
%PROBE_DC_SOLVER Observe the actual DC-OPF solver on this MATLAB machine.
%   EVIDENCE = SEGAN.PROBE_DC_SOLVER(CFG) runs two in-memory five-bus
%   demonstration cases with the repository's DEFAULT solver setting and
%   attempts the same cases using explicitly requested GUROBI.
%
%   This diagnostic does not alter inputs, caches, publication outputs,
%   MATLAB source files, or Git state. It does not prove which solver was
%   selected in a past run: it documents the CURRENT MATLAB environment.
%
%   The resolved algorithm is taken from results.raw.output.alg, NOT
%   inferred from whether Gurobi is installed or from solver preferences.

    if nargin < 1 || isempty(cfg)
        cfg = reproduction_config();
    end
    if exist('rundcopf', 'file') ~= 2 || exist('mpoption', 'file') ~= 2
        error('SEGAN:SolverProbeNoMATPOWER', ...
            'MATPOWER rundcopf and mpoption are unavailable.');
    end
    if ~isfile(cfg.files.preparedInputs)
        error('SEGAN:SolverProbeNoInputs', ...
            'Stage 1 prepared inputs are required for this read-only probe.');
    end
    loaded = load(cfg.files.preparedInputs, 'inputs');
    if ~isfield(loaded, 'inputs') || ~isfield(loaded.inputs, 'FiveBus')
        error('SEGAN:SolverProbeBadInputs', ...
            'Stage 1 cache has no FiveBus input structure.');
    end
    fiveBus = loaded.inputs.FiveBus;
    scenarios = segan.list_withholding_scenarios( ...
        cfg.withholding.economicRatios, ...
        cfg.withholding.physicalRatios, fiveBus.CWDesign.FocusGen);
    names = string({scenarios.Name});
    ix0 = find(names == "CW0_BASE", 1);
    ix1 = find(names == "CCW_E0.30_F0.05", 1);
    if isempty(ix0) || isempty(ix1)
        error('SEGAN:SolverProbeScenarios', ...
            'Required baseline / CCW scenario names are missing.');
    end
    peakHours = fiveBus.CWDesign.PeakHours(:).';
    if isempty(peakHours)
        error('SEGAN:SolverProbePeakHours', 'Peak hours are missing.');
    end
    targetHour = peakHours(1);
    baseCase = segan.build_5bus_case(fiveBus);
    choices = [ix0, ix1];
    names = { 'CW0 peak', 'CCW peak' };
    expected = upper(char(cfg.solver.dcSolver));
    fprintf('\n=== SEGAN Stage 11O: observed DC-OPF solver evidence ===\n');
    fprintf('Configured solver: %s | example peak hour: %d\n', expected, targetHour);
    fprintf('Four small DC-OPFs at most; all results remain in memory.\n');

    resolvedDefault = strings(2,1);
    successDefault = false(2,1);
    defaultObjective = nan(2,1);
    defaultDispatch = cell(2,1);
    defaultPrices = cell(2,1);
    explicitSolved = false(2,1);
    resolvedExplicit = strings(2,1);
    explicitObjective = nan(2,1);
    maxDispatchDiff = nan(2,1);
    maxPriceDiff = nan(2,1);
    explicitError = strings(2,1);

    if ~strcmp(expected, 'DEFAULT')
        fprintf('NOTE: configuration is not DEFAULT; the configured run is still tested.\n');
    end
    optsDefault = mpoption('verbose', 0, 'out.all', 0, ...
        'opf.dc.solver', cfg.solver.dcSolver);
    optsExplicit = mpoption('verbose', 0, 'out.all', 0, ...
        'opf.dc.solver', 'GUROBI');
    define_constants;
    for k = 1:2
        mpc = baseCase;
        demand = reshape(fiveBus.Load.LoadBus_day_bus_hour(1,:,targetHour), [], 1);
        mpc.bus(:,PD) = demand;
        [mpc, offered] = segan.apply_withholding( ...
            mpc, fiveBus.TrueCost, scenarios(choices(k)), ...
            targetHour, peakHours); %#ok<ASGLU>

        d = rundcopf(mpc, optsDefault);
        successDefault(k) = isfield(d,'success') && logical(d.success);
        if ~successDefault(k)
            error('SEGAN:SolverProbeDefaultFailed', ...
                'Configured DC-OPF failed: %s.', names{k});
        end
        resolvedDefault(k) = get_solver_name(d);
        defaultObjective(k) = d.f;
        defaultDispatch{k} = d.gen(:,PG);
        defaultPrices{k} = d.bus(:,LAM_P);
        fprintf('%-9s configured=%-8s resolved=%-12s success=%d\n', ...
            names{k}, expected, char(resolvedDefault(k)), successDefault(k));

        try
            g = rundcopf(mpc, optsExplicit);
            explicitSolved(k) = isfield(g,'success') && logical(g.success);
            resolvedExplicit(k) = get_solver_name(g);
            if explicitSolved(k)
                explicitObjective(k) = g.f;
                maxDispatchDiff(k) = max(abs(d.gen(:,PG) - g.gen(:,PG)));
                maxPriceDiff(k) = max(abs(d.bus(:,LAM_P) - g.bus(:,LAM_P)));
                fprintf('  explicit GUROBI resolved=%-12s obj difference=%.5g\n', ...
                    char(resolvedExplicit(k)), abs(defaultObjective(k)-explicitObjective(k)));
            else
                explicitError(k) = "Explicit GUROBI returned an unsuccessful solve";
                fprintf('  explicit GUROBI did not converge.\n');
            end
        catch exception
            explicitError(k) = string(exception.identifier) + ": " + string(exception.message);
            fprintf('  explicit GUROBI unavailable/failed (details in report).\n');
        end
    end

    evidence = struct();
    evidence.ConfiguredSolver = string(expected);
    evidence.Cases = table(string(names(:)), resolvedDefault, successDefault, ...
        defaultObjective, resolvedExplicit, explicitSolved, ...
        explicitObjective, maxDispatchDiff, maxPriceDiff, explicitError, ...
        'VariableNames', {'Case','ResolvedConfiguredSolver', ...
        'ConfiguredSolveSucceeded','ConfiguredObjective', ...
        'ResolvedExplicitSolver','ExplicitGurobiSucceeded', ...
        'ExplicitGurobiObjective','MaxDispatchMWDifference', ...
        'MaxLMPDifference','ExplicitGurobiNote'});
    evidence.Validation = struct();
    evidence.Validation.ConfiguredSolvesSucceeded = all(successDefault);
    evidence.Validation.AlgorithmRecorded = all(strlength(resolvedDefault)>0) && ...
        ~any(resolvedDefault=="UNKNOWN");
    evidence.Validation.ConfiguredSolverIsGurobi = ...
        all(contains(upper(resolvedDefault),"GUROBI"));
    evidence.Validation.ExplicitGurobiAvailable = all(explicitSolved) && ...
        all(contains(upper(resolvedExplicit),"GUROBI"));
    evidence.Validation.NoResearchFilesWritten = true;
    evidence.Validation.HistoricalFullRunProven = false;
    evidence.Validation.InMemoryProbePassed = ...
        evidence.Validation.ConfiguredSolvesSucceeded && ...
        evidence.Validation.AlgorithmRecorded;
    fprintf('Configured resolves to GUROBI in both probes: %d\n', ...
        evidence.Validation.ConfiguredSolverIsGurobi);
    fprintf('Explicit GUROBI succeeds in both probes: %d\n', ...
        evidence.Validation.ExplicitGurobiAvailable);
    fprintf('IMPORTANT: historical Full Mode solver selection is not proven by this new probe.\n');
    fprintf('No MAT, figure, table, source, or Git files were written.\n');
    fprintf('=== Stage 11O solver probe completed ===\n\n');
    if ~evidence.Validation.InMemoryProbePassed
        error('SEGAN:SolverProbeNotRecorded', ...
            'Configured solver could not be identified from OPF output.');
    end
end

function resolved = get_solver_name(results)
%GET_SOLVER_NAME Read the solver identifier from the real OPF result.
    resolved = "UNKNOWN";
    if isfield(results,'raw') && isstruct(results.raw) && ...
            isfield(results.raw,'output') && ...
            isstruct(results.raw.output) && ...
            isfield(results.raw.output,'alg') && ...
            ~isempty(results.raw.output.alg)
        resolved = upper(string(results.raw.output.alg));
    end
end
