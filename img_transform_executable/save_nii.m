%  Save NIFTI dataset. Support both *.nii and *.hdr/*.img file extension.
%  If file extension is not provided, *.hdr/*.img will be used as default.
%  
%  Usage: save_nii(nii, filename, [old_RGB])
%  
%  nii.hdr - struct with NIFTI header fields (from load_nii.m or make_nii.m)
%
%  nii.img - 3D (or 4D) matrix of NIFTI data.
%
%  filename - NIFTI file name.
%
%  old_RGB    - an optional boolean variable to handle special RGB data 
%       sequence [R1 R2 ... G1 G2 ... B1 B2 ...] that is used only by 
%       AnalyzeDirect (Analyze Software). Since both NIfTI and Analyze
%       file format use RGB triple [R1 G1 B1 R2 G2 B2 ...] sequentially
%       for each voxel, this variable is set to FALSE by default. If you
%       would like the saved image only to be opened by AnalyzeDirect 
%       Software, set old_RGB to TRUE (or 1). It will be set to 0, if it
%       is default or empty.
%  
%  Tip: to change the data type, set nii.hdr.dime.datatype,
%	and nii.hdr.dime.bitpix to:
% 
%     0 None                     (Unknown bit per voxel) % DT_NONE, DT_UNKNOWN 
%     1 Binary                         (ubit1, bitpix=1) % DT_BINARY 
%     2 Unsigned char         (uchar or uint8, bitpix=8) % DT_UINT8, NIFTI_TYPE_UINT8 
%     4 Signed short                  (int16, bitpix=16) % DT_INT16, NIFTI_TYPE_INT16 
%     8 Signed integer                (int32, bitpix=32) % DT_INT32, NIFTI_TYPE_INT32 
%    16 Floating point    (single or float32, bitpix=32) % DT_FLOAT32, NIFTI_TYPE_FLOAT32 
%    32 Complex, 2 float32      (Use float32, bitpix=64) % DT_COMPLEX64, NIFTI_TYPE_COMPLEX64
%    64 Double precision  (double or float64, bitpix=64) % DT_FLOAT64, NIFTI_TYPE_FLOAT64 
%   128 uint RGB                  (Use uint8, bitpix=24) % DT_RGB24, NIFTI_TYPE_RGB24 
%   256 Signed char            (schar or int8, bitpix=8) % DT_INT8, NIFTI_TYPE_INT8 
%   511 Single RGB              (Use float32, bitpix=96) % DT_RGB96, NIFTI_TYPE_RGB96
%   512 Unsigned short               (uint16, bitpix=16) % DT_UNINT16, NIFTI_TYPE_UNINT16 
%   768 Unsigned integer             (uint32, bitpix=32) % DT_UNINT32, NIFTI_TYPE_UNINT32 
%  1024 Signed long long              (int64, bitpix=64) % DT_INT64, NIFTI_TYPE_INT64
%  1280 Unsigned long long           (uint64, bitpix=64) % DT_UINT64, NIFTI_TYPE_UINT64 
%  1536 Long double, float128  (Unsupported, bitpix=128) % DT_FLOAT128, NIFTI_TYPE_FLOAT128 
%  1792 Complex128, 2 float64  (Use float64, bitpix=128) % DT_COMPLEX128, NIFTI_TYPE_COMPLEX128 
%  2048 Complex256, 2 float128 (Unsupported, bitpix=256) % DT_COMPLEX128, NIFTI_TYPE_COMPLEX128 
%  
%  Part of this file is copied and modified from:
%  http://www.mathworks.com/matlabcentral/fileexchange/1878-mri-analyze-tools
%
%  NIFTI data format can be found on: http://nifti.nimh.nih.gov
%
%  - Jimmy Shen (jimmy@rotman-baycrest.on.ca)
%  - "old_RGB" related codes in "save_nii.m" are added by Mike Harms (2006.06.28) 
%
function save_nii(nii, fileprefix, old_RGB)
   
   if ~exist('nii','var') | isempty(nii) | ~isfield(nii,'hdr') | ...
	~isfield(nii,'img') | ~exist('fileprefix','var') | isempty(fileprefix)

      error('Usage: save_nii(nii, filename, [old_RGB])');
   end

   if isfield(nii,'untouch') & nii.untouch == 1
      error('Usage: please use ''save_untouch_nii.m'' for the untouched structure.');
   end

   if ~exist('old_RGB','var') | isempty(old_RGB)
      old_RGB = 0;
   end

   v = version;

   %%  Check file extension for gz 
   % remove gz if its there and set gzFile flag.
   gzFile=0;
   if length(fileprefix) > 2 & strcmp(fileprefix(end-2:end), '.gz')
       if ~strcmp(fileprefix(end-6:end), '.img.gz') & ...
               ~strcmp(fileprefix(end-6:end), '.hdr.gz') & ...
               ~strcmp(fileprefix(end-6:end), '.nii.gz')
           error('Please check filename.');
       end
       if str2num(v(1:3)) < 7.1 | ~usejava('jvm')
           error('Please use MATLAB 7.1 (with java) and above, or run gunzip outside MATLAB.');
       else
           gzFile = 1;
           fileprefix = fileprefix(1:end-3);
       end
   end
   
   filetype = 1;
   %% remove extension from file and set file type. 
   % Note: fileprefix starts as the filename you want to save
   if findstr('.nii',fileprefix) & strcmp(fileprefix(end-3:end), '.nii')
      filetype = 2;
      fileprefix(end-3:end)='';
   end
   
   if findstr('.hdr',fileprefix) & strcmp(fileprefix(end-3:end), '.hdr')
      fileprefix(end-3:end)='';
   end
   
   if findstr('.img',fileprefix) & strcmp(fileprefix(end-3:end), '.img')
      fileprefix(end-3:end)='';
   end
   %% write data
   % originally write_nii was not aware you wanted gzipping. That has been
   % adjusted so we can use gzip_write and write direct to gzip.
   write_nii(nii, filetype, fileprefix, old_RGB, gzFile);

   %%  gzip output file if requested
   % and if not gzipped by integrated gzip code. 
   if gzFile
       nii_gzip_out(fileprefix,filetype);
   end;

   if filetype == 1
      % Never tested this code, dont really indend to, Best of luck :D !
      error('Now why would we support this :p'); 
      %  So earlier versions of SPM can also open it with correct originator
      %
      M=[[diag(nii.hdr.dime.pixdim(2:4)) -[nii.hdr.hist.originator(1:3).*nii.hdr.dime.pixdim(2:4)]'];[0 0 0 1]];
      save([fileprefix '.mat'], 'M');
   end
   
   return					% save_nii

