function report = export_57bus_figure6_table8(cfg)
%EXPORT_57BUS_FIGURE6_TABLE8 Export the published K-sensitivity evidence.
%   REPORT = SEGAN.EXPORT_57BUS_FIGURE6_TABLE8(CFG) reads only the newly
%   generated Stage 9A K-sensitivity manifest. It exports the two-panel
%   Figure 6 and the six-row Table 8 with a numerical source CSV.
%
%   Panel (a) shows the approximate silhouette, and panel (b) shows the
%   proportion of the cluster with the highest ex-post net-earning target.
%   K=2/3/4 cluster labels are not altered or fitted here. Cluster-share
%   ordering in Table 8 follows the newly computed cluster labels; a
%   permutation of those labels has no scientific effect.
%
%   No DC-OPF, feature engineering, K-means, robustness fit, or changes to
%   previously validated figures and tables occur. Existing destinations
%   are never overwritten.

    if nargin ~= 1 || ~isstruct(cfg) || ~isfield(cfg,'paths') || ...
            ~isfield(cfg.paths,'project') || ~isfield(cfg.paths,'cache')
        error('SEGAN:Stage9BInvalidConfig', ...
            'Use the portable repository configuration from reproduction_config.');
    end

    root = cfg.paths.project;
    cache = cfg.paths.cache;
    sourcePath = fullfile(cache,'segan_57bus_k_sensitivity.mat');
    figDir = fullfile(root,'outputs','figures');
    tabDir = fullfile(root,'outputs','tables');
    pngPath = fullfile(figDir,'Figure_6.png');
    pdfPath = fullfile(figDir,'Figure_6.pdf');
    csvPath = fullfile(tabDir,'Table_8.csv');
    texPath = fullfile(tabDir,'Table_8.tex');
    dataPath = fullfile(tabDir,'Figure_6_data.csv');
    targets = {pngPath,pdfPath,csvPath,texPath,dataPath};
    if any(cellfun(@isfile,targets))
        error('SEGAN:Stage9BExistingOutput', ...
            'A Stage 9B output already exists; automatic overwrite is refused.');
    end
    if ~isfile(sourcePath)
        error('SEGAN:Stage9BMissingSource', ...
            'Validated Stage 9A K-sensitivity output is required.');
    end
    raw = load(sourcePath,'analysis');
    if ~isfield(raw,'analysis')
        error('SEGAN:Stage9BInvalidSource', ...
            'Stage 9A manifest must contain the analysis structure.');
    end
    a = raw.analysis;
    if ~all(isfield(a,{'Meta','Summary','Table8Comparison','Validation', ...
            'K2SilhouetteMethodComparison'})) || ...
            ~isfield(a.Validation,'AllPassed') || ...
            ~a.Validation.AllPassed || ...
            a.Validation.PublishedChecksPassed ~= 24 || ...
            a.Validation.PublishedChecksTotal ~= 24
        error('SEGAN:Stage9BUnvalidatedSource', ...
            'Stage 9A must pass all internal and published Table 8 checks.');
    end
    if ~strcmp(a.Meta.Stage,'9A')
        error('SEGAN:Stage9BWrongStage', ...
            'Only newly calculated Stage 9A data are accepted.');
    end

    S = a.Summary;
    C = a.Table8Comparison;
    expectedConfig = [repmat("Single_G5",3,1);repmat("Double_G5G7",3,1)];
    expectedK = repmat([2;3;4],2,1);
    if ~istable(S) || ~istable(C) || height(S) ~= 6 || height(C) ~= 6 || ...
            ~isequal(string(S.Configuration(:)),expectedConfig) || ...
            ~isequal(double(S.K(:)),expectedK) || ...
            ~isequal(string(C.Configuration(:)),expectedConfig) || ...
            ~isequal(double(C.K(:)),expectedK)
        error('SEGAN:Stage9BIncompleteRows', ...
            'Expected six aligned rows for two configurations and K=2/3/4.');
    end
    required = {'ApproxSilhouette','RawClusterShares','HighTargetShare', ...
                'NetEarningTargetGap','Observations','ActiveFeatures', ...
                'ARIvsMainK2'};
    if ~all(ismember(required,S.Properties.VariableNames)) || ...
            ~all(ismember({'SilhouettePass','ClusterSharesPass', ...
                'HighSharePass','TargetGapPass'},C.Properties.VariableNames))
        error('SEGAN:Stage9BMissingColumns', ...
            'Stage 9A results lack required numeric or validation columns.');
    end
    checks = [C.SilhouettePass,C.ClusterSharesPass, ...
              C.HighSharePass,C.TargetGapPass];
    if ~all(checks,'all') || nnz(checks) ~= 24 || ...
            any(S.Observations~=34560) || any(S.ActiveFeatures~=28) || ...
            any(~isfinite([S.ApproxSilhouette,S.HighTargetShare, ...
                           S.NetEarningTargetGap]),'all') || ...
            any(S.ApproxSilhouette<0 | S.ApproxSilhouette>1) || ...
            any(S.HighTargetShare<=0 | S.HighTargetShare>=1) || ...
            any(S.NetEarningTargetGap<=0)
        error('SEGAN:Stage9BIntegrityFailed', ...
            'The six K-sensitivity rows did not pass structural checks.');
    end

    displayNames = [repmat("Single-G5",3,1); ...
                    repmat("Double-G5/G7",3,1)];
    shareTexts = strings(6,1);
    shareChecks = false(6,1);
    for i = 1:6
        % Parse the computed cluster proportions, never published values.
        portions = str2double(strsplit(strtrim(char(S.RawClusterShares(i)))));
        if numel(portions) ~= S.K(i) || any(~isfinite(portions)) || ...
                any(portions<=0) || abs(sum(portions)-1)>1e-5
            % The highest ex-post target cluster need not have the largest share.
            error('SEGAN:Stage9BBadClusterShares', ...
                'Invalid computed shares for configuration row %d.',i);
        end
        shareTexts(i) = string(strjoin(arrayfun( ...
            @(v) sprintf('%.3f',v),portions,'UniformOutput',false),', '));
        shareChecks(i) = all(portions>0) && abs(sum(portions)-1)<1e-5;
    end
    if ~all(shareChecks)
        error('SEGAN:Stage9BClusterShareCheckFailed', ...
            'Cluster share validation failed.');
    end

    role = strings(6,1);
    role(S.K==2) = "Main";
    role(S.K~=2) = "Sensitivity";
    table8 = table(displayNames,double(S.K),double(S.ApproxSilhouette), ...
        shareTexts,double(S.HighTargetShare),double(S.NetEarningTargetGap), ...
        role,'VariableNames',{'Configuration','K','Silhouette', ...
        'ClusterShares','HighNETargetShare','NETargetGapUnitsPerHour','Role'});
    figureData = table(displayNames,double(S.K), ...
        double(S.ApproxSilhouette),double(S.HighTargetShare), ...
        double(S.NetEarningTargetGap),double(S.ARIvsMainK2), ...
        'VariableNames',{'Configuration','K','ApproxSilhouette', ...
        'HighNETargetShare','NETargetGapUnitsPerHour','ARIvsMainK2'});

    fprintf('\n=== SEGAN Stage 9B: Figure 6 and Table 8 export ===\n');
    fprintf('Reading validated Stage 9A data only.\n');
    fprintf('Six sensitivity rows: 2 strategies x K=2,3,4.\n');
    fprintf('Published Table 8 checks: %d/%d.\n',nnz(checks),numel(checks));
    fprintf('No DC-OPF, feature rebuild, K-means, or silhouette refit.\n');
    disp(table8);

    if ~isfolder(figDir)
        [ok,msg] = mkdir(figDir);
        if ~ok, error('SEGAN:Stage9BFigureFolder','%s',msg); end
    end
    if ~isfolder(tabDir)
        [ok,msg] = mkdir(tabDir);
        if ~ok, error('SEGAN:Stage9BTableFolder','%s',msg); end
    end
    drawFigure6(S,pngPath,pdfPath);
    writetable(table8,csvPath);
    writetable(figureData,dataPath);
    writeTable8Tex(table8,texPath);

    report = struct();
    report.Scope = 'IEEE 57-bus Figure 6 and Table 8';
    report.Table8 = table8;
    report.Figure6Data = figureData;
    report.K2SilhouetteMethodComparison = a.K2SilhouetteMethodComparison;
    report.FigurePNG = pngPath;
    report.FigurePDF = pdfPath;
    report.TableCSV = csvPath;
    report.TableLaTeX = texPath;
    report.FigureDataCSV = dataPath;
    report.Validation = struct( ...
        'ConfigurationCount',2, ...
        'KValues',[2 3 4], ...
        'KRecords',height(table8), ...
        'Figure6Points',height(figureData)*2, ...
        'ShareSumsChecked',nnz(shareChecks), ...
        'PublishedChecksPassed',nnz(checks), ...
        'PublishedChecksTotal',numel(checks), ...
        'NoDCOPFOrKMeansRun',true, ...
        'AllPassed',height(table8)==6 && nnz(checks)==24 && ...
                    all(shareChecks));
    fprintf('Exported outputs/figures/Figure_6.png\n');
    fprintf('Exported outputs/figures/Figure_6.pdf\n');
    fprintf('Exported outputs/tables/Table_8.csv\n');
    fprintf('Exported outputs/tables/Table_8.tex\n');
    fprintf('Exported outputs/tables/Figure_6_data.csv\n');
    fprintf('Computed cluster shares retain label-specific order.\n');
    fprintf('No previous MATLAB sources, results, figures, or tables changed.\n');
    fprintf('=== SEGAN Stage 9B completed ===\n\n');
