function [nii_hdr,nii_binaryh,nii_gz_bool,nii_fid]=load_niigz_hdr(nii_path)
% Read a nifti header gzipped or not using native matlab gzip routines. 
nii_gz_bool=0;
%% header only read.
if strcmp(nii_path(end-1:end),'gz')
    d=gunzip_load(nii_path,{{352,'uint8','bhdr'}},352);
    nii_binaryh=d.bhdr;
    nii_gz_bool=1;
    nii_fid=-1;
else
    nii_fid=fopen(nii_path);
    if nii_fid<=0
        error('Failed to open nifti images');
    end
    nii_data = fread(nii_fid,352,'uint8=>uint8',0,'l');
    nii_binaryh = nii_data;
end
%% set endian
if typecast(nii_binaryh(1:4),'int32') == 348
    nii_endian='l';
elseif  typecast(nii_binaryh(4:-1:1),'int32') == 348
    nii_endian='b';
    db_inplace(mfilename,'DID NOT HANDLE Big endian data!');
else
    db_inplace(mfilename,'ERROR in decompression!');
end
%% convert binary header to hdr struct
nii_hdr=nii_hdr_bin_to_struct(nii_binaryh);