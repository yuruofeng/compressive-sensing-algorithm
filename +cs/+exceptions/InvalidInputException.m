classdef InvalidInputException < cs.exceptions.CSException
    % InvalidInputException 无效输入异常
    
    methods
        function obj = InvalidInputException(msg, varargin)
            obj@cs.exceptions.CSException(cs.exceptions.CSException.ERROR_CODES.INVALID_INPUT, ...
                ['Invalid input: ' msg], varargin{:});
            obj = obj.addSuggestion('Check input parameters and their types');
        end
    end
    
    methods (Static)
        function throwInvalidType(paramName, expectedType, actualType)
            ex = cs.exceptions.InvalidInputException(...
                sprintf('Parameter ''%s'' expected to be %s but got %s', ...
                paramName, expectedType, actualType));
            ex = ex.addContext('ParameterName', paramName);
            ex = ex.addContext('ExpectedType', expectedType);
            ex = ex.addContext('ActualType', actualType);
            throw(ex);
        end
        
        function throwOutOfRange(paramName, value, range)
            ex = cs.exceptions.InvalidInputException(...
                sprintf('Parameter ''%s'' value %g is out of range %s', ...
                paramName, value, range));
            ex = ex.addContext('ParameterName', paramName);
            ex = ex.addContext('Value', value);
            ex = ex.addContext('ValidRange', range);
            throw(ex);
        end
        
        function throwEmptyInput(paramName)
            ex = cs.exceptions.InvalidInputException(...
                sprintf('Parameter ''%s'' cannot be empty', paramName));
            ex = ex.addContext('ParameterName', paramName);
            throw(ex);
        end
    end
end
