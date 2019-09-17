function [val] = convert_py_type(py_obj)
%CONVERT_PY_TYPE Try to convert Python type to native MATLAB type.
    val = py_obj;
    % Convert type if reasonable + wouldn't happen automatically.
    if isa(py_obj, 'py.tuple') || isa(py_obj, 'py.list')
        val = cell(py_obj);
    elseif isa(py_obj, 'py.str')
        val = char(py_obj);
    elseif isa(py_obj, 'py.dict')
        % Here, the field names can be invalid (e.g. have spaces)
        try
            val = struct(py_obj);
            fns = fieldnames(val);
            for i = 1:numel(fns)
                fn = fns{i};
                val.(fn) = convert_py_type(val.(fn));
            end
        catch
            % TODO check err?
            return
        end 
    end
end

