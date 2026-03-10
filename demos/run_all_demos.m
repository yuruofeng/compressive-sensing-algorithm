function results = run_all_demos()
    % run_all_demos 运行所有演示程序并生成验证报告
    % 
    % 本脚本运行demos目录下的所有演示程序：
    %   - demo_unified: 统一算法演示（主入口）
    %   - demo_bcs: 贝叶斯压缩感知专用演示
    %   - demo_mmv: 多测量向量专用演示
    %   - demo_block_sparse: 块稀疏信号专用演示
    %
    % 输出：
    %   results - 包含所有demo运行结果的结构体
    %
    % 使用方法：
    %   results = run_all_demos();
    %
    % 作者: 压缩感知算法库
    % 版本: 2.1
    % 更新时间: 2026-03-10
    
    scriptPath = fileparts(mfilename('fullpath'));
    rootPath = fileparts(scriptPath);
    addpath(rootPath);
    
    fprintf('\n========================================\n');
    fprintf('  Demo程序批量测试\n');
    fprintf('  时间: %s\n', char(datetime('now')));
    fprintf('========================================\n\n');
    
    demos = {...
        'demo_unified_standard', ...
        'demo_unified_all_algorithms', ...
        'demo_bcs', ...
        'demo_mmv', ...
        'demo_block_sparse'};
    
    results = struct();
    
    for i = 1:length(demos)
        demoName = demos{i};
        fprintf('\n>>> 测试 %d/%d: %s\n', i, length(demos), demoName);
        fprintf('    开始时间: %s\n', datestr(now));
        
        results.(demoName) = struct();
        results.(demoName).name = demoName;
        results.(demoName).startTime = now;
        
        try
            run_single_demo(demoName);
            
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
    
    display_summary(results, demos);
end

function run_single_demo(demoName)
    % 运行单个demo
    
    switch demoName
        case 'demo_unified_standard'
            % 运行统一demo的标准配置
            demo_unified('Algorithms', {'OMP', 'FISTA'}, 'Verbose', false);
            
        case 'demo_unified_all_algorithms'
            % 运行所有算法（静默模式）
            demo_unified('Verbose', false);
            
        case 'demo_bcs'
            demo_bcs();
            
        case 'demo_mmv'
            demo_mmv();
            
        case 'demo_block_sparse'
            demo_block_sparse();
            
        otherwise
            error('未知的demo: %s', demoName);
    end
end

function display_summary(results, demos)
    % 显示测试结果汇总
    
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
    fprintf('========================================\n');
    
    if failCount == 0
        fprintf('所有demo运行成功！\n');
    else
        fprintf('警告: %d 个demo运行失败，请检查错误信息。\n', failCount);
    end
end
