function report = export_quick_results(cfg, mode)
%EXPORT_QUICK_RESULTS Regenerate publication figures/tables from saved MAT data.
%   REPORT = SEGAN.EXPORT_QUICK_RESULTS(CFG,'quick_plan') checks the saved
%   checkpoint library and intended destinations without writing any files.
%   REPORT = SEGAN.EXPORT_QUICK_RESULTS(CFG,'quick') generates Figures 2-7
%   and Tables 4-9 in quick_reproduction/outputs/ under the repository.
%
%   The original outputs/cache/ records are READ-ONLY. This function does
%   not run DC-OPF, K-means, or any feature-library reconstruction. PCA
%   projections and lightweight figure/table statistics are reconstructed
%   from the validated numerical checkpoints by existing export functions.
%
%   A quick run is refused if any file already exists in its destination
%   directory. Original paper outputs under outputs/ are never overwritten.
%   Figure 1 is manual and intentionally excluded.

    if nargin ~= 2 || ~isstruct(cfg) || ~isfield(cfg,'paths') || ...
            ~isfield(cfg.paths,'project') || ~isfield(cfg.paths,'cache')
        error('SEGAN:QuickInvalidConfig', ...
            'Pass a portable reproduction_config structure and a quick mode.');
    end
    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('SEGAN:QuickInvalidMode', 'Mode must be quick or quick_plan.');
    end
    mode = lower(strtrim(char(mode)));
    if ~ismember(mode, {'quick','quick_plan'})
        error('SEGAN:QuickInvalidMode', 'Mode must be quick or quick_plan.');
    end

    originalRoot = char(cfg.paths.project);
    originalCache = char(cfg.paths.cache);
    quickRoot = fullfile(originalRoot,'quick_reproduction');
    quickOutputRoot = fullfile(quickRoot,'outputs');

    requiredMatNames = { ...
        'segan_5bus_clusters.mat', ...
        'segan_57bus_screening_ranks.mat', ...
        'segan_57bus_single_g5_library.mat', ...
        'segan_57bus_double_g5_g7_library.mat', ...
        'segan_57bus_feature_manifest.mat', ...
        'segan_57bus_cluster_manifest.mat', ...
        'segan_57bus_single_g5_features.mat', ...
        'segan_57bus_double_g5_g7_features.mat', ...
        'segan_57bus_single_g5_clusters.mat', ...
        'segan_57bus_double_g5_g7_clusters.mat', ...
        'segan_57bus_k_sensitivity.mat', ...
        'segan_57bus_feature_ablation.mat'};
    matPaths = cellfun(@(name) fullfile(originalCache,name), ...
        requiredMatNames,'UniformOutput',false);
    matPresent = cellfun(@isfile,matPaths);

    exporterNames = { ...
        'export_figures_and_tables', ...
        'export_57bus_table4', ...
        'export_57bus_figure3_table6', ...
        'export_57bus_figure4_table7', ...
        'export_57bus_figure5', ...
        'export_57bus_figure6_table8', ...
        'export_57bus_figure7_table9'};
    sourcePaths = cellfun(@(name) fullfile(originalRoot, ...
        'src','+segan',[name '.m']),exporterNames,'UniformOutput',false);
    sourcesPresent = cellfun(@isfile,sourcePaths);
    pcaAvailable = exist('pca','file') == 2;
    quickExistingFiles = list_regular_files(quickRoot);
    outputTreeClean = isempty(quickExistingFiles);

    report = struct();
    report.Mode = mode;
    report.OriginalCache = originalCache;
    report.QuickOutputRoot = quickOutputRoot;
    report.RequiredMAT = table(string(requiredMatNames(:)), ...
        logical(matPresent(:)), 'VariableNames',{'File','Present'});
    report.Exporters = table(string(exporterNames(:)), ...
        logical(sourcesPresent(:)), 'VariableNames',{'Function','SourcePresent'});
    report.PCAAvailable = pcaAvailable;
    report.QuickOutputTreeClean = outputTreeClean;
    report.ExistingQuickFiles = string(quickExistingFiles(:));
    report.SafeToStartQuickRun = all(matPresent) && ...
        all(sourcesPresent) && pcaAvailable && outputTreeClean;
    report.Completed = false;

    fprintf('\n=== SEGAN quick reproduction ===\n');
    fprintf('Mode: %s | Required MAT checkpoints: %d/%d\n',mode, ...
        nnz(matPresent),numel(matPresent));
    fprintf('Exporter sources: %d/%d | PCA: %s\n', ...
        nnz(sourcesPresent),numel(sourcesPresent),yesno(pcaAvailable));
    fprintf('Quick destination clean: %s\n',yesno(outputTreeClean));
    fprintf('Cache source: outputs/cache/ (read-only)\n');
    fprintf('Destination: quick_reproduction/outputs/\n');
    fprintf('No OPF, K-means, or feature-library rebuild. Figure 1 excluded.\n');

    if strcmp(mode,'quick_plan')
        fprintf('Plan complete: no file changes. Ready: %s\n', ...
            yesno(report.SafeToStartQuickRun));
        return;
    end
    if ~report.SafeToStartQuickRun
        error('SEGAN:QuickUnsafe', [ ...
            'Quick reproduction is blocked. Check reproduce_all(''quick_plan''). ' ...
            'Do not delete or overwrite existing generated results. ' ...
            'Quick Mode requires complete MAT checkpoints and an empty ' ...
            'quick_reproduction directory.']);
    end

    % Source data stay in the ORIGINAL validated cache while all writes are
    % redirected to a wholly separate, initially empty directory.
    cfgQuick = cfg;
    cfgQuick.paths.project = quickRoot;
    cfgQuick.paths.cache = originalCache;

    stage4 = load(matPaths{1},'output');
    if ~isfield(stage4,'output') || ~isstruct(stage4.output) || ...
            ~isfield(stage4.output,'FiveBus') || ...
            ~isfield(stage4.output.FiveBus,'Table5Comparison') || ...
            ~stage4.output.FiveBus.Table5Comparison.AllPass
        error('SEGAN:QuickUnvalidatedFiveBus', ...
            'The saved Stage 4 five-bus clusters failed validation.');
    end
    stage6 = load(matPaths{2},'result');
    if ~isfield(stage6,'result') || ~isstruct(stage6.result) || ...
            ~isfield(stage6.result,'Validation') || ...
            ~stage6.result.Validation.AllPassed
        error('SEGAN:QuickUnvalidatedScreening', ...
            'The saved Stage 6D screening ranks failed validation.');
    end

    fprintf('Rendering from validated MAT checkpoints only...\n');
    r2 = segan.export_figures_and_tables(cfgQuick,stage4.output);
    assert_pass(r2.Table5PassedChecks == 10 && ...
        r2.Table5TotalChecks == 10,'Figure 2 / Table 5');
    clear stage4;

    r4 = segan.export_57bus_table4(cfgQuick,stage6.result);
    assert_pass(r4.RanksMatched == 7 && r4.TotalRanks == 7,'Table 4');
    clear stage6;

    r3 = segan.export_57bus_figure3_table6(cfgQuick);
    assert_pass(r3.Validation.AllPassed,'Figure 3 / Table 6');
    r4fig = segan.export_57bus_figure4_table7(cfgQuick);
    assert_pass(r4fig.Validation.AllPassed,'Figure 4 / Table 7');
    r5 = segan.export_57bus_figure5(cfgQuick);
    assert_pass(r5.Validation.AllPassed,'Figure 5');
    r6 = segan.export_57bus_figure6_table8(cfgQuick);
    assert_pass(r6.Validation.AllPassed,'Figure 6 / Table 8');
    r7 = segan.export_57bus_figure7_table9(cfgQuick);
    assert_pass(r7.Validation.AllPassed,'Figure 7 / Table 9');

    figNames = strcat('Figure_',string((2:7).'));
    tabNames = strcat('Table_',string((4:9).'));
    pngPaths = fullfile(quickOutputRoot,'figures',figNames + '.png');
    pdfPaths = fullfile(quickOutputRoot,'figures',figNames + '.pdf');
    csvPaths = fullfile(quickOutputRoot,'tables',tabNames + '.csv');
    texPaths = fullfile(quickOutputRoot,'tables',tabNames + '.tex');
    extraNames = ["Figure_5_data.csv";"Figure_6_data.csv"; ...
                  "Figure_7_data.csv"];
    extraPaths = fullfile(quickOutputRoot,'tables',extraNames);
    paths = [pngPaths(:);pdfPaths(:);csvPaths(:);texPaths(:);extraPaths(:)];
    present = false(numel(paths),1);
    nonempty = false(numel(paths),1);
    for i = 1:numel(paths)
        present(i) = isfile(paths(i));
        if present(i)
            fileDetail = dir(paths(i));
            nonempty(i) = isscalar(fileDetail) && fileDetail.bytes > 0;
        end
    end
    assert_pass(numel(paths)==27 && all(present) && all(nonempty), ...
        'Complete Quick Mode publication-output inventory');

    report.GeneratedFiles = table(paths,present,nonempty, ...
        'VariableNames',{'AbsolutePath','Exists','Nonempty'});
    report.Validation = struct( ...
        'FiveBusTable5Checks',10, ...
        'ScreeningRanksMatched',7, ...
        'Figure3Table6Passed',logical(r3.Validation.AllPassed), ...
        'Figure4Table7Passed',logical(r4fig.Validation.AllPassed), ...
        'Figure5Passed',logical(r5.Validation.AllPassed), ...
        'Figure6Table8Passed',logical(r6.Validation.AllPassed), ...
        'Figure7Table9Passed',logical(r7.Validation.AllPassed), ...
        'FigureCount',6, ...
        'TableCount',6, ...
        'PublicationOutputFiles',numel(paths), ...
        'AllPassed',all(present) && all(nonempty));
    report.Completed = report.Validation.AllPassed;
    fprintf('Quick Mode generated 6 figures and 6 tables: 27/27 files.\n');
    fprintf('Original outputs/cache, outputs/figures and outputs/tables untouched.\n');
    fprintf('=== SEGAN quick reproduction completed ===\n\n');
end

function assert_pass(condition,context)
    if ~isscalar(condition) || ~logical(condition)
        error('SEGAN:QuickValidationFailed', ...
            'Saved-data export validation failed at: %s.',context);
    end
end

function files = list_regular_files(root)
    files = {};
    if ~isfolder(root), return; end
    queue = {root};
    while ~isempty(queue)
        current = queue{end};
        queue(end) = [];
        entries = dir(current);
        for i = 1:numel(entries)
            name = entries(i).name;
            if strcmp(name,'.') || strcmp(name,'..'), continue; end
            fullName = fullfile(current,name);
            if entries(i).isdir
                queue{end+1} = fullName; %#ok<AGROW>
            else
                files{end+1,1} = fullName; %#ok<AGROW>
            end
        end
    end
end

function label = yesno(flag)
    if flag, label='YES'; else, label='NO'; end
end
