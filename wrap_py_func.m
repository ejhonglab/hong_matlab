function [wrapped_fn] = wrap_py_func(py_fn)
%WRAP_PY_FUNC Return a MATLAB function that tries to convert more types
% that could be output by the Python function.

% TODO TODO how to support variable # of arguments w/ this kind of approach
% to wrapping fns? (like adding optional pyargs)

% TODO maybe replace this w/ recursion in convert_py_type?
wrapped_fn = @(x) convert_py_type(py_fn(x));
end

