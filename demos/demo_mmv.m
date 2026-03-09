function demo_mmv()
    % demo_mmv 多测量向量(MMV)问题演示
    
    fprintf('\n========================================\n');
    fprintf('  多测量向量(MMV)问题演示\n');
    fprintf('========================================\n\n');
    
    rng(42);
    
    N = 256;
    M = 100;
    K = 25;
    L = 10;
    noiseLevel = 0.01;
    
    fprintf('问题设置:\n');
    fprintf('  信号长度 N = %d\n', N);
    fprintf('  测量数 M = %d\n', M);
    fprintf('  稀疏度 K = %d\n', K);
    fprintf('  测量向量数 L = %d\n\n', L);
    
    X_true = zeros(N, L);
    commonSupport = randperm(N, K);
    for l = 1:L
        X_true(commonSupport, l) = randn(K, 1);
    end
    
    A = cs.data.SensorMatrix.random(M, N);
    
    B = A.multiply(X_true) + noiseLevel * randn(M, L);
    
    opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
    
    fprintf('运行TMSBL算法...\n');
    alg_tmsbl = cs.algorithms.sbl.TMSBL(opts);
    tic;
    [result_tmsbl, ~] = alg_tmsbl.solve(A, B);
    time_tmsbl = toc;
    
    fprintf('运行MSBL算法...\n');
    alg_msbl = cs.algorithms.sbl.MSBL(opts);
    tic;
    [result_msbl, ~] = alg_msbl.solve(A, B);
    time_msbl = toc;
    
    fprintf('\n========================================\n');
    fprintf('  结果对比\n');
    fprintf('========================================\n\n');
    
    X_rec_tmsbl = result_tmsbl.X;
    X_rec_msbl = result_msbl.X;
    
    nmse_tmsbl = norm(X_rec_tmsbl - X_true, 'fro')^2 / norm(X_true, 'fro')^2;
    nmse_msbl = norm(X_rec_msbl - X_true, 'fro')^2 / norm(X_true, 'fro')^2;
    
    snr_tmsbl = 10 * log10(norm(X_true, 'fro')^2 / norm(X_rec_tmsbl - X_true, 'fro')^2);
    snr_msbl = 10 * log10(norm(X_true, 'fro')^2 / norm(X_rec_msbl - X_true, 'fro')^2);
    
    fprintf('%-15s %10s %10s %10s\n', '算法', 'NMSE', 'SNR(dB)', '时间');
    fprintf('%s\n', repmat('-', 1, 50));
    fprintf('%-15s %10.2e %10.2f %10.3f\n', 'TMSBL', nmse_tmsbl, snr_tmsbl, time_tmsbl);
    fprintf('%-15s %10.2e %10.2f %10.3f\n', 'MSBL', nmse_msbl, snr_msbl, time_msbl);
    
    fprintf('\n可视化...\n');
    
    figure('Name', 'MMV重构结果', 'NumberTitle', 'off', 'Position', [100, 100, 1200, 400]);
    
    subplot(1, 3, 1);
    imagesc(abs(X_true)');
    colorbar;
    title('真实信号 (行范数)');
    xlabel('信号索引');
    ylabel('测量向量');
    
    subplot(1, 3, 2);
    imagesc(abs(X_rec_tmsbl)');
    colorbar;
    title('TMSBL重构');
    xlabel('信号索引');
    ylabel('测量向量');
    
    subplot(1, 3, 3);
    imagesc(abs(X_rec_msbl)');
    colorbar;
    title('MSBL重构');
    xlabel('信号索引');
    ylabel('测量向量');
    
    fprintf('\nMMV演示完成!\n');
end
