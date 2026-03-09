function validation(varargin)
    % validation 输入验证工具函数
    % 用法: cs.utils.validation('functionName', args...)
    
    if nargin < 1
        error('cs.exceptions.InvalidInputException', ...
            'Function name required');
    end
    
    funcName = varargin{1};
    
    switch lower(funcName)
        case 'validatematrix'
            validateMatrix(varargin{2:end});
        case 'validatevector'
            validateVector(varargin{2:end});
        case 'validatescalar'
            validateScalar(varargin{2:end});
        case 'validatepositive'
            validatePositive(varargin{2:end});
        case 'validateinteger'
            validateInteger(varargin{2:end});
        case 'validatedimensions'
            validateDimensions(varargin{2:end});
        otherwise
            error('cs.exceptions.NotImplementedException', ...
                'Unknown validation function: %s', funcName);
    end
end

function validateMatrix(inputMatrix, varName, varargin)
    if nargin < 2
        varName = 'Input';
    end
    
    paramParser = inputParser;
    addParameter(paramParser, 'AllowEmpty', false, @islogical);
    addParameter(paramParser, 'AllowComplex', true, @islogical);
    addParameter(paramParser, 'MinRows', 1, @isnumeric);
    addParameter(paramParser, 'MinCols', 1, @isnumeric);
    parse(paramParser, varargin{:});
    
    if isempty(inputMatrix)
        if ~paramParser.Results.AllowEmpty
            cs.exceptions.InvalidInputException.throwEmptyInput(varName);
        end
        return;
    end
    
    if ~isnumeric(inputMatrix)
        cs.exceptions.InvalidInputException.throwInvalidType(varName, 'numeric', class(inputMatrix));
    end
    
    if ~paramParser.Results.AllowComplex && ~isreal(inputMatrix)
        error('cs.exceptions.InvalidInputException', ...
            '%s must be real-valued', varName);
    end
    
    if size(inputMatrix, 1) < paramParser.Results.MinRows || size(inputMatrix, 2) < paramParser.Results.MinCols
        error('cs.exceptions.InvalidInputException', ...
            '%s size [%d, %d] is smaller than minimum [%d, %d]', ...
            varName, size(inputMatrix, 1), size(inputMatrix, 2), paramParser.Results.MinRows, paramParser.Results.MinCols);
    end
end

function validateVector(inputVector, varName, varargin)
    if nargin < 2
        varName = 'Input';
    end
    
    paramParser = inputParser;
    addParameter(paramParser, 'AllowEmpty', false, @islogical);
    addParameter(paramParser, 'AllowComplex', true, @islogical);
    addParameter(paramParser, 'MinLength', 1, @isnumeric);
    addParameter(paramParser, 'Orientation', 'any', @ischar);
    parse(paramParser, varargin{:});
    
    if isempty(inputVector)
        if ~paramParser.Results.AllowEmpty
            cs.exceptions.InvalidInputException.throwEmptyInput(varName);
        end
        return;
    end
    
    if ~isnumeric(inputVector)
        cs.exceptions.InvalidInputException.throwInvalidType(varName, 'numeric', class(inputVector));
    end
    
    if ndims(inputVector) > 2 || (size(inputVector, 1) ~= 1 && size(inputVector, 2) ~= 1)
        error('cs.exceptions.InvalidInputException', ...
            '%s must be a vector, got size [%s]', varName, num2str(size(inputVector)));
    end
    
    if ~paramParser.Results.AllowComplex && ~isreal(inputVector)
        error('cs.exceptions.InvalidInputException', ...
            '%s must be real-valued', varName);
    end
    
    if length(inputVector) < paramParser.Results.MinLength
        error('cs.exceptions.InvalidInputException', ...
            '%s length %d is smaller than minimum %d', varName, length(inputVector), paramParser.Results.MinLength);
    end
    
    switch lower(paramParser.Results.Orientation)
        case 'column'
            if size(inputVector, 2) ~= 1
                error('cs.exceptions.InvalidInputException', ...
                    '%s must be a column vector', varName);
            end
        case 'row'
            if size(inputVector, 1) ~= 1
                error('cs.exceptions.InvalidInputException', ...
                    '%s must be a row vector', varName);
            end
    end
end

function validateScalar(scalarValue, varName, varargin)
    if nargin < 2
        varName = 'Input';
    end
    
    paramParser = inputParser;
    addParameter(paramParser, 'AllowComplex', false, @islogical);
    addParameter(paramParser, 'Min', -Inf, @isnumeric);
    addParameter(paramParser, 'Max', Inf, @isnumeric);
    parse(paramParser, varargin{:});
    
    if ~isnumeric(scalarValue) || numel(scalarValue) ~= 1
        cs.exceptions.InvalidInputException.throwInvalidType(varName, 'scalar', ...
            ['array of size ' num2str(size(scalarValue))]);
    end
    
    if ~paramParser.Results.AllowComplex && ~isreal(scalarValue)
        error('cs.exceptions.InvalidInputException', ...
            '%s must be real-valued', varName);
    end
    
    if scalarValue < paramParser.Results.Min || scalarValue > paramParser.Results.Max
        cs.exceptions.InvalidInputException.throwOutOfRange(varName, scalarValue, ...
            sprintf('[%g, %g]', paramParser.Results.Min, paramParser.Results.Max));
    end
end

function validatePositive(positiveValue, varName)
    if nargin < 2
        varName = 'Input';
    end
    
    validateScalar(positiveValue, varName, 'Min', eps, 'Max', Inf);
end

function validateInteger(integerValue, varName, varargin)
    if nargin < 2
        varName = 'Input';
    end
    
    paramParser = inputParser;
    addParameter(paramParser, 'Min', 1, @isnumeric);
    addParameter(paramParser, 'Max', Inf, @isnumeric);
    parse(paramParser, varargin{:});
    
    if ~isnumeric(integerValue) || numel(integerValue) ~= 1 || integerValue ~= floor(integerValue)
        error('cs.exceptions.InvalidInputException', ...
            '%s must be an integer, got %g', varName, integerValue);
    end
    
    if integerValue < paramParser.Results.Min || integerValue > paramParser.Results.Max
        cs.exceptions.InvalidInputException.throwOutOfRange(varName, integerValue, ...
            sprintf('[%d, %d]', paramParser.Results.Min, paramParser.Results.Max));
    end
end

function validateDimensions(sensorMatrix, observations, matrixName, vectorName)
    if nargin < 3
        matrixName = 'A';
    end
    if nargin < 4
        vectorName = 'b';
    end
    
    if size(sensorMatrix, 1) ~= size(observations, 1)
        cs.exceptions.DimensionMismatchException.throwMatrixVector(...
            matrixName, size(sensorMatrix, 1), size(sensorMatrix, 2), vectorName, size(observations, 1));
    end
end
