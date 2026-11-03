function report = export_figures_and_tables(cfg, states)
%EXPORT_FIGURES_AND_TABLES Export verified five-bus paper outputs.
%   REPORT = SEGAN.EXPORT_FIGURES_AND_TABLES(CFG, STATES) generates the
%   published Figure 2 PCA projection and Table 5 state signatures using
%   the new Stage 4 clustering output. It does not load historical results,
%   solve OPF cases, compute economic metrics, or run K-means again.
%
%   The five-bus export is the first supported reporting module. Further
%   figures and tables will be added after independent stage validation.
%
%   Required toolbox: Statistics and Machine Learning Toolbox (PCA).

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(states)
        error('SEGAN:InvalidExportInput', ...
            'Pass the portable configuration and new Stage 4 output.');
    end
    if ~isfield(states, 'FiveBus') || ...
            ~isfield(states.FiveBus, 'FeatureTableWithStates') || ...
            ~isfield(states.FiveBus, 'Main') || ...
            ~isfield(states.FiveBus, 'StateSignature') || ...
            ~isfield(states.FiveBus, 'Table5Comparison')
        error('SEGAN:InvalidExportInput', ...
            'The supplied structure is not a complete Stage 4 result.');
    end
    if exist('pca', 'file') ~= 2
        error('SEGAN:MissingStatisticsToolbox', ...
            'PCA requires MATLAB Statistics and Machine Learning Toolbox.');
    end
    if ~states.FiveBus.Table5Comparison.AllPass
        error('SEGAN:UnvalidatedTable5', ...
            'Published Table 5 validation must pass before exporting.');
    end

    projectRoot = cfg.paths.project;
    figureDir = fullfile(projectRoot, 'outputs', 'figures');
    tableDir = fullfile(projectRoot, 'outputs', 'tables');
    if ~isfolder(figureDir)
        mkdir(figureDir);
    end
    if ~isfolder(tableDir)
        mkdir(tableDir);
    end

    ft = states.FiveBus.FeatureTableWithStates;
    featureNames = states.FiveBus.Main.ActiveFeatureNames;
    selected = ft.IsUsedForKMeans;
    assert(istable(ft) && numel(selected) == height(ft), ...
        'Stage 4 feature table or clustering mask is invalid.');
    assert(all(ismember(featureNames, ft.Properties.VariableNames)), ...
        'At least one Stage 4 active feature is missing.');
    assert(nnz(selected) == 384, ...
        'Figure 2 expects exactly 384 valid five-bus observations.');

    % Match the source publication's PCA method: standardize retained
    % Stage 4 features once more, then apply SVD-based PCA for projection.
    raw = ft{selected, featureNames};
    if any(~isfinite(raw), 'all')
        error('SEGAN:InvalidPCAData', ...
            'PCA input must have no nonfinite feature values.');
    end
    mu = mean(raw, 1);
    sigma = std(raw, 0, 1);
    keep = isfinite(sigma) & sigma > 1e-10;
    assert(nnz(keep) >= 2, 'PCA needs at least two varying features.');
    z = (raw(:, keep) - mu(keep)) ./ sigma(keep);
    [~, pcScores, latent] = pca(z, 'Algorithm', 'svd');
    assert(size(pcScores, 2) >= 2 && sum(latent) > 0, ...
        'PCA could not determine two principal components.');
    explained = 100 * latent(1:2) / sum(latent);

    names = string(ft.StateName(selected));
    moderate = names == "ModerateStress";
    high = names == "HighProfit";
    assert(all(moderate | high) && any(moderate) && any(high), ...
        'The five-bus state labels are invalid or incomplete.');

    fprintf('\n=== SEGAN Stage 5: Five-bus figure and table export ===\n');
    fprintf('Source: newly generated Stage 4 data.\n');
    fprintf('No old figures, OPF reruns, or new clustering are used.\n');
    fprintf('PCA explained variance: PC1 %.2f%%; PC2 %.2f%%\n', ...
        explained(1), explained(2));

    figurePng = fullfile(figureDir, 'Figure_2.png');
    figurePdf = fullfile(figureDir, 'Figure_2.pdf');
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [100 100 1200 830], ...
        'MenuBar', 'none', 'ToolBar', 'none');
    closeFigure = onCleanup(@() close(fig)); %#ok<NASGU>
    ax = axes('Parent', fig);
    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    scatter(ax, pcScores(moderate, 1), pcScores(moderate, 2), ...
        65, 'o', 'filled', 'MarkerFaceColor', [0.08 0.36 0.78], ...
        'MarkerEdgeColor', [0.10 0.10 0.10], ...
        'MarkerFaceAlpha', 0.92, 'LineWidth', 0.7, ...
        'DisplayName', 'Moderate state');
    scatter(ax, pcScores(high, 1), pcScores(high, 2), ...
        65, 'o', 'filled', 'MarkerFaceColor', [0.88 0.23 0.16], ...
        'MarkerEdgeColor', [0.10 0.10 0.10], ...
        'MarkerFaceAlpha', 0.92, 'LineWidth', 0.7, ...
        'DisplayName', 'High-profit state');
    xlabel(ax, sprintf('PC 1 (%.1f%%)', explained(1)), ...
        'Interpreter', 'none');
    ylabel(ax, sprintf('PC 2 (%.1f%%)', explained(2)), ...
        'Interpreter', 'none');
    legend(ax, 'Location', 'northeast', 'Box', 'off');
    set(ax, 'FontName', 'Times New Roman', 'FontSize', 13, ...
        'LineWidth', 1.1, 'GridAlpha', 0.20);
    drawnow;
    exportgraphics(fig, figurePng, 'Resolution', 600);
    exportgraphics(fig, figurePdf, 'ContentType', 'vector');

    % Generate the publication table from the calculated state statistics.
    % The CSV retains full precision, while LaTeX matches printed rounding.
    t = states.FiveBus.StateSignature;
    assert(height(t) == 2 && all(ismember( ...
        {'State', 'Share', 'MeanLMP', 'LMPSpread', ...
         'MeanMaxLoading', 'FocusNetEarningTarget'}, ...
        t.Properties.VariableNames)), ...
        'The computed five-bus state signature is incomplete.');
    tableCsv = fullfile(tableDir, 'Table_5.csv');
    tableTex = fullfile(tableDir, 'Table_5.tex');
    writetable(t, tableCsv);
    write_table5_tex(t, tableTex);

    report = struct();
    report.Scope = 'Five-bus published Figure 2 and Table 5';
    report.FigurePNG = figurePng;
    report.FigurePDF = figurePdf;
    report.TableCSV = tableCsv;
    report.TableLaTeX = tableTex;
    report.PCAExplainedPercent = explained(:).';
    report.Observations = nnz(selected);
    report.Table5PassedChecks = ...
        states.FiveBus.Table5Comparison.PassedChecks;
    report.Table5TotalChecks = ...
        states.FiveBus.Table5Comparison.TotalChecks;

    fprintf('Exported outputs/figures/Figure_2.png\n');
    fprintf('Exported outputs/figures/Figure_2.pdf\n');
    fprintf('Exported outputs/tables/Table_5.csv\n');
    fprintf('Exported outputs/tables/Table_5.tex\n');
    fprintf('Table 5 publication checks: %d/%d passed.\n', ...
        report.Table5PassedChecks, report.Table5TotalChecks);
    fprintf('Figure 1 was not accessed or modified.\n');
    fprintf('=== SEGAN Stage 5 completed ===\n\n');
