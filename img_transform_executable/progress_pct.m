function progress_pct(op,operations)
% dumb progress printer called after progress_init which displays 0%
% progress, this updates that with what op of operations you've done.
fprintf('\b\b\b\b\b\b\b\b\b\b\b%06.3f/100\n',100*op/operations);
    