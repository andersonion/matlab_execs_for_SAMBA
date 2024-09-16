function [outd,a,gzi,bos,unused_bytes]=gunzip_load(input,var_specifications,max_read,gzip_cont_vars)
% output_struct=GUNZIP_LOAD(input,var_specifications,max_read)
% Take gzip compressed file and load it into memory.
% Optionally dividing it up according to var_specification.
% Optionally stoping at max_read (in decompresed bytes).
% Useful in loading gz files, used in our internal functions.
% 
% Input should be a file path.
% The file is set up as a java FileInputStream, with a GZIPInputStream
% wrapper.
%
% If var_specifications is omitted the output will be a single uint8 byte
% byte array
%
% var_specifications are three or four element cell vectors of
% {decompresseed_byte_count, 'data_type','name'}
% {decompresseed_byte_count, 'data_type','name','endian'}
% where endian is little or big. 
% You can have multiple var_specificaions, in a cell array.
if ~exist('var_specifications','var')
    var_specifications={{inf,'uint8','data','little'}};
end
% Not sure what this if statement was guarding against.
% if numel(var_specifications)>=3 
%     var_specifications={var_specifications};
% end
continue_mode=0;
if exist('gzip_cont_vars','var')
    continue_mode=1;
    if isstr(gzip_cont_vars)
        clear gzip_cont_vars;
    end
end
%% TODO
% check var_specificaions for even multiples of output bytes to data type.
% also check output requested names are unique

if ~exist(input,'file')
    error('File %s missing.',input);
