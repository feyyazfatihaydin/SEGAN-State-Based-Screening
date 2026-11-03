function report = export_57bus_table4(cfg, screening)
%EXPORT_57BUS_TABLE4 Export the validated IEEE 57-bus screening table.
%   REPORT = SEGAN.EXPORT_57BUS_TABLE4(CFG, SCREENING) converts the
%   freshly computed Stage 6D result into Table_4.csv and Table_4.tex.
%   The function does not execute DC-OPF or read historical results.
%
%   IMPORTANT: The published Table 4 labels its CCW response as $/day,
%   but the reported numerical values are the aggregate changes over the
%   entire 90-day simulation. This export preserves those values and
%   explicitly labels the column as a 90-day total. The daily mean is
%   additionally included in the machine-readable CSV file.
%
%   The generator roles document the published experiment design. They
%   are not inferred automatically from the ordinal screening ranks.

    if nargin ~= 2 || ~isstruct(cfg) || ~isstruct(screening) || ...
            ~isfield(cfg, 'paths') || ~isfield(cfg.paths, 'project') || ...
            ~isfield(screening, 'Table4') || ...
            ~isfield(screening, 'RankDetails') || ...
            ~isfield(screening, 'Validation')
        error('SEGAN:InvalidTable4Input', ...
            'Provide the repository configuration and validated Stage 6D output.');
    end

    checks = screening.Validation;
    if ~isfield(checks, 'AllPassed') || ...
            ~isscalar(checks.AllPassed) || ~checks.AllPassed || ...
            ~isfield(checks, 'PublishedRanksMatched') || ...
            ~isfield(checks, 'TotalPublishedRanks') || ...
            checks.PublishedRanksMatched ~= 7 || ...
            checks.TotalPublishedRanks ~= 7
        error('SEGAN:UnvalidatedTable4', ...
            'All seven published screening ranks must be validated first.');
    end

    t = screening.Table4;
    rankDetails = screening.RankDetails;
    needed = {'GenCo', 'Bus', 'Pmax', 'MeanPG', ...
        'DispatchShare', 'CapacityUtilization', 'MeanDailyNetEarning', ...
        'CCWDelta90Day', 'CCWDeltaMeanDaily', 'ScreeningRank'};
    if ~istable(t) || height(t) ~= 7 || ...
            ~all(ismember(needed, t.Properties.VariableNames)) || ...
            ~istable(rankDetails) || height(rankDetails) ~= 7
        error('SEGAN:InvalidTable4Data', ...
            'Stage 6D did not provide a complete seven-generator table.');
    end
    if ~isequal(t.GenCo(:), (1:7).') || ...
            ~isequal(rankDetails.GenCo(:), t.GenCo(:)) || ...
            ~isequal(rankDetails.ComputedRank(:), t.ScreeningRank(:)) || ...
            ~all(rankDetails.Pass) || ...
            ~isequal(sort(t.ScreeningRank(:)), (1:7).')
        error('SEGAN:InvalidScreeningRanks', ...
            'Generator identities, rank integrity, or rank checks are inconsistent.');
    end
    numericValues = t{:, needed};
    if ~isnumeric(numericValues) || any(~isfinite(numericValues), 'all')
        error('SEGAN:NonfiniteTable4Data', ...
            'All exported generator-screening metrics must be finite numeric values.');
    end
    if any(abs(t.CCWDelta90Day - 90*t.CCWDeltaMeanDaily) > 1e-5)
        error('SEGAN:Table4UnitMismatch', ...
            'The 90-day CCW totals do not match 90 times the daily means.');
    end

    % G5 and G7 are the fixed strategic configurations in the article.
    % G1 is ranked second but remains a comparator, not the second member.
    roles = repmat("Comparator", 7, 1);
    roles(t.GenCo == 5) = "Single";
    roles(t.GenCo == 7) = "Double member";
    exportTable = t;
    exportTable.Role = roles;

    tableDir = fullfile(cfg.paths.project, 'outputs', 'tables');
    csvPath = fullfile(tableDir, 'Table_4.csv');
    texPath = fullfile(tableDir, 'Table_4.tex');
    if isfile(csvPath) || isfile(texPath)
        error('SEGAN:Table4AlreadyExported', ...
            ['A Table 4 export already exists. Review it before ' ...
             'manually deciding whether a rerun is necessary.']);
    end
    if ~isfolder(tableDir)
        mkdir(tableDir);
    end

    % The CSV retains numerical precision and explicit time units.
    writetable(exportTable, csvPath);
    write_table4_tex(exportTable, texPath);

    report = struct();
    report.Scope = 'IEEE 57-bus Table 4';
    report.TableCSV = csvPath;
    report.TableLaTeX = texPath;
    report.RanksMatched = checks.PublishedRanksMatched;
    report.TotalRanks = checks.TotalPublishedRanks;
    report.CompleteTable = exportTable;
    report.UnitNote = ['Published CCW numeric entries are 90-day totals; ' ...
        'daily means are supplied separately in the CSV.'];

    fprintf('\n=== SEGAN Stage 6E: Table 4 export ===\n');
    fprintf('Source: validated, newly generated Stage 6D output.\n');
    fprintf('Published generator ranks: %d/%d matched.\n', ...
        report.RanksMatched, report.TotalRanks);
    fprintf('Exported outputs/tables/Table_4.csv\n');
    fprintf('Exported outputs/tables/Table_4.tex\n');
    fprintf(['Unit note: CCWDelta90Day is a 90-day aggregate, not ' ...
        'a per-day value.\n']);
    fprintf('No OPF, ranking, clustering, or figure generation occurred.\n');
    fprintf('=== SEGAN Stage 6E completed ===\n\n');
end

function write_table4_tex(t, fileName)
%WRITE_TABLE4_TEX Write the published table values with accurate units.
    fileId = fopen(fileName, 'w');
    if fileId < 0
        error('SEGAN:Table4WriteFailed', ...
            'Unable to open the new Table 4 LaTeX file for writing.');
    end
    closeFile = onCleanup(@() fclose(fileId)); %#ok<NASGU>

    fprintf(fileId, '%% Generated from newly computed Stage 6D results.\n');
    fprintf(fileId, '%% Requires the booktabs LaTeX package.\n');
    fprintf(fileId, ['%% The publication labels the CCW response as dollars/day, ' ...
        'but its numeric values are 90-day totals.\n']);
    fprintf(fileId, '\\begin{tabular}{rrrrrrrrrl}\n');
    fprintf(fileId, '\\toprule\n');
    fprintf(fileId, ['GenCo & Bus & Pmax & Mean PG & Dispatch share & ' ...
        'Util. & Mean daily NE & CCW $\\Delta$ own NE & Rank & Role \\\\\n']);
    fprintf(fileId, [' & & (MW) & (MW) & & & (\\$/day) & ' ...
        '(model \\$, 90-day total) & & \\\\\n']);
    fprintf(fileId, '\\midrule\n');

    for row = 1:height(t)
        fprintf(fileId, ...
            '%d & %d & %.0f & %.1f & %.3f & %.3f & %.0f & %.0f & %d & %s \\\\\n', ...
            t.GenCo(row), t.Bus(row), t.Pmax(row), t.MeanPG(row), ...
            t.DispatchShare(row), t.CapacityUtilization(row), ...
            t.MeanDailyNetEarning(row), t.CCWDelta90Day(row), ...
            t.ScreeningRank(row), char(t.Role(row)));
    end
    fprintf(fileId, '\\bottomrule\n');
    fprintf(fileId, '\\end{tabular}\n');
end
