function y = normr(x)
%NORMR Normalize matrix rows to unit Euclidean norm.
% Minimal local compatibility shim for legacy third-party optimizers.

    row_norms = sqrt(sum(x.^2, 2));
    row_norms(row_norms == 0) = 1;
    y = x ./ row_norms;
end
