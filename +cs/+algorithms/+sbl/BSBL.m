classdef BSBL < cs.core.Algorithm
    % BSBL 块稀疏贝叶斯学习算法
    % 实现BSBL-FM(快速边际化)和BSBL-BO(边界优化)两种模式
    
    properties (Access = private)
        pBlockStructure
        pHistory
        pTimer
        pInternalParams
    end
    
    properties (Dependent)
        BlockStructure
    end
    
    methods
        function obj = BSBL(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
        end
        
        function bs = get.BlockStructure(obj)
            bs = obj.pBlockStructure;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations, blockStruct)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            obj.assertValidInputs(sensorMatrix.getMatrix(), observations);
            
            if nargin < 3 || isempty(blockStruct)
                blockStruct = cs.data.BlockStructure.equalBlock(sensorMatrix.N, 1);
            elseif ~isa(blockStruct, 'cs.data.BlockStructure')
                blockStruct = cs.data.BlockStructure(blockStruct);
            end
            obj.pBlockStructure = blockStruct;
            
            [x, gamma, Sigma, internalParams] = obj.initialize(sensorMatrix, observations, blockStruct);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    [x, Sigma] = obj.expectationStep(sensorMatrix, observations, gamma, internalParams);
                    
                    [gamma, internalParams] = obj.maximizationStep(sensorMatrix, observations, x, Sigma, gamma, internalParams);
                    
                    [currentObjective, residual] = obj.computeObjective(sensorMatrix, observations, x, gamma, internalParams);
                    
                    [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                        residual, nnz(gamma > internalParams.pruned_gamma));
                    
                    obj.pHistory.record('Objective', currentObjective, ...
                                       'Residual', residual, ...
                                       'SupportSize', metrics.support_size);
                    
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
            x = obj.postProcess(x, gamma, internalParams);
            
            info = obj.createInfoStruct(obj.pHistory.CurrentIndex, converged, metrics, internalParams);
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, gamma, Sigma, params] = initialize(obj, sensorMatrix, observations, blockStruct)
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            numBlocks = blockStruct.NumBlocks;
            
            x = zeros(signalLength, 1);
            gamma = ones(numBlocks, 1);
            Sigma = [];
            
            params.pruned_gamma = 1e-3;
            params.noise_var = max(var(observations) * 0.1, 1e-6);
            params.learn_type = 1;
            params.epsilon = 1e-8;
            params.rho_init = 0.95;
            
            params.B = cell(numBlocks, 1);
            for blockIdx = 1:numBlocks
                params.B{blockIdx} = eye(blockStruct.BlockLengths(blockIdx));
            end
        end
        
        function [x, Sigma] = expectationStep(obj, sensorMatrix, observations, gamma, params)
            numBlocks = obj.pBlockStructure.NumBlocks;
            signalLength = obj.pBlockStructure.TotalLength;
            
            weightMatrix = zeros(signalLength, signalLength);
            for blockIdx = 1:numBlocks
                blockIndices = obj.pBlockStructure.getBlockIndices(blockIdx);
                if gamma(blockIdx) > params.pruned_gamma
                    weightMatrix(blockIndices, blockIndices) = gamma(blockIdx) * params.B{blockIdx};
                end
            end
            
            matrixA = sensorMatrix.getMatrix();
            covWeighted = matrixA * weightMatrix * matrixA' + params.noise_var * eye(size(matrixA, 1));
            
            try
                covWeightedInv = inv(covWeighted + params.epsilon * eye(size(covWeighted)));
            catch
                covWeightedInv = pinv(covWeighted);
            end
            
            Sigma = weightMatrix - weightMatrix * matrixA' * covWeightedInv * matrixA * weightMatrix;
            x = weightMatrix * matrixA' * covWeightedInv * observations;
        end
        
        function [gamma, params] = maximizationStep(obj, sensorMatrix, observations, x, Sigma, gamma, params)
            numBlocks = obj.pBlockStructure.NumBlocks;
            
            for blockIdx = 1:numBlocks
                blockIndices = obj.pBlockStructure.getBlockIndices(blockIdx);
                blockLength = length(blockIndices);
                
                xBlock = x(blockIndices);
                SigmaBlock = Sigma(blockIndices, blockIndices);
                
                if gamma(blockIdx) > params.pruned_gamma
                    blockCorrMatrix = params.B{blockIdx};
                    
                    gamma(blockIdx) = (xBlock' * inv(blockCorrMatrix) * xBlock + ...
                        trace(inv(blockCorrMatrix) * SigmaBlock) + params.epsilon) / blockLength;
                    
                    if params.learn_type == 1
                        correlationMat = (xBlock * xBlock' + SigmaBlock) / gamma(blockIdx);
                        if blockLength > 1
                            diagElements = diag(diag(correlationMat));
                            offDiagElements = correlationMat - diagElements;
                            offDiagSum = sum(offDiagElements(:));
                            diagMean = mean(diag(correlationMat));
                            if diagMean > 0
                                rhoEstimate = min(0.99, max(0, offDiagSum / (blockLength * (blockLength-1) * diagMean)));
                            else
                                rhoEstimate = params.rho_init;
                            end
                            params.B{blockIdx} = toeplitz(rhoEstimate.^(0:blockLength-1));
                        end
                    end
                end
                
                gamma(blockIdx) = max(gamma(blockIdx), 0);
            end
            
            residualVec = observations - sensorMatrix.multiply(x, false);
            params.noise_var = (norm(residualVec)^2 + sensorMatrix.NumMeasurements * params.noise_var - ...
                trace(sensorMatrix.multiply(sensorMatrix.multiply(Sigma, true), false))) / sensorMatrix.NumMeasurements;
            params.noise_var = max(params.noise_var, 1e-10);
        end
        
        function [objVal, residual] = computeObjective(obj, sensorMatrix, observations, x, ~, params)
            residual = norm(observations - sensorMatrix.multiply(x, false));
            sparsity = sum(abs(x));
            objVal = 0.5 * residual^2 / params.noise_var + obj.pOptions.Lambda * sparsity;
        end
        
        function x = postProcess(obj, x, gamma, params)
            numBlocks = obj.pBlockStructure.NumBlocks;
            for blockIdx = 1:numBlocks
                if gamma(blockIdx) <= params.pruned_gamma
                    blockIndices = obj.pBlockStructure.getBlockIndices(blockIdx);
                    x(blockIndices) = 0;
                end
            end
        end
        
        function info = createInfoStruct(obj, numIterations, converged, metrics, params)
            info.iterations = numIterations;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.support = find(abs(obj.pHistory.ObjectiveValues(1:numIterations)) > 0);
            info.history = obj.pHistory.toObject();
            info.noise_variance = params.noise_var;
            info.algorithm_name = 'BSBL';
        end
        
        function info = createErrorInfo(obj, exception, numIterations)
            info.iterations = numIterations;
            info.converged = false;
            info.error = exception;
            info.algorithm_name = 'BSBL';
        end
        
        function name = getAlgorithmName(obj)
            name = 'Block Sparse Bayesian Learning';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'Z. Zhang and B. D. Rao, "Sparse Signal Recovery With Temporally Correlated Source Vectors Using Sparse Bayesian Learning," IEEE J-STSP, 2011';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