end

function drawFigure6(S,pngPath,pdfPath)
%DRAWFIGURE6 Recreate the article's two-panel K-sensitivity figure.
    fig = figure('Color','white','Visible','off', ...
        'Units','pixels','Position',[80 80 1300 530], ...
        'MenuBar','none','ToolBar','none');
    figGuard = onCleanup(@()close(fig)); %#ok<NASGU>
    gridLayout = tiledlayout(fig,1,2,'TileSpacing','compact', ...
        'Padding','compact');
    color = [0.08 0.38 0.82;0.88 0.22 0.18];
    titles = {'(a) Cluster compactness', ...
              '(b) Size of highest-NE-target cluster'};
    ylabels = {'Approximate silhouette', ...
               'Highest-NE-target cluster share'};
    valueColumns = {'ApproxSilhouette','HighTargetShare'};
    for p = 1:2
        ax = nexttile(gridLayout,p);
        hold(ax,'on'); grid(ax,'on'); box(ax,'on');
        for c = 1:2
            ix = (c-1)*3+(1:3);
            k = double(S.K(ix));
            seriesValues = S.(valueColumns{p});
            val = double(seriesValues(ix));
            if c==1, label='57-bus Single-G5';
            else, label='57-bus Double-G5/G7'; end
            plot(ax,k,val,'-o','Color',color(c,:), ...
                'LineWidth',1.7,'MarkerSize',7, ...
                'MarkerFaceColor','white', ...
                'MarkerEdgeColor',color(c,:), ...
                'DisplayName',label);
        end
        set(ax,'XLim',[1.85 4.15],'XTick',[2 3 4], ...
            'FontName','Times New Roman','FontSize',12, ...
            'LineWidth',1,'GridAlpha',0.17);
        if p==1
            ylim(ax,[0.45 0.65]);
            legend(ax,'Location','southwest','FontSize',10, ...
                'Interpreter','none','Box','on');
        else
            ylim(ax,[0 0.28]);
        end
        xlabel(ax,'Number of clusters, K','FontSize',13);
        ylabel(ax,ylabels{p},'FontSize',13,'Interpreter','none');
        title(ax,titles{p},'FontWeight','bold', ...
            'FontSize',13,'Interpreter','none');
    end
    drawnow;
    exportgraphics(fig,pngPath,'Resolution',350);
    exportgraphics(fig,pdfPath,'ContentType','vector');
