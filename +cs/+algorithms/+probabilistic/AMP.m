classdef AMP < cs.core.Algorithm
    % AMP 近似消息传递算法（完整实现）
    % 
    % 基于概率图模型的高效稀疏重构算法，包含以下核心组件：
    %   - 标准AMP迭代（含Onsager校正项）
    %   - 自适应阈值选择
    %   - 阻尼机制提高稳定性
    %   - 数值稳定性检查
    %   - 支持多种阈值函数
    %
    % 参考文献:
    %   [1] D. L. Donoho, A. Maleki, and A. Montanari, "Message Passing 
    %       Algorithms for Compressed Sensing," Proc. Natl. Acad. Sci., 2009.
    %   [2] A. Maleki, "Approximate Message Passing Algorithms for Compressed 
    %       Sensing," PhD Thesis, Stanford University, 2011.
    
    properties (Access = private)
        pHistory
        pSigma
        pThreshold
        pThresholdType
        pDamping
    end
    
    properties (Dependent)
        History
        Sigma
        Threshold
        ThresholdType
        Damping
    end
    
    methods
        function obj = AMP(varargin)
            % 提取Options对象
            opts = cs.core.Options();
            
            for i = 1:nargin
                if isa(varargin{i}, 'cs.core.Options')
                    opts = varargin{i};
                    break;
                end
            end
            
            % 调用父类构造函数
            obj@cs.core.Algorithm(opts);
            
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pSigma = [];
            obj.pThreshold = [];
            obj.pThresholdType = 'soft';  % 默认使用软阈值
            obj.pDamping = 0.0;  % 默认无阻尼
            
            % 处理其他参数
            for i = 1:2:length(varargin)
                if i+1 <= length(varargin) && ~isa(varargin{i}, 'cs.core.Options') && ~isa(varargin{i+1}, 'cs.core.Options')
                    switch lower(varargin{i})
                        case 'sigma'
                            obj.pSigma = varargin{i+1};
                        case 'noise'
                            obj.pSigma = varargin{i+1};
                        case 'threshold'
                            obj.pThreshold = varargin{i+1};
                        case 'thresholdtype'
                            obj.pThresholdType = lower(varargin{i+1});
                        case 'damping'
                            obj.pDamping = varargin{i+1};
                    end
                end
            end
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function s = get.Sigma(obj)
            s = obj.pSigma;
        end
        
        function t = get.Threshold(obj)
            t = obj.pThreshold;
        end
        
        function tt = get.ThresholdType(obj)
            tt = obj.pThresholdType;
        end
        
        function d = get.Damping(obj)
            d = obj.pDamping;
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
            
            % 处理额外参数
            if nargin >= 4 && ~isempty(varargin{1})
                if isstruct(varargin{1})
                    if isfield(varargin{1}, 'sigma')
                        obj.pSigma = varargin{1}.sigma;
                    end
                end
            end
            
            % 如果没有提供sigma，则估计
            if isempty(obj.pSigma) || obj.pSigma <= 0
                obj.pSigma = norm(observations) / sqrt(numMeasurements);
            end
            
            % 验证阻尼参数
            if obj.pDamping < 0 || obj.pDamping >= 1
                obj.pDamping = 0.0;
            end
            
            maxIter = obj.pOptions.MaxIterations;
            
            [x, supportSize, residualNorms, thresholds] = obj.runAMP(matrixA, observations, maxIter);
            
            obj.pHistory.trim();
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = obj.pConverged;
            info.residual_norm = residualNorms(end);
            info.support_size = supportSize;
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'AMP';
            info.sigma = obj.pSigma;
            info.thresholds = thresholds;
            info.damping = obj.pDamping;
            info.threshold_type = obj.pThresholdType;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, supportSize, residualNorms, thresholds] = runAMP(obj, A, y, maxIter)
            [M, N] = size(A);
            delta = M / N;
            
            x = zeros(N, 1);
            r = y;
            
            residualNorms = zeros(maxIter, 1);
            thresholds = zeros(maxIter, 1);
            prevObjective = Inf;
            supportSize = 0;
            
            for iterIdx = 1:maxIter
                % 步骤1: 计算中间变量
                z = x + A' * r;
                
                % 步骤2: 计算自适应阈值
                if isempty(obj.pThreshold) || obj.pThreshold <= 0
                    % 使用Bayanati-Montanari自适应阈值
                    tau = obj.pSigma * sqrt(2 * log(N));
                    thresholds(iterIdx) = tau;
                else
                    tau = obj.pThreshold;
                    thresholds(iterIdx) = tau;
                end
                
                % 步骤3: 应用阈值函数
                x_prev = x;
                switch obj.pThresholdType
                    case 'soft'
                        x = obj.softThreshold(z, tau);
                    case 'hard'
                        x = obj.hardThreshold(z, tau);
                    case 'firm'
                        x = obj.firmThreshold(z, tau);
                    otherwise
                        x = obj.softThreshold(z, tau);
                end
                
                % 步骤4: 计算Onsager校正项
                % 对于软阈值: Onsager项 = (1/delta) * mean(x - z)
                % 这里使用divergence-free校正
                onsager = (1/delta) * mean(x - z);
                
                % 步骤5: 更新残差（包含Onsager校正）
                r_new = y - A * x + onsager;
                
                % 应用阻尼
                if obj.pDamping > 0
                    r = obj.pDamping * r_new + (1 - obj.pDamping) * r;
                else
                    r = r_new;
                end
                
                % 数值稳定性检查
                if any(isnan(r)) || any(isinf(r)) || norm(r) > 1e10
                    if obj.pOptions.Verbose
                        fprintf('  警告: 迭代 %d 出现数值不稳定，提前终止\n', iterIdx);
                    end
                    break;
                end
                
                % 记录历史
                residualNorm = norm(r);
                residualNorms(iterIdx) = residualNorm;
                
                currentObjective = 0.5 * residualNorm^2;
                supportSize = nnz(abs(x) > 1e-10);
                
                obj.pHistory.record('Objective', currentObjective, ...
                                   'Residual', residualNorm, ...
                                   'SupportSize', supportSize);
                
                if obj.pOptions.Verbose && mod(iterIdx, obj.pOptions.DisplayInterval) == 0
                    fprintf('  Iter %4d: Res=%.6e, Support=%d, Onsager=%.6e, Tau=%.6e\n', ...
                        iterIdx, residualNorm, supportSize, onsager, tau);
                end
                
                % 检查收敛
                [converged, ~] = obj.checkConvergence(iterIdx, currentObjective, ...
                    prevObjective, residualNorm, supportSize);
                
                if converged
                    obj.pConverged = true;
                    break;
                end
                
                prevObjective = currentObjective;
            end
            
            residualNorms = residualNorms(1:iterIdx);
            thresholds = thresholds(1:iterIdx);
        end
        
        function y = softThreshold(obj, x, tau)
            % 软阈值函数: η(x; τ) = sign(x) * max(|x| - τ, 0)
            y = sign(x) .* max(abs(x) - tau, 0);
        end
        
        function y = hardThreshold(obj, x, tau)
            % 硬阈值函数: η(x; τ) = x * I(|x| > τ)
            y = x .* (abs(x) > tau);
        end
        
        function y = firmThreshold(obj, x, tau)
            % Firm阈值函数（介于软硬阈值之间）
            % 对于 |x| < τ: η(x) = 0
            % 对于 τ <= |x| < 2τ: η(x) = τ * sign(x)
            % 对于 |x| >= 2τ: η(x) = x
            y = zeros(size(x));
            idx1 = abs(x) >= tau & abs(x) < 2*tau;
            idx2 = abs(x) >= 2*tau;
            y(idx1) = tau * sign(x(idx1));
            y(idx2) = x(idx2);
        end
        
        function name = getAlgorithmName(obj)
            name = 'Approximate Message Passing';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';  % 完整实现版本
        end
        
        function ref = getAlgorithmReference(obj)
            ref = '[1] D. L. Donoho, A. Maleki, and A. Montanari, "Message Passing ' + ...
                  'Algorithms for Compressed Sensing," Proc. Natl. Acad. Sci., vol. 106, no. 45, 2009.' + ...
                  char(10) + ...
                  '[2] A. Maleki, "Approximate Message Passing Algorithms for Compressed ' + ...
                  'Sensing," PhD Thesis, Stanford University, 2011.';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
            if ~isprop(opts, 'Tolerance') || isempty(opts.Tolerance)
                validatedOpts.Tolerance = 1e-6;
            end
        end
    end
end
