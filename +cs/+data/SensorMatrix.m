classdef SensorMatrix
    % SensorMatrix 感知矩阵统一封装
    % 支持显式矩阵、函数句柄和隐式算子三种模式
    
    properties (Access = private)
        pMatrix        
        pFunction      
        pAdjointFunc   
        pSize          
        pType          
    end
    
    properties (Dependent)
        M
        N
        NumMeasurements
        SignalLength
        Size
        Type
        IsExplicit
        IsImplicit
    end
    
    properties (Constant)
        TYPES = struct(...
            'EXPLICIT', 'explicit', ...
            'FUNCTION', 'function', ...
            'IMPLICIT', 'implicit')
    end
    
    methods
        function obj = SensorMatrix(A, varargin)
            if isa(A, 'cs.data.SensorMatrix')
                obj = A;
                return;
            end
            
            if isnumeric(A)
                obj.pMatrix = A;
                obj.pSize = size(A);
                obj.pType = obj.TYPES.EXPLICIT;
            elseif isa(A, 'function_handle')
                obj.pFunction = A;
                obj.pType = obj.TYPES.FUNCTION;
                
                if nargin >= 2
                    if isstruct(varargin{1})
                        obj.pSize = [varargin{1}.M, varargin{1}.N];
                    elseif isnumeric(varargin{1})
                        obj.pSize = varargin{1}(:)';
                    end
                end
                
                if nargin >= 3 && isa(varargin{2}, 'function_handle')
                    obj.pAdjointFunc = varargin{2};
                end
            else
                error('cs.exceptions.InvalidInputException', ...
                    'Input must be numeric matrix or function handle');
            end
        end
        
        function m = get.M(obj)
            m = obj.pSize(1);
        end
        
        function n = get.N(obj)
            n = obj.pSize(2);
        end
        
        function m = get.NumMeasurements(obj)
            m = obj.pSize(1);
        end
        
        function n = get.SignalLength(obj)
            n = obj.pSize(2);
        end
        
        function s = get.Size(obj)
            s = obj.pSize;
        end
        
        function t = get.Type(obj)
            t = obj.pType;
        end
        
        function flag = get.IsExplicit(obj)
            flag = strcmp(obj.pType, obj.TYPES.EXPLICIT);
        end
        
        function flag = get.IsImplicit(obj)
            flag = ~strcmp(obj.pType, obj.TYPES.EXPLICIT);
        end
        
        function obj = setSize(obj, M, N)
            validateattributes(M, {'numeric'}, {'scalar', 'positive', 'integer'});
            validateattributes(N, {'numeric'}, {'scalar', 'positive', 'integer'});
            obj.pSize = [M, N];
        end
        
        function y = multiply(obj, x, transposed)
            if nargin < 3
                transposed = false;
            end
            
            switch obj.pType
                case obj.TYPES.EXPLICIT
                    if transposed
                        y = obj.pMatrix' * x;
                    else
                        y = obj.pMatrix * x;
                    end
                    
                case obj.TYPES.FUNCTION
                    if transposed
                        if ~isempty(obj.pAdjointFunc)
                            y = obj.pAdjointFunc(x);
                        else
                            try
                                y = obj.pFunction(x, 2);
                            catch
                                error('cs.exceptions.NotImplementedException', ...
                                    'Adjoint operation not implemented');
                            end
                        end
                    else
                        if nargin(x) == 2
                            y = obj.pFunction(x, 1);
                        else
                            y = obj.pFunction(x);
                        end
                    end
                    
                otherwise
                    error('cs.exceptions.InvalidStateException', ...
                        'Unknown sensor matrix type');
            end
        end
        
        function y = mtimes(obj, x)
            if isa(obj, 'cs.data.SensorMatrix')
                y = obj.multiply(x, false);
            else
                y = x.multiply(obj, false);
            end
        end
        
        function y = mrdivide(obj, x)
            y = obj.pMatrix / x;
        end
        
        function y = mldivide(obj, x)
            y = obj.pMatrix \ x;
        end
        
        function n = norm(obj, varargin)
            if obj.IsExplicit
                n = norm(obj.pMatrix, varargin{:});
            else
                error('cs.exceptions.NotImplementedException', ...
                    'Norm computation not supported for implicit matrices');
            end
        end
        
        function s = svd(obj, varargin)
            if obj.IsExplicit
                [s, ~, ~] = svd(obj.pMatrix, varargin{:});
            else
                error('cs.exceptions.NotImplementedException', ...
                    'SVD not supported for implicit matrices');
            end
        end
        
        function c = cond(obj)
            if obj.IsExplicit
                c = cond(obj.pMatrix);
            else
                error('cs.exceptions.NotImplementedException', ...
                    'Condition number not supported for implicit matrices');
            end
        end
        
        function [U, S, V] = economySVD(obj)
            if ~obj.IsExplicit
                error('cs.exceptions.NotImplementedException', ...
                    'SVD not supported for implicit matrices');
            end
            
            [U, S, V] = svd(obj.pMatrix, 'econ');
        end
        
        function A = getMatrix(obj)
            if obj.IsExplicit
                A = obj.pMatrix;
            else
                A = obj.toExplicit();
            end
        end
        
        function A = toExplicit(obj)
            if obj.IsExplicit
                A = obj.pMatrix;
                return;
            end
            
            A = zeros(obj.M, obj.N);
            e = zeros(obj.N, 1);
            
            for i = 1:obj.N
                e(i) = 1;
                A(:, i) = obj.multiply(e, false);
                e(i) = 0;
            end
        end
        
        function display(obj)
            fprintf('  cs.data.SensorMatrix:\n');
            fprintf('    Size: [%d x %d]\n', obj.M, obj.N);
            fprintf('    Type: %s\n', obj.pType);
            
            if obj.IsExplicit
                fprintf('    Norm (Frobenius): %.6f\n', norm(obj.pMatrix, 'fro'));
                fprintf('    Condition number: %.6f\n', cond(obj.pMatrix));
            end
        end
        
        function save(obj, filename)
            if obj.IsExplicit
                save(filename, 'pMatrix', 'pSize', 'pType');
            else
                error('cs.exceptions.NotImplementedException', ...
                    'Cannot save implicit matrix to file');
            end
        end
    end
    
    methods (Static)
        function obj = random(M, N, varargin)
            p = inputParser;
            addParameter(p, 'Normalized', true, @islogical);
            addParameter(p, 'Type', 'gaussian', @ischar);
            parse(p, varargin{:});
            
            switch lower(p.Results.Type)
                case 'gaussian'
                    A = randn(M, N);
                case 'uniform'
                    A = rand(M, N);
                case 'bernoulli'
                    A = sign(randn(M, N));
                otherwise
                    A = randn(M, N);
            end
            
            if p.Results.Normalized
                A = orth(A);
                if N > M
                    extraCols = N - M;
                    extraA = randn(M, extraCols);
                    extraA = extraA - A * (A' * extraA);
                    for i = 1:extraCols
                        extraA(:, i) = extraA(:, i) / norm(extraA(:, i));
                    end
                    A = [A, extraA];
                end
            end
            
            obj = cs.data.SensorMatrix(A);
        end
        
        function obj = partialFourier(M, N)
            idx = randperm(N, M);
            F = fft(eye(N)) / sqrt(N);
            A = F(idx, :);
            obj = cs.data.SensorMatrix(A);
        end
        
        function obj = partialIdentity(M, N)
            idx = randperm(N, M);
            A = zeros(M, N);
            for i = 1:M
                A(i, idx(i)) = 1;
            end
            obj = cs.data.SensorMatrix(A);
        end
        
        function obj = convolution(M, N, kernel)
            functionHandle = @(x, flag) convOp(x, flag, kernel, M, N);
            
            obj = cs.data.SensorMatrix(functionHandle, [M, N]);
            
            function y = convOp(x, flag, k, M, N)
                if flag == 1
                    y = conv(k, x, 'same');
                    y = y(1:M);
                else
                    y = conv(flip(conj(k)), x, 'same');
                    y = y(1:N);
                end
            end
        end
        
        function obj = load(filename)
            data = load(filename);
            if isfield(data, 'pMatrix')
                obj = cs.data.SensorMatrix(data.pMatrix);
            else
                fields = fieldnames(data);
                A = data.(fields{1});
                obj = cs.data.SensorMatrix(A);
            end
        end
    end
end
