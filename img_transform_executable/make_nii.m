%  Make NIfTI structure specified by an N-D matrix. Usually, N is 3 for 
%  3D matrix [x y z], or 4 for 4D matrix with time series [x y z t]. 
%  Optional parameters can also be included, such as: voxel_size, 
%  origin, datatype, and description. 
%  
%  Once the NIfTI structure is made, it can be saved into NIfTI file 
%  using "save_nii" command (for more detail, type: help save_nii). 
%  
%  Usage: nii = make_nii(img, [voxel_size], [origin], [datatype], [description], [header_only])
%
%  Where:
%
%	img:		Usually, img is a 3D matrix [x y z], or a 4D
%			matrix with time series [x y z t]. However,
%			NIfTI allows a maximum of 7D matrix. When the
%			image is in RGB format, make sure that the size
%			of 4th dimension is always 3 (i.e. [R G B]). In
%			that case, make sure that you must specify RGB
%			datatype, which is either 128 or 511.
%
%	voxel_size (optional):	Voxel size in millimeter for each
%				dimension. Default is [1 1 1].
%
%	origin (optional):	The AC origin. Default is [0 0 0].
%
%	datatype (optional):	Storage data type:
%		2 - uint8,  4 - int16,  8 - int32,  16 - float32,
%		32 - complex64,  64 - float64,  128 - RGB24,
%		256 - int8,  511 - RGB96,  512 - uint16,
%		768 - uint32,  1792 - complex128
%			Default will use the data type of 'img' matrix
%			For RGB image, you must specify it to either 128
%			or 511.
%
%	description (optional):	Description of data. Default is ''.
%
%  e.g.:
%     origin = [33 44 13]; datatype = 64;
%     nii = make_nii(img, [], origin, datatype);    % default voxel_size
%
%  NIFTI data format can be found on: http://nifti.nimh.nih.gov
%
%  - Jimmy Shen (jimmy@rotman-baycrest.on.ca)
%
function nii = make_nii(varargin)
   %varg_offset=0; % before fixing the whole function, just use this to the index.
   % {
   nii.img = varargin{1}; % this immediately duplicates the data.... How Sloppy!
   % in testing, that behavior is intermittent.... wtf mates?
   varg_offset=0;
   %}
   %{
   img=varargin{1};
   nii.img=img;
   %}
   dims = size(nii.img);
   %dims = size(varagin{1});
   dims = [length(dims) dims ones(1,8)];
   dims = dims(1:8);

   voxel_size = [0 ones(1,7)];
   origin = zeros(1,5);
   descrip = '';

   switch class(nii.img)
      case 'uint8'
         datatype = 2;
      case 'int16'
         datatype = 4;
      case 'int32'
         datatype = 8;
      case 'single'
         if isreal(nii.img)
            datatype = 16;
         else
            datatype = 32;
         end
      case 'double'
         if isreal(nii.img)
            datatype = 64;
         else
            datatype = 1792;
         end
      case 'int8'
         datatype = 256;
      case 'uint16'
         datatype = 512;
      case 'uint32'
         datatype = 768;
      otherwise
         error('Datatype is not supported by make_nii.');
   end

   if nargin > 1 && ~isempty(varargin{varg_offset+2})
      voxel_size(2:4) = double(varargin{varg_offset+2});
   end

   if nargin > 2 && ~isempty(varargin{varg_offset+3})
      origin(1:3) = double(varargin{varg_offset+3});
   end

   if nargin > 3 && ~isempty(varargin{varg_offset+4})
      datatype = double(varargin{varg_offset+4});

      if datatype == 128 || datatype == 511
         dims(5) = [];
         dims(1) = dims(1) - 1;
         dims = [dims 1];
      end
   end

   if nargin > 4 && ~isempty(varargin{varg_offset+5})
      descrip = varargin{varg_offset+5};
   end
   if nargin >= 6  && ~isempty(varargin{varg_offset+6})
      hdr_only = varargin{varg_offset+6};
      if ischar(hdr_only)
          hdr_only=str2num(hdr_only);
      end
   else
       hdr_only=0;
   end

   if ndims(nii.img) > 7
      error('NIfTI only allows a maximum of 7 Dimension matrix.');
   end
   %{
   % Very unclear what the purpose of forcing double and then rounding here
   is. vectorization here causes a memory surge... Not sure if its
   avoidable. Attempting to mitigate by putting the rounded(double maxval)
   later.
   % Moved cal max later in process to isolate memory things.
   maxval = round(double(max(nii.img(:))));
   minval = round(double(min(nii.img(:))));
   %}
   nii.hdr = make_header(dims, voxel_size, origin, datatype, ...
	descrip, inf, -inf);
   if hdr_only
       nii.img=[];
       return;
   end

   switch nii.hdr.dime.datatype
   case 2
      if ~isa(nii.img,'uint8')
      nii.img = uint8(nii.img);
      end
   case 4
      if ~isa(nii.img,'int16')
      nii.img = int16(nii.img);
      end
   case 8
      if ~isa(nii.img,'int32')
      nii.img = int32(nii.img);
      end
   case 16
      if ~isa(nii.img,'single')
      nii.img = single(nii.img);
      end
   case 32
      if ~isa(nii.img,'single')
      nii.img = single(nii.img);
      end
   case 64
      if ~isa(nii.img,'double')
      nii.img = double(nii.img);
      end
   case 128
      if ~isa(nii.img,'uint8')
      nii.img = uint8(nii.img);
      end
   case 256
      if ~isa(nii.img,'int8')
      nii.img = int8(nii.img);
      end
   case 511
      img = double(nii.img(:));
      img = single((img - min(img))/(max(img) - min(img)));
      nii.img = reshape(img, size(nii.img));
      nii.hdr.dime.glmax = double(max(img));
      nii.hdr.dime.glmin = double(min(img));
   case 512
      if ~isa(nii.img,'uint16')
      nii.img = uint16(nii.img);
      end
   case 768
      if ~isa(nii.img,'uint32')
      nii.img = uint32(nii.img);
      end
   case 1792
      if ~isa(nii.img,'double')
      nii.img = double(nii.img);
      end
   otherwise
      error('Datatype is not supported by make_nii.');
   end
   
   % {
   if isinf(nii.hdr.dime.glmin)
       minval = min(nii.img(:));
       nii.hdr.dime.glmin = round(double(minval));% this looks like such wasted effort to me...
   end
   if isinf(nii.hdr.dime.glmax)
       maxval = max(nii.img(:));
       nii.hdr.dime.glmax = round(double(maxval));% this looks like such wasted effort to me...
   end
   %}   

   return;					% make_nii


