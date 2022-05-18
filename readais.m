%  AisData = READAIS(filePath,mmsiList)
%
%  DESCRIPTION: reads the navigation information from one or more AIS files 
%  and returns it in a structure. Only the Pamguard (*.csv) format is
%  supported; the SeicheSSV (*.aistext) format will be included in a future 
%  revision.
%
%  INPUT VARIABLES
%  - filePath: character string or cell vector of character strings specifying
%    the full path of the AIS file(s).
%  - mmsiList: numeric vector of MMSI identifiers. AISDATA contains only 
%    the navigation data from the corresponding vessels. To read the data 
%    from all MMSI use mmsiList = [];
%
%  OUTPUT VARIABLES
%  - AisData: navigation data structure. The structure contains as many 
%    elements as vessels have been selected. AISDATA contains the following 
%    fields:
%    ¬ pctick [number, double]: PC clock timestamp (ref. to '01-jan-0001
%      00:00:00')[s]
%    ¬ utctick [number, double]: UTC GPS timestamp (ref. to '01-jan-0001
%      00:00:00')[s]
%    ¬ lat [numeric vector, double]: latitude [deg]
%    ¬ lon [numeric vector, double]: longitude [deg]
%    ¬ mmsi [number, uint32]: unique vessel identifier MMSI
%    ¬ shipName [string]: name of the vessel
%    ¬ shipType [string]: type of vessel (e.g. passenger, tug, ...)
%    ¬ navStatus [numeric vector, uint8]: navigation status
%    ¬ sog [numeric vector, single]: speed over ground [kts]
%    ¬ cog [numeric vector, single]: course over ground [deg]
%    ¬ hea [numeric vector, sinlge]: heading [deg, re. North]
%
%  INTERNALLY CALLED FUNCTIONS
%  - None
%
%  CONSIDERATIONS & LIMITATIONS
%  - Multiple files can be read
%  - SeicheSSV (*.aistxt) format not yet supported.
%
%  FUNCTION CALLS
%  1) AisData = readais(filePath,mmsiList)

%  VERSION 1.0
%  Guillermo Jimenez Arranz
%  email: gjarranz@gmail.com
%  16 Apr 2018

function AisData = readais (filePath,mmsiList)

% Number of Selected Files
if iscell(filePath)
    nFiles = numel(filePath);
end

if ischar(filePath)
    filePath = {filePath};
    nFiles = 1;
end

% Error Control: Files Exist
fexist = false(1,nFiles);
for k = 1:nFiles
    fexist(k) = exist(filePath{k},'file') == 2;
end
if ~all(fexist)
    error('One or more of the selected AIS files do not exist')
end

% Error Control: File Extension
fext = cell(1,nFiles);
for k = 1:nFiles
    [~,~,fext{k}] = fileparts(filePath{k});
end

iscsv = strcmp(fext,'.csv');
isgpstext = strcmp(fext,'.aistext');
allcsv = all(iscsv);
allgpstext = all(isgpstext);

if any(~iscsv & ~isgpstext)
    error('One or more selected files have an unrecognised or unsupported format')
end

if ~allcsv && ~allgpstext
    error('All selected files must have the same format')
end

% File Format
if allcsv
    fext = '.csv';
else
    fext = '.aistext';
end

switch fext
    case '.aistext' % Read AIS Data (SeicheSSV)
        % NOT SUPPORTED IN THE CURRENT VERSION (v1.0, 14/04/2018)

        % Initialise AIS structure
        AisData = struct('pctick',[],'utctick',[],'lat',[],'lon',[],...
            'mmsi',[],'shipName',[],'shipType',[],'navStatus',[],...
            'sog',[],'cog',[],'hea',[]); % initialise AIS structure

    case '.csv' % Read AIS Data (PamGuard)

        % Error Control: Number of Input Arguments
        if nargin < 2, error('Not enough input arguments'); end
        if nargin > 2, error('Too many input arguments'); end

        % Initialise AIS structure
        AisData = struct('pctick',[],'utctick',[],'lat',[],'lon',[],...
            'mmsi',[],'shipName',[],'shipType',[],'navStatus',[],...
            'sog',[],'cog',[],'hea',[]); % initialise AIS structure

        % Load Data from Files
        i1 = 1;
        for k = 1:nFiles
            % Open .csv File
            fid = fopen(filePath{k});
            datatemp = textscan(fid,'%s','delimiter','\n');
            datatemp = datatemp{1};
            datatemp(1) = []; % remove first line (column names)
            fclose(fid);
            i2 = i1 + numel(datatemp) - 1;
            data(i1:i2) = datatemp;
            i1 = i2 + 1;
        end

        clear datatemp

        % Remove repeated sentences
        data = unique(data,'stable');

        % Remove Commas Not Used to Separate Fields (e.g. in shipName)
        ncol = 22;
        nrow = numel(data);
        ncom = uint8(zeros(1,nrow));
        for m = 1:nrow
            ncom(m) = uint8(length(find(data{m}==',')));
        end

        iwrongLine = find(ncom == 22);
        for m = 1: length(iwrongLine)
            lin = data{iwrongLine(m)};
            icom = find(lin == ',');
            ixtracom = icom(14);
            lin(ixtracom) = ' ';
            data{iwrongLine(m)} = lin;
        end

        clear ncom

        % Split Sentences into Fields
        datatxt = textscan([char(data) repmat(',',nrow,1)]','%s','delimiter',',');
        datatxt = reshape(datatxt{1},ncol,nrow)';

        clear data

        % Remove Sentences with Identical Relevant Parameters
        [~,ival,~] = unique([char(datatxt{:,2}) char(datatxt{:,8}) ...
            char(datatxt{:,10}) char(datatxt{:,11}) char(datatxt{:,15}) ...
            char(datatxt{:,17}) char(datatxt{:,18}) char(datatxt{:,19}) ...
            char(datatxt{:,20}) char(datatxt{:,21})],'rows','stable'); % ¦pctick¦ = datatxt{:,5} not included (somehow two different pcticks can be linked to the same AIS sentence)
        datatxt = datatxt(ival,:);

        % Retrieve Parameters
        pctick = datenum(datatxt(:,5),'yyyy-mm-dd HH:MM:SS.FFF')*86400; % PC tick time vector (ref. '01-jan-0001 00:00:00') [s]
        utctick = datenum(datatxt(:,2),'yyyy-mm-dd HH:MM:SS.FFF')*86400; % GPS tick time vector (ref. '01-jan-0001 00:00:00') [s]
        lat = str2double(datatxt(:,18)); %#ok<*FNDSB> % NOTE: converting to 'char' and using #str2num makes the processing 30 times faster than using #str2double
        lon = str2double(datatxt(:,19));
        mmsi = uint32(str2double(datatxt(:,8)));
        shipName = deblank(datatxt(:,10));
        shipType = deblank(datatxt(:,11));
        navStatus = uint8(str2double(datatxt(:,15)));
        sog = single(str2double(datatxt(:,17)));
        cog = single(str2double(datatxt(:,20)));
        hea = single(str2double(datatxt(:,21)));

        clear datatxt

        % Selected Vessels (MMSI)
        mmsiList = uint32(mmsiList);
        if isempty(mmsiList)
            mmsiList = unique(mmsi); % all the MMSI within the AIS file
        end

        % Generate Output Structure
        immsi = find(ismember(mmsi,mmsiList));
        AisData.utctick = utctick(immsi);
        AisData.pctick = pctick(immsi);
        AisData.lat = lat(immsi);
        AisData.lon = lon(immsi);
        AisData.mmsi = mmsi(immsi);
        AisData.shipName = shipName(immsi);
        AisData.shipType = shipType(immsi);
        AisData.navStatus = navStatus(immsi);
        AisData.sog = sog(immsi);
        AisData.cog = cog(immsi);
        AisData.hea = hea(immsi);

        % Sort Data by Time
        [~,isort] = sort(AisData.utctick);
        AisData.utctick = AisData.utctick(isort);
        AisData.pctick = AisData.pctick(isort);
        AisData.lat = AisData.lat(isort);
        AisData.lon = AisData.lon(isort);
        AisData.mmsi = AisData.mmsi(isort);
        AisData.shipName = AisData.shipName(isort);
        AisData.shipType = AisData.shipType(isort);
        AisData.navStatus = AisData.navStatus(isort);
        AisData.sog = AisData.sog(isort);
        AisData.cog = AisData.cog(isort);
        AisData.hea = AisData.hea(isort);

         % Remove Duplicated Ticks
        [~,iuni,~] = unique(AisData.utctick,'stable');
        AisData.utctick = AisData.utctick(iuni);
        AisData.pctick = AisData.pctick(iuni);
        AisData.lat = AisData.lat(iuni);
        AisData.lon = AisData.lon(iuni);
        AisData.mmsi = AisData.mmsi(iuni);
        AisData.shipName = AisData.shipName(iuni);
        AisData.shipType = AisData.shipType(iuni);
        AisData.navStatus = AisData.navStatus(iuni);
        AisData.sog = AisData.sog(iuni);
        AisData.cog = AisData.cog(iuni);
        AisData.hea = AisData.hea(iuni);

    otherwise
        error('File format not supported')
end
