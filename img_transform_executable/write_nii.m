function write_nii(nii, filetype, fileprefix, old_RGB,gzBool)
%internal function to save_nii pulled out.

   hdr = nii.hdr;
   if isfield(nii,'ext') & ~isempty(nii.ext)
      ext = nii.ext;
      [ext, esize_total] = verify_nii_ext(ext);
   else
      ext = [];
   end

   switch double(hdr.dime.datatype),
   case   1,
      hdr.dime.bitpix = int16(1 ); precision = 'ubit1';
   case   2,
      hdr.dime.bitpix = int16(8 ); precision = 'uint8';
   case   4,
      hdr.dime.bitpix = int16(16); precision = 'int16';
   case   8,
      hdr.dime.bitpix = int16(32); precision = 'int32';
   case  16,
      hdr.dime.bitpix = int16(32); precision = 'float32';
   case  32,
      hdr.dime.bitpix = int16(64); precision = 'float32';
   case  64,
      hdr.dime.bitpix = int16(64); precision = 'float64';
   case 128,
      hdr.dime.bitpix = int16(24); precision = 'uint8';
   case 256 
      hdr.dime.bitpix = int16(8 ); precision = 'int8';
   case 511,
      hdr.dime.bitpix = int16(96); precision = 'float32';
   case 512 
      hdr.dime.bitpix = int16(16); precision = 'uint16';
   case 768 
      hdr.dime.bitpix = int16(32); precision = 'uint32';
   case 1024
      hdr.dime.bitpix = int16(64); precision = 'int64';
   case 1280
      hdr.dime.bitpix = int16(64); precision = 'uint64';
   case 1792,
      hdr.dime.bitpix = int16(128); precision = 'float64';
   otherwise
      error('This datatype is not supported');
   end
   %{
   % not gonna force this update here. If users want to play with 
   % gl(min|max) this breaks that.
   hdr.dime.glmax = round(double(max(nii.img(:))));
   hdr.dime.glmin = round(double(min(nii.img(:))));
   %}
   %%%
   % A "Cheap" way to convert the struct tobinary would be to capture the
   % ouptut of our fwrite's here...
   % At a first glance, we could use stderr or stdout... however I dont
   % know how we'll get that back...
   %%%
   if filetype == 2
      [fid,fmsg] = fopen(sprintf('%s.nii',fileprefix),'w+');
      if fid < 0,
         msg = sprintf('Cannot open file %s.nii with error: %s.',fileprefix,fmsg);
         error(msg);
      end
      hdr.dime.vox_offset = 352;
      if ~isempty(ext)
         hdr.dime.vox_offset = hdr.dime.vox_offset + esize_total;
      end
      hdr.hist.magic = 'n+1';
      save_nii_hdr(hdr, fid);
      if ~isempty(ext)
         save_nii_ext(ext, fid);
      end
   else
       fid = fopen(sprintf('%s.hdr',fileprefix),'w');
       if fid < 0,
           msg = sprintf('Cannot open file %s.hdr.',fileprefix);
           error(msg);
       end
       hdr.dime.vox_offset = 0;
       hdr.hist.magic = 'ni1';
       save_nii_hdr(hdr, fid);
       if ~isempty(ext)
           save_nii_ext(ext, fid);
       end
       fclose(fid);
       fid = fopen(sprintf('%s.img',fileprefix),'w');
   end
   %{
   % vestigal code. 
   ScanDim = double(hdr.dime.dim(5));		% t
   SliceDim = double(hdr.dime.dim(4));		% z
   RowDim   = double(hdr.dime.dim(3));		% y
   PixelDim = double(hdr.dime.dim(2));		% x
   SliceSz  = double(hdr.dime.pixdim(4));
   RowSz    = double(hdr.dime.pixdim(3));
   PixelSz  = double(hdr.dime.pixdim(2));
   x = 1:PixelDim;
   %}

   if filetype == 2 & isempty(ext)
      skip_bytes = double(hdr.dime.vox_offset) - 348;
   else
      skip_bytes = 0;
   end
   if double(hdr.dime.datatype) == 128 ...
           || double(hdr.dime.datatype) == 511
       %  RGB planes are expected to be in the 4th dimension of nii.img
       if(size(nii.img,4)~=3)
           error('The NII structure does not appear to have 3 RGB color planes in the 4th dimension');
       end
       if old_RGB
           nii.img = permute(nii.img, [1 2 4 3 5 6 7 8]);
       else
           nii.img = permute(nii.img, [4 1 2 3 5 6 7 8]);
       end
   elseif hdr.dime.datatype == 32 ...
           || hdr.dime.datatype == 1792
       %  For complex float32 or complex float64, voxel values
       %  include [real, imag]
       %
       real_img = real(nii.img(:))';
       nii.img = imag(nii.img(:))';
       nii.img = [real_img; nii.img];
   end

   if skip_bytes
      fwrite(fid, zeros(1,skip_bytes), 'uint8');
   end
   if gzBool && filetype == 2
       % pull header back into memory :D
       frewind(fid);
       bin_hdr=fread(fid,inf,'uint8=>uint8');
       fclose(fid);
       % ok=gzip_write(filename,matrix);
       % Waste a bit of time here checking how many zero elements.
       data_elements=nnz(nii.img);
       compression_warning='';
       if data_elements/numel(nii.img) > 0.95
           compression_warning=sprintf('  Image data compresses poorly!\n\tThis takes drastically longer with little gain, unless you have lots of empty values (literal 0).\n');
       end
       fprintf('%s%s',...
           sprintf('Writing directly to compressed file ...\n'), ...
           compression_warning ...
           );
       ok=gzip_write([fileprefix '.nii.gz'],nii.img,bin_hdr);
       delete([fileprefix '.nii']);
   else
       
       fwrite(fid, nii.img, precision);
       %   fwrite(fid, nii.img, precision, skip_bytes);        % error using skip
       fclose(fid);
   end

   return;					% write_nii
