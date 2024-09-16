function success=gzip_write(out,DATA,HEADER)
% status=GZIP_WRITE(output_path,data_matrix,header_matrix)
% primitive buffered gzip writer, to handle compression on save
% header should be simple binary data to prevent any problems.
% header is second because its optional... this is kinda silly, but not
% sure how far this has propigated yet. This feels like a job for vargin
% dumping each one in a buffered manner until we have no more.
success=0;
if ~strcmp(out(end-1:end),'gz')
    error('Gzip requires gz extension!');
end

%buffer_size=100*1024^2;%100mb buffer.
buffer_size=10*1024^2;  %10mb buffer.
%   buffer_size=1*1024^2;    %1mb buffer.
%   buffer_size=1*1024^1;     %1kb buffer.
%   buffer_size=128;        %128b buffer.

fOut=java.io.FileOutputStream(out);
%gzipOut=java.util.zip.GZIPOutputStream(fOut);
gzipOut=java.util.zip.GZIPOutputStream(fOut,cast(buffer_size,'int32'));
if exist('HEADER','var')
    HEADER=typecast(HEADER(:),'uint8');
    gzipOut.write(HEADER,0,numel(HEADER));
    gzipOut.flush();
    fOut.flush();
    clear HEADER;
end;

data_meta=whos('DATA');
% 
% get op size?
%elem=data_meta.size;
%bpe=data_meta.bytes/elem;
%op_size=data_meta.bytes
operations=ceil(data_meta.bytes/buffer_size);
DATA=typecast(DATA(:),'uint8');
% this typecast saves the machine endianness, such that it will be the same
% on load. 
% This may cause trouble in the future if we're loading stale datafiles...
% for each unit of data write and flush
progress_init();
for op=1:operations
    %ep=min(op*buffer_size,numel(DATA))
    sz=min(buffer_size,numel(DATA)-(op-1)*buffer_size);
    gzipOut.write(DATA((op-1)*buffer_size+1:(op-1)*buffer_size+sz),0,sz);

    progress_pct(op,operations);
end
gzipOut.flush();
fOut.flush();
% finish up.
gzipOut.finish();
gzipOut.close();
fOut.close();
success=1;