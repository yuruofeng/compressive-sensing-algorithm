classdef AlgorithmRegistry < handle
    % AlgorithmRegistry 算法注册中心
    % 
    % 提供统一的算法管理和注册机制，支持：
    %   - 算法元数据管理（名称、类别、参数、描述）
    %   - 算法实例化
    %   - 类别过滤
    %   - 批量操作
    %
    % 使用示例：
    %   registry = AlgorithmRegistry.getInstance();
    %   registry.registerAlgorithm('OMP', 'greedy', @cs.algorithms.greedy.OMP, ...
    %       'Description', '正交匹配追踪', 'DefaultParams', struct('Sparsity', 20));
    %   algorithms = registry.getAlgorithmsByCategory('greedy');
    %
    % 作者: 压缩感知算法库
    % 版本: 1.0
    
    properties (Access = private)
        pAlgorithms
        pCategories
    end
    
    properties (Constant)
        CATEGORIES = struct(...
            'greedy', '贪婪算法', ...
            'iterative', '迭代算法', ...
            'convex', '凸优化算法', ...
            'sbl', '稀疏贝叶斯学习', ...
            'probabilistic', '概率图模型');
    end
    
    methods (Access = private)
        function obj = AlgorithmRegistry()
            obj.pAlgorithms = struct();
            obj.pCategories = {};
            obj.registerDefaultAlgorithms();
        end
    end
    
    methods (Static)
        function instance = getInstance()
            persistent localInstance
            if isempty(localInstance) || ~isvalid(localInstance)
                localInstance = AlgorithmRegistry();
            end
            instance = localInstance;
        end
    end
    
    methods
        function registerAlgorithm(obj, name, category, constructor, varargin)
            % 注册算法
            %
            % 参数：
            %   name - 算法名称
            %   category - 算法类别
            %   constructor - 算法构造函数句柄
            %   varargin - 可选参数：Description, DefaultParams, Reference
            
            p = inputParser;
            addParameter(p, 'Description', '', @ischar);
            addParameter(p, 'DefaultParams', struct(), @isstruct);
            addParameter(p, 'Reference', '', @ischar);
            parse(p, varargin{:});
            
            obj.pAlgorithms.(name) = struct(...
                'Name', name, ...
                'Category', category, ...
                'Constructor', constructor, ...
                'Description', p.Results.Description, ...
                'DefaultParams', p.Results.DefaultParams, ...
                'Reference', p.Results.Reference);
            
            if ~ismember(category, obj.pCategories)
                obj.pCategories{end+1} = category;
            end
        end
        
        function algorithm = getAlgorithm(obj, name)
            % 获取算法元数据
            if isfield(obj.pAlgorithms, name)
                algorithm = obj.pAlgorithms.(name);
            else
                error('AlgorithmRegistry:NotFound', '算法 "%s" 未注册', name);
            end
        end
        
        function instance = createInstance(obj, name, varargin)
            % 创建算法实例
            meta = obj.getAlgorithm(name);
            
            opts = cs.core.Options();
            params = meta.DefaultParams;
            
            for i = 1:length(varargin)
                if isa(varargin{i}, 'cs.core.Options')
                    opts = varargin{i};
                elseif isstruct(varargin{i})
                    params = varargin{i};
                end
            end
            
            args = {opts};
            fields = fieldnames(params);
            for i = 1:length(fields)
                args{end+1} = fields{i};
                args{end+1} = params.(fields{i});
            end
            
            instance = meta.Constructor(args{:});
        end
        
        function algorithms = getAlgorithmsByCategory(obj, category)
            % 按类别获取算法列表
            algorithms = {};
            names = fieldnames(obj.pAlgorithms);
            for i = 1:length(names)
                if strcmp(obj.pAlgorithms.(names{i}).Category, category)
                    algorithms{end+1} = obj.pAlgorithms.(names{i});
                end
            end
        end
        
        function names = getAllAlgorithmNames(obj)
            % 获取所有算法名称
            names = fieldnames(obj.pAlgorithms);
        end
        
        function categories = getAllCategories(obj)
            % 获取所有类别
            categories = obj.pCategories;
        end
        
        function displayAlgorithms(obj, category)
            % 显示算法列表
            if nargin < 2
                category = '';
            end
            
            fprintf('\n========================================\n');
            fprintf('  已注册算法列表\n');
            fprintf('========================================\n\n');
            
            if isempty(category)
                categories = obj.getAllCategories();
                for i = 1:length(categories)
                    cat = categories{i};
                    fprintf('[%s] %s\n', cat, obj.CATEGORIES.(cat));
                    algorithms = obj.getAlgorithmsByCategory(cat);
                    for j = 1:length(algorithms)
                        alg = algorithms{j};
                        fprintf('  - %s: %s\n', alg.Name, alg.Description);
                    end
                    fprintf('\n');
                end
            else
                algorithms = obj.getAlgorithmsByCategory(category);
                fprintf('[%s] %s\n', category, obj.CATEGORIES.(category));
                for i = 1:length(algorithms)
                    alg = algorithms{i};
                    fprintf('  - %s: %s\n', alg.Name, alg.Description);
                end
            end
        end
    end
    
    methods (Access = private)
        function registerDefaultAlgorithms(obj)
            % 注册默认算法集
            
            % 贪婪算法
            obj.registerAlgorithm('OMP', 'greedy', @cs.algorithms.greedy.OMP, ...
                'Description', '正交匹配追踪', ...
                'DefaultParams', struct('Sparsity', 20), ...
                'Reference', 'J. A. Tropp and A. C. Gilbert, IEEE Trans. Inf. Theory, 2007');
            
            obj.registerAlgorithm('MFOCUSS', 'greedy', @cs.algorithms.greedy.MFOCUSS, ...
                'Description', '多测量向量FOCUSS算法', ...
                'DefaultParams', struct('P', 0.8, 'Lambda', 1e-3));
            
            % 迭代算法
            obj.registerAlgorithm('IHT', 'iterative', @cs.algorithms.iterative.IHT, ...
                'Description', '迭代硬阈值算法', ...
                'DefaultParams', struct('Sparsity', 20), ...
                'Reference', 'T. Blumensath and M. E. Davies, Appl. Comput. Harmonic Anal., 2009');
            
            obj.registerAlgorithm('FISTA', 'iterative', @cs.algorithms.iterative.FISTA, ...
                'Description', '快速迭代软阈值算法', ...
                'DefaultParams', struct('Lambda', 0.01), ...
                'Reference', 'A. Beck and M. Teboulle, SIAM J. Imaging Sci., 2009');
            
            % 凸优化算法
            obj.registerAlgorithm('BasisPursuit', 'convex', @cs.algorithms.convex.BasisPursuit, ...
                'Description', '基追踪算法', ...
                'DefaultParams', struct('Tolerance', 1e-6));
            
            obj.registerAlgorithm('LassoADMM', 'convex', @cs.algorithms.convex.LassoADMM, ...
                'Description', 'LASSO-ADMM算法', ...
                'DefaultParams', struct('Lambda', 0.01));
            
            % 稀疏贝叶斯学习
            obj.registerAlgorithm('BSBL', 'sbl', @cs.algorithms.sbl.BSBL, ...
                'Description', '块稀疏贝叶斯学习', ...
                'DefaultParams', struct('Lambda', 1e-3));
            
            obj.registerAlgorithm('BCS', 'sbl', @cs.algorithms.sbl.BCS, ...
                'Description', '贝叶斯压缩感知', ...
                'DefaultParams', struct(), ...
                'Reference', 'S. Ji, Y. Xue, and L. Carin, IEEE Trans. Signal Processing, 2008');
            
            obj.registerAlgorithm('MSBL', 'sbl', @cs.algorithms.sbl.MSBL, ...
                'Description', '多测量向量稀疏贝叶斯学习', ...
                'DefaultParams', struct());
            
            obj.registerAlgorithm('TMSBL', 'sbl', @cs.algorithms.sbl.TMSBL, ...
                'Description', '时序多测量向量稀疏贝叶斯学习', ...
                'DefaultParams', struct());
            
            % 概率图模型
            obj.registerAlgorithm('AMP', 'probabilistic', @cs.algorithms.probabilistic.AMP, ...
                'Description', '近似消息传递算法', ...
                'DefaultParams', struct('Sigma', 0.01), ...
                'Reference', 'D. L. Donoho, A. Maleki, and A. Montanari, Proc. Natl. Acad. Sci., 2009');
        end
    end
end
