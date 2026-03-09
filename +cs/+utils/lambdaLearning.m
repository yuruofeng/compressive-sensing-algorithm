function [x, info] = lambdaLearning(matrixA, observations, currentEstimate, currentLambda, varargin)
    % lambdaLearning Lambda参数自适应学习
    % [newLambda, info] = lambdaLearning(matrixA, observations, currentEstimate, currentLambda, ...)
    %
    % 输入:
    %   matrixA        - 感知矩阵 (numMeasurements x signalLength)
    %   observations   - 观测向量 (numMeasurements x 1)
    %   currentEstimate- 当前估计 (signalLength x 1)
    %   currentLambda  - 当前Lambda值
    %
    % 可选参数:
    %   Method       - 学习方法: 'noise'/'mm'/'empirical'(默认)
    %   MinLambda    - 最小Lambda值 (默认1e-8)
    %   MaxLambda    - 最大Lambda值 (默认1e2)
    %   NoiseVariance- 噪声方差(如已知)
    %
    % 输出:
    %   newLambda - 更新后的Lambda
    %   info      - 更新信息结构体
    
    paramParser = inputParser;
    addParameter(paramParser, 'Method', 'noise', @ischar);
    addParameter(paramParser, 'MinLambda', 1e-8, @isnumeric);
    addParameter(paramParser, 'MaxLambda', 1e2, @isnumeric);
    addParameter(paramParser, 'NoiseVariance', [], @isnumeric);
    addParameter(paramParser, 'SupportThreshold', 1e-4, @isnumeric);
    parse(paramParser, varargin{:});
    
    info = struct();
    info.Method = paramParser.Results.Method;
    info.PreviousLambda = currentLambda;
    
    residualVec = observations - matrixA * currentEstimate;
    supportMask = abs(currentEstimate) > paramParser.Results.SupportThreshold;
    supportSize = nnz(supportMask);
    numMeasurements = size(matrixA, 1);
    signalLength = size(matrixA, 1);
    
    switch lower(paramParser.Results.Method)
        case 'noise'
            if isempty(paramParser.Results.NoiseVariance)
                noiseVariance = (norm(residualVec)^2) / max(1, numMeasurements - supportSize);
            else
                noiseVariance = paramParser.Results.NoiseVariance;
            end
            newLambda = sqrt(noiseVariance);
            
        case 'mm'
            newLambda = (1 / max(1, supportSize)) * sum(abs(currentEstimate(supportMask)));
            
        case 'empirical'
            if supportSize > 0
                newLambda = norm(residualVec) / sqrt(numMeasurements) * sqrt(log(signalLength) / numMeasurements);
            else
                newLambda = currentLambda * 1.1;
            end
            
        case 'fixed'
            newLambda = currentLambda;
            
        otherwise
            newLambda = currentLambda;
    end
    
    newLambda = max(paramParser.Results.MinLambda, min(paramParser.Results.MaxLambda, newLambda));
    
    info.NewLambda = newLambda;
    info.SupportSize = supportSize;
    info.ResidualNorm = norm(residualVec);
    info.NoiseVarianceEstimate = isempty(paramParser.Results.NoiseVariance);
end
