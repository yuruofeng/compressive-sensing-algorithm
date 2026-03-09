classdef MFOCUSS < cs.core.Algorithm
    % MFOCUSS 多测量向量FOCUSS算法
    % 使用p范数正则化的迭代重加权最小二乘
    
    properties (Access = private)
        pHistory
        pTimer
        pP
    end
    
    properties (Dependent)
        P
    end
    
    methods
        function obj = MFOCUSS(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pP = 0.8;
            
            if nargin > 0
                for i = 1:2:length(varargin)
                    switch lower(varargin{i})
                        case 'p'
                            obj.pP = varargin{i+1};
                    end
                end
            end
        end
        
        function p = get.P(obj)
            p = obj.pP;
        end
        
        function obj = set.P(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', '>', 0, '<=', 2});
            obj.pP = val;
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
            
            [X, params] = obj.initialize(sensorMatrix, observations, signalLength, numTimeSamples);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    weights = obj.computeWeights(X, params);
                    
                    X = obj.updateSolution(sensorMatrix, observations, weights, params, signalLength, numTimeSamples);
                    
                    [currentObjective, residual] = obj.computeObjective(sensorMatrix, observations, X, params);
                    
                    rowNorms = sqrt(sum(X.^2, 2));
                    supportSize = nnz(rowNorms > params.zeroThreshold);
                    
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
                info.algorithm_name = 'MFOCUSS';
                result = cs.core.Result(X(:,1), info);
                notify(obj, 'Error');
                return;
            end
            
            obj.pHistory.trim();
            X = obj.postProcess(X, params);
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.support = find(rowNorms > params.zeroThreshold);
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'MFOCUSS';
            info.num_measurements = numTimeSamples;
            info.p = obj.pP;
            
            result = cs.core.Result(X, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [X, params] = initialize(obj, sensorMatrix, observations, ~, ~)
            matrixA = sensorMatrix.getMatrix();
            X = matrixA \ observations;
            
            params.lambda = obj.pOptions.Lambda;
            params.p = obj.pP;
            params.epsilon = 1e-8;
            params.zeroThreshold = 1e-10;
        end
        
        function weights = computeWeights(obj, X, params)
            rowNorms = sqrt(sum(X.^2, 2));
            weights = (rowNorms + params.epsilon).^(params.p - 2);
            weights = max(weights, params.epsilon);
        end
        
        function X = updateSolution(obj, sensorMatrix, observations, weights, params, signalLength, ~)
            matrixA = sensorMatrix.getMatrix();
            
            diagWeights = diag(sqrt(weights + params.epsilon));
            diagWeightsInv = diag(1 ./ sqrt(weights + params.epsilon));
            
            weightedA = matrixA * diagWeightsInv;
            
            lambdaReg = params.lambda;
            weightedAtA = weightedA' * weightedA + lambdaReg * eye(signalLength);
            weightedAtObs = weightedA' * observations;
            
            try
                Z = weightedAtA \ weightedAtObs;
            catch
                Z = pinv(weightedAtA) * weightedAtObs;
            end
            
            X = diagWeightsInv * Z;
        end
        
        function [objVal, residual] = computeObjective(obj, sensorMatrix, observations, X, params)
            residual = norm(observations - sensorMatrix.multiply(X, false), 'fro');
            
            rowNorms = sqrt(sum(X.^2, 2));
            objVal = 0.5 * residual^2 + params.lambda * sum(rowNorms.^params.p);
        end
        
        function X = postProcess(obj, X, params)
            rowNorms = sqrt(sum(X.^2, 2));
            zeroRows = rowNorms < params.zeroThreshold;
            X(zeroRows, :) = 0;
        end
        
        function name = getAlgorithmName(obj)
            name = 'Multi-Measurement Vector FOCUSS';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'B. D. Rao and K. Kreutz-Delgado, "An Affine Scaling Methodology for Best Basis Selection," IEEE TSP, 1999';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
