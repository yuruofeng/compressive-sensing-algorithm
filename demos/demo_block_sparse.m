function demo_block_sparse()
    % demo_block_sparse 块稀疏信号重构演示
    
    fprintf('\n========================================\n');
    fprintf('  块稀疏信号重构演示\n');
    fprintf('========================================\n\n');
    
    rng(42);
    
    N = 200;
    M = 80;
    numActiveBlocks = 3;
    blockSize = 10;
    
    fprintf('问题设置:\n');
    fprintf('  信号长度 N = %d\n', N);
    fprintf('  测量数 M = %d\n', M);
    fprintf('  块大小 = %d\n', blockSize);
    fprintf('  活跃块数 = %d\n\n', numActiveBlocks);
    
    x_true = zeros(N, 1);
    numBlocks = N / blockSize;
    activeBlocks = randperm(numBlocks, numActiveBlocks);
    
    for i = 1:numActiveBlocks
        blockIdx = activeBlocks(i);
        startIdx = (blockIdx - 1) * blockSize + 1;
        endIdx = blockIdx * blockSize;
        
        corr = 0.9;
        B = toeplitz(corr.^(0:blockSize-1));
        x_true(startIdx:endIdx) = mvnrnd(zeros(1, blockSize), B)';
    end
    
    A = cs.data.SensorMatrix.random(M, N);
    noise = 0.01 * randn(M, 1);
    b = A.multiply(x_true) + noise;
    
    blockStruct = cs.data.BlockStructure.equalBlock(N, blockSize);
    
    opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
    
    fprintf('使用BSBL算法 (利用块结构)...\n');
    alg_bsbl = cs.algorithms.sbl.BSBL(opts);
    tic;
    [result_bsbl, ~] = alg_bsbl.solve(A, b, blockStruct);
    time_bsbl = toc;
    
    fprintf('使用LassoADMM (不利用块结构)...\n');
    alg_lasso = cs.algorithms.convex.LassoADMM(opts);
    tic;
    [result_lasso, ~] = alg_lasso.solve(A, b);
    time_lasso = toc;
    
    fprintf('\n========================================\n');
    fprintf('  结果对比\n');
    fprintf('========================================\n\n');
    
    metrics_bsbl = result_bsbl.evaluate(x_true);
    metrics_lasso = result_lasso.evaluate(x_true);
    
    fprintf('%-15s %10s %10s %10s\n', '算法', 'NMSE', 'SNR(dB)', '时间');
    fprintf('%s\n', repmat('-', 1, 50));
    fprintf('%-15s %10.2e %10.2f %10.3f\n', 'BSBL', metrics_bsbl.NMSE, metrics_bsbl.SNR, time_bsbl);
    fprintf('%-15s %10.2e %10.2f %10.3f\n', 'LassoADMM', metrics_lasso.NMSE, metrics_lasso.SNR, time_lasso);
    
    fprintf('\n可视化...\n');
    
    figure('Name', '块稀疏重构', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 400]);
    
    subplot(1, 3, 1);
    stem(x_true, 'b', 'MarkerSize', 2);
    title('真实信号 (块稀疏)');
    xlabel('索引');
    ylabel('幅值');
    grid on;
    
    subplot(1, 3, 2);
    stem(result_bsbl.X, 'r', 'MarkerSize', 2);
    title(sprintf('BSBL重构 (SNR=%.1fdB)', metrics_bsbl.SNR));
    xlabel('索引');
    grid on;
    
    subplot(1, 3, 3);
    stem(result_lasso.X, 'g', 'MarkerSize', 2);
    title(sprintf('LassoADMM重构 (SNR=%.1fdB)', metrics_lasso.SNR));
    xlabel('索引');
    grid on;
    
    fprintf('\n块稀疏演示完成!\n');
end
