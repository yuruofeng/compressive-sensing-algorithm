function results = run_all_demos()
    % run_all_demos 运行所有demo并生成验证报告
    
    scriptPath = fileparts(mfilename('fullpath'));
    rootPath = fileparts(scriptPath);
    addpath(rootPath);
    
    fprintf('\n========================================\n');
    fprintf('  Demo程序运行测试\n');
    fprintf('  时间: %s\n', char(datetime('now')));
    fprintf('========================================\n\n');
    
    demos = {'demo_basic_usage', 'demo_algorithm_comparison', 'demo_mmv', 'demo_block_sparse'};
    results = struct();
    
    for i = 1:length(demos)
        demoName = demos{i};
        fprintf('\n>>> 测试 %d/%d: %s\n', i, length(demos), demoName);
        fprintf('    开始时间: %s\n', datestr(now));
        
        results.(demoName) = struct();
        results.(demoName).name = demoName;
        results.(demoName).startTime = now;
        
        try
            if strcmp(demoName, 'demo_basic_usage')
                demo_basic_usage();
            elseif strcmp(demoName, 'demo_algorithm_comparison')
                demo_algorithm_comparison();
            elseif strcmp(demoName, 'demo_mmv')
                demo_mmv();
            elseif strcmp(demoName, 'demo_block_sparse')
                demo_block_sparse();
            end
            
            results.(demoName).status = 'PASS';
            results.(demoName).error = '';
            fprintf('    状态: 通过 ✓\n');
            
        catch ME
            results.(demoName).status = 'FAIL';
            results.(demoName).error = ME.message;
            results.(demoName).stack = ME.stack;
            fprintf('    状态: 失败 ✗\n');
            fprintf('    错误: %s\n', ME.message);
            if ~isempty(ME.stack)
                fprintf('    位置: %s (行 %d)\n', ME.stack(1).name, ME.stack(1).line);
            end
        end
        
        results.(demoName).endTime = now;
        close all;
        fprintf('    结束时间: %s\n', datestr(now));
    end
    
    fprintf('\n========================================\n');
    fprintf('  测试结果汇总\n');
    fprintf('========================================\n\n');
    
    passCount = 0;
    failCount = 0;
    
    for i = 1:length(demos)
        demoName = demos{i};
        status = results.(demoName).status;
        if strcmp(status, 'PASS')
            passCount = passCount + 1;
            fprintf('  [✓] %s - 通过\n', demoName);
        else
            failCount = failCount + 1;
            fprintf('  [✗] %s - 失败: %s\n', demoName, results.(demoName).error);
        end
    end
    
    fprintf('\n总计: %d 通过, %d 失败\n', passCount, failCount);
end
