classdef IHT < cs.core.Algorithm
    % IHT 迭代硬阈值算法
    % 简单高效的稀疏信号重构算法，适用于大规模问题
    % 参考文献: T. Blumensath and M. E. Davies, "Iterative Hard Thresholding for 
    %           Compressed Sensing," Applied and Computational Harmonic Analysis, 2009.
    
    properties (Access = private)
        pHistory
        pSparsity
        pStepSize
    end
    
    properties (Dependent)
        History
        StepSize
    end
    
    methods
        function obj = IHT(varargin)
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
            obj.pSparsity = [];
            obj.pStepSize = [];
            
            % 处理其他参数
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin) && ~isa(varargin{i}, 'cs.core.Options') && ~isa(varargin{i+1}, 'cs.core.Options')
                    switch lower(varargin{i})
                        case 'sparsity'
                            obj.pSparsity = varargin{i+1};
                        case 'k'
                            obj.pSparsity = varargin{i+1};
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
        
        function s = get.StepSize(obj)
            s = obj.pStepSize;
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
            
            if isempty(obj.pStepSize)
                svs = svds(matrixA, 1);
                obj.pStepSize = 0.9 / (svs^2);
            end
            
            maxIter = obj.pOptions.MaxIterations;
            
            [x, supportSize, residualNorms] = obj.runIHT(matrixA, observations, maxIter);
            
            obj.pHistory.trim();
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = obj.pConverged;
            info.residual_norm = residualNorms(end);
            info.support_size = supportSize;
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'IHT';
            info.sparsity = obj.pSparsity;
            info.step_size = obj.pStepSize;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, supportSize, residualNorms] = runIHT(obj, matrixA, y, maxIter)
            [numMeasurements, signalLength] = size(matrixA);
            
            x = zeros(signalLength, 1);
            residualNorms = zeros(maxIter, 1);
            prevObjective = Inf;
            supportSize = 0;
            
            AtA = matrixA' * matrixA;
            Aty = matrixA' * y;
            
            for iterIdx = 1:maxIter
                gradient = Aty - AtA * x;
                x_temp = x + obj.pStepSize * gradient;
                
                x = obj.hardThreshold(x_temp, obj.pSparsity);
                
                residual = y - matrixA * x;
                residualNorm = norm(residual);
                residualNorms(iterIdx) = residualNorm;
                
                currentObjective = 0.5 * residualNorm^2;
                
                supportSize = nnz(abs(x) > 1e-10);
                
                obj.pHistory.record('Objective', currentObjective, ...
                                   'Residual', residualNorm, ...
                                   'SupportSize', supportSize);
                
                if obj.pOptions.Verbose && mod(iterIdx, obj.pOptions.DisplayInterval) == 0
                    fprintf('  Iter %4d: Residual=%.6e, Support=%d\n', ...
                        iterIdx, residualNorm, supportSize);
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
        
        function x_thresholded = hardThreshold(obj, x, k)
            [sortedVals, sortedIdx] = sort(abs(x), 'descend');
            x_thresholded = zeros(size(x));
            x_thresholded(sortedIdx(1:min(k, length(sortedIdx)))) = x(sortedIdx(1:min(k, length(sortedIdx))));
        end
        
        function name = getAlgorithmName(obj)
            name = 'Iterative Hard Thresholding';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '1.0.0';
        end
        
        function ref = getAlgorithmReference(obj)
            ref = 'T. Blumensath and M. E. Davies, "Iterative Hard Thresholding for ' + ...
                  'Compressed Sensing," Applied and Computational Harmonic Analysis, vol. 27, no. 3, 2009.';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
            if ~isprop(opts, 'Tolerance') || isempty(opts.Tolerance)
                validatedOpts.Tolerance = 1e-6;
            end
        end
    end
end
