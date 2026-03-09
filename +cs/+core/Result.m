classdef Result < matlab.mixin.CustomDisplay
    % Result 统一结果封装类
    % 提供重构结果、性能指标和可视化功能
    
    properties
        X              
        Support        
        Iterations     
        Converged      
        ResidualNorm   
        ObjectiveValue 
        ElapsedTime    
        AlgorithmName  
    end
    
    properties (Access = private)
        pHistory       
        pReconstructionInfo
    end
    
    properties (Dependent)
        Sparsity
        SignalLength
        SupportSize
        History
        ReconstructionInfo
    end
    
    methods
        function obj = Result(x, info)
            obj.X = x;
            obj.Support = [];
            obj.Iterations = 0;
            obj.Converged = false;
            obj.ResidualNorm = NaN;
            obj.ObjectiveValue = NaN;
            obj.ElapsedTime = 0;
            obj.AlgorithmName = '';
            obj.pHistory = [];
            obj.pReconstructionInfo = struct();
            
            if nargin > 1 && ~isempty(info)
                obj = obj.parseInfo(info);
            end
            
            if isempty(obj.Support) && ~isempty(obj.X)
                obj.Support = find(abs(obj.X) > eps);
            end
        end
        
        function obj = parseInfo(obj, info)
            if isfield(info, 'support') || isprop(info, 'support')
                try
                    obj.Support = info.support;
                catch
                end
            end
            
            if isfield(info, 'iterations') || isprop(info, 'iterations')
                try
                    obj.Iterations = info.iterations;
                catch
                end
            end
            
            if isfield(info, 'converged') || isprop(info, 'converged')
                try
                    obj.Converged = info.converged;
                catch
                end
            end
            
            if isfield(info, 'residual_norm') || isprop(info, 'residual_norm')
                try
                    obj.ResidualNorm = info.residual_norm;
                catch
                end
            end
            
            if isfield(info, 'objective') || isprop(info, 'objective')
                try
                    obj.ObjectiveValue = info.objective;
                catch
                end
            end
            
            if isfield(info, 'elapsed_time') || isprop(info, 'elapsed_time')
                try
                    obj.ElapsedTime = info.elapsed_time;
                catch
                end
            end
            
            if isfield(info, 'algorithm_name') || isprop(info, 'algorithm_name')
                try
                    obj.AlgorithmName = info.algorithm_name;
                catch
                end
            end
            
            if isfield(info, 'history') || isprop(info, 'history')
                try
                    obj.pHistory = info.history;
                catch
                end
            end
            
            if isfield(info, 'reconstruction_info')
                try
                    obj.pReconstructionInfo = info.reconstruction_info;
                catch
                end
            end
        end
        
        function sp = get.Sparsity(obj)
            sp = nnz(obj.X) / length(obj.X);
        end
        
        function len = get.SignalLength(obj)
            len = length(obj.X);
        end
        
        function sz = get.SupportSize(obj)
            sz = length(obj.Support);
        end
        
        function h = get.History(obj)
            h = obj.pHistory;
        end
        
        function ri = get.ReconstructionInfo(obj)
            ri = obj.pReconstructionInfo;
        end
        
        function metrics = evaluate(obj, xTrue)
            if isempty(obj.X) || isempty(xTrue)
                error('Result:EmptyData', 'Cannot evaluate with empty data');
            end
            
            if length(obj.X) ~= length(xTrue)
                error('Result:DimensionMismatch', ...
                    'Length mismatch: result=%d, ground truth=%d', ...
                    length(obj.X), length(xTrue));
            end
            
            metrics.MSE = mean((obj.X - xTrue).^2);
            metrics.RMSE = sqrt(metrics.MSE);
            metrics.NMSE = norm(obj.X - xTrue)^2 / norm(xTrue)^2;
            metrics.SNR = 10 * log10(norm(xTrue)^2 / norm(obj.X - xTrue)^2);
            
            trueSupport = find(abs(xTrue) > eps);
            if ~isempty(obj.Support) && ~isempty(trueSupport)
                metrics.SupportRecovery = length(intersect(obj.Support, trueSupport)) ...
                    / length(trueSupport);
                metrics.FalsePositive = length(setdiff(obj.Support, trueSupport));
                metrics.FalseNegative = length(setdiff(trueSupport, obj.Support));
            else
                metrics.SupportRecovery = NaN;
                metrics.FalsePositive = NaN;
                metrics.FalseNegative = NaN;
            end
            
            metrics.SparsityTrue = nnz(xTrue) / length(xTrue);
            metrics.SparsityEstimated = obj.Sparsity;
        end
        
        function plotSignal(obj, varargin)
            p = inputParser;
            addParameter(p, 'TrueSignal', [], @isnumeric);
            addParameter(p, 'Title', 'Reconstructed Signal', @ischar);
            addParameter(p, 'ShowSupport', true, @islogical);
            parse(p, varargin{:});
            
            figure('Name', 'Reconstruction Result', 'NumberTitle', 'off');
            
            if ~isempty(p.Results.TrueSignal)
                subplot(2,1,1);
                stem(p.Results.TrueSignal, 'b', 'MarkerSize', 4, 'LineWidth', 0.5);
                title('Ground Truth Signal');
                xlabel('Index');
                ylabel('Amplitude');
                grid on;
                
                subplot(2,1,2);
            end
            
            stem(obj.X, 'r', 'MarkerSize', 4, 'LineWidth', 0.5);
            hold on;
            
            if p.Results.ShowSupport && ~isempty(obj.Support)
                stem(obj.Support, obj.X(obj.Support), 'go', ...
                    'MarkerSize', 8, 'LineWidth', 1.5);
            end
            
            title(p.Results.Title);
            xlabel('Index');
            ylabel('Amplitude');
            grid on;
            legend('Reconstructed', 'Support', 'Location', 'best');
        end
        
        function plotConvergence(obj)
            if isempty(obj.pHistory)
                warning('Result:NoHistory', 'No iteration history available');
                return;
            end
            
            figure('Name', 'Convergence Analysis', 'NumberTitle', 'off');
            
            if isfield(obj.pHistory, 'ObjectiveValues') || ...
               isprop(obj.pHistory, 'ObjectiveValues')
                try
                    objVals = obj.pHistory.ObjectiveValues;
                    objVals = objVals(objVals ~= 0);
                    
                    subplot(2,2,1);
                    semilogy(1:length(objVals), objVals, 'b-', 'LineWidth', 1.5);
                    title('Objective Function');
                    xlabel('Iteration');
                    ylabel('Objective Value');
                    grid on;
                catch
                end
            end
            
            if isfield(obj.pHistory, 'ResidualNorms') || ...
               isprop(obj.pHistory, 'ResidualNorms')
                try
                    resNorms = obj.pHistory.ResidualNorms;
                    resNorms = resNorms(resNorms ~= 0);
                    
                    subplot(2,2,2);
                    semilogy(1:length(resNorms), resNorms, 'r-', 'LineWidth', 1.5);
                    title('Residual Norm');
                    xlabel('Iteration');
                    ylabel('||Ax - b||_2');
                    grid on;
                catch
                end
            end
            
            if isfield(obj.pHistory, 'SupportSizes') || ...
               isprop(obj.pHistory, 'SupportSizes')
                try
                    suppSizes = obj.pHistory.SupportSizes;
                    suppSizes = suppSizes(suppSizes ~= 0);
                    
                    subplot(2,2,3);
                    plot(1:length(suppSizes), suppSizes, 'g-', 'LineWidth', 1.5);
                    title('Support Size');
                    xlabel('Iteration');
                    ylabel('|supp(x)|');
                    grid on;
                catch
                end
            end
            
            subplot(2,2,4);
            axis off;
            infoText = sprintf([...
                'Algorithm: %s\n', ...
                'Iterations: %d\n', ...
                'Converged: %s\n', ...
                'Time: %.3f s\n', ...
                'Support Size: %d\n', ...
                'Sparsity: %.2f%%'], ...
                obj.AlgorithmName, obj.Iterations, mat2str(obj.Converged), ...
                obj.ElapsedTime, obj.SupportSize, obj.Sparsity*100);
            text(0.1, 0.9, infoText, 'VerticalAlignment', 'top', ...
                'FontName', 'monospaced', 'FontSize', 10);
        end
        
        function s = toStruct(obj)
            s.X = obj.X;
            s.Support = obj.Support;
            s.Iterations = obj.Iterations;
            s.Converged = obj.Converged;
            s.ResidualNorm = obj.ResidualNorm;
            s.ObjectiveValue = obj.ObjectiveValue;
            s.ElapsedTime = obj.ElapsedTime;
            s.AlgorithmName = obj.AlgorithmName;
            s.Sparsity = obj.Sparsity;
            s.SupportSize = obj.SupportSize;
        end
        
        function save(obj, filename)
            s = obj.toStruct();
            save(filename, '-struct', 's');
        end
    end
    
    methods (Static)
        function obj = load(filename)
            data = load(filename);
            obj = cs.core.Result(data.X, data);
        end
    end
end
