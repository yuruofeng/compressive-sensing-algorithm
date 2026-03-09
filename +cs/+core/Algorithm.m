classdef (Abstract) Algorithm < handle
    % Algorithm 算法抽象基类
    % 所有压缩感知算法的统一接口定义
    
    properties (Access = protected)
        pOptions       % cs.core.Options 配置对象
        pIsFitted      % 是否已完成拟合
        pIterCount     % 当前迭代次数
        pConverged     % 收敛标志
        pElapsedTime   % 运行时间
    end
    
    properties (Dependent, SetAccess = protected)
        Options
        IsFitted
        IterationCount
        Converged
        ElapsedTime
    end
    
    properties (Constant)
        VERSION = '2.0.0'
    end
    
    events
        IterationComplete
        ConvergenceReached
        Error
    end
    
    methods
        function obj = Algorithm(varargin)
            if nargin > 0
                if isa(varargin{1}, 'cs.core.Options')
                    obj.pOptions = varargin{1};
                else
                    obj.pOptions = cs.core.Options(varargin{:});
                end
            else
                obj.pOptions = cs.core.Options();
            end
            obj.pIsFitted = false;
            obj.pIterCount = 0;
            obj.pConverged = false;
            obj.pElapsedTime = 0;
        end
        
        function set.Options(obj, value)
            obj.pOptions = obj.validateOptions(value);
        end
        
        function opts = get.Options(obj)
            opts = obj.pOptions;
        end
        
        function fitted = get.IsFitted(obj)
            fitted = obj.pIsFitted;
        end
        
        function count = get.IterationCount(obj)
            count = obj.pIterCount;
        end
        
        function conv = get.Converged(obj)
            conv = obj.pConverged;
        end
        
        function t = get.ElapsedTime(obj)
            t = obj.pElapsedTime;
        end
        
        function info = getAlgorithmInfo(obj)
            info.Name = obj.getAlgorithmName();
            info.Version = obj.getAlgorithmVersion();
            info.Reference = obj.getAlgorithmReference();
            info.Description = obj.getAlgorithmDescription();
        end
        
        function reset(obj)
            obj.pIsFitted = false;
            obj.pIterCount = 0;
            obj.pConverged = false;
            obj.pElapsedTime = 0;
        end
    end
    
    methods (Abstract)
        [result, info] = solve(obj, varargin)
    end
    
    methods (Abstract, Access = protected)
        name = getAlgorithmName(obj)
        version = getAlgorithmVersion(obj)
        reference = getAlgorithmReference(obj)
        validatedOpts = validateOptions(obj, opts)
    end
    
    methods (Access = protected)
        function desc = getAlgorithmDescription(obj)
            desc = '';
        end
        
        function logProgress(obj, iter, metrics)
            if obj.pOptions.Verbose
                if mod(iter, obj.pOptions.DisplayInterval) == 0 || iter == 1
                    fprintf('[%s] Iter %4d: Obj=%.6e, Res=%.6e, Support=%d\n', ...
                        obj.getAlgorithmName(), iter, ...
                        metrics.objective, metrics.residual, metrics.support_size);
                end
            end
        end
        
        function notifyIteration(obj, iter, metrics, x)
            notify(obj, 'IterationComplete');
            
            if ~isempty(obj.pOptions.Callback)
                try
                    obj.pOptions.Callback(iter, metrics, x);
                catch ME
                    warning('Algorithm:CallbackError', ...
                        'Callback function failed: %s', ME.message);
                end
            end
        end
        
        function [converged, metrics] = checkConvergence(obj, iter, ...
                currentObj, prevObj, residual, supportSize)
            metrics.objective = currentObj;
            metrics.residual = residual;
            metrics.support_size = supportSize;
            metrics.iteration = iter;
            
            if iter > 1 && prevObj ~= 0
                relChange = abs(currentObj - prevObj) / abs(prevObj);
                converged = relChange < obj.pOptions.Tolerance;
            else
                converged = false;
            end
            
            if converged
                notify(obj, 'ConvergenceReached');
            end
        end
        
        function assertValidInputs(obj, A, b)
            cs.utils.validation('validateMatrix', A, 'A');
            cs.utils.validation('validateVector', b, 'b');
            
            if isnumeric(A)
                if size(A, 1) ~= size(b, 1)
                    error('cs.exceptions.DimensionMismatchException', ...
                        'Dimension mismatch: A has %d rows but b has %d elements', ...
                        size(A, 1), size(b, 1));
                end
            end
        end
    end
    
    methods (Static)
        function algorithms = listAlgorithms()
            algorithms = {'BSBL_FM', 'BSBL_BO', 'TMSBL', 'MSBL', 'ARSBL', ...
                         'SPGL1', 'LassoADMM', 'BasisPursuit', 'MFOCUSS'};
        end
    end
end
