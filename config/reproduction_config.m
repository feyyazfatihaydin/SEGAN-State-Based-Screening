function cfg = reproduction_config()
%REPRODUCTION_CONFIG Build a portable configuration for the SEGAN study.
%   CFG = REPRODUCTION_CONFIG() locates the repository relative to this file.
%   No personal, absolute, or machine-specific paths are stored in source code.
%
    configDir = fileparts(mfilename('fullpath'));
    projectRoot = fileparts(configDir);

    cfg = struct();
    cfg.paths.project = projectRoot;
    cfg.paths.raw = fullfile(projectRoot, 'data', 'raw');
    cfg.paths.cache = fullfile(projectRoot, 'outputs', 'cache');
    cfg.files.ames5 = fullfile(cfg.paths.raw, 'AMES_5Bus.xlsx');
    cfg.files.case57 = fullfile(cfg.paths.raw, 'case57.m');
    cfg.files.pglib57 = fullfile(cfg.paths.raw, 'pglib_opf_case57_ieee__sad.m');
    cfg.files.turkeyLoad = fullfile(cfg.paths.raw, 'power Generation and consumption.csv');
    cfg.files.preparedInputs = fullfile(cfg.paths.cache, 'segan_inputs.mat');

    % Published scenario design.
    cfg.withholding.economicRatios = [0.10, 0.20, 0.30];
    cfg.withholding.physicalRatios = [0.02, 0.03, 0.05];
    cfg.withholding.regimes = {'CW0', 'ECW', 'FCW', 'CCW'};
    cfg.fiveBus.focusGenerator = 3;
    cfg.fiveBus.peakHours = [17, 18];
    cfg.fiveBus.hoursPerDay = 24;
    cfg.fiftySevenBus.singleGenerator = 5;
    cfg.fiftySevenBus.doubleGenerators = [5, 7];
    cfg.fiftySevenBus.daysPerSeason = 30;
    cfg.fiftySevenBus.hoursPerDay = 24;
    cfg.fiftySevenBus.seasonNames = {'Winter', 'Summer', 'Neutral'};
    cfg.fiftySevenBus.seasonStarts = [datetime(2022, 1, 1), ...
                                     datetime(2022, 7, 1), ...
                                     datetime(2022, 4, 1)];

    % Settings recorded in the published article; later stages will use these.
    cfg.market.lmpCap = Inf;
    cfg.solver.dcSolver = 'DEFAULT';
    cfg.clustering.seed = 20260422;
    cfg.clustering.replicates = 50;
    cfg.clustering.maxIterations = 1000;
    cfg.clustering.zeroVarianceTolerance = 1e-8;
end
