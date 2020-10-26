function nii_gzip_out(fileprefix,filetype)
%% check if we gzipped on save before we try to gzip post.
if filetype == 1
    ext={'.img','.hdr'};
elseif filetype == 2
    ext={'.nii'};
end
for i_e=1:numel(ext)
    if ~exist([fileprefix ext{i_e} '.gz'],'file')
        warning('Post write gzipping is slow and inefficient! You''d be better off not bothering.');
        gzip([fileprefix ext{i_e}]);
        delete([fileprefix ext{i_e}]);
    end
end
%{
       %% prev code before integrated gzipping.
       if filetype == 1
           gzip([fileprefix, '.img']);
           delete([fileprefix, '.img']);
           gzip([fileprefix, '.hdr']);
           delete([fileprefix, '.hdr']);
       elseif filetype == 2
           gzip([fileprefix, '.nii']);
           delete([fileprefix, '.nii']);
       end;
%}