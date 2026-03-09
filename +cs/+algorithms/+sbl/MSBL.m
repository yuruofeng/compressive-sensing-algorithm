classdef MSBL < cs.core.Algorithm
    % MSBL 多测量向量稀疏贝叶斯学习
    % 标准MMV稀疏贝叶斯学习算法
    
    properties (Access = private)
        pHistory
        pTimer
    end
    
    methods
        function obj = MSBL(varargin)
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
            
            [X, gamma, params] = obj.initialize(sensorMatrix, observations, signalLength, numTimeSamples);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    [X, Sigma] = obj.expectationStep(sensorMatrix, observations, gamma, params, signalLength, numTimeSamples);
                    
                    [gamma, params] = obj.maximizationStep(sensorMatrix, observations, X, Sigma, gamma, params, signalLength, numTimeSamples);
                    
                    [currentObjective, residual] = obj.computeObjective(sensorMatrix, observations, X, gamma, params);
                    
                    supportSize = nnz(gamma > params.pruned_gamma);
                    
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
                info.algorithm_name = 'MSBL';
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
            info.algorithm_name = 'MSBL';
            info.num_measurements = numTimeSamples;
            
            result = cs.core.Result(X, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [X, gamma, params] = initialize(obj, ~, ~, signalLength, numTimeSamples)
            X = zeros(signalLength, numTimeSamples);
            gamma = ones(signalLength, 1);
            
            params.pruned_gamma = 1e-3;
            params.noise_var = 1e-6;
            params.epsilon = 1e-8;
        end
        
        function [X, Sigma] = expectationStep(obj, sensorMatrix, observations, gamma, params, signalLength, ~)
            matrixA = sensorMatrix.getMatrix();
            numMeasurements = size(matrixA, 1);
            
            gammaSqrt = sqrt(gamma);
            gammaSqrtInv = 1 ./ (gammaSqrt + params.epsilon);
            
            weightedA = matrixA .* gammaSqrt';
            
            weightedASq = weightedA * weightedA';
            covInv = (weightedASq + params.noise_var * eye(numMeasurements)) \ eye(numMeasurements);
            
            X = diag(gamma) * matrixA' * covInv * observations;
            
            Sigma = diag(gamma) - diag(gamma) * matrixA' * covInv * matrixA * diag(gamma);
        end
        
        function [gamma, params] = maximizationStep(obj, sensorMatrix, observations, X, Sigma, gamma, params, signalLength, numTimeSamples)
            for signalIdx = 1:signalLength
                xRow = X(signalIdx, :);
                sigmaDiag = Sigma(signalIdx, signalIdx);
                
                gamma(signalIdx) = (norm(xRow)^2 + numTimeSamples * sigmaDiag + params.epsilon) / numTimeSamples;
                gamma(signalIdx) = max(gamma(signalIdx), 0);
            end
            
            residualMat = observations - sensorMatrix.multiply(X, false);
            params.noise_var = norm(residualMat, 'fro')^2 / (numTimeSamples * size(sensorMatrix.getMatrix(), 1));
            params.noise_var = max(params.noise_var, 1e-10);
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
            name = 'Multi-Measurement Vector SBL';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'D. P. Wipf and B. D. Rao, "An Empirical Bayesian Strategy for Solving the Simultaneous Sparse Approximation Problem," IEEE TSP, 2007';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
