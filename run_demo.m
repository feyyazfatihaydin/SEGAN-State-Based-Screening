function report = run_demo()
%RUN_DEMO Solve a small, in-memory IEEE five-bus withholding example.
%   REPORT = RUN_DEMO() solves four DC-OPF cases: CW0 and CCW at one
%   non-peak hour and one withholding-active peak hour. It illustrates
%   reported offers versus baseline true-cost accounting without writing
%   MAT files, changing cached research results, or creating figures.
%
%   Prerequisites: Stage 1 prepared inputs (segan_inputs.mat), MATPOWER.
%   The full study is run separately using reproduce_all() in a clean copy.
%
%   This is a short operational demonstration, NOT a clean-clone or
%   publication-wide reproducibility test.

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'config'));
    addpath(fullfile(root, 'src'));
    cfg = reproduction_config();

    if ~strcmp(char(cfg.paths.project), root)
        error('SEGAN:DemoRepositoryMismatch', ...
            'The configuration does not point to this repository.');
    end
    if ~isfile(cfg.files.preparedInputs)
        error('SEGAN:DemoInputsUnavailable', [ ...
            'Stage 1 prepared inputs are missing. First prepare the raw ' ...
            'inputs with segan.prepare_inputs(cfg).']);
    end
    if exist('rundcopf', 'file') ~= 2 || exist('mpoption', 'file') ~= 2
        error('SEGAN:DemoMATPOWERUnavailable', ...
            'MATPOWER rundcopf and mpoption must be on the MATLAB path.');
    end

    prepared = load(cfg.files.preparedInputs, 'inputs');
    if ~isfield(prepared, 'inputs') || ~isfield(prepared.inputs, 'FiveBus')
        error('SEGAN:DemoInputStructure', ...
            'The Stage 1 cache does not contain the expected five-bus inputs.');
    end
    fiveBus = prepared.inputs.FiveBus;
    assert(fiveBus.Meta.nHours == 24 && ...
        fiveBus.Meta.nGen == 5 && fiveBus.Meta.nBus == 5, ...
        'The prepared five-bus input has unexpected dimensions.');

    scenarios = segan.list_withholding_scenarios( ...
        cfg.withholding.economicRatios, ...
        cfg.withholding.physicalRatios, ...
        fiveBus.CWDesign.FocusGen);
    scenarioNames = string({scenarios.Name});
    baseIdx = find(scenarioNames == "CW0_BASE", 1);
    ccwIdx = find(scenarioNames == "CCW_E0.30_F0.05", 1);
    assert(~isempty(baseIdx) && ~isempty(ccwIdx), ...
        'Required demonstration scenarios are missing.');

    peakHours = fiveBus.CWDesign.PeakHours(:).';
    peak = peakHours(1);
    nonpeak = find(~ismember(1:24, peakHours), 1, 'last');
    assert(~isempty(nonpeak) && peak >= 1 && peak <= 24, ...
        'The five-bus peak-hour design is invalid.');

    baseCase = segan.build_5bus_case(fiveBus);
    opts = mpoption('verbose', 0, 'out.all', 0, ...
        'opf.dc.solver', cfg.solver.dcSolver);
    chosen = [baseIdx; ccwIdx; baseIdx; ccwIdx];
    hours = [nonpeak; nonpeak; peak; peak];
    labels = ["CW0 nonpeak"; "CCW nonpeak"; "CW0 peak"; "CCW peak"];
    meanLMP = zeros(4, 1);
    focusDispatch = zeros(4, 1);
    focusLMP = zeros(4, 1);
    focusTrueCost = zeros(4, 1);
    focusNetEarning = zeros(4, 1);
    maxLoading = zeros(4, 1);
    dispatch = cell(4, 1);
    lmp = cell(4, 1);
    reported = cell(4, 1);
    focus = fiveBus.CWDesign.FocusGen;

    fprintf('\n=== SEGAN: In-memory five-bus demonstration ===\n');
    fprintf('Nonpeak hour: %d | withholding-active peak hour: %d\n', ...
        nonpeak, peak);
    fprintf('Four newly solved DC-OPF cases. No files will be written.\n');

    for k = 1:4
        [solved, offered, loadingPercent] = solve_example( ...
            baseCase, fiveBus, scenarios(chosen(k)), hours(k), ...
            peakHours, opts);
        define_constants;
        power = solved.gen(:, PG);
        nodalPrice = solved.bus(:, LAM_P);
        focusPower = power(focus);
        focusBus = fiveBus.Generator.Bus(focus);
        price = nodalPrice(focusBus);
        actualVariableCost = fiveBus.TrueCost.a(focus) * focusPower + ...
            fiveBus.TrueCost.b(focus) * focusPower^2;

        meanLMP(k) = mean(nodalPrice);
        focusDispatch(k) = focusPower;
        focusLMP(k) = price;
        focusTrueCost(k) = actualVariableCost;
        focusNetEarning(k) = price * focusPower - actualVariableCost;
        maxLoading(k) = max(loadingPercent);
        dispatch{k} = power;
        lmp{k} = nodalPrice;
        reported{k} = offered;

        fprintf('%-12s | hour %2d | mean LMP %.5f | focus NE %.5f\n', ...
            char(labels(k)), hours(k), meanLMP(k), focusNetEarning(k));
    end

    define_constants;
    focusPmax = baseCase.gen(focus, PMAX);
    expectedRatio = 1 - scenarios(ccwIdx).FCW;
    expectedOfferRatio = 1 + scenarios(ccwIdx).ECW;
    trueA = fiveBus.TrueCost.a(:);
    trueB = fiveBus.TrueCost.b(:);
    nonpeakOfferUnchanged = ...
        ~reported{2}.ActivePeakHour && ...
        max(abs(reported{1}.a(:) - reported{2}.a(:))) < 1e-10 && ...
        max(abs(reported{1}.b(:) - reported{2}.b(:))) < 1e-10 && ...
        max(abs(reported{1}.Pmax(:) - reported{2}.Pmax(:))) < 1e-10;
    nonpeakOutcomeUnchanged = ...
        max(abs(dispatch{1} - dispatch{2})) < 1e-5 && ...
        max(abs(lmp{1} - lmp{2})) < 1e-5;
    peakOfferApplied = ...
        reported{4}.ActivePeakHour && ...
        abs(reported{4}.a(focus) - expectedOfferRatio * trueA(focus)) < 1e-8 && ...
        abs(reported{4}.b(focus) - expectedOfferRatio * trueB(focus)) < 1e-8 && ...
        abs(reported{4}.Pmax(focus) - expectedRatio * focusPmax) < 1e-8;
    baseOfferUnchanged = ...
        max(abs(reported{3}.a(:) - trueA)) < 1e-10 && ...
        max(abs(reported{3}.b(:) - trueB)) < 1e-10 && ...
        max(abs(reported{3}.Pmax(:) - baseCase.gen(:, PMAX))) < 1e-10;
    economicIdentity = all(isfinite(focusNetEarning)) && ...
        all(abs(focusNetEarning - (focusLMP .* focusDispatch - ...
            focusTrueCost)) < 1e-8);

    report = struct();
    report.DemoCases = table(labels, hours, meanLMP, focusDispatch, ...
        focusLMP, focusTrueCost, focusNetEarning, maxLoading, ...
        'VariableNames', {'Case','Hour','MeanLMP','FocusDispatchMW', ...
            'FocusLMP','FocusTrueVariableCost','FocusNetEarning', ...
            'MaxBranchLoadingPercent'});
    report.PeakComparison = struct( ...
        'DeltaMeanLMP', meanLMP(4) - meanLMP(3), ...
        'DeltaFocusNetEarning', focusNetEarning(4) - focusNetEarning(3));
    report.Validation = struct( ...
        'SolvedCases', 4, ...
        'NonpeakOfferUnchanged', nonpeakOfferUnchanged, ...
        'NonpeakOutcomeUnchanged', nonpeakOutcomeUnchanged, ...
        'PeakOfferApplied', peakOfferApplied, ...
        'BaselineOfferUnchanged', baseOfferUnchanged, ...
        'TrueCostAccountingPassed', economicIdentity, ...
        'ReadOnly', true);
    report.Validation.AllPassed = nonpeakOfferUnchanged && ...
        nonpeakOutcomeUnchanged && peakOfferApplied && ...
        baseOfferUnchanged && economicIdentity;

    disp(report.DemoCases);
    fprintf('Demonstration checks: %s\n', pass_text(report.Validation.AllPassed));
    fprintf('No existing OPF, clustering, figure, or table files were modified.\n');
    fprintf('=== SEGAN demonstration completed ===\n\n');
    if ~report.Validation.AllPassed
        error('SEGAN:DemoVerificationFailed', ...
            'An in-memory five-bus demonstration check failed.');
    end
