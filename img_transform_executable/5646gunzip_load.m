function [outd,a,gzi,bos,unused_bytes]=gunzip_load(input,var_specifications,max_read,gzip_cont_vars)
% output_struct=GUNZIP_LOAD(input,var_specifications,max_read)
% Take gzip compressed file and load it into memory.
% Optionally dividing it up according to var_specification.
%   NOTE: this is very important for efficient processsing.
% Optionally stoping at max_read (in decompresed bytes).
% max_read is for use in streaming mode to load just enough data for one
% operation and process as you go, instead of loading the whole thing.
% If stream processing must provide continue vars, and capture internal vars
% to hand back for subsequent operations.
% See examples.
%
% Useful in loading gz files efficiently.
% 
% Input should be a file path.
% If possible, the file is set up as a java FileInputStream, with a GZIPInputStream
% wrapper. This requires an appropriate java sdk that is set up so that the
% minimal GzipRead class can be used. ( Note: in future matlab post 2015b
% the GzipRead class may not be required.)
% If gzip java handling should fail it will first fall back to a system
% avilable gunzip to pipe from, then fall back again to single byte read
% which is monsterously inefficient. 
%
% If var_specifications is omitted the output will be a single uint8 byte array
%
% var_specifications is a 1xN cell array of specs.
% specs are three or four element cell vectors of 
% {decompresseed_byte_count, 'data_type','name_in_struct'}
% {decompresseed_byte_count, 'data_type','name_in_struct','endian'}
% where endian is little or big. 
%
% When operating in stream mode add 4th option as a string to indicate
% setup, its value doesn't matter, its just a check for string. 
% example:
% [outd, javaIOFileInputStream, javaUtilZipGZIPInputStream, javaIOByteArrayOutputStream, unused_bytes] = ...
%         gunzip_load(input,var_specifications,max_read, 'setup')
% %%% pass the internalvars back in a cell array on sebsequent calls.
% %%% input is ignored on subsequent calls.
% %%% The continue vars should probably be cleaned up once complete.
% [outd, javaIOFileInputStream, javaUtilZipGZIPInputStream, javaIOByteArrayOutputStream, unused_bytes] = ...
%         gunzip_load(input,var_specifications,max_read, ...
%             { javaIOFileInputStream, javaUtilZipGZIPInputStream, javaIOByteArrayOutputStream, unused_bytes} )
% %..dowork..%
% % cleanup, could be optional(I'm not a java programmer so IDK what i'm
% % doing here).
% javaUtilZipGZIPInputStream.close(); 
% javaIOFileInputStream.close(); 
% javaIOByteArrayOutputStream.close();
% 
if ~exist('var_specifications','var')
    var_specifications={{inf,'uint8','data','little'}};
end
% Not sure what this if statement was guarding against.
% if numel(var_specifications)>=3 
%     var_specifications={var_specifications};
% end
for c_var=1:numel(var_specifications)
    if numel(var_specifications{c_var})<4
        var_specifications{c_var}{4}='little';
    end
end
continue_mode=0;
if exist('gzip_cont_vars','var')
    continue_mode=1;
    if isstr(gzip_cont_vars)
        clear gzip_cont_vars;
    end
end
cleaner=cell(0);
INLINE_CAST_AND_SWAP=1;
%% TODO
% check var_specificaions for even multiples of output bytes to data type.
% also check output requested names are unique

if ~exist(input,'file')
    error('File %s missing.',input);
