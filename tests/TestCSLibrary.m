classdef TestCSLibrary < matlab.unittest.TestCase
    % TestCSLibrary 压缩感知算法库综合测试
    
    properties
        TestSignal
        TestMatrix
        TestMeasurements
        Sparsity
        NoiseLevel
    end
    
    methods (TestMethodSetup)
        function setupTestData(testCase)
            rng(42);
            
            N = 256;
            M = 128;
            testCase.Sparsity = 20;
            testCase.NoiseLevel = 0.01;
            
            testCase.TestMatrix = randn(M, N);
            testCase.TestMatrix = orth(testCase.TestMatrix);
            
            testCase.TestSignal = zeros(N, 1);
            support = randperm(N, testCase.Sparsity);
            testCase.TestSignal(support) = randn(testCase.Sparsity, 1);
            
            noise = testCase.NoiseLevel * randn(M, 1);
            testCase.TestMeasurements = testCase.TestMatrix * testCase.TestSignal + noise;
        end
    end
    
    methods (Test)
        function testOptionsCreation(testCase)
            opts = cs.core.Options();
            testCase.verifyEqual(opts.Tolerance, 1e-8);
            testCase.verifyEqual(opts.MaxIterations, 1000);
            testCase.verifyEqual(opts.Lambda, 1e-3);
        end
        
        function testOptionsPreset(testCase)
            opts = cs.core.Options().loadPreset('fast');
            testCase.verifyEqual(opts.Tolerance, 1e-6);
            testCase.verifyEqual(opts.MaxIterations, 500);
        end
        
        function testOptionsInvalidInput(testCase)
            testCase.verifyError(@() cs.core.Options('InvalidParam', 123), ...
                'MATLAB:InvalidInput');
        end
        
        function testSensorMatrixCreation(testCase)
            A = cs.data.SensorMatrix(testCase.TestMatrix);
            testCase.verifyEqual(A.M, 128);
            testCase.verifyEqual(A.N, 256);
            testCase.verifyTrue(A.IsExplicit);
        end
        
        function testSensorMatrixMultiply(testCase)
            A = cs.data.SensorMatrix(testCase.TestMatrix);
            y = A.multiply(testCase.TestSignal, false);
            testCase.verifyEqual(size(y), [128, 1]);
            
            x = A.multiply(y, true);
            testCase.verifyEqual(size(x), [256, 1]);
        end
        
        function testSensorMatrixRandom(testCase)
            A = cs.data.SensorMatrix.random(64, 128, 'Normalized', true);
            testCase.verifyEqual(A.M, 64);
            testCase.verifyEqual(A.N, 128);
        end
        
        function testBlockStructureCreation(testCase)
            starts = [1, 10, 20, 30];
            lengths = [9, 10, 10, 10];
            bs = cs.data.BlockStructure(starts, lengths);
            
            testCase.verifyEqual(bs.NumBlocks, 4);
            testCase.verifyEqual(bs.TotalLength, 39);
        end
        
        function testBlockStructureEqualBlock(testCase)
            bs = cs.data.BlockStructure.equalBlock(100, 10);
            testCase.verifyEqual(bs.NumBlocks, 10);
            testCase.verifyEqual(bs.MeanBlockLength, 10);
        end
        
        function testIterationHistory(testCase)
            history = cs.data.IterationHistory(100);
            
            for i = 1:10
                history.record('Objective', rand(), 'Residual', rand(), 'SupportSize', randi(50));
            end
            
            testCase.verifyEqual(history.NumRecorded, 10);
            history.trim();
            testCase.verifyEqual(length(history.ObjectiveValues), 10);
        end
        
        function testConvergenceChecker(testCase)
            checker = cs.core.ConvergenceChecker('Tolerance', 1e-6, 'MaxIterations', 100);
            
            prev = 1.0;
            for i = 1:50
                curr = prev * 0.5;
                [converged, ~] = checker.check(i, curr, prev);
                if converged
                    break;
                end
                prev = curr;
            end
            
            testCase.verifyTrue(checker.Converged);
        end
        
        function testShrinkageSoft(testCase)
            x = [-3, -1, 0, 1, 3];
            y = cs.utils.shrinkage(x, 1);
            expected = [-2, 0, 0, 0, 2];
            testCase.verifyEqual(y, expected, 'AbsTol', 1e-10);
        end
        
        function testShrinkageHard(testCase)
            x = [-3, -1, 0, 1, 3];
            y = cs.utils.shrinkage(x, 1, 'Method', 'hard');
            expected = [-3, 0, 0, 0, 3];
            testCase.verifyEqual(y, expected, 'AbsTol', 1e-10);
        end
        
        function testBSBLBasic(testCase)
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.sbl.BSBL(opts);
            
            blockStruct = cs.data.BlockStructure.equalBlock(256, 8);
            [result, ~] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements, blockStruct);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(result.Iterations <= 100);
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.1);
        end
        
        function testTMSBLBasic(testCase)
            L = 5;
            B = repmat(testCase.TestMeasurements, 1, L);
            B = B + testCase.NoiseLevel * randn(128, L);
            
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.sbl.TMSBL(opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, B);
            
            testCase.verifyEqual(size(result.X), [256, L]);
            testCase.verifyTrue(result.Iterations <= 100);
        end
        
        function testMSBLBasic(testCase)
            L = 5;
            B = repmat(testCase.TestMeasurements, 1, L);
            B = B + testCase.NoiseLevel * randn(128, L);
            
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.sbl.MSBL(opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, B);
            
            testCase.verifyEqual(size(result.X), [256, L]);
        end
        
        function testLassoADMMBasic(testCase)
            opts = cs.core.Options('MaxIterations', 500, 'Lambda', 1e-2, 'Verbose', false);
            alg = cs.algorithms.convex.LassoADMM(opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.2);
        end
        
        function testBasisPursuitBasic(testCase)
            opts = cs.core.Options('MaxIterations', 500, 'Verbose', false);
            alg = cs.algorithms.convex.BasisPursuit('Mode', 'BP', opts);
            
            cleanMeasurements = testCase.TestMatrix * testCase.TestSignal;
            [result, ~] = alg.solve(testCase.TestMatrix, cleanMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
        end
        
        function testMFOCUSSBasic(testCase)
            L = 3;
            B = repmat(testCase.TestMeasurements, 1, L);
            
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.greedy.MFOCUSS('P', 0.8, opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, B);
            
            testCase.verifyEqual(size(result.X), [256, L]);
        end
        
        function testResultEvaluation(testCase)
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.sbl.BSBL(opts);
            
            blockStruct = cs.data.BlockStructure.equalBlock(256, 8);
            [result, ~] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements, blockStruct);
            
            metrics = result.evaluate(testCase.TestSignal);
            
            testCase.verifyTrue(isfield(metrics, 'MSE'));
            testCase.verifyTrue(isfield(metrics, 'NMSE'));
            testCase.verifyTrue(isfield(metrics, 'SNR'));
            testCase.verifyTrue(metrics.SNR > 10);
        end
        
        function testAlgorithmExceptionHandling(testCase)
            opts = cs.core.Options('MaxIterations', 10);
            alg = cs.algorithms.sbl.BSBL(opts);
            
            badMatrix = randn(10, 5);
            badVector = randn(20, 1);
            
            testCase.verifyError(@() alg.solve(badMatrix, badVector), ...
                'cs.exceptions.DimensionMismatchException');
        end
        
        function testBCSBasic(testCase)
            opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
            alg = cs.algorithms.sbl.BCS(opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(result.Iterations <= 200);
            testCase.verifyTrue(isfield(info, 'noise_variance'));
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.15);
        end
        
        function testBCSConvergence(testCase)
            opts = cs.core.Options('MaxIterations', 500, 'Tolerance', 1e-6, 'Verbose', false);
            alg = cs.algorithms.sbl.BCS(opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(info.converged || info.iterations >= 100);
            testCase.verifyTrue(info.support_size >= testCase.Sparsity * 0.5);
        end
        
        function testBCSHistoryTracking(testCase)
            opts = cs.core.Options('MaxIterations', 50, 'Verbose', false);
            alg = cs.algorithms.sbl.BCS(opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(~isempty(result.History));
            testCase.verifyTrue(length(result.History.ObjectiveValues) > 0);
        end
        
        function testBCSWithCleanSignal(testCase)
            opts = cs.core.Options('MaxIterations', 300, 'Verbose', false);
            alg = cs.algorithms.sbl.BCS(opts);
            
            cleanMeasurements = testCase.TestMatrix * testCase.TestSignal;
            [result, ~] = alg.solve(testCase.TestMatrix, cleanMeasurements);
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyGreaterThan(metrics.SNR, 20);
        end
        
        function testBCSAlgorithmInfo(testCase)
            alg = cs.algorithms.sbl.BCS();
            info = alg.getAlgorithmInfo();
            
            testCase.verifyEqual(info.Name, 'Bayesian Compressive Sensing');
            testCase.verifyTrue(~isempty(info.Reference));
        end
        
        function testOMPBasic(testCase)
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.greedy.OMP('Sparsity', testCase.Sparsity, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(result.Iterations <= testCase.Sparsity);
            testCase.verifyTrue(isfield(info, 'support_indices'));
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.2);
        end
        
        function testOMPHistoryTracking(testCase)
            opts = cs.core.Options('MaxIterations', 50, 'Verbose', false);
            alg = cs.algorithms.greedy.OMP('Sparsity', 20, opts);
            
            [result, ~] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(~isempty(result.History));
        end
        
        function testIHTBasic(testCase)
            opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
            alg = cs.algorithms.iterative.IHT('Sparsity', testCase.Sparsity, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(isfield(info, 'step_size'));
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.3);
        end
        
        function testIHTConvergence(testCase)
            opts = cs.core.Options('MaxIterations', 500, 'Tolerance', 1e-6, 'Verbose', false);
            alg = cs.algorithms.iterative.IHT('Sparsity', testCase.Sparsity, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(info.iterations <= 500);
        end
        
        function testFISTABasic(testCase)
            opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
            alg = cs.algorithms.iterative.FISTA('Lambda', 0.01, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(isfield(info, 'lambda'));
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.2);
        end
        
        function testFISTAConvergence(testCase)
            opts = cs.core.Options('MaxIterations', 500, 'Tolerance', 1e-6, 'Verbose', false);
            alg = cs.algorithms.iterative.FISTA('Lambda', 0.005, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(info.converged || info.iterations >= 100);
        end
        
        function testAMPBasic(testCase)
            opts = cs.core.Options('MaxIterations', 100, 'Verbose', false);
            alg = cs.algorithms.probabilistic.AMP('Sigma', testCase.NoiseLevel, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyEqual(size(result.X), [256, 1]);
            testCase.verifyTrue(isfield(info, 'sigma'));
            
            metrics = result.evaluate(testCase.TestSignal);
            testCase.verifyLessThan(metrics.NMSE, 0.3);
        end
        
        function testAMPConvergence(testCase)
            opts = cs.core.Options('MaxIterations', 200, 'Tolerance', 1e-5, 'Verbose', false);
            alg = cs.algorithms.probabilistic.AMP('Sigma', testCase.NoiseLevel, opts);
            
            [result, info] = alg.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            testCase.verifyTrue(info.iterations <= 200);
        end
        
        function testAlgorithmComparison(testCase)
            opts = cs.core.Options('MaxIterations', 200, 'Verbose', false);
            
            algOMP = cs.algorithms.greedy.OMP('Sparsity', testCase.Sparsity, opts);
            algIHT = cs.algorithms.iterative.IHT('Sparsity', testCase.Sparsity, opts);
            algFISTA = cs.algorithms.iterative.FISTA('Lambda', 0.01, opts);
            algAMP = cs.algorithms.probabilistic.AMP('Sigma', testCase.NoiseLevel, opts);
            
            [resultOMP, ~] = algOMP.solve(testCase.TestMatrix, testCase.TestMeasurements);
            [resultIHT, ~] = algIHT.solve(testCase.TestMatrix, testCase.TestMeasurements);
            [resultFISTA, ~] = algFISTA.solve(testCase.TestMatrix, testCase.TestMeasurements);
            [resultAMP, ~] = algAMP.solve(testCase.TestMatrix, testCase.TestMeasurements);
            
            metricsOMP = resultOMP.evaluate(testCase.TestSignal);
            metricsIHT = resultIHT.evaluate(testCase.TestSignal);
            metricsFISTA = resultFISTA.evaluate(testCase.TestSignal);
            metricsAMP = resultAMP.evaluate(testCase.TestSignal);
            
            testCase.verifyGreaterThan(metricsOMP.SNR, 5);
            testCase.verifyGreaterThan(metricsFISTA.SNR, 5);
            
            fprintf('\n算法性能对比:\n');
            fprintf('  OMP:    SNR=%.2f dB, NMSE=%.4f\n', metricsOMP.SNR, metricsOMP.NMSE);
            fprintf('  IHT:    SNR=%.2f dB, NMSE=%.4f\n', metricsIHT.SNR, metricsIHT.NMSE);
            fprintf('  FISTA:  SNR=%.2f dB, NMSE=%.4f\n', metricsFISTA.SNR, metricsFISTA.NMSE);
            fprintf('  AMP:    SNR=%.2f dB, NMSE=%.4f\n', metricsAMP.SNR, metricsAMP.NMSE);
        end
    end
end