end

  % relies on small helper java code. That code should not be necessary, and 
  % may not be required in later versions of matlab.
  % input_info=whos('input');
  % if(input_info.bytes/1024^2 > 500 )
  %     warning('Large input, this could take a while.');
  % end
  buffer_size=100*1024^2;%100mb buffer.
  %   buffer_size=10*1024^2;  %10mb buffer.
  %   buffer_size=1*1024^2;    %1mb buffer.
  %   buffer_size=1*1024^1;     %1kb buffer.
  %   buffer_size=128;        %128b buffer.
  if exist('max_read','var') && ~isinf(max_read)
      buffer_size=max_read;
  else
      max_read=inf;
  end
  if (buffer_size == -1)
      outd=null;
      return; %'null';
  end
  import java.util.zip.GZIPInputStream;
  import java.io.*;
  %% find custom java gzip reader, and compile if need be.
  cpath=fileparts(mfilename('fullpath'));
  %%%
  % check if available, if not try adding path.
  if isempty(which('GzipRead'))
      javaaddpath(cpath);
  end
  % check if available, if not try compiling.
  if isempty(which('GzipRead'))
      [c_success,c_out]=system(sprintf('javac %s',fullfile(cpath,'GzipRead.java')));
      if ~c_success 
          warning('Problem in java compile %s. "%s"',fullfile(cpath,'GzipRead.java'),c_out);
      end
  end
  % check if available, if not check that matlab_java is set.
  if isempty(which('GzipRead'))
      if isempty(getenv('MATLAB_JAVA'))
          warning('MATLAB_JAVA is not set!!!, this code relies on an updated version of java to dynamically compile a simple class file! set MATLAB_JAVA for full functionality, ideally add the bin folder of your JDK to the path.');
      end
  end
  JAVA_HELPER_AVAILABLE=1;
  % last check for available, if not, proceed in byte read mode.
  if isempty(which('GzipRead'))
      warning('THIS IS IMPOSSIBLY SLOW WITHOUT THE HELPER JAVA CODE');
      pause(3);
      JAVA_HELPER_AVAILABLE=0;
      read_buffer = zeros(1,buffer_size,'uint8');
  else
      % this was originally created inside the loop, but that is bad form
      % beacuse it would cause dropped bits.
      gzipReader=GzipRead;
      jmem=[java.lang.Runtime.getRuntime.maxMemory...
          java.lang.Runtime.getRuntime.totalMemory...
          java.lang.Runtime.getRuntime.freeMemory];
      if buffer_size > max(jmem)
          error('java memory not tuned high enough, generally we want it as high as possible try adding java.opts file, see https://www.mathworks.com/matlabcentral/answers/92813-how-do-i-increase-the-heap-space-for-the-java-vm-in-matlab-6-0-r12-and-later-versions');
      end
      if jmem(1) < 4*1024^3
          warning('Less than 4GiB allocated to java mem, this code is likely to fail, for instructions see https://www.mathworks.com/help/matlab/matlab_external/java-heap-memory-preferences.html');
      end
  end
  % this matlab code was puzzled together from java examples, the java
  % equivalent code is in the comments.
  if ~exist('gzip_cont_vars','var')
      a=java.io.FileInputStream(input); gzi =java.util.zip.GZIPInputStream(a,buffer_size);%  GZIPInputStream gzi = new GZIPInputStream(new ByteArrayInputStream(buffer, 0, buffer.length));
      bos = java.io.ByteArrayOutputStream; %ByteArrayOutputStream bos =  new ByteArrayOutputStream();
      unused_bytes=uint8([]);
  else
      a=gzip_cont_vars{1};
      gzi=gzip_cont_vars{2};
      bos=gzip_cont_vars{3};
      unused_bytes=gzip_cont_vars{4};
  end
  rn=1;% read count, used for the output structure.
  outd=struct;
  bi=1; %byte index, when java helper is unavailable we do it very wrongly.
  fprintf('expanding...\n');
  ot=sprintf('%06.2fMiB ',0);
  fprintf(ot);
  % backspace count to let us print on same line, once data gets super big
  % we have to have more of them....
  bs_count=length(ot);
  c_var=1;%var_specifications{1}{3}; % which variable we're filling in right now.
  ready_bytes=0; % number of bytes of decompressed output ready.
  total_bytes=0; % total bytes we've decompressed.
  while(gzi.available ) % && a.available>0
      % Documentation of GZIPInputStream::read(byte[] buf, int off, int len)
      % read should have been the solution, however in testing, it
      % only returned arrays of zeros. It has been wrapped into an ultra
      % minimal class to do that job for us. 
      %%
      %     len=gzi.read(read_buffer,0,max_read); read_buffer(1:10)
      % MORE MADNESS, read() with no args, returns bytes as expected!
      if JAVA_HELPER_AVAILABLE
          try
              javaMethod('readToStream',gzipReader,gzi,buffer_size,bos);
          catch je
              if ~isempty(regexpi(je.message,'Unexpected end of ZLIB input stream'))
                  % db_inplace(mfilename);
                  warning('GzipStream unexpected end of stream');
                  break;
              else
                  je.throwAsCaller;
              end
          end
          try
          d=[unused_bytes,reshape(typecast(bos.toByteArray(),'uint8'),[1,bos.size])];
          unused_bytes=uint8([]);
          catch merr
              warning(merr.message);
          end
          bos.reset();
          % the output structure use a very large numebr of leading zeros
          % to help ensure the output structure works right.
      else
          while(gzi.available && bi<= buffer_size) %while((len=gzi.read(outbuf, 0, outbuf.length)) != -1)
              read_buffer(bi)=gzi.read();
              bi=bi+1;
          end
          % the output structure use a very large numebr of leading zeros
          % to help ensure the output structure works right.
          d=read_buffer(1:bi-1);
          bi=1;% reset byte index.
      end
      ready_bytes=ready_bytes+numel(d);
      total_bytes=total_bytes+ready_bytes;
      d=reshape(d,[1,numel(d)]);
      %% TODO 
      % fix issues with many small variable in a single decompression. 
      % this code is only good if the outputs are large enough that they
      % at most end up with 2 pieces per load.
      if ready_bytes<var_specifications{c_var}{1}
          outd.(var_specifications{c_var}{3}).(sprintf('r_%030i',rn))=reshape(d,[1,numel(d)]);
      else
          % we have enough data elements in first var, 
          % split up current array, assign part to current var, and rest to
          % next var. Maybe a while loop would allow this to assign to many
          % small vars.
          % need to know how many extra bytes we have
          % that should be ready_bytes-desired_total
          skip_bytes=0;
          while ready_bytes>0 && c_var<=numel(var_specifications)
              extra_bytes=ready_bytes-var_specifications{c_var}{1}; % desired total bytes
              if extra_bytes==-inf
                  extra_bytes=0;
              end
              outd.(var_specifications{c_var}{3}).(sprintf('r_%030i',rn))=d(1+skip_bytes:end-extra_bytes);
              skip_bytes=skip_bytes+var_specifications{c_var}{1};
              ready_bytes=ready_bytes-var_specifications{c_var}{1};
              rn=1;
              if ready_bytes==-inf
                  ready_bytes=0;
              else
                  c_var=c_var+1;
              end
          end
          %% stash extra bytes?
