function demo_bcs()
    % demo_bcs 贝叶斯压缩感知(BCS)算法演示
    % 展示BCS算法的基本使用方法和重构性能
    
    fprintf('\n========================================\n');
    fprintf('  贝叶斯压缩感知(BCS)算法演示\n');
    fprintf('========================================\n\n');
    
    fprintf('参考文献:\n');
    fprintf('S. Ji, Y. Xue, and L. Carin, "Bayesian Compressive Sensing,"\n');
    fprintf('IEEE Trans. Signal Processing, vol. 56, no. 6, June 2008.\n\n');
    
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
    
    fprintf('2. 使用BCS算法进行重构\n');
    fprintf('   BCS基于Relevance Vector Machine (RVM)框架\n');
    fprintf('   使用快速边际化方法进行超参数学习\n\n');
    
    opts = cs.core.Options(...
        'MaxIterations', 300, ...
        'Tolerance', 1e-6, ...
        'Verbose', true, ...
        'DisplayInterval', 30);
    
    alg = cs.algorithms.sbl.BCS(opts);
    
    info = alg.getAlgorithmInfo();
    fprintf('算法信息:\n');
    fprintf('   名称: %s\n', info.Name);
    fprintf('   版本: %s\n', info.Version);
    fprintf('\n');
    
    tic;
    [result, solveInfo] = alg.solve(A, b);
    elapsed = toc;
    
    fprintf('\n3. 重构结果分析\n');
    fprintf('   迭代次数: %d\n', result.Iterations);
    fprintf('   是否收敛: %s\n', mat2str(result.Converged));
    fprintf('   运行时间: %.3f 秒\n', elapsed);
    fprintf('   支撑集大小: %d\n', result.SupportSize);
    fprintf('   估计噪声方差: %.6e\n', solveInfo.noise_variance);
    
    metrics = result.evaluate(x_true);
    fprintf('\n   重构质量指标:\n');
    fprintf('   - MSE: %.6e\n', metrics.MSE);
    fprintf('   - NMSE: %.6e\n', metrics.NMSE);
    fprintf('   - SNR: %.2f dB\n', metrics.SNR);
    fprintf('   - 支撑集恢复率: %.1f%%\n', metrics.SupportRecovery * 100);
    
    fprintf('\n4. 与BSBL算法对比\n');
    
    optsBSBL = cs.core.Options(...
        'MaxIterations', 200, ...
        'Tolerance', 1e-8, ...
        'Verbose', false);
    
    algBSBL = cs.algorithms.sbl.BSBL(optsBSBL);
    blockStruct = cs.data.BlockStructure.equalBlock(N, 8);
    
    tic;
    [resultBSBL, ~] = algBSBL.solve(A, b, blockStruct);
    elapsedBSBL = toc;
    
    metricsBSBL = resultBSBL.evaluate(x_true);
    
    fprintf('\n   算法对比结果:\n');
    fprintf('   %-10s %8s %10s %10s\n', '算法', 'SNR(dB)', '时间(s)', '支撑集');
    fprintf('   %-10s %8.2f %10.3f %10d\n', 'BCS', metrics.SNR, elapsed, result.SupportSize);
    fprintf('   %-10s %8.2f %10.3f %10d\n', 'BSBL', metricsBSBL.SNR, elapsedBSBL, resultBSBL.SupportSize);
    
    fprintf('\n5. 可视化结果\n');
    
    figure('Name', 'BCS算法演示', 'Position', [100, 100, 1200, 400]);
    
    subplot(1, 3, 1);
    stem(x_true, 'b', 'MarkerSize', 4, 'LineWidth', 0.5);
    hold on;
    stem(result.X, 'r', 'MarkerSize', 4, 'LineWidth', 0.5);
    legend('真实信号', 'BCS重构');
    title('信号重构对比');
    xlabel('索引');
    ylabel('幅值');
    grid on;
    
    subplot(1, 3, 2);
    if ~isempty(result.History) && isfield(result.History, 'ObjectiveValues')
        plot(result.History.ObjectiveValues, 'b-', 'LineWidth', 1.5);
        title('目标函数收敛曲线');
        xlabel('迭代次数');
        ylabel('目标函数值');
        grid on;
    end
    
    subplot(1, 3, 3);
    if ~isempty(result.History) && isfield(result.History, 'ResidualNorms')
        semilogy(result.History.ResidualNorms, 'r-', 'LineWidth', 1.5);
        title('残差范数收敛曲线');
        xlabel('迭代次数');
        ylabel('残差范数');
        grid on;
    end
    
    fprintf('\n演示完成!\n');
end
