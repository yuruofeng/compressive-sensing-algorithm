classdef DimensionMismatchException < cs.exceptions.CSException
    % DimensionMismatchException 维度不匹配异常
    
    methods
        function obj = DimensionMismatchException(msg, varargin)
            obj@cs.exceptions.CSException(cs.exceptions.CSException.ERROR_CODES.DIMENSION_MISMATCH, ...
                ['Dimension mismatch: ' msg], varargin{:});
            obj = obj.addSuggestion('Check matrix and vector dimensions');
        end
    end
    
    methods (Static)
        function throwMatrixVector(Aname, Arows, Acols, bname, blen)
            ex = cs.exceptions.DimensionMismatchException(...
                sprintf('%s (%dx%d) incompatible with %s (length %d)', ...
                Aname, Arows, Acols, bname, blen));
            ex = ex.addContext('MatrixName', Aname);
            ex = ex.addContext('MatrixSize', [Arows, Acols]);
            ex = ex.addContext('VectorName', bname);
            ex = ex.addContext('VectorLength', blen);
            throw(ex);
        end
        
        function throwMatrixMatrix(Aname, Asize, Bname, Bsize)
            ex = cs.exceptions.DimensionMismatchException(...
                sprintf('%s (%dx%d) incompatible with %s (%dx%d)', ...
                Aname, Asize(1), Asize(2), Bname, Bsize(1), Bsize(2)));
            ex = ex.addContext('Matrix1Name', Aname);
            ex = ex.addContext('Matrix1Size', Asize);
            ex = ex.addContext('Matrix2Name', Bname);
            ex = ex.addContext('Matrix2Size', Bsize);
            throw(ex);
        end
    end
end