%              =[overflow; typecast(fgz.byteOut.toByteArray(),'uint8')]
          unused_bytes=typecast(d(end-extra_bytes+1:end),'uint8');
      end
      %outd.(sprintf('r_%030i',rn))=d';
      oinfo=whos('outd');
      MB=oinfo.bytes/1024^2;
      % this for loop clumsily prints the right number of chars to
      % backspace the whole % so we can print out the next one.
      for rep=1:bs_count;fprintf('\b');end
      ot=sprintf('%06.2fMiB ',MB);
      fprintf(ot);
      bs_count=length(ot);
      rn=rn+1;
      if total_bytes>=max_read || c_var>numel(var_specifications)
          fprintf('max_read tripped.');
          break;
      end
  end
  fprintf('\n');
  %   oinfo_s=whos('outd');
  if ~continue_mode
      gzi.close();a.close();
      bos.close();
      java.lang.System.gc();% not really sure if this is a good thing to run here or not.
  end
  fprintf('cleaning up temp vars...\n');
  
  if exist('test_code','var')
      if test_code==1
          simple_code=1;
      end
      if test_code==2
          inline_strctlooper=1;
      end
  end
  for se=1:numel(var_specifications)
    vn=var_specifications{se}{3};
    if exist('simple_code','var')
      outd.(vn)=struct2array(outd.(vn)); % Significant memory surge, ~25-50% of array size.
    elseif ~exist('inline_strctlooper','var')
      %% custom struct2array
      % outd=struct2array(outd); % Significant memory surge, ~25-50% of array size.
      s2a=large_array;
      s2a.addprop('data');
      s2a.data= outd.(vn);outd=rmfield(outd,vn);
      kind_struct2array(s2a);
      outd.(vn)=s2a.data;clear s2a;
    else
      oe=sort(fieldnames( outd.(vn)));
      count=0;
      for fn=1:numel(oe)
          count=count+numel( outd.(vn).(oe{fn}));
      end
      output=zeros(1,count,'like', outd.(vn).(oe{fn}));
      %       output=spalloc(1,count,count); % sparse only available for type
      %       double : (
      idx=1;
      fprintf('%s\n',vn);
      fprintf('\t%06.3f/100\n',0)
      %%% probably have to insert uneven decompression handling here,
      %%% adding or removing bits from the unused_bytes?
      for fn=1:numel(oe)
          output(idx:numel( outd.(vn).(oe{fn}))+(idx-1))= outd.(vn).(oe{fn});
          idx=idx+numel( outd.(vn).(oe{fn}));
          outd.(vn)=rmfield( outd.(vn),oe{fn});
          fprintf('\b\b\b\b\b\b\b\b\b\b\b%06.3f/100\n',100*fn/numel(oe));
      end
      outd.(vn)=output;clear output;
    end
    %% TODO Move the typecast code someplace better, so it isnt so memory intensive doing it all at once at the end.
    if strcmp(var_specifications{se}{2},'uint8')
        % uint8, do nothing
    else
        outd.(vn)=typecast(outd.(vn),var_specifications{se}{2});
        % 'little'
    end
  end
%   outd=full(outd);
  
  % maybe this would be more mem efficient by making a zeros array, and adding each
  % element array glob one at a time in a loop and removing structure elements as we go?
%   if ( nnz(outd)==0 ) % slow, but no memory impact. Maybe we can skip this now?
%       db_inplace(mfilename,'all bytes are zero on decompression!');
%   end
  return ;
end

function byteData=gunzip_vars(input)
% This works great for SMALL volumes ~55MiB.
% in testing at that scale, the other code was about 30% faster, so it is
% always used.
% Once the volume is sufficiently large this crashes.
% the problem is that interruptable stream copier operates in pure java, 
% and will exceed the max var size for java in/with matlab. 
import com.mathworks.mlwidgets.io.*;
%import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;

if ~strcmpi(class(input),'uint8') || ndims(input) > 2 || min(size(input) ~= 1)
    error('Input must be a 1-D array of uint8');
end

%------Decompress byte-array "byteArray" to "byteData" using java methods------
% a=java.io.ByteArrayInputStream(input);
% b=java.util.zip.GZIPInputStream(a);
% c = java.io.ByteArrayOutputStream;

byteInStream=java.io.ByteArrayInputStream(input);
gzipInStream=java.util.zip.GZIPInputStream(byteInStream);
byteOutStream = java.io.ByteArrayOutputStream;

isc = InterruptibleStreamCopier.getInterruptibleStreamCopier;
isc.copyStream(gzipInStream,byteOutStream);

byteData = typecast(byteOutStream.toByteArray,'uint8');
%----------------------------------------------------------------------
end

