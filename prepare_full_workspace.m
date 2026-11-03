function report = prepare_full_workspace(mode)
%PREPARE_FULL_WORKSPACE Create an isolated clean Full Mode workspace.
%   PREPARE_FULL_WORKSPACE('plan') checks the canonical bundled inputs and
%   destination without changing any files.
%   REPORT = PREPARE_FULL_WORKSPACE() copies the source and four raw inputs
%   to full_workspace/ under this project's root, with NO cached results.
%
%   The original research outputs/cache/ and Quick Mode files are never
%   copied, altered, removed or overwritten by this function.
%
%   Run in MATLAB from the downloaded SEGAN repository and follow the
%   commands in USER_GUIDE.md. This helper never starts Full Mode itself.

    if nargin < 1
        mode = 'create';
    end
    if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
        error('SEGAN:WorkspaceInvalidMode','Mode must be create or plan.');
    end
    mode = lower(strtrim(char(mode)));
    if ~ismember(mode,{'plan','create'})
        error('SEGAN:WorkspaceInvalidMode','Mode must be create or plan.');
    end

    root = fileparts(mfilename('fullpath'));
    target = fullfile(root,'full_workspace');
    requiredRaw = {'AMES_5Bus.xlsx','case57.m', ...
        'pglib_opf_case57_ieee__sad.m', ...
        'power Generation and consumption.csv'};
    requiredFolders = {'config','src','tests'};
    requiredFiles = {'reproduce_all.m','validate_results.m','run_demo.m', ...
        'README.md','USER_GUIDE.md','DATA_SOURCES.md', ...
        'DATA_ACQUISITION.md','CITATION.cff','CITATION.bib', ...
        'PROVENANCE.md','SOLVER_EVIDENCE.md','RELEASE_CHECKLIST.md'};

    for i = 1:numel(requiredFolders)
        if ~isfolder(fullfile(root,requiredFolders{i}))
            error('SEGAN:WorkspaceMissingSource', ...
                'Required folder is missing: %s',requiredFolders{i});
        end
    end
    for i = 1:numel(requiredFiles)
        if ~isfile(fullfile(root,requiredFiles{i}))
            error('SEGAN:WorkspaceMissingSource', ...
                'Required project file is missing: %s',requiredFiles{i});
        end
    end
    for i = 1:numel(requiredRaw)
        p = fullfile(root,'data','raw',requiredRaw{i});
        if ~isfile(p)
            error('SEGAN:WorkspaceMissingInput', ...
                'Required bundled input is missing: %s',requiredRaw{i});
        end
        info = dir(p);
        if numel(info)~=1 || info.bytes<=0
            error('SEGAN:WorkspaceEmptyInput', ...
                'Required bundled input is empty: %s',requiredRaw{i});
        end
    end
    ready = ~isfolder(target) && ~isfile(target);

    report = struct('Mode',mode,'SourceRoot',root, ...
        'WorkspacePath',target,'RawFilesPresent',numel(requiredRaw), ...
        'SafeToCreate',ready,'Created',false, ...
        'OriginalResearchOutputsUntouched',true);
    if strcmp(mode,'plan')
        fprintf('SEGAN clean Full workspace plan: %s\n',target);
        fprintf('Four bundled inputs present; destination free: %d\n',ready);
        fprintf('No files changed.\n');
        return;
    end
    if ~ready
        error('SEGAN:WorkspaceAlreadyExists',[ ...
            'Refusing to overwrite an existing full_workspace. ' ...
            'Preserve and inspect its existing contents.']);
    end

    [ok,msg] = mkdir(target);
    if ~ok
        error('SEGAN:WorkspaceCreateFailed','%s',msg);
    end
    try
        for i = 1:numel(requiredFolders)
            source = fullfile(root,requiredFolders{i});
            destination = fullfile(target,requiredFolders{i});
            [ok,msg] = copyfile(source,destination);
            if ~ok
                error('SEGAN:WorkspaceCopyFailed', ...
                    'Unable to copy %s: %s',requiredFolders{i},msg);
            end
        end
        [ok,msg] = mkdir(fullfile(target,'data'));
        if ~ok, error('SEGAN:WorkspaceCreateFailed','%s',msg); end
        [ok,msg] = copyfile(fullfile(root,'data','raw'), ...
            fullfile(target,'data','raw'));
        if ~ok, error('SEGAN:WorkspaceCopyFailed','Raw data copy: %s',msg); end
        for i = 1:numel(requiredFiles)
            [ok,msg] = copyfile(fullfile(root,requiredFiles{i}), ...
                fullfile(target,requiredFiles{i}));
            if ~ok
                error('SEGAN:WorkspaceCopyFailed', ...
                    'Unable to copy %s: %s',requiredFiles{i},msg);
            end
        end
        for sub = {'cache','figures','tables','logs'}
            [ok,msg] = mkdir(fullfile(target,'outputs',sub{1}));
            if ~ok, error('SEGAN:WorkspaceCreateFailed','%s',msg); end
        end
        for i = 1:numel(requiredRaw)
            a = dir(fullfile(root,'data','raw',requiredRaw{i}));
            b = dir(fullfile(target,'data','raw',requiredRaw{i}));
            if numel(b)~=1 || a.bytes~=b.bytes
                error('SEGAN:WorkspaceIntegrity', ...
                    'Input copy size mismatch: %s',requiredRaw{i});
            end
        end
        cacheEntries = dir(fullfile(target,'outputs','cache'));
        if any(~[cacheEntries.isdir])
            error('SEGAN:WorkspaceDirtyCache', ...
                'Fresh Full workspace unexpectedly contains cache files.');
        end
    catch failure
        warning('SEGAN:WorkspacePartial',[ ...
            'Full workspace creation was incomplete. No original files ' ...
            'were changed. The incomplete destination was left intact.']);
        rethrow(failure);
    end
    report.Created = true;
    report.SafeToCreate = false;
    fprintf('SEGAN clean Full workspace created: %s\n',target);
    fprintf('Only four bundled inputs and project source were copied.\n');
    fprintf('Outputs tree is empty. Open this folder in MATLAB.\n');
end
