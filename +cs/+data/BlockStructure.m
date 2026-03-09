classdef BlockStructure
    % BlockStructure 块稀疏结构定义
    % 用于BSBL等块稀疏算法的块信息管理
    
    properties
        BlockStarts
        BlockLengths
        NumBlocks
        TotalLength
    end
    
    properties (Access = private)
        pBlockIndices
        pCorrelationType
        pDefaultRho
    end
    
    properties (Dependent)
        MeanBlockLength
        BlockIndices
        CorrelationType
    end
    
    properties (Constant)
        CORR_TYPES = struct(...
            'AR1', 'AR(1)', ...
            'TOEPLITZ', 'Toeplitz', ...
            'IDENTITY', 'Identity', ...
            'CUSTOM', 'Custom')
    end
    
    methods
        function obj = BlockStructure(blockStarts, blockLengths)
            if nargin < 1
                obj.BlockStarts = [];
                obj.BlockLengths = [];
                obj.NumBlocks = 0;
                obj.TotalLength = 0;
                obj.pCorrelationType = obj.CORR_TYPES.AR1;
                obj.pDefaultRho = 0.9;
                return;
            end
            
            obj.BlockStarts = blockStarts(:)';
            
            if nargin >= 2 && ~isempty(blockLengths)
                obj.BlockLengths = blockLengths(:)';
            else
                obj.BlockLengths = obj.inferBlockLengths(blockStarts);
            end
            
            obj.NumBlocks = length(obj.BlockStarts);
            obj.TotalLength = max(obj.BlockStarts + obj.BlockLengths - 1);
            obj.pCorrelationType = obj.CORR_TYPES.AR1;
            obj.pDefaultRho = 0.9;
            
            obj.pBlockIndices = cell(obj.NumBlocks, 1);
            for i = 1:obj.NumBlocks
                obj.pBlockIndices{i} = obj.getBlockIndices(i);
            end
        end
        
        function lens = inferBlockLengths(obj, starts)
            n = length(starts);
            lens = zeros(1, n);
            
            for i = 1:n-1
                lens(i) = starts(i+1) - starts(i);
            end
            
            if n == 1
                lens(1) = 1;
            end
        end
        
        function ml = get.MeanBlockLength(obj)
            if obj.NumBlocks > 0
                ml = mean(obj.BlockLengths);
            else
                ml = 0;
            end
        end
        
        function idx = get.BlockIndices(obj)
            idx = obj.pBlockIndices;
        end
        
        function ct = get.CorrelationType(obj)
            ct = obj.pCorrelationType;
        end
        
        function obj = setCorrelationType(obj, type)
            validTypes = {obj.CORR_TYPES.AR1, obj.CORR_TYPES.TOEPLITZ, ...
                         obj.CORR_TYPES.IDENTITY, obj.CORR_TYPES.CUSTOM};
            if ~any(strcmp(type, validTypes))
                error('cs.exceptions.InvalidInputException', ...
                    'Invalid correlation type: %s', type);
            end
            obj.pCorrelationType = type;
        end
        
        function indices = getBlockIndices(obj, blockIdx)
            if blockIdx < 1 || blockIdx > obj.NumBlocks
                error('cs.exceptions.IndexOutOfBoundsException', ...
                    'Block index %d out of range [1, %d]', blockIdx, obj.NumBlocks);
            end
            
            start = obj.BlockStarts(blockIdx);
            len = obj.BlockLengths(blockIdx);
            indices = start:(start + len - 1);
        end
        
        function blockIdx = findBlock(obj, elementIdx)
            blockIdx = 0;
            for i = 1:obj.NumBlocks
                if elementIdx >= obj.BlockStarts(i) && ...
                   elementIdx < obj.BlockStarts(i) + obj.BlockLengths(i)
                    blockIdx = i;
                    return;
                end
            end
        end
        
        function B = generateCorrelationMatrix(obj, blockIdx, rho)
            if nargin < 3
                rho = obj.pDefaultRho;
            end
            
            if blockIdx < 1 || blockIdx > obj.NumBlocks
                error('cs.exceptions.IndexOutOfBoundsException', ...
                    'Block index out of range');
            end
            
            len = obj.BlockLengths(blockIdx);
            
            switch obj.pCorrelationType
                case obj.CORR_TYPES.AR1
                    B = toeplitz(rho.^(0:len-1));
                    
                case obj.CORR_TYPES.TOEPLITZ
                    B = toeplitz(exp(-((0:len-1)').^2 / (2*len^2)));
                    
                case obj.CORR_TYPES.IDENTITY
                    B = eye(len);
                    
                otherwise
                    B = eye(len);
            end
        end
        
        function B = generateAllCorrelationMatrices(obj, rho)
            if nargin < 2
                rho = obj.pDefaultRho;
            end
            
            B = cell(obj.NumBlocks, 1);
            for i = 1:obj.NumBlocks
                B{i} = obj.generateCorrelationMatrix(i, rho);
            end
        end
        
        function mask = createBlockMask(obj)
            mask = zeros(obj.TotalLength, obj.NumBlocks);
            for i = 1:obj.NumBlocks
                idx = obj.getBlockIndices(i);
                mask(idx, i) = 1;
            end
        end
        
        function display(obj)
            fprintf('  cs.data.BlockStructure:\n');
            fprintf('    Total Length:   %d\n', obj.TotalLength);
            fprintf('    Num Blocks:     %d\n', obj.NumBlocks);
            fprintf('    Mean Block Len: %.1f\n', obj.MeanBlockLength);
            fprintf('    Corr Type:      %s\n', obj.pCorrelationType);
            
            if obj.NumBlocks <= 10
                fprintf('    Block Info:\n');
                for i = 1:obj.NumBlocks
                    fprintf('      Block %d: [%d, %d] (len=%d)\n', i, ...
                        obj.BlockStarts(i), ...
                        obj.BlockStarts(i) + obj.BlockLengths(i) - 1, ...
                        obj.BlockLengths(i));
                end
            else
                fprintf('    Block Info: (showing first 5)\n');
                for i = 1:5
                    fprintf('      Block %d: [%d, %d] (len=%d)\n', i, ...
                        obj.BlockStarts(i), ...
                        obj.BlockStarts(i) + obj.BlockLengths(i) - 1, ...
                        obj.BlockLengths(i));
                end
                fprintf('      ... (%d more blocks)\n', obj.NumBlocks - 5);
            end
        end
        
        function s = toStruct(obj)
            s.BlockStarts = obj.BlockStarts;
            s.BlockLengths = obj.BlockLengths;
            s.NumBlocks = obj.NumBlocks;
            s.TotalLength = obj.TotalLength;
            s.CorrelationType = obj.pCorrelationType;
        end
    end
    
    methods (Static)
        function obj = equalBlock(totalLength, blockLength)
            numBlocks = ceil(totalLength / blockLength);
            starts = zeros(1, numBlocks);
            lengths = zeros(1, numBlocks);
            
            for i = 1:numBlocks
                starts(i) = (i-1) * blockLength + 1;
                if i == numBlocks
                    lengths(i) = totalLength - (i-1) * blockLength;
                else
                    lengths(i) = blockLength;
                end
            end
            
            obj = cs.data.BlockStructure(starts, lengths);
        end
        
        function obj = fromSupport(support, minLength)
            if nargin < 2
                minLength = 1;
            end
            
            if isempty(support)
                obj = cs.data.BlockStructure();
                return;
            end
            
            support = sort(support(:));
            diffs = diff(support);
            blockBoundaries = [0; find(diffs > 1); length(support)];
            
            numBlocks = length(blockBoundaries) - 1;
            starts = zeros(1, numBlocks);
            lengths = zeros(1, numBlocks);
            
            for i = 1:numBlocks
                blockElements = support(blockBoundaries(i)+1:blockBoundaries(i+1));
                starts(i) = blockElements(1);
                lengths(i) = blockElements(end) - blockElements(1) + 1;
            end
            
            obj = cs.data.BlockStructure(starts, lengths);
        end
        
        function obj = fromStruct(s)
            obj = cs.data.BlockStructure(s.BlockStarts, s.BlockLengths);
            if isfield(s, 'CorrelationType')
                obj.setCorrelationType(s.CorrelationType);
            end
        end
    end
end