end

function [solved, offered, loadingPercent] = solve_example( ...
    baseCase, fiveBus, scenario, hourIndex, peakHours, options)
%SOLVE_EXAMPLE Run one five-bus DC-OPF without saving its outcome.
    define_constants;
    demand = reshape(fiveBus.Load.LoadBus_day_bus_hour(1, :, hourIndex), [], 1);
    mpc = baseCase;
    mpc.bus(:, PD) = demand;
    [mpc, offered] = segan.apply_withholding( ...
        mpc, fiveBus.TrueCost, scenario, hourIndex, peakHours);
    solved = rundcopf(mpc, options);
    if ~isfield(solved,'success') || solved.success ~= 1
        error('SEGAN:DemoOPFFailed', ...
            'The in-memory example failed for %s at hour %d.', ...
            scenario.Name, hourIndex);
    end
    power = solved.gen(:, PG);
    flow = solved.branch(:, PF);
    loadingPercent = 100 * abs(flow) ./ fiveBus.Branch.RateA(:);
    if abs(sum(power) - sum(demand)) > 1e-3 || ...
            any(loadingPercent > 100 + 1e-2) || ...
            any(~isfinite([power; solved.bus(:, LAM_P); loadingPercent]))
        error('SEGAN:DemoPhysicalCheckFailed', ...
            'A physical feasibility check failed for the demo case.');
    end
end

function result = pass_text(value)
    if value
        result = 'PASS';
    else
        result = 'FAIL';
    end
end