end
[~,~,native_endian] = computer;

  % relies on small helper java code. That code should not be necessary, and 
  % may not be required in later versions of matlab.
  % input_info=whos('input');
  % if(input_info.bytes/2^20 > 500 )
  %     warning('Large input, this could take a while.');
  % end
  
  % buffer size tries to balance speed, vs memory requirements.
  byte_size.MB100=100*2^20;%100mb buffer
  byte_size.MB25=  25*2^20;% 25mb buffer.
  byte_size.MB10=  10*2^20;% 10mb buffer.
  byte_size.MB1=    1*2^20;%  1mb buffer.
  byte_size.KB1=    1*2^10;%  1kb buffer.
  byte_size.B128=128;%128b buffer.
  buffer_size=byte_size.MB25;
  
  if exist('max_read','var') && ~isinf(max_read) && buffer_size>max_read
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
  JAVA_HELPER_AVAILABLE=GzipReadCheck(1,buffer_size,byte_size.MB1);
  % while sketching out the code, actually using fifo'd gunzip not allowed.
  GUNZIP_allowed=1;
  SYS_FIFO_GUNZIP=0;
  % last check for available, if not, proceed in byte read mode.
  if JAVA_HELPER_AVAILABLE==0
      % IF in just the right situation (linux/mac), we could use mkfifo,
      % and system gunzip to write to fifo, then fopen the fifo...
      [gunzip_missing,sout]=system('which gunzip');
      [mkfifo_missing,sout]=system('which mkfifo');
      if GUNZIP_allowed && gunzip_missing==0
          warning('\n\n\n%s\n\n%s\n\n\n','THIS IS IMPOSSIBLY SLOW WITHOUT THE HELPER JAVA CODE','(We''re going to try wizardly tricks with sys tools mkfifo and gunzip, This is very experimental)');
          if mkfifo_missing==0
              [p,n]=fileparts(input);
              SYS_FIFO_GUNZIP=fullfile(p,sprintf('.%s_fifo',n));
              [s,sout]=system(sprintf('mkfifo -m700 %s',SYS_FIFO_GUNZIP));
              cleaner{end+1} = onCleanup(@() delete(SYS_FIFO_GUNZIP));
              if s~=0
                  error(sout);
              end
              % wait... maybe we dont even need a fifo because we could just
              % take sysout immediately and make it a var? Tested, see
              % below.
              
              % Appears we have to background this process so we're not blocked
              [s,sout]=system(sprintf('gunzip %s -c > %s &',input,SYS_FIFO_GUNZIP));
              fid=fopen(SYS_FIFO_GUNZIP,'r');
              assert(fid>0,'Error opening fifo (%s) for reading',SYS_FIFO_GUNZIP);
              SYS_FIFO_GUNZIP=fid;clear fid;
          else
              % If we can't fifo, there is a possiblity we could get the
              % raw data dump straight to stdout, Unfortunately, any
              % terminal spam is lumpted into that.
              % That could be alright, as we can just take the trailing
              % bytes, NOTE: This REQUIRES an exact var specification,
              % WHICH IS NOT enforced by this reader.
              [s,sout]=system(sprintf('gunzip %s -c -',input));
          end
          if s~=0 
              error(sout);
          end
      else
          warning('\n\n\n%s\n\n%s\n\n\n','THIS IS IMPOSSIBLY SLOW WITHOUT THE HELPER JAVA CODE','(like life of universe slow, you might as well quit)');
          pause(3);
          read_buffer = zeros(1,buffer_size,'uint8');
      end
  else
      % Mem check code used to be here, it has been moved to be part of
      % GzipReadCheck.
      
      % this was originally created inside the loop, but that is bad form
      % beacuse it would cause dropped bits.
      gzipReader=GzipRead;
  end
  % this matlab code was puzzled together from java examples, the java
  % equivalent code is in the comments.
  if ~exist('gzip_cont_vars','var')
      a=java.io.FileInputStream(input); gzi =java.util.zip.GZIPInputStream(a,buffer_size);%  GZIPInputStream gzi = new GZIPInputStream(new ByteArrayInputStream(buffer, 0, buffer.length));
      bos = java.io.ByteArrayOutputStream; %ByteArrayOutputStream bos =  new ByteArrayOutputStream();
      unused_bytes=uint8([]);
  else
      if ischar(SYS_FIFO_GUNZIP)||SYS_FIFO_GUNZIP~=0
          error('sys gunzip not compatible with gzip continue, not sure how you found this code path');
      end
      a=gzip_cont_vars{1};
      gzi=gzip_cont_vars{2};
      bos=gzip_cont_vars{3};
      unused_bytes=gzip_cont_vars{4};
  end
  rn=1;% read count, used for the output structure.
  outd=struct;
  fprintf('expanding...\n');
  ot=sprintf('%06.2fMiB ',0);
  fprintf(ot);
  % backspace count to let us print on same line, once data gets super big
  % we have to have more of them....
  bs_count=length(ot);
  c_var=1;%var_specifications{1}{3}; % which variable we're filling in right now.
  ready_bytes=0; % number of bytes of decompressed output ready.
  total_bytes=0; % total bytes we've decompressed.
  
  % Apparent logical glitch here, we only sort out the next vars, 
  % IF we're still reading the compressed data.
  % TODO: enhance while condition to run if c_var != last var, &&
  % gzi.available || unclaimed_bytes>0
  while(gzi.available ) % && a.available>0
      % Documentation of GZIPInputStream::read(byte[] buf, int off, int len)
      % read should have been the solution, however in testing, it
      % only returned arrays of zeros. It has been wrapped into an ultra
      % minimal class to do that job for us. 
      %%
      %     len=gzi.read(read_buffer,0,max_read); read_buffer(1:10)
      % MORE MADNESS, read() with no args, returns bytes as expected!
      % HINT: Zeros could be unsigned INT truncation.
      d=uint8([]);
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
      elseif SYS_FIFO_GUNZIP~=0 
          % we re-use sys_fifo_gunzip in naughty ways, first it's the path,
          % then its the file id.
          %
          % HOW would we get remaining bytes?
          % can we handle inf? or would that block forever on read?
          REMAINING_BYTES=buffer_size;%temp just have them equivalent.
          % Might be able to slip in var_spec details here for endian and
          % read count and data type
          d=fread(SYS_FIFO_GUNZIP,min(buffer_size,REMAINING_BYTES),'uint8=>uint8');
          if numel(d)<=0
              max_read=total_bytes;
          end
      else
          bi=1; %byte index, when java helper is unavailable we do it very wrongly.
          while(gzi.available && bi<= buffer_size) %while((len=gzi.read(outbuf, 0, outbuf.length)) != -1)
              read_buffer(bi)=gzi.read();
              bi=bi+1;
          end
          d=read_buffer(1:bi-1);
          %bi=1;% reset byte index.
      end
      ready_bytes=ready_bytes+numel(d);
      if numel(d)>0
          total_bytes=total_bytes+ready_bytes;
      end
      d=reshape(d,[1,numel(d)]);
      %% TODO 
      % fix issues with many small variable in a single decompression. 
      % this code is only good if the outputs are large enough that they
      % at most end up with 2 pieces per load.
      % MOVE typecast/endian handling right around here
      if ready_bytes<var_specifications{c_var}{1}
          % the output structure use a very large numebr of leading zeros
          % to help ensure the output structure works right. This does
          % introduce a maximum array size, but buffer_suze^30 is a very 
          % large amount of data so I feel okay about that.
          
          % check the type for var spec, and make sure we're an even
          % multiple of that, type cast and byteswap here to avoid large
          % data expansion later. 
          data_type=var_specifications{c_var}{2};
          bpv=class_bytes(data_type);
          if bpv>1
              % in case of uneven reads, find out how much over we are.
              extra_bytes=mod(numel(d),bpv);
              t=d(1:end-extra_bytes);
              unused_bytes=typecast(d(end-extra_bytes+1:end),'uint8');
              t=typecast(t,var_specifications{c_var}{2});
              endian=var_specifications{c_var}{4};
              if isempty(regexpi(endian,'(l(ittle)?|ieee-le)','once'))
                  if strcmp('L',native_endian)
                      t=swapbytes(t);
                  end
              end
              outd.(var_specifications{c_var}{3}).(sprintf('r_%030i',rn))=t;
              clear t;
          else
              outd.(var_specifications{c_var}{3}).(sprintf('r_%030i',rn))=reshape(d,[1,numel(d)]);
          end
      else
          % we have enough data elements for at least the first var, 
          % split up current array, assign part to current var, and rest to
          % next var. Maybe a while loop would allow this to assign to many
          % small vars.
          % need to know how many extra bytes we have
          % that should be ready_bytes-desired_total
          skip_bytes=0;
          while ready_bytes>0 && c_var<=numel(var_specifications)
              % in case of uneven reads, find out how much over we are.
              data_type=var_specifications{c_var}{2};
              bpv=class_bytes(data_type);
              % how many bytes more than this var spec's total bytes
              extra_bytes=ready_bytes-var_specifications{c_var}{1}; 
              if extra_bytes==-inf || bpv>1
                  extra_bytes=mod(numel(d),bpv);
              end
              t=d(1+skip_bytes:end-extra_bytes);
              t=typecast(t,var_specifications{c_var}{2});
              endian=var_specifications{c_var}{4};
              if isempty(regexpi(endian,'(l(ittle)?|ieee-le)','once'))
                  % If we're not little endian(eg we didnt match little)
                  if strcmp('L',native_endian)
                      t=swapbytes(t);
                  else
                      db_inplace(mfilename,'Endian not well understood by lazy programmer, I think in this context we don''t do anything? ');
                  end
              end
              outd.(var_specifications{c_var}{3}).(sprintf('r_%030i',rn))=t;
              skip_bytes=skip_bytes+var_specifications{c_var}{1};
              ready_bytes=ready_bytes-var_specifications{c_var}{1};
              rn=1;
              if ready_bytes==-inf
                  ready_bytes=0;
              else
                  c_var=c_var+1;
              end
              clear t;
          end
          %% stash extra bytes?
