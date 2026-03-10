classdef FISTA < cs.core.Algorithm
    % FISTA 快速迭代软阈值算法
    % 基于Nesterov加速的ISTA算法，收敛速度O(1/k^2)
    % 参考文献: A. Beck and M. Teboulle, "A Fast Iterative Shrinkage-Thresholding 
    %           Algorithm for Linear Inverse Problems," SIAM J. Imaging Sci., 2009.
    
    properties (Access = private)
        pHistory
        pLambda
        pStepSize
    end
    
    properties (Dependent)
        History
        Lambda
        StepSize
    end
    
    methods
        function obj = FISTA(varargin)
            % 提取Options对象或使用默认值
            opts = cs.core.Options();
            
            for i = 1:nargin
                if isa(varargin{i}, 'cs.core.Options')
                    opts = varargin{i};
                    break;
                end
            end
            
            % 必须在第一行调用父类构造函数
            obj@cs.core.Algorithm(opts);
            
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pLambda = 0.1;
            obj.pStepSize = [];
            
            % 处理其他参数
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin) && ~isa(varargin{i}, 'cs.core.Options') && ~isa(varargin{i+1}, 'cs.core.Options')
                    switch lower(varargin{i})
                        case 'lambda'
                            obj.pLambda = varargin{i+1};
                        case 'stepsize'
                            obj.pStepSize = varargin{i+1};
                        case 'mu'
                            obj.pStepSize = varargin{i+1};
                    end
                end
            end
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function l = get.Lambda(obj)
            l = obj.pLambda;
        end
        
        function s = get.StepSize(obj)
            s = obj.pStepSize;
        end
        
        function obj = set.Lambda(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', '>', 0});
            obj.pLambda = val;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations, varargin)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            matrixA = sensorMatrix.getMatrix();
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            obj.assertValidInputs(matrixA, observations);
            observations = observations(:);
            
            if isempty(obj.pStepSize)
                svs = svds(matrixA, 1);
                obj.pStepSize = 1.0 / (svs^2);
            end
            
            maxIter = obj.pOptions.MaxIterations;
            
            [x, supportSize, residualNorms] = obj.runFISTA(matrixA, observations, maxIter);
            
            obj.pHistory.trim();
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = obj.pConverged;
            info.residual_norm = residualNorms(end);
            info.support_size = supportSize;
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'FISTA';
            info.lambda = obj.pLambda;
            info.step_size = obj.pStepSize;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, supportSize, residualNorms] = runFISTA(obj, matrixA, y, maxIter)
            signalLength = size(matrixA, 2);
            
            x = zeros(signalLength, 1);
            z = x;
            t = 1;
            
            residualNorms = zeros(maxIter, 1);
            prevObjective = Inf;
            supportSize = 0;
            
            AtA = matrixA' * matrixA;
            Aty = matrixA' * y;
            
            for iterIdx = 1:maxIter
                gradient = Aty - AtA * z;
                x_new = obj.softThreshold(z + obj.pStepSize * gradient, ...
                    obj.pStepSize * obj.pLambda);
                
                t_new = (1 + sqrt(1 + 4 * t^2)) / 2;
                z = x_new + ((t - 1) / t_new) * (x_new - x);
                
                x = x_new;
                t = t_new;
                
                residual = y - matrixA * x;
                residualNorm = norm(residual);
                residualNorms(iterIdx) = residualNorm;
                
                currentObjective = 0.5 * residualNorm^2 + obj.pLambda * norm(x, 1);
                
                supportSize = nnz(abs(x) > 1e-10);
                
                obj.pHistory.record('Objective', currentObjective, ...
                                   'Residual', residualNorm, ...
                                   'SupportSize', supportSize);
                
                if obj.pOptions.Verbose && mod(iterIdx, obj.pOptions.DisplayInterval) == 0
                    fprintf('  Iter %4d: Obj=%.6e, Res=%.6e, Support=%d\n', ...
                        iterIdx, currentObjective, residualNorm, supportSize);
                end
                
                [converged, ~] = obj.checkConvergence(iterIdx, currentObjective, ...
                    prevObjective, residualNorm, supportSize);
                
                if converged
                    obj.pConverged = true;
                    break;
                end
                
                prevObjective = currentObjective;
            end
            
            residualNorms = residualNorms(1:iterIdx);
        end
        
        function y = softThreshold(obj, x, threshold)
            y = sign(x) .* max(abs(x) - threshold, 0);
        end
        
        function name = getAlgorithmName(obj)
            name = 'Fast Iterative Shrinkage-Thresholding Algorithm';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '1.0.0';
        end
        
        function ref = getAlgorithmReference(obj)
            ref = 'A. Beck and M. Teboulle, "A Fast Iterative Shrinkage-Thresholding ' + ...
                  'Algorithm for Linear Inverse Problems," SIAM J. Imaging Sci., vol. 2, no. 1, 2009.';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
            if ~isprop(opts, 'Tolerance') || isempty(opts.Tolerance)
                validatedOpts.Tolerance = 1e-6;
            end
        end
    end
end
