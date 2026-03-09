function demo_algorithm_comparison()
    % demo_algorithm_comparison 算法对比演示
    % 比较不同算法在相同问题上的性能
    
    fprintf('\n========================================\n');
    fprintf('  算法性能对比演示\n');
    fprintf('========================================\n\n');
    
    rng(42);
    
    N = 256;
    M = 128;
    K = 20;
    noiseLevel = 0.01;
    
    x_true = zeros(N, 1);
    support = randperm(N, K);
    x_true(support) = randn(K, 1);
    
    A = cs.data.SensorMatrix.random(M, N);
    noise = noiseLevel * randn(M, 1);
    b = A.multiply(x_true) + noise;
    
    opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
    
    algorithms = {};
    results = {};
    times = [];
    
    fprintf('运行各算法...\n\n');
    
    fprintf('1. BSBL (块稀疏贝叶斯学习)\n');
    alg1 = cs.algorithms.sbl.BSBL(opts);
    blockStruct = cs.data.BlockStructure.equalBlock(N, 8);
    tic;
    [result1, ~] = alg1.solve(A, b, blockStruct);
    times(end+1) = toc;
    results{end+1} = result1;
    algorithms{end+1} = 'BSBL';
    
    fprintf('2. LassoADMM (LASSO-ADMM)\n');
    alg2 = cs.algorithms.convex.LassoADMM(opts);
    tic;
    [result2, ~] = alg2.solve(A, b);
    times(end+1) = toc;
    results{end+1} = result2;
    algorithms{end+1} = 'LassoADMM';
    
    fprintf('3. BasisPursuit (基追踪)\n');
    alg3 = cs.algorithms.convex.BasisPursuit(opts);
    alg3.Mode = 'BPDN';
    alg3.Epsilon = 0.1;
    tic;
    [result3, ~] = alg3.solve(A, b);
    times(end+1) = toc;
    results{end+1} = result3;
    algorithms{end+1} = 'BasisPursuit';
    
    fprintf('\n========================================\n');
    fprintf('  性能对比结果\n');
    fprintf('========================================\n\n');
    
    fprintf('%-15s %10s %10s %10s %12s\n', '算法', 'NMSE', 'SNR(dB)', '时间', '支撑集大小');
    fprintf('%s\n', repmat('-', 1, 60));
    
    for i = 1:length(results)
        metrics = results{i}.evaluate(x_true);
        fprintf('%-15s %10.2e %10.2f %10.3f %12d\n', ...
            algorithms{i}, metrics.NMSE, metrics.SNR, times(i), results{i}.SupportSize);
    end
    
    fprintf('\n可视化对比...\n');
    
    figure('Name', '算法对比', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 600]);
    
    subplot(2, 2, 1);
    stem(x_true, 'b', 'MarkerSize', 3);
    title('真实信号');
    xlabel('索引');
    ylabel('幅值');
    grid on;
    
    for i = 1:min(3, length(results))
        subplot(2, 2, i+1);
        stem(results{i}.X, 'r', 'MarkerSize', 3);
        title(sprintf('%s 重构', algorithms{i}));
        xlabel('索引');
        ylabel('幅值');
        grid on;
    end
    
    fprintf('\n对比演示完成!\n');
end
