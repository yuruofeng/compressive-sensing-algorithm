classdef TMSBL < cs.core.Algorithm
    % TMSBL 时间相关多测量向量稀疏贝叶斯学习
    % 利用测量向量间的时间相关性进行稀疏重构
    
    properties (Access = private)
        pHistory
        pTimer
        pInternalParams
    end
    
    methods
        function obj = TMSBL(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            if size(observations, 2) == 1
                observations = observations';
            end
            numTimeSamples = size(observations, 2);
            
            [X, gamma, Sigma, params] = obj.initialize(sensorMatrix, observations, signalLength, numTimeSamples);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    [X, Sigma] = obj.expectationStep(sensorMatrix, observations, gamma, params, signalLength, numTimeSamples);
                    
                    [gamma, params] = obj.maximizationStep(sensorMatrix, observations, X, Sigma, gamma, params, signalLength, numTimeSamples);
                    
                    [currentObjective, residual] = obj.computeObjective(sensorMatrix, observations, X, gamma, params);
                    
                    supportSize = nnz(sum(abs(X), 2) > params.pruned_gamma);
                    
                    [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                        residual, supportSize);
                    
                    obj.pHistory.record('Objective', currentObjective, ...
                                       'Residual', residual, ...
                                       'SupportSize', supportSize);
                    
                    obj.notifyIteration(iterIdx, metrics, X);
                    obj.logProgress(iterIdx, metrics);
                    
                    if converged
                        break;
                    end
                    
                    prevObjective = currentObjective;
                end
                
            catch exception
                info = struct();
                info.iterations = obj.pHistory.CurrentIndex;
                info.converged = false;
                info.error = exception;
                info.algorithm_name = 'TMSBL';
                result = cs.core.Result(X(:,1), info);
                notify(obj, 'Error');
                return;
            end
            
            obj.pHistory.trim();
            X = obj.postProcess(X, gamma, params);
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'TMSBL';
            info.num_measurements = numTimeSamples;
            
            result = cs.core.Result(X, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [X, gamma, Sigma, params] = initialize(obj, ~, observations, signalLength, numTimeSamples)
            X = zeros(signalLength, numTimeSamples);
            gamma = ones(signalLength, 1);
            Sigma = zeros(signalLength, signalLength, numTimeSamples);
            
            params.pruned_gamma = 1e-3;
            params.noise_var = max(var(observations(:)) * 0.01, 1e-6);
            params.epsilon = 1e-8;
            params.lambda_init = 1e-3;
            params.C = eye(numTimeSamples);
            
            if obj.pOptions.LearnLambda
                params.lambda = params.lambda_init;
            else
                params.lambda = obj.pOptions.Lambda;
            end
        end
        
        function [X, Sigma] = expectationStep(obj, sensorMatrix, observations, gamma, params, signalLength, ~)
            matrixA = sensorMatrix.getMatrix();
            numMeasurements = size(matrixA, 1);
            
            gammaMat = diag(gamma);
            priorCov = gammaMat;
            
            weightedA = matrixA * gammaMat;
            covObservations = weightedA * matrixA' + params.noise_var * eye(numMeasurements);
            
            try
                covInv = inv(covObservations + params.epsilon * eye(numMeasurements));
            catch
                covInv = pinv(covObservations);
            end
            
            X = gammaMat * matrixA' * covInv * observations;
            
            Sigma = gammaMat - gammaMat * matrixA' * covInv * matrixA * gammaMat;
        end
        
        function [gamma, params] = maximizationStep(obj, sensorMatrix, observations, X, Sigma, gamma, params, signalLength, numTimeSamples)
            for signalIdx = 1:signalLength
                xRow = X(signalIdx, :);
                sigmaDiag = Sigma(signalIdx, signalIdx);
                
                gamma(signalIdx) = (norm(xRow)^2 + numTimeSamples * sigmaDiag + params.epsilon) / numTimeSamples;
                gamma(signalIdx) = max(gamma(signalIdx), 0);
            end
            
            residualMat = observations - sensorMatrix.multiply(X, false);
            residualNormSq = norm(residualMat, 'fro')^2;
            
            traceTerm = 0;
            matrixA = sensorMatrix.getMatrix();
            for sampleIdx = 1:numTimeSamples
                traceTerm = traceTerm + trace(matrixA * Sigma * matrixA');
            end
            
            params.noise_var = (residualNormSq + numTimeSamples * params.noise_var * size(matrixA, 1) - traceTerm) ...
                / (numTimeSamples * size(matrixA, 1));
            params.noise_var = max(params.noise_var, 1e-10);
            
            if obj.pOptions.LearnLambda
                activeCount = nnz(gamma > params.pruned_gamma);
                if activeCount > 0
                    params.lambda = sum(gamma(gamma > params.pruned_gamma)) / activeCount;
                    params.lambda = max(1e-6, min(1e2, params.lambda));
                end
            end
        end
        
        function [objVal, residual] = computeObjective(obj, sensorMatrix, observations, X, ~, params)
            residual = norm(observations - sensorMatrix.multiply(X, false), 'fro');
            sparsity = sum(sum(abs(X)));
            objVal = 0.5 * residual^2 / params.noise_var + obj.pOptions.Lambda * sparsity;
        end
        
        function X = postProcess(obj, X, gamma, params)
            for rowIdx = 1:size(X, 1)
                if gamma(rowIdx) <= params.pruned_gamma
                    X(rowIdx, :) = 0;
                end
            end
        end
        
        function name = getAlgorithmName(obj)
            name = 'Temporal Multi-Measurement Vector SBL';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'Z. Zhang and B. D. Rao, "Sparse Signal Recovery With Temporally Correlated Source Vectors," IEEE J-STSP, 2011';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
