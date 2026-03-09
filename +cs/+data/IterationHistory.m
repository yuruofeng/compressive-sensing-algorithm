classdef IterationHistory < handle
    % IterationHistory 迭代历史记录类
    % 跟踪和存储算法迭代过程中的各种指标
    
    properties
        ObjectiveValues
        ResidualNorms
        SupportSizes
        LambdaValues
        TimeStamps
        GradientNorms
    end
    
    properties (Access = private)
        pMaxIterations
        pCurrentIndex
        pCustomMetrics
        pCustomNames
    end
    
    properties (Dependent)
        CurrentIndex
        MaxIterations
        NumRecorded
    end
    
    methods
        function obj = IterationHistory(maxIter)
            if nargin < 1
                maxIter = 1000;
            end
            
            obj.pMaxIterations = maxIter;
            obj.pCurrentIndex = 0;
            obj.pCustomMetrics = {};
            obj.pCustomNames = {};
            
            obj.ObjectiveValues = zeros(maxIter, 1);
            obj.ResidualNorms = zeros(maxIter, 1);
            obj.SupportSizes = zeros(maxIter, 1);
            obj.TimeStamps = zeros(maxIter, 1);
            obj.LambdaValues = [];
            obj.GradientNorms = [];
        end
        
        function idx = get.CurrentIndex(obj)
            idx = obj.pCurrentIndex;
        end
        
        function mi = get.MaxIterations(obj)
            mi = obj.pMaxIterations;
        end
        
        function n = get.NumRecorded(obj)
            n = obj.pCurrentIndex;
        end
        
        function record(obj, varargin)
            p = inputParser;
            addParameter(p, 'Objective', NaN, @isnumeric);
            addParameter(p, 'Residual', NaN, @isnumeric);
            addParameter(p, 'SupportSize', NaN, @isnumeric);
            addParameter(p, 'Lambda', NaN, @isnumeric);
            addParameter(p, 'Gradient', NaN, @isnumeric);
            addParameter(p, 'Custom', [], @isstruct);
            parse(p, varargin{:});
            
            obj.pCurrentIndex = obj.pCurrentIndex + 1;
            iter = obj.pCurrentIndex;
            
            if ~isnan(p.Results.Objective)
                obj.ObjectiveValues(iter) = p.Results.Objective;
            end
            
            if ~isnan(p.Results.Residual)
                obj.ResidualNorms(iter) = p.Results.Residual;
            end
            
            if ~isnan(p.Results.SupportSize)
                obj.SupportSizes(iter) = p.Results.SupportSize;
            end
            
            if ~isnan(p.Results.Lambda)
                if isempty(obj.LambdaValues)
                    obj.LambdaValues = zeros(obj.pMaxIterations, 1);
                end
                obj.LambdaValues(iter) = p.Results.Lambda;
            end
            
            if ~isnan(p.Results.Gradient)
                if isempty(obj.GradientNorms)
                    obj.GradientNorms = zeros(obj.pMaxIterations, 1);
                end
                obj.GradientNorms(iter) = p.Results.Gradient;
            end
            
            obj.TimeStamps(iter) = tic;
            
            if ~isempty(p.Results.Custom)
                obj.pCustomMetrics{iter} = p.Results.Custom;
            end
        end
        
        function trim(obj)
            if obj.pCurrentIndex == 0
                return;
            end
            
            idx = obj.pCurrentIndex;
            
            obj.ObjectiveValues = obj.ObjectiveValues(1:idx);
            obj.ResidualNorms = obj.ResidualNorms(1:idx);
            obj.SupportSizes = obj.SupportSizes(1:idx);
            obj.TimeStamps = obj.TimeStamps(1:idx);
            
            if ~isempty(obj.LambdaValues)
                obj.LambdaValues = obj.LambdaValues(1:idx);
            end
            
            if ~isempty(obj.GradientNorms)
                obj.GradientNorms = obj.GradientNorms(1:idx);
            end
            
            if ~isempty(obj.pCustomMetrics)
                obj.pCustomMetrics = obj.pCustomMetrics(1:idx);
                obj.pCustomMetrics = obj.pCustomMetrics(~cellfun(@isempty, obj.pCustomMetrics));
            end
            
            obj.pMaxIterations = idx;
        end
        
        function reset(obj)
            obj.pCurrentIndex = 0;
            obj.ObjectiveValues = zeros(obj.pMaxIterations, 1);
            obj.ResidualNorms = zeros(obj.pMaxIterations, 1);
            obj.SupportSizes = zeros(obj.pMaxIterations, 1);
            obj.TimeStamps = zeros(obj.pMaxIterations, 1);
            obj.LambdaValues = [];
            obj.GradientNorms = [];
            obj.pCustomMetrics = {};
        end
        
        function obj = resize(obj, newMaxIter)
            oldData = obj.toObject();
            
            obj.pMaxIterations = newMaxIter;
            obj.ObjectiveValues = zeros(newMaxIter, 1);
            obj.ResidualNorms = zeros(newMaxIter, 1);
            obj.SupportSizes = zeros(newMaxIter, 1);
            obj.TimeStamps = zeros(newMaxIter, 1);
            
            copyLen = min(obj.pCurrentIndex, newMaxIter);
            if copyLen > 0
                obj.ObjectiveValues(1:copyLen) = oldData.ObjectiveValues(1:copyLen);
                obj.ResidualNorms(1:copyLen) = oldData.ResidualNorms(1:copyLen);
                obj.SupportSizes(1:copyLen) = oldData.SupportSizes(1:copyLen);
                obj.TimeStamps(1:copyLen) = oldData.TimeStamps(1:copyLen);
                
                if ~isempty(oldData.LambdaValues)
                    obj.LambdaValues = zeros(newMaxIter, 1);
                    obj.LambdaValues(1:copyLen) = oldData.LambdaValues(1:copyLen);
                end
                
                if ~isempty(oldData.GradientNorms)
                    obj.GradientNorms = zeros(newMaxIter, 1);
                    obj.GradientNorms(1:copyLen) = oldData.GradientNorms(1:copyLen);
                end
            end
            
            obj.pCurrentIndex = copyLen;
        end
        
        function s = toObject(obj)
            s.ObjectiveValues = obj.ObjectiveValues(1:obj.pCurrentIndex);
            s.ResidualNorms = obj.ResidualNorms(1:obj.pCurrentIndex);
            s.SupportSizes = obj.SupportSizes(1:obj.pCurrentIndex);
            s.TimeStamps = obj.TimeStamps(1:obj.pCurrentIndex);
            
            if ~isempty(obj.LambdaValues)
                s.LambdaValues = obj.LambdaValues(1:obj.pCurrentIndex);
            end
            
            if ~isempty(obj.GradientNorms)
                s.GradientNorms = obj.GradientNorms(1:obj.pCurrentIndex);
            end
            
            s.NumRecorded = obj.pCurrentIndex;
        end
        
        function plot(obj, varargin)
            p = inputParser;
            addParameter(p, 'Metrics', 'all', @ischar);
            addParameter(p, 'Scale', 'log', @ischar);
            addParameter(p, 'Figure', [], @isnumeric);
            parse(p, varargin{:});
            
            if ~isempty(p.Results.Figure)
                figure(p.Results.Figure);
            else
                figure('Name', 'Iteration History', 'NumberTitle', 'off');
            end
            
            metrics = p.Results.Metrics;
            if strcmp(metrics, 'all')
                metrics = 'objective,residual,support';
            end
            
            metricList = strsplit(metrics, ',');
            numPlots = length(metricList);
            
            for i = 1:numPlots
                subplot(numPlots, 1, i);
                
                switch strtrim(metricList{i})
                    case 'objective'
                        data = obj.ObjectiveValues(1:obj.pCurrentIndex);
                        if strcmp(p.Results.Scale, 'log')
                            semilogy(data, 'b-', 'LineWidth', 1.5);
                        else
                            plot(data, 'b-', 'LineWidth', 1.5);
                        end
                        title('Objective Function');
                        ylabel('f(x)');
                        
                    case 'residual'
                        data = obj.ResidualNorms(1:obj.pCurrentIndex);
                        if strcmp(p.Results.Scale, 'log')
                            semilogy(data, 'r-', 'LineWidth', 1.5);
                        else
                            plot(data, 'r-', 'LineWidth', 1.5);
                        end
                        title('Residual Norm');
                        ylabel('||r||_2');
                        
                    case 'support'
                        data = obj.SupportSizes(1:obj.pCurrentIndex);
                        plot(data, 'g-', 'LineWidth', 1.5);
                        title('Support Size');
                        ylabel('|supp(x)|');
                        
                    case 'lambda'
                        if isempty(obj.LambdaValues)
                            continue;
                        end
                        data = obj.LambdaValues(1:obj.pCurrentIndex);
                        if strcmp(p.Results.Scale, 'log')
                            semilogy(data, 'm-', 'LineWidth', 1.5);
                        else
                            plot(data, 'm-', 'LineWidth', 1.5);
                        end
                        title('Lambda Value');
                        ylabel('\lambda');
                        
                    case 'gradient'
                        if isempty(obj.GradientNorms)
                            continue;
                        end
                        data = obj.GradientNorms(1:obj.pCurrentIndex);
                        if strcmp(p.Results.Scale, 'log')
                            semilogy(data, 'c-', 'LineWidth', 1.5);
                        else
                            plot(data, 'c-', 'LineWidth', 1.5);
                        end
                        title('Gradient Norm');
                        ylabel('||\nabla||');
                end
                
                grid on;
                xlabel('Iteration');
            end
        end
        
        function display(obj)
            fprintf('  cs.data.IterationHistory:\n');
            fprintf('    Recorded Iterations: %d\n', obj.pCurrentIndex);
            fprintf('    Max Capacity:        %d\n', obj.pMaxIterations);
            
            if obj.pCurrentIndex > 0
                fprintf('    Final Objective:     %.6e\n', ...
                    obj.ObjectiveValues(obj.pCurrentIndex));
                fprintf('    Final Residual:      %.6e\n', ...
                    obj.ResidualNorms(obj.pCurrentIndex));
                fprintf('    Final Support Size:  %d\n', ...
                    obj.SupportSizes(obj.pCurrentIndex));
            end
        end
        
        function summary = getSummary(obj)
            summary = struct();
            
            if obj.pCurrentIndex == 0
                summary.IsEmpty = true;
                return;
            end
            
            summary.IsEmpty = false;
            summary.NumIterations = obj.pCurrentIndex;
            
            objVals = obj.ObjectiveValues(1:obj.pCurrentIndex);
            summary.Objective = struct(...
                'Initial', objVals(1), ...
                'Final', objVals(end), ...
                'Min', min(objVals), ...
                'Reduction', objVals(1) - objVals(end));
            
            resNorms = obj.ResidualNorms(1:obj.pCurrentIndex);
            summary.Residual = struct(...
                'Initial', resNorms(1), ...
                'Final', resNorms(end), ...
                'Min', min(resNorms));
            
            suppSizes = obj.SupportSizes(1:obj.pCurrentIndex);
            summary.Support = struct(...
                'Initial', suppSizes(1), ...
                'Final', suppSizes(end), ...
                'Max', max(suppSizes), ...
                'Min', min(suppSizes));
            
            if ~isempty(obj.LambdaValues)
                lambdaVals = obj.LambdaValues(1:obj.pCurrentIndex);
                summary.Lambda = struct(...
                    'Initial', lambdaVals(1), ...
                    'Final', lambdaVals(end));
            end
        end
    end
end
