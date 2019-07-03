function [ success_code ] = create_identity_warp(image_nii,varargin )
%Create Identity Warp: Create a self-warp for a given image.  When applied,
% will replicate input image.
%   Created 01 July 2015 by BJ Anderson
%
%   Build output name 
%   Read nii
%   Create zeros array equal to image array
%   Repmat n_dimension times along 5th dimension
%   Replace nii image with new array
%   Set intent code to '1007'
%   Save nii
%   Test for success
%
%   Note: Only guaranteed to support 2 and 3 dimensional images.
%   
%   Optional argument can be an output directory or a full output file
%   name.
%    
%   Ouput  - '1' for success, '0' for failure.

%%   Build output name 

[out_dir,original_name,ext]=fileparts(image_nii);
out_name = 'identity_warp';
out_ext = '.nii.gz';

nVarargs = length(varargin);
   for k = 1:nVarargs
      tester = varargin{k};
      t_class = class(tester);
      if (ischar(t_class))
          [t_dir, t_name, t_ext] = fileparts(tester);
          if (exist(t_dir,'dir') == 7)
              out_dir = t_dir
              
              if (~ strcmp(t_ext,'')) % It is assumed that if there is an extension, there was a filename
                  out_name=t_name;
                  out_ext=t_ext;
              end
          end
      end
   end
      
outputpath = [out_dir '/' out_name out_ext];

%%  Read nii
nii=load_nii(image_nii);
image = nii.img;
dims=nii.hdr.dime.dim;

%%   Create zeros array equal to image array and repmat n_dimension times along 5th dimension
zero_array = zeros(dims(2:5));
if dims(1) == 2
    dims(6) = 2;
    new_image = cat(5,zero_array,zero_array); 
else
   dims(6)=3;
   new_image = cat(5,zero_array,zero_array,zero_array);   
end
dims(1) = 5;
nii.hdr.dime.dim=dims;
%%   Replace nii image with new array
nii.img = new_image;

%%   Set intent code to '1007'
nii.hdr.dime.intent_code = 1007;

%%   Write nii
save_nii(nii,outputpath);


%% Check for output

pause(2)

if (exist(outputpath,'file') == 2)
    success_code = 1; % Success
else
    success_code = 0; % Failure
end
    
end