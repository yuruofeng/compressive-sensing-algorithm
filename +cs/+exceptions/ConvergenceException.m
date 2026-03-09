classdef ConvergenceException < cs.exceptions.CSException
    % ConvergenceException 收敛异常
    
    methods
        function obj = ConvergenceException(msg, varargin)
            obj@cs.exceptions.CSException(cs.exceptions.CSException.ERROR_CODES.NOT_CONVERGED, ...
                ['Convergence error: ' msg], varargin{:});
            obj = obj.addSuggestion('Try increasing MaxIterations or relaxing Tolerance');
        end
    end
    
    methods (Static)
        function throwNotConverged(algorithmName, iterations, tolerance)
            ex = cs.exceptions.ConvergenceException(...
                sprintf('%s did not converge after %d iterations', ...
                algorithmName, iterations));
            ex = ex.addContext('AlgorithmName', algorithmName);
            ex = ex.addContext('IterationsCompleted', iterations);
            ex = ex.addContext('Tolerance', tolerance);
            ex = ex.addSuggestion('Increase MaxIterations parameter');
            ex = ex.addSuggestion('Check if problem is well-conditioned');
            throw(ex);
        end
        
        function throwMaxIterationsReached(algorithmName, maxIter)
            ex = cs.exceptions.ConvergenceException(...
                sprintf('%s reached maximum iterations (%d)', algorithmName, maxIter));
            ex = ex.addContext('AlgorithmName', algorithmName);
            ex = ex.addContext('MaxIterations', maxIter);
            ex = ex.addSuggestion('Increase MaxIterations parameter');
            ex = ex.addSuggestion('Check problem scaling');
            throw(ex);
        end
        
        function throwNumericalIssue(algorithmName, details)
            ex = cs.exceptions.ConvergenceException(...
                sprintf('%s encountered numerical issue: %s', algorithmName, details));
            ex = ex.addContext('AlgorithmName', algorithmName);
            ex = ex.addContext('Details', details);
            ex = ex.addSuggestion('Check for NaN or Inf in inputs');
            ex = ex.addSuggestion('Try normalizing the data');
            throw(ex);
        end
    end
end
