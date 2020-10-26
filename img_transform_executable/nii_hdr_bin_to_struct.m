function [hdr, machine] = nii_hdr_bin_to_struct(binary_header)
%function [hdr, machine] = (binary_header)

b=large_array;
b.addprop('char_bin');
b.char_bin=binary_header;


if ~exist('binary_header','var')
    error('Usage: [hdr, machine] = load_nii_hdr(binary_header)');
end

b.addprop('machine');
b.machine='ieee-le';
if typecast(b.char_bin(1:4),'int32') ~= 348
    %try opposing_endianness
    if typecast(b.char_bin(4:-1:1),'int32') ~= 348
        
        %  Now throw an error
        %
        msg = sprintf('Data is corrupted.');
        error(msg);
    else
        warning('DONT KNOW HOW TO PROPERLY HANDLE OTHER ENDIANNESS!');
    end
   b.machine = 'ieee-be'; 
end
hdr = read_header(b);

if strcmp(hdr.hist.magic, 'n+1')
    filetype = 2;
elseif strcmp(hdr.hist.magic, 'ni1')
    filetype = 1;
else
    filetype = 0;
end
machine=b.machine;
% return					% load_nii_hdr
end


%---------------------------------------------------------------------
function [ dsr ] = read_header(b)

        %  Original header structures
	%  struct dsr
	%       { 
	%       struct header_key hk;            /*   0 +  40       */
	%       struct image_dimension dime;     /*  40 + 108       */
	%       struct data_history hist;        /* 148 + 200       */
	%       };                               /* total= 348 bytes*/

    dsr.hk   = header_key(b);
    dsr.dime = image_dimension(b);
    dsr.hist = data_history(b);
    dsr.extension = eat(b,4,'uint8');
    %  For Analyze data format
    %
    if ~strcmp(dsr.hist.magic, 'n+1') & ~strcmp(dsr.hist.magic, 'ni1')
        dsr.hist.qform_code = 0;
        dsr.hist.sform_code = 0;
    end
%     return					% read_header
end


%---------------------------------------------------------------------
function [ hk ] = header_key(b)

