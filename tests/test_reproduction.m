function tests = test_reproduction
%TEST_REPRODUCTION Focused MATLAB unit tests for the SEGAN repository.
%   Run with:
%       results = runtests('tests/test_reproduction.m');
%
%   The tests do not create or modify research outputs. The demo test
%   solves four five-bus OPF cases in memory when Stage 1 inputs exist.
%   Recorded-results validation is tested only when the full set of
%   generated study outputs is already present.
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testsDir = fileparts(mfilename('fullpath'));
    root = fileparts(testsDir);
    addpath(root);
    addpath(fullfile(root,'config'));
    addpath(fullfile(root,'src'));
    testCase.TestData.Root = root;
    testCase.TestData.Config = reproduction_config();
end

function testConfigurationIsRepositoryRelative(testCase)
    cfg = testCase.TestData.Config;
    root = testCase.TestData.Root;
    testCase.verifyEqual(char(cfg.paths.project), root);
    testCase.verifyEqual(char(cfg.paths.raw), fullfile(root,'data','raw'));
    testCase.verifyEqual(char(cfg.paths.cache), fullfile(root,'outputs','cache'));
    testCase.verifyTrue(isfile(cfg.files.ames5));
    testCase.verifyTrue(isfile(cfg.files.case57));
    testCase.verifyTrue(isfile(cfg.files.pglib57));
    testCase.verifyTrue(isfile(cfg.files.turkeyLoad));
end

function testPublishedScenarioDesign(testCase)
    cfg = testCase.TestData.Config;
    scenarios = segan.list_withholding_scenarios( ...
        cfg.withholding.economicRatios, ...
        cfg.withholding.physicalRatios, cfg.fiveBus.focusGenerator);
    regimes = string({scenarios.Regime});
    names = string({scenarios.Name});
    testCase.verifyNumElements(scenarios,16);
    testCase.verifyEqual(nnz(regimes == "CW0"),1);
    testCase.verifyEqual(nnz(regimes == "ECW"),3);
    testCase.verifyEqual(nnz(regimes == "FCW"),3);
    testCase.verifyEqual(nnz(regimes == "CCW"),9);
    testCase.verifyEqual(names(1),"CW0_BASE");
    testCase.verifyEqual(names(end),"CCW_E0.30_F0.05");
end

function testTrueCostDailyAccounting(testCase)
    hourly = struct();
    hourly.Success = true(24,1);
    hourly.DispatchMW = repmat([10,20],24,1);
    hourly.LMP = repmat([15,25,30],24,1);
    costs = struct('a',[3;2], 'b',[0.1;0.2], 'Fcost',[10;20]);
    economics = segan.compute_true_cost_accounting(hourly, costs, [1;3]);
    testCase.verifyEqual(economics.Daily.Revenue,[3600,14400], ...
        'AbsTol',1e-9);
    testCase.verifyEqual(economics.Daily.TrueVariableCost,[960,2880], ...
        'AbsTol',1e-9);
    testCase.verifyEqual(economics.Daily.NetEarning,[2640,11520], ...
        'AbsTol',1e-9);
    testCase.verifyEqual(economics.Daily.Profit,[2630,11500], ...
        'AbsTol',1e-9);
    testCase.verifyEqual(economics.SystemDaily.NetEarning,14160, ...
        'AbsTol',1e-9);
end

function testReproductionPlanIsNonDestructive(testCase)
    first = reproduce_all('plan');
    second = reproduce_all('plan');
    testCase.verifyEqual(first.Mode,'plan');
    testCase.verifyFalse(first.Completed);
    testCase.verifyNumElements(first.Stages.Stage,23);
    testCase.verifyTrue(all(first.Stages.SourcePresent));
    testCase.verifyEqual(first.SafeToStartFreshRun, ...
        second.SafeToStartFreshRun);
    testCase.verifyEqual(first.ExistingOutputFiles, ...
        second.ExistingOutputFiles);
    if ~isempty(first.ExistingOutputFiles)
        testCase.verifyFalse(first.SafeToStartFreshRun);
    end
end

function testSourceAuditAndInstalledEntrypoints(testCase)
    cfg = testCase.TestData.Config;
    audit = segan.audit_release_readiness(cfg);
    testCase.verifyTrue(audit.Validation.MatlabSourcesPortable);
    testCase.verifyTrue(audit.Validation.EntryPointsImplemented);
    testCase.verifyEqual(height(audit.EntryPoints),4);
    testCase.verifyTrue(all(audit.EntryPoints.PresentAndNonempty));
end

function testFourInMemoryDemoCases(testCase)
    cfg = testCase.TestData.Config;
    testCase.assumeTrue(isfile(cfg.files.preparedInputs), ...
        'Stage 1 inputs have not been prepared.');
    testCase.assumeTrue(exist('rundcopf','file') == 2, ...
        'MATPOWER is not on the path.');
    before = dir(cfg.files.preparedInputs);
    demo = run_demo();
    after = dir(cfg.files.preparedInputs);
    testCase.verifyEqual(height(demo.DemoCases),4);
    testCase.verifyEqual(demo.Validation.SolvedCases,4);
    testCase.verifyTrue(demo.Validation.AllPassed);
    testCase.verifyTrue(demo.Validation.ReadOnly);
    testCase.verifyEqual(before.bytes,after.bytes);
    testCase.verifyEqual(before.datenum,after.datenum);
end

function testRecordedResultsWhenAvailable(testCase)
    cfg = testCase.TestData.Config;
    artifact = fullfile(cfg.paths.cache, ...
        'segan_57bus_feature_ablation.mat');
    testCase.assumeTrue(isfile(artifact), ...
        'Full study outputs are not available yet.');
    validated = validate_results();
    testCase.verifyTrue(validated.Validation.AllPassed);
    testCase.verifyEqual(validated.Validation.ChecksPassed,17);
    testCase.verifyTrue(validated.Validation.ReadOnly);
    testCase.verifyFalse(validated.Validation.CleanCloneEndToEndRunVerified);
end