end

function write_table5_tex(t, fileName)
%WRITE_TABLE5_TEX Format the new five-bus results for LaTeX inclusion.
    fid = fopen(fileName, 'w');
    if fid < 0
        error('SEGAN:TableWriteFailed', ...
            'Could not create the LaTeX table output.');
    end
    guard = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid, '%% Generated from the live five-bus Stage 4 results.\n');
    fprintf(fid, '\\begin{tabular}{lrrrrr}\n');
    fprintf(fid, '\\toprule\n');
    fprintf(fid, ['State & Share & Mean LMP & LMP spread & ' ...
        'Mean max loading & NE target \\\\\n']);
    fprintf(fid, [' & & (\\$/MWh) & (\\$/MWh) & ' ...
        '(\\%%) & (\\$/h) \\\\\n']);
    fprintf(fid, '\\midrule\n');
    for i = 1:height(t)
        fprintf(fid, '%s & %.3f & %.3f & %.3f & %.2f & %.1f \\\\\n', ...
            char(t.State(i)), t.Share(i), t.MeanLMP(i), ...
            t.LMPSpread(i), t.MeanMaxLoading(i), ...
            t.FocusNetEarningTarget(i));
    end
    fprintf(fid, '\\bottomrule\n');
    fprintf(fid, '\\end{tabular}\n');
end
