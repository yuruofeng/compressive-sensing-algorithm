classdef BCS < cs.core.Algorithm
    % BCS 贝叶斯压缩感知算法
    % 实现基于Relevance Vector Machine (RVM)的快速边际化方法
    % 参考文献: S. Ji, Y. Xue, and L. Carin, "Bayesian Compressive Sensing,"
    %           IEEE Trans. Signal Processing, vol. 56, no. 6, June 2008.
    
    properties (Access = private)
        pHistory
        pTimer
        pInternalParams
    end
    
    properties (Dependent)
        History
    end
    
    methods
        function obj = BCS(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            matrixA = sensorMatrix.getMatrix();
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            obj.assertValidInputs(matrixA, observations);
            observations = observations(:);
            
            [x, gamma, sigma, params] = obj.initialize(matrixA, observations, signalLength);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    [x, sigma, gamma] = obj.expectationStep(matrixA, observations, gamma, params);
                    
                    [gamma, params] = obj.maximizationStep(matrixA, observations, x, sigma, gamma, params);
                    
                    [currentObjective, residual] = obj.computeObjective(matrixA, observations, x, gamma, params);
                    
                    supportSize = nnz(gamma > params.pruned_gamma);
                    
                    [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                        residual, supportSize);
                    
                    obj.pHistory.record('Objective', currentObjective, ...
                                       'Residual', residual, ...
                                       'SupportSize', supportSize);
                    
                    obj.notifyIteration(iterIdx, metrics, x);
                    obj.logProgress(iterIdx, metrics);
                    
                    if converged
                        break;
                    end
                    
                    prevObjective = currentObjective;
                end
                
            catch exception
                info = obj.createErrorInfo(exception, obj.pHistory.CurrentIndex);
                result = cs.core.Result(x, info);
                notify(obj, 'Error');
                return;
            end
            
            obj.pHistory.trim();
            x = obj.postProcess(x, gamma, params);
            
            info = obj.createInfoStruct(obj.pHistory.CurrentIndex, converged, metrics, params);
            info.algorithm_name = 'BCS';
            info.signal_length = signalLength;
            info.num_measurements = numMeasurements;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, gamma, sigma, params] = initialize(obj, matrixA, observations, signalLength)
            x = zeros(signalLength, 1);
            gamma = ones(signalLength, 1);
            sigma = zeros(signalLength, signalLength);
            
            params.pruned_gamma = 1e-3;
            params.noise_var = max(var(observations) * 0.1, 1e-6);
            params.epsilon = 1e-8;
            params.max_gamma = 1e12;
        end
        
        function [x, sigma, gamma] = expectationStep(obj, matrixA, observations, gamma, params)
            numMeasurements = size(matrixA, 1);
            signalLength = size(matrixA, 2);
            
            activeIdx = gamma > params.pruned_gamma;
            numActive = sum(activeIdx);
            
            if numActive == 0
                x = zeros(signalLength, 1);
                sigma = zeros(signalLength, signalLength);
                return;
            end
            
            A_active = matrixA(:, activeIdx);
            gamma_active = gamma(activeIdx);
            
            gammaSqrtInv = 1 ./ sqrt(gamma_active + params.epsilon);
            
            weightedA = A_active .* gammaSqrtInv';
            
            try
                sigma_w = (weightedA' * weightedA + ...
                          params.noise_var * eye(numActive)) \ eye(numActive);
            catch
                sigma_w = pinv(weightedA' * weightedA + ...
                              params.noise_var * eye(numActive));
            end
            
            mu_active = gammaSqrtInv .* (sigma_w * (weightedA' * observations));
            
            sigma_w_full = sigma_w ./ (gammaSqrtInv * gammaSqrtInv');
            
            x = zeros(signalLength, 1);
            x(activeIdx) = mu_active;
            
            sigma = zeros(signalLength, signalLength);
            activeIndices = find(activeIdx);
            for i = 1:numActive
                for j = 1:numActive
                    sigma(activeIndices(i), activeIndices(j)) = sigma_w_full(i, j);
                end
            end
        end
        
        function [gamma, params] = maximizationStep(obj, matrixA, observations, x, sigma, gamma, params)
            signalLength = size(matrixA, 2);
            
            for signalIdx = 1:signalLength
                mu_i = x(signalIdx);
                sigma_ii = sigma(signalIdx, signalIdx);
                
                if gamma(signalIdx) > params.pruned_gamma
                    gamma_new = (mu_i^2 + sigma_ii + params.epsilon);
                    
                    if gamma_new > params.max_gamma
                        gamma(signalIdx) = params.max_gamma;
                    else
                        gamma(signalIdx) = gamma_new;
                    end
                    
                    if gamma(signalIdx) < params.pruned_gamma
                        gamma(signalIdx) = params.pruned_gamma;
                    end
                end
            end
            
            residual = observations - matrixA * x;
            numActive = nnz(gamma > params.pruned_gamma);
            
            if numActive > 0 && numActive < size(matrixA, 1)
                params.noise_var = (norm(residual)^2 + ...
                    trace(matrixA(:, gamma > params.pruned_gamma)' * ...
                          matrixA(:, gamma > params.pruned_gamma) * ...
                          sigma(gamma > params.pruned_gamma, gamma > params.pruned_gamma))) / ...
                    size(matrixA, 1);
                params.noise_var = max(params.noise_var, 1e-10);
            end
        end
        
        function [objVal, residual] = computeObjective(obj, matrixA, observations, x, gamma, params)
            residual = norm(observations - matrixA * x);
            activeIdx = gamma > params.pruned_gamma;
            sparsity = sum(log(gamma(activeIdx) + params.epsilon));
            objVal = 0.5 * residual^2 / params.noise_var - 0.5 * sparsity;
        end
        
        function x = postProcess(obj, x, gamma, params)
            x(gamma <= params.pruned_gamma) = 0;
        end
        
        function assertValidInputs(obj, matrixA, observations)
            numMeasurements = size(matrixA, 1);
            
            if size(observations, 1) ~= numMeasurements && ...
               size(observations, 2) ~= numMeasurements
                throw(cs.exceptions.DimensionMismatchException(...
                    'Observations dimension mismatch. Expected %d, got %dx%d', ...
                    numMeasurements, size(observations, 1), size(observations, 2)));
            end
            
            if size(observations, 2) > 1 && size(observations, 1) == numMeasurements
                warning('BCS:MultipleColumns', ...
                    'BCS is designed for single vector. Using first column only.');
            end
        end
        
        function name = getAlgorithmName(obj)
            name = 'Bayesian Compressive Sensing';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '1.0.0';
        end
        
        function ref = getAlgorithmReference(obj)
            ref = 'S. Ji, Y. Xue, and L. Carin, "Bayesian Compressive Sensing," ' + ...
                  'IEEE Trans. Signal Processing, vol. 56, no. 6, June 2008.';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
            if ~isprop(opts, 'Tolerance') || isempty(opts.Tolerance)
                validatedOpts.Tolerance = 1e-6;
            end
        end
        
        function info = createInfoStruct(obj, iterations, converged, metrics, params)
            info = struct();
            info.iterations = iterations;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.history = obj.pHistory.toObject();
            info.noise_variance = params.noise_var;
            info.support_size = metrics.support_size;
        end
        
        function info = createErrorInfo(obj, exception, iterations)
            info = struct();
            info.iterations = iterations;
            info.converged = false;
            info.error = exception.message;
            info.exception = exception;
            info.algorithm_name = 'BCS';
        end
        
        function [converged, metrics] = checkConvergence(obj, iterIdx, currentObjective, prevObjective, residual, supportSize)
            converged = false;
            metrics = struct();
            
            metrics.objective = currentObjective;
            metrics.residual = residual;
            metrics.support_size = supportSize;
            
            if iterIdx >= obj.pOptions.MaxIterations
                converged = true;
                metrics.stop_reason = 'MaxIterations';
                return;
            end
            
            if iterIdx > 1
                relChange = abs(currentObjective - prevObjective) / (abs(prevObjective) + obj.pOptions.Tolerance);
                
                if relChange < obj.pOptions.Tolerance && iterIdx >= 5
                    converged = true;
                    metrics.stop_reason = 'ToleranceMet';
                end
            end
        end
        
        function notifyIteration(obj, iterIdx, metrics, x)
            notify(obj, 'IterationComplete');
        end
        
        function logProgress(obj, iterIdx, metrics)
            if obj.pOptions.Verbose && mod(iterIdx, obj.pOptions.DisplayInterval) == 0
                fprintf('  Iter %4d: Objective=%.6e, Residual=%.6e, Support=%d\n', ...
                    iterIdx, metrics.objective, metrics.residual, metrics.support_size);
            end
        end
    end
end
