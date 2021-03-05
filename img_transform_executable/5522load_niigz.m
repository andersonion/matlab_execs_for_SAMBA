function nii=load_niigz(nii_path)
% function nii=LOAD_NIIGZ(nii_path)
% Read a gzipped nifti not stupid slowly.
%% Load our binaryh header, gzipped or not hdr struct
[nii_hdr,nii_binaryh,nii_gz_bool,nii_fid]=load_niigz_hdr(nii_path);
%% set endian
if typecast(nii_binaryh(1:4),'int32') == 348
    nii_endian='l';
elseif  typecast(nii_binaryh(4:-1:1),'int32') == 348
    nii_endian='b';
    db_inplace(mfilename,'DID NOT HANDLE Big endian data!');
else
    db_inplace(mfilename,'ERROR in decompression!');
end
%% data read
if nii_gz_bool
    d=gunzip_load(nii_path,{{352,'uint8','bhdr'},{inf,nifti1('data_type',nii_hdr.dime.datatype),'imgdata','little'}});
    nii_data=d.imgdata;clear d;
else
    nii_data = fread(nii_fid,inf,[nifti1('data_type',nii_hdr.dime.datatype) '=>' nifti1('data_type',nii_hdr.dime.datatype)],0,nii_endian);
    fclose(nii_fid);
end
%% vector something something, What are we doing here? also, make all dims at least 1
nii_vector_mode=0;
nii_hdr.dime.dim(nii_hdr.dime.dim==0)=1;% some nifti programs set 0 on dimensions, that caues this math to break.

extra_elements=8*(uint32(nii_hdr.dime.vox_offset)-352)/uint32(nii_hdr.dime.bitpix);
if ( extra_elements > 0 )
    warning('Extra data found, possibly additional metadata (xml, perhaps?). Converting to text and storing in nii.extra_data.');
    nii_extra_data=nii_data(1:extra_elements);
    nii_extra_data=char(typecast([nii_extra_data(1:end)],'uint8'));  
    nii_data(1:extra_elements)=[];
end

if prod(nii_hdr.dime.dim(2:end)) < numel(nii_data)
    warning('dimensions state 3d, but we have more data than we should. Assuming vector/multi-channel volume.');
    n_dims=[numel(nii_data)/prod(nii_hdr.dime.dim(2:end)),nii_hdr.dime.dim(2:end)];
    nii_vector_mode=1;
elseif prod(nii_hdr.dime.dim(2:end)) > numel(nii_data)
    db_inplace(mfilename,'Problem with data load, insufficient data loaded!');
else
    %     n_dims=[1,nii_hdr.dime.dim(2:end)];
    n_dims=nii_hdr.dime.dim(2:end);
end
if size(n_dims,1)~=1
    n_dims=n_dims';
end
%% reshape data.
nii_data=reshape(nii_data,n_dims);
if ~nii_vector_mode
    nii_data=permute(nii_data,[1,5:numel(n_dims),2:4]);
    %     td=size(nii1_data);
    %     nii1_data=reshape(nii1_data,[prod(td(1:5)),td(6:8)]);
    nii_data=reshape(nii_data,[prod([n_dims(1),n_dims(5:end)]), n_dims(2:4)]);
else
    %     nii1_data=permute(nii1_data,[2:numel(n1_dims),1]);
    %     td=size(nii1_data);
    %     nii1_data=reshape(nii1_data,[td(1:3),prod(td(4:end))]);
    nii_data=permute(nii_data,[1,5:numel(n_dims),2:4]);
    td=size(nii_data);
    nii_data=reshape(nii_data,[prod(td(1:5)),td(6:8)]);
end
%% set nii struct and return
nii.hdr=nii_hdr;
nii.img=nii_data;

if ( extra_elements > 0 )
    nii.extra_data=nii_extra_data;
end