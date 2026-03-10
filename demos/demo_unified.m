function demo_unified(varargin)
    % demo_unified 统一算法演示入口
    % 
    % 提供统一的算法演示接口，支持：
    %   - 自动化算法测试
    %   - 灵活的参数配置
    %   - 标准化结果展示
    %   - 可扩展的算法注册
    %
    % 使用方法：
    %   % 基本用法 - 运行所有算法
    %   demo_unified();
    %   
    %   % 指定算法
    %   demo_unified('Algorithms', {'OMP', 'IHT', 'FISTA'});
    %   
    %   % 按类别运行
    %   demo_unified('Category', 'greedy');
    %   
    %   % 自定义参数
    %   demo_unified('N', 512, 'K', 50, 'M', 200);
    %   
    %   % 使用预设配置
    %   demo_unified('Preset', 'high_sparsity');
    %   
    %   % 生成报告
    %   demo_unified('GenerateReport', true);
    %
    % 参数说明：
    %   Algorithms - 算法名称列表 (cell array)
    %   Category - 算法类别 ('greedy', 'iterative', 'convex', 'sbl', 'probabilistic')
    %   N - 信号长度
    %   K - 稀疏度
    %   M - 测量数
    %   NoiseLevel - 噪声水平
    %   Preset - 预设配置名称
    %   GenerateReport - 是否生成报告 (true/false)
    %   Verbose - 是否显示详细信息 (true/false)
    %
    % 作者: 压缩感知算法库
    % 版本: 2.0
    % 更新时间: 2026-03-10
    
    p = inputParser;
    addParameter(p, 'Algorithms', {}, @iscell);
    addParameter(p, 'Category', '', @ischar);
    addParameter(p, 'N', 256, @isnumeric);
    addParameter(p, 'K', 20, @isnumeric);
    addParameter(p, 'M', 128, @isnumeric);
    addParameter(p, 'NoiseLevel', 0.01, @isnumeric);
    addParameter(p, 'Preset', '', @ischar);
    addParameter(p, 'GenerateReport', false, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    parse(p, varargin{:});
    
    opts = p.Results;
    
    run_demo(opts);
end

function run_demo(opts)
    % 主演示流程
    
    fprintf('\n========================================\n');
    fprintf('  压缩感知算法统一演示平台\n');
    fprintf('  版本: 2.0\n');
    fprintf('========================================\n\n');
    
    % 初始化组件
    registry = AlgorithmRegistry.getInstance();
    config = DemoConfig();
    presenter = ResultPresenter();
    
    % 配置参数
    configure_params(config, opts);
    
    % 确定要运行的算法
    algorithms = determine_algorithms(registry, opts);
    
    % 生成测试数据
    [A, y, x_true] = generate_test_data(config);
    
    % 运行算法
    run_algorithms(registry, algorithms, A, y, x_true, presenter, opts);
    
    % 展示结果
    presenter.displayTable();
    
    if ~isempty(x_true)
        presenter.visualize(x_true, 'mode', 'all');
    end
    
    % 生成报告
    if opts.GenerateReport
        presenter.generateReport();
    end
    
    fprintf('演示完成！\n\n');
end

function configure_params(config, opts)
    % 配置测试参数
    
    if ~isempty(opts.Preset)
        config.loadPreset(opts.Preset);
    else
        config.SignalLength = opts.N;
        config.Sparsity = opts.K;
        config.NumMeasurements = opts.M;
        config.NoiseLevel = opts.NoiseLevel;
        
        if opts.Verbose
            config.displayParams();
        end
    end
end

function algorithms = determine_algorithms(registry, opts)
    % 确定要运行的算法列表
    
    if ~isempty(opts.Algorithms)
        algorithms = opts.Algorithms;
        fprintf('运行指定算法: %s\n\n', strjoin(algorithms, ', '));
    elseif ~isempty(opts.Category)
        algList = registry.getAlgorithmsByCategory(opts.Category);
        algorithms = cell(length(algList), 1);
        for i = 1:length(algList)
            algorithms{i} = algList{i}.Name;
        end
        fprintf('运行类别 [%s] 的所有算法: %s\n\n', ...
            opts.Category, strjoin(algorithms, ', '));
    else
        algorithms = registry.getAllAlgorithmNames();
        fprintf('运行所有已注册算法: %s\n\n', strjoin(algorithms, ', '));
    end
end

function [A, y, x_true] = generate_test_data(config)
    % 生成测试数据
    
    params = config.getParams();
    
    if ~isempty(params.randomSeed)
        rng(params.randomSeed);
    end
    
    fprintf('生成测试数据...\n');
    
    N = params.N;
    M = params.M;
    K = params.K;
    noiseLevel = params.noiseLevel;
    
    % 生成测量矩阵
    A = randn(M, N);
    for col = 1:N
        A(:, col) = A(:, col) / norm(A(:, col));
    end
    
    % 生成稀疏信号
    x_true = zeros(N, 1);
    support = randperm(N, K);
    x_true(support) = randn(K, 1);
    
    % 生成测量向量
    noise = noiseLevel * randn(M, 1);
    y = A * x_true + noise;
    
    fprintf('  支撑集位置: [%s]\n', num2str(support(1:min(5,K))));
    fprintf('  测量向量范数: %.4f\n\n', norm(y));
end

function run_algorithms(registry, algorithms, A, y, x_true, presenter, opts)
    % 批量运行算法
    
    for i = 1:length(algorithms)
        name = algorithms{i};
        
        try
            fprintf('>>> 运行 %s 算法...\n', name);
            
            % 创建算法实例
            alg = registry.createInstance(name);
            
            % 运行算法
            tic;
            [result, info] = alg.solve(A, y);
            time = toc;
            
            % 计算性能指标
            metrics = result.evaluate(x_true);
            
            % 记录结果
            presenter.addResult(name, result, metrics, time);
            
            if opts.Verbose
                fprintf('  迭代次数: %d\n', info.iterations);
                fprintf('  运行时间: %.4f 秒\n', time);
                fprintf('  SNR: %.2f dB | NMSE: %.6f\n\n', ...
                    metrics.SNR, metrics.NMSE);
            end
            
        catch ME
            fprintf('  错误: %s\n\n', ME.message);
            if opts.Verbose
                fprintf('  详细信息: %s\n', ME.getReport());
            end
        end
    end
end
