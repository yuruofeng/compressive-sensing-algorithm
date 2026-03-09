classdef BasisPursuit < cs.core.Algorithm
    % BasisPursuit 使用ADMM求解基追踪问题
    % min ||x||_1 s.t. Ax = b (BP)
    % 或 min ||x||_1 s.t. ||Ax-b||_2 <= epsilon (BPDN)
    
    properties (Access = private)
        pHistory
        pTimer
        pMode
        pEpsilon
    end
    
    properties (Dependent)
        Mode
        Epsilon
    end
    
    methods
        function obj = BasisPursuit(varargin)
            obj@cs.core.Algorithm(varargin{:});
            obj.pHistory = cs.data.IterationHistory(obj.pOptions.MaxIterations);
            obj.pMode = 'BP';
            obj.pEpsilon = 0.01;
            
            if nargin > 0
                startIdx = 1;
                if isa(varargin{1}, 'cs.core.Options')
                    startIdx = 2;
                end
                
                for i = startIdx:2:length(varargin)
                    if ischar(varargin{i}) || isstring(varargin{i})
                        switch lower(varargin{i})
                            case 'mode'
                                obj.pMode = varargin{i+1};
                            case 'epsilon'
                                obj.pEpsilon = varargin{i+1};
                        end
                    end
                end
            end
        end
        
        function m = get.Mode(obj)
            m = obj.pMode;
        end
        
        function obj = set.Mode(obj, val)
            validModes = {'BP', 'BPDN'};
            if ~any(strcmpi(val, validModes))
                error('cs.exceptions.InvalidInputException', ...
                    'Mode must be one of: %s', strjoin(validModes, ', '));
            end
            obj.pMode = upper(val);
        end
        
        function e = get.Epsilon(obj)
            e = obj.pEpsilon;
        end
        
        function obj = set.Epsilon(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'nonnegative'});
            obj.pEpsilon = val;
        end
        
        function [result, info] = solve(obj, sensorMatrix, observations)
            startTime = tic;
            
            if ~isa(sensorMatrix, 'cs.data.SensorMatrix')
                sensorMatrix = cs.data.SensorMatrix(sensorMatrix);
            end
            
            obj.assertValidInputs(sensorMatrix.getMatrix(), observations);
            
            numMeasurements = sensorMatrix.M;
            signalLength = sensorMatrix.N;
            
            switch obj.pMode
                case 'BP'
                    [x, info] = obj.solveBP(sensorMatrix, observations, numMeasurements, signalLength);
                case 'BPDN'
                    [x, info] = obj.solveBPDN(sensorMatrix, observations, numMeasurements, signalLength);
            end
            
            obj.pHistory.trim();
            
            info.algorithm_name = ['Basis Pursuit (' obj.pMode ')'];
            info.elapsed_time = toc(startTime);
            
            result = cs.core.Result(x, info);
            
            obj.pIsFitted = true;
            obj.pIterCount = info.iterations;
            obj.pConverged = info.converged;
            obj.pElapsedTime = info.elapsed_time;
        end
    end
    
    methods (Access = protected)
        function [x, info] = solveBP(obj, sensorMatrix, observations, ~, signalLength)
            x = zeros(signalLength, 1);
            z = zeros(signalLength, 1);
            u = zeros(signalLength, 1);
            
            rho = 1.0;
            tau = 2.0;
            mu = 10.0;
            
            matrixA = sensorMatrix.getMatrix();
            AtA = matrixA' * matrixA;
            Atb = matrixA' * observations;
            
            converged = false;
            prevObjective = Inf;
            
            for iterIdx = 1:obj.pOptions.MaxIterations
                x = (AtA + rho * eye(signalLength)) \ (Atb + rho * (z - u));
                
                zPrev = z;
                z = cs.utils.shrinkage(x + u, 1/rho);
                
                u = u + x - z;
                
                primalResidual = norm(x - z);
                dualResidual = norm(rho * (z - zPrev));
                
                if primalResidual > mu * dualResidual
                    rho = tau * rho;
                    u = u / tau;
                elseif dualResidual > mu * primalResidual
                    rho = rho / tau;
                    u = u * tau;
                end
                
                currentObjective = norm(z, 1);
                residual = norm(observations - matrixA * z);
                supportSize = nnz(abs(z) > 1e-10);
                
                [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                    residual, supportSize);
                
                obj.pHistory.record('Objective', currentObjective, ...
                                   'Residual', residual, ...
                                   'SupportSize', supportSize);
                
                obj.notifyIteration(iterIdx, metrics, z);
                obj.logProgress(iterIdx, metrics);
                
                if converged && primalResidual < obj.pOptions.Tolerance
                    break;
                end
                
                prevObjective = currentObjective;
            end
            
            info = struct();
            info.iterations = iterIdx;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.support = find(abs(z) > 1e-10);
            info.history = obj.pHistory.toObject();
        end
        
        function [x, info] = solveBPDN(obj, sensorMatrix, observations, ~, signalLength)
            x = zeros(signalLength, 1);
            z = zeros(signalLength, 1);
            u = zeros(signalLength, 1);
            
            rho = 1.0;
            
            matrixA = sensorMatrix.getMatrix();
            AtA = matrixA' * matrixA;
            Atb = matrixA' * observations;
            
            converged = false;
            prevObjective = Inf;
            
            for iterIdx = 1:obj.pOptions.MaxIterations
                x = (AtA + rho * eye(signalLength)) \ (Atb + rho * (z - u));
                
                zPrev = z;
                
                residualVec = observations - matrixA * x;
                if norm(residualVec) <= obj.pEpsilon
                    z = cs.utils.shrinkage(x + u, 0);
                else
                    alpha = obj.pEpsilon / norm(residualVec);
                    z = cs.utils.shrinkage(x + u, 0) + alpha * residualVec' * matrixA;
                end
                
                u = u + x - z;
                
                currentObjective = norm(z, 1);
                residual = norm(observations - matrixA * z);
                supportSize = nnz(abs(z) > 1e-10);
                
                [converged, metrics] = obj.checkConvergence(iterIdx, currentObjective, prevObjective, ...
                    residual, supportSize);
                
                obj.pHistory.record('Objective', currentObjective, ...
                                   'Residual', residual, ...
                                   'SupportSize', supportSize);
                
                if converged
                    break;
                end
                
                prevObjective = currentObjective;
            end
            
            info = struct();
            info.iterations = iterIdx;
            info.converged = converged;
            info.residual_norm = metrics.residual;
            info.objective = metrics.objective;
            info.support = find(abs(z) > 1e-10);
            info.history = obj.pHistory.toObject();
        end
        
        function name = getAlgorithmName(obj)
            name = 'Basis Pursuit';
        end
        
        function version = getAlgorithmVersion(obj)
            version = '2.0.0';
        end
        
        function reference = getAlgorithmReference(obj)
            reference = 'S. S. Chen et al., "Atomic Decomposition by Basis Pursuit," SIAM Review, 2001';
        end
        
        function validatedOpts = validateOptions(obj, opts)
            validatedOpts = opts;
        end
    end
end
