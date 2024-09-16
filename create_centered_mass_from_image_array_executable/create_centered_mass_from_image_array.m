function create_centered_mass_from_image_array(in_file,out_file)
%in_file = '/glusterspace/VBM_14obrien01_DTI101b-work/preprocess/base_images/native_reference_controlSpring2013_4.nii.gz';
%out_file = '/glusterspace/VBM_14obrien01_DTI101b-work/preprocess/base_images/native_reference_controlSpring2013_4_TEST.nii.gz';

% 8 July 2019, BJA: changing from dependency on 'wasteful_load' to
% try/catch block which uses load_niigz_hdr IF AVAILABLE
try
    nii.hdr=load_niigz_hdr(in_file);
    image=zeros(nii.hdr.dime.dim(2:4),nifti1('data_type',nii.hdr.dime.datatype));
catch
    wasteful_load=1;
%if exist('wasteful_load','var')
    nii = load_untouch_nii(in_file);
    % testing of load_niigz shows its a bit slower than the other code. That is
    % confusing. Maybe the true savings of load_niigz only show up for mask
    % data or other egregiously compression ratio files.
    %nii = load_niigz(in_file);
    image = squeeze(nii.img(:,:,:,1,1,1,1));
    % On paying closer attention to what this function is doing, There is
    % no reason to load the image data.... Hence wastful_load disables
    % load/save_untouch code. 
%else
%    nii.hdr=load_niigz_hdr(in_file);
%    image=zeros(nii.hdr.dime.dim(2:4),nifti1('data_type',nii.hdr.dime.datatype));
end

dims=nii.hdr.dime.dim(2:4);

frac = 4;
starters = ceil(dims*(1/2-1/(frac*2)));
enders = starters + round(dims/frac);

image = image*0;
image(starters(1):enders(1),starters(2):enders(2),starters(3):enders(3))=1;

nii.img = image;
nii.hdr.dime.dim(1)=3;
nii.hdr.dime.dim(5)=1;
nii.hdr.dime.pixdim(1)=1;
nii.hdr.dime.pixdim(5)=0;
if exist('wasteful_load','var')
    save_untouch_nii(nii,out_file)
else
    save_nii(nii,out_file)
end