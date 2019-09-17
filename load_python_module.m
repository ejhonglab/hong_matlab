
[this_repo_dir, ~, ~] = fileparts(mfilename('fullpath'));
[ps1, po1] = system(['cd ' this_repo_dir '; git pull']);
% TODO check status, and if it updated, force / prompt for restart
disp(po1)

% TODO register this code at matlab startup, after other things added to
% path, to avoid shadowing

% TODO delete
%
%(doesn't seem to affect whether zlib can be found in 2018)
%{
llp = 'LD_LIBRARY_PATH';
disp(llp)
getenv(llp)
%setenv(llp, '/home/tom/anaconda3/lib');
setenv(llp, '/home/tom/anaconda3');
getenv(llp)
%}

%{
% also seems not to matter whether the path is as it was in the 2019 ver
path = 'PATH';
disp(path)
getenv(path)
setenv(path, '/home/tom/anaconda3/bin:/home/tom/bin:/home/tom/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games:/snap/bin');
getenv(path)
%}
%

%{
ldp = 'LD_PRELOAD';
getenv(ldp)
setenv(ldp, '/lib/x86_64-linux-gnu/libz.so.1');
getenv(ldp)
%}

% R2019b+ only
if exist('pyenv', 'builtin')
    try
        pyenv('ExecutionMode', 'InProcess');
    catch err
        if ~ strcmp(err.identifier, 'MATLAB:Pyenv:PythonLoadedInProcess')
            rethrow(err);
        end
    end
else
    % TODO modify so this works on windows too. $HOME is not set there.
    conda_py3 = fullfile(getenv('HOME'), 'anaconda3/bin/python3');
    % TODO square brackets inside system call weren't required in r2019b,
    % were they?
    [~, sys_py3] = system(...
        'env python3 -c "import sys; print(sys.executable)"');
    % Because the Python print make a newline at the end.
    sys_py3 = sys_py3(1:(end - 1));
    
    if exist(conda_py3, 'file')
        py3_exe = conda_py3;
    elseif exist(sys_py3, 'file')
        py3_exe = sys_py3;
    else
        error('could not find Python 3 executable');
    end
    
    try
        pyversion(py3_exe);
    catch err
        if ~ strcmp(err.identifier, 'MATLAB:Pyversion:PythonLoaded')
            rethrow(err);
        end
    end
end

%keyboard;
% TODO delete
%{
pyviron = py.os.environ;
%pyviron.get(ldp)
%disp('llp')
%pyviron.get(llp)
disp('path')
pyviron.get(path)
%return
%}

ver_str = char(py.sys.version);
assert(str2double(ver_str(1)) >= 3, 'Python must be version 3, but is 2');

module_name = 'hong2p.util';
try
    module = py.importlib.import_module(module_name);
catch err
    if ~ startsWith(err.message, ...
        'Python Error: ModuleNotFoundError: No module named ')
    
        rethrow(err);
    end
    % TODO a few things in this section might only work on linux.
    % test on other systems.
    
    src_dir = '~/src';
    if ~ exist(src_dir, 'dir')
        mkdir(src_dir);
    end

    repo_name = 'python_2p_analysis';
    repo_dir = fullfile(src_dir, repo_name);
    
    if ~ exist(repo_dir, 'dir')
        [status1, cmdout1] = system(['git clone https://github.com/' ...
            'ejhonglab/' repo_name ' ' repo_dir]);
    end
    
    [ps2, po2] = system(['cd ' repo_dir '; git pull']);
    disp(po2)
    
    % TODO git pull if repo there + no unstaged changes
    % + warn if can't pull b/c unstaged changes
    % TODO also git pull for this repo? (probably can't reload code tho...
    % could prompt to restart matlab)
    
    [status2, cmdout2] = system(['unset LD_LIBRARY_PATH; ' ...
        'python -m pip install -e ' repo_dir]);
    
    py_path = py.sys.path;
    if ~ any(cellfun(@(x) endsWith(char(x), repo_name), cell(py_path)))
        repo_dir = char(py.os.path.expanduser(repo_dir));
        insert(py_path, int32(0), repo_dir);
        % TODO TODO how to get this not to fail in pyversion case
        % , where current error is: ImportError:
        % /lib/x86_64-linux-gnu/libz.so.1: version `ZLIB_1.2.9' not found
        % (required by /home/tom/anaconda3/lib/python3.7/
        % site-packages/matplotlib/../../../libpng16.so.16)
        % py.sys.path (seems) to be the same in both cases
    end
    module = py.importlib.import_module(module_name);
end

fns = fieldnames(module);
defined_names = {};
for i = 1:numel(fns)
    fn = fns{i};
    field = module.(fn);
    if isa(field, 'py.module')
        continue
    end
    
    val = field;
    try
        field_module_name = char(py.getattr(field, '__module__'));
        if ~ strcmp(field_module_name, module_name)
            continue
        end
    catch err
        % Should just be Python builtins.
        val = convert_py_type(val);
    end
    
    if exist(fn) %#ok<EXIST>
        disp(['Python object "' fn ...
            '" would shadow a member of MATLAB workspace.'])
        disp(['To access this function, use the prefix py.' ...
           module_name '.'])
        disp(newline)
        continue
    end
    
    if isa(val, 'py.function')
        val = wrap_py_func(val);
    end
    
    eval([fn ' = val;']);
    defined_names{end + 1} = fn; %#ok<SAGROW>
end

% Deleting MATLAB vars used in this script from workspace, so only
% Python stuff remains.
vars_to_clear = who();
[~, left_idx, ~] = intersect(vars_to_clear, defined_names, 'stable');
vars_to_clear(left_idx) = [];
clear(vars_to_clear{:});
clear('vars_to_clear');
clear('left_idx');

%abbrev = odor2abbrev('ethanol');
%disp(abbrev)
