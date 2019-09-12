function db_inplace(fname,msg)
%db_inplace(function_name, extra message;
% will start debugging on next exectuion line after printing a message.
% message is optional. 
    if ~exist('msg','var')
        msg='DBSTOP CALLED CODE PAUSED';
    end
    [l,n,f]=db_get_line(fname);
    warning(msg);
    if ~isdeployed 
        eval(sprintf('dbstop in %s at %d',f,l+1));
    end
end
