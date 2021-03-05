function [line, name, file]=db_get_line(function_name)
% DB_GET_LINE given a function name, 
% return the line number of current executrion so we can see what we're
% doing.
d=dbstack;
line=0;
name='';
file='';
for el=1:length(d)
    if strcmp(d(el).name,function_name)
        line=d(el).line;
        name=d(el).name;
        file=d(el).file;
        break;
    end
end
end

function [line, name, file]=get_dbline(function_name)
% comptiblity function for old code. 
warning('Obsolete function call! get_dbline use db_get_line in the future');
pause(1);
[line, name, file]=db_get_line(function_name);
end
