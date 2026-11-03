function report = reproduce_all(mode)
%REPRODUCE_ALL Orchestrate the SEGAN study in a clean repository copy.
%   REPORT = REPRODUCE_ALL('plan') inspects prerequisites and existing
%   generated files WITHOUT running models or writing any files.
%
%   REPORT = REPRODUCE_ALL('quick_plan') inspects saved checkpoint readiness.
%   REPORT = REPRODUCE_ALL('quick') regenerates Figures 2-7 and Tables 4-9
%   from validated MAT checkpoints into quick_reproduction/outputs/.
%
%   REPORT = REPRODUCE_ALL() or REPRODUCE_ALL('full') executes all stages,
%   including the generator screening experiments, both 57-bus strategies,
%   clustering, sensitivity analysis, and all publication exports.
%
%   SAFETY: Full mode REFUSES to start unless outputs/ contains no regular
%   files. Run it only in a fresh repository copy. It never deletes, clears,
%   or overwrites the existing research results in an occupied repository.
%   The original publication Figure 1 is intentionally excluded.
%
%   This function requires MATLAB, MATPOWER, and Statistics and Machine
%   Learning Toolbox. Results are checked against publication values only
%   after the corresponding calculations. No historical study outputs are
%   imported as scientific evidence.

    if nargin < 1
        mode = 'full';
    end
    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('SEGAN:InvalidRunMode', 'Mode must be plan, full, quick_plan, or quick.');
    end
    mode = lower(strtrim(char(mode)));
    if ~ismember(mode, {'plan','full','quick','quick_plan'})
        error('SEGAN:InvalidRunMode', 'Mode must be plan, full, quick_plan, or quick.');
    end

    root = fileparts(mfilename('fullpath'));
    addpath(fullfile(root, 'config'));
    addpath(fullfile(root, 'src'));
    cfg = reproduction_config();
    if ~strcmp(char(cfg.paths.project), root)
        error('SEGAN:WrongRepository', ...
            'The configuration points to a different repository.');
    end

    % Quick mode uses validated MAT checkpoints and a separate output tree.
    % It never calls OPF, K-means, or the full-reproduction stage chain.
    if ismember(mode, {'quick','quick_plan'})
        report = segan.export_quick_results(cfg, mode);
        return;
    end

    stages = { ...
        'Stage 1', 'Stage 2', 'Stage 3', 'Stage 4', 'Stage 5', ...
        'Stage 6A', 'Stage 6B', 'Stage 6C', 'Stage 6D', 'Stage 6E', ...
        'Stage 7A', 'Stage 7B', 'Stage 7C', 'Stage 7D', ...
        'Stage 8A', 'Stage 8B', 'Stage 8C', 'Stage 8D', 'Stage 8E', ...
        'Stage 9A', 'Stage 9B', 'Stage 10A', 'Stage 10B'};
    operations = { ...
        'prepare_inputs', 'run_5bus_scenarios', ...
        'compute_economic_network_metrics', 'build_features_and_cluster', ...
        'export_figures_and_tables', 'run_57bus_baseline', ...
        'run_57bus_ccw_probes', 'run_57bus_ecw_fcw_probes', ...
        'complete_57bus_screening', 'export_57bus_table4', ...
        'run_57bus_single_g5_pilot', 'run_57bus_single_g5_library', ...
        'run_57bus_double_g5_g7_pilot', ...
        'run_57bus_double_g5_g7_library', ...
        'build_57bus_feature_libraries', 'cluster_57bus_states', ...
        'export_57bus_figure3_table6', 'export_57bus_figure4_table7', ...
        'export_57bus_figure5', 'analyze_57bus_k_sensitivity', ...
        'export_57bus_figure6_table8', ...
        'analyze_57bus_feature_ablation', ...
        'export_57bus_figure7_table9'};
    filenames = strcat('src/+segan/', string(operations(:)), '.m');
    present = false(numel(filenames),1);
    for i = 1:numel(filenames)
        present(i) = isfile(fullfile(root, strrep(char(filenames(i)), '/', filesep)));
    end
    rawFiles = {cfg.files.ames5, cfg.files.case57, cfg.files.pglib57, ...
        cfg.files.turkeyLoad};
    rawPresent = cellfun(@isfile, rawFiles);
    outputsRoot = fullfile(root, 'outputs');
    existing = generated_files(outputsRoot);
    cleanOutput = isempty(existing);
    dependencies = [exist('loadcase','file')==2, ...
                    exist('rundcopf','file')==2, ...
                    exist('kmeans','file')==2, ...
                    exist('pca','file')==2, ...
                    exist('statset','file')==2];

    report = struct();
    report.Mode = mode;
    report.Stages = table(string(stages(:)), string(operations(:)), ...
        present, 'VariableNames', {'Stage','Function','SourcePresent'});
    report.RawInputsPresent = all(rawPresent);
    report.DependenciesPresent = all(dependencies);
    report.OutputTreeClean = cleanOutput;
    report.ExistingOutputFiles = string(existing(:));
    report.SafeToStartFreshRun = all(present) && ...
        report.RawInputsPresent && report.DependenciesPresent && cleanOutput;
    report.Completed = false;

    fprintf('\n=== SEGAN reproduction entrypoint ===\n');
    fprintf('Mode: %s | Available modules: %d/%d\n', mode, ...
        nnz(present), numel(present));
    fprintf('Raw inputs: %d/%d | Tool dependencies: %d/%d\n', ...
        nnz(rawPresent),numel(rawPresent), ...
        nnz(dependencies),numel(dependencies));
    fprintf('Outputs tree clean: %s\n', logical_text(cleanOutput));
    if ~cleanOutput
        fprintf('Existing generated files: %d\n',numel(existing));
        fprintf('Full mode will refuse to overwrite these files.\n');
    end

    if strcmp(mode,'plan')
        fprintf('Plan mode finished: no computations or file changes.\n');
        fprintf('Fresh-run readiness: %s\n', ...
            logical_text(report.SafeToStartFreshRun));
        return;
    end
    if ~report.SafeToStartFreshRun
        error('SEGAN:FreshRunUnsafe', [ ...
            'Fresh reproduction is blocked. Inspect reproduce_all(''plan''). ' ...
            'Do not run full mode in a repository containing generated results. ' ...
            'Use a separate clean repository copy with the four authorized inputs.']);
    end
    if ~isfile(fullfile(root,'validate_results.m'))
        error('SEGAN:MissingValidator', ...
            'The validate_results.m entrypoint is required.');
    end

    fprintf('Beginning a clean, full computation. Figure 1 is excluded.\n');
    inputs = segan.prepare_inputs(cfg);
    opf5 = segan.run_5bus_scenarios(cfg,inputs);
    metrics5 = segan.compute_economic_network_metrics(cfg,inputs,opf5);
    states5 = segan.build_features_and_cluster(cfg,inputs,opf5,metrics5);
    require_pass(states5.FiveBus.Table5Comparison.AllPass, 'Stage 4 Table 5');
    report5 = segan.export_figures_and_tables(cfg,states5);
    require_pass(report5.Table5PassedChecks == report5.Table5TotalChecks && ...
        report5.Table5TotalChecks == 10, 'Stage 5 publication export');
    clear opf5 metrics5 states5 report5;

    baseline = segan.run_57bus_baseline(cfg,inputs);
    require_pass(baseline.Validation.AllPassed, 'Stage 6A baseline');
    clear baseline;
    ccw = segan.run_57bus_ccw_probes(cfg,inputs);
    require_pass(ccw.Validation.AllPassed, 'Stage 6B CCW probes');
    clear ccw;
    probes = segan.run_57bus_ecw_fcw_probes(cfg,inputs);
    require_pass(probes.Validation.AllPassed, 'Stage 6C ECW/FCW probes');
    clear probes;
    ranks = segan.complete_57bus_screening(cfg,inputs);
    require_pass(ranks.Validation.AllPassed, 'Stage 6D screening ranks');
    table4 = segan.export_57bus_table4(cfg,ranks);
    require_pass(table4.RanksMatched == 7 && table4.TotalRanks == 7, ...
        'Stage 6E Table 4 export');
    clear ranks table4;

    pilotSingle = segan.run_57bus_single_g5_pilot(cfg,inputs);
    require_pass(pilotSingle.Validation.AllPassed, 'Stage 7A Single-G5 pilot');
    clear pilotSingle;
    singleLibrary = segan.run_57bus_single_g5_library(cfg,inputs);
    require_pass(singleLibrary.Validation.AllPassed, 'Stage 7B Single-G5 library');
    clear singleLibrary;
    pilotDouble = segan.run_57bus_double_g5_g7_pilot(cfg,inputs);
    require_pass(pilotDouble.Validation.AllPassed, 'Stage 7C Double-G5/G7 pilot');
    clear pilotDouble;
    doubleLibrary = segan.run_57bus_double_g5_g7_library(cfg,inputs);
    require_pass(doubleLibrary.Validation.AllPassed, 'Stage 7D Double-G5/G7 library');
    clear doubleLibrary inputs;

    feat = segan.build_57bus_feature_libraries(cfg, ...
        load_prepared_inputs(cfg));
    require_pass(feat.Validation.AllPassed, 'Stage 8A hourly features');
    clear feat;
    states = segan.cluster_57bus_states(cfg);
    require_pass(states.Validation.AllPassed, 'Stage 8B K=2 states');
    clear states;
    fig3 = segan.export_57bus_figure3_table6(cfg);
    require_pass(fig3.Validation.AllPassed, 'Stage 8C Figure 3 / Table 6');
    clear fig3;
    fig4 = segan.export_57bus_figure4_table7(cfg);
    require_pass(fig4.Validation.AllPassed, 'Stage 8D Figure 4 / Table 7');
    clear fig4;
    fig5 = segan.export_57bus_figure5(cfg);
    require_pass(fig5.Validation.AllPassed, 'Stage 8E Figure 5');
    clear fig5;

    sensitivity = segan.analyze_57bus_k_sensitivity(cfg);
    require_pass(sensitivity.Validation.AllPassed, 'Stage 9A K-sensitivity');
    clear sensitivity;
    fig6 = segan.export_57bus_figure6_table8(cfg);
    require_pass(fig6.Validation.AllPassed, 'Stage 9B Figure 6 / Table 8');
    clear fig6;
    ablation = segan.analyze_57bus_feature_ablation(cfg);
    require_pass(ablation.Validation.AllPassed, 'Stage 10A ablation');
    clear ablation;
    fig7 = segan.export_57bus_figure7_table9(cfg);
    require_pass(fig7.Validation.AllPassed, 'Stage 10B Figure 7 / Table 9');
    clear fig7;

    finalCheck = validate_results();
    require_pass(finalCheck.Validation.AllPassed, ...
        'Post-run reproduction validation');
    report.Completed = true;
    report.Validation = finalCheck.Validation;
    fprintf('=== SEGAN complete reproduction passed ===\n');
end

function inputs = load_prepared_inputs(cfg)
    data = load(cfg.files.preparedInputs,'inputs');
    if ~isfield(data,'inputs')
        error('SEGAN:MissingPreparedInputs', ...
            'Stage 1 prepared input variable is missing.');
    end
    inputs = data.inputs;
end

function require_pass(condition,label)
    if ~isscalar(condition) || ~logical(condition)
        error('SEGAN:StageVerificationFailed', ...
            'Validation failed at %s. Existing outputs have been preserved.',label);
    end
end

function files = generated_files(root)
    files = {};
    if ~isfolder(root)
        return;
    end
    queue = {root};
    while ~isempty(queue)
        current = queue{end};
        queue(end) = [];
        entries = dir(current);
        for j = 1:numel(entries)
            name = entries(j).name;
            if strcmp(name,'.') || strcmp(name,'..')
                continue;
            end
            fullName = fullfile(current,name);
            if entries(j).isdir
                queue{end+1} = fullName; %#ok<AGROW>
            else
                files{end+1,1} = fullName; %#ok<AGROW>
            end
        end
    end
end

function str = logical_text(value)
    if value
        str = 'YES';
    else
        str = 'NO';
    end
end
