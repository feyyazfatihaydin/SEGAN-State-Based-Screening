function audit = audit_release_readiness(cfg)
%AUDIT_RELEASE_READINESS Read-only pre-release audit of the SEGAN repository.
%   AUDIT = SEGAN.AUDIT_RELEASE_READINESS(CFG) checks the presence and basic
%   integrity of source files, raw input files, validated result manifests,
%   scenario checkpoints, figures, tables, and public-release documentation.
%
%   This diagnostic does not solve OPF models, refit clusters, change any
%   existing file, or create a report. Passing this audit is not a license
%   clearance or a substitute for fresh end-to-end reproduction testing.

    if nargin ~= 1 || ~isstruct(cfg) || ~isfield(cfg, 'paths') || ...
            ~isfield(cfg.paths, 'project') || ~isfield(cfg.paths, 'cache')
        error('SEGAN:InvalidConfiguration', ...
            'Provide the existing configuration from reproduction_config().');
    end

    root = cfg.paths.project;
    cacheRoot = cfg.paths.cache;
    if ~isfolder(root) || ~isfolder(cacheRoot)
        error('SEGAN:MissingRepository', ...
            'The configured project or cache directory does not exist.');
    end

    fprintf('\n=== SEGAN Stage 11A: Read-only release readiness audit ===\n');
    fprintf('No OPF, clustering, plotting, export, or file modifications.\n');

    rawNames = [
        "data/raw/AMES_5Bus.xlsx"
        "data/raw/case57.m"
        "data/raw/pglib_opf_case57_ieee__sad.m"
        "data/raw/power Generation and consumption.csv"
    ];
    audit.RawInputs = inspect_files(root, rawNames);

    sourceNames = [
        "config/reproduction_config.m"
        "src/+segan/prepare_inputs.m"
        "src/+segan/apply_withholding.m"
        "src/+segan/build_5bus_case.m"
        "src/+segan/list_withholding_scenarios.m"
        "src/+segan/run_5bus_scenarios.m"
        "src/+segan/compute_economic_network_metrics.m"
        "src/+segan/compute_true_cost_accounting.m"
        "src/+segan/build_5bus_feature_table.m"
        "src/+segan/build_features_and_cluster.m"
        "src/+segan/cluster_operating_states.m"
        "src/+segan/compare_5bus_publication_table.m"
        "src/+segan/export_figures_and_tables.m"
        "src/+segan/solve_57bus_case.m"
        "src/+segan/run_57bus_baseline.m"
        "src/+segan/run_57bus_ccw_probes.m"
        "src/+segan/run_57bus_ecw_fcw_probes.m"
        "src/+segan/complete_57bus_screening.m"
        "src/+segan/export_57bus_table4.m"
        "src/+segan/run_57bus_single_g5_pilot.m"
        "src/+segan/run_57bus_single_g5_library.m"
        "src/+segan/run_57bus_double_g5_g7_pilot.m"
        "src/+segan/run_57bus_double_g5_g7_library.m"
        "src/+segan/build_57bus_feature_libraries.m"
        "src/+segan/cluster_57bus_states.m"
        "src/+segan/export_57bus_figure3_table6.m"
        "src/+segan/export_57bus_figure4_table7.m"
        "src/+segan/export_57bus_figure5.m"
        "src/+segan/analyze_57bus_k_sensitivity.m"
        "src/+segan/export_57bus_figure6_table8.m"
        "src/+segan/analyze_57bus_feature_ablation.m"
        "src/+segan/export_57bus_figure7_table9.m"
    ];
    audit.CoreSources = inspect_files(root, sourceNames);

    figureNames = "outputs/figures/Figure_" + string((2:7).') + ".png";
    pdfNames = "outputs/figures/Figure_" + string((2:7).') + ".pdf";
    csvNames = "outputs/tables/Table_" + string((4:9).') + ".csv";
    texNames = "outputs/tables/Table_" + string((4:9).') + ".tex";
    chartDataNames = [
        "outputs/tables/Figure_5_data.csv"
        "outputs/tables/Figure_6_data.csv"
        "outputs/tables/Figure_7_data.csv"
    ];
    audit.PublishedOutputs = inspect_files(root, ...
        [figureNames; pdfNames; csvNames; texNames; chartDataNames]);

    cacheNames = [
        "segan_inputs.mat"
        "segan_5bus_opf.mat"
        "segan_5bus_metrics.mat"
        "segan_5bus_clusters.mat"
        "segan_57bus_screening_baseline.mat"
        "segan_57bus_ccw_probes.mat"
        "segan_57bus_ecw_fcw_probes.mat"
        "segan_57bus_screening_ranks.mat"
        "segan_57bus_single_g5_ccw_pilot.mat"
        "segan_57bus_double_g5_g7_ccw_pilot.mat"
        "segan_57bus_single_g5_library.mat"
        "segan_57bus_double_g5_g7_library.mat"
        "segan_57bus_single_g5_features.mat"
        "segan_57bus_double_g5_g7_features.mat"
        "segan_57bus_feature_manifest.mat"
        "segan_57bus_single_g5_clusters.mat"
        "segan_57bus_double_g5_g7_clusters.mat"
        "segan_57bus_cluster_manifest.mat"
        "segan_57bus_k_sensitivity.mat"
        "segan_57bus_feature_ablation.mat"
    ];
    audit.CacheFiles = inspect_files(cacheRoot, cacheNames);

    entryNames = [
        "reproduce_all.m"
        "validate_results.m"
        "run_demo.m"
        "tests/test_reproduction.m"
    ];
    audit.EntryPoints = inspect_files(root, entryNames);

    inactiveScaffolds = [
        "src/+segan/run_57bus_scenarios.m"
        "src/+segan/select_57bus_generators.m"
        "src/+segan/check_k_sensitivity.m"
        "src/+segan/check_robustness_ablation.m"
    ];
    audit.LegacyScaffolds = inspect_files(root, inactiveScaffolds);

    [audit.LibraryIntegrity, allLibrariesPass] = inspect_libraries(cacheRoot);
    audit.Dependencies = dependency_inventory();
    audit.Portability = scan_matlab_sources(root);

    readmePath = fullfile(root, 'README.md');
    readmeCurrent = false;
    if isfile(readmePath)
        readme = fileread(readmePath);
        readmeCurrent = ~contains(readme, ...
            'Status: Clean project structure only.');
    end
    audit.Documentation = table( ...
        ["README is updated"; "Repository LICENSE is declared"; ...
         "Input sourcing and licensing is documented"], ...
        [readmeCurrent; isfile(fullfile(root, 'LICENSE')); ...
         isfile(fullfile(root, 'DATA_SOURCES.md'))], ...
        'VariableNames', {'Check', 'Passed'});

    audit.Validation = struct();
    audit.Validation.RawInputsPresent = all(audit.RawInputs.PresentAndNonempty);
    audit.Validation.CoreSourcesPresent = all(audit.CoreSources.PresentAndNonempty);
    audit.Validation.PublishedOutputsPresent = ...
        all(audit.PublishedOutputs.PresentAndNonempty);
    audit.Validation.CacheFilesPresent = ...
        all(audit.CacheFiles.PresentAndNonempty);
    audit.Validation.LibraryReferencesValid = allLibrariesPass;
    audit.Validation.MatlabSourcesPortable = audit.Portability.AllPassed;
    audit.Validation.RequiredDependenciesFound = ...
        all(audit.Dependencies.Found(1:3));
    audit.Validation.EntryPointsImplemented = ...
        all(audit.EntryPoints.PresentAndNonempty);
    audit.Validation.DocumentationComplete = ...
        all(audit.Documentation.Passed);
    audit.Validation.NoUnusedEmptyScaffolds = ...
        all(~audit.LegacyScaffolds.Exists | ...
            audit.LegacyScaffolds.PresentAndNonempty);
    audit.Validation.DataRedistributionCleared = false;
    audit.Validation.ReadOnly = true;
    audit.Validation.ReproductionEvidencePresent = ...
        audit.Validation.RawInputsPresent && ...
        audit.Validation.CoreSourcesPresent && ...
        audit.Validation.PublishedOutputsPresent && ...
        audit.Validation.CacheFilesPresent && ...
        audit.Validation.LibraryReferencesValid && ...
        audit.Validation.MatlabSourcesPortable;
    audit.Validation.ReadyForPublicRelease = ...
        audit.Validation.ReproductionEvidencePresent && ...
        audit.Validation.RequiredDependenciesFound && ...
        audit.Validation.EntryPointsImplemented && ...
        audit.Validation.DocumentationComplete && ...
        audit.Validation.NoUnusedEmptyScaffolds && ...
        audit.Validation.DataRedistributionCleared;

    fprintf('\nVerification inventory (presence only, not a full rerun):\n');
    fprintf(' Raw inputs          : %d/%d\n', ...
        nnz(audit.RawInputs.PresentAndNonempty), height(audit.RawInputs));
    fprintf(' Core MATLAB sources : %d/%d\n', ...
        nnz(audit.CoreSources.PresentAndNonempty), height(audit.CoreSources));
    fprintf(' Publication files   : %d/%d\n', ...
        nnz(audit.PublishedOutputs.PresentAndNonempty), ...
        height(audit.PublishedOutputs));
    fprintf(' Cache artifacts     : %d/%d\n', ...
        nnz(audit.CacheFiles.PresentAndNonempty), ...
        height(audit.CacheFiles));
    fprintf(' Scenario references : %d/%d\n', ...
        nnz(audit.LibraryIntegrity.Valid), height(audit.LibraryIntegrity));
    fprintf(' Implemented entrypoints: %d/%d\n', ...
        nnz(audit.EntryPoints.PresentAndNonempty), ...
        height(audit.EntryPoints));
    fprintf(' Source portability  : %s\n', ...
        pass_fail(audit.Validation.MatlabSourcesPortable));
    fprintf(' Repository release ready: %s\n', ...
        pass_fail(audit.Validation.ReadyForPublicRelease));
    fprintf(' Raw input redistribution permissions require manual review.\n');
    fprintf(' This audit does not rerun the study or alter files.\n');
    fprintf('=== SEGAN Stage 11A completed ===\n\n');
end

function results = inspect_files(base, relativeNames)
    names = string(relativeNames(:));
    n = numel(names);
    exists = false(n,1);
    nonempty = false(n,1);
    bytes = zeros(n,1);
    for k = 1:n
        path = portable_join(base, names(k));
        exists(k) = isfile(path);
        if exists(k)
            details = dir(path);
            if ~isempty(details)
                bytes(k) = details(1).bytes;
                nonempty(k) = bytes(k) > 0;
            end
        end
    end
    results = table(names,exists,nonempty,bytes,exists & nonempty, ...
        'VariableNames', {'RelativeFile','Exists','Nonempty','Bytes', ...
                           'PresentAndNonempty'});
end

function path = portable_join(base, relativeName)
    pathParts = regexp(char(relativeName), '[\\/]', 'split');
    path = fullfile(base, pathParts{:});
end

function [details, valid] = inspect_libraries(cacheRoot)
    configs = ["Single_G5"; "Double_G5G7"];
    files = ["segan_57bus_single_g5_library.mat"; ...
             "segan_57bus_double_g5_g7_library.mat"];
    exists = false(2,1);
    passed = false(2,1);
    scenarioCount = zeros(2,1);
    totalHours = zeros(2,1);
    checkedReferences = zeros(2,1);
    missingReferences = zeros(2,1);
    for c = 1:2
        path = fullfile(cacheRoot, char(files(c)));
        exists(c) = isfile(path);
        if ~exists(c)
            continue;
        end
        try
            input = load(path, 'library');
            if ~isfield(input,'library') || ...
                    ~isfield(input.library,'ScenarioSummary') || ...
                    ~isfield(input.library,'Validation') || ...
                    ~isfield(input.library.Validation,'AllPassed')
                continue;
            end
            lib = input.library;
            summary = lib.ScenarioSummary;
            scenarioCount(c) = height(summary);
            if ~all(ismember({'RelativeFile','SolvedHours'}, ...
                    summary.Properties.VariableNames))
                continue;
            end
            totalHours(c) = sum(summary.SolvedHours);
            for k = 1:height(summary)
                file = portable_join(cacheRoot,summary.RelativeFile(k));
                if isfile(file)
                    info = dir(file);
                    if ~isempty(info) && info(1).bytes > 0
                        checkedReferences(c) = checkedReferences(c)+1;
                    else
                        missingReferences(c) = missingReferences(c)+1;
                    end
                else
                    missingReferences(c) = missingReferences(c)+1;
                end
            end
            passed(c) = lib.Validation.AllPassed && ...
                scenarioCount(c)==16 && totalHours(c)==34560 && ...
                checkedReferences(c)==16 && missingReferences(c)==0;
        catch err
            fprintf(' Library audit issue for %s: %s\n', ...
                char(configs(c)),err.message);
        end
    end
    details = table(configs,files,exists,scenarioCount,totalHours, ...
        checkedReferences,missingReferences,passed, ...
        'VariableNames', {'Configuration','Manifest','Exists', ...
        'Scenarios','ScenarioHours','ValidFileReferences', ...
        'MissingFileReferences','Valid'});
    valid = all(passed);
end

function dependencies = dependency_inventory()
    names = ["MATLAB"; "MATPOWER rundcopf"; ...
        "Statistics Toolbox kmeans"; "PCA function"; ...
        "Gurobi MATLAB interface (optional)"];
    found = [~isempty(which('version')); ...
        ~isempty(which('rundcopf')); ~isempty(which('kmeans')); ...
        ~isempty(which('pca')); ~isempty(which('gurobi'))];
    dependencies = table(names,logical(found), ...
        'VariableNames',{'Dependency','Found'});
end

function portability = scan_matlab_sources(root)
    sourceDir = fullfile(root,'src','+segan');
    inventory = dir(fullfile(sourceDir,'*.m'));
    names = strings(numel(inventory)+1,1);
    hasAbsolutePaths = false(numel(inventory)+1,1);
    hasNonAscii = false(numel(inventory)+1,1);
    for k=1:numel(inventory)+1
        if k <= numel(inventory)
            names(k) = "src/+segan/" + string(inventory(k).name);
        else
            names(k) = "config/reproduction_config.m";
        end
        path = portable_join(root,names(k));
        if ~isfile(path)
            continue;
        end
        sourceText = fileread(path);
        % Require a drive-letter boundary and a path segment to avoid
        % mistaking fprintf labels and newline escapes for absolute paths.
        windowsPath = ~isempty(regexp(sourceText, ...
            '(?<![A-Za-z0-9_])[A-Za-z]:[\\/][A-Za-z0-9_.-]{2,}', ...
            'once'));
        % Construct Unix home-directory patterns from separate literals so
        % the audit source does not match its own search pattern.
        unixHomePath = contains(sourceText, ['/' 'Users' '/']) || ...
            contains(sourceText, ['/' 'home' '/']);
        hasAbsolutePaths(k) = windowsPath || unixHomePath;
        hasNonAscii(k) = any(double(sourceText) > 127);
    end
    portability = struct();
    portability.Files = table(names,hasAbsolutePaths,hasNonAscii, ...
        'VariableNames',{'SourceFile','ContainsPersonalPathPattern', ...
        'ContainsNonAsciiCharacters'});
    portability.AllPassed = ~any(hasAbsolutePaths | hasNonAscii);
end

function result = pass_fail(value)
    if value
        result = 'YES';
    else
        result = 'NO';
    end
end
