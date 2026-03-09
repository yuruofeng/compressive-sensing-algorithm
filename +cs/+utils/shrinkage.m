function y = shrinkage(x, lambda, varargin)
    % shrinkage 软阈值算子
    % y = shrinkage(x, lambda) 对x应用软阈值
    % y = shrinkage(x, lambda, 'Method', method) 指定阈值方法
    %
    % 输入:
    %   x      - 输入信号
    %   lambda - 阈值参数
    % 可选参数:
    %   Method - 'soft'(默认), 'hard', 'firm', 'half'
    %
    % 输出:
    %   y - 阈值处理后的信号
    
    p = inputParser;
    addParameter(p, 'Method', 'soft', @ischar);
    parse(p, varargin{:});
    
    method = lower(p.Results.Method);
    
    validateattributes(x, {'numeric'}, {});
    validateattributes(lambda, {'numeric'}, {'scalar', 'nonnegative'});
    
    switch method
        case 'soft'
            y = sign(x) .* max(abs(x) - lambda, 0);
            
        case 'hard'
            y = x;
            y(abs(x) < lambda) = 0;
            
        case 'firm'
            mu = 2 * lambda;
            y = zeros(size(x));
            mask1 = abs(x) < lambda;
            mask2 = abs(x) >= lambda & abs(x) < mu;
            mask3 = abs(x) >= mu;
            
            y(mask1) = 0;
            y(mask2) = x(mask2) .* (2 * sqrt(abs(x(mask2)) .* lambda) - lambda) ./ (mu - lambda);
            y(mask3) = x(mask3);
            
        case 'half'
            y = sign(x) .* (abs(x) - lambda + sqrt((abs(x) - lambda).^2 + lambda^2)) / 2;
            y(abs(x) <= lambda) = 0;
            
        otherwise
            error('cs.exceptions.InvalidInputException', ...
                'Unknown shrinkage method: %s', method);
    end
end
