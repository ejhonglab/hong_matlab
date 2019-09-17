
try
    pyenv('ExecutionMode', 'OutOfProcess');
catch err
    disp('caught error')
    disp(err)
end

%{
import py.hong2p.util.*
abbrev = odor2abbrev('ethanol', pyargs('use_gsheet', true));
%}

% this just hangs for some reason, even though
% importing just hong2p seems to succeed
%py.importlib.import_module('hong2p.util')
% this also seems to hang
% py.importlib.import_module('hong2p.util.odor2abbrev')

import py.hong2p.util.odor2abbrev

%{
% TODO why, when setting pyenv to OutOfProcess above,
% does this not find odor2abbrev (even though
% import py.hong2p.util.* doesn't fail... maybe it fails silently?)
abbrev = py.hong2p.util.odor2abbrev('ethanol', pyargs('use_gsheet', true));
disp(abbrev)
%}