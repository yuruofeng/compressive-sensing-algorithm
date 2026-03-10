classdef OMP < cs.core.Algorithm
    % OMP 正交匹配追踪算法
    % 经典贪婪迭代算法，用于稀疏信号重构
    % 参考文献: J. A. Tropp and A. C. Gilbert, "Signal Recovery From Random 
    %           Measurements Via Orthogonal Matching Pursuit," 
    %           IEEE Trans. Info. Theory, vol. 53, no. 12, 2007.
    
    properties (Access = private)
        pHistory
        pSparsity
    end
    
    properties (Dependent)
        History
    end
    
    methods
        function obj = OMP(varargin)
            % 提取Options对象或使用默认值
            opts = cs.core.Options();
            hasOpts = false;
            
            for i = 1:nargin
                if isa(varargin{i}, 'cs.core.Options')
                    opts = varargin{i};
                    hasOpts = true;
                    break;
                end
            end
            
            % 必须在第一行调用父类构造函数
            obj@cs.core.Algorithm(opts);
            
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pSparsity = [];
            
            % 处理其他参数
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin) && ~isa(varargin{i}, 'cs.core.Options') && ~isa(varargin{i+1}, 'cs.core.Options')
                    switch lower(varargin{i})
                        case 'sparsity'
                            obj.pSparsity = varargin{i+1};
                        case 'k'
                            obj.pSparsity = varargin{i+1};
                    end
                end
            end
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations, varargin)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            matrixA = sensorMatrix.getMatrix();
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            if nargin >= 4 && ~isempty(varargin{1})
                obj.pSparsity = varargin{1};
            end
            
            obj.assertValidInputs(matrixA, observations);
            observations = observations(:);
            
            if isempty(obj.pSparsity)
                obj.pSparsity = min(floor(numMeasurements / 2), signalLength);
            end
            
            maxIter = min(obj.pSparsity, obj.pOptions.MaxIterations);
            
            [x, supportSet, residualNorms] = obj.runOMP(matrixA, observations, maxIter);
            
            obj.pHistory.trim();
            
            rowNorms = abs(x);
            supportSize = nnz(rowNorms > 1e-10);
            
            info = struct();
            info.iterations = length(supportSet);
            info.converged = true;
            info.residual_norm = residualNorms(end);
            info.support_size = supportSize;
            info.support_indices = supportSet;
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'OMP';
            info.sparsity = obj.pSparsity;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = length(supportSet);
            obj.pConverged = true;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, supportSet, residualNorms] = runOMP(obj, matrixA, y, maxIter)
            [numMeasurements, signalLength] = size(matrixA);
            
            supportSet = [];
            residual = y;
            x = zeros(signalLength, 1);
            residualNorms = zeros(maxIter, 1);
            
            for iterIdx = 1:maxIter
                correlations = abs(matrixA' * residual);
                
                [maxCorr, maxIdx] = max(correlations);
                
                if maxCorr < obj.pOptions.Tolerance
                    break;
                end
                
                if ~ismember(maxIdx, supportSet)
                    supportSet = [supportSet; maxIdx];
                end
                
                A_support = matrixA(:, supportSet);
                
                try
                    x_support = pinv(A_support) * y;
                catch
                    x_support = A_support \ y;
                end
                
                x = zeros(signalLength, 1);
                x(supportSet) = x_support;
                
                residual = y - A_support * x_support;
                residualNorm = norm(residual);
                residualNorms(iterIdx) = residualNorm;
                
                obj.pHistory.record('Objective', residualNorm, ...
                                   'Residual', residualNorm, ...
                                   'SupportSize', length(supportSet));
                
                if obj.pOptions.Verbose && mod(iterIdx, obj.pOptions.DisplayInterval) == 0
                    fprintf('  Iter %4d: Residual=%.6e, Support=%d\n', ...
                        iterIdx, residualNorm, length(supportSet));
                end
                
                if residualNorm < obj.pOptions.Tolerance
                    break;
                end
            end
            
            residualNorms = residualNorms(1:iterIdx);
        end
        
        function name = getAlgorithmName(obj)
            name = 'Orthogonal Matching Pursuit';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '1.0.0';
        end
        
        function ref = getAlgorithmReference(obj)
            ref = 'J. A. Tropp and A. C. Gilbert, "Signal Recovery From Random ' + ...
                  'Measurements Via Orthogonal Matching Pursuit," ' + ...
                  'IEEE Trans. Info. Theory, vol. 53, no. 12, 2007.';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
            if ~isprop(opts, 'Tolerance') || isempty(opts.Tolerance)
                validatedOpts.Tolerance = 1e-6;
            end
        end
    end
end