%              =[overflow; typecast(fgz.byteOut.toByteArray(),'uint8')]
          unused_bytes=typecast(d(end-extra_bytes+1:end),'uint8');
      end
      %outd.(sprintf('r_%030i',rn))=d';
      oinfo=whos('outd');
      MB=oinfo.bytes/2^20;
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
  out_fields=fieldnames( outd );
  if numel(out_fields)~=numel(var_specifications)
      db_inplace(mfilename,'error reading data gzip underflow?');
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
          try
              s2a.data= outd.(vn);outd=rmfield(outd,vn);
              kind_struct2array(s2a);
              outd.(vn)=s2a.data;clear s2a;
          catch merr
              warning(merr.message)
              outd.(vn)=zeros(0,var_specifications{se}{2});
          end
    else
      %% inline_strctlooper
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
    %% TODO Move the typecast code someplace better, 
    % ... this may finally be done. 
    % so it isnt so memory intensive doing it all at once at the end.
    % In theory, if our buffer size was a multiple of our data size, we
    % could do it right away.
    if strcmp(var_specifications{se}{2},'uint8')
        % uint8, do nothing
    else
        if ~INLINE_CAST_AND_SWAP
            outd.(vn)=typecast(outd.(vn),var_specifications{se}{2});
            endian=var_specifications{se}{4};
            if isempty(regexpi(endian,'(l(ittle)?|ieee-le)','once'))
                % ~regexpi(endian,'(l(ittle)|ieee-le)','once')
                [~,~,native_endian] = computer;
                if strcmp('L',native_endian)
                     outd.(vn)=swapbytes( outd.(vn));
                else
                    db_inplace(mfilename,'Endian not well understood by lazy programmer, I think in this context we don''t do anything? ');
                end
            end
        end
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
import com.mathworks.mlwidgets.io.InterruptibleStreamCopier;

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