end

function writeTable8Tex(T,path)
%WRITETABLE8TEX Format the six computed rows with explicit units.
    file = fopen(path,'w');
    if file<0
        error('SEGAN:Stage9BLaTeXOpenFailed', ...
            'Unable to write the new Table 8 LaTeX file.');
    end
    fileGuard = onCleanup(@()fclose(file)); %#ok<NASGU>
    fprintf(file,'%% Table 8 regenerated from Stage 9A computed results.\n');
    fprintf(file,'%% Requires booktabs. Computed cluster labels may be permuted.\n');
    fprintf(file,'\\begin{tabular}{lrrlrrl}\n');
    fprintf(file,'\\toprule\n');
    fprintf(file,['Configuration & $K$ & Silhouette & Cluster shares & ' ...
        'High-NE target share & NE target gap (\\$/h) & Role \\\\\n']);
    fprintf(file,'\\midrule\n');
    for i=1:height(T)
        if i==4, fprintf(file,'\\addlinespace\n'); end
        config='';
        if i==1, config='Single-G5'; end
        if i==4, config='Double-G5/G7'; end
        fprintf(file,'%s & %d & %.3f & %s & %.3f & %.1f & %s \\\\\n', ...
            config,T.K(i),T.Silhouette(i),char(T.ClusterShares(i)), ...
            T.HighNETargetShare(i),T.NETargetGapUnitsPerHour(i), ...
            char(T.Role(i)));
    end
    fprintf(file,'\\bottomrule\n');
    fprintf(file,'\\end{tabular}\n');
end
