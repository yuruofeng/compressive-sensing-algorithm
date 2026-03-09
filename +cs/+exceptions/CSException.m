classdef CSException < MException
    % CSException 压缩感知库基础异常类
    % 提供统一的错误码体系和异常处理接口
    
    properties
        ErrorCode
        Context
        Suggestions
    end
    
    properties (Constant)
        ERROR_CODES = struct(...
            'UNKNOWN', 0, ...
            'INVALID_INPUT', 1001, ...
            'DIMENSION_MISMATCH', 1002, ...
            'NUMERICAL_ERROR', 2001, ...
            'SINGULAR_MATRIX', 2002, ...
            'NOT_CONVERGED', 2003, ...
            'MAX_ITERATIONS', 2004, ...
            'NOT_IMPLEMENTED', 3001, ...
            'FILE_ERROR', 4001, ...
            'CONFIG_ERROR', 5001, ...
            'INTERNAL_ERROR', 9999)
    end
    
    methods
        function obj = CSException(errorCode, msg, varargin)
            msgid = CSException.getIdentifier(errorCode);
            obj@MException(msgid, msg, varargin{:});
            obj.ErrorCode = errorCode;
            obj.Context = struct();
            obj.Suggestions = {};
        end
        
        function obj = addContext(obj, name, value)
            obj.Context.(name) = value;
        end
        
        function obj = addSuggestion(obj, suggestion)
            obj.Suggestions{end+1} = suggestion;
        end
        
        function report(obj)
            fprintf(2, '\n=== CS Exception Report ===\n');
            fprintf(2, 'Error Code: %d\n', obj.ErrorCode);
            fprintf(2, 'Message: %s\n', obj.message);
            fprintf(2, 'Identifier: %s\n', obj.identifier);
            
            if ~isempty(fieldnames(obj.Context))
                fprintf(2, '\nContext:\n');
                fields = fieldnames(obj.Context);
                for i = 1:length(fields)
                    fprintf(2, '  %s: ', fields{i});
                    disp(obj.Context.(fields{i}));
                end
            end
            
            if ~isempty(obj.Suggestions)
                fprintf(2, '\nSuggestions:\n');
                for i = 1:length(obj.Suggestions)
                    fprintf(2, '  %d. %s\n', i, obj.Suggestions{i});
                end
            end
            
            fprintf(2, '\nStack Trace:\n');
            for i = 1:length(obj.stack)
                fprintf(2, '  %s (line %d)\n', obj.stack(i).name, obj.stack(i).line);
            end
            fprintf(2, '===========================\n\n');
        end
    end
    
    methods (Static)
        function id = getIdentifier(errorCode)
            baseName = 'cs.exceptions';
            
            switch errorCode
                case CSException.ERROR_CODES.INVALID_INPUT
                    id = [baseName '.InvalidInputException'];
                case CSException.ERROR_CODES.DIMENSION_MISMATCH
                    id = [baseName '.DimensionMismatchException'];
                case CSException.ERROR_CODES.NUMERICAL_ERROR
                    id = [baseName '.NumericalException'];
                case CSException.ERROR_CODES.SINGULAR_MATRIX
                    id = [baseName '.SingularMatrixException'];
                case CSException.ERROR_CODES.NOT_CONVERGED
                    id = [baseName '.ConvergenceException'];
                case CSException.ERROR_CODES.MAX_ITERATIONS
                    id = [baseName '.MaxIterationsException'];
                case CSException.ERROR_CODES.NOT_IMPLEMENTED
                    id = [baseName '.NotImplementedException'];
                case CSException.ERROR_CODES.FILE_ERROR
                    id = [baseName '.FileException'];
                case CSException.ERROR_CODES.CONFIG_ERROR
                    id = [baseName '.ConfigException'];
                otherwise
                    id = [baseName '.UnknownException'];
            end
        end
    end
end
