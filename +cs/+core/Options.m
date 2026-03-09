classdef Options < matlab.mixin.CustomDisplay
    % Options 统一配置基类
    % 提供所有算法的通用参数配置与验证机制
    
    properties
        Tolerance = 1e-8
        MaxIterations = 1000
        Lambda = 1e-3
        LearnLambda = true
        Verbose = false
        DisplayInterval = 10
    end
    
    properties (Access = private)
        pCallback = []
        pUserData = []
        pPresetName = ''
    end
    
    properties (Dependent)
        Callback
        UserData
        PresetName
    end
    
    properties (Constant)
        AVAILABLE_PRESETS = {'default', 'fast', 'precise', 'noiseless', 'lowSNR', 'highSNR'}
    end
    
    methods
        function obj = Options(varargin)
            obj = obj.loadDefaults();
            if nargin > 0
                obj = obj.parseInputs(varargin{:});
            end
        end
        
        function obj = loadDefaults(obj)
            obj.Tolerance = 1e-8;
            obj.MaxIterations = 1000;
            obj.Lambda = 1e-3;
            obj.LearnLambda = true;
            obj.Verbose = false;
            obj.DisplayInterval = 10;
        end
        
        function obj = parseInputs(obj, varargin)
            if nargin == 1 && isa(varargin{1}, 'struct')
                fields = fieldnames(varargin{1});
                for i = 1:length(fields)
                    obj.(fields{i}) = varargin{1}.(fields{i});
                end
            elseif mod(length(varargin), 2) == 0
                for i = 1:2:length(varargin)
                    name = varargin{i};
                    if strncmp(name, '-', 1)
                        name = name(2:end);
                    end
                    if isprop(obj, name)
                        obj.(name) = varargin{i+1};
                    else
                        warning('Options:UnknownParameter', ...
                            'Unknown parameter: %s', name);
                    end
                end
            else
                error('Options:InvalidInput', ...
                    'Parameters must be name-value pairs or a struct');
            end
        end
        
        function obj = set.Tolerance(obj, val)
            validateattributes(val, {'numeric'}, ...
                {'scalar', 'positive', 'finite'});
            obj.Tolerance = val;
        end
        
        function obj = set.MaxIterations(obj, val)
            validateattributes(val, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            obj.MaxIterations = double(val);
        end
        
        function obj = set.Lambda(obj, val)
            validateattributes(val, {'numeric'}, ...
                {'scalar', 'nonnegative'});
            obj.Lambda = val;
        end
        
        function obj = set.LearnLambda(obj, val)
            validateattributes(val, {'logical', 'numeric'}, {'scalar'});
            obj.LearnLambda = logical(val);
        end
        
        function obj = set.Verbose(obj, val)
            validateattributes(val, {'logical', 'numeric'}, {'scalar'});
            obj.Verbose = logical(val);
        end
        
        function obj = set.DisplayInterval(obj, val)
            validateattributes(val, {'numeric'}, ...
                {'scalar', 'integer', 'positive'});
            obj.DisplayInterval = double(val);
        end
        
        function cb = get.Callback(obj)
            cb = obj.pCallback;
        end
        
        function obj = set.Callback(obj, val)
            if ~isempty(val)
                validateattributes(val, {'function_handle'}, {});
            end
            obj.pCallback = val;
        end
        
        function ud = get.UserData(obj)
            ud = obj.pUserData;
        end
        
        function obj = set.UserData(obj, val)
            obj.pUserData = val;
        end
        
        function name = get.PresetName(obj)
            name = obj.pPresetName;
        end
        
        function obj = loadPreset(obj, presetName)
            if ~any(strcmp(presetName, obj.AVAILABLE_PRESETS))
                error('Options:UnknownPreset', ...
                    'Unknown preset: %s. Available: %s', ...
                    presetName, strjoin(obj.AVAILABLE_PRESETS, ', '));
            end
            
            switch presetName
                case 'default'
                    obj = obj.loadDefaults();
                case 'fast'
                    obj.Tolerance = 1e-6;
                    obj.MaxIterations = 500;
                    obj.DisplayInterval = 50;
                case 'precise'
                    obj.Tolerance = 1e-10;
                    obj.MaxIterations = 5000;
                    obj.DisplayInterval = 100;
                case 'noiseless'
                    obj.Tolerance = 1e-10;
                    obj.Lambda = 1e-4;
                    obj.LearnLambda = false;
                case 'lowSNR'
                    obj.Tolerance = 1e-6;
                    obj.Lambda = 1e-2;
                    obj.LearnLambda = true;
                case 'highSNR'
                    obj.Tolerance = 1e-8;
                    obj.Lambda = 1e-4;
                    obj.LearnLambda = true;
            end
            
            obj.pPresetName = presetName;
        end
        
        function savePreset(obj, filename)
            if ~endsWith(filename, '.json')
                filename = [filename '.json'];
            end
            
            data = struct();
            props = properties(obj);
            for i = 1:length(props)
                if ~startsWith(props{i}, 'p') || strcmp(props{i}, 'pPresetName')
                    data.(props{i}) = obj.(props{i});
                end
            end
            
            jsonStr = jsonencode(data, 'PrettyPrint', true);
            fid = fopen(filename, 'w');
            fprintf(fid, '%s', jsonStr);
            fclose(fid);
        end
        
        function obj = loadFromFile(obj, filename)
            if ~endsWith(filename, '.json')
                filename = [filename '.json'];
            end
            
            fid = fopen(filename, 'r');
            jsonStr = fread(fid, '*char')';
            fclose(fid);
            
            data = jsondecode(jsonStr);
            fields = fieldnames(data);
            for i = 1:length(fields)
                if isprop(obj, fields{i})
                    obj.(fields{i}) = data.(fields{i});
                end
            end
        end
        
        function s = toStruct(obj)
            s = struct();
            props = {'Tolerance', 'MaxIterations', 'Lambda', ...
                    'LearnLambda', 'Verbose', 'DisplayInterval'};
            for i = 1:length(props)
                s.(props{i}) = obj.(props{i});
            end
        end
    end
    
    methods (Static)
        function obj = fromStruct(s)
            obj = cs.core.Options();
            fields = fieldnames(s);
            for i = 1:length(fields)
                if isprop(obj, fields{i})
                    obj.(fields{i}) = s.(fields{i});
                end
            end
        end
        
        function obj = quick(preset)
            if nargin < 1
                preset = 'default';
            end
            obj = cs.core.Options();
            obj = obj.loadPreset(preset);
        end
    end
end