%---------------------------------------------------------------------
function hdr = make_header(dims, voxel_size, origin, datatype, ...
	descrip, maxval, minval)

   hdr.hk   = header_key;
   hdr.dime = image_dimension(dims, voxel_size, datatype, maxval, minval);
   hdr.hist = data_history(origin, descrip);
    
   return;					% make_header


%---------------------------------------------------------------------
function hk = header_key

    hk.sizeof_hdr       = 348;			% must be 348!
    hk.data_type        = '';
    hk.db_name          = '';
    hk.extents          = 0;
    hk.session_error    = 0;
    hk.regular          = 'r';
    hk.dim_info         = 0;
    
    return;					% header_key


%---------------------------------------------------------------------
function dime = image_dimension(dims, voxel_size, datatype, maxval, minval)
   
   dime.dim = dims;
   dime.intent_p1 = 0;
   dime.intent_p2 = 0;
   dime.intent_p3 = 0;
   dime.intent_code = 0;
   dime.datatype = datatype;
   
   switch dime.datatype
   case 2,
      dime.bitpix = 8;  precision = 'uint8';
   case 4,
      dime.bitpix = 16; precision = 'int16';
   case 8,
      dime.bitpix = 32; precision = 'int32';
   case 16,
      dime.bitpix = 32; precision = 'float32';
   case 32,
      dime.bitpix = 64; precision = 'float32';
   case 64,
      dime.bitpix = 64; precision = 'float64';
   case 128
      dime.bitpix = 24;  precision = 'uint8';
   case 256 
      dime.bitpix = 8;  precision = 'int8';
   case 511
      dime.bitpix = 96;  precision = 'float32';
   case 512 
      dime.bitpix = 16; precision = 'uint16';
   case 768 
      dime.bitpix = 32; precision = 'uint32';
   case 1792,
      dime.bitpix = 128; precision = 'float64';
   otherwise
      error('Datatype is not supported by make_nii.');
   end
   
   dime.slice_start = 0;
   dime.pixdim = voxel_size;
   dime.vox_offset = 0;
   dime.scl_slope = 0;
   dime.scl_inter = 0;
   dime.slice_end = 0;
   dime.slice_code = 0;
   dime.xyzt_units = 0;
   dime.cal_max = 0;
   dime.cal_min = 0;
   dime.slice_duration = 0;
   dime.toffset = 0;
   dime.glmax = maxval;
   dime.glmin = minval;
   
   return;					% image_dimension


%---------------------------------------------------------------------
function hist = data_history(origin, descrip)
   
   hist.descrip = descrip;
   hist.aux_file = 'none';
   hist.qform_code = 0;
   hist.sform_code = 0;
   hist.quatern_b = 0;
   hist.quatern_c = 0;
   hist.quatern_d = 0;
   hist.qoffset_x = 0;
   hist.qoffset_y = 0;
   hist.qoffset_z = 0;
   hist.srow_x = zeros(1,4);
   hist.srow_y = zeros(1,4);
   hist.srow_z = zeros(1,4);
   hist.intent_name = '';
   %%% WARNING magic is set by save_nii!
   hist.magic = '';
   hist.originator = origin;
   
   return;					% data_history

