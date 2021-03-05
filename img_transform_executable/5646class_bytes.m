function bytes=class_bytes(class)
% bytes per value =class_bytes(class_string);
% given some matlab type uses cast to create a 0 of that type and return
% the byte count per value.
B = cast(0,class);
S = whos('B');
bytes=S.bytes;