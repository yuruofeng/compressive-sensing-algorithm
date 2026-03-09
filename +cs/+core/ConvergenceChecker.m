classdef ConvergenceChecker < handle
    % ConvergenceChecker 收敛性检查器
    % 提供多种收敛准则的统一检查机制
    
    properties
        Tolerance = 1e-8
        MaxIterations = 1000
        MinIterations = 5
        Patience = 10
    end
    
    properties (Access = private)
        pHistory
        pNoImprovementCount
        pBestObjective
        pConverged
        pStopReason
    end
    
    properties (Dependent, SetAccess = protected)
        Converged
        StopReason
        History
    end
    
    properties (Constant)
        STOP_REASONS = struct(...
            'TOLERANCE_MET', 'Relative tolerance met', ...
            'MAX_ITERATIONS', 'Maximum iterations reached', ...
            'NO_IMPROVEMENT', 'No improvement for specified patience', ...
            'USER_STOP', 'User requested stop', ...
            'NUMERICAL_ISSUE', 'Numerical issue detected', ...
            'CONTINUE', 'Not converged yet')
    end
    
    methods
        function obj = ConvergenceChecker(varargin)
            obj.pHistory = struct(...
                'ObjectiveValues', [], ...
                'ResidualNorms', [], ...
                'GradientNorms', [], ...
                'SupportSizes', [], ...
                'CustomMetrics', {});
            obj.pNoImprovementCount = 0;
            obj.pBestObjective = Inf;
            obj.pConverged = false;
            obj.pStopReason = obj.STOP_REASONS.CONTINUE;
            
            if nargin > 0
                obj = obj.parseOptions(varargin{:});
            end
        end
        
        function obj = parseOptions(obj, varargin)
            for i = 1:2:length(varargin)
                name = varargin{i};
                value = varargin{i+1};
                
                switch lower(name)
                    case {'tolerance', 'tol'}
                        obj.Tolerance = value;
                    case {'maxiterations', 'maxiter'}
                        obj.MaxIterations = value;
                    case {'miniterations', 'miniter'}
                        obj.MinIterations = value;
                    case {'patience'}
                        obj.Patience = value;
                end
            end
        end
        
        function set.Tolerance(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'positive'});
            obj.Tolerance = val;
        end
        
        function set.MaxIterations(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'integer', 'positive'});
            obj.MaxIterations = double(val);
        end
        
        function set.MinIterations(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'integer', 'nonnegative'});
            obj.MinIterations = double(val);
        end
        
        function set.Patience(obj, val)
            validateattributes(val, {'numeric'}, {'scalar', 'integer', 'positive'});
            obj.Patience = double(val);
        end
        
        function conv = get.Converged(obj)
            conv = obj.pConverged;
        end
        
        function reason = get.StopReason(obj)
            reason = obj.pStopReason;
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function reset(obj)
            obj.pHistory = struct(...
                'ObjectiveValues', [], ...
                'ResidualNorms', [], ...
                'GradientNorms', [], ...
                'SupportSizes', [], ...
                'CustomMetrics', {});
            obj.pNoImprovementCount = 0;
            obj.pBestObjective = Inf;
            obj.pConverged = false;
            obj.pStopReason = obj.STOP_REASONS.CONTINUE;
        end
        
        function record(obj, iter, varargin)
            p = inputParser;
            addParameter(p, 'Objective', NaN, @isnumeric);
            addParameter(p, 'Residual', NaN, @isnumeric);
            addParameter(p, 'Gradient', NaN, @isnumeric);
            addParameter(p, 'SupportSize', NaN, @isnumeric);
            addParameter(p, 'Custom', [], @isstruct);
            parse(p, varargin{:});
            
            if ~isnan(p.Results.Objective)
                obj.pHistory.ObjectiveValues(end+1) = p.Results.Objective;
            end
            
            if ~isnan(p.Results.Residual)
                obj.pHistory.ResidualNorms(end+1) = p.Results.Residual;
            end
            
            if ~isnan(p.Results.Gradient)
                obj.pHistory.GradientNorms(end+1) = p.Results.Gradient;
            end
            
            if ~isnan(p.Results.SupportSize)
                obj.pHistory.SupportSizes(end+1) = p.Results.SupportSize;
            end
            
            if ~isempty(p.Results.Custom)
                obj.pHistory.CustomMetrics{end+1} = p.Results.Custom;
            end
        end
        
        function [converged, stopReason] = check(obj, iter, currentObj, prevObj)
            if iter >= obj.MaxIterations
                obj.pConverged = true;
                obj.pStopReason = obj.STOP_REASONS.MAX_ITERATIONS;
                converged = true;
                stopReason = obj.pStopReason;
                return;
            end
            
            if isnan(currentObj) || isinf(currentObj)
                obj.pConverged = true;
                obj.pStopReason = obj.STOP_REASONS.NUMERICAL_ISSUE;
                converged = true;
                stopReason = obj.pStopReason;
                return;
            end
            
            if currentObj < obj.pBestObjective
                obj.pBestObjective = currentObj;
                obj.pNoImprovementCount = 0;
            else
                obj.pNoImprovementCount = obj.pNoImprovementCount + 1;
            end
            
            if obj.pNoImprovementCount >= obj.Patience && iter > obj.MinIterations
                obj.pConverged = true;
                obj.pStopReason = obj.STOP_REASONS.NO_IMPROVEMENT;
                converged = true;
                stopReason = obj.pStopReason;
                return;
            end
            
            if iter > obj.MinIterations
                if prevObj ~= 0
                    relChange = abs(currentObj - prevObj) / abs(prevObj);
                else
                    relChange = abs(currentObj - prevObj);
                end
                
                if relChange < obj.Tolerance
                    obj.pConverged = true;
                    obj.pStopReason = obj.STOP_REASONS.TOLERANCE_MET;
                    converged = true;
                    stopReason = obj.pStopReason;
                    return;
                end
            end
            
            converged = false;
            stopReason = obj.STOP_REASONS.CONTINUE;
        end
        
        function [converged, stopReason] = checkMulti(obj, iter, criteria)
            if iter >= obj.MaxIterations
                obj.pConverged = true;
                obj.pStopReason = obj.STOP_REASONS.MAX_ITERATIONS;
                converged = true;
                stopReason = obj.pStopReason;
                return;
            end
            
            allConverged = true;
            reasons = {};
            
            if isfield(criteria, 'objective') && ~isempty(obj.pHistory.ObjectiveValues)
                if length(obj.pHistory.ObjectiveValues) >= 2
                    prev = obj.pHistory.ObjectiveValues(end-1);
                    curr = obj.pHistory.ObjectiveValues(end);
                    if prev ~= 0
                        relChange = abs(curr - prev) / abs(prev);
                    else
                        relChange = abs(curr - prev);
                    end
                    if relChange >= criteria.objective
                        allConverged = false;
                    else
                        reasons{end+1} = 'objective';
                    end
                else
                    allConverged = false;
                end
            end
            
            if isfield(criteria, 'residual') && ~isempty(obj.pHistory.ResidualNorms)
                lastResidual = obj.pHistory.ResidualNorms(end);
                if lastResidual >= criteria.residual
                    allConverged = false;
                else
                    reasons{end+1} = 'residual';
                end
            end
            
            if isfield(criteria, 'gradient') && ~isempty(obj.pHistory.GradientNorms)
                lastGradient = obj.pHistory.GradientNorms(end);
                if lastGradient >= criteria.gradient
                    allConverged = false;
                else
                    reasons{end+1} = 'gradient';
                end
            end
            
            if allConverged && iter > obj.MinIterations
                obj.pConverged = true;
                obj.pStopReason = [obj.STOP_REASONS.TOLERANCE_MET ': ' strjoin(reasons, ', ')];
                converged = true;
                stopReason = obj.pStopReason;
            else
                converged = false;
                stopReason = obj.STOP_REASONS.CONTINUE;
            end
        end
        
        function userStop(obj)
            obj.pConverged = true;
            obj.pStopReason = obj.STOP_REASONS.USER_STOP;
        end
        
        function plot(obj)
            fig = figure('Name', 'Convergence History', 'NumberTitle', 'off');
            
            plots = 0;
            if ~isempty(obj.pHistory.ObjectiveValues)
                plots = plots + 1;
            end
            if ~isempty(obj.pHistory.ResidualNorms)
                plots = plots + 1;
            end
            if ~isempty(obj.pHistory.SupportSizes)
                plots = plots + 1;
            end
            if ~isempty(obj.pHistory.GradientNorms)
                plots = plots + 1;
            end
            
            if plots == 0
                text(0.5, 0.5, 'No convergence history available', ...
                    'HorizontalAlignment', 'center');
                return;
            end
            
            idx = 1;
            
            if ~isempty(obj.pHistory.ObjectiveValues)
                subplot(plots, 1, idx);
                semilogy(obj.pHistory.ObjectiveValues, 'b-', 'LineWidth', 1.5);
                title('Objective Function');
                ylabel('f(x)');
                grid on;
                idx = idx + 1;
            end
            
            if ~isempty(obj.pHistory.ResidualNorms)
                subplot(plots, 1, idx);
                semilogy(obj.pHistory.ResidualNorms, 'r-', 'LineWidth', 1.5);
                title('Residual Norm');
                ylabel('||r||_2');
                grid on;
                idx = idx + 1;
            end
            
            if ~isempty(obj.pHistory.SupportSizes)
                subplot(plots, 1, idx);
                plot(obj.pHistory.SupportSizes, 'g-', 'LineWidth', 1.5);
                title('Support Size');
                ylabel('|supp(x)|');
                grid on;
                idx = idx + 1;
            end
            
            if ~isempty(obj.pHistory.GradientNorms)
                subplot(plots, 1, idx);
                semilogy(obj.pHistory.GradientNorms, 'm-', 'LineWidth', 1.5);
                title('Gradient Norm');
                ylabel('||\nabla f||_2');
                grid on;
            end
            
            xlabel('Iteration');
            
            sgtitle(sprintf('Stop Reason: %s', obj.pStopReason));
        end
    end
end