%     fseek(fid,0,'bof');
    
	%  Original header structures	
	%  struct header_key                     /* header key      */ 
	%       {                                /* off + size      */
	%       int sizeof_hdr                   /*  0 +  4         */
	%       char data_type[10];              /*  4 + 10         */
	%       char db_name[18];                /* 14 + 18         */
	%       int extents;                     /* 32 +  4         */
	%       short int session_error;         /* 36 +  2         */
	%       char regular;                    /* 38 +  1         */
	%       char dim_info;   % char hkey_un0;        /* 39 +  1 */
	%       };                               /* total=40 bytes  */
	%
	% int sizeof_header   Should be 348.
	% char regular        Must be 'r' to indicate that all images and 
	%                     volumes are the same size. 
    %{
typecast(b.char_bin(1:4),'int32');b.char_bin(1:4)=[];
typecast(b.char_bin(1:2),'int16');b.char_bin(1:2)=[];
    %}
    
    %{
    hk.sizeof_hdr    = typecast(b.char_bin(1:4),'int32');b.char_bin(1:4)=[];       % fread(fid, 1,'int32')';	% should be 348!
    hk.data_type     = deblank(cast(b.char_bin(1:10),'char'));b.char_bin(1:10)=[]; % deblank(fread(fid,10,directchar)');
    hk.db_name       = deblank(cast(b.char_bin(1:18),'char'));b.char_bin(1:18)=[]; % deblank(fread(fid,18,directchar)');
    hk.extents       = typecast(b.char_bin(1:4),'int32');b.char_bin(1:4)=[];       % fread(fid, 1,'int32')';
    hk.session_error = typecast(b.char_bin(1:2),'int16');b.char_bin(1:2)=[];       % fread(fid, 1,'int16')';
    hk.regular       = cast(b.char_bin(1),'char');b.char_bin(1)=[];                % fread(fid, 1,directchar)';
    hk.dim_info      = cast(b.char_bin(1),'char');b.char_bin(1)=[];                % fread(fid, 1,'uchar')';
    %}
    

    hk.sizeof_hdr    = eat(b, 1,'int32')';	% should be 348!
    hk.data_type     = deblank(eat(b,10,'char')');
    hk.db_name       = deblank(eat(b,18,'char')');
    hk.extents       = eat(b, 1,'int32')';
    hk.session_error = eat(b, 1,'int16')';
    hk.regular       = eat(b, 1,'char')';
    hk.dim_info      = eat(b, 1,'char')';
%    return					% header_key
end


%---------------------------------------------------------------------
function [ dime ] = image_dimension(b)

	%  Original header structures    
	%  struct image_dimension
	%       {                                /* off + size      */
	%       short int dim[8];                /* 0 + 16          */
        %       /*
        %           dim[0]      Number of dimensions in database; usually 4. 
        %           dim[1]      Image X dimension;  number of *pixels* in an image row. 
        %           dim[2]      Image Y dimension;  number of *pixel rows* in slice. 
        %           dim[3]      Volume Z dimension; number of *slices* in a volume. 
        %           dim[4]      Time points; number of volumes in database
        %       */
	%       float intent_p1;   % char vox_units[4];   /* 16 + 4       */
	%       float intent_p2;   % char cal_units[8];   /* 20 + 4       */
	%       float intent_p3;   % char cal_units[8];   /* 24 + 4       */
	%       short int intent_code;   % short int unused1;   /* 28 + 2 */
	%       short int datatype;              /* 30 + 2          */
	%       short int bitpix;                /* 32 + 2          */
	%       short int slice_start;   % short int dim_un0;   /* 34 + 2 */
	%       float pixdim[8];                 /* 36 + 32         */
	%	/*
	%		pixdim[] specifies the voxel dimensions:
	%		pixdim[1] - voxel width, mm
	%		pixdim[2] - voxel height, mm
	%		pixdim[3] - slice thickness, mm
	%		pixdim[4] - volume timing, in msec
	%					..etc
	%	*/
	%       float vox_offset;                /* 68 + 4          */
	%       float scl_slope;   % float roi_scale;     /* 72 + 4 */
	%       float scl_inter;   % float funused1;      /* 76 + 4 */
	%       short slice_end;   % float funused2;      /* 80 + 2 */
	%       char slice_code;   % float funused2;      /* 82 + 1 */
	%       char xyzt_units;   % float funused2;      /* 83 + 1 */
	%       float cal_max;                   /* 84 + 4          */
	%       float cal_min;                   /* 88 + 4          */
	%       float slice_duration;   % int compressed; /* 92 + 4 */
	%       float toffset;   % int verified;          /* 96 + 4 */
	%       int glmax;                       /* 100 + 4         */
	%       int glmin;                       /* 104 + 4         */
	%       };                               /* total=108 bytes */
	
    dime.dim        = eat(b,8,'int16');
    dime.intent_p1  = eat(b,1,'float32')';
    dime.intent_p2  = eat(b,1,'float32')';
    dime.intent_p3  = eat(b,1,'float32')';
    dime.intent_code = eat(b,1,'int16')';
    dime.datatype   = eat(b,1,'int16')';
    dime.bitpix     = eat(b,1,'int16')';
    dime.slice_start = eat(b,1,'int16')';
    dime.pixdim     = eat(b,8,'float32');
    dime.vox_offset = eat(b,1,'float32')';
    dime.scl_slope  = eat(b,1,'float32')';
    dime.scl_inter  = eat(b,1,'float32')';
    dime.slice_end  = eat(b,1,'int16')';
    dime.slice_code = eat(b,1,'char')';
    dime.xyzt_units = eat(b,1,'char')';
    dime.cal_max    = eat(b,1,'float32')';
    dime.cal_min    = eat(b,1,'float32')';
    dime.slice_duration = eat(b,1,'float32')';
    dime.toffset    = eat(b,1,'float32')';
    dime.glmax      = eat(b,1,'int32')';
    dime.glmin      = eat(b,1,'int32')';
        
%     return					% image_dimension
end

%---------------------------------------------------------------------
function [ hist ] = data_history(b)
        
	%  Original header structures
	%  struct data_history       
	%       {                                /* off + size      */
	%       char descrip[80];                /* 0 + 80          */
	%       char aux_file[24];               /* 80 + 24         */
	%       short int qform_code;            /* 104 + 2         */
	%       short int sform_code;            /* 106 + 2         */
	%       float quatern_b;                 /* 108 + 4         */
	%       float quatern_c;                 /* 112 + 4         */
	%       float quatern_d;                 /* 116 + 4         */
	%       float qoffset_x;                 /* 120 + 4         */
	%       float qoffset_y;                 /* 124 + 4         */
	%       float qoffset_z;                 /* 128 + 4         */
	%       float srow_x[4];                 /* 132 + 16        */
	%       float srow_y[4];                 /* 148 + 16        */
	%       float srow_z[4];                 /* 164 + 16        */
	%       char intent_name[16];            /* 180 + 16        */
	%       char magic[4];   % int smin;     /* 196 + 4         */
	%       };                               /* total=200 bytes */

%     v6 = version;
%     if str2num(v6(1))<6
%        directchar = '*char';
%     else
%        directchar = 'uchar=>char';
%     end

    hist.descrip     = deblank(eat(b,80,'char')');
    warning('Originator is a BOGUS BOGUS BOGUS BOGUS field, invented by SPM');
%     hist.originator  = typecast(b.char_bin(1:10),'int16');
    hist.originator  = zeros([5 1],'int16');
    hist.aux_file    = deblank(eat(b,24,'char')');
    hist.qform_code  = eat(b,1,'int16')';
    hist.sform_code  = eat(b,1,'int16')';
    hist.quatern_b   = eat(b,1,'float32')';
    hist.quatern_c   = eat(b,1,'float32')';
    hist.quatern_d   = eat(b,1,'float32')';
    hist.qoffset_x   = eat(b,1,'float32')';
    hist.qoffset_y   = eat(b,1,'float32')';
    hist.qoffset_z   = eat(b,1,'float32')';
    hist.srow_x      = eat(b,4,'float32');
    hist.srow_y      = eat(b,4,'float32');
    hist.srow_z      = eat(b,4,'float32');
    hist.intent_name = deblank(eat(b,16,'char')');
    hist.magic       = deblank(eat(b,4,'char'));
    
    
    %     Originator is a BOGUS BOGUS BOGUS BOGUS field, invented by SPM 
    % this would have been completely omitted, except that view_nii relies
    % on it!.
    %     fseek(fid,253,'bof');
    %hist.originator  = eat(b, 5,'int16')';

end

function val=eat(b,vals,type)
% function val=eat(b,type,endian)
% eats part of a uchar array to typecast them to other types.
% simulates an fread on a filehandle.
if strcmp(b.machine,'ieee-be')
    warning('Big endian support not done!');
end
% set up the number of chars to use per value
switch type
    case {'int8', 'uint8','char','uchar'}
        chars_per_val=1;
    case {'int16', 'uint16'}
        chars_per_val=2;
    case {'int32', 'uint32','float32','single'}
        chars_per_val=4;
    case {'int64','uint64','float64','double'}
        chars_per_val=8;
    otherwise
        error('eat for typecast not gonna work.');
end
nchars=chars_per_val*vals;


% change the type to valid matlab typecast targets
switch type
    case {'float32'}
        type='single';
    case {'float64'}
        type='double';
end
if chars_per_val>1 % chars dont type cast
    val=typecast(b.char_bin(1:nchars),type);b.char_bin(1:nchars)=[];
    if strcmp(b.machine,'ieee-be')
        val=swapbytes(val);
    end
else
    val=cast(b.char_bin(1:nchars),type);b.char_bin(1:nchars)=[];
end
end

