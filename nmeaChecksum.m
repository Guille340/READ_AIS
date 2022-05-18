%  checksumTrue = NMEACHECKSUM(nmeaLine)
%
%  DESCRIPTION
%  Calculates the checksum of a NMEA sentence (GPS or AIS) and returns 
%  TRUE when the checksum is correct.
%
%  INPUT VARIABLES
%  - nmeaLine: string containing the NMEA sentence. An NMEA sentence 
%    starts with "$" (GPS) or "!" (AIS) and ends with the hexadecimal 
%    checksum field "*HH".
%
%  OUTPUT VARIABLES
%  - checksumTrue: TRUE for a valid checksum
%
%  INTERNALLY CALLED FUNCTIONS
%  - None
%
%  FUNCTION CALLS
%  checksumTrue = nmeaChecksum(nmeaLine)

%  VERSION 1.0
%  Guillermo Jimenez Arranz
%  email: gjarranz@gmail.com
%  01 Nov 2014

function checksumTrue = nmeaChecksum(nmeaLine)

c1 = min([strfind(nmeaLine,'$') strfind(nmeaLine,'!')])+1; % starting position of NMEA line
c2 = strfind(nmeaLine,'*')-1; % ending position of NMEA line
nmeaNum = uint8(nmeaLine(c1:c2)); % convert characters into unsigned integer 8 bit (ASCII)
checksumStr = nmeaLine(c2+2:c2+3); % checksum string

checksum = 0; % checksum (initialised)
N = length(nmeaNum); % number of characters in NMEA line
for n = 1:N       
    checksum = bitxor(checksum,nmeaNum(n));  % checksum calculation
end

checksum = dec2hex(checksum,2); % convert checksum to hexadecimal value
checksumTrue = strcmp(checksum,checksumStr); % true for valid checksum (calculated checksum == checksum string)

