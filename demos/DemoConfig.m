classdef DemoConfig < handle
    % DemoConfig 演示参数配置类
    % 
    % 提供统一的参数管理和验证机制，支持：
    %   - 标准参数配置
    %   - 参数验证
    %   - 预设配置模板
    %   - 配置导入导出
    %
    % 使用示例：
    %   config = DemoConfig();
    %   config.setSignalParams(256, 20);
    %   config.setMeasurementParams(128, 0.01);
    %   params = config.getParams();
    %
    % 作者: 压缩感知算法库
    % 版本: 1.0
    
    properties (Access = private)
        pParams
        pPresets
    end
    
    properties (Dependent)
        SignalLength
        Sparsity
        NumMeasurements
        NoiseLevel
        RandomSeed
    end
    
    properties (Constant)
        PRESET_NAMES = {'standard', 'high_sparsity', 'low_measurements', 'noisy', 'clean'};
    end
    
    methods
        function obj = DemoConfig()
            obj.pParams = obj.getDefaultParams();
            obj.pPresets = obj.createPresets();
        end
        
        function set.SignalLength(obj, value)
            obj.validatePositiveInteger(value, 'SignalLength');
            obj.pParams.N = value;
        end
        
        function value = get.SignalLength(obj)
            value = obj.pParams.N;
        end
        
        function set.Sparsity(obj, value)
            obj.validatePositiveInteger(value, 'Sparsity');
            if value > obj.pParams.N
                error('DemoConfig:InvalidSparsity', ...
                    '稀疏度 %d 不能大于信号长度 %d', value, obj.pParams.N);
            end
            obj.pParams.K = value;
        end
        
        function value = get.Sparsity(obj)
            value = obj.pParams.K;
        end
        
        function set.NumMeasurements(obj, value)
            obj.validatePositiveInteger(value, 'NumMeasurements');
            if value > obj.pParams.N
                error('DemoConfig:InvalidMeasurements', ...
                    '测量数 %d 不能大于信号长度 %d', value, obj.pParams.N);
            end
            obj.pParams.M = value;
        end
        
        function value = get.NumMeasurements(obj)
            value = obj.pParams.M;
        end
        
        function set.NoiseLevel(obj, value)
            if value < 0
                error('DemoConfig:InvalidNoiseLevel', '噪声水平必须为非负数');
            end
            obj.pParams.noiseLevel = value;
        end
        
        function value = get.NoiseLevel(obj)
            value = obj.pParams.noiseLevel;
        end
        
        function set.RandomSeed(obj, value)
            if ~isempty(value)
                if ~isnumeric(value) || value < 0
                    error('DemoConfig:InvalidRandomSeed', '随机种子必须为非负整数');
                end
            end
            obj.pParams.randomSeed = value;
        end
        
        function value = get.RandomSeed(obj)
            value = obj.pParams.randomSeed;
        end
        
        function setSignalParams(obj, N, K)
            % 设置信号参数
            obj.SignalLength = N;
            obj.Sparsity = K;
        end
        
        function setMeasurementParams(obj, M, noiseLevel)
            % 设置测量参数
            obj.NumMeasurements = M;
            obj.NoiseLevel = noiseLevel;
        end
        
        function params = getParams(obj)
            % 获取所有参数
            params = obj.pParams;
        end
        
        function loadPreset(obj, presetName)
            % 加载预设配置
            if ~isfield(obj.pPresets, presetName)
                error('DemoConfig:UnknownPreset', ...
                    '未知的预设配置: %s\n可用预设: %s', ...
                    presetName, strjoin(obj.PRESET_NAMES, ', '));
            end
            
            preset = obj.pPresets.(presetName);
            fields = fieldnames(preset);
            for i = 1:length(fields)
                obj.pParams.(fields{i}) = preset.(fields{i});
            end
            
            fprintf('已加载预设配置: %s\n', presetName);
            obj.displayParams();
        end
        
        function displayParams(obj)
            % 显示当前参数配置
            fprintf('\n========================================\n');
            fprintf('  当前参数配置\n');
            fprintf('========================================\n');
            fprintf('信号长度 N = %d\n', obj.pParams.N);
            fprintf('稀疏度   K = %d\n', obj.pParams.K);
            fprintf('测量数   M = %d (压缩比 %.2f)\n', ...
                obj.pParams.M, obj.pParams.N / obj.pParams.M);
            fprintf('噪声水平 = %.4f\n', obj.pParams.noiseLevel);
            if ~isempty(obj.pParams.randomSeed)
                fprintf('随机种子 = %d\n', obj.pParams.randomSeed);
            end
            fprintf('========================================\n\n');
        end
        
        function config = exportConfig(obj)
            % 导出配置（用于保存）
            config = obj.pParams;
        end
        
        function importConfig(obj, config)
            % 导入配置
            if ~isstruct(config)
                error('DemoConfig:InvalidConfig', '配置必须是结构体');
            end
            
            fields = fieldnames(config);
            for i = 1:length(fields)
                if isfield(obj.pParams, fields{i})
                    obj.pParams.(fields{i}) = config.(fields{i});
                end
            end
        end
    end
    
    methods (Access = private)
        function params = getDefaultParams(obj)
            % 默认参数
            params = struct(...
                'N', 256, ...
                'K', 20, ...
                'M', 128, ...
                'noiseLevel', 0.01, ...
                'randomSeed', 42);
        end
        
        function presets = createPresets(obj)
            % 创建预设配置模板
            presets = struct();
            
            % 标准配置
            presets.standard = struct(...
                'N', 256, 'K', 20, 'M', 128, 'noiseLevel', 0.01, 'randomSeed', 42);
            
            % 高稀疏度
            presets.high_sparsity = struct(...
                'N', 512, 'K', 100, 'M', 256, 'noiseLevel', 0.01, 'randomSeed', 42);
            
            % 低测量数
            presets.low_measurements = struct(...
                'N', 256, 'K', 20, 'M', 64, 'noiseLevel', 0.01, 'randomSeed', 42);
            
            % 高噪声
            presets.noisy = struct(...
                'N', 256, 'K', 20, 'M', 128, 'noiseLevel', 0.1, 'randomSeed', 42);
            
            % 无噪声
            presets.clean = struct(...
                'N', 256, 'K', 20, 'M', 128, 'noiseLevel', 0.0, 'randomSeed', 42);
        end
        
        function validatePositiveInteger(obj, value, paramName)
            if ~isnumeric(value) || value <= 0 || mod(value, 1) ~= 0
                error('DemoConfig:InvalidParam', ...
                    '%s 必须是正整数', paramName);
            end
        end
    end
    
    methods (Static)
        function listPresets()
            % 列出所有可用预设
            fprintf('\n可用的预设配置:\n');
            fprintf('  - standard: 标准配置 (N=256, K=20, M=128)\n');
            fprintf('  - high_sparsity: 高稀疏度 (N=512, K=100, M=256)\n');
            fprintf('  - low_measurements: 低测量数 (N=256, K=20, M=64)\n');
            fprintf('  - noisy: 高噪声环境 (N=256, K=20, M=128, noise=0.1)\n');
            fprintf('  - clean: 无噪声环境 (N=256, K=20, M=128, noise=0)\n\n');
        end
    end
end
