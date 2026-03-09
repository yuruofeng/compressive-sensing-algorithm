classdef LassoADMM < cs.core.Algorithm
    % LassoADMM 使用ADMM算法求解LASSO问题
    % min 0.5||Ax-b||^2 + lambda*||x||_1
    
    properties (Access = private)
        pHistory
        pTimer
        pRho
    end
    
    properties (Dependent)
        Rho
    end
    
    methods
        function obj = LassoADMM(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pRho = 1.0;
        end
        
        function r = get.Rho(obj)
            r = obj.pRho;
        end
        
        function obj = set.Rho(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'positive'});
            obj.pRho = val;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            obj.assertValidInputs(sensorMatrix.getMatrix(), observations);
            
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            [x, z, u, params] = obj.initialize(sensorMatrix, observations, signalLength);
            
            converged = false;
            prevObjective = Inf;
            
            try
                for iterIdx = 1:obj.pOptions.MaxIterations
                    x = obj.updateX(sensorMatrix, observations, z, u, params);
                    
                    zPrev = z;
                    z = obj.updateZ(x, u, params);
                    
                    u = u + x - z;
                    
                    [currentObjective, residual] = obj.computeObjective(sensorMatrix, observations, z, params);
                    
                    primalResidual = norm(x - z);
                    dualResidual = norm(obj.pRho * (z - zPrev));
                    supportSize = nnz(abs(z) > params.zeroThreshold);
                    
                    [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                        residual, supportSize);
                    
                    metrics.primal_residual = primalResidual;
                    metrics.dual_residual = dualResidual;
                    
                    obj.pHistory.record('Objective', currentObjective, ...
                                       'Residual', residual, ...
                                       'SupportSize', supportSize);
                    
                    obj.notifyIteration(iterIdx, metrics, z);
                    obj.logProgress(iterIdx, metrics);
                    
                    if converged && primalResidual < params.epsAbs
                        break;
                    end
                    
                    prevObjective = currentObjective;
                end
                
            catch exception
                info = struct();
                info.iterations = obj.pHistory.CurrentIndex;
                info.converged = false;
                info.error = exception;
                info.algorithm_name = 'LassoADMM';
                result = cs.core.Result(z, info);
                notify(obj, 'Error');
                return;
            end
            
            obj.pHistory.trim();
            x = obj.postProcess(z, params);
            
            info = struct();
            info.iterations = obj.pHistory.CurrentIndex;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.support = find(abs(x) > params.zeroThreshold);
            info.history = obj.pHistory.toObject();
            info.algorithm_name = 'LassoADMM';
            info.rho = obj.pRho;
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = obj.pHistory.CurrentIndex;
            obj.pConverged = converged;
            obj.pElapsedTime = toc(startTime);
        end
    end
    
    methods (Access = protected)
        function [x, z, u, params] = initialize(obj, sensorMatrix, observations, signalLength)
            x = zeros(signalLength, 1);
            z = zeros(signalLength, 1);
            u = zeros(signalLength, 1);
            
            params.lambda = obj.pOptions.Lambda;
            params.epsAbs = obj.pOptions.Tolerance;
            params.epsRel = obj.pOptions.Tolerance;
            params.zeroThreshold = 1e-10;
            params.overRelax = 1.0;
            
            matrixA = sensorMatrix.getMatrix();
            params.AtA = matrixA' * matrixA;
            params.Atb = matrixA' * observations;
            params.maxEigVal = eig(params.AtA);
            params.maxEigVal = max(params.maxEigVal(:)) + obj.pRho;
        end
        
        function x = updateX(obj, ~, ~, z, u, params)
            rhs = params.Atb + obj.pRho * (z - u);
            x = (params.AtA + obj.pRho * eye(size(params.AtA))) \ rhs;
        end
        
        function z = updateZ(obj, x, u, params)
            z = cs.utils.shrinkage(x + u, params.lambda / obj.pRho);
        end
        
        function [objVal, residual] = computeObjective(obj, sensorMatrix, observations, x, params)
            residual = norm(observations - sensorMatrix.multiply(x, false));
            l1Term = params.lambda * norm(x, 1);
            objVal = 0.5 * residual^2 + l1Term;
        end
        
        function x = postProcess(obj, x, params)
            x(abs(x) < params.zeroThreshold) = 0;
        end
        
        function name = getAlgorithmName(obj)
            name = 'LASSO via ADMM';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'S. Boyd et al., "Distributed Optimization and Statistical Learning via the Alternating Direction Method of Multipliers," Foundations and Trends in Machine Learning, 2011';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
