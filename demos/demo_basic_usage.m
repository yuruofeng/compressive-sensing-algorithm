function demo_basic_usage()
    % demo_basic_usage 基本用法演示
    % 展示压缩感知算法库的基本使用方法
    
    fprintf('\n========================================\n');
    fprintf('  压缩感知算法库 - 基本用法演示\n');
    fprintf('========================================\n\n');
    
    rng(42);
    
    N = 256;
    M = 128;
    K = 20;
    noiseLevel = 0.01;
    
    fprintf('1. 生成测试信号\n');
    fprintf('   信号长度 N = %d\n', N);
    fprintf('   测量数 M = %d\n', M);
    fprintf('   稀疏度 K = %d\n', K);
    
    x_true = zeros(N, 1);
    support = randperm(N, K);
    x_true(support) = randn(K, 1);
    
    A = cs.data.SensorMatrix.random(M, N);
    
    noise = noiseLevel * randn(M, 1);
    b = A.multiply(x_true) + noise;
    
    fprintf('   测量向量 b 生成完成\n\n');
    
    fprintf('2. 使用BSBL算法进行重构\n');
    
    opts = cs.core.Options(...
        'MaxIterations', 200, ...
        'Tolerance', 1e-8, ...
        'Lambda', 1e-3, ...
        'Verbose', true, ...
        'DisplayInterval', 20);
    
    alg = cs.algorithms.sbl.BSBL(opts);
    
    blockStruct = cs.data.BlockStructure.equalBlock(N, 8);
    fprintf('   块大小: 8, 块数: %d\n\n', blockStruct.NumBlocks);
    
    tic;
    [result, ~] = alg.solve(A, b, blockStruct);
    elapsed = toc;
    
    fprintf('\n3. 重构结果分析\n');
    fprintf('   迭代次数: %d\n', result.Iterations);
    fprintf('   是否收敛: %s\n', mat2str(result.Converged));
    fprintf('   运行时间: %.3f 秒\n', elapsed);
    fprintf('   支撑集大小: %d\n', result.SupportSize);
    
    metrics = result.evaluate(x_true);
    fprintf('\n   重构质量指标:\n');
    fprintf('   - MSE: %.6e\n', metrics.MSE);
    fprintf('   - NMSE: %.6e\n', metrics.NMSE);
    fprintf('   - SNR: %.2f dB\n', metrics.SNR);
    fprintf('   - 支撑集恢复率: %.1f%%\n', metrics.SupportRecovery * 100);
    
    fprintf('\n4. 可视化结果\n');
    result.plotSignal('TrueSignal', x_true, 'Title', 'BSBL重构结果');
    
    fprintf('\n5. 收敛曲线\n');
    result.plotConvergence();
    
    fprintf('\n演示完成!\n');
end
