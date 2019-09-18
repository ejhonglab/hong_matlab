
this_file_path = mfilename('fullpath');
startup_line = sprintf(char("run('%s')"), this_file_path);
startup_fname = fullfile(userpath(), 'startup.m');

[this_repo_dir, ~, ~] = fileparts(this_file_path);
old_path = path();
path(this_repo_dir, old_path);

if ~ exist(startup_fname, 'file')
    fid = fopen(startup_fname, 'wt');
    fprintf(fid, '%s\n', startup_line);
    fclose(fid);
else
    fid = fopen(startup_fname, 'rt');
    found_line = false;
    while true
        line = fgetl(fid);
        % fgetl return -1 when EOF (and == -1 woudldn't work)
        if ~ ischar(line)
            break;
        end
        if strcmp(line, startup_line)
            found_line = true;
            break;
        end
    end
    fclose(fid);
    
    if ~ found_line
        fid = fopen(startup_fname, 'at');
        fprintf(fid, '%s\n', startup_line);
        fclose(fid);
    end
end

[ps1, po1] = system(['cd ' this_repo_dir '; git pull']);
% TODO check status, and if it updated, force / prompt for restart
disp('Checking for hong_matlab updates:')
disp(po1)

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
    pe = pyenv;
    py3_exe = char(pe.Executable);
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

[ss, so] = system([py3_exe ' -c "import _ssl; [print(s) for s in ' ...
    '_ssl.get_default_verify_paths()]"']);
parts = splitlines(so);
% TODO get var for whether py is loaded in each branch of if above,
% and assert it's not loaded here, otherwise env changes won't have an
% effect (can i set these in py while it's loaded?)
setenv(parts{1}, parts{2});
setenv(parts{3}, parts{4});

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

% TODO assert that py ssl certs are not none / some random matlab thing

repo_name = 'python_2p_analysis';
src_dir = '~/src';
repo_dir = fullfile(src_dir, repo_name);
module_name = 'hong2p.util';

pulled = false;
if exist(repo_dir, 'dir')
    [ps2, po2] = system(['cd ' repo_dir '; git pull']);
    disp(['Checking for ' module_name ' updates:'])
    disp(po2)
    pulled = true;
end

try
    module = py.importlib.import_module(module_name);
catch err
    if ~ startsWith(err.message, ...
        'Python Error: ModuleNotFoundError: No module named ')
    
        rethrow(err);
    end
    % TODO a few things in this section might only work on linux.
    % test on other systems.
    
    if ~ exist(src_dir, 'dir')
        mkdir(src_dir);
    end
    
    if ~ exist(repo_dir, 'dir')
        [status1, cmdout1] = system(['git clone https://github.com/' ...
            'ejhonglab/' repo_name ' ' repo_dir]);
    end
    
    if ~ pulled
        [ps2, po2] = system(['cd ' repo_dir '; git pull']);
        disp(['Checking for ' module_name ' updates:'])
        disp(po2)
    end
    
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
% Field names not to import into MATLAB namespace.
blacklist = {'sep'};
for i = 1:numel(fns)
    fn = fns{i};
    if any(cellfun(@(x) strcmp(x, fn), blacklist))
        continue
    end
    
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
        continue
    end
    
    %
    if isa(val, 'py.function')
        val = wrap_py_func(val);
    end
    %
    
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
% TODO investigate differences w/ python-in-bash when calling
% odor2abbrev('ethyl alcohol')
