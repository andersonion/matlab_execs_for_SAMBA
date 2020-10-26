function kind_struct2array(data_buffer,test_code)
oe=sort(fieldnames(data_buffer.data));
count=0;
for fn=1:numel(oe)
    count=count+numel(data_buffer.data.(oe{fn}));
end
output=zeros(1,count,'like',data_buffer.data.(oe{fn}));
output=output*1;% force allocation now?
%       output=spalloc(1,count,count); % sparse only available for type
%       double : (
idx=1;
fprintf('\t%06.3f/100\n',0)
for fn=1:numel(oe)
    output(idx:numel(data_buffer.data.(oe{fn}))+(idx-1))=data_buffer.data.(oe{fn});
    idx=idx+numel(data_buffer.data.(oe{fn}));
    data_buffer.data=rmfield(data_buffer.data,oe{fn});
    fprintf('\b\b\b\b\b\b\b\b\b\b\b%06.3f/100\n',100*fn/numel(oe));
end
data_buffer.data=output;clear output;
end