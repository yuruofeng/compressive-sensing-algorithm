classdef ResultPresenter < handle
    % ResultPresenter 结果展示器
    % 
    % 提供统一的算法结果展示机制，支持：
    %   - 控制台输出（表格、摘要）
    %   - 可视化（信号重构、性能对比）
    %   - 结果导出（报告生成）
    %
    % 使用示例：
    %   presenter = ResultPresenter();
    %   presenter.addResult('OMP', resultOMP, metricsOMP, timeOMP);
    %   presenter.displayTable();
    %   presenter.visualize(x_true);
    %
    % 作者: 压缩感知算法库
    % 版本: 1.0
    
    properties (Access = private)
        pResults
        pAlgorithmNames
        pFigures
    end
    
    properties (Constant)
        COLORS = struct(...
            'OMP', 'r', ...
            'IHT', 'g', ...
            'FISTA', 'm', ...
            'AMP', 'c', ...
            'BSBL', 'b', ...
            'BCS', [0.8500, 0.3250, 0.0980], ...
            'default', 'k');
    end
    
    methods
        function obj = ResultPresenter()
            obj.pResults = struct();
            obj.pAlgorithmNames = {};
            obj.pFigures = struct();
        end
        
        function addResult(obj, name, result, metrics, time)
            % 添加算法结果
            obj.pResults.(name) = struct(...
                'Name', name, ...
                'Result', result, ...
                'Metrics', metrics, ...
                'Time', time, ...
                'X', result.X);
            
            if ~ismember(name, obj.pAlgorithmNames)
                obj.pAlgorithmNames{end+1} = name;
            end
        end
        
        function displayTable(obj)
            % 显示性能对比表格
            if isempty(obj.pAlgorithmNames)
                fprintf('暂无结果数据\n');
                return;
            end
            
            fprintf('\n========================================\n');
            fprintf('  算法性能对比汇总\n');
            fprintf('========================================\n');
            fprintf('%-12s %10s %12s %12s %10s\n', ...
                '算法', 'SNR (dB)', 'NMSE', '支撑集大小', '时间 (s)');
            fprintf('%-12s %10s %12s %12s %10s\n', ...
                '------', '------', '------', '------', '------');
            
            for i = 1:length(obj.pAlgorithmNames)
                name = obj.pAlgorithmNames{i};
                data = obj.pResults.(name);
                
                if isfield(data.Metrics, 'SupportSize')
                    supportSize = data.Metrics.SupportSize;
                else
                    supportSize = nnz(abs(data.X) > 1e-10);
                end
                
                fprintf('%-12s %10.2f %12.6f %12d %10.4f\n', ...
                    name, data.Metrics.SNR, data.Metrics.NMSE, ...
                    supportSize, data.Time);
            end
            
            fprintf('========================================\n\n');
        end
        
        function visualize(obj, x_true, varargin)
            % 可视化结果
            % 参数：
            %   x_true - 原始信号
            %   varargin - 可选：'mode' ('reconstruction' | 'comparison' | 'all')
            
            p = inputParser;
            addParameter(p, 'mode', 'all', @ischar);
            parse(p, varargin{:});
            
            mode = p.Results.mode;
            
            switch lower(mode)
                case 'reconstruction'
                    obj.plotReconstruction(x_true);
                case 'comparison'
                    obj.plotComparison();
                case 'all'
                    obj.plotAll(x_true);
                otherwise
                    error('ResultPresenter:InvalidMode', ...
                        '未知的可视化模式: %s', mode);
            end
        end
        
        function generateReport(obj, filename)
            % 生成结果报告
            if nargin < 2
                filename = sprintf('demo_report_%s.txt', datestr(now, 'yyyymmdd_HHMMSS'));
            end
            
            fid = fopen(filename, 'w');
            if fid == -1
                error('ResultPresenter:FileError', '无法创建文件: %s', filename);
            end
            
            fprintf(fid, '========================================\n');
            fprintf(fid, '  压缩感知算法性能报告\n');
            fprintf(fid, '  生成时间: %s\n', datestr(now));
            fprintf(fid, '========================================\n\n');
            
            fprintf(fid, '算法列表:\n');
            for i = 1:length(obj.pAlgorithmNames)
                name = obj.pAlgorithmNames{i};
                data = obj.pResults.(name);
                fprintf(fid, '  %d. %s\n', i, name);
                fprintf(fid, '     SNR: %.2f dB\n', data.Metrics.SNR);
                fprintf(fid, '     NMSE: %.6f\n', data.Metrics.NMSE);
                fprintf(fid, '     时间: %.4f 秒\n\n', data.Time);
            end
            
            fprintf(fid, '最佳性能:\n');
            [bestSNR, bestIdx] = max(obj.getSNRValues());
            bestName = obj.pAlgorithmNames{bestIdx};
            fprintf(fid, '  最高SNR: %s (%.2f dB)\n', bestName, bestSNR);
            
            [bestTime, bestIdx] = min(obj.getTimeValues());
            bestName = obj.pAlgorithmNames{bestIdx};
            fprintf(fid, '  最快速度: %s (%.4f 秒)\n', bestName, bestTime);
            
            fclose(fid);
            fprintf('报告已保存至: %s\n', filename);
        end
    end
    
    methods (Access = private)
        function plotAll(obj, x_true)
            % 绘制完整可视化
            numAlgorithms = length(obj.pAlgorithmNames);
            
            obj.pFigures.main = figure('Name', '算法性能对比', ...
                'Position', [100, 100, 1400, 900]);
            
            % 第一行：原始信号 + 重构结果
            subplot(3, 4, 1);
            stem(x_true, 'b', 'LineWidth', 1, 'MarkerSize', 4);
            title('原始稀疏信号');
            xlabel('索引');
            ylabel('幅值');
            xlim([0, length(x_true)]);
            grid on;
            
            for i = 1:min(numAlgorithms, 3)
                name = obj.pAlgorithmNames{i};
                data = obj.pResults.(name);
                
                subplot(3, 4, i+1);
                color = obj.getColor(name);
                stem(data.X, color, 'LineWidth', 1, 'MarkerSize', 4);
                title(sprintf('%s重构 (SNR=%.1f dB)', name, data.Metrics.SNR));
                xlabel('索引');
                ylabel('幅值');
                xlim([0, length(x_true)]);
                grid on;
            end
            
            % 第二行：更多重构结果
            for i = 4:min(numAlgorithms, 6)
                name = obj.pAlgorithmNames{i};
                data = obj.pResults.(name);
                
                subplot(3, 4, i+1);
                color = obj.getColor(name);
                stem(data.X, color, 'LineWidth', 1, 'MarkerSize', 4);
                title(sprintf('%s重构 (SNR=%.1f dB)', name, data.Metrics.SNR));
                xlabel('索引');
                ylabel('幅值');
                xlim([0, length(x_true)]);
                grid on;
            end
            
            % SNR对比柱状图
            subplot(3, 4, 8);
            snrValues = obj.getSNRValues();
            bar(snrValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('SNR性能对比');
            ylabel('SNR (dB)');
            grid on;
            
            % 时间对比柱状图
            subplot(3, 4, 9);
            timeValues = obj.getTimeValues();
            bar(timeValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('运行时间对比');
            ylabel('时间 (秒)');
            grid on;
            
            % NMSE对比
            subplot(3, 4, 10);
            nmseValues = obj.getNMSEValues();
            bar(nmseValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('NMSE对比');
            ylabel('NMSE');
            grid on;
            
            sgtitle('压缩感知算法性能综合对比', 'FontSize', 14, 'FontWeight', 'bold');
        end
        
        function plotReconstruction(obj, x_true)
            % 仅绘制重构结果
            numAlgorithms = length(obj.pAlgorithmNames);
            
            obj.pFigures.reconstruction = figure('Name', '重构结果', ...
                'Position', [100, 100, 1200, 600]);
            
            subplot(2, ceil((numAlgorithms+1)/2), 1);
            stem(x_true, 'b', 'LineWidth', 1, 'MarkerSize', 4);
            title('原始稀疏信号');
            xlabel('索引');
            ylabel('幅值');
            grid on;
            
            for i = 1:numAlgorithms
                name = obj.pAlgorithmNames{i};
                data = obj.pResults.(name);
                
                subplot(2, ceil((numAlgorithms+1)/2), i+1);
                color = obj.getColor(name);
                stem(data.X, color, 'LineWidth', 1, 'MarkerSize', 4);
                title(sprintf('%s (SNR=%.1f dB)', name, data.Metrics.SNR));
                xlabel('索引');
                ylabel('幅值');
                grid on;
            end
        end
        
        function plotComparison(obj)
            % 仅绘制性能对比图
            obj.pFigures.comparison = figure('Name', '性能对比', ...
                'Position', [100, 100, 1000, 400]);
            
            subplot(1, 3, 1);
            snrValues = obj.getSNRValues();
            bar(snrValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('SNR对比');
            ylabel('SNR (dB)');
            grid on;
            
            subplot(1, 3, 2);
            timeValues = obj.getTimeValues();
            bar(timeValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('运行时间对比');
            ylabel('时间 (秒)');
            grid on;
            
            subplot(1, 3, 3);
            nmseValues = obj.getNMSEValues();
            bar(nmseValues);
            set(gca, 'XTickLabel', obj.pAlgorithmNames, 'XTickLabelRotation', 45);
            title('NMSE对比');
            ylabel('NMSE');
            grid on;
        end
        
        function color = getColor(obj, name)
            % 获取算法对应的颜色
            if isfield(obj.COLORS, name)
                color = obj.COLORS.(name);
            else
                color = obj.COLORS.default;
            end
        end
        
        function values = getSNRValues(obj)
            % 获取所有SNR值
            values = zeros(1, length(obj.pAlgorithmNames));
            for i = 1:length(obj.pAlgorithmNames)
                name = obj.pAlgorithmNames{i};
                values(i) = obj.pResults.(name).Metrics.SNR;
            end
        end
        
        function values = getNMSEValues(obj)
            % 获取所有NMSE值
            values = zeros(1, length(obj.pAlgorithmNames));
            for i = 1:length(obj.pAlgorithmNames)
                name = obj.pAlgorithmNames{i};
                values(i) = obj.pResults.(name).Metrics.NMSE;
            end
        end
        
        function values = getTimeValues(obj)
            % 获取所有运行时间
            values = zeros(1, length(obj.pAlgorithmNames));
            for i = 1:length(obj.pAlgorithmNames)
                name = obj.pAlgorithmNames{i};
                values(i) = obj.pResults.(name).Time;
            end
        end
    end
end
