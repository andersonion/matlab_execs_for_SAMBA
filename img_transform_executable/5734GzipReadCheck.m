function JAVA_HELPER_AVAILABLE=GzipReadCheck(skip_compile,requested_bytes,min_bytes)
if~exist('min_bytes','var')
    %min 1MiB;
    min_bytes=2^20;
end
if ~exist('skip_compile','var')
    skip_compile=0;
end
if ~exist('requested_bytes','var')
    % request 10MiB
    requested_bytes=10*2^20;
end

JAVA_HELPER_AVAILABLE=0;
%% find custom java gzip reader, and compile if need be.
cpath=fileparts(mfilename('fullpath'));
%%%
% check if available, if not try adding path.
if isempty(which('GzipRead'))
    javaaddpath(cpath);
end
% check if available, if not try compiling.
if isempty(which('GzipRead')) && ~skip_compile
    if isempty(getenv('MATLAB_JAVA'))
        warning('MATLAB_JAVA is not set!!!, this code relies on an updated version of java to dynamically compile a simple class file! set MATLAB_JAVA for full functionality, ideally add the bin folder of your JDK to the path. Will try anyway.');
    end
    [c_success,c_out]=system(sprintf('javac %s',fullfile(cpath,'GzipRead.java')));
    if ~c_success || isempty(which('GzipRead'))
        warning('Problem in java compile %s. "%s"',fullfile(cpath,'GzipRead.java'),c_out);
    end
end
if ~isempty(which('GzipRead'))
    JAVA_HELPER_AVAILABLE=1;
end
%% Check that we have enough memory to effectively use the gzip helper.

if java.lang.Runtime.getRuntime.maxMemory < 4*1024^3
    warning('Java memory, only %0.2fGiB allocated. 4GiB or more recommended, this code is likely to fail, for instructions see https://www.mathworks.com/help/matlab/matlab_external/java-heap-memory-preferences.html',java.lang.Runtime.getRuntime.maxMemory/2^30);
end
if requested_bytes*3 > java.lang.Runtime.getRuntime.freeMemory
    warning('Free memory safty margin exceeded, running java garbage collection');
    % not really sure if this is a good thing to run here or not.
    java.lang.System.gc();
end
% cut buffer size in half until it will fit in free memory.
while requested_bytes*3 > java.lang.Runtime.getRuntime.freeMemory ...
        && requested_bytes>min_bytes
    requested_bytes=0.5*requested_bytes;
    warning('Reduced buffer to %0.2fMiB',requested_bytes/1024^2);
end
if 3*min_bytes > java.lang.Runtime.getRuntime.freeMemory
    warning('Cant effecively use GzipRead. Java memory not tuned high enough, generally we want it as high as possible try adding java.opts file, see https://www.mathworks.com/matlabcentral/answers/92813-how-do-i-increase-the-heap-space-for-the-java-vm-in-matlab-6-0-r12-and-later-versions');
    JAVA_HELPER_AVAILABLE=0;
end
