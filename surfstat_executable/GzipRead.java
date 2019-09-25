import java.io.*; 
import java.util.zip.GZIPInputStream; 
/* java wrap the GZIPInputStream read method to enable matlab to use it.
 * This was required in MATLAB 2014a, and could be fixed in later versions. 
 * This java code is very rudimentary. 
 * It is probably a bad example, and breaks all kinds of common conventions.
 * -James Cook 20180216
 */
public class GzipRead {
      public int readToStream(GZIPInputStream inStream, int length, ByteArrayOutputStream oStream ) throws IOException {
          byte[] buffer = new byte[length];
          int rbytes=0;
          if (inStream.available()==1) {
              rbytes=inStream.read(buffer,0,length);
              if ( rbytes>0 ) {
                  oStream.write(buffer,0,rbytes);
                  oStream.flush();
              }
          }
          return rbytes;
      }
}
