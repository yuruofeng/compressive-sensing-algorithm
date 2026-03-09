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
    end
end
