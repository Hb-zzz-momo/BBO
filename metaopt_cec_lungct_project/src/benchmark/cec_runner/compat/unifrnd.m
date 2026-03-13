function r = unifrnd(a, b, varargin)
% Toolbox-free fallback for uniform random sampling.
% Supports scalar/vector bounds with optional output size.

    if nargin < 2
        error('unifrnd requires at least two inputs: a, b.');
    end

    if isempty(varargin)
        r = a + (b - a) .* rand(size(a));
    else
        r = a + (b - a) .* rand(varargin{:});
    end
end
